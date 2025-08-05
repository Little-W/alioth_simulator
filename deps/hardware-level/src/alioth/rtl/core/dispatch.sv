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

// 指令分发模块 - 将译码结果分发到各功能单元
module dispatch (
    input wire                     clk,
    input wire                     rst_n,
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i, // 流水线暂停标志

    // 指令有效信号输入
    input wire inst_valid_i,
    // 新增：非法指令信号输入
    input wire illegal_inst_i,

    // 输入译码信息总线和立即数
    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,
    input wire [`INST_ADDR_WIDTH-1:0] dec_pc_i,
    input wire [`INST_DATA_WIDTH-1:0] inst_i,
    input wire [ `REG_DATA_WIDTH-1:0] rs1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] rs2_rdata_i,
    input wire                        is_pred_branch_i,

    // 寄存器写入信息 - 用于HDU检测冒险
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [`REG_ADDR_WIDTH-1:0] reg1_raddr_i,
    input wire [`REG_ADDR_WIDTH-1:0] reg2_raddr_i,
    input wire                       reg_we_i,

    // 从IDU接收额外的CSR信号
    input wire                       csr_we_i,
    input wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_i,

    // 长指令有效信号 - 用于HDU
    input wire rd_access_inst_valid_i,

    // 写回阶段提交信号 - 用于HDU
    input wire                        commit_valid_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // HDU输出信号
    output wire                        hazard_stall_o,
    output wire                        long_inst_atom_lock_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,
    output wire [`INST_ADDR_WIDTH-1:0] pipe_inst_addr_o,
    output wire [`INST_DATA_WIDTH-1:0] pipe_inst_o,
    // 指令有效信号输出
    output wire                        pipe_inst_valid_o,
    // 向其他模块输出的额外信号
    output wire                        pipe_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] pipe_reg_waddr_o,
    output wire                        pipe_csr_we_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] pipe_csr_waddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] pipe_csr_raddr_o,
    output wire [                31:0] pipe_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] pipe_dec_info_bus_o,
    // 寄存rs1/rs2数据
    output wire [                31:0] pipe_rs1_rdata_o,
    output wire [                31:0] pipe_rs2_rdata_o,

    // dispatch to ADDER (第一路)
    output wire        inst1_req_adder_o,
    output wire [31:0] inst1_adder_op1_o,
    output wire [31:0] inst1_adder_op2_o,
    output wire [6:0]  inst1_adder_op_info_o,  // {op_jump, op_sltu, op_slt, op_sub, op_add, op_lui, op_auipc}

    // dispatch to SHIFTER (第一路)
    output wire        inst1_req_shifter_o,
    output wire [31:0] inst1_shifter_op1_o,
    output wire [31:0] inst1_shifter_op2_o,
    output wire [5:0]  inst1_shifter_op_info_o,  // {op_and, op_or, op_xor, op_sra, op_srl, op_sll}

    // dispatch to ADDER (第二路)
    output wire        inst2_req_adder_o,
    output wire [31:0] inst2_adder_op1_o,
    output wire [31:0] inst2_adder_op2_o,
    output wire [6:0]  inst2_adder_op_info_o,  // {op_jump, op_sltu, op_slt, op_sub, op_add, op_lui, op_auipc}

    // dispatch to SHIFTER (第二路)
    output wire        inst2_req_shifter_o,
    output wire [31:0] inst2_shifter_op1_o,
    output wire [31:0] inst2_shifter_op2_o,
    output wire [5:0]  inst2_shifter_op_info_o,  // {op_and, op_or, op_xor, op_sra, op_srl, op_sll}

    // dispatch to Bru (单路，只有第一路)
    output wire        req_bjp_o,
    output wire [31:0] bjp_op1_o,
    output wire [31:0] bjp_op2_o,
    output wire [31:0] bjp_jump_op1_o,
    output wire [31:0] bjp_jump_op2_o,
    output wire        bjp_op_jal_o,
    output wire        bjp_op_beq_o,
    output wire        bjp_op_bne_o,
    output wire        bjp_op_blt_o,
    output wire        bjp_op_bltu_o,
    output wire        bjp_op_bge_o,
    output wire        bjp_op_bgeu_o,
    output wire        bjp_op_jalr_o,

    // dispatch to MULDIV (第一路)
    output wire                        inst1_req_muldiv_o,
    output wire [                31:0] inst1_muldiv_op1_o,
    output wire [                31:0] inst1_muldiv_op2_o,
    output wire                        inst1_muldiv_op_mul_o,
    output wire                        inst1_muldiv_op_mulh_o,
    output wire                        inst1_muldiv_op_mulhsu_o,
    output wire                        inst1_muldiv_op_mulhu_o,
    output wire                        inst1_muldiv_op_div_o,
    output wire                        inst1_muldiv_op_divu_o,
    output wire                        inst1_muldiv_op_rem_o,
    output wire                        inst1_muldiv_op_remu_o,
    output wire                        inst1_muldiv_op_mul_all_o,
    output wire                        inst1_muldiv_op_div_all_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_muldiv_commit_id_o,

    // dispatch to MULDIV (第二路)
    output wire                        inst2_req_muldiv_o,
    output wire [                31:0] inst2_muldiv_op1_o,
    output wire [                31:0] inst2_muldiv_op2_o,
    output wire                        inst2_muldiv_op_mul_o,
    output wire                        inst2_muldiv_op_mulh_o,
    output wire                        inst2_muldiv_op_mulhsu_o,
    output wire                        inst2_muldiv_op_mulhu_o,
    output wire                        inst2_muldiv_op_div_o,
    output wire                        inst2_muldiv_op_divu_o,
    output wire                        inst2_muldiv_op_rem_o,
    output wire                        inst2_muldiv_op_remu_o,
    output wire                        inst2_muldiv_op_mul_all_o,
    output wire                        inst2_muldiv_op_div_all_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_muldiv_commit_id_o,

    // dispatch to CSR (合并单路输出)
    output wire        req_csr_o,
    output wire [31:0] csr_op1_o,
    output wire [31:0] csr_addr_o,
    output wire        csr_csrrw_o,
    output wire        csr_csrrs_o,
    output wire        csr_csrrc_o,

    // dispatch to MEM (第一路)
    output wire                        inst1_req_mem_o,
    output wire                        inst1_mem_op_lb_o,
    output wire                        inst1_mem_op_lh_o,
    output wire                        inst1_mem_op_lw_o,
    output wire                        inst1_mem_op_lbu_o,
    output wire                        inst1_mem_op_lhu_o,
    output wire                        inst1_mem_op_load_o,
    output wire                        inst1_mem_op_store_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_mem_commit_id_o,
    output wire [                31:0] inst1_mem_addr_o,
    output wire [                 7:0] inst1_mem_wmask_o,  // 升级到8位掩码
    output wire [                63:0] inst1_mem_wdata_o,  // 升级到64位数据

    // dispatch to MEM (第二路)
    output wire                        inst2_req_mem_o,
    output wire                        inst2_mem_op_lb_o,
    output wire                        inst2_mem_op_lh_o,
    output wire                        inst2_mem_op_lw_o,
    output wire                        inst2_mem_op_lbu_o,
    output wire                        inst2_mem_op_lhu_o,
    output wire                        inst2_mem_op_load_o,
    output wire                        inst2_mem_op_store_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_mem_commit_id_o,
    output wire [                31:0] inst2_mem_addr_o,
    output wire [                 7:0] inst2_mem_wmask_o,  // 升级到8位掩码
    output wire [                63:0] inst2_mem_wdata_o,  // 升级到64位数据

    // dispatch to SYS (第一路)
    output wire inst1_sys_op_nop_o,
    output wire inst1_sys_op_mret_o,
    output wire inst1_sys_op_ecall_o,
    output wire inst1_sys_op_ebreak_o,
    output wire inst1_sys_op_fence_o,
    output wire inst1_sys_op_dret_o,
    output wire inst1_is_pred_branch_o,
    output wire inst1_misaligned_load_o,
    output wire inst1_misaligned_store_o,
    output wire inst1_illegal_inst_o,

    // dispatch to SYS (第二路)
    output wire inst2_sys_op_nop_o,
    output wire inst2_sys_op_mret_o,
    output wire inst2_sys_op_ecall_o,
    output wire inst2_sys_op_ebreak_o,
    output wire inst2_sys_op_fence_o,
    output wire inst2_sys_op_dret_o,
    output wire inst2_is_pred_branch_o,
    output wire inst2_misaligned_load_o,
    output wire inst2_misaligned_store_o,
    output wire inst2_illegal_inst_o
);

    // 内部连线，用于连接dispatch_logic和dispatch_pipe

    wire [`COMMIT_ID_WIDTH-1:0] hdu_long_inst_id;

    // 第一路dispatch_logic输出信号
    wire                        inst1_logic_req_adder;
    wire [                31:0] inst1_logic_adder_op1;
    wire [                31:0] inst1_logic_adder_op2;
    wire [                 6:0] inst1_logic_adder_op_info;

    wire                        inst1_logic_req_shifter;
    wire [                31:0] inst1_logic_shifter_op1;
    wire [                31:0] inst1_logic_shifter_op2;
    wire [                 5:0] inst1_logic_shifter_op_info;

    wire                        inst1_logic_req_bjp;
    wire [                31:0] inst1_logic_bjp_op1;
    wire [                31:0] inst1_logic_bjp_op2;
    wire [                31:0] inst1_logic_bjp_jump_op1;
    wire [                31:0] inst1_logic_bjp_jump_op2;
    wire                        inst1_logic_bjp_op_jump;
    wire                        inst1_logic_bjp_op_beq;
    wire                        inst1_logic_bjp_op_bne;
    wire                        inst1_logic_bjp_op_blt;
    wire                        inst1_logic_bjp_op_bltu;
    wire                        inst1_logic_bjp_op_bge;
    wire                        inst1_logic_bjp_op_bgeu;
    wire                        inst1_logic_bjp_op_jalr;

    wire                        inst1_logic_req_muldiv;
    wire [                31:0] inst1_logic_muldiv_op1;
    wire [                31:0] inst1_logic_muldiv_op2;
    wire                        inst1_logic_muldiv_op_mul;
    wire                        inst1_logic_muldiv_op_mulh;
    wire                        inst1_logic_muldiv_op_mulhsu;
    wire                        inst1_logic_muldiv_op_mulhu;
    wire                        inst1_logic_muldiv_op_div;
    wire                        inst1_logic_muldiv_op_divu;
    wire                        inst1_logic_muldiv_op_rem;
    wire                        inst1_logic_muldiv_op_remu;
    wire                        inst1_logic_muldiv_op_mul_all;
    wire                        inst1_logic_muldiv_op_div_all;

    wire                        inst1_logic_req_csr;
    wire [                31:0] inst1_logic_csr_op1;
    wire [                31:0] inst1_logic_csr_addr;
    wire                        inst1_logic_csr_csrrw;
    wire                        inst1_logic_csr_csrrs;
    wire                        inst1_logic_csr_csrrc;

    wire                        inst1_logic_req_mem;
    wire                        inst1_logic_mem_op_lb;
    wire                        inst1_logic_mem_op_lh;
    wire                        inst1_logic_mem_op_lw;
    wire                        inst1_logic_mem_op_lbu;
    wire                        inst1_logic_mem_op_lhu;
    wire                        inst1_logic_mem_op_load;
    wire                        inst1_logic_mem_op_store;
    wire [                31:0] inst1_logic_mem_addr;
    wire [                 7:0] inst1_logic_mem_wmask;  // 升级到8位掩码
    wire [                63:0] inst1_logic_mem_wdata;  // 升级到64位数据

    wire                        inst1_logic_sys_op_nop;
    wire                        inst1_logic_sys_op_mret;
    wire                        inst1_logic_sys_op_ecall;
    wire                        inst1_logic_sys_op_ebreak;
    wire                        inst1_logic_sys_op_fence;
    wire                        inst1_logic_sys_op_dret;

    wire                        inst1_logic_misaligned_load;
    wire                        inst1_logic_misaligned_store;

    // 第二路dispatch_logic输出信号
    wire                        inst2_logic_req_adder;
    wire [                31:0] inst2_logic_adder_op1;
    wire [                31:0] inst2_logic_adder_op2;
    wire [                 6:0] inst2_logic_adder_op_info;

    wire                        inst2_logic_req_shifter;
    wire [                31:0] inst2_logic_shifter_op1;
    wire [                31:0] inst2_logic_shifter_op2;
    wire [                 5:0] inst2_logic_shifter_op_info;

    // 第二路的其他模块信号（与第一路相同的输入，但输出将悬空）
    wire                        inst2_logic_req_bjp;
    wire [                31:0] inst2_logic_bjp_op1;
    wire [                31:0] inst2_logic_bjp_op2;
    wire [                31:0] inst2_logic_bjp_jump_op1;
    wire [                31:0] inst2_logic_bjp_jump_op2;
    wire                        inst2_logic_bjp_op_jump;
    wire                        inst2_logic_bjp_op_beq;
    wire                        inst2_logic_bjp_op_bne;
    wire                        inst2_logic_bjp_op_blt;
    wire                        inst2_logic_bjp_op_bltu;
    wire                        inst2_logic_bjp_op_bge;
    wire                        inst2_logic_bjp_op_bgeu;
    wire                        inst2_logic_bjp_op_jalr;

    wire                        inst2_logic_req_muldiv;
    wire [                31:0] inst2_logic_muldiv_op1;
    wire [                31:0] inst2_logic_muldiv_op2;
    wire                        inst2_logic_muldiv_op_mul;
    wire                        inst2_logic_muldiv_op_mulh;
    wire                        inst2_logic_muldiv_op_mulhsu;
    wire                        inst2_logic_muldiv_op_mulhu;
    wire                        inst2_logic_muldiv_op_div;
    wire                        inst2_logic_muldiv_op_divu;
    wire                        inst2_logic_muldiv_op_rem;
    wire                        inst2_logic_muldiv_op_remu;
    wire                        inst2_logic_muldiv_op_mul_all;
    wire                        inst2_logic_muldiv_op_div_all;

    wire                        inst2_logic_req_csr;
    wire [                31:0] inst2_logic_csr_op1;
    wire [                31:0] inst2_logic_csr_addr;
    wire                        inst2_logic_csr_csrrw;
    wire                        inst2_logic_csr_csrrs;
    wire                        inst2_logic_csr_csrrc;

    wire                        inst2_logic_req_mem;
    wire                        inst2_logic_mem_op_lb;
    wire                        inst2_logic_mem_op_lh;
    wire                        inst2_logic_mem_op_lw;
    wire                        inst2_logic_mem_op_lbu;
    wire                        inst2_logic_mem_op_lhu;
    wire                        inst2_logic_mem_op_load;
    wire                        inst2_logic_mem_op_store;
    wire [                31:0] inst2_logic_mem_addr;
    wire [                 7:0] inst2_logic_mem_wmask;  // 升级到8位掩码
    wire [                63:0] inst2_logic_mem_wdata;  // 升级到64位数据

    wire                        inst2_logic_sys_op_nop;
    wire                        inst2_logic_sys_op_mret;
    wire                        inst2_logic_sys_op_ecall;
    wire                        inst2_logic_sys_op_ebreak;
    wire                        inst2_logic_sys_op_fence;
    wire                        inst2_logic_sys_op_dret;

    wire                        inst2_logic_misaligned_load;
    wire                        inst2_logic_misaligned_store;

    assign inst1_mem_commit_id_o    = commit_id_o;  // 将HDU的commit_id输出到第一路MEM模块
    assign inst1_muldiv_commit_id_o = commit_id_o;  // 将HDU的commit_id输出到第一路MULDIV模块
    assign inst2_mem_commit_id_o    = commit_id_o;  // 将HDU的commit_id输出到第二路MEM模块
    assign inst2_muldiv_commit_id_o = commit_id_o;  // 将HDU的commit_id输出到第二路MULDIV模块
    // 实例化HDU模块
    hdu u_hdu (
        .clk                  (clk),
        .rst_n                (rst_n),
        .inst_valid           (rd_access_inst_valid_i),
        .new_inst_rd_addr     (reg_waddr_i),
        .new_inst_rs1_addr    (reg1_raddr_i),
        .new_inst_rs2_addr    (reg2_raddr_i),
        .new_inst_rd_we       (reg_we_i),
        .commit_valid_i       (commit_valid_i),
        .commit_id_i          (commit_id_i),
        .hazard_stall_o       (hazard_stall_o),
        .commit_id_o          (hdu_long_inst_id),
        .long_inst_atom_lock_o(long_inst_atom_lock_o)
    );

    // 实例化dispatch_logic模块 (第一路)
    dispatch_logic u_inst1_dispatch_logic (
        .dec_info_bus_i(dec_info_bus_i),
        .dec_imm_i     (dec_imm_i),
        .dec_pc_i      (dec_pc_i),
        .rs1_rdata_i   (rs1_rdata_i),
        .rs2_rdata_i   (rs2_rdata_i),

        // ADDER信号
        .req_adder_o    (inst1_logic_req_adder),
        .adder_op1_o    (inst1_logic_adder_op1),
        .adder_op2_o    (inst1_logic_adder_op2),
        .adder_op_info_o(inst1_logic_adder_op_info),

        // SHIFTER信号
        .req_shifter_o    (inst1_logic_req_shifter),
        .shifter_op1_o    (inst1_logic_shifter_op1),
        .shifter_op2_o    (inst1_logic_shifter_op2),
        .shifter_op_info_o(inst1_logic_shifter_op_info),

        // BJP信号
        .req_bjp_o     (inst1_logic_req_bjp),
        .bjp_op1_o     (inst1_logic_bjp_op1),
        .bjp_op2_o     (inst1_logic_bjp_op2),
        .bjp_jump_op1_o(inst1_logic_bjp_jump_op1),
        .bjp_jump_op2_o(inst1_logic_bjp_jump_op2),
        .bjp_op_jump_o (inst1_logic_bjp_op_jump),
        .bjp_op_beq_o  (inst1_logic_bjp_op_beq),
        .bjp_op_bne_o  (inst1_logic_bjp_op_bne),
        .bjp_op_blt_o  (inst1_logic_bjp_op_blt),
        .bjp_op_bltu_o (inst1_logic_bjp_op_bltu),
        .bjp_op_bge_o  (inst1_logic_bjp_op_bge),
        .bjp_op_bgeu_o (inst1_logic_bjp_op_bgeu),
        .bjp_op_jalr_o (inst1_logic_bjp_op_jalr),

        // MULDIV信号
        .req_muldiv_o       (inst1_logic_req_muldiv),
        .muldiv_op1_o       (inst1_logic_muldiv_op1),
        .muldiv_op2_o       (inst1_logic_muldiv_op2),
        .muldiv_op_mul_o    (inst1_logic_muldiv_op_mul),
        .muldiv_op_mulh_o   (inst1_logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_o (inst1_logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_o  (inst1_logic_muldiv_op_mulhu),
        .muldiv_op_div_o    (inst1_logic_muldiv_op_div),
        .muldiv_op_divu_o   (inst1_logic_muldiv_op_divu),
        .muldiv_op_rem_o    (inst1_logic_muldiv_op_rem),
        .muldiv_op_remu_o   (inst1_logic_muldiv_op_remu),
        .muldiv_op_mul_all_o(inst1_logic_muldiv_op_mul_all),
        .muldiv_op_div_all_o(inst1_logic_muldiv_op_div_all),

        // CSR信号
        .req_csr_o  (inst1_logic_req_csr),
        .csr_op1_o  (inst1_logic_csr_op1),
        .csr_addr_o (inst1_logic_csr_addr),
        .csr_csrrw_o(inst1_logic_csr_csrrw),
        .csr_csrrs_o(inst1_logic_csr_csrrs),
        .csr_csrrc_o(inst1_logic_csr_csrrc),

        // MEM信号
        .req_mem_o     (inst1_logic_req_mem),
        .mem_op_lb_o   (inst1_logic_mem_op_lb),
        .mem_op_lh_o   (inst1_logic_mem_op_lh),
        .mem_op_lw_o   (inst1_logic_mem_op_lw),
        .mem_op_lbu_o  (inst1_logic_mem_op_lbu),
        .mem_op_lhu_o  (inst1_logic_mem_op_lhu),
        .mem_op_load_o (inst1_logic_mem_op_load),
        .mem_op_store_o(inst1_logic_mem_op_store),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_o    (inst1_logic_mem_addr),
        .mem_wmask_o   (inst1_logic_mem_wmask),
        .mem_wdata_o   (inst1_logic_mem_wdata),

        // SYS信号
        .sys_op_nop_o   (inst1_logic_sys_op_nop),
        .sys_op_mret_o  (inst1_logic_sys_op_mret),
        .sys_op_ecall_o (inst1_logic_sys_op_ecall),
        .sys_op_ebreak_o(inst1_logic_sys_op_ebreak),
        .sys_op_fence_o (inst1_logic_sys_op_fence),
        .sys_op_dret_o  (inst1_logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_o (inst1_logic_misaligned_load),
        .misaligned_store_o(inst1_logic_misaligned_store)
    );

    // 实例化dispatch_logic模块 (第二路)
    dispatch_logic u_inst2_dispatch_logic (
        .dec_info_bus_i(dec_info_bus_i),
        .dec_imm_i     (dec_imm_i),
        .dec_pc_i      (dec_pc_i),
        .rs1_rdata_i   (rs1_rdata_i),
        .rs2_rdata_i   (rs2_rdata_i),

        // ADDER信号
        .req_adder_o    (inst2_logic_req_adder),
        .adder_op1_o    (inst2_logic_adder_op1),
        .adder_op2_o    (inst2_logic_adder_op2),
        .adder_op_info_o(inst2_logic_adder_op_info),

        // SHIFTER信号
        .req_shifter_o    (inst2_logic_req_shifter),
        .shifter_op1_o    (inst2_logic_shifter_op1),
        .shifter_op2_o    (inst2_logic_shifter_op2),
        .shifter_op_info_o(inst2_logic_shifter_op_info),

        // BJP信号
        .req_bjp_o     (inst2_logic_req_bjp),
        .bjp_op1_o     (inst2_logic_bjp_op1),
        .bjp_op2_o     (inst2_logic_bjp_op2),
        .bjp_jump_op1_o(inst2_logic_bjp_jump_op1),
        .bjp_jump_op2_o(inst2_logic_bjp_jump_op2),
        .bjp_op_jump_o (inst2_logic_bjp_op_jump),
        .bjp_op_beq_o  (inst2_logic_bjp_op_beq),
        .bjp_op_bne_o  (inst2_logic_bjp_op_bne),
        .bjp_op_blt_o  (inst2_logic_bjp_op_blt),
        .bjp_op_bltu_o (inst2_logic_bjp_op_bltu),
        .bjp_op_bge_o  (inst2_logic_bjp_op_bge),
        .bjp_op_bgeu_o (inst2_logic_bjp_op_bgeu),
        .bjp_op_jalr_o (inst2_logic_bjp_op_jalr),

        // MULDIV信号
        .req_muldiv_o       (inst2_logic_req_muldiv),
        .muldiv_op1_o       (inst2_logic_muldiv_op1),
        .muldiv_op2_o       (inst2_logic_muldiv_op2),
        .muldiv_op_mul_o    (inst2_logic_muldiv_op_mul),
        .muldiv_op_mulh_o   (inst2_logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_o (inst2_logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_o  (inst2_logic_muldiv_op_mulhu),
        .muldiv_op_div_o    (inst2_logic_muldiv_op_div),
        .muldiv_op_divu_o   (inst2_logic_muldiv_op_divu),
        .muldiv_op_rem_o    (inst2_logic_muldiv_op_rem),
        .muldiv_op_remu_o   (inst2_logic_muldiv_op_remu),
        .muldiv_op_mul_all_o(inst2_logic_muldiv_op_mul_all),
        .muldiv_op_div_all_o(inst2_logic_muldiv_op_div_all),

        // CSR信号
        .req_csr_o  (inst2_logic_req_csr),
        .csr_op1_o  (inst2_logic_csr_op1),
        .csr_addr_o (inst2_logic_csr_addr),
        .csr_csrrw_o(inst2_logic_csr_csrrw),
        .csr_csrrs_o(inst2_logic_csr_csrrs),
        .csr_csrrc_o(inst2_logic_csr_csrrc),

        // MEM信号
        .req_mem_o     (inst2_logic_req_mem),
        .mem_op_lb_o   (inst2_logic_mem_op_lb),
        .mem_op_lh_o   (inst2_logic_mem_op_lh),
        .mem_op_lw_o   (inst2_logic_mem_op_lw),
        .mem_op_lbu_o  (inst2_logic_mem_op_lbu),
        .mem_op_lhu_o  (inst2_logic_mem_op_lhu),
        .mem_op_load_o (inst2_logic_mem_op_load),
        .mem_op_store_o(inst2_logic_mem_op_store),
        .mem_addr_o    (inst2_logic_mem_addr),
        .mem_wmask_o   (inst2_logic_mem_wmask),
        .mem_wdata_o   (inst2_logic_mem_wdata),

        // SYS信号
        .sys_op_nop_o   (inst2_logic_sys_op_nop),
        .sys_op_mret_o  (inst2_logic_sys_op_mret),
        .sys_op_ecall_o (inst2_logic_sys_op_ecall),
        .sys_op_ebreak_o(inst2_logic_sys_op_ebreak),
        .sys_op_fence_o (inst2_logic_sys_op_fence),
        .sys_op_dret_o  (inst2_logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_o (inst2_logic_misaligned_load),
        .misaligned_store_o(inst2_logic_misaligned_store)
    );

    // 实例化dispatch_pipe模块 (第一路)
    dispatch_pipe u_inst1_dispatch_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_flag_i(stall_flag_i),

        .inst_valid_i(inst_valid_i),
        .inst_addr_i (dec_pc_i),
        .inst_i      (inst_i),
        .commit_id_i (hdu_long_inst_id),

        // 额外的IDU信号输入
        .reg_we_i        (reg_we_i),
        .reg_waddr_i     (reg_waddr_i),
        .csr_we_i        (csr_we_i),
        .csr_waddr_i     (csr_waddr_i),
        .csr_raddr_i     (csr_raddr_i),
        .dec_imm_i       (dec_imm_i),
        .dec_info_bus_i  (dec_info_bus_i),
        // 寄存rs1/rs2数据
        .rs1_rdata_i     (rs1_rdata_i),
        .rs2_rdata_i     (rs2_rdata_i),
        .is_pred_branch_i(is_pred_branch_i),  // 连接预测分支信号输入
        // 新增：非法指令信号输入
        .illegal_inst_i  (illegal_inst_i),

        // ADDER信号输入
        .req_adder_i    (inst1_logic_req_adder),
        .adder_op1_i    (inst1_logic_adder_op1),
        .adder_op2_i    (inst1_logic_adder_op2),
        .adder_op_info_i(inst1_logic_adder_op_info),

        // SHIFTER信号输入
        .req_shifter_i    (inst1_logic_req_shifter),
        .shifter_op1_i    (inst1_logic_shifter_op1),
        .shifter_op2_i    (inst1_logic_shifter_op2),
        .shifter_op_info_i(inst1_logic_shifter_op_info),

        // BJP信号输入 (只使用第一路)
        .req_bjp_i     (inst1_logic_req_bjp),
        .bjp_op1_i     (inst1_logic_bjp_op1),
        .bjp_op2_i     (inst1_logic_bjp_op2),
        .bjp_jump_op1_i(inst1_logic_bjp_jump_op1),
        .bjp_jump_op2_i(inst1_logic_bjp_jump_op2),
        .bjp_op_jump_i (inst1_logic_bjp_op_jump),
        .bjp_op_beq_i  (inst1_logic_bjp_op_beq),
        .bjp_op_bne_i  (inst1_logic_bjp_op_bne),
        .bjp_op_blt_i  (inst1_logic_bjp_op_blt),
        .bjp_op_bltu_i (inst1_logic_bjp_op_bltu),
        .bjp_op_bge_i  (inst1_logic_bjp_op_bge),
        .bjp_op_bgeu_i (inst1_logic_bjp_op_bgeu),
        .bjp_op_jalr_i (inst1_logic_bjp_op_jalr),

        // MULDIV信号输入
        .req_muldiv_i       (inst1_logic_req_muldiv),
        .muldiv_op1_i       (inst1_logic_muldiv_op1),
        .muldiv_op2_i       (inst1_logic_muldiv_op2),
        .muldiv_op_mul_i    (inst1_logic_muldiv_op_mul),
        .muldiv_op_mulh_i   (inst1_logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_i (inst1_logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_i  (inst1_logic_muldiv_op_mulhu),
        .muldiv_op_div_i    (inst1_logic_muldiv_op_div),
        .muldiv_op_divu_i   (inst1_logic_muldiv_op_divu),
        .muldiv_op_rem_i    (inst1_logic_muldiv_op_rem),
        .muldiv_op_remu_i   (inst1_logic_muldiv_op_remu),
        .muldiv_op_mul_all_i(inst1_logic_muldiv_op_mul_all),
        .muldiv_op_div_all_i(inst1_logic_muldiv_op_div_all),

        // CSR信号输入
        .req_csr_i  (inst1_logic_req_csr),
        .csr_op1_i  (inst1_logic_csr_op1),
        .csr_addr_i (inst1_logic_csr_addr),
        .csr_csrrw_i(inst1_logic_csr_csrrw),
        .csr_csrrs_i(inst1_logic_csr_csrrs),
        .csr_csrrc_i(inst1_logic_csr_csrrc),

        // MEM信号输入
        .req_mem_i     (inst1_logic_req_mem),
        .mem_op_lb_i   (inst1_logic_mem_op_lb),
        .mem_op_lh_i   (inst1_logic_mem_op_lh),
        .mem_op_lw_i   (inst1_logic_mem_op_lw),
        .mem_op_lbu_i  (inst1_logic_mem_op_lbu),
        .mem_op_lhu_i  (inst1_logic_mem_op_lhu),
        .mem_op_load_i (inst1_logic_mem_op_load),
        .mem_op_store_i(inst1_logic_mem_op_store),
        .mem_addr_i    (inst1_logic_mem_addr),
        .mem_wmask_i   (inst1_logic_mem_wmask),
        .mem_wdata_i   (inst1_logic_mem_wdata),

        // SYS信号输入
        .sys_op_nop_i   (inst1_logic_sys_op_nop),
        .sys_op_mret_i  (inst1_logic_sys_op_mret),
        .sys_op_ecall_i (inst1_logic_sys_op_ecall),
        .sys_op_ebreak_i(inst1_logic_sys_op_ebreak),
        .sys_op_fence_i (inst1_logic_sys_op_fence),
        .sys_op_dret_i  (inst1_logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_i (inst1_logic_misaligned_load),
        .misaligned_store_i(inst1_logic_misaligned_store),

        // 指令地址和ID输出
        .inst_addr_o   (pipe_inst_addr_o),
        .inst_o        (pipe_inst_o),
        .commit_id_o   (commit_id_o),
        .inst_valid_o  (pipe_inst_valid_o),
        // 额外的IDU信号输出
        .reg_we_o      (pipe_reg_we_o),
        .reg_waddr_o   (pipe_reg_waddr_o),
        .csr_we_o      (pipe_csr_we_o),
        .csr_waddr_o   (pipe_csr_waddr_o),
        .csr_raddr_o   (pipe_csr_raddr_o),
        .dec_imm_o     (pipe_dec_imm_o),
        .dec_info_bus_o(pipe_dec_info_bus_o),
        // 寄存rs1/rs2数据
        .rs1_rdata_o   (pipe_rs1_rdata_o),
        .rs2_rdata_o   (pipe_rs2_rdata_o),

        // ADDER信号输出 (第一路)
        .req_adder_o    (inst1_req_adder_o),
        .adder_op1_o    (inst1_adder_op1_o),
        .adder_op2_o    (inst1_adder_op2_o),
        .adder_op_info_o(inst1_adder_op_info_o),

        // SHIFTER信号输出 (第一路)
        .req_shifter_o    (inst1_req_shifter_o),
        .shifter_op1_o    (inst1_shifter_op1_o),
        .shifter_op2_o    (inst1_shifter_op2_o),
        .shifter_op_info_o(inst1_shifter_op_info_o),

        // BJP信号输出
        .req_bjp_o     (req_bjp_o),
        .bjp_op1_o     (bjp_op1_o),
        .bjp_op2_o     (bjp_op2_o),
        .bjp_jump_op1_o(bjp_jump_op1_o),
        .bjp_jump_op2_o(bjp_jump_op2_o),
        .bjp_op_jal_o  (bjp_op_jal_o),
        .bjp_op_beq_o  (bjp_op_beq_o),
        .bjp_op_bne_o  (bjp_op_bne_o),
        .bjp_op_blt_o  (bjp_op_blt_o),
        .bjp_op_bltu_o (bjp_op_bltu_o),
        .bjp_op_bge_o  (bjp_op_bge_o),
        .bjp_op_bgeu_o (bjp_op_bgeu_o),
        .bjp_op_jalr_o (bjp_op_jalr_o),

        // MULDIV信号输出 (第一路)
        .req_muldiv_o       (inst1_req_muldiv_o),
        .muldiv_op1_o       (inst1_muldiv_op1_o),
        .muldiv_op2_o       (inst1_muldiv_op2_o),
        .muldiv_op_mul_o    (inst1_muldiv_op_mul_o),
        .muldiv_op_mulh_o   (inst1_muldiv_op_mulh_o),
        .muldiv_op_mulhsu_o (inst1_muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_o  (inst1_muldiv_op_mulhu_o),
        .muldiv_op_div_o    (inst1_muldiv_op_div_o),
        .muldiv_op_divu_o   (inst1_muldiv_op_divu_o),
        .muldiv_op_rem_o    (inst1_muldiv_op_rem_o),
        .muldiv_op_remu_o   (inst1_muldiv_op_remu_o),
        .muldiv_op_mul_all_o(inst1_muldiv_op_mul_all_o),
        .muldiv_op_div_all_o(inst1_muldiv_op_div_all_o),

        // CSR信号输出 (第一路)
        .req_csr_o  (inst1_req_csr),
        .csr_op1_o  (inst1_csr_op1),
        .csr_addr_o (inst1_csr_addr),
        .csr_csrrw_o(inst1_csr_csrrw),
        .csr_csrrs_o(inst1_csr_csrrs),
        .csr_csrrc_o(inst1_csr_csrrc),

        // MEM信号输出 (第一路)
        .req_mem_o     (inst1_req_mem_o),
        .mem_op_lb_o   (inst1_mem_op_lb_o),
        .mem_op_lh_o   (inst1_mem_op_lh_o),
        .mem_op_lw_o   (inst1_mem_op_lw_o),
        .mem_op_lbu_o  (inst1_mem_op_lbu_o),
        .mem_op_lhu_o  (inst1_mem_op_lhu_o),
        .mem_op_load_o (inst1_mem_op_load_o),
        .mem_op_store_o(inst1_mem_op_store_o),
        .mem_addr_o    (inst1_mem_addr_o),
        .mem_wmask_o   (inst1_mem_wmask_o),
        .mem_wdata_o   (inst1_mem_wdata_o),

        // SYS信号输出 (第一路)
        .sys_op_nop_o      (inst1_sys_op_nop_o),
        .sys_op_mret_o     (inst1_sys_op_mret_o),
        .sys_op_ecall_o    (inst1_sys_op_ecall_o),
        .sys_op_ebreak_o   (inst1_sys_op_ebreak_o),
        .sys_op_fence_o    (inst1_sys_op_fence_o),
        .sys_op_dret_o     (inst1_sys_op_dret_o),
        .is_pred_branch_o  (is_pred_branch_o),   // 连接预测分支信号输出
        .misaligned_load_o (misaligned_load_o),
        .misaligned_store_o(misaligned_store_o),
        .illegal_inst_o    (illegal_inst_o)       // 新增：非法指令信号输出
    );

    // 实例化dispatch_pipe模块 (第二路) - 只连接ADDER和SHIFTER输出
    // 为第二路创建悬空的输出信号
    wire [`INST_ADDR_WIDTH-1:0] inst2_pipe_inst_addr;
    wire [`INST_DATA_WIDTH-1:0] inst2_pipe_inst;
    wire [`COMMIT_ID_WIDTH-1:0] inst2_pipe_commit_id;
    wire                        inst2_pipe_inst_valid;
    wire                        inst2_pipe_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] inst2_pipe_reg_waddr;
    wire                        inst2_pipe_csr_we;
    wire [ `BUS_ADDR_WIDTH-1:0] inst2_pipe_csr_waddr;
    wire [ `BUS_ADDR_WIDTH-1:0] inst2_pipe_csr_raddr;
    wire [                31:0] inst2_pipe_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] inst2_pipe_dec_info_bus;
    wire [                31:0] inst2_pipe_rs1_rdata;
    wire [                31:0] inst2_pipe_rs2_rdata;

    // 第二路的其他模块输出信号（悬空）
    wire        inst2_req_bjp;
    wire [31:0] inst2_bjp_op1;
    wire [31:0] inst2_bjp_op2;
    wire [31:0] inst2_bjp_jump_op1;
    wire [31:0] inst2_bjp_jump_op2;
    wire        inst2_bjp_op_jump;
    wire        inst2_bjp_op_beq;
    wire        inst2_bjp_op_bne;
    wire        inst2_bjp_op_blt;
    wire        inst2_bjp_op_bltu;
    wire        inst2_bjp_op_bge;
    wire        inst2_bjp_op_bgeu;
    wire        inst2_bjp_op_jalr;

    wire                        inst2_req_muldiv;
    wire [                31:0] inst2_muldiv_op1;
    wire [                31:0] inst2_muldiv_op2;
    wire                        inst2_muldiv_op_mul;
    wire                        inst2_muldiv_op_mulh;
    wire                        inst2_muldiv_op_mulhsu;
    wire                        inst2_muldiv_op_mulhu;
    wire                        inst2_muldiv_op_div;
    wire                        inst2_muldiv_op_divu;
    wire                        inst2_muldiv_op_rem;
    wire                        inst2_muldiv_op_remu;
    wire                        inst2_muldiv_op_mul_all;
    wire                        inst2_muldiv_op_div_all;

    wire        inst2_req_csr;
    wire [31:0] inst2_csr_op1;
    wire [31:0] inst2_csr_addr;
    wire        inst2_csr_csrrw;
    wire        inst2_csr_csrrs;
    wire        inst2_csr_csrrc;

    // 第一路CSR内部信号
    wire        inst1_req_csr;
    wire [31:0] inst1_csr_op1;
    wire [31:0] inst1_csr_addr;
    wire        inst1_csr_csrrw;
    wire        inst1_csr_csrrs;
    wire        inst1_csr_csrrc;

    wire                        inst2_req_mem;
    wire                        inst2_mem_op_lb;
    wire                        inst2_mem_op_lh;
    wire                        inst2_mem_op_lw;
    wire                        inst2_mem_op_lbu;
    wire                        inst2_mem_op_lhu;
    wire                        inst2_mem_op_load;
    wire                        inst2_mem_op_store;
    wire [                31:0] inst2_mem_addr;
    wire [                 3:0] inst2_mem_wmask;
    wire [                31:0] inst2_mem_wdata;

    wire        inst2_sys_op_nop;
    wire        inst2_sys_op_mret;
    wire        inst2_sys_op_ecall;
    wire        inst2_sys_op_ebreak;
    wire        inst2_sys_op_fence;
    wire        inst2_sys_op_dret;
    wire        inst2_is_pred_branch;
    wire        inst2_misaligned_load;
    wire        inst2_misaligned_store;
    wire        inst2_illegal_inst;

    dispatch_pipe u_inst2_dispatch_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_flag_i(stall_flag_i),

        .inst_valid_i(inst_valid_i),
        .inst_addr_i (dec_pc_i),
        .inst_i      (inst_i),
        .commit_id_i (hdu_long_inst_id),

        // 额外的IDU信号输入
        .reg_we_i        (reg_we_i),
        .reg_waddr_i     (reg_waddr_i),
        .csr_we_i        (csr_we_i),
        .csr_waddr_i     (csr_waddr_i),
        .csr_raddr_i     (csr_raddr_i),
        .dec_imm_i       (dec_imm_i),
        .dec_info_bus_i  (dec_info_bus_i),
        // 寄存rs1/rs2数据
        .rs1_rdata_i     (rs1_rdata_i),
        .rs2_rdata_i     (rs2_rdata_i),
        .is_pred_branch_i(is_pred_branch_i),
        .illegal_inst_i  (illegal_inst_i),

        // ADDER信号输入
        .req_adder_i    (inst2_logic_req_adder),
        .adder_op1_i    (inst2_logic_adder_op1),
        .adder_op2_i    (inst2_logic_adder_op2),
        .adder_op_info_i(inst2_logic_adder_op_info),

        // SHIFTER信号输入
        .req_shifter_i    (inst2_logic_req_shifter),
        .shifter_op1_i    (inst2_logic_shifter_op1),
        .shifter_op2_i    (inst2_logic_shifter_op2),
        .shifter_op_info_i(inst2_logic_shifter_op_info),

        // BJP信号输入 (连接第二路信号，但第二路BJP为0)
        .req_bjp_i     (inst2_logic_req_bjp),
        .bjp_op1_i     (inst2_logic_bjp_op1),
        .bjp_op2_i     (inst2_logic_bjp_op2),
        .bjp_jump_op1_i(inst2_logic_bjp_jump_op1),
        .bjp_jump_op2_i(inst2_logic_bjp_jump_op2),
        .bjp_op_jump_i (inst2_logic_bjp_op_jump),
        .bjp_op_beq_i  (inst2_logic_bjp_op_beq),
        .bjp_op_bne_i  (inst2_logic_bjp_op_bne),
        .bjp_op_blt_i  (inst2_logic_bjp_op_blt),
        .bjp_op_bltu_i (inst2_logic_bjp_op_bltu),
        .bjp_op_bge_i  (inst2_logic_bjp_op_bge),
        .bjp_op_bgeu_i (inst2_logic_bjp_op_bgeu),
        .bjp_op_jalr_i (inst2_logic_bjp_op_jalr),

        // MULDIV信号输入
        .req_muldiv_i       (inst2_logic_req_muldiv),
        .muldiv_op1_i       (inst2_logic_muldiv_op1),
        .muldiv_op2_i       (inst2_logic_muldiv_op2),
        .muldiv_op_mul_i    (inst2_logic_muldiv_op_mul),
        .muldiv_op_mulh_i   (inst2_logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_i (inst2_logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_i  (inst2_logic_muldiv_op_mulhu),
        .muldiv_op_div_i    (inst2_logic_muldiv_op_div),
        .muldiv_op_divu_i   (inst2_logic_muldiv_op_divu),
        .muldiv_op_rem_i    (inst2_logic_muldiv_op_rem),
        .muldiv_op_remu_i   (inst2_logic_muldiv_op_remu),
        .muldiv_op_mul_all_i(inst2_logic_muldiv_op_mul_all),
        .muldiv_op_div_all_i(inst2_logic_muldiv_op_div_all),

        // CSR信号输入
        .req_csr_i  (inst2_logic_req_csr),
        .csr_op1_i  (inst2_logic_csr_op1),
        .csr_addr_i (inst2_logic_csr_addr),
        .csr_csrrw_i(inst2_logic_csr_csrrw),
        .csr_csrrs_i(inst2_logic_csr_csrrs),
        .csr_csrrc_i(inst2_logic_csr_csrrc),

        // MEM信号输入
        .req_mem_i     (inst2_logic_req_mem),
        .mem_op_lb_i   (inst2_logic_mem_op_lb),
        .mem_op_lh_i   (inst2_logic_mem_op_lh),
        .mem_op_lw_i   (inst2_logic_mem_op_lw),
        .mem_op_lbu_i  (inst2_logic_mem_op_lbu),
        .mem_op_lhu_i  (inst2_logic_mem_op_lhu),
        .mem_op_load_i (inst2_logic_mem_op_load),
        .mem_op_store_i(inst2_logic_mem_op_store),
        .mem_addr_i    (inst2_logic_mem_addr),
        .mem_wmask_i   (inst2_logic_mem_wmask),
        .mem_wdata_i   (inst2_logic_mem_wdata),

        // SYS信号输入
        .sys_op_nop_i   (inst2_logic_sys_op_nop),
        .sys_op_mret_i  (inst2_logic_sys_op_mret),
        .sys_op_ecall_i (inst2_logic_sys_op_ecall),
        .sys_op_ebreak_i(inst2_logic_sys_op_ebreak),
        .sys_op_fence_i (inst2_logic_sys_op_fence),
        .sys_op_dret_i  (inst2_logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_i (inst2_logic_misaligned_load),
        .misaligned_store_i(inst2_logic_misaligned_store),

        // 输出信号（悬空，除了ADDER和SHIFTER）
        .inst_addr_o   (inst2_pipe_inst_addr),
        .inst_o        (inst2_pipe_inst),
        .commit_id_o   (inst2_pipe_commit_id),
        .inst_valid_o  (inst2_pipe_inst_valid),
        .reg_we_o      (inst2_pipe_reg_we),
        .reg_waddr_o   (inst2_pipe_reg_waddr),
        .csr_we_o      (inst2_pipe_csr_we),
        .csr_waddr_o   (inst2_pipe_csr_waddr),
        .csr_raddr_o   (inst2_pipe_csr_raddr),
        .dec_imm_o     (inst2_pipe_dec_imm),
        .dec_info_bus_o(inst2_pipe_dec_info_bus),
        .rs1_rdata_o   (inst2_pipe_rs1_rdata),
        .rs2_rdata_o   (inst2_pipe_rs2_rdata),

        // ADDER信号输出 (第二路) - 连接到模块输出端口
        .req_adder_o    (inst2_req_adder_o),
        .adder_op1_o    (inst2_adder_op1_o),
        .adder_op2_o    (inst2_adder_op2_o),
        .adder_op_info_o(inst2_adder_op_info_o),

        // SHIFTER信号输出 (第二路) - 连接到模块输出端口
        .req_shifter_o    (inst2_req_shifter_o),
        .shifter_op1_o    (inst2_shifter_op1_o),
        .shifter_op2_o    (inst2_shifter_op2_o),
        .shifter_op_info_o(inst2_shifter_op_info_o),

        // BJP信号输出 (悬空，第二路不使用BJP)
        .req_bjp_o     (inst2_req_bjp),
        .bjp_op1_o     (inst2_bjp_op1),
        .bjp_op2_o     (inst2_bjp_op2),
        .bjp_jump_op1_o(inst2_bjp_jump_op1),
        .bjp_jump_op2_o(inst2_bjp_jump_op2),
        .bjp_op_jump_o (inst2_bjp_op_jump),
        .bjp_op_beq_o  (inst2_bjp_op_beq),
        .bjp_op_bne_o  (inst2_bjp_op_bne),
        .bjp_op_blt_o  (inst2_bjp_op_blt),
        .bjp_op_bltu_o (inst2_bjp_op_bltu),
        .bjp_op_bge_o  (inst2_bjp_op_bge),
        .bjp_op_bgeu_o (inst2_bjp_op_bgeu),
        .bjp_op_jalr_o (inst2_bjp_op_jalr),

        // MULDIV信号输出 (第二路)
        .req_muldiv_o       (inst2_req_muldiv_o),
        .muldiv_op1_o       (inst2_muldiv_op1_o),
        .muldiv_op2_o       (inst2_muldiv_op2_o),
        .muldiv_op_mul_o    (inst2_muldiv_op_mul_o),
        .muldiv_op_mulh_o   (inst2_muldiv_op_mulh_o),
        .muldiv_op_mulhsu_o (inst2_muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_o  (inst2_muldiv_op_mulhu_o),
        .muldiv_op_div_o    (inst2_muldiv_op_div_o),
        .muldiv_op_divu_o   (inst2_muldiv_op_divu_o),
        .muldiv_op_rem_o    (inst2_muldiv_op_rem_o),
        .muldiv_op_remu_o   (inst2_muldiv_op_remu_o),
        .muldiv_op_mul_all_o(inst2_muldiv_op_mul_all_o),
        .muldiv_op_div_all_o(inst2_muldiv_op_div_all_o),

        // CSR信号输出 (第二路)
        .req_csr_o  (inst2_req_csr),
        .csr_op1_o  (inst2_csr_op1),
        .csr_addr_o (inst2_csr_addr),
        .csr_csrrw_o(inst2_csr_csrrw),
        .csr_csrrs_o(inst2_csr_csrrs),
        .csr_csrrc_o(inst2_csr_csrrc),

        // MEM信号输出 (第二路)
        .req_mem_o     (inst2_req_mem_o),
        .mem_op_lb_o   (inst2_mem_op_lb_o),
        .mem_op_lh_o   (inst2_mem_op_lh_o),
        .mem_op_lw_o   (inst2_mem_op_lw_o),
        .mem_op_lbu_o  (inst2_mem_op_lbu_o),
        .mem_op_lhu_o  (inst2_mem_op_lhu_o),
        .mem_op_load_o (inst2_mem_op_load_o),
        .mem_op_store_o(inst2_mem_op_store_o),
        .mem_addr_o    (inst2_mem_addr_o),
        .mem_wmask_o   (inst2_mem_wmask_o),
        .mem_wdata_o   (inst2_mem_wdata_o),

        // SYS信号输出 (第二路)
        .sys_op_nop_o      (inst2_sys_op_nop_o),
        .sys_op_mret_o     (inst2_sys_op_mret_o),
        .sys_op_ecall_o    (inst2_sys_op_ecall_o),
        .sys_op_ebreak_o   (inst2_sys_op_ebreak_o),
        .sys_op_fence_o    (inst2_sys_op_fence_o),
        .sys_op_dret_o     (inst2_sys_op_dret_o),
        .is_pred_branch_o  (inst2_is_pred_branch),
        .misaligned_load_o (inst2_misaligned_load),
        .misaligned_store_o(inst2_misaligned_store),
        .illegal_inst_o    (inst2_illegal_inst)
    );

    // CSR合并逻辑
    // 由于ICU已经处理了两个指令都是CSR的情况（通过RAW冒险检测），
    // 这里只需要简单的OR逻辑来合并两路CSR输出
    // 优先级：如果第一路有有效的CSR请求，则使用第一路；否则使用第二路
    assign req_csr_o = inst1_req_csr | inst2_req_csr;
    
    // 当第一路有CSR请求时，使用第一路的信号；否则使用第二路的信号
    assign csr_op1_o  = inst1_req_csr ? inst1_csr_op1  : inst2_csr_op1;
    assign csr_addr_o = inst1_req_csr ? inst1_csr_addr : inst2_csr_addr;
    assign csr_csrrw_o = inst1_req_csr ? inst1_csr_csrrw : inst2_csr_csrrw;
    assign csr_csrrs_o = inst1_req_csr ? inst1_csr_csrrs : inst2_csr_csrrs;
    assign csr_csrrc_o = inst1_req_csr ? inst1_csr_csrrc : inst2_csr_csrrc;

    // 实例化dispatch_pipe模块 (第二路) - 只连接ADDER和SHIFTER输出
    // 为第二路创建悬空的输出信号
    wire [`INST_ADDR_WIDTH-1:0] inst2_pipe_inst_addr;
    wire [`INST_DATA_WIDTH-1:0] inst2_pipe_inst;
    wire [`COMMIT_ID_WIDTH-1:0] inst2_pipe_commit_id;
    wire                        inst2_pipe_inst_valid;
    wire                        inst2_pipe_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] inst2_pipe_reg_waddr;
    wire                        inst2_pipe_csr_we;
    wire [ `BUS_ADDR_WIDTH-1:0] inst2_pipe_csr_waddr;
    wire [ `BUS_ADDR_WIDTH-1:0] inst2_pipe_csr_raddr;
    wire [                31:0] inst2_pipe_dec_imm;
    wire [  `DECINFO_WIDTH-1:0] inst2_pipe_dec_info_bus;
    wire [                31:0] inst2_pipe_rs1_rdata;
    wire [                31:0] inst2_pipe_rs2_rdata;

    // 第二路的其他模块输出信号（悬空）
    wire        inst2_req_bjp;
    wire [31:0] inst2_bjp_op1;
    wire [31:0] inst2_bjp_op2;
    wire [31:0] inst2_bjp_jump_op1;
    wire [31:0] inst2_bjp_jump_op2;
    wire        inst2_bjp_op_jump;
    wire        inst2_bjp_op_beq;
    wire        inst2_bjp_op_bne;
    wire        inst2_bjp_op_blt;
    wire        inst2_bjp_op_bltu;
    wire        inst2_bjp_op_bge;
    wire        inst2_bjp_op_bgeu;
    wire        inst2_bjp_op_jalr;

    wire                        inst2_req_muldiv;
    wire [                31:0] inst2_muldiv_op1;
    wire [                31:0] inst2_muldiv_op2;
    wire                        inst2_muldiv_op_mul;
    wire                        inst2_muldiv_op_mulh;
    wire                        inst2_muldiv_op_mulhsu;
    wire                        inst2_muldiv_op_mulhu;
    wire                        inst2_muldiv_op_div;
    wire                        inst2_muldiv_op_divu;
    wire                        inst2_muldiv_op_rem;
    wire                        inst2_muldiv_op_remu;
    wire                        inst2_muldiv_op_mul_all;
    wire                        inst2_muldiv_op_div_all;

    wire        inst2_req_csr;
    wire [31:0] inst2_csr_op1;
    wire [31:0] inst2_csr_addr;
    wire        inst2_csr_csrrw;
    wire        inst2_csr_csrrs;
    wire        inst2_csr_csrrc;

    // 第一路CSR内部信号
    wire        inst1_req_csr;
    wire [31:0] inst1_csr_op1;
    wire [31:0] inst1_csr_addr;
    wire        inst1_csr_csrrw;
    wire        inst1_csr_csrrs;
    wire        inst1_csr_csrrc;

    wire                        inst2_req_mem;
    wire                        inst2_mem_op_lb;
    wire                        inst2_mem_op_lh;
    wire                        inst2_mem_op_lw;
    wire                        inst2_mem_op_lbu;
    wire                        inst2_mem_op_lhu;
    wire                        inst2_mem_op_load;
    wire                        inst2_mem_op_store;
    wire [                31:0] inst2_mem_addr;
    wire [                 3:0] inst2_mem_wmask;
    wire [                31:0] inst2_mem_wdata;

    wire        inst2_sys_op_nop;
    wire        inst2_sys_op_mret;
    wire        inst2_sys_op_ecall;
    wire        inst2_sys_op_ebreak;
    wire        inst2_sys_op_fence;
    wire        inst2_sys_op_dret;
    wire        inst2_is_pred_branch;
    wire        inst2_misaligned_load;
    wire        inst2_misaligned_store;
    wire        inst2_illegal_inst;

    dispatch_pipe u_inst2_dispatch_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_flag_i(stall_flag_i),

        .inst_valid_i(inst_valid_i),
        .inst_addr_i (dec_pc_i),
        .inst_i      (inst_i),
        .commit_id_i (hdu_long_inst_id),

        // 额外的IDU信号输入
        .reg_we_i        (reg_we_i),
        .reg_waddr_i     (reg_waddr_i),
        .csr_we_i        (csr_we_i),
        .csr_waddr_i     (csr_waddr_i),
        .csr_raddr_i     (csr_raddr_i),
        .dec_imm_i       (dec_imm_i),
        .dec_info_bus_i  (dec_info_bus_i),
        // 寄存rs1/rs2数据
        .rs1_rdata_i     (rs1_rdata_i),
        .rs2_rdata_i     (rs2_rdata_i),
        .is_pred_branch_i(is_pred_branch_i),
        .illegal_inst_i  (illegal_inst_i),

        // ADDER信号输入
        .req_adder_i    (inst2_logic_req_adder),
        .adder_op1_i    (inst2_logic_adder_op1),
        .adder_op2_i    (inst2_logic_adder_op2),
        .adder_op_info_i(inst2_logic_adder_op_info),

        // SHIFTER信号输入
        .req_shifter_i    (inst2_logic_req_shifter),
        .shifter_op1_i    (inst2_logic_shifter_op1),
        .shifter_op2_i    (inst2_logic_shifter_op2),
        .shifter_op_info_i(inst2_logic_shifter_op_info),

        // BJP信号输入 (连接第二路信号，但第二路BJP为0)
        .req_bjp_i     (inst2_logic_req_bjp),
        .bjp_op1_i     (inst2_logic_bjp_op1),
        .bjp_op2_i     (inst2_logic_bjp_op2),
        .bjp_jump_op1_i(inst2_logic_bjp_jump_op1),
        .bjp_jump_op2_i(inst2_logic_bjp_jump_op2),
        .bjp_op_jump_i (inst2_logic_bjp_op_jump),
        .bjp_op_beq_i  (inst2_logic_bjp_op_beq),
        .bjp_op_bne_i  (inst2_logic_bjp_op_bne),
        .bjp_op_blt_i  (inst2_logic_bjp_op_blt),
        .bjp_op_bltu_i (inst2_logic_bjp_op_bltu),
        .bjp_op_bge_i  (inst2_logic_bjp_op_bge),
        .bjp_op_bgeu_i (inst2_logic_bjp_op_bgeu),
        .bjp_op_jalr_i (inst2_logic_bjp_op_jalr),

        // MULDIV信号输入
        .req_muldiv_i       (inst2_logic_req_muldiv),
        .muldiv_op1_i       (inst2_logic_muldiv_op1),
        .muldiv_op2_i       (inst2_logic_muldiv_op2),
        .muldiv_op_mul_i    (inst2_logic_muldiv_op_mul),
        .muldiv_op_mulh_i   (inst2_logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_i (inst2_logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_i  (inst2_logic_muldiv_op_mulhu),
        .muldiv_op_div_i    (inst2_logic_muldiv_op_div),
        .muldiv_op_divu_i   (inst2_logic_muldiv_op_divu),
        .muldiv_op_rem_i    (inst2_logic_muldiv_op_rem),
        .muldiv_op_remu_i   (inst2_logic_muldiv_op_remu),
        .muldiv_op_mul_all_i(inst2_logic_muldiv_op_mul_all),
        .muldiv_op_div_all_i(inst2_logic_muldiv_op_div_all),

        // CSR信号输入
        .req_csr_i  (inst2_logic_req_csr),
        .csr_op1_i  (inst2_logic_csr_op1),
        .csr_addr_i (inst2_logic_csr_addr),
        .csr_csrrw_i(inst2_logic_csr_csrrw),
        .csr_csrrs_i(inst2_logic_csr_csrrs),
        .csr_csrrc_i(inst2_logic_csr_csrrc),

        // MEM信号输入
        .req_mem_i     (inst2_logic_req_mem),
        .mem_op_lb_i   (inst2_logic_mem_op_lb),
        .mem_op_lh_i   (inst2_logic_mem_op_lh),
        .mem_op_lw_i   (inst2_logic_mem_op_lw),
        .mem_op_lbu_i  (inst2_logic_mem_op_lbu),
        .mem_op_lhu_i  (inst2_logic_mem_op_lhu),
        .mem_op_load_i (inst2_logic_mem_op_load),
        .mem_op_store_i(inst2_logic_mem_op_store),
        .mem_addr_i    (inst2_logic_mem_addr),
        .mem_wmask_i   (inst2_logic_mem_wmask),
        .mem_wdata_i   (inst2_logic_mem_wdata),

        // SYS信号输入
        .sys_op_nop_i   (inst2_logic_sys_op_nop),
        .sys_op_mret_i  (inst2_logic_sys_op_mret),
        .sys_op_ecall_i (inst2_logic_sys_op_ecall),
        .sys_op_ebreak_i(inst2_logic_sys_op_ebreak),
        .sys_op_fence_i (inst2_logic_sys_op_fence),
        .sys_op_dret_i  (inst2_logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_i (inst2_logic_misaligned_load),
        .misaligned_store_i(inst2_logic_misaligned_store),

        // 输出信号（悬空，除了ADDER和SHIFTER）
        .inst_addr_o   (inst2_pipe_inst_addr),
        .inst_o        (inst2_pipe_inst),
        .commit_id_o   (inst2_pipe_commit_id),
        .inst_valid_o  (inst2_pipe_inst_valid),
        .reg_we_o      (inst2_pipe_reg_we),
        .reg_waddr_o   (inst2_pipe_reg_waddr),
        .csr_we_o      (inst2_pipe_csr_we),
        .csr_waddr_o   (inst2_pipe_csr_waddr),
        .csr_raddr_o   (inst2_pipe_csr_raddr),
        .dec_imm_o     (inst2_pipe_dec_imm),
        .dec_info_bus_o(inst2_pipe_dec_info_bus),
        .rs1_rdata_o   (inst2_pipe_rs1_rdata),
        .rs2_rdata_o   (inst2_pipe_rs2_rdata),

        // ADDER信号输出 (第二路) - 连接到模块输出端口
        .req_adder_o    (inst2_req_adder_o),
        .adder_op1_o    (inst2_adder_op1_o),
        .adder_op2_o    (inst2_adder_op2_o),
        .adder_op_info_o(inst2_adder_op_info_o),

        // SHIFTER信号输出 (第二路) - 连接到模块输出端口
        .req_shifter_o    (inst2_req_shifter_o),
        .shifter_op1_o    (inst2_shifter_op1_o),
        .shifter_op2_o    (inst2_shifter_op2_o),
        .shifter_op_info_o(inst2_shifter_op_info_o),

        // BJP信号输出 (悬空，第二路不使用BJP)
        .req_bjp_o     (inst2_req_bjp),
        .bjp_op1_o     (inst2_bjp_op1),
        .bjp_op2_o     (inst2_bjp_op2),
        .bjp_jump_op1_o(inst2_bjp_jump_op1),
        .bjp_jump_op2_o(inst2_bjp_jump_op2),
        .bjp_op_jump_o (inst2_bjp_op_jump),
        .bjp_op_beq_o  (inst2_bjp_op_beq),
        .bjp_op_bne_o  (inst2_bjp_op_bne),
        .bjp_op_blt_o  (inst2_bjp_op_blt),
        .bjp_op_bltu_o (inst2_bjp_op_bltu),
        .bjp_op_bge_o  (inst2_bjp_op_bge),
        .bjp_op_bgeu_o (inst2_bjp_op_bgeu),
        .bjp_op_jalr_o (inst2_bjp_op_jalr),

        // MULDIV信号输出 (第二路)
        .req_muldiv_o       (inst2_req_muldiv_o),
        .muldiv_op1_o       (inst2_muldiv_op1_o),
        .muldiv_op2_o       (inst2_muldiv_op2_o),
        .muldiv_op_mul_o    (inst2_muldiv_op_mul_o),
        .muldiv_op_mulh_o   (inst2_muldiv_op_mulh_o),
        .muldiv_op_mulhsu_o (inst2_muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_o  (inst2_muldiv_op_mulhu_o),
        .muldiv_op_div_o    (inst2_muldiv_op_div_o),
        .muldiv_op_divu_o   (inst2_muldiv_op_divu_o),
        .muldiv_op_rem_o    (inst2_muldiv_op_rem_o),
        .muldiv_op_remu_o   (inst2_muldiv_op_remu_o),
        .muldiv_op_mul_all_o(inst2_muldiv_op_mul_all_o),
        .muldiv_op_div_all_o(inst2_muldiv_op_div_all_o),

        // CSR信号输出 (第二路)
        .req_csr_o  (inst2_req_csr),
        .csr_op1_o  (inst2_csr_op1),
        .csr_addr_o (inst2_csr_addr),
        .csr_csrrw_o(inst2_csr_csrrw),
        .csr_csrrs_o(inst2_csr_csrrs),
        .csr_csrrc_o(inst2_csr_csrrc),

        // MEM信号输出 (第二路)
        .req_mem_o     (inst2_req_mem_o),
        .mem_op_lb_o   (inst2_mem_op_lb_o),
        .mem_op_lh_o   (inst2_mem_op_lh_o),
        .mem_op_lw_o   (inst2_mem_op_lw_o),
        .mem_op_lbu_o  (inst2_mem_op_lbu_o),
        .mem_op_lhu_o  (inst2_mem_op_lhu_o),
        .mem_op_load_o (inst2_mem_op_load_o),
        .mem_op_store_o(inst2_mem_op_store_o),
        .mem_addr_o    (inst2_mem_addr_o),
        .mem_wmask_o   (inst2_mem_wmask_o),
        .mem_wdata_o   (inst2_mem_wdata_o),

        // SYS信号输出 (第二路)
        .sys_op_nop_o      (inst2_sys_op_nop_o),
        .sys_op_mret_o     (inst2_sys_op_mret_o),
        .sys_op_ecall_o    (inst2_sys_op_ecall_o),
        .sys_op_ebreak_o   (inst2_sys_op_ebreak_o),
        .sys_op_fence_o    (inst2_sys_op_fence_o),
        .sys_op_dret_o     (inst2_sys_op_dret_o),
        .is_pred_branch_o  (inst2_is_pred_branch),
        .misaligned_load_o (inst2_misaligned_load),
        .misaligned_store_o(inst2_misaligned_store),
        .illegal_inst_o    (inst2_illegal_inst)
    );

    // CSR合并逻辑
    // 由于ICU已经处理了两个指令都是CSR的情况（通过RAW冒险检测），
    // 这里只需要简单的OR逻辑来合并两路CSR输出
    // 优先级：如果第一路有有效的CSR请求，则使用第一路；否则使用第二路
    assign req_csr_o = inst1_req_csr | inst2_req_csr;
    
    // 当第一路有CSR请求时，使用第一路的信号；否则使用第二路的信号
    assign csr_op1_o  = inst1_req_csr ? inst1_csr_op1  : inst2_csr_op1;
    assign csr_addr_o = inst1_req_csr ? inst1_csr_addr : inst2_csr_addr;
    assign csr_csrrw_o = inst1_req_csr ? inst1_csr_csrrw : inst2_csr_csrrw;
    assign csr_csrrs_o = inst1_req_csr ? inst1_csr_csrrs : inst2_csr_csrrs;
    assign csr_csrrc_o = inst1_req_csr ? inst1_csr_csrrc : inst2_csr_csrrc;

endmodule
