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

// 乘法控制单元 - 管理两个乘法器实例
module exu_mul (
    input wire clk,
    input wire rst_n,
    input wire wb_ready,

    // 指令和操作数输入
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 译码输入
    input wire req_mul_i,
    input wire mul_op_mul_i,
    input wire mul_op_mulh_i,
    input wire mul_op_mulhsu_i,
    input wire mul_op_mulhu_i,

    // 中断信号
    input wire int_assert_i,

    // 控制输出
    output wire mul_stall_flag_o,

    // 寄存器写回接口
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 添加寄存器保存乘法指令的写回信息
    wire [`REG_ADDR_WIDTH-1:0] saved_mul0_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul1_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id;

    // 添加第二级寄存器
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id_stage2;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id_stage2;

    // 添加状态寄存器，用于控制写回
    wire mul0_result_we;
    wire mul1_result_we;
    wire [`REG_DATA_WIDTH-1:0] saved_mul0_result;
    wire [`REG_DATA_WIDTH-1:0] saved_mul1_result;

    wire [3:0] mul_op_sel_mux;
    wire [3:0] mul0_op;
    wire [3:0] mul1_op;
    wire ctrl_ready0;
    wire ctrl_ready1;
    wire mul0_start;
    wire mul1_start;

    wire [`REG_DATA_WIDTH-1:0] mul0_multiplicand;
    wire [`REG_DATA_WIDTH-1:0] mul0_multiplier;
    wire [`REG_DATA_WIDTH-1:0] mul1_multiplicand;
    wire [`REG_DATA_WIDTH-1:0] mul1_multiplier;

    // 乘法器输出信号
    wire [`REG_DATA_WIDTH-1:0] mul0_result;
    wire mul0_busy;
    wire mul0_valid;
    wire [`REG_DATA_WIDTH-1:0] mul1_result;
    wire mul1_busy;
    wire mul1_valid;

    // 直接使用输入的总乘法信号
    wire is_mul_op = req_mul_i && !int_assert_i;

    // Buffer寄存器定义
    reg [`REG_ADDR_WIDTH-1:0] waddr_buffer;
    reg [`REG_DATA_WIDTH-1:0] multiplicand_buffer;
    reg [`REG_DATA_WIDTH-1:0] multiplier_buffer;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_buffer;
    reg [3:0] mul_op_buffer;  // 4位：mul_op_mul_i, mul_op_mulh_i, mul_op_mulhsu_i, mul_op_mulhu_i
    reg buffer_req_valid;

    // Buffer数据选择
    wire use_buffer = buffer_req_valid;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_mux = use_buffer ? waddr_buffer : reg_waddr_i;
    wire [`REG_DATA_WIDTH-1:0] reg1_rdata_mux = use_buffer ? multiplicand_buffer : reg1_rdata_i;
    wire [`REG_DATA_WIDTH-1:0] reg2_rdata_mux = use_buffer ? multiplier_buffer : reg2_rdata_i;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_mux = use_buffer ? commit_id_buffer : commit_id_i;
    wire [3:0] mul_op_mux = use_buffer ? mul_op_buffer : {mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i};

    // mul_op_sel调整为mux后的数据
    assign mul_op_sel_mux    = mul_op_mux;
    assign mul0_op           = mul_op_sel_mux;
    assign mul1_op           = mul_op_sel_mux;
    // 乘法器输入调整为mux后的数据
    assign mul0_multiplicand = reg1_rdata_mux;
    assign mul0_multiplier = reg2_rdata_mux;
    assign mul1_multiplicand = reg1_rdata_mux;
    assign mul1_multiplier = reg2_rdata_mux;

    // 定义控制信号
    wire sel_mul0 = mul0_result_we;
    wire sel_mul1 = mul1_result_we;

    // 写回地址和commit_id调整为mux后的数据
    wire [`REG_ADDR_WIDTH-1:0] saved_mul0_waddr_nxt = reg_waddr_mux;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id_nxt = commit_id_mux;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul1_waddr_nxt = reg_waddr_mux;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id_nxt = commit_id_mux;

    wire mul0_result_we_en = (mul0_valid && ctrl_ready0) | (mul0_result_we && wb_ready);
    wire mul0_result_we_nxt = mul0_valid ? 1'b1 : 1'b0;

    wire saved_mul0_result_en = mul0_valid;
    wire [`REG_DATA_WIDTH-1:0] saved_mul0_result_nxt = mul0_result;

    wire mul1_result_we_en = (mul1_valid && ctrl_ready1) | (mul1_result_we && wb_ready && !sel_mul0);
    wire mul1_result_we_nxt = mul1_valid ? 1'b1 : 1'b0;

    wire saved_mul1_result_en = mul1_valid;
    wire [`REG_DATA_WIDTH-1:0] saved_mul1_result_nxt = mul1_result;

    // 使用gnrl_dfflr实现时序逻辑
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul0_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul0_start),
        .dnxt (saved_mul0_waddr_nxt),
        .qout (saved_mul0_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul0_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul0_start),
        .dnxt (saved_mul0_commit_id_nxt),
        .qout (saved_mul0_commit_id)
    );

    gnrl_dfflr #(
        .DW(1)
    ) mul0_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul0_result_we_en),
        .dnxt (mul0_result_we_nxt),
        .qout (mul0_result_we)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_mul0_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul0_result_en),
        .dnxt (saved_mul0_result_nxt),
        .qout (saved_mul0_result)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul1_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul1_start),
        .dnxt (saved_mul1_waddr_nxt),
        .qout (saved_mul1_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul1_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul1_start),
        .dnxt (saved_mul1_commit_id_nxt),
        .qout (saved_mul1_commit_id)
    );

    gnrl_dfflr #(
        .DW(1)
    ) mul1_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul1_result_we_en),
        .dnxt (mul1_result_we_nxt),
        .qout (mul1_result_we)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_mul1_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul1_result_en),
        .dnxt (saved_mul1_result_nxt),
        .qout (saved_mul1_result)
    );

    // 第二级 commit_id 更新条件
    wire                        saved_mul0_commit_id_stage2_en = mul0_valid;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id_stage2_nxt = saved_mul0_commit_id;

    wire                        saved_mul1_commit_id_stage2_en = mul1_valid;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id_stage2_nxt = saved_mul1_commit_id;

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul0_commit_id_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul0_commit_id_stage2_en),
        .dnxt (saved_mul0_commit_id_stage2_nxt),
        .qout (saved_mul0_commit_id_stage2)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul1_commit_id_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul1_commit_id_stage2_en),
        .dnxt (saved_mul1_commit_id_stage2_nxt),
        .qout (saved_mul1_commit_id_stage2)
    );

    // 第二级 waddr 更新条件
    wire                       saved_mul0_waddr_stage2_en = mul0_result_we_en;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul0_waddr_stage2_nxt = saved_mul0_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul0_waddr_stage2;

    wire                       saved_mul1_waddr_stage2_en = mul1_result_we_en;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul1_waddr_stage2_nxt = saved_mul1_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul1_waddr_stage2;

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul0_waddr_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul0_waddr_stage2_en),
        .dnxt (saved_mul0_waddr_stage2_nxt),
        .qout (saved_mul0_waddr_stage2)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul1_waddr_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul1_waddr_stage2_en),
        .dnxt (saved_mul1_waddr_stage2_nxt),
        .qout (saved_mul1_waddr_stage2)
    );

    // 添加乘法忙信号 - 表示乘除法器正在执行
    wire mul_busy = mul0_busy && mul1_busy;

    // 条件信号定义 - 用于流水线保持逻辑
    wire mul0_result_pending = mul0_result_we && mul0_valid;
    wire mul1_result_pending = mul1_result_we && mul1_valid;
    wire stall_mul_cond = is_mul_op && (mul_busy || mul0_result_pending || mul1_result_pending);

    // 乘法可用信号
    wire mul0_available = !mul0_busy && !mul0_result_pending;
    wire mul1_available = !mul1_busy && !mul1_result_pending;

    // Buffer写入条件
    wire buffer_write_en = stall_mul_cond;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_req_valid    <= 1'b0;
            waddr_buffer        <= {`REG_ADDR_WIDTH{1'b0}};
            multiplicand_buffer <= {`REG_DATA_WIDTH{1'b0}};
            multiplier_buffer   <= {`REG_DATA_WIDTH{1'b0}};
            commit_id_buffer    <= {`COMMIT_ID_WIDTH{1'b0}};
            mul_op_buffer       <= 4'b0;
        end else if (buffer_write_en && !buffer_req_valid) begin
            buffer_req_valid    <= 1'b1;
            waddr_buffer        <= reg_waddr_i;
            multiplicand_buffer <= reg1_rdata_i;
            multiplier_buffer   <= reg2_rdata_i;
            commit_id_buffer    <= commit_id_i;
            mul_op_buffer       <= {mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i};
        end else if (mul0_start || mul1_start) begin
            buffer_req_valid <= 1'b0;
        end
    end

    // 流水线保持控制逻辑
    assign mul_stall_flag_o = buffer_req_valid & is_mul_op;
    assign ctrl_ready0 = wb_ready || !mul0_result_we;
    assign ctrl_ready1 = wb_ready && !sel_mul0 || !mul1_result_we;

    // 启动条件调整
    assign mul0_start = (is_mul_op || buffer_req_valid) && mul0_available;
    assign mul1_start = (is_mul_op || buffer_req_valid) && !mul0_available && mul1_available;

    // 结果写回数据和地址选择逻辑 - 使用保存的结果和寄存器地址
    assign reg_wdata_o = sel_mul0 ? saved_mul0_result : (sel_mul1 ? saved_mul1_result : 0);
    assign reg_waddr_o = sel_mul0 ? saved_mul0_waddr_stage2 : (sel_mul1 ? saved_mul1_waddr_stage2 : 0);
    assign commit_id_o = sel_mul0 ? saved_mul0_commit_id_stage2 : (sel_mul1 ? saved_mul1_commit_id_stage2 : 0);

    // 结果写回使能控制逻辑
    assign reg_we_o = (sel_mul0 | sel_mul1);

    mul u_mul0 (
        .clk           (clk),
        .rst_n         (rst_n),
        .multiplicand_i(mul0_multiplicand),
        .multiplier_i  (mul0_multiplier),
        .start_i       (mul0_start),
        .ctrl_ready_i  (ctrl_ready0),
        .op_i          (mul0_op),
        .result_o      (mul0_result),
        .busy_o        (mul0_busy),
        .valid_o       (mul0_valid)
    );

    mul u_mul1 (
        .clk           (clk),
        .rst_n         (rst_n),
        .multiplicand_i(mul1_multiplicand),
        .multiplier_i  (mul1_multiplier),
        .start_i       (mul1_start),
        .ctrl_ready_i  (ctrl_ready1),
        .op_i          (mul1_op),
        .result_o      (mul1_result),
        .busy_o        (mul1_busy),
        .valid_o       (mul1_valid)
    );

endmodule
