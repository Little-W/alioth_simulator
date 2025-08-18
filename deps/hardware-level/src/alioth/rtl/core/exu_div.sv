/*         
 The MIT License (MIT)

 Copyright © 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
                                                                         
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
                                                                         
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "defines.svh"

// 除法控制单元 - 管理两个除法器实例
module exu_div (
    input wire clk,
    input wire rst_n,
    input wire wb_ready,

    // 指令和操作数输入
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    // 新增旁路输入和选择信号
    input wire [ `REG_DATA_WIDTH-1:0] alu1_result_bypass_i,
    input wire [ `REG_DATA_WIDTH-1:0] alu2_result_bypass_i,
    input wire                        div_pass_alu1_op1_i,
    input wire                        div_pass_alu1_op2_i,
    input wire                        div_pass_alu2_op1_i,
    input wire                        div_pass_alu2_op2_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 译码输入
    input wire req_div_i,
    input wire div_op_div_i,
    input wire div_op_divu_i,
    input wire div_op_rem_i,
    input wire div_op_remu_i,

    // 中断信号
    input wire int_assert_i,

    // 控制输出
    output wire div_stall_flag_o,

    // 寄存器写回接口
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 保存除法指令写回信息
    wire [`REG_ADDR_WIDTH-1:0] saved_div0_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_div1_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div0_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div1_commit_id;

    wire [3:0] div_op_sel_mux;
    wire [3:0] div0_op;
    wire [3:0] div1_op;
    wire ctrl_ready0;
    wire ctrl_ready1;
    wire div0_start;
    wire div1_start;
    wire div0_waw_mark;
    wire div1_waw_mark;

    wire [`REG_DATA_WIDTH-1:0] div0_dividend;
    wire [`REG_DATA_WIDTH-1:0] div0_divisor;
    wire [`REG_DATA_WIDTH-1:0] div1_dividend;
    wire [`REG_DATA_WIDTH-1:0] div1_divisor;

    // 除法器输出信号
    wire [`REG_DATA_WIDTH-1:0] div0_result;
    wire div0_busy;
    wire div0_valid;
    wire [`REG_DATA_WIDTH-1:0] div1_result;
    wire div1_busy;
    wire div1_valid;

    // 直接使用输入的总除法信号
    wire is_div_op = req_div_i && !int_assert_i;

    wire div_busy = div0_busy || div1_busy;

    // Buffer寄存器定义
    reg [`REG_ADDR_WIDTH-1:0] waddr_buffer;
    reg [`REG_DATA_WIDTH-1:0] dividend_buffer;
    reg [`REG_DATA_WIDTH-1:0] divisor_buffer;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_buffer;
    reg [3:0] div_op_buffer;  // 4位：div_op_remu_i, div_op_rem_i, div_op_divu_i, div_op_div_i
    reg buffer_req_valid;

    // Buffer数据选择
    wire use_buffer = buffer_req_valid;
    // 新增旁路mux
    wire [`REG_DATA_WIDTH-1:0] reg1_rdata_pre_mux = use_buffer ? dividend_buffer : reg1_rdata_i;
    wire [`REG_DATA_WIDTH-1:0] reg2_rdata_pre_mux = use_buffer ? divisor_buffer : reg2_rdata_i;
    // 修改为支持四种旁路选择
    wire [`REG_DATA_WIDTH-1:0] reg1_rdata_mux =
        div_pass_alu1_op1_i ? alu1_result_bypass_i :
        div_pass_alu2_op1_i ? alu2_result_bypass_i :
        reg1_rdata_pre_mux;
    wire [`REG_DATA_WIDTH-1:0] reg2_rdata_mux =
        div_pass_alu1_op2_i ? alu1_result_bypass_i :
        div_pass_alu2_op2_i ? alu2_result_bypass_i :
        reg2_rdata_pre_mux;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_mux = use_buffer ? waddr_buffer : reg_waddr_i;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_mux = use_buffer ? commit_id_buffer : commit_id_i;
    wire [3:0] div_op_mux = use_buffer ? div_op_buffer : {div_op_remu_i, div_op_rem_i, div_op_divu_i, div_op_div_i};

    // div_op_sel调整为mux后的数据
    assign div_op_sel_mux = div_op_mux;
    assign div0_op        = div_op_sel_mux;
    assign div1_op        = div_op_sel_mux;
    assign div0_dividend  = reg1_rdata_mux;
    assign div0_divisor   = reg2_rdata_mux;
    assign div1_dividend  = reg1_rdata_mux;
    assign div1_divisor   = reg2_rdata_mux;

    // 控制信号
    wire                        sel_div0 = div0_valid && !div0_waw_mark;
    wire                        sel_div1 = div1_valid && !div1_waw_mark;

    // 写回地址和commit_id调整为mux后的数据
    wire [ `REG_ADDR_WIDTH-1:0] saved_div0_waddr_nxt = reg_waddr_mux;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div0_commit_id_nxt = commit_id_mux;
    wire [ `REG_ADDR_WIDTH-1:0] saved_div1_waddr_nxt = reg_waddr_mux;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div1_commit_id_nxt = commit_id_mux;

    // 保存除法器写回地址和commit_id
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div0_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div0_start),
        .dnxt (saved_div0_waddr_nxt),
        .qout (saved_div0_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div0_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div0_start),
        .dnxt (saved_div0_commit_id_nxt),
        .qout (saved_div0_commit_id)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div1_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div1_start),
        .dnxt (saved_div1_waddr_nxt),
        .qout (saved_div1_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div1_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div1_start),
        .dnxt (saved_div1_commit_id_nxt),
        .qout (saved_div1_commit_id)
    );

    // 条件信号定义 - 用于流水线保持逻辑
    wire div0_result_pending = div0_valid;
    wire div1_result_pending = div1_valid;

    // 除法可用信号
    wire div0_available = !div0_busy && !div0_result_pending;
    wire div1_available = !div1_busy && !div1_result_pending;

    wire div0_wb_accept = sel_div0 && wb_ready;
    wire div1_wb_accept = sel_div1 && wb_ready;

    // WAW检测条件
    wire div0_waw_mark_nxt = (saved_div0_waddr_nxt == saved_div1_waddr) && div1_busy && !div1_wb_accept;
    wire div1_waw_mark_nxt = (saved_div1_waddr_nxt == saved_div0_waddr) && div0_busy && !div0_wb_accept;

    gnrl_dfflr #(
        .DW(1)
    ) div0_waw_mark_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div0_start | div1_wb_accept),
        .dnxt (div0_waw_mark_nxt),
        .qout (div0_waw_mark)
    );

    gnrl_dfflr #(
        .DW(1)
    ) div1_waw_mark_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div1_start | div0_wb_accept),
        .dnxt (div1_waw_mark_nxt),
        .qout (div1_waw_mark)
    );

    // Buffer写入条件
    wire buffer_write_en = is_div_op && !div1_available && !div1_available;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_req_valid <= 1'b0;
            waddr_buffer     <= {`REG_ADDR_WIDTH{1'b0}};
            dividend_buffer  <= {`REG_DATA_WIDTH{1'b0}};
            divisor_buffer   <= {`REG_DATA_WIDTH{1'b0}};
            commit_id_buffer <= {`COMMIT_ID_WIDTH{1'b0}};
            div_op_buffer    <= 4'b0;
        end else if (buffer_write_en && !buffer_req_valid) begin
            buffer_req_valid <= 1'b1;
            waddr_buffer     <= reg_waddr_i;
            // buffer写入时使用mux数据
            dividend_buffer  <= reg1_rdata_mux;
            divisor_buffer   <= reg2_rdata_mux;
            commit_id_buffer <= commit_id_i;
            div_op_buffer    <= {div_op_remu_i, div_op_rem_i, div_op_divu_i, div_op_div_i};
        end else if (div0_start || div1_start) begin
            buffer_req_valid <= 1'b0;
        end
    end

    // 流水线保持控制逻辑
    assign div_stall_flag_o = buffer_req_valid & is_div_op;
    // WAW避免：div0_waw_mark为1时block写回
    assign ctrl_ready0 = (wb_ready || !div0_valid) && !div0_waw_mark;
    // WAW避免：div1_waw_mark为1时block写回
    assign ctrl_ready1 = ((wb_ready && !sel_div0) || !div1_valid) && !div1_waw_mark;

    // 启动条件调整
    assign div0_start = (is_div_op || buffer_req_valid) && div0_available;
    assign div1_start = (is_div_op || buffer_req_valid) && !div0_available && div1_available;

    // 结果写回数据和地址选择逻辑 - 直接使用除法器输出
    assign reg_wdata_o = sel_div0 ? div0_result : (sel_div1 ? div1_result : 0);
    assign reg_waddr_o = sel_div0 ? saved_div0_waddr : (sel_div1 ? saved_div1_waddr : 0);
    assign commit_id_o = sel_div0 ? saved_div0_commit_id : (sel_div1 ? saved_div1_commit_id : 0);

    // 结果写回使能控制逻辑
    assign reg_we_o = (sel_div0 | sel_div1);

    div u_div0 (
        .clk         (clk),
        .rst_n       (rst_n),
        .dividend_i  (div0_dividend),
        .divisor_i   (div0_divisor),
        .start_i     (div0_start),
        .ctrl_ready_i(ctrl_ready0),
        .op_i        (div0_op),
        .result_o    (div0_result),
        .busy_o      (div0_busy),
        .valid_o     (div0_valid)
    );

    div u_div1 (
        .clk         (clk),
        .rst_n       (rst_n),
        .dividend_i  (div1_dividend),
        .divisor_i   (div1_divisor),
        .start_i     (div1_start),
        .ctrl_ready_i(ctrl_ready1),
        .op_i        (div1_op),
        .result_o    (div1_result),
        .busy_o      (div1_busy),
        .valid_o     (div1_valid)
    );

endmodule