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

// ALU加法器子模块 - 负责加减法、比较、地址计算等操作
module exu_alu_adder (
    // 操作数输入
    input wire [31:0] op1_i,
    input wire [31:0] op2_i,
    
    // 操作类型
    input wire op_add_i,
    input wire op_sub_i,
    input wire op_slt_i,
    input wire op_sltu_i,
    input wire op_auipc_i,
    
    // 输出
    output wire [31:0] add_result_o,
    output wire [31:0] sub_result_o,
    output wire [31:0] slt_result_o,
    output wire [31:0] sltu_result_o,
    output wire [31:0] auipc_result_o
);

    // 加法器输入选择
    wire [31:0] adder_in1;
    wire [31:0] adder_in2;
    wire        adder_cin;
    wire [32:0] adder_res;  // 33位，包含进位信息

    // 操作数选择 - 使用门控优化
    wire adder_op = op_add_i | op_sub_i | op_slt_i | op_sltu_i | op_auipc_i;
    
    assign adder_in1 = {32{adder_op}} & op1_i;
    assign adder_in2 = {32{adder_op}} & ((op_sub_i | op_slt_i | op_sltu_i) ? ~op2_i : op2_i);
    assign adder_cin = adder_op & (op_sub_i | op_slt_i | op_sltu_i);

    // 执行加法运算
    assign adder_res = {1'b0, adder_in1} + {1'b0, adder_in2} + {{32{1'b0}}, adder_cin};

    // 比较运算结果
    // 有符号比较结果: op1_i < op2_i
    wire op1_sign = op1_i[31];
    wire op2_sign = op2_i[31];
    wire signs_differ = op1_sign != op2_sign;
    
    // 当符号不同时，op1为负数则op1<op2
    // 当符号相同时，检查减法结果的符号位
    wire is_lt_signed = (op_slt_i) ? (signs_differ ? op1_sign : adder_res[31]) : 1'b0;
    
    // 无符号比较结果: op1_i < op2_i 
    // 对于无符号比较，当执行op1-op2时，如果op1<op2，则会产生借位
    // 借位等价于加法器进位输出为0（因为是33位加法器）
    wire is_lt_unsigned = (op_sltu_i) ? ~adder_res[32] : 1'b0;

    // 输出结果
    assign add_result_o = adder_res[31:0];
    assign sub_result_o = adder_res[31:0];
    assign auipc_result_o = adder_res[31:0];
    assign slt_result_o = {31'b0, is_lt_signed};
    assign sltu_result_o = {31'b0, is_lt_unsigned};

endmodule
