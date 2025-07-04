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

// 将译码结果向执行模块传递
module idu_id_pipe (

    input wire                        clk,
    input wire                        rst_n,
    // 输入
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,     // 指令地址
    input wire                        reg_we_i,        // 写通用寄存器标志
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,     // 写通用寄存器地址
    input wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_i,    // 读通用寄存器1地址
    input wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_i,    // 读通用寄存器2地址
    input wire                        csr_we_i,        // 写CSR寄存器标志
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,     // 写CSR寄存器地址
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_raddr_i,     // 读CSR寄存器地址
    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,

    input wire [   `CU_BUS_WIDTH-1:0] stall_flag_i,  // 流水线暂停标志
    input wire [`INST_ADDR_WIDTH-1:0] old_pc_i,      // 旧跳转地址
//    input wire                        branch_taken_i, // 分支预测结果

    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,    // 指令地址
    output wire                        reg_we_o,       // 写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,    // 写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_o,   // 读通用寄存器1地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_o,   // 读通用寄存器2地址
    output wire                        csr_we_o,       // 写CSR寄存器标志
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,    // 写CSR寄存器地址
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_raddr_o,    // 读CSR寄存器地址
    output wire [                31:0] dec_imm_o,      // 立即数
    output wire [  `DECINFO_WIDTH-1:0] dec_info_bus_o, // 译码信息总线
    output wire [`INST_ADDR_WIDTH-1:0] old_pc_o,       // 旧跳转地址
 //   output wire                        branch_taken_o  // 分支预测结果
);

    wire                        flush_en = stall_flag_i[`CU_FLUSH];// 流水线冲刷标志(是否加上分支预测错误标志？)
    wire                        stall_en = stall_flag_i[`CU_STALL];
    wire                        reg_update_en = ~stall_en;

    wire [`INST_ADDR_WIDTH-1:0] inst_addr_dnxt = flush_en ? `ZeroWord : inst_addr_i;
    wire [`INST_ADDR_WIDTH-1:0] inst_addr;
    gnrl_dfflr #(32) inst_addr_ff (
        clk,
        rst_n,
        reg_update_en,
        inst_addr_dnxt,
        inst_addr
    );
    assign inst_addr_o = inst_addr;

    wire reg_we_dnxt = flush_en ? `WriteDisable : reg_we_i;
    wire reg_we;
    gnrl_dfflr #(1) reg_we_ff (
        clk,
        rst_n,
        reg_update_en,
        reg_we_dnxt,
        reg_we
    );
    assign reg_we_o = reg_we;


    wire [`INST_ADDR_WIDTH-1:0] old_pc_dnxt = flush_en ? `ZeroWord : old_pc_i;
    wire [`INST_ADDR_WIDTH-1:0] old_pc;
    gnrl_dfflr #(32) old_pc_ff (
        clk,
        rst_n,
        reg_update_en,
        old_pc_dnxt,
        old_pc
    );
    assign old_pc_o = old_pc;

//   wire branch_taken_dnxt = flush_en ? `BranchNotTaken : branch_taken_i;
//   wire branch_taken;
//   gnrl_dfflr #(1) branch_taken_ff (
//        clk,
//       rst_n,
//       reg_update_en,
//       branch_taken_dnxt,
//        branch_taken
//    );
//   assign branch_taken_o = branch_taken;


    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_dnxt = flush_en ? `ZeroReg : reg_waddr_i;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr;
    gnrl_dfflr #(5) reg_waddr_ff (
        clk,
        rst_n,
        reg_update_en,
        reg_waddr_dnxt,
        reg_waddr
    );
    assign reg_waddr_o = reg_waddr;

    // 传递寄存器地址而非数据
    wire [`REG_ADDR_WIDTH-1:0] reg1_raddr_dnxt = flush_en ? `ZeroReg : reg1_raddr_i;
    wire [`REG_ADDR_WIDTH-1:0] reg1_raddr;
    gnrl_dfflr #(5) reg1_raddr_ff (
        clk,
        rst_n,
        reg_update_en,
        reg1_raddr_dnxt,
        reg1_raddr
    );
    assign reg1_raddr_o = reg1_raddr;

    wire [`REG_ADDR_WIDTH-1:0] reg2_raddr_dnxt = flush_en ? `ZeroReg : reg2_raddr_i;
    wire [`REG_ADDR_WIDTH-1:0] reg2_raddr;
    gnrl_dfflr #(5) reg2_raddr_ff (
        clk,
        rst_n,
        reg_update_en,
        reg2_raddr_dnxt,
        reg2_raddr
    );
    assign reg2_raddr_o = reg2_raddr;

    wire csr_we_dnxt = flush_en ? `WriteDisable : csr_we_i;
    wire csr_we;
    gnrl_dfflr #(1) csr_we_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_we_dnxt,
        csr_we
    );
    assign csr_we_o = csr_we;

    wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_dnxt = flush_en ? `ZeroWord : csr_waddr_i;
    wire [`BUS_ADDR_WIDTH-1:0] csr_waddr;
    gnrl_dfflr #(32) csr_waddr_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_waddr_dnxt,
        csr_waddr
    );
    assign csr_waddr_o = csr_waddr;

    // 传递CSR读地址
    wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_dnxt = flush_en ? `ZeroWord : csr_raddr_i;
    wire [`BUS_ADDR_WIDTH-1:0] csr_raddr;
    gnrl_dfflr #(32) csr_raddr_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_raddr_dnxt,
        csr_raddr
    );
    assign csr_raddr_o = csr_raddr;

    // 译码信息总线传递
    wire [`DECINFO_WIDTH-1:0] dec_info_bus_dnxt = flush_en ? `ZeroWord : dec_info_bus_i;
    wire [`DECINFO_WIDTH-1:0] dec_info_bus;
    gnrl_dfflr #(`DECINFO_WIDTH) dec_info_bus_ff (
        clk,
        rst_n,
        reg_update_en,
        dec_info_bus_dnxt,
        dec_info_bus
    );
    assign dec_info_bus_o = dec_info_bus;

    // 立即数传递
    wire [31:0] dec_imm_dnxt = flush_en ? `ZeroWord : dec_imm_i;
    wire [31:0] dec_imm;
    gnrl_dfflr #(32) dec_imm_ff (
        clk,
        rst_n,
        reg_update_en,
        dec_imm_dnxt,
        dec_imm
    );
    assign dec_imm_o = dec_imm;

endmodule
