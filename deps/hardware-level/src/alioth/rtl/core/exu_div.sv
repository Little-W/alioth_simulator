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
    wire [ `REG_ADDR_WIDTH-1:0] saved_div0_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] saved_div1_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div0_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div1_commit_id;

    // 第二级寄存器
    wire [`COMMIT_ID_WIDTH-1:0] saved_div0_commit_id_stage2;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div1_commit_id_stage2;

    // 状态寄存器
    wire                        div0_result_we;
    wire                        div1_result_we;
    wire [ `REG_DATA_WIDTH-1:0] saved_div0_result;
    wire [ `REG_DATA_WIDTH-1:0] saved_div1_result;

    // 生成div_op_sel
    wire [                 3:0] div_op_sel;
    assign div_op_sel = {div_op_remu_i, div_op_rem_i, div_op_divu_i, div_op_div_i};

    wire [3:0] div0_op;
    wire [3:0] div1_op;
    wire       ctrl_ready0;
    wire       ctrl_ready1;
    wire       div0_start;
    wire       div1_start;

    assign div0_op = div_op_sel;
    assign div1_op = div_op_sel;

    wire [`REG_DATA_WIDTH-1:0] div0_dividend;
    wire [`REG_DATA_WIDTH-1:0] div0_divisor;
    wire [`REG_DATA_WIDTH-1:0] div1_dividend;
    wire [`REG_DATA_WIDTH-1:0] div1_divisor;

    assign div0_dividend = reg1_rdata_i;
    assign div0_divisor  = reg2_rdata_i;
    assign div1_dividend = reg1_rdata_i;
    assign div1_divisor  = reg2_rdata_i;

    // 除法器输出信号
    wire [`REG_DATA_WIDTH-1:0] div0_result;
    wire div0_busy;
    wire div0_valid;
    wire [`REG_DATA_WIDTH-1:0] div1_result;
    wire div1_busy;
    wire div1_valid;

    // 总除法信号
    wire is_div_op = req_div_i && !int_assert_i;

    // 控制信号
    wire sel_div0 = div0_result_we;
    wire sel_div1 = div1_result_we;

    // 除法寄存器更新条件
    wire [`REG_ADDR_WIDTH-1:0] saved_div0_waddr_nxt = reg_waddr_i;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div0_commit_id_nxt = commit_id_i;
    wire div0_result_we_en = (div0_valid && ctrl_ready0) | (div0_result_we && wb_ready);
    wire div0_result_we_nxt = div0_valid ? 1'b1 : 1'b0;
    wire saved_div0_result_en = div0_valid;
    wire [`REG_DATA_WIDTH-1:0] saved_div0_result_nxt = div0_result;

    wire [`REG_ADDR_WIDTH-1:0] saved_div1_waddr_nxt = reg_waddr_i;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div1_commit_id_nxt = commit_id_i;
    wire div1_result_we_en = (div1_valid && ctrl_ready1) | (div1_result_we && wb_ready && !sel_div0);
    wire div1_result_we_nxt = div1_valid ? 1'b1 : 1'b0;
    wire saved_div1_result_en = div1_valid;
    wire [`REG_DATA_WIDTH-1:0] saved_div1_result_nxt = div1_result;

    // 时序逻辑
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
        .DW(1)
    ) div0_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div0_result_we_en),
        .dnxt (div0_result_we_nxt),
        .qout (div0_result_we)
    );
    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_div0_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div0_result_en),
        .dnxt (saved_div0_result_nxt),
        .qout (saved_div0_result)
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
    gnrl_dfflr #(
        .DW(1)
    ) div1_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div1_result_we_en),
        .dnxt (div1_result_we_nxt),
        .qout (div1_result_we)
    );
    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_div1_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div1_result_en),
        .dnxt (saved_div1_result_nxt),
        .qout (saved_div1_result)
    );

    // 第二级 commit_id
    wire                        saved_div0_commit_id_stage2_en = div0_valid;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div0_commit_id_stage2_nxt = saved_div0_commit_id;
    wire                        saved_div1_commit_id_stage2_en = div1_valid;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div1_commit_id_stage2_nxt = saved_div1_commit_id;
    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div0_commit_id_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div0_commit_id_stage2_en),
        .dnxt (saved_div0_commit_id_stage2_nxt),
        .qout (saved_div0_commit_id_stage2)
    );
    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div1_commit_id_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div1_commit_id_stage2_en),
        .dnxt (saved_div1_commit_id_stage2_nxt),
        .qout (saved_div1_commit_id_stage2)
    );

    // 第二级 waddr
    wire                       saved_div0_waddr_stage2_en = div0_result_we_en;
    wire [`REG_ADDR_WIDTH-1:0] saved_div0_waddr_stage2_nxt = saved_div0_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_div0_waddr_stage2;
    wire                       saved_div1_waddr_stage2_en = div1_result_we_en;
    wire [`REG_ADDR_WIDTH-1:0] saved_div1_waddr_stage2_nxt = saved_div1_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_div1_waddr_stage2;
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div0_waddr_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div0_waddr_stage2_en),
        .dnxt (saved_div0_waddr_stage2_nxt),
        .qout (saved_div0_waddr_stage2)
    );
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div1_waddr_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div1_waddr_stage2_en),
        .dnxt (saved_div1_waddr_stage2_nxt),
        .qout (saved_div1_waddr_stage2)
    );

    // 除法忙信号
    wire div_busy = div0_busy && div1_busy;

    // 条件信号
    wire div0_result_pending = div0_result_we && div0_valid;
    wire div1_result_pending = div1_result_we && div1_valid;
    wire stall_div_cond = is_div_op && (div_busy || div0_result_pending || div1_result_pending);

    // 流水线保持控制逻辑
    assign div_stall_flag_o = stall_div_cond;
    assign ctrl_ready0 = wb_ready || !div0_result_we;
    assign ctrl_ready1 = wb_ready && !sel_div0 || !div1_result_we;

    // 除法可用信号 - 检查除法器是否空闲且结果未准备好
    wire div0_available = !div0_busy && !div0_result_pending;
    wire div1_available = !div1_busy && !div1_result_pending;

    // 除法启动控制逻辑
    assign div0_start = is_div_op && div0_available;
    assign div1_start = is_div_op && !div0_available && div1_available;

    // 结果写回数据和地址选择逻辑
    assign reg_wdata_o = sel_div0 ? saved_div0_result : (sel_div1 ? saved_div1_result : 0);
    assign reg_waddr_o = sel_div0 ? saved_div0_waddr_stage2 : (sel_div1 ? saved_div1_waddr_stage2 : 0);
    assign commit_id_o = sel_div0 ? saved_div0_commit_id_stage2 : (sel_div1 ? saved_div1_commit_id_stage2 : 0);

    // 结果写回使能
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
