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
    input wire [`INST_DATA_WIDTH-1:0] inst_i,            // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 指令地址
    input wire                        is_pred_branch_i,  // 添加预测分支指令标志输入
    input wire                        inst_valid_i,      // 新增：指令有效输入

    // from ctrl
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i,  // 流水线暂停标志

    // to csr reg
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // 读CSR寄存器地址

    // to ex
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,  // 指令地址
    output wire reg_we_o,  // 写通用寄存器标志
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,  // 写通用寄存器地址
    output wire [`REG_ADDR_WIDTH-1:0] reg1_raddr_o,  // 读通用寄存器1地址(传给EX)
    output wire [`REG_ADDR_WIDTH-1:0] reg2_raddr_o,  // 读通用寄存器2地址(传给EX)
    output wire csr_we_o,  // 写CSR寄存器标志
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,  // 写CSR寄存器地址
    output wire [31:0] dec_imm_o,  // 立即数
    output wire [`DECINFO_WIDTH-1:0] dec_info_bus_o,  // 译码信息总线
    output wire is_pred_branch_o,  // 添加预测分支指令标志输出
    output wire inst_valid_o,  // 新增：指令有效输出
    output wire illegal_inst_o,  // 新增：非法指令输出
    output wire [`INST_DATA_WIDTH-1:0] inst_o,  // 新增：指令内容输出
    output wire rs1_re_o,  // 新增：rs1寄存器是否需要访问
    output wire rs2_re_o,  // 新增：rs2寄存器是否需要
    output wire [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus_o  // 新增：ex单元类型输出
);

    // 内部连线，连接id和id_pipe
    wire [  `INST_ADDR_WIDTH-1:0] id_inst_addr;
    wire                          id_reg_we;
    wire [   `REG_ADDR_WIDTH-1:0] id_reg_waddr;
    wire [   `REG_ADDR_WIDTH-1:0] id_reg1_raddr;
    wire [   `REG_ADDR_WIDTH-1:0] id_reg2_raddr;
    wire                          id_csr_we;
    wire [   `BUS_ADDR_WIDTH-1:0] id_csr_waddr;
    wire [   `BUS_ADDR_WIDTH-1:0] id_csr_raddr;  // CSR读地址
    wire [                  31:0] id_dec_imm;
    wire [    `DECINFO_WIDTH-1:0] id_dec_info_bus;
    wire                          id_illegal_inst;  // 新增：非法指令信号
    // 新增rs1_re/rs2_re信号连线
    wire                          id_rs1_re;
    wire                          id_rs2_re;
    wire                          id_pipe_rs1_re;
    wire                          id_pipe_rs2_re;
    wire [`EX_INFO_BUS_WIDTH-1:0] id_ex_info_bus;  // 新增

    // 输出最终rs1_re/rs2_re信号
    assign rs1_re_o = id_pipe_rs1_re;
    assign rs2_re_o = id_pipe_rs2_re;

    // 实例化id模块
    idu_decode u_idu_decode (
        .rst_n(rst_n),

        // from if_id
        .inst_i      (inst_i),
        .inst_addr_i (inst_addr_i),
        .inst_valid_i(inst_valid_i), // 新增：指令有效输入

        // to regs
        .reg1_raddr_o(id_reg1_raddr),
        .reg2_raddr_o(id_reg2_raddr),
        // 新增
        .rs1_re_o    (id_rs1_re),
        .rs2_re_o    (id_rs2_re),

        // to csr reg
        .csr_raddr_o(id_csr_raddr),

        // to id_ex
        .dec_imm_o     (id_dec_imm),
        .dec_info_bus_o(id_dec_info_bus),
        .inst_addr_o   (id_inst_addr),
        .reg_we_o      (id_reg_we),
        .reg_waddr_o   (id_reg_waddr),
        .csr_we_o      (id_csr_we),
        .csr_waddr_o   (id_csr_waddr),
        .illegal_inst_o(id_illegal_inst),  // 输出非法指令信号
        .ex_info_bus_o (id_ex_info_bus)    // 新增
    );


    idu_id_pipe u_idu_id_pipe (
        .clk  (clk),
        .rst_n(rst_n),

        // from id
        .inst_i          (inst_i),            // 新增：指令内容输入
        .inst_addr_i     (id_inst_addr),
        .reg_we_i        (id_reg_we),
        .reg_waddr_i     (id_reg_waddr),
        .reg1_raddr_i    (id_reg1_raddr),
        .reg2_raddr_i    (id_reg2_raddr),
        // 新增
        .rs1_re          (id_rs1_re),
        .rs2_re          (id_rs2_re),
        .csr_we_i        (id_csr_we),
        .csr_waddr_i     (id_csr_waddr),
        .csr_raddr_i     (id_csr_raddr),
        .dec_info_bus_i  (id_dec_info_bus),
        .dec_imm_i       (id_dec_imm),
        .is_pred_branch_i(is_pred_branch_i),  // 添加预测分支信号输入
        .inst_valid_i    (inst_valid_i),      // 新增：指令有效输入
        .illegal_inst_i  (id_illegal_inst),   // 新增：非法指令输入
        .ex_info_bus_i   (id_ex_info_bus),    // 新增

        // from ctrl
        .stall_flag_i(stall_flag_i),

        // to ex
        .inst_addr_o     (inst_addr_o),
        .reg_we_o        (reg_we_o),
        .reg_waddr_o     (reg_waddr_o),
        .reg1_raddr_o    (reg1_raddr_o),
        .reg2_raddr_o    (reg2_raddr_o),
        .csr_we_o        (csr_we_o),
        .csr_waddr_o     (csr_waddr_o),
        .csr_raddr_o     (csr_raddr_o),
        .dec_imm_o       (dec_imm_o),
        .dec_info_bus_o  (dec_info_bus_o),
        .is_pred_branch_o(is_pred_branch_o),  // 添加预测分支信号输出
        .inst_valid_o    (inst_valid_o),      // 新增：指令有效输出
        .illegal_inst_o  (illegal_inst_o),    // 新增：非法指令输出
        .inst_o          (inst_o),            // 新增：指令内容输出
        .rs1_re_o        (id_pipe_rs1_re),    // 新增：rs1寄存器是否需要访问
        .rs2_re_o        (id_pipe_rs2_re),    // 新增：rs2寄存器是否需要访问
        .ex_info_bus_o   (ex_info_bus_o)      // 新增
    );

endmodule
