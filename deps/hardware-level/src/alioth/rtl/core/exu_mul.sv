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
    input wire mul_op_mul_all_i,

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
    wire [ `REG_ADDR_WIDTH-1:0] saved_mul0_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] saved_mul1_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id;

    // 添加第二级寄存器
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id_stage2;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id_stage2;

    // 添加状态寄存器，用于控制写回
    wire                        mul0_result_we;
    wire                        mul1_result_we;
    wire [ `REG_DATA_WIDTH-1:0] saved_mul0_result;
    wire [ `REG_DATA_WIDTH-1:0] saved_mul1_result;

    // 生成mul_op_o的组合逻辑
    wire [                 3:0] mul_op_sel;
    assign mul_op_sel = {mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i};

    // 补充操作类型信号定义
    wire [3:0] mul0_op;
    wire [3:0] mul1_op;
    wire       ctrl_ready0;
    wire       ctrl_ready1;
    wire       mul0_start;
    wire       mul1_start;

    assign mul0_op = mul_op_sel;
    assign mul1_op = mul_op_sel;

    wire [`REG_DATA_WIDTH-1:0] mul0_multiplicand;
    wire [`REG_DATA_WIDTH-1:0] mul0_multiplier;
    wire [`REG_DATA_WIDTH-1:0] mul1_multiplicand;
    wire [`REG_DATA_WIDTH-1:0] mul1_multiplier;

    assign mul0_multiplicand = reg1_rdata_i;
    assign mul0_multiplier   = reg2_rdata_i;
    assign mul1_multiplicand = reg1_rdata_i;
    assign mul1_multiplier   = reg2_rdata_i;

    // 乘法器输出信号
    wire [`REG_DATA_WIDTH-1:0] mul0_result;
    wire mul0_busy;
    wire mul0_valid;
    wire [`REG_DATA_WIDTH-1:0] mul1_result;
    wire mul1_busy;
    wire mul1_valid;

    // 直接使用输入的总乘法信号
    wire is_mul_op = req_mul_i && !int_assert_i;

    // 定义控制信号
    wire sel_mul0 = mul0_result_we;
    wire sel_mul1 = mul1_result_we;

    // 乘法寄存器更新条件
    wire [`REG_ADDR_WIDTH-1:0] saved_mul0_waddr_nxt = reg_waddr_i;

    wire [`COMMIT_ID_WIDTH-1:0] saved_mul0_commit_id_nxt = commit_id_i;

    wire mul0_result_we_en = (mul0_valid && ctrl_ready0) | (mul0_result_we && wb_ready);
    wire mul0_result_we_nxt = mul0_valid ? 1'b1 : 1'b0;

    wire saved_mul0_result_en = mul0_valid;
    wire [`REG_DATA_WIDTH-1:0] saved_mul0_result_nxt = mul0_result;

    // 乘法寄存器更新条件
    wire [`REG_ADDR_WIDTH-1:0] saved_mul1_waddr_nxt = reg_waddr_i;

    wire [`COMMIT_ID_WIDTH-1:0] saved_mul1_commit_id_nxt = commit_id_i;

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

    // 流水线保持控制逻辑
    assign mul_stall_flag_o = stall_mul_cond;
    assign ctrl_ready0 = wb_ready || !mul0_result_we;
    assign ctrl_ready1 = wb_ready && !sel_mul0 || !mul1_result_we;

    // 乘法可用信号
    wire mul0_available = !mul0_busy && !mul0_result_pending;
    wire mul1_available = !mul1_busy && !mul1_result_pending;

    // 乘法启动控制逻辑 - 只在需要启动新的乘法操作时为高，并在中断时禁止启动
    assign mul0_start = is_mul_op && mul0_available;
    assign mul1_start = is_mul_op && !mul0_available && mul1_available;

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
