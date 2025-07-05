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

// 乘除法控制单元 - 处理乘除法指令的控制和结果写回
module exu_muldiv_ctrl (
    input wire clk,
    input wire rst_n,
    input wire wb_ready,
    input wire hazard_stall_i,  // 添加数据冒险检测信号

    // 指令和操作数输入
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 从dispatch接收的译码输入
    input wire req_muldiv_i,
    input wire muldiv_op_mul_i,
    input wire muldiv_op_mulh_i,
    input wire muldiv_op_mulhsu_i,
    input wire muldiv_op_mulhu_i,
    input wire muldiv_op_div_i,
    input wire muldiv_op_divu_i,
    input wire muldiv_op_rem_i,
    input wire muldiv_op_remu_i,
    input wire muldiv_op_mul_all_i,
    input wire muldiv_op_div_all_i,

    // 除法器接口
    input wire [`REG_DATA_WIDTH-1:0] div_result_i,
    input wire                       div_busy_i,
    input wire                       div_valid_i,   // 新增：除法结果有效信号

    // 乘法器接口
    input wire [`REG_DATA_WIDTH-1:0] mul_result_i,
    input wire                       mul_busy_i,
    input wire                       mul_valid_i,   // 新增：乘法结果有效信号

    // 中断信号
    input wire int_assert_i,

    // 除法控制输出
    output reg                       div_start_o,
    output reg [`REG_DATA_WIDTH-1:0] div_dividend_o,
    output reg [`REG_DATA_WIDTH-1:0] div_divisor_o,
    output reg [                3:0] div_op_o,

    // 乘法控制输出
    output reg                       mul_start_o,
    output reg [`REG_DATA_WIDTH-1:0] mul_multiplicand_o,
    output reg [`REG_DATA_WIDTH-1:0] mul_multiplier_o,
    output reg [                3:0] mul_op_o,

    // 控制输出
    output reg muldiv_stall_flag_o,

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output reg [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 添加寄存器保存乘除法指令的写回信息
    wire [`REG_ADDR_WIDTH-1:0] saved_div_waddr;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul_commit_id;

    // 添加状态寄存器，用于控制写回
    wire                       div_result_we;
    wire                       mul_result_we;
    wire [`REG_DATA_WIDTH-1:0] saved_div_result;
    wire [`REG_DATA_WIDTH-1:0] saved_mul_result;

    // 生成div_op_o的组合逻辑
    wire [                3:0] div_op_sel;
    assign div_op_sel = {muldiv_op_remu_i, muldiv_op_rem_i, muldiv_op_divu_i, muldiv_op_div_i};

    // 生成mul_op_o的组合逻辑
    wire [3:0] mul_op_sel;
    assign mul_op_sel = {muldiv_op_mulhu_i, muldiv_op_mulhsu_i, muldiv_op_mulh_i, muldiv_op_mul_i};

    // 直接使用输入的总乘法和总除法信号
    wire is_mul_op = muldiv_op_mul_all_i;
    wire is_div_op = muldiv_op_div_all_i;

    // 定义控制信号
    wire div_start_cond = is_div_op && !div_busy_i && !div_result_we;
    wire mul_start_cond = is_mul_op && !mul_busy_i && !mul_result_we;
    wire sel_mul = mul_result_we;
    wire sel_div = div_result_we;

    // 除法寄存器更新条件
    wire saved_div_waddr_en = div_start_cond;
    wire [`REG_ADDR_WIDTH-1:0] saved_div_waddr_nxt = reg_waddr_i;

    wire saved_div_commit_id_en = div_start_cond;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div_commit_id_nxt = commit_id_i;

    wire div_result_we_en = div_valid_i | (div_result_we && wb_ready && reg_we_o && !sel_mul);
    wire div_result_we_nxt = div_valid_i ? 1'b1 : 1'b0;

    wire saved_div_result_en = div_valid_i;
    wire [`REG_DATA_WIDTH-1:0] saved_div_result_nxt = div_result_i;

    // 乘法寄存器更新条件
    wire saved_mul_waddr_en = mul_start_cond;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul_waddr_nxt = reg_waddr_i;

    wire saved_mul_commit_id_en = mul_start_cond;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul_commit_id_nxt = commit_id_i;

    wire mul_result_we_en = mul_valid_i | (mul_result_we && wb_ready && reg_we_o);
    wire mul_result_we_nxt = mul_valid_i ? 1'b1 : 1'b0;

    wire saved_mul_result_en = mul_valid_i;
    wire [`REG_DATA_WIDTH-1:0] saved_mul_result_nxt = mul_result_i;

    // 使用gnrl_dfflr实现时序逻辑
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_waddr_en),
        .dnxt (saved_div_waddr_nxt),
        .qout (saved_div_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_commit_id_en),
        .dnxt (saved_div_commit_id_nxt),
        .qout (saved_div_commit_id)
    );

    gnrl_dfflr #(
        .DW(1)
    ) div_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div_result_we_en),
        .dnxt (div_result_we_nxt),
        .qout (div_result_we)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_div_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_result_en),
        .dnxt (saved_div_result_nxt),
        .qout (saved_div_result)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_waddr_en),
        .dnxt (saved_mul_waddr_nxt),
        .qout (saved_mul_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_commit_id_en),
        .dnxt (saved_mul_commit_id_nxt),
        .qout (saved_mul_commit_id)
    );

    gnrl_dfflr #(
        .DW(1)
    ) mul_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul_result_we_en),
        .dnxt (mul_result_we_nxt),
        .qout (mul_result_we)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_mul_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_result_en),
        .dnxt (saved_mul_result_nxt),
        .qout (saved_mul_result)
    );

    // 操作数和操作类型输出 - 可以保持为组合逻辑
    assign div_dividend_o     = reg1_rdata_i;
    assign div_divisor_o      = reg2_rdata_i;
    assign div_op_o           = div_op_sel;
    assign mul_multiplicand_o = reg1_rdata_i;
    assign mul_multiplier_o   = reg2_rdata_i;
    assign mul_op_o           = mul_op_sel;

    // 添加乘除法忙信号 - 表示乘除法器正在执行
    wire muldiv_busy = div_busy_i || mul_busy_i;

    // 除法启动控制逻辑 - 条件定义
    wire div_int_cond = int_assert_i;
    wire div_op_busy_cond = is_div_op && div_busy_i;
    wire div_op_ready_cond = is_div_op && !div_busy_i;
    wire div_op_start_cond = is_div_op && !div_busy_i && !div_result_we && !hazard_stall_i;
    wire div_busy_cond = !is_div_op && div_busy_i;

    // 除法启动控制逻辑 - 只在需要启动新的除法操作时为高，并在中断时禁止启动
    assign div_start_o = (int_assert_i == `INT_ASSERT) ? 1'b0 : div_op_start_cond;

    // 乘法启动控制逻辑 - 条件定义
    wire mul_int_cond = int_assert_i;
    wire mul_op_busy_cond = is_mul_op && mul_busy_i;
    wire mul_op_ready_cond = is_mul_op && !mul_busy_i;
    wire mul_op_start_cond = is_mul_op && !mul_busy_i && !mul_result_we && !hazard_stall_i;
    wire mul_busy_cond = !is_mul_op && mul_busy_i;

    // 乘法启动控制逻辑 - 只在需要启动新的乘法操作时为高，并在中断时禁止启动
    assign mul_start_o = (int_assert_i == `INT_ASSERT) ? 1'b0 : mul_op_start_cond;

    // 条件信号定义 - 用于流水线保持逻辑
    wire stall_mul_cond = is_mul_op && (mul_busy_i || mul_result_we);
    wire stall_div_cond = is_div_op && (div_busy_i || div_result_we);
    wire stall_result_pending = div_result_we || mul_result_we; // 增加结果等待写回的保持条件

    // 流水线保持控制逻辑
    assign muldiv_stall_flag_o = stall_mul_cond | stall_div_cond;

    // 结果写回数据和地址选择逻辑 - 使用保存的结果和寄存器地址
    assign reg_wdata_o = sel_mul ? saved_mul_result : (sel_div ? saved_div_result : 0);
    assign reg_waddr_o = sel_mul ? saved_mul_waddr : (sel_div ? saved_div_waddr : 0);
    assign commit_id_o = sel_mul ? saved_mul_commit_id : (sel_div ? saved_div_commit_id : 0);

    // 结果写回使能控制逻辑
    assign reg_we_o = (sel_mul | sel_div);

endmodule