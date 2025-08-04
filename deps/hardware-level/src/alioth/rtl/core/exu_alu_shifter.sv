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

// ALU移位器子模块 - 负责移位和位运算操作
module exu_alu_shifter (
    // 操作数输入
    input wire [31:0] op1_i,
    input wire [31:0] op2_i,
    
    // 操作类型
    input wire op_sll_i,
    input wire op_srl_i,
    input wire op_sra_i,
    input wire op_xor_i,
    input wire op_or_i,
    input wire op_and_i,
    
    // 输出
    output wire [31:0] sll_result_o,
    output wire [31:0] srl_result_o,
    output wire [31:0] sra_result_o,
    output wire [31:0] xor_result_o,
    output wire [31:0] or_result_o,
    output wire [31:0] and_result_o
);

    // 移位操作统一处理
    wire        op_shift = op_sll_i | op_srl_i | op_sra_i;
    wire [31:0] shifter_in1;
    wire [ 4:0] shifter_in2;
    wire [31:0] shifter_res;

    // 为右移操作翻转输入位
    assign shifter_in1 = {32{op_shift}} & ((op_sra_i | op_srl_i) ? {  // 输入位反转
        op1_i[00],op1_i[01],op1_i[02],op1_i[03],
        op1_i[04],op1_i[05],op1_i[06],op1_i[07],
        op1_i[08],op1_i[09],op1_i[10],op1_i[11],
        op1_i[12],op1_i[13],op1_i[14],op1_i[15],
        op1_i[16],op1_i[17],op1_i[18],op1_i[19],
        op1_i[20],op1_i[21],op1_i[22],op1_i[23],
        op1_i[24],op1_i[25],op1_i[26],op1_i[27],
        op1_i[28],op1_i[29],op1_i[30],op1_i[31]
    } : op1_i);

    assign shifter_in2 = {5{op_shift}} & op2_i[4:0];

    // 执行左移操作
    assign shifter_res = (shifter_in1 << shifter_in2);

    // 左移结果
    wire [31:0] sll_res = shifter_res;

    // 逻辑右移结果 - 通过反转左移结果
    wire [31:0] srl_res = {
        shifter_res[00], shifter_res[01], shifter_res[02], shifter_res[03],
        shifter_res[04], shifter_res[05], shifter_res[06], shifter_res[07],
        shifter_res[08], shifter_res[09], shifter_res[10], shifter_res[11],
        shifter_res[12], shifter_res[13], shifter_res[14], shifter_res[15],
        shifter_res[16], shifter_res[17], shifter_res[18], shifter_res[19],
        shifter_res[20], shifter_res[21], shifter_res[22], shifter_res[23],
        shifter_res[24], shifter_res[25], shifter_res[26], shifter_res[27],
        shifter_res[28], shifter_res[29], shifter_res[30], shifter_res[31]
    };

    // 算术右移结果 - 在逻辑右移基础上处理符号位
    wire [31:0] shift_mask = ~(32'hffffffff >> shifter_in2);
    wire [31:0] sra_res = (srl_res & (~shift_mask)) | ({32{op1_i[31]}} & shift_mask);

    // 位运算
    wire [31:0] xor_res = {32{op_xor_i}} & (op1_i ^ op2_i);
    wire [31:0] or_res = {32{op_or_i}} & (op1_i | op2_i);
    wire [31:0] and_res = {32{op_and_i}} & (op1_i & op2_i);

    // 输出分配
    assign sll_result_o = sll_res;
    assign srl_result_o = srl_res;
    assign sra_result_o = sra_res;
    assign xor_result_o = xor_res;
    assign or_result_o = or_res;
    assign and_result_o = and_res;

endmodule
