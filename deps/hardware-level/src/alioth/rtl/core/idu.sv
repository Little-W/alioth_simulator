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
// 整合两路id和id_ex模块
module idu (
    input wire clk,
    input wire rst_n,

    // from if_id - 第一条指令
    input wire [`INST_DATA_WIDTH-1:0] inst_i,            // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 指令地址
    input wire                        is_pred_branch_i,  // 添加预测分支指令标志输入
    input wire                        inst_valid_i,      // 新增：指令有效输入
    
    // from if_id - 第二条指令
    input wire [`INST_DATA_WIDTH-1:0] inst2_i,           // 第二条指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,      // 第二条指令地址
    input wire                        is_pred_branch2_i, // 第二条指令预测分支标志输入
    input wire                        inst2_valid_i,     // 第二条指令有效输入

    // from ctrl
    input wire [`CU_BUS_WIDTH-1:0] stall_flag1_i,  // 流水线暂停标志
    input wire [`CU_BUS_WIDTH-1:0] stall_flag2_i,  // 流水线暂停标志

    // to csr reg
    output wire [31:0] inst1_csr_raddr_o,   // 读CSR寄存器地址
    output wire [31:0] inst2_csr_raddr_o,  // 第二路读CSR寄存器地址

    // to icu - 第一路
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,          // 指令地址
    output wire                        inst1_reg_we_o,       // 写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,    // 写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_o,   // 读通用寄存器1地址(传给EX)
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_o,   // 读通用寄存器2地址(传给EX)
    output wire                        inst1_csr_we_o,       // 写CSR寄存器标志
    output wire [ 31:0] inst1_csr_waddr_o,    // 写CSR寄存器地址
    output wire [                31:0] inst1_dec_imm_o,      // 立即数
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o, // 译码信息总线
    output wire                        inst1_is_pred_branch_o, // 添加预测分支指令标志输出
    output wire                        inst1_valid_o,        // 新增：指令有效输出
    output wire                        inst1_illegal_inst_o, // 新增：非法指令输出
    output wire [`INST_DATA_WIDTH-1:0] inst1_o,             // 新增：指令内容输出
    output wire                        inst1_jump_o,         // 新增：第一路跳转指令输出
    output wire                        inst1_branch_o,       // 新增：第一路分支指令输出
    output wire                        inst1_csr_type_o,     // 新增：第一路CSR类型指令输出

    // to ex - 第二路
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,          // 第二路指令地址
    output wire                        inst2_reg_we_o,       // 第二路写通用寄存器标志
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,    // 第二路写通用寄存器地址
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_o,   // 第二路读通用寄存器1地址
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_o,   // 第二路读通用寄存器2地址
    output wire                        inst2_csr_we_o,       // 第二路写CSR寄存器标志
    output wire [ 31:0] inst2_csr_waddr_o,    // 第二路写CSR寄存器地址
    output wire [                31:0] inst2_dec_imm_o,      // 第二路立即数
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o, // 第二路译码信息总线
    output wire                        inst2_is_pred_branch_o, // 第二路预测分支指令标志输出
    output wire                        inst2_valid_o,        // 第二路指令有效输出
    output wire                        inst2_illegal_inst_o, // 第二路非法指令输出
    output wire [`INST_DATA_WIDTH-1:0] inst2_o,             // 第二路指令内容输出
    output wire                        inst2_csr_type_o     // 第二路CSR类型指令输出
);

    // 内部连线，连接id和id_pipe
    wire [`INST_ADDR_WIDTH-1:0] id_inst_addr;
    wire                        id_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg1_raddr;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg2_raddr;
    wire                        id_csr_we;
    wire [ 31:0] id_csr_waddr;
    wire [ 31:0] id_csr_raddr;  // CSR读地址
    wire [                31:0] id_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] id_dec_info_bus;
    wire                        id_illegal_inst;  // 新增：非法指令信号
    wire                        id_inst_jump;     // 新增：跳转指令信号
    wire                        id_inst_branch;   // 新增：分支指令信号
    wire                        id_inst_csr_type; // 新增：CSR类型指令信号

    // 第二路内部连线
    wire [`INST_ADDR_WIDTH-1:0] id2_inst_addr;
    wire                        id2_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] id2_reg_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] id2_reg1_raddr;
    wire [ `REG_ADDR_WIDTH-1:0] id2_reg2_raddr;
    wire                        id2_csr_we;
    wire [ 31:0] id2_csr_waddr;
    wire [ 31:0] id2_csr_raddr;  // 第二路CSR读地址
    wire [                31:0] id2_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] id2_dec_info_bus;
    wire                        id2_illegal_inst;  // 第二路非法指令信号
    wire                        id2_inst_csr_type; // 第二路CSR类型指令信号
    // 第二路的跳转和分支信号不连接，直接悬空

    // 实例化第一路id模块
    idu_decode u_idu_decode (
        .rst_n(rst_n),

        // from if_id
        .inst_i      (inst_i),
        .inst_addr_i (inst_addr_i),
        .inst_valid_i(inst_valid_i), // 新增：指令有效输入

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
        .csr_waddr_o   (id_csr_waddr),
        .illegal_inst_o(id_illegal_inst),   // 输出非法指令信号
        .inst_jump_o   (id_inst_jump),      // 新增：跳转指令信号
        .inst_branch_o (id_inst_branch),    // 新增：分支指令信号
        .inst_csr_type_o(id_inst_csr_type)  // 新增：CSR类型指令信号
    );

    // 实例化第二路id模块
    idu_decode u_idu_decode2 (
        .rst_n(rst_n),

        // from if_id
        .inst_i      (inst2_i),
        .inst_addr_i (inst2_addr_i),
        .inst_valid_i(inst2_valid_i), // 第二路指令有效输入

        // to regs
        .reg1_raddr_o(id2_reg1_raddr),
        .reg2_raddr_o(id2_reg2_raddr),

        // to csr reg
        .csr_raddr_o(id2_csr_raddr),

        // to id_ex
        .dec_imm_o     (id2_dec_imm),
        .dec_info_bus_o(id2_dec_info_bus),
        .inst_addr_o   (id2_inst_addr),
        .reg_we_o      (id2_reg_we),
        .reg_waddr_o   (id2_reg_waddr),
        .csr_we_o      (id2_csr_we),
        .csr_waddr_o   (id2_csr_waddr),
        .illegal_inst_o(id2_illegal_inst),   // 输出第二路非法指令信号
        .inst_jump_o   (),                   // 第二路跳转信号悬空
        .inst_branch_o (),                   // 第二路分支信号悬空
        .inst_csr_type_o(id2_inst_csr_type)  // 第二路CSR类型指令信号
    );

    // 实例化第一路idu_id_pipe模块
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
        .csr_we_i        (id_csr_we),
        .csr_waddr_i     (id_csr_waddr),
        .csr_raddr_i     (id_csr_raddr),
        .dec_info_bus_i  (id_dec_info_bus),
        .dec_imm_i       (id_dec_imm),
        .is_pred_branch_i(is_pred_branch_i),  // 添加预测分支信号输入
        .inst_valid_i    (inst_valid_i),      // 新增：指令有效输入
        .illegal_inst_i  (id_illegal_inst),   // 新增：非法指令输入
        .inst_jump_i     (id_inst_jump),      // 新增：跳转指令信号输入
        .inst_branch_i   (id_inst_branch),    // 新增：分支指令信号输入
        .inst_csr_type_i (id_inst_csr_type),  // 新增：CSR类型指令信号输入

        // from ctrl
        .stall_flag_i(stall_flag1_i),

        // to ex
        .inst_addr_o     (inst1_addr_o),
        .reg_we_o        (inst1_reg_we_o),
        .reg_waddr_o     (inst1_reg_waddr_o),
        .reg1_raddr_o    (inst1_reg1_raddr_o),
        .reg2_raddr_o    (inst1_reg2_raddr_o),
        .csr_we_o        (inst1_csr_we_o),
        .csr_waddr_o     (inst1_csr_waddr_o),
        .csr_raddr_o     (inst1_csr_raddr_o),
        .dec_imm_o       (inst1_dec_imm_o),
        .dec_info_bus_o  (inst1_dec_info_bus_o),
        .is_pred_branch_o(inst1_is_pred_branch_o),  // 添加预测分支信号输出
        .inst_valid_o    (inst1_valid_o),      // 新增：指令有效输出
        .illegal_inst_o  (inst1_illegal_inst_o),    // 新增：非法指令输出
        .inst_o          (inst1_o),            // 新增：指令内容输出
        .inst_jump_o     (inst1_jump_o),       // 新增：跳转指令信号输出
        .inst_branch_o   (inst1_branch_o),     // 新增：分支指令信号输出
        .inst_csr_type_o (inst1_csr_type_o)    // 新增：CSR类型指令信号输出
    );

    // 实例化第二路idu_id_pipe模块
    idu_id_pipe u_idu_id_pipe2 (
        .clk  (clk),
        .rst_n(rst_n),

        // from id
        .inst_i          (inst2_i),            // 第二路指令内容输入
        .inst_addr_i     (id2_inst_addr),
        .reg_we_i        (id2_reg_we),
        .reg_waddr_i     (id2_reg_waddr),
        .reg1_raddr_i    (id2_reg1_raddr),
        .reg2_raddr_i    (id2_reg2_raddr),
        .csr_we_i        (id2_csr_we),
        .csr_waddr_i     (id2_csr_waddr),
        .csr_raddr_i     (id2_csr_raddr),
        .dec_info_bus_i  (id2_dec_info_bus),
        .dec_imm_i       (id2_dec_imm),
        .is_pred_branch_i(is_pred_branch2_i),  // 添加第二路预测分支信号输入
        .inst_valid_i    (inst2_valid_i),      // 第二路指令有效输入
        .illegal_inst_i  (id2_illegal_inst),   // 第二路非法指令输入
        .inst_jump_i     (1'b0),               // 第二路跳转信号接地
        .inst_branch_i   (),               // 第二路分支信号接地
        .inst_csr_type_i (id2_inst_csr_type),  // 第二路CSR类型指令信号输入

        // from ctrl
        .stall_flag_i(stall_flag2_i),

        // to ex
        .inst_addr_o     (inst2_addr_o),
        .reg_we_o        (inst2_reg_we_o),
        .reg_waddr_o     (inst2_reg_waddr_o),
        .reg1_raddr_o    (inst2_reg1_raddr_o),
        .reg2_raddr_o    (inst2_reg2_raddr_o),
        .csr_we_o        (inst2_csr_we_o),
        .csr_waddr_o     (inst2_csr_waddr_o),
        .csr_raddr_o     (inst2_csr_raddr_o),
        .dec_imm_o       (inst2_dec_imm_o),
        .dec_info_bus_o  (inst2_dec_info_bus_o),
        .is_pred_branch_o(inst2_is_pred_branch_o),  // 添加第二路预测分支信号输出
        .inst_valid_o    (inst2_valid_o),      // 第二路指令有效输出
        .illegal_inst_o  (inst2_illegal_inst_o),    // 第二路非法指令输出
        .inst_o          (inst2_o),            // 第二路指令内容输出
        .inst_jump_o     (),                   // 第二路跳转信号输出悬空
        .inst_branch_o   (),        
        .inst_csr_type_o (inst2_csr_type_o)    // 第二路CSR类型指令信号输出
    );

endmodule
