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
    input wire        clk,
    input wire        rst_n,
    input wire        req_bjp_i,
    input wire [31:0] bjp_op1_i,
    input wire [31:0] bjp_op2_i,
    input wire [31:0] bjp_jump_op1_i,
    input wire [31:0] bjp_jump_op2_i,
    input wire        bjp_op_jal_i,      // JAL指令标志
    input wire        bjp_op_beq_i,
    input wire        bjp_op_bne_i,
    input wire        bjp_op_blt_i,
    input wire        bjp_op_bltu_i,
    input wire        bjp_op_bge_i,
    input wire        bjp_op_bgeu_i,
    input wire        bjp_op_jalr_i,     // JALR指令标志
    input wire        is_pred_branch_i,  // 前级是否进行了分支预测
    input wire        exu_stall_i,       // 增加stall输入
    input wire        sys_op_fence_i,    // FENCE指令
    // 中断信号
    input wire        int_assert_i,

    // 跳转输出
    output wire                        jump_ready_o,       // 跳转准备好信号
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,
    output wire                        misaligned_fetch_o
);
    // 内部信号
    wire        jump_flag;  // 跳转标志
    wire        jump_flag_nxt;
    wire        op1_eq_op2;
    wire        op1_ge_op2_signed;
    wire        op1_ge_op2_unsigned;
    wire [31:0] adder_op2;
    wire [31:0] adder_result;
    wire [31:0] jalr_target_addr;
    wire        branch_cond;

    // 比较结果
    assign op1_eq_op2          = (bjp_op1_i == bjp_op2_i);
    assign op1_ge_op2_signed   = $signed(bjp_op1_i) >= $signed(bjp_op2_i);
    assign op1_ge_op2_unsigned = bjp_op1_i >= bjp_op2_i;

    // 预测回退条件：当预测分支但实际不需要跳转
    wire pred_rollback = is_pred_branch_i & req_bjp_i & ~branch_cond;

    // 复用加法器：根据是否需要回退选择加法的第二个操作数
    assign adder_op2 = pred_rollback ? 32'h4 : bjp_jump_op2_i;
    assign adder_result = bjp_jump_op1_i + adder_op2;
    assign jalr_target_addr = adder_result & ~32'h1;  // JALR目标地址需要清除最低位

    // 简化跳转条件信号判断
    assign branch_cond = req_bjp_i & (
        (bjp_op_beq_i  &  op1_eq_op2) |
        (bjp_op_bne_i  & ~op1_eq_op2) |
        (bjp_op_blt_i  & ~op1_ge_op2_signed) |
        (bjp_op_bge_i  &  op1_ge_op2_signed) |
        (bjp_op_bltu_i & ~op1_ge_op2_unsigned) |
        (bjp_op_bgeu_i &  op1_ge_op2_unsigned) |
        bjp_op_jalr_i
    );

    assign jump_flag = (branch_cond & ~is_pred_branch_i) | sys_op_fence_i | pred_rollback;

    // 简化跳转标志判断，增加预测回退条件
    assign jump_flag_nxt = jump_flag & ~misaligned_fetch_o & ~int_assert_i;  // 跳转标志输出，排除预测回退情况，并屏蔽中断

    // 简化跳转地址选择逻辑
    wire [`INST_ADDR_WIDTH-1:0] jump_addr_nxt;  // 新跳转地址组合逻辑
    assign jump_addr_nxt      = (bjp_op_jalr_i ? jalr_target_addr : adder_result);

    // 非对齐跳转判断（跳转地址低2位非0）
    assign misaligned_fetch_o = ((jump_addr_nxt[1:0] != 2'b00) && (jump_flag_nxt || bjp_op_jal_i));

    // 跳转标志和地址寄存一拍
    reg                        jump_flag_r;
    reg [`INST_ADDR_WIDTH-1:0] jump_addr_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            jump_flag_r <= 1'b0;
            jump_addr_r <= {`INST_ADDR_WIDTH{1'b0}};
        end else if (!exu_stall_i) begin
            jump_flag_r <= jump_flag_nxt;
            jump_addr_r <= jump_addr_nxt;
        end else begin
            jump_flag_r <= 0;
        end
    end

    assign jump_ready_o = jump_flag_nxt;
    assign jump_flag_o = jump_flag_r;
    assign jump_addr_o = (bjp_op_jal_i & ~jump_flag_r) ? jump_addr_nxt : jump_addr_r;  // JAL指令直接使用计算结果，其他指令使用寄存的跳转地址

endmodule
