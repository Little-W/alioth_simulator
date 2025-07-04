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
    input wire                        clk,
    input wire                        rst_n,
    input wire                        req_bjp_i,
    input wire                        bjp_op_jal_i,      // JAL指令标志
    input wire                        bjp_op_beq_i,
    input wire                        bjp_op_bne_i,
    input wire                        bjp_op_blt_i,
    input wire                        bjp_op_bltu_i,
    input wire                        bjp_op_bge_i,
    input wire                        bjp_op_bgeu_i,
    input wire                        bjp_op_jalr_i,     // JALR指令标志
    input wire                        is_pred_branch_i,  // 前级是否进行了分支预测
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 当前指令PC

    input wire [31:0] bjp_adder_result_i,
    input wire [31:0] bjp_next_pc_i,
    input wire        op1_eq_op2_i,
    input wire        op1_ge_op2_signed_i,
    input wire        op1_ge_op2_unsigned_i,

    input wire                        sys_op_fence_i,  // FENCE指令
    // 中断信号
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 跳转输出
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,

    // BHT回写接口
    output wire                        update_valid_o,  // 需要更新BHT
    output wire [`INST_ADDR_WIDTH-1:0] update_pc_o,     // 被更新指令PC
    output wire                        real_taken_o,    // 分支实际结果

    // 新增：非对齐跳转信号
    output wire misaligned_fetch_o
);
    // 内部信号
    wire        jump_flag;
    wire [31:0] jalr_target_addr;
    wire        branch_cond;

    // 使用dispatch_pipe传递下来的比较结果
    wire        op1_eq_op2 = op1_eq_op2_i;
    wire        op1_ge_op2_signed = op1_ge_op2_signed_i;
    wire        op1_ge_op2_unsigned = op1_ge_op2_unsigned_i;

    // 预测回退条件：当预测分支但实际不需要跳转
    assign branch_cond = req_bjp_i & (
        (bjp_op_beq_i  &  op1_eq_op2) |
        (bjp_op_bne_i  & ~op1_eq_op2) |
        (bjp_op_blt_i  & ~op1_ge_op2_signed) |
        (bjp_op_bge_i  &  op1_ge_op2_signed) |
        (bjp_op_bltu_i & ~op1_ge_op2_unsigned) |
        (bjp_op_bgeu_i &  op1_ge_op2_unsigned) |
        bjp_op_jalr_i
    );
    wire pred_rollback = is_pred_branch_i & req_bjp_i & ~branch_cond;

    // JALR目标地址需要清除最低位
    assign jalr_target_addr = (bjp_adder_result_i & ~32'h1);

    // 跳转标志判断，增加预测回退条件
    assign jump_flag = (branch_cond & ~is_pred_branch_i) | sys_op_fence_i | pred_rollback;

    // 跳转地址选择逻辑
    assign jump_addr_o = (sys_op_fence_i || pred_rollback) ? bjp_next_pc_i :
                         (bjp_op_jalr_i ? jalr_target_addr : bjp_adder_result_i);

    // BHT回写接口实现
    // 仅当处理条件分支指令时更新BHT
    wire is_cond_branch = req_bjp_i & (bjp_op_beq_i | bjp_op_bne_i | bjp_op_blt_i | 
                          bjp_op_bltu_i | bjp_op_bge_i | bjp_op_bgeu_i);

    wire update_valid_d = is_cond_branch & ~int_assert_i;  // 当前是条件分支且非中断
    wire [`INST_ADDR_WIDTH-1:0] update_pc_d = inst_addr_i;  // 当前指令的PC
    wire real_taken_d = branch_cond & ~bjp_op_jalr_i;  // 实际分支结果（排除JALR）

    reg update_valid_q;
    reg [`INST_ADDR_WIDTH-1:0] update_pc_q;
    reg real_taken_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            update_valid_q <= 1'b0;
            update_pc_q    <= {`INST_ADDR_WIDTH{1'b0}};
            real_taken_q   <= 1'b0;
        end else begin
            update_valid_q <= update_valid_d;
            update_pc_q    <= update_pc_d;
            real_taken_q   <= real_taken_d;
        end
    end

    assign update_valid_o = update_valid_q;
    assign update_pc_o    = update_pc_q;
    assign real_taken_o   = real_taken_q;

    // 非对齐跳转判断（跳转地址低2位非0）
    assign misaligned_fetch_o = ((jump_addr_o[1:0] != 2'b00) && (jump_flag || bjp_op_jal_i));

    assign jump_flag_o = jump_flag & ~misaligned_fetch_o & ~int_assert_i;  // 跳转标志输出，排除预测回退情况，并屏蔽中断

endmodule
