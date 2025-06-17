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
    input wire        bjp_op_jump_i,   // JAL/JALR指令
    input wire        bjp_op_beq_i,
    input wire        bjp_op_bne_i,
    input wire        bjp_op_blt_i,
    input wire        bjp_op_bltu_i,
    input wire        bjp_op_bge_i,
    input wire        bjp_op_bgeu_i,
    input wire        bjp_op_jalr_i,   // JALR指令标志

    input wire                        sys_op_fence_i,      // FENCE指令
    // 中断信号
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 跳转输出
    output wire                       jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o
);
    // 内部信号
    wire        op1_eq_op2;
    wire        op1_ge_op2_signed;
    wire        op1_ge_op2_unsigned;
    wire [31:0] op1_jump_add_op2_jump_res;

    // 比较结果
    assign op1_eq_op2                = (bjp_op1_i == bjp_op2_i);
    assign op1_ge_op2_signed         = $signed(bjp_op1_i) >= $signed(bjp_op2_i);
    assign op1_ge_op2_unsigned       = bjp_op1_i >= bjp_op2_i;

    // 计算跳转地址
    assign op1_jump_add_op2_jump_res = bjp_jump_op1_i + bjp_jump_op2_i;

    // 各种跳转条件信号
    wire int_jump        = (int_assert_i == `INT_ASSERT);
    wire jal_jump        = req_bjp_i & bjp_op_jump_i;
    wire jalr_jump       = req_bjp_i & bjp_op_jalr_i;
    wire beq_jump        = req_bjp_i & bjp_op_beq_i & op1_eq_op2;
    wire bne_jump        = req_bjp_i & bjp_op_bne_i & ~op1_eq_op2;
    wire blt_jump        = req_bjp_i & bjp_op_blt_i & ~op1_ge_op2_signed;
    wire bge_jump        = req_bjp_i & bjp_op_bge_i & op1_ge_op2_signed;
    wire bltu_jump       = req_bjp_i & bjp_op_bltu_i & ~op1_ge_op2_unsigned;
    wire bgeu_jump       = req_bjp_i & bjp_op_bgeu_i & op1_ge_op2_unsigned;
    wire fence_jump      = sys_op_fence_i;

    // 使用并行选择逻辑确定是否跳转
    assign jump_flag_o = int_jump | jal_jump | jalr_jump | beq_jump | 
                         bne_jump | blt_jump | bge_jump | bltu_jump | 
                         bgeu_jump | fence_jump;

    // 使用并行选择逻辑确定跳转地址
    assign jump_addr_o = ({`INST_ADDR_WIDTH{int_jump}} & int_addr_i) |
                         ({`INST_ADDR_WIDTH{jal_jump | jalr_jump | beq_jump | bne_jump | 
                                           blt_jump | bge_jump | bltu_jump | bgeu_jump | 
                                           fence_jump}} & op1_jump_add_op2_jump_res);

endmodule
