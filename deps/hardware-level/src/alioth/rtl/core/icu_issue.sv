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

//指令发射控制单元
module icu (
    input wire clk,
    input wire rst_n,

    // from idu
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i,
    input wire                        inst1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_i,
    input wire                        inst1_csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_waddr_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_raddr_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,

    // from idu - 第二路
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_waddr_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_raddr_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    
    // from hdu 控制信号
    input wire [1:0]                  issue_inst_i,
    
    // from control 控制信号
    input wire [`CU_BUS_WIDTH-1:0]   stall_flag_i,
    
    // to hdu 输出信号 - 直接透传输入信号
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_rd_addr,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_rs1_addr,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_rs2_addr,
    output wire                        inst1_rd_we,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_rd_addr,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_rs1_addr,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_rs2_addr,
    output wire                        inst2_rd_we,
    
    // 发射指令的完整decode信息
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,
    output wire                        inst1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_waddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_raddr_o,
    output wire                        inst1_csr_we_o,
    output wire [                31:0] inst1_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o,
    output wire                        inst1_is_pred_branch_o,
    
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,
    output wire                        inst2_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_waddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_raddr_o,
    output wire                        inst2_csr_we_o,
    output wire [                31:0] inst2_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o,
    output wire                        inst2_is_pred_branch_o
);



    // HDU接口信号 - 直接透传输入信号
    assign inst1_rd_addr = inst1_reg_waddr_i;
    assign inst1_rs1_addr = inst1_reg1_raddr_i;
    assign inst1_rs2_addr = inst1_reg2_raddr_i;
    assign inst1_rd_we = inst1_reg_we_i;
    
    assign inst2_rd_addr = inst2_reg_waddr_i;
    assign inst2_rs1_addr = inst2_reg1_raddr_i;
    assign inst2_rs2_addr = inst2_reg2_raddr_i;
    assign inst2_rd_we = inst2_reg_we_i;
    
    // 下一个时钟周期的指令信号 - flush时清零，否则等于输入
    wire [`INST_ADDR_WIDTH-1:0] nxt_inst1_addr = flush_en ? {`INST_ADDR_WIDTH{1'b0}} : inst1_addr_i;
    wire                        nxt_inst1_reg_we = flush_en ? 1'b0 : inst1_reg_we_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst1_reg_waddr = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : inst1_reg_waddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst1_reg1_raddr = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : inst1_reg1_raddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst1_reg2_raddr = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : inst1_reg2_raddr_i;
    wire [ `BUS_ADDR_WIDTH-1:0] nxt_inst1_csr_waddr = flush_en ? {`BUS_ADDR_WIDTH{1'b0}} : inst1_csr_waddr_i;
    wire [ `BUS_ADDR_WIDTH-1:0] nxt_inst1_csr_raddr = flush_en ? {`BUS_ADDR_WIDTH{1'b0}} : inst1_csr_raddr_i;
    wire                        nxt_inst1_csr_we = flush_en ? 1'b0 : inst1_csr_we_i;
    wire [                31:0] nxt_inst1_dec_imm = flush_en ? 32'b0 : inst1_dec_imm_i;
    wire [  `DECINFO_WIDTH-1:0] nxt_inst1_dec_info_bus = flush_en ? {`DECINFO_WIDTH{1'b0}} : inst1_dec_info_bus_i;
    wire                        nxt_inst1_is_pred_branch = flush_en ? 1'b0 : inst1_is_pred_branch_i;
    
    wire [`INST_ADDR_WIDTH-1:0] nxt_inst2_addr = flush_en ? {`INST_ADDR_WIDTH{1'b0}} : inst2_addr_i;
    wire                        nxt_inst2_reg_we = flush_en ? 1'b0 : inst2_reg_we_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst2_reg_waddr = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : inst2_reg_waddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst2_reg1_raddr = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : inst2_reg1_raddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst2_reg2_raddr = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : inst2_reg2_raddr_i;
    wire [ `BUS_ADDR_WIDTH-1:0] nxt_inst2_csr_waddr = flush_en ? {`BUS_ADDR_WIDTH{1'b0}} : inst2_csr_waddr_i;
    wire [ `BUS_ADDR_WIDTH-1:0] nxt_inst2_csr_raddr = flush_en ? {`BUS_ADDR_WIDTH{1'b0}} : inst2_csr_raddr_i;
    wire                        nxt_inst2_csr_we = flush_en ? 1'b0 : inst2_csr_we_i;
    wire [                31:0] nxt_inst2_dec_imm = flush_en ? 32'b0 : inst2_dec_imm_i;
    wire [  `DECINFO_WIDTH-1:0] nxt_inst2_dec_info_bus = flush_en ? {`DECINFO_WIDTH{1'b0}} : inst2_dec_info_bus_i;
    wire                        nxt_inst2_is_pred_branch = flush_en ? 1'b0 : inst2_is_pred_branch_i;
    
     // 控制信号解析
    wire flush_en = stall_flag_i[`CU_FLUSH];
    wire other_stall_en = stall_flag_i[`CU_STALL_DISPATCH];
    wire update_output_1 = issue_inst_i[0] & (~other_stall_en);
    wire update_output_2 = issue_inst_i[1] & (~other_stall_en);

    // 指令1地址寄存器
    wire [`INST_ADDR_WIDTH-1:0] inst1_addr;
    gnrl_dfflr #(`INST_ADDR_WIDTH) inst1_addr_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_addr,
        inst1_addr
    );
    assign inst1_addr_o = inst1_addr;

    // 指令1寄存器写使能寄存器
    wire inst1_reg_we;
    gnrl_dfflr #(1) inst1_reg_we_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_reg_we,
        inst1_reg_we
    );
    assign inst1_reg_we_o = inst1_reg_we;

    // 指令1寄存器写地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst1_reg_waddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst1_reg_waddr_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_reg_waddr,
        inst1_reg_waddr
    );
    assign inst1_reg_waddr_o = inst1_reg_waddr;

    // 指令1寄存器1读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst1_reg1_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst1_reg1_raddr_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_reg1_raddr,
        inst1_reg1_raddr
    );
    assign inst1_reg1_raddr_o = inst1_reg1_raddr;

    // 指令1寄存器2读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst1_reg2_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst1_reg2_raddr_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_reg2_raddr,
        inst1_reg2_raddr
    );
    assign inst1_reg2_raddr_o = inst1_reg2_raddr;

    // 指令1 CSR写地址寄存器
    wire [`BUS_ADDR_WIDTH-1:0] inst1_csr_waddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst1_csr_waddr_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_csr_waddr,
        inst1_csr_waddr
    );
    assign inst1_csr_waddr_o = inst1_csr_waddr;

    // 指令1 CSR读地址寄存器
    wire [`BUS_ADDR_WIDTH-1:0] inst1_csr_raddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst1_csr_raddr_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_csr_raddr,
        inst1_csr_raddr
    );
    assign inst1_csr_raddr_o = inst1_csr_raddr;

    // 指令1 CSR写使能寄存器
    wire inst1_csr_we;
    gnrl_dfflr #(1) inst1_csr_we_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_csr_we,
        inst1_csr_we
    );
    assign inst1_csr_we_o = inst1_csr_we;

    // 指令1立即数寄存器
    wire [31:0] inst1_dec_imm;
    gnrl_dfflr #(32) inst1_dec_imm_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_dec_imm,
        inst1_dec_imm
    );
    assign inst1_dec_imm_o = inst1_dec_imm;

    // 指令1译码信息总线寄存器
    wire [`DECINFO_WIDTH-1:0] inst1_dec_info_bus;
    gnrl_dfflr #(`DECINFO_WIDTH) inst1_dec_info_bus_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_dec_info_bus,
        inst1_dec_info_bus
    );
    assign inst1_dec_info_bus_o = inst1_dec_info_bus;

    // 指令1预测分支寄存器
    wire inst1_is_pred_branch;
    gnrl_dfflr #(1) inst1_is_pred_branch_ff (
        clk,
        rst_n,
        update_output_1,
        nxt_inst1_is_pred_branch,
        inst1_is_pred_branch
    );
    assign inst1_is_pred_branch_o = inst1_is_pred_branch;

    // 指令2地址寄存器
    wire [`INST_ADDR_WIDTH-1:0] inst2_addr;
    gnrl_dfflr #(`INST_ADDR_WIDTH) inst2_addr_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_addr,
        inst2_addr
    );
    assign inst2_addr_o = inst2_addr;

    // 指令2寄存器写使能寄存器
    wire inst2_reg_we;
    gnrl_dfflr #(1) inst2_reg_we_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_reg_we,
        inst2_reg_we
    );
    assign inst2_reg_we_o = inst2_reg_we;

    // 指令2寄存器写地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst2_reg_waddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst2_reg_waddr_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_reg_waddr,
        inst2_reg_waddr
    );
    assign inst2_reg_waddr_o = inst2_reg_waddr;

    // 指令2寄存器1读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst2_reg1_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst2_reg1_raddr_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_reg1_raddr,
        inst2_reg1_raddr
    );
    assign inst2_reg1_raddr_o = inst2_reg1_raddr;

    // 指令2寄存器2读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst2_reg2_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst2_reg2_raddr_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_reg2_raddr,
        inst2_reg2_raddr
    );
    assign inst2_reg2_raddr_o = inst2_reg2_raddr;

    // 指令2 CSR写地址寄存器
    wire [`BUS_ADDR_WIDTH-1:0] inst2_csr_waddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst2_csr_waddr_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_csr_waddr,
        inst2_csr_waddr
    );
    assign inst2_csr_waddr_o = inst2_csr_waddr;

    // 指令2 CSR读地址寄存器
    wire [`BUS_ADDR_WIDTH-1:0] inst2_csr_raddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst2_csr_raddr_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_csr_raddr,
        inst2_csr_raddr
    );
    assign inst2_csr_raddr_o = inst2_csr_raddr;

    // 指令2 CSR写使能寄存器
    wire inst2_csr_we;
    gnrl_dfflr #(1) inst2_csr_we_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_csr_we,
        inst2_csr_we
    );
    assign inst2_csr_we_o = inst2_csr_we;

    // 指令2立即数寄存器
    wire [31:0] inst2_dec_imm;
    gnrl_dfflr #(32) inst2_dec_imm_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_dec_imm,
        inst2_dec_imm
    );
    assign inst2_dec_imm_o = inst2_dec_imm;

    // 指令2译码信息总线寄存器
    wire [`DECINFO_WIDTH-1:0] inst2_dec_info_bus;
    gnrl_dfflr #(`DECINFO_WIDTH) inst2_dec_info_bus_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_dec_info_bus,
        inst2_dec_info_bus
    );
    assign inst2_dec_info_bus_o = inst2_dec_info_bus;

    // 指令2预测分支寄存器
    wire inst2_is_pred_branch;
    gnrl_dfflr #(1) inst2_is_pred_branch_ff (
        clk,
        rst_n,
        update_output_2,
        nxt_inst2_is_pred_branch,
        inst2_is_pred_branch
    );
    assign inst2_is_pred_branch_o = inst2_is_pred_branch;

endmodule