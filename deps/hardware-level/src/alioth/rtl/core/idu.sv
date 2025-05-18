/*                                                                      
 Copyright 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
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

    // from regs
    input wire [`REG_DATA_WIDTH-1:0] reg1_rdata_i,  // 通用寄存器1输入数据
    input wire [`REG_DATA_WIDTH-1:0] reg2_rdata_i,  // 通用寄存器2输入数据

    // from csr reg
    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,  // CSR寄存器输入数据

    // from ctrl
    input wire [`Hold_Flag_Bus] hold_flag_i,  // 流水线暂停标志

    // from writeback
    input wire wb_done_i,                     // 写回完成信号

    // 从EXU获取当前执行阶段信息（用于数据前推）
    input wire                       ex_reg_we_i,     // 执行阶段寄存器写使能
    input wire [`REG_ADDR_WIDTH-1:0] ex_reg_waddr_i,  // 执行阶段写寄存器地址

    // to regs
    output wire [`REG_ADDR_WIDTH-1:0] reg1_raddr_o,  // 读通用寄存器1地址
    output wire [`REG_ADDR_WIDTH-1:0] reg2_raddr_o,  // 读通用寄存器2地址

    // to csr reg
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // 读CSR寄存器地址

    // to ex
    output wire [`INST_DATA_WIDTH-1:0] inst_o,         // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,    // 指令地址
    output wire                        reg_we_o,       // 写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,    // 写通用寄存器地址
    output wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_o,   // 通用寄存器1数据
    output wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_o,   // 通用寄存器2数据
    output wire                        csr_we_o,       // 写CSR寄存器标志
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,    // 写CSR寄存器地址
    output wire [ `REG_DATA_WIDTH-1:0] csr_rdata_o,    // CSR寄存器数据
    output wire [                31:0] dec_imm_o,      // 立即数
    output wire [  `DECINFO_WIDTH-1:0] dec_info_bus_o, // 译码信息总线

    // to ctrl
    output wire                        hdu_hold_flag_o // 数据冲突暂停信号
);

    // 内部连线，连接id和id_ex
    wire [`INST_DATA_WIDTH-1:0] id_inst;
    wire [`INST_ADDR_WIDTH-1:0] id_inst_addr;
    wire [ `REG_DATA_WIDTH-1:0] id_reg1_rdata;
    wire [ `REG_DATA_WIDTH-1:0] id_reg2_rdata;
    wire                        id_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg_waddr;
    wire                        id_csr_we;
    wire [ `BUS_ADDR_WIDTH-1:0] id_csr_waddr;
    wire [ `REG_DATA_WIDTH-1:0] id_csr_rdata;
    wire [                31:0] id_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] id_dec_info_bus;

    // 实例化id模块 - 更新接口，传递HDU所需信号
    id u_id (
        .clk         (clk),            // 新增：传递时钟给ID内部的HDU
        .rst_n       (rst_n),

        // from if_id
        .inst_i     (inst_i),
        .inst_addr_i(inst_addr_i),

        // from regs
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),

        // from csr reg
        .csr_rdata_i(csr_rdata_i),

        // 新增：传递HDU所需信号
        .hold_flag_i(hold_flag_i),
        .wb_done_i(wb_done_i),
        .ex_reg_we_i(ex_reg_we_i),
        .ex_reg_waddr_i(ex_reg_waddr_i),

        // to regs
        .reg1_raddr_o(reg1_raddr_o),
        .reg2_raddr_o(reg2_raddr_o),

        // to csr reg
        .csr_raddr_o(csr_raddr_o),

        // to id_ex
        .dec_imm_o     (id_dec_imm),
        .dec_info_bus_o(id_dec_info_bus),
        .inst_o        (id_inst),
        .inst_addr_o   (id_inst_addr),
        .reg1_rdata_o  (id_reg1_rdata),
        .reg2_rdata_o  (id_reg2_rdata),
        .reg_we_o      (id_reg_we),
        .reg_waddr_o   (id_reg_waddr),
        .csr_we_o      (id_csr_we),
        .csr_rdata_o   (id_csr_rdata),
        .csr_waddr_o   (id_csr_waddr),
        
        // 新增：从ID模块获取HDU暂停信号
        .hdu_hold_flag_o(hdu_hold_flag_o)
    );

    // 移除独立的HDU模块实例，因为它已经集成到ID模块内部

    // 实例化id_ex模块
    id_ex u_id_ex (
        .clk  (clk),
        .rst_n(rst_n),

        // from id
        .inst_i        (id_inst),
        .inst_addr_i   (id_inst_addr),
        .reg_we_i      (id_reg_we),
        .reg_waddr_i   (id_reg_waddr),
        .reg1_rdata_i  (id_reg1_rdata),
        .reg2_rdata_i  (id_reg2_rdata),
        .csr_we_i      (id_csr_we),
        .csr_waddr_i   (id_csr_waddr),
        .csr_rdata_i   (id_csr_rdata),
        .dec_info_bus_i(id_dec_info_bus),
        .dec_imm_i     (id_dec_imm),

        // from ctrl
        .hold_flag_i(hold_flag_i),

        // to ex
        .inst_o        (inst_o),
        .inst_addr_o   (inst_addr_o),
        .reg_we_o      (reg_we_o),
        .reg_waddr_o   (reg_waddr_o),
        .reg1_rdata_o  (reg1_rdata_o),
        .reg2_rdata_o  (reg2_rdata_o),
        .csr_we_o      (csr_we_o),
        .csr_rdata_o   (csr_rdata_o),
        .csr_waddr_o   (csr_waddr_o),
        .dec_imm_o     (dec_imm_o),
        .dec_info_bus_o(dec_info_bus_o)
    );

endmodule
