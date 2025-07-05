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

// 指令解码单元顶层模块
// 整合id和id_ex模块
module idu (
    input wire clk,
    input wire rst_n,

    // from if_id
    input wire [`INST_DATA_WIDTH-1:0] inst_i,      // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i, // 指令地址
    input wire                        is_pred_branch_i, // 添加预测分支指令标志输入

    // from ctrl
    input wire [   `CU_BUS_WIDTH-1:0] stall_flag_i,  // 流水线暂停标志

    // to csr reg
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // 读CSR寄存器地址

    // to ex
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,    // 指令地址
    output wire                        reg_we_o,       // 写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,    // 写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_o,   // 读通用寄存器1地址(传给EX)
    output wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_o,   // 读通用寄存器2地址(传给EX)
    output wire                        csr_we_o,       // 写CSR寄存器标志
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,    // 写CSR寄存器地址
    output wire [                31:0] dec_imm_o,      // 立即数
    output wire [  `DECINFO_WIDTH-1:0] dec_info_bus_o, // 译码信息总线
    output wire                        is_pred_branch_o // 添加预测分支指令标志输出
);

    // 内部连线，连接id和id_pipe
    wire [`INST_ADDR_WIDTH-1:0] id_inst_addr;
    wire                        id_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg1_raddr;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg2_raddr;
    wire                        id_csr_we;
    wire [ `BUS_ADDR_WIDTH-1:0] id_csr_waddr;
    wire [ `BUS_ADDR_WIDTH-1:0] id_csr_raddr;  // CSR读地址
    wire [                31:0] id_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] id_dec_info_bus;

    // 实例化id模块
    idu_decode u_idu_decode (
        .rst_n(rst_n),

        // from if_id
        .inst_i     (inst_i),
        .inst_addr_i(inst_addr_i),

        // to regs
        .reg1_raddr_o(id_reg1_raddr),
        .reg2_raddr_o(id_reg2_raddr),

        // to csr reg
        .csr_raddr_o(id_csr_raddr),

        // to id_ex
        .dec_imm_o     (id_dec_imm),
        .dec_info_bus_o(id_dec_info_bus),
        .inst_addr_o   (id_inst_addr),
        .reg_we_o      (id_reg_we),
        .reg_waddr_o   (id_reg_waddr),
        .csr_we_o      (id_csr_we),
        .csr_waddr_o   (id_csr_waddr)
    );

    // 实例化idu_id_pipe模块 - 添加预测分支信号
    idu_id_pipe u_idu_id_pipe (
        .clk  (clk),
        .rst_n(rst_n),

        // from id
        .inst_addr_i   (id_inst_addr),
        .reg_we_i      (id_reg_we),
        .reg_waddr_i   (id_reg_waddr),
        .reg1_raddr_i  (id_reg1_raddr),
        .reg2_raddr_i  (id_reg2_raddr),
        .csr_we_i      (id_csr_we),
        .csr_waddr_i   (id_csr_waddr),
        .csr_raddr_i   (id_csr_raddr),
        .dec_info_bus_i(id_dec_info_bus),
        .dec_imm_i     (id_dec_imm),
        .is_pred_branch_i(is_pred_branch_i),  // 添加预测分支信号输入

        // from ctrl
        .stall_flag_i(stall_flag_i),

        // to ex
        .inst_addr_o   (inst_addr_o),
        .reg_we_o      (reg_we_o),
        .reg_waddr_o   (reg_waddr_o),
        .reg1_raddr_o  (reg1_raddr_o),
        .reg2_raddr_o  (reg2_raddr_o),
        .csr_we_o      (csr_we_o),
        .csr_waddr_o   (csr_waddr_o),
        .csr_raddr_o   (csr_raddr_o),
        .dec_imm_o     (dec_imm_o),
        .dec_info_bus_o(dec_info_bus_o),
        .is_pred_branch_o(is_pred_branch_o)  // 添加预测分支信号输出
    );

endmodule
