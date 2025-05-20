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

// alioth处理器核顶层模块
module cpu_top (

    input wire clk,
    input wire rst_n

);

    // pc_reg模块输出信号
    wire [`INST_ADDR_WIDTH-1:0] pc_pc_o;

    // if_id模块输出信号
    wire [`INST_DATA_WIDTH-1:0] if_inst_o;
    wire [`INST_ADDR_WIDTH-1:0] if_inst_addr_o;
    wire [`INST_DATA_WIDTH-1:0] if_int_flag_o;

    // id模块输出信号
    wire [ `REG_ADDR_WIDTH-1:0] id_reg1_raddr_o;
    wire [ `REG_ADDR_WIDTH-1:0] id_reg2_raddr_o;
    wire [ `BUS_ADDR_WIDTH-1:0] id_csr_raddr_o;

    // idu模块输出信号 - 直接包含了ID和ID_EX的功能
    wire [`INST_DATA_WIDTH-1:0] idu_inst_o;
    wire [`INST_ADDR_WIDTH-1:0] idu_inst_addr_o;
    wire                        idu_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] idu_reg_waddr_o;
    wire [ `REG_ADDR_WIDTH-1:0] idu_reg1_raddr_o;
    wire [ `REG_ADDR_WIDTH-1:0] idu_reg2_raddr_o;
    wire                        idu_csr_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] idu_csr_waddr_o;
    wire [ `REG_DATA_WIDTH-1:0] idu_csr_rdata_o;
    wire [                31:0] idu_dec_imm_o;
    wire [  `DECINFO_WIDTH-1:0] idu_dec_info_bus_o;

    // exu模块输出信号
    wire [ `BUS_DATA_WIDTH-1:0] exu_mem_wdata_o;
    wire [ `BUS_ADDR_WIDTH-1:0] exu_mem_raddr_o;
    wire [ `BUS_ADDR_WIDTH-1:0] exu_mem_waddr_o;
    wire                        exu_mem_we_o;
    wire                        exu_mem_req_o;
    wire [                 3:0] exu_mem_wmask_o;
    wire                        exu_hold_flag_o;
    wire                        exu_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;
    wire [ `REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire                        exu_csr_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;
    wire                        exu_muldiv_started_o;

    // 添加CSR寄存器写数据信号
    wire [ `REG_DATA_WIDTH-1:0] exu_csr_reg_wdata_o;

    // 系统操作信号
    wire                        exu_ecall_o;
    wire                        exu_ebreak_o;
    wire                        exu_mret_o;

    // EXU到WBU的数据通路信号
    wire [ `REG_DATA_WIDTH-1:0] exu_alu_reg_wdata_o;
    wire                        exu_alu_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] exu_alu_reg_waddr_o;

    wire [ `REG_DATA_WIDTH-1:0] exu_muldiv_reg_wdata_o;
    wire                        exu_muldiv_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] exu_muldiv_reg_waddr_o;

    wire [ `REG_DATA_WIDTH-1:0] exu_agu_reg_wdata_o;
    wire                        exu_agu_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] exu_agu_reg_waddr_o;

    // wbu输出信号
    wire [ `REG_DATA_WIDTH-1:0] wbu_reg_wdata_o;
    wire                        wbu_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] wbu_reg_waddr_o;

    // WBU CSR输出信号
    wire [ `REG_DATA_WIDTH-1:0] wbu_csr_wdata_o;
    wire                        wbu_csr_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] wbu_csr_waddr_o;

    // regs模块输出信号
    wire [ `REG_DATA_WIDTH-1:0] regs_rdata1_o;
    wire [ `REG_DATA_WIDTH-1:0] regs_rdata2_o;

    // csr_reg模块输出信号
    wire [ `REG_DATA_WIDTH-1:0] csr_data_o;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_data_o;
    wire                        csr_global_int_en_o;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_csr_mtvec;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_csr_mepc;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_csr_mstatus;

    // ctrl模块输出信号
    wire [ `HOLD_BUS_WIDTH-1:0] ctrl_hold_flag_o;
    wire                        ctrl_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] ctrl_jump_addr_o;

    // clint模块输出信号
    wire                        clint_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] clint_waddr_o;
    wire [ `BUS_ADDR_WIDTH-1:0] clint_raddr_o;
    wire [ `REG_DATA_WIDTH-1:0] clint_data_o;
    wire [`INST_ADDR_WIDTH-1:0] clint_int_addr_o;
    wire                        clint_int_assert_o;
    wire                        clint_hold_flag_o;

    // mems模块接口信号
    wire                        hold_flag_i;
    wire [`INST_DATA_WIDTH-1:0] inst_data_i;
    wire [ `BUS_DATA_WIDTH-1:0] exu_mem_data_i;

    // IFU模块例化
    ifu u_ifu (
        .clk        (clk),
        .rst_n      (rst_n),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_i     (inst_data_i),
        .pc_o       (pc_pc_o),
        .inst_o     (if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // ctrl模块例化
    ctrl u_ctrl (
        .rst_n            (rst_n),
        .jump_flag_i      (exu_jump_flag_o),
        .jump_addr_i      (exu_jump_addr_o),
        .hold_flag_ex_i   (exu_hold_flag_o),
        .hold_flag_mems_i (hold_flag_i),
        .hold_flag_o      (ctrl_hold_flag_o),
        .hold_flag_clint_i(clint_hold_flag_o),
        .jump_flag_o      (ctrl_jump_flag_o),
        .jump_addr_o      (ctrl_jump_addr_o)
    );

    // regs模块例化
    regs u_regs (
        .clk     (clk),
        .rst_n   (rst_n),
        .we_i    (wbu_reg_we_o),
        .waddr_i (wbu_reg_waddr_o),
        .wdata_i (wbu_reg_wdata_o),
        .raddr1_i(idu_reg1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(idu_reg2_raddr_o),
        .rdata2_o(regs_rdata2_o)
    );

    // csr_reg模块例化
    csr_reg u_csr_reg (
        .clk              (clk),
        .rst_n            (rst_n),
        .we_i             (wbu_csr_we_o),
        .raddr_i          (id_csr_raddr_o),
        .waddr_i          (wbu_csr_waddr_o),
        .data_i           (wbu_csr_wdata_o),
        .data_o           (csr_data_o),
        .global_int_en_o  (csr_global_int_en_o),
        .clint_we_i       (clint_we_o),
        .clint_raddr_i    (clint_raddr_o),
        .clint_waddr_i    (clint_waddr_o),
        .clint_data_i     (clint_data_o),
        .clint_data_o     (csr_clint_data_o),
        .clint_csr_mtvec  (csr_clint_csr_mtvec),
        .clint_csr_mepc   (csr_clint_csr_mepc),
        .clint_csr_mstatus(csr_clint_csr_mstatus)
    );

    // idu模块例化 - 已集成id和id_ex功能
    idu u_idu (
        .clk           (clk),
        .rst_n         (rst_n),
        .inst_i        (if_inst_o),
        .inst_addr_i   (if_inst_addr_o),
        .hold_flag_i   (ctrl_hold_flag_o),
        .csr_raddr_o   (id_csr_raddr_o),
        .inst_o        (idu_inst_o),
        .inst_addr_o   (idu_inst_addr_o),
        .reg_we_o      (idu_reg_we_o),
        .reg_waddr_o   (idu_reg_waddr_o),
        .reg1_raddr_o  (idu_reg1_raddr_o),
        .reg2_raddr_o  (idu_reg2_raddr_o),
        .csr_we_o      (idu_csr_we_o),
        .csr_waddr_o   (idu_csr_waddr_o),
        .dec_imm_o     (idu_dec_imm_o),
        .dec_info_bus_o(idu_dec_info_bus_o)
    );

    // exu模块例化
    exu u_exu (
        .clk           (clk),
        .rst_n         (rst_n),
        .inst_i        (idu_inst_o),
        .inst_addr_i   (idu_inst_addr_o),
        .reg_we_i      (idu_reg_we_o),
        .reg_waddr_i   (idu_reg_waddr_o),
        .csr_we_i      (idu_csr_we_o),
        .csr_waddr_i   (idu_csr_waddr_o),
        .csr_rdata_i   (csr_data_o),
        .dec_info_bus_i(idu_dec_info_bus_o),
        .dec_imm_i     (idu_dec_imm_o),
        .mem_rdata_i   (exu_mem_data_i),
        .int_assert_i  (clint_int_assert_o),
        .int_addr_i    (clint_int_addr_o),

        // 直接从寄存器文件读取数据
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),

        .mem_wdata_o(exu_mem_wdata_o),
        .mem_raddr_o(exu_mem_raddr_o),
        .mem_waddr_o(exu_mem_waddr_o),
        .mem_we_o   (exu_mem_we_o),
        .mem_req_o  (exu_mem_req_o),
        .mem_wmask_o(exu_mem_wmask_o),

        .alu_reg_wdata_o(exu_alu_reg_wdata_o),
        .alu_reg_we_o   (exu_alu_reg_we_o),
        .alu_reg_waddr_o(exu_alu_reg_waddr_o),

        .muldiv_reg_wdata_o(exu_muldiv_reg_wdata_o),
        .muldiv_reg_we_o   (exu_muldiv_reg_we_o),
        .muldiv_reg_waddr_o(exu_muldiv_reg_waddr_o),

        .agu_reg_wdata_o(exu_agu_reg_wdata_o),
        .agu_reg_we_o   (exu_agu_reg_we_o),
        .agu_reg_waddr_o(exu_agu_reg_waddr_o),

        // 连接CSR寄存器写数据信号
        .csr_reg_wdata_o(exu_csr_reg_wdata_o),

        .csr_wdata_o(exu_csr_wdata_o),
        .csr_we_o   (exu_csr_we_o),
        .csr_waddr_o(exu_csr_waddr_o),

        .hold_flag_o     (exu_hold_flag_o),
        .jump_flag_o     (exu_jump_flag_o),
        .jump_addr_o     (exu_jump_addr_o),
        .muldiv_started_o(exu_muldiv_started_o),

        // 系统操作信号输出
        .exu_op_ecall_o (exu_ecall_o),
        .exu_op_ebreak_o(exu_ebreak_o),
        .exu_op_mret_o  (exu_mret_o)
    );

    // wbu模块例化
    wbu u_wbu (
        .clk  (clk),
        .rst_n(rst_n),

        .alu_reg_wdata_i(exu_alu_reg_wdata_o),
        .alu_reg_we_i   (exu_alu_reg_we_o),
        .alu_reg_waddr_i(exu_alu_reg_waddr_o),

        .muldiv_reg_wdata_i(exu_muldiv_reg_wdata_o),
        .muldiv_reg_we_i   (exu_muldiv_reg_we_o),
        .muldiv_reg_waddr_i(exu_muldiv_reg_waddr_o),

        .csr_wdata_i(exu_csr_wdata_o),
        .csr_we_i   (exu_csr_we_o),
        .csr_waddr_i(exu_csr_waddr_o),

        // CSR对通用寄存器的写数据输入
        .csr_reg_wdata_i(exu_csr_reg_wdata_o),

        .agu_reg_wdata_i(exu_agu_reg_wdata_o),
        .agu_reg_we_i   (exu_agu_reg_we_o),
        .agu_reg_waddr_i(exu_agu_reg_waddr_o),

        .idu_reg_waddr_i(idu_reg_waddr_o),

        .int_assert_i(clint_int_assert_o),

        .reg_wdata_o(wbu_reg_wdata_o),
        .reg_we_o   (wbu_reg_we_o),
        .reg_waddr_o(wbu_reg_waddr_o),

        .csr_wdata_o(wbu_csr_wdata_o),
        .csr_we_o   (wbu_csr_we_o),
        .csr_waddr_o(wbu_csr_waddr_o)
    );

    // clint模块例化
    clint u_clint (
        .clk             (clk),
        .rst_n           (rst_n),
        .inst_addr_i     (idu_inst_addr_o),
        .jump_flag_i     (exu_jump_flag_o),
        .jump_addr_i     (exu_jump_addr_o),
        .hold_flag_i     (ctrl_hold_flag_o),
        .muldiv_started_i(exu_muldiv_started_o),

        // 连接系统操作信号
        .sys_op_ecall_i (exu_ecall_o),
        .sys_op_ebreak_i(exu_ebreak_o),
        .sys_op_mret_i  (exu_mret_o),

        .data_i         (csr_clint_data_o),
        .csr_mtvec      (csr_clint_csr_mtvec),
        .csr_mepc       (csr_clint_csr_mepc),
        .csr_mstatus    (csr_clint_csr_mstatus),
        .we_o           (clint_we_o),
        .waddr_o        (clint_waddr_o),
        .raddr_o        (clint_raddr_o),
        .data_o         (clint_data_o),
        .hold_flag_o    (clint_hold_flag_o),
        .global_int_en_i(csr_global_int_en_o),
        .int_addr_o     (clint_int_addr_o),
        .int_assert_o   (clint_int_assert_o)
    );

    // mems模块例化
    mems u_mems (
        .clk        (clk),
        .rst_n      (rst_n),
        // PC接口
        .pc_i       (pc_pc_o),
        .inst_o     (inst_data_i),
        // EX接口
        .ex_addr_i  (exu_mem_we_o ? exu_mem_waddr_o : exu_mem_raddr_o),
        .ex_data_i  (exu_mem_wdata_o),
        .ex_data_o  (exu_mem_data_i),
        .ex_we_i    (exu_mem_we_o),
        .ex_req_i   (exu_mem_req_o),
        .ex_wmask_i (exu_mem_wmask_o),
        // 暂停信号
        .hold_flag_o(hold_flag_i)
    );

endmodule
