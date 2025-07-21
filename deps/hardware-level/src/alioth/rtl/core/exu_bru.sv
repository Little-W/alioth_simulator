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


module exu_bru (
    input wire        rst_n,
    input wire        req_bjp_i,
    input wire [31:0] bjp_op1_i,
    input wire [31:0] bjp_op2_i,
    input wire [31:0] bjp_jump_op1_i,
    input wire [31:0] bjp_jump_op2_i,
    input wire        bjp_op_jump_i,    // JAL/JALR指令
    input wire        bjp_op_beq_i,
    input wire        bjp_op_bne_i,
    input wire        bjp_op_blt_i,
    input wire        bjp_op_bltu_i,
    input wire        bjp_op_bge_i,
    input wire        bjp_op_bgeu_i,
    input wire        bjp_op_jalr_i,    // JALR指令标志
    input wire        is_pred_branch_i, // 前级是否进行了分支预测

    input wire                        sys_op_fence_i,  // FENCE指令
    // 中断信号
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 跳转输出
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,
    // 新增JALR执行信号
    output wire                        jalr_executed_o,
    // 新增：非对齐跳转信号
    output wire                        misaligned_fetch_o
);
    // 内部信号
    wire        jump_flag;
    wire        op1_eq_op2;
    wire        op1_ge_op2_signed;
    wire        op1_ge_op2_unsigned;
    wire [31:0] adder_op2;
    wire [31:0] adder_result;
    wire        is_op_jal;
    wire [31:0] jalr_target_addr;

    assign is_op_jal           = bjp_op_jump_i & ~bjp_op_jalr_i;

    // 比较结果
    assign op1_eq_op2          = (bjp_op1_i == bjp_op2_i);
    assign op1_ge_op2_signed   = $signed(bjp_op1_i) >= $signed(bjp_op2_i);
    assign op1_ge_op2_unsigned = bjp_op1_i >= bjp_op2_i;

    // 预测回退条件：当预测分支但实际不需要跳转
    wire pred_rollback = is_pred_branch_i & req_bjp_i & ~branch_cond;

    // 复用加法器：根据是否需要回退选择加法的第二个操作数
    assign adder_op2        = pred_rollback ? 32'h4 : bjp_jump_op2_i;
    assign adder_result     = bjp_jump_op1_i + adder_op2;
    assign jalr_target_addr = adder_result & ~32'h1;  // JALR目标地址需要清除最低位

    // 简化跳转条件信号判断
    wire branch_cond = req_bjp_i & (
        (bjp_op_beq_i  &  op1_eq_op2) |
        (bjp_op_bne_i  & ~op1_eq_op2) |
        (bjp_op_blt_i  & ~op1_ge_op2_signed) |
        (bjp_op_bge_i  &  op1_ge_op2_signed) |
        (bjp_op_bltu_i & ~op1_ge_op2_unsigned) |
        (bjp_op_bgeu_i &  op1_ge_op2_unsigned) |
        bjp_op_jalr_i
    );

    // JALR执行信号
    assign jalr_executed_o = req_bjp_i & bjp_op_jalr_i;

    // 简化跳转标志判断，增加预测回退条件
    assign jump_flag = int_assert_i | (branch_cond & ~is_pred_branch_i) | sys_op_fence_i | pred_rollback;

    // 简化跳转地址选择逻辑
    assign jump_addr_o = int_assert_i ? int_addr_i :
        (bjp_op_jalr_i ? jalr_target_addr : adder_result);

    // 非对齐跳转判断（跳转地址低2位非0）
    assign misaligned_fetch_o = ((jump_addr_o[1:0] != 2'b00) && (jump_flag || is_op_jal));

    assign jump_flag_o = jump_flag & ~misaligned_fetch_o;  // 跳转标志输出，排除预测回退情况

endmodule
