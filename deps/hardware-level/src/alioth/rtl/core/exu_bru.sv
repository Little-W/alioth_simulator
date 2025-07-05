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
    input wire                        rst_n,
    input wire                        req_bjp_i,
    input wire [                31:0] bjp_op1_i,
    input wire [                31:0] bjp_op2_i,
    input wire [                31:0] bjp_jump_op1_i,
    input wire [                31:0] bjp_jump_op2_i,
    input wire                        bjp_op_jump_i,     // JAL/JALR指令
    input wire                        bjp_op_beq_i,
    input wire                        bjp_op_bne_i,
    input wire                        bjp_op_blt_i,
    input wire                        bjp_op_bltu_i,
    input wire                        bjp_op_bge_i,
    input wire                        bjp_op_bgeu_i,
    input wire                        bjp_op_jalr_i,     // JALR指令标志
    input wire                        is_pred_branch_i,  // 前级是否进行了分支预测
    input wire                        is_pred_jalr_i,    // 添加预测JALR指令标志输入
    input wire [`INST_ADDR_WIDTH-1:0] branch_addr_i,     // 添加预测分支地址输入
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 添加当前指令地址输入

    input wire                        sys_op_fence_i,  // FENCE指令
    // 中断信号
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 跳转输出
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,

    // BTB更新输出
    output wire                        btb_update_o,        // BTB更新使能
    output wire [`INST_ADDR_WIDTH-1:0] btb_update_pc_o,     // 需要更新的PC
    output wire [`INST_ADDR_WIDTH-1:0] btb_update_target_o  // 更新的目标地址
);
    // 内部信号
    wire        op1_eq_op2;
    wire        op1_ge_op2_signed;
    wire        op1_ge_op2_unsigned;
    wire [31:0] adder_op2;
    wire [31:0] adder_result;

    // 比较结果
    assign op1_eq_op2          = (bjp_op1_i == bjp_op2_i);
    assign op1_ge_op2_signed   = $signed(bjp_op1_i) >= $signed(bjp_op2_i);
    assign op1_ge_op2_unsigned = bjp_op1_i >= bjp_op2_i;

    // 预测回退条件：当预测分支但实际不需要跳转
    wire pred_rollback = is_pred_branch_i & req_bjp_i & ~branch_cond;

    // 新增：地址预测错误条件，当JALR指令预测地址与实际计算地址不匹配
    wire addr_mismatch = is_pred_jalr_i & (adder_result != branch_addr_i);

    // 复用加法器：根据是否需要回退选择加法的第二个操作数
    assign adder_op2    = pred_rollback ? 32'h4 : bjp_jump_op2_i;
    assign adder_result = bjp_jump_op1_i + adder_op2;

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

    // 修改跳转标志判断，增加地址不匹配条件
    assign jump_flag_o = int_assert_i | 
                        (branch_cond & ~is_pred_branch_i) | 
                        sys_op_fence_i | 
                        pred_rollback | 
                        addr_mismatch;

    // 简化跳转地址选择逻辑
    assign jump_addr_o = int_assert_i ? int_addr_i : adder_result;

    // BTB更新逻辑 - 针对JALR指令
    // 在以下情况更新BTB：
    // 1. 执行了JALR指令且它没有被预测(需要建立新的BTB条目)
    // 2. 执行了JALR指令且预测地址错误(需要更新已有的BTB条目)
    assign btb_update_o = rst_n & bjp_op_jalr_i & req_bjp_i & 
                          (!is_pred_jalr_i | (is_pred_jalr_i & addr_mismatch));

    // 将当前指令地址设为BTB更新源地址
    assign btb_update_pc_o = inst_addr_i;

    // 将计算出的JALR目标地址作为BTB更新目标地址
    assign btb_update_target_o = adder_result;

endmodule
