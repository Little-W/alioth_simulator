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

    // from ctrl
    input wire [`HOLD_BUS_WIDTH-1:0] hold_flag_i,  // 流水线暂停标志

    // 长指令完成信号
    input wire       commit_valid_i,  // 长指令执行完成有效信号
    input wire [1:0] commit_id_i,     // 执行完成的长指令ID

    // to csr reg
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // 读CSR寄存器地址

    // to ex
    output wire [`INST_DATA_WIDTH-1:0] inst_o,  // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,  // 指令地址
    output wire reg_we_o,  // 写通用寄存器标志
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,  // 写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_o,   // 读通用寄存器1地址(传给EX)
    output wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_o,   // 读通用寄存器2地址(传给EX)
    output wire csr_we_o,  // 写CSR寄存器标志
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,  // 写CSR寄存器地址
    output wire [31:0] dec_imm_o,  // 立即数
    output wire [`DECINFO_WIDTH-1:0] dec_info_bus_o,  // 译码信息总线

    // 冒险处理输出
    output wire       hold_flag_o,    // 流水线暂停信号
    output wire [1:0] long_inst_id_o,  // 为新的长指令分配的ID
    output wire       long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
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
    wire [ `BUS_ADDR_WIDTH-1:0] id_csr_raddr;  // CSR读地址
    wire [                31:0] id_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] id_dec_info_bus;

    // 新增内部连线，连接冒险检测相关信号
    wire                        id_hold_flag;
    wire [                 1:0] id_long_inst_id;
    wire                        id_long_inst_atom_lock;  // 原子锁信号

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
        .inst_o        (id_inst),
        .inst_addr_o   (id_inst_addr),
        .reg_we_o      (id_reg_we),
        .reg_waddr_o   (id_reg_waddr),
        .csr_we_o      (id_csr_we),
        .csr_waddr_o   (id_csr_waddr)
    );

    // 判断当前指令是否为长指令（乘除法指令或访存指令）
    wire is_muldiv_long_inst = (id_dec_info_bus[`DECINFO_GRP_BUS] == `DECINFO_GRP_MULDIV);
    wire is_mem_long_inst = (id_dec_info_bus[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire is_long_inst = is_muldiv_long_inst | is_mem_long_inst;
    wire new_long_inst_valid = is_long_inst;

    // 实例化冒险检测单元 - 所有输入信号都从decode模块输出获取
    hdu u_hdu (
        .clk  (clk),
        .rst_n(rst_n),

        // 新指令信息 - 从decode模块获取
        .new_long_inst_valid(new_long_inst_valid),
        .new_inst_rd_addr   (id_reg_waddr),    // 从decode获取目标寄存器地址
        .new_inst_rs1_addr  (id_reg1_raddr),   // 从decode获取源寄存器1地址
        .new_inst_rs2_addr  (id_reg2_raddr),   // 从decode获取源寄存器2地址
        .new_inst_rd_we(id_reg_we),  // 从decode获取写寄存器使能

        // 长指令完成信号 - 从顶层输入
        .commit_valid(commit_valid_i),
        .commit_id   (commit_id_i),

        // 控制信号
        .hold        (id_hold_flag),
        .long_inst_id(id_long_inst_id),
        .long_inst_atom_lock_o(id_long_inst_atom_lock)  // 连接原子锁信号
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
        .csr_raddr_i   (id_csr_raddr),
        .dec_info_bus_i(id_dec_info_bus),
        .dec_imm_i     (id_dec_imm),
        .long_inst_id_i(id_long_inst_id),  // 连接长指令ID输入

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
        .csr_waddr_o   (csr_waddr_o),
        .csr_raddr_o   (csr_raddr_o),
        .dec_imm_o     (dec_imm_o),
        .dec_info_bus_o(dec_info_bus_o),
        .long_inst_id_o(long_inst_id_o)   // 连接长指令ID输出
    );

    // 将冒险信号传递到顶层 - hold_flag直接传递，无需经过流水线寄存
    assign hold_flag_o = id_hold_flag;
    assign long_inst_atom_lock_o = id_long_inst_atom_lock;

endmodule
