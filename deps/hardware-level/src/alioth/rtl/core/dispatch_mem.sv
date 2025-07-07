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

module dispatch_mem (
    input wire rst_n, // 复位信号，低电平有效

    // 输入译码信息总线和立即数
    input wire [              31:0] dec_imm_i,
    input wire [              31:0] dec_pc_i,

    // 寄存器读数据
    input wire [31:0] rs1_rdata_i,               // 寄存器1读数据
    input wire [31:0] rs2_rdata_i,               // 寄存器2读数据
    input wire op_muldiv,                  // 是否为MULDIV操作
    input wire op_bjp,                     // 是否为BJP操作
    input wire op_alu,                     // 是否为ALU操作
    input wire op_mem,                     // 是否为MEM操作
    input wire op_csr,                     // 是否为CSR操作

    // ALU操作数计算中间信号输入
    input wire alu_op1_pc_i,
    input wire alu_op1_zero_i,
    input wire alu_op2_imm_i,
    input wire bjp_op_jump_i,
    input wire bjp_op1_rs1_i,              // BJP操作数1是否使用rs1寄存器
    input wire sys_op_fence_i,              // 系统操作是否为FENCE指
    input wire csr_rs1imm_i,                // CSR操作数是否使用立即数

    // ALU操作数输出
    output wire [31:0] alu_op1_o,
    output wire [31:0] alu_op2_o,

    output wire [31:0] bjp_op1_o,
    output wire [31:0] bjp_op2_o,
    output wire [31:0] muldiv_op1_o,
    output wire [31:0] muldiv_op2_o,
    output wire [31:0] bjp_jump_op1_o,
    output wire [31:0] bjp_jump_op2_o,
    output wire [31:0] csr_op1_o,            // CSR操作数输出
    output wire [31:0] mem_op1_o,          // MEM操作数1
    output wire [31:0] mem_op2_o,          // MEM操作数2
    output wire [31:0] mem_rs2_data_o       // MEM操作数2 (rs2寄存器值)

);
    // MULDIV op1
    assign muldiv_op1_o        = op_muldiv ? rs1_rdata_i : 32'h0;  // rs1寄存器值
    // MULDIV op2
    assign muldiv_op2_o        = op_muldiv ? rs2_rdata_i : 32'h0;  // rs2寄存器值
    // BJP 比较操作数
    assign bjp_op1_o      = op_bjp ? rs1_rdata_i : dec_pc_i;
    assign bjp_op2_o      = op_bjp ? rs2_rdata_i : 32'h0; 
    
    // BJP 跳转操作数定义
    wire [31:0] bjp_op1 = bjp_op1_rs1_i ? rs1_rdata_i : dec_pc_i;
    wire [31:0] bjp_op2 = dec_imm_i;
    
    assign bjp_jump_op1_o = (sys_op_fence_i | op_bjp) ? bjp_op1 : 32'h0;
    assign bjp_jump_op2_o = (sys_op_fence_i) ? 32'h4 : op_bjp ? bjp_op2 : 32'h0;

    // ALU操作数计算逻辑
    wire [31:0] alu_op1 = (alu_op1_pc_i | bjp_op_jump_i) ? dec_pc_i : alu_op1_zero_i ? 32'h0 : rs1_rdata_i;
    assign alu_op1_o = (op_alu | bjp_op_jump_i) ? alu_op1 : 32'h0;  // ALU指令的操作数1

    wire [31:0] alu_op2 = alu_op2_imm_i ? dec_imm_i : rs2_rdata_i;
    assign alu_op2_o = bjp_op_jump_i ? 32'h4 : op_alu ? alu_op2 : 32'h0;

    //csr
    wire [31:0] csr_rs1 = csr_rs1imm_i ? dec_imm_i : rs1_rdata_i;
    assign csr_op1_o   = op_csr ? csr_rs1 : 32'h0;


    //mem
    assign mem_op1_o      = op_mem ? rs1_rdata_i : 32'h0;  // 基地址 (rs1)
    assign mem_op2_o      = op_mem ? dec_imm_i : 32'h0;  // 偏移量 (立即数)
    assign mem_rs2_data_o = op_mem ? rs2_rdata_i : 32'h0;  // 存储指令的数据 (rs2)

endmodule