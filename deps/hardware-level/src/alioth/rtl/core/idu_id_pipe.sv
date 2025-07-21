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
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 指令地址
    input wire                        reg_we_i,          // 写通用寄存器标志
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,       // 写通用寄存器地址
    input wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_i,      // 读通用寄存器1地址
    input wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_i,      // 读通用寄存器2地址
    input wire                        csr_we_i,          // 写CSR寄存器标志
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,       // 写CSR寄存器地址
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_raddr_i,       // 读CSR寄存器地址
    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,
    input wire                        is_pred_branch_i,  // 添加预测分支指令标志输入
    input wire                        inst_valid_i,      // 新增：指令有效输入
    input wire                        illegal_inst_i,    // 新增：非法指令输入
    input wire [`INST_DATA_WIDTH-1:0] inst_i,            // 新增：指令内容输入

    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i,  // 流水线暂停标志

    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,       // 指令地址
    output wire                        reg_we_o,          // 写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,       // 写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_o,      // 读通用寄存器1地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_o,      // 读通用寄存器2地址
    output wire                        csr_we_o,          // 写CSR寄存器标志
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,       // 写CSR寄存器地址
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_raddr_o,       // 读CSR寄存器地址
    output wire [                31:0] dec_imm_o,         // 立即数
    output wire [  `DECINFO_WIDTH-1:0] dec_info_bus_o,    // 译码信息总线
    output wire                        is_pred_branch_o,  // 添加预测分支指令标志输出
    output wire                        inst_valid_o,      // 新增：指令有效输出
    output wire                        illegal_inst_o,     // 新增：非法指令输出
    output wire [`INST_DATA_WIDTH-1:0] inst_o             // 新增：指令内容输出
);

    wire                        flush_en = stall_flag_i[`CU_FLUSH];
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

    // 预测分支信号传递
    wire is_pred_branch_dnxt = flush_en ? 1'b0 : is_pred_branch_i;
    wire is_pred_branch;
    gnrl_dfflr #(1) is_pred_branch_ff (
        clk,
        rst_n,
        reg_update_en,
        is_pred_branch_dnxt,
        is_pred_branch
    );
    assign is_pred_branch_o = is_pred_branch;

    // 指令有效信号传递
    wire inst_valid_dnxt = flush_en ? 1'b0 : inst_valid_i;
    wire inst_valid;
    gnrl_dfflr #(1) inst_valid_ff (
        clk,
        rst_n,
        reg_update_en,
        inst_valid_dnxt,
        inst_valid
    );
    assign inst_valid_o = inst_valid;

    // 非法指令信号传递
    wire illegal_inst_dnxt = flush_en ? 1'b0 : illegal_inst_i;
    wire illegal_inst;
    gnrl_dfflr #(1) illegal_inst_ff (
        clk,
        rst_n,
        reg_update_en,
        illegal_inst_dnxt,
        illegal_inst
    );
    assign illegal_inst_o = illegal_inst;

    // 指令内容传递
    wire [`INST_DATA_WIDTH-1:0] inst_dnxt = flush_en ? `ZeroWord : inst_i;
    wire [`INST_DATA_WIDTH-1:0] inst;
    gnrl_dfflr #(`INST_DATA_WIDTH) inst_ff (
        clk,
        rst_n,
        reg_update_en,
        inst_dnxt,
        inst
    );
    assign inst_o = inst;

endmodule
