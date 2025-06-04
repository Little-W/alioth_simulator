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

    // 指令和操作数输入
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`BUS_ADDR_WIDTH-1:0] op1_jump_i,
    input wire [`BUS_ADDR_WIDTH-1:0] op2_jump_i,
    input wire [                3:0] commit_id_i,

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
    input wire                       div_valid_i,  // 新增：除法结果有效信号

    // 乘法器接口
    input wire [`REG_DATA_WIDTH-1:0] mul_result_i,
    input wire                       mul_busy_i,
    input wire                       mul_valid_i,  // 新增：乘法结果有效信号

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
    output reg muldiv_hold_flag_o,
    output reg muldiv_jump_flag_o,

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output reg [                3:0] commit_id_o
);

    // 添加寄存器保存乘除法指令的写回信息
    reg [`REG_ADDR_WIDTH-1:0] saved_div_waddr;
    reg [`REG_ADDR_WIDTH-1:0] saved_mul_waddr;
    reg [3:0] saved_div_commit_id;
    reg [3:0] saved_mul_commit_id;

    // 添加状态寄存器，用于控制写回
    reg div_result_we;
    reg mul_result_we;
    reg [`REG_DATA_WIDTH-1:0] saved_div_result;
    reg [`REG_DATA_WIDTH-1:0] saved_mul_result;

    // 生成div_op_o的组合逻辑
    wire [3:0] div_op_sel;
    assign div_op_sel = {
        muldiv_op_remu_i, muldiv_op_rem_i, muldiv_op_divu_i, muldiv_op_div_i
    };

    // 生成mul_op_o的组合逻辑
    wire [3:0] mul_op_sel;
    assign mul_op_sel = {
        muldiv_op_mulhu_i, muldiv_op_mulhsu_i, muldiv_op_mulh_i, muldiv_op_mul_i
    };

    // 直接使用输入的总乘法和总除法信号
    wire is_mul_op = muldiv_op_mul_all_i;
    wire is_div_op = muldiv_op_div_all_i;

    // 时序逻辑：当启动除法或乘法操作时，保存写回地址
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_div_waddr       <= 0;
            saved_mul_waddr       <= 0;
            saved_div_commit_id   <= 0;
            saved_mul_commit_id   <= 0;
            div_result_we         <= 1'b0;
            mul_result_we         <= 1'b0;
            saved_div_result      <= 0;
            saved_mul_result      <= 0;
        end else begin
            // 除法指令启动时保存信息
            if (is_div_op && !div_busy_i && !div_result_we) begin
                saved_div_waddr <= reg_waddr_i;
                saved_div_commit_id   <= commit_id_i;   // 新增：保存除法指令commit_id
                div_result_we         <= 1'b0; // 新指令开始时清除结果有效标志
            end else if (div_valid_i) begin
                // 当除法结果有效时，表示除法完成
                saved_div_result      <= div_result_i;  // 保存除法结果
                div_result_we         <= 1'b1;  // 设置结果有效标志
            end

            // 乘法指令启动时保存信息
            if (is_mul_op && !mul_busy_i && !mul_result_we) begin
                saved_mul_waddr <= reg_waddr_i;
                saved_mul_commit_id   <= commit_id_i;   // 新增：保存乘法指令commit_id
                mul_result_we         <= 1'b0; // 新指令开始时清除结果有效标志
            end else if (mul_valid_i) begin
                // 当乘法结果有效时，表示乘法完成
                saved_mul_result      <= mul_result_i;  // 保存乘法结果
                mul_result_we         <= 1'b1;  // 设置结果有效标志
            end

            // 修改写回后清除有效标志的逻辑 - 使用wb_ready握手信号
            // 优先写回乘法结果：只有当写回请求被接受(wb_ready=1)时才清除valid标志
            if (mul_result_we && wb_ready && reg_we_o) begin
                mul_result_we <= 1'b0;
            end
            if (div_result_we && wb_ready && reg_we_o && !sel_mul) begin
                // 只有在不写回乘法结果时，才考虑清除除法结果有效标志
                div_result_we <= 1'b0;
            end
        end
    end

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
    wire div_op_start_cond = is_div_op && !div_busy_i && !div_result_we;
    wire div_busy_cond = !is_div_op && div_busy_i;

    // 除法启动控制逻辑 - 只在需要启动新的除法操作时为高，并在中断时禁止启动
    assign div_start_o = (int_assert_i == `INT_ASSERT) ? 1'b0 : div_op_start_cond;

    // 乘法启动控制逻辑 - 条件定义
    wire mul_int_cond = int_assert_i;
    wire mul_op_busy_cond = is_mul_op && mul_busy_i;
    wire mul_op_ready_cond = is_mul_op && !mul_busy_i;
    wire mul_op_start_cond = is_mul_op && !mul_busy_i && !mul_result_we;
    wire mul_busy_cond = !is_mul_op && mul_busy_i;

    // 乘法启动控制逻辑 - 只在需要启动新的乘法操作时为高，并在中断时禁止启动
    assign mul_start_o = (int_assert_i == `INT_ASSERT) ? 1'b0 : mul_op_start_cond;

    // 条件信号定义 - 用于流水线保持逻辑
    wire hold_mul_cond = is_mul_op && (mul_busy_i || mul_result_we);
    wire hold_div_cond = is_div_op && (div_busy_i || div_result_we);
    wire hold_result_pending = div_result_we || mul_result_we; // 增加结果等待写回的保持条件

    // 流水线保持控制逻辑
    assign muldiv_hold_flag_o = hold_mul_cond | hold_div_cond;

    // 条件信号定义
    wire is_mul_req = is_mul_op;
    wire mul_not_busy = !mul_busy_i;

    wire is_div_req = is_div_op;
    wire div_not_busy = !div_busy_i;

    // 跳转条件
    wire jump_mul_cond = is_mul_req & mul_not_busy;
    wire jump_div_cond = is_div_req & div_not_busy;

    // 跳转控制逻辑
    assign muldiv_jump_flag_o = jump_mul_cond | jump_div_cond;

    // 选择信号定义 - 现在基于内部状态寄存器，不依赖外部输入
    wire sel_div = div_result_we;
    wire sel_mul = mul_result_we;

    // 结果写回数据和地址选择逻辑 - 使用保存的结果和寄存器地址
    always @(*) begin
        if (sel_mul) begin
            reg_wdata_o = saved_mul_result;
            reg_waddr_o = saved_mul_waddr;
            commit_id_o = saved_mul_commit_id;
        end else if (sel_div) begin
            reg_wdata_o = saved_div_result;
            reg_waddr_o = saved_div_waddr;
            commit_id_o = saved_div_commit_id;
        end else begin
            reg_wdata_o = 0;
            reg_waddr_o = 0;
            commit_id_o = 0;
        end
    end

    // 结果写回使能控制逻辑
    assign reg_we_o = (sel_mul | sel_div);

    // 注意：乘法结果有更高优先级，实现在结果选择逻辑中

endmodule
