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

    // from csr reg
    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,  // CSR寄存器输入数据

    // from ctrl
    input wire [`Hold_Flag_Bus] hold_flag_i,  // 流水线暂停标志

    // to csr reg
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // 读CSR寄存器地址

    // to ex
    output wire [`INST_DATA_WIDTH-1:0] inst_o,         // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,    // 指令地址
    output wire                        reg_we_o,       // 写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,    // 写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_o,   // 读通用寄存器1地址(传给EX)
    output wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_o,   // 读通用寄存器2地址(传给EX)
    output wire                        csr_we_o,       // 写CSR寄存器标志
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,    // 写CSR寄存器地址
    output wire [ `REG_DATA_WIDTH-1:0] csr_rdata_o,    // CSR寄存器数据
    output wire [                31:0] dec_imm_o,      // 立即数
    output wire [  `DECINFO_WIDTH-1:0] dec_info_bus_o  // 译码信息总线
);

    // 内部连线，连接id和id_ex
    wire [`INST_DATA_WIDTH-1:0] id_inst;
    wire [`INST_ADDR_WIDTH-1:0] id_inst_addr;
    wire                        id_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg1_raddr;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg2_raddr;
    wire                        id_csr_we;
    wire [ `BUS_ADDR_WIDTH-1:0] id_csr_waddr;
    wire [ `REG_DATA_WIDTH-1:0] id_csr_rdata;
    wire [                31:0] id_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] id_dec_info_bus;

    // 实例化id模块
    idu_decode u_idu_decode (
        .rst_n       (rst_n),

        // from if_id
        .inst_i     (inst_i),
        .inst_addr_i(inst_addr_i),

        // from csr reg
        .csr_rdata_i(csr_rdata_i),

        // to regs
        .reg1_raddr_o(id_reg1_raddr),
        .reg2_raddr_o(id_reg2_raddr),

        // to csr reg
        .csr_raddr_o(csr_raddr_o),

        // to id_ex
        .dec_imm_o     (id_dec_imm),
        .dec_info_bus_o(id_dec_info_bus),
        .inst_o        (id_inst),
        .inst_addr_o   (id_inst_addr),
        .reg_we_o      (id_reg_we),
        .reg_waddr_o   (id_reg_waddr),
        .csr_we_o      (id_csr_we),
        .csr_rdata_o   (id_csr_rdata),
        .csr_waddr_o   (id_csr_waddr)
    );

    // 实例化idu_id_pipe模块
    idu_id_pipe u_idu_id_pipe (
        .clk  (clk),
        .rst_n(rst_n),

        // from id
        .inst_i        (id_inst),
        .inst_addr_i   (id_inst_addr),
        .reg_we_i      (id_reg_we),
        .reg_waddr_i   (id_reg_waddr),
        .reg1_raddr_i  (id_reg1_raddr),
        .reg2_raddr_i  (id_reg2_raddr),
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
        .reg1_raddr_o  (reg1_raddr_o),
        .reg2_raddr_o  (reg2_raddr_o),
        .csr_we_o      (csr_we_o),
        .csr_rdata_o   (csr_rdata_o),
        .csr_waddr_o   (csr_waddr_o),
        .dec_imm_o     (dec_imm_o),
        .dec_info_bus_o(dec_info_bus_o)
    );

endmodule
