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
    input wire                        is_pred_branch_i,
    input wire [`GREG_DATA_WIDTH-1:0] rs1_rdata_i,
    input wire [`GREG_DATA_WIDTH-1:0] rs2_rdata_i,
    input wire [`FREG_DATA_WIDTH-1:0] frs1_rdata_i,
    input wire [`FREG_DATA_WIDTH-1:0] frs2_rdata_i,
    input wire [`FREG_DATA_WIDTH-1:0] frs3_rdata_i,

    // 寄存器写入信息 - 用于HDU检测冒险
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [`REG_ADDR_WIDTH-1:0] rs1_raddr_i,
    input wire [`REG_ADDR_WIDTH-1:0] rs2_raddr_i,
    input wire [`REG_ADDR_WIDTH-1:0] rs3_raddr_i,
    input wire                       reg_we_i,

    // 从IDU接收额外的CSR信号
    input wire                       csr_we_i,
    input wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_i,

    // 长指令有效信号 - 用于HDU
    input wire rd_access_inst_valid_i,

    // 写回阶段提交信号 - 用于HDU
    input wire                        commit_valid_int_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_int_i,
    input wire                        commit_valid_fp_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_fp_i,

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

    // dispatch to ALU
    output wire                     req_alu_o,
    output wire [             31:0] alu_op1_o,
    output wire [             31:0] alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] alu_op_info_o,

    // dispatch to Bru
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

    // dispatch to MULDIV
    output wire                        req_muldiv_o,
    output wire [                31:0] muldiv_op1_o,
    output wire [                31:0] muldiv_op2_o,
    output wire                        muldiv_op_mul_o,
    output wire                        muldiv_op_mulh_o,
    output wire                        muldiv_op_mulhsu_o,
    output wire                        muldiv_op_mulhu_o,
    output wire                        muldiv_op_div_o,
    output wire                        muldiv_op_divu_o,
    output wire                        muldiv_op_rem_o,
    output wire                        muldiv_op_remu_o,
    output wire                        muldiv_op_mul_all_o,
    output wire                        muldiv_op_div_all_o,
    output wire [`COMMIT_ID_WIDTH-1:0] muldiv_commit_id_o,

    // dispatch to CSR
    output wire        req_csr_o,
    output wire [31:0] csr_op1_o,
    output wire [31:0] csr_addr_o,
    output wire        csr_csrrw_o,
    output wire        csr_csrrs_o,
    output wire        csr_csrrc_o,

    // dispatch to MEM
    output wire                        req_mem_o,
    output wire                        mem_op_lb_o,
    output wire                        mem_op_lh_o,
    output wire                        mem_op_lw_o,
    output wire                        mem_op_lbu_o,
    output wire                        mem_op_lhu_o,
    output wire                        mem_op_load_o,
    output wire                        mem_op_store_o,
    output wire [`COMMIT_ID_WIDTH-1:0] mem_commit_id_o,
    output wire [                31:0] mem_addr_o,
    output wire [                 3:0] mem_wmask_o,
    output wire [                31:0] mem_wdata_o,

    output wire                        req_fpu_o,
    output wire                        fpu_op_fadd_s_o,
    output wire                        fpu_op_fsub_s_o,
    output wire                        fpu_op_fmul_s_o,
    output wire                        fpu_op_fdiv_s_o,
    output wire                        fpu_op_fsqrt_s_o,
    output wire                        fpu_op_fsgnj_s_o,
    output wire                        fpu_op_fmax_s_o,
    output wire                        fpu_op_fcmp_s_o,
    output wire                        fpu_op_fcvt_f2i_s_o,
    output wire                        fpu_op_fcvt_i2f_s_o,
    output wire                        fpu_op_fmadd_s_o,
    output wire                        fpu_op_fmsub_s_o,
    output wire                        fpu_op_fnmadd_s_o,
    output wire                        fpu_op_fnmsub_s_o,
    output wire                        fpu_op_fmv_i2f_s_o,
    output wire                        fpu_op_fmv_f2i_s_o,
    output wire                        fpu_op_fclass_s_o,
    output wire [`FREG_DATA_WIDTH-1:0] fpu_op1_o,
    output wire [`FREG_DATA_WIDTH-1:0] fpu_op2_o,
    output wire [`FREG_DATA_WIDTH-1:0] fpu_op3_o,
    output wire [                 2:0] frm_o,
    output wire [                 1:0] fcvt_op_o,

    // dispatch to SYS
    output wire sys_op_nop_o,
    output wire sys_op_mret_o,
    output wire sys_op_ecall_o,
    output wire sys_op_ebreak_o,
    output wire sys_op_fence_o,
    output wire sys_op_dret_o,
    output wire is_pred_branch_o, // 预测分支信号输出

    output wire misaligned_load_o,   // 未对齐加载异常信号输出
    output wire misaligned_store_o,  // 未对齐存储异常信号输出
    // 新增：非法指令信号输出
    output wire illegal_inst_o
);

    // 内部连线，用于连接dispatch_logic和dispatch_pipe

    wire [`COMMIT_ID_WIDTH-1:0] hdu_long_inst_id;

    // 用于连接dispatch_logic输出到dispatch_pipe输入的内部地址、掩码和数据信号
    wire [                31:0] logic_mem_addr;
    wire [                 3:0] logic_mem_wmask;
    wire [                31:0] logic_mem_wdata;

    // 用于连接dispatch_logic输出到dispatch_pipe输入的内部信号
    wire                        logic_req_alu;
    wire [                31:0] logic_alu_op1;
    wire [                31:0] logic_alu_op2;
    wire [   `ALU_OP_WIDTH-1:0] logic_alu_op_info;

    wire                        logic_req_bjp;
    wire [                31:0] logic_bjp_op1;
    wire [                31:0] logic_bjp_op2;
    wire [                31:0] logic_bjp_jump_op1;
    wire [                31:0] logic_bjp_jump_op2;
    wire                        logic_bjp_op_jal;
    wire                        logic_bjp_op_beq;
    wire                        logic_bjp_op_bne;
    wire                        logic_bjp_op_blt;
    wire                        logic_bjp_op_bltu;
    wire                        logic_bjp_op_bge;
    wire                        logic_bjp_op_bgeu;
    wire                        logic_bjp_op_jalr;

    wire                        logic_req_muldiv;
    wire [                31:0] logic_muldiv_op1;
    wire [                31:0] logic_muldiv_op2;
    wire                        logic_muldiv_op_mul;
    wire                        logic_muldiv_op_mulh;
    wire                        logic_muldiv_op_mulhsu;
    wire                        logic_muldiv_op_mulhu;
    wire                        logic_muldiv_op_div;
    wire                        logic_muldiv_op_divu;
    wire                        logic_muldiv_op_rem;
    wire                        logic_muldiv_op_remu;
    wire                        logic_muldiv_op_mul_all;
    wire                        logic_muldiv_op_div_all;
    wire [`COMMIT_ID_WIDTH-1:0] logic_muldiv_commit_id;

    wire                        logic_req_csr;
    wire [                31:0] logic_csr_op1;
    wire [                31:0] logic_csr_addr;
    wire                        logic_csr_csrrw;
    wire                        logic_csr_csrrs;
    wire                        logic_csr_csrrc;

    wire                        logic_req_mem;
    wire [                31:0] logic_mem_op1;
    wire [                31:0] logic_mem_op2;
    wire [                31:0] logic_mem_rs2_data;
    wire                        logic_mem_op_lb;
    wire                        logic_mem_op_lh;
    wire                        logic_mem_op_lw;
    wire                        logic_mem_op_lbu;
    wire                        logic_mem_op_lhu;
    wire                        logic_mem_op_sb;
    wire                        logic_mem_op_sh;
    wire                        logic_mem_op_sw;
    wire                        logic_mem_op_load;
    wire                        logic_mem_op_store;
    wire [`COMMIT_ID_WIDTH-1:0] logic_mem_commit_id;

    wire                        logic_sys_op_nop;
    wire                        logic_sys_op_mret;
    wire                        logic_sys_op_ecall;
    wire                        logic_sys_op_ebreak;
    wire                        logic_sys_op_fence;
    wire                        logic_sys_op_dret;

    // 未对齐访存异常信号
    wire                        logic_misaligned_load;
    wire                        logic_misaligned_store;

    wire                        logic_req_fpu;
    wire                        logic_fpu_op_fadd_s;
    wire                        logic_fpu_op_fsub_s;
    wire                        logic_fpu_op_fmul_s;
    wire                        logic_fpu_op_fdiv_s;
    wire                        logic_fpu_op_fsqrt_s;
    wire                        logic_fpu_op_fsgnj_s;
    wire                        logic_fpu_op_fmax_s;
    wire                        logic_fpu_op_fcmp_s;
    wire                        logic_fpu_op_fcvt_f2i_s;
    wire                        logic_fpu_op_fcvt_i2f_s;
    wire                        logic_fpu_op_fmadd_s;
    wire                        logic_fpu_op_fmsub_s;
    wire                        logic_fpu_op_fnmadd_s;
    wire                        logic_fpu_op_fnmsub_s;
    wire                        logic_fpu_op_fmv_i2f_s;
    wire                        logic_fpu_op_fmv_f2i_s;
    wire                        logic_fpu_op_fclass_s;
    wire [`FREG_DATA_WIDTH-1:0] logic_fpu_op1;
    wire [`FREG_DATA_WIDTH-1:0] logic_fpu_op2;
    wire [`FREG_DATA_WIDTH-1:0] logic_fpu_op3;
    wire [                 2:0] logic_frm;
    wire [                 1:0] logic_fcvt_op;

    assign mem_commit_id_o    = commit_id_o;  // 将HDU的commit_id输出到MEM模块
    assign muldiv_commit_id_o = commit_id_o;
    // 实例化HDU模块
    hdu u_hdu (
        .clk                  (clk),
        .rst_n                (rst_n),
        .inst_valid           (rd_access_inst_valid_i),
        .new_inst_rd_addr     (reg_waddr_i),
        .new_inst_rs1_addr    (rs1_raddr_i),
        .new_inst_rs2_addr    (rs2_raddr_i),
        .new_inst_rs3_addr    (rs3_raddr_i),
        .new_inst_rd_we       (reg_we_i),
        .commit_valid_int_i   (commit_valid_int_i),
        .commit_id_int_i      (commit_id_int_i),
        .commit_valid_fp_i    (commit_valid_fp_i),
        .commit_id_fp_i       (commit_id_fp_i),
        .hazard_stall_o       (hazard_stall_o),
        .commit_id_o          (hdu_long_inst_id),
        .long_inst_atom_lock_o(long_inst_atom_lock_o)
    );

    // dispatch_logic实例化
    dispatch_logic u_dispatch_logic (
        .dec_info_bus_i(dec_info_bus_i),
        .dec_imm_i     (dec_imm_i),
        .dec_pc_i      (dec_pc_i),
        .rs1_rdata_i   (rs1_rdata_i),
        .rs2_rdata_i   (rs2_rdata_i),
        // 新增：浮点寄存器数据输入端口
        .frs1_rdata_i  (frs1_rdata_i),
        .frs2_rdata_i  (frs2_rdata_i),
        .frs3_rdata_i  (frs3_rdata_i),

        // ALU信号
        .req_alu_o    (logic_req_alu),
        .alu_op1_o    (logic_alu_op1),
        .alu_op2_o    (logic_alu_op2),
        .alu_op_info_o(logic_alu_op_info),

        // BJP信号
        .req_bjp_o     (logic_req_bjp),
        .bjp_op1_o     (logic_bjp_op1),
        .bjp_op2_o     (logic_bjp_op2),
        .bjp_jump_op1_o(logic_bjp_jump_op1),
        .bjp_jump_op2_o(logic_bjp_jump_op2),
        .bjp_op_jal_o  (logic_bjp_op_jal),
        .bjp_op_beq_o  (logic_bjp_op_beq),
        .bjp_op_bne_o  (logic_bjp_op_bne),
        .bjp_op_blt_o  (logic_bjp_op_blt),
        .bjp_op_bltu_o (logic_bjp_op_bltu),
        .bjp_op_bge_o  (logic_bjp_op_bge),
        .bjp_op_bgeu_o (logic_bjp_op_bgeu),
        .bjp_op_jalr_o (logic_bjp_op_jalr),

        // MULDIV信号
        .req_muldiv_o       (logic_req_muldiv),
        .muldiv_op1_o       (logic_muldiv_op1),
        .muldiv_op2_o       (logic_muldiv_op2),
        .muldiv_op_mul_o    (logic_muldiv_op_mul),
        .muldiv_op_mulh_o   (logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_o (logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_o  (logic_muldiv_op_mulhu),
        .muldiv_op_div_o    (logic_muldiv_op_div),
        .muldiv_op_divu_o   (logic_muldiv_op_divu),
        .muldiv_op_rem_o    (logic_muldiv_op_rem),
        .muldiv_op_remu_o   (logic_muldiv_op_remu),
        .muldiv_op_mul_all_o(logic_muldiv_op_mul_all),
        .muldiv_op_div_all_o(logic_muldiv_op_div_all),

        // CSR信号
        .req_csr_o  (logic_req_csr),
        .csr_op1_o  (logic_csr_op1),
        .csr_addr_o (logic_csr_addr),
        .csr_csrrw_o(logic_csr_csrrw),
        .csr_csrrs_o(logic_csr_csrrs),
        .csr_csrrc_o(logic_csr_csrrc),

        // MEM信号
        .req_mem_o     (logic_req_mem),
        .mem_op_lb_o   (logic_mem_op_lb),
        .mem_op_lh_o   (logic_mem_op_lh),
        .mem_op_lw_o   (logic_mem_op_lw),
        .mem_op_lbu_o  (logic_mem_op_lbu),
        .mem_op_lhu_o  (logic_mem_op_lhu),
        .mem_op_load_o (logic_mem_op_load),
        .mem_op_store_o(logic_mem_op_store),
        .mem_addr_o    (logic_mem_addr),
        .mem_wmask_o   (logic_mem_wmask),
        .mem_wdata_o   (logic_mem_wdata),

        // SYS信号
        .sys_op_nop_o   (logic_sys_op_nop),
        .sys_op_mret_o  (logic_sys_op_mret),
        .sys_op_ecall_o (logic_sys_op_ecall),
        .sys_op_ebreak_o(logic_sys_op_ebreak),
        .sys_op_fence_o (logic_sys_op_fence),
        .sys_op_dret_o  (logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_o (logic_misaligned_load),
        .misaligned_store_o(logic_misaligned_store),

        // FPU接口
        .req_fpu_o          (logic_req_fpu),
        .fpu_op_fadd_s_o    (logic_fpu_op_fadd_s),
        .fpu_op_fsub_s_o    (logic_fpu_op_fsub_s),
        .fpu_op_fmul_s_o    (logic_fpu_op_fmul_s),
        .fpu_op_fdiv_s_o    (logic_fpu_op_fdiv_s),
        .fpu_op_fsqrt_s_o   (logic_fpu_op_fsqrt_s),
        .fpu_op_fsgnj_s_o   (logic_fpu_op_fsgnj_s),
        .fpu_op_fmax_s_o    (logic_fpu_op_fmax_s),
        .fpu_op_fcmp_s_o    (logic_fpu_op_fcmp_s),
        .fpu_op_fcvt_f2i_s_o(logic_fpu_op_fcvt_f2i_s),
        .fpu_op_fcvt_i2f_s_o(logic_fpu_op_fcvt_i2f_s),
        .fpu_op_fmadd_s_o   (logic_fpu_op_fmadd_s),
        .fpu_op_fmsub_s_o   (logic_fpu_op_fmsub_s),
        .fpu_op_fnmadd_s_o  (logic_fpu_op_fnmadd_s),
        .fpu_op_fnmsub_s_o  (logic_fpu_op_fnmsub_s),
        .fpu_op_fmv_i2f_s_o (logic_fpu_op_fmv_i2f_s),
        .fpu_op_fmv_f2i_s_o (logic_fpu_op_fmv_f2i_s),
        .fpu_op_fclass_s_o  (logic_fpu_op_fclass_s),
        .fpu_op1_o          (logic_fpu_op1),
        .fpu_op2_o          (logic_fpu_op2),
        .fpu_op3_o          (logic_fpu_op3),
        .frm_o              (logic_frm),
        .fcvt_op_o          (logic_fcvt_op)
    );

    // dispatch_pipe实例化
    dispatch_pipe u_dispatch_pipe (
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
        .rs1_rdata_i     (rs1_rdata_i),
        .rs2_rdata_i     (rs2_rdata_i),
        .is_pred_branch_i(is_pred_branch_i),
        .illegal_inst_i  (illegal_inst_i),

        // ALU信号输入
        .req_alu_i    (logic_req_alu),
        .alu_op1_i    (logic_alu_op1),
        .alu_op2_i    (logic_alu_op2),
        .alu_op_info_i(logic_alu_op_info),

        // BJP信号输入
        .req_bjp_i     (logic_req_bjp),
        .bjp_op1_i     (logic_bjp_op1),
        .bjp_op2_i     (logic_bjp_op2),
        .bjp_jump_op1_i(logic_bjp_jump_op1),
        .bjp_jump_op2_i(logic_bjp_jump_op2),
        .bjp_op_jal_i  (logic_bjp_op_jal),
        .bjp_op_beq_i  (logic_bjp_op_beq),
        .bjp_op_bne_i  (logic_bjp_op_bne),
        .bjp_op_blt_i  (logic_bjp_op_blt),
        .bjp_op_bltu_i (logic_bjp_op_bltu),
        .bjp_op_bge_i  (logic_bjp_op_bge),
        .bjp_op_bgeu_i (logic_bjp_op_bgeu),
        .bjp_op_jalr_i (logic_bjp_op_jalr),

        // MULDIV信号输入
        .req_muldiv_i       (logic_req_muldiv),
        .muldiv_op1_i       (logic_muldiv_op1),
        .muldiv_op2_i       (logic_muldiv_op2),
        .muldiv_op_mul_i    (logic_muldiv_op_mul),
        .muldiv_op_mulh_i   (logic_muldiv_op_mulh),
        .muldiv_op_mulhsu_i (logic_muldiv_op_mulhsu),
        .muldiv_op_mulhu_i  (logic_muldiv_op_mulhu),
        .muldiv_op_div_i    (logic_muldiv_op_div),
        .muldiv_op_divu_i   (logic_muldiv_op_divu),
        .muldiv_op_rem_i    (logic_muldiv_op_rem),
        .muldiv_op_remu_i   (logic_muldiv_op_remu),
        .muldiv_op_mul_all_i(logic_muldiv_op_mul_all),
        .muldiv_op_div_all_i(logic_muldiv_op_div_all),

        // CSR信号输入
        .req_csr_i  (logic_req_csr),
        .csr_op1_i  (logic_csr_op1),
        .csr_addr_i (logic_csr_addr),
        .csr_csrrw_i(logic_csr_csrrw),
        .csr_csrrs_i(logic_csr_csrrs),
        .csr_csrrc_i(logic_csr_csrrc),

        // MEM信号输入
        .req_mem_i     (logic_req_mem),
        .mem_op_lb_i   (logic_mem_op_lb),
        .mem_op_lh_i   (logic_mem_op_lh),
        .mem_op_lw_i   (logic_mem_op_lw),
        .mem_op_lbu_i  (logic_mem_op_lbu),
        .mem_op_lhu_i  (logic_mem_op_lhu),
        .mem_op_load_i (logic_mem_op_load),
        .mem_op_store_i(logic_mem_op_store),
        .mem_addr_i    (logic_mem_addr),
        .mem_wmask_i   (logic_mem_wmask),
        .mem_wdata_i   (logic_mem_wdata),

        // SYS信号输入
        .sys_op_nop_i   (logic_sys_op_nop),
        .sys_op_mret_i  (logic_sys_op_mret),
        .sys_op_ecall_i (logic_sys_op_ecall),
        .sys_op_ebreak_i(logic_sys_op_ebreak),
        .sys_op_fence_i (logic_sys_op_fence),
        .sys_op_dret_i  (logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_i (logic_misaligned_load),
        .misaligned_store_i(logic_misaligned_store),

        // FPU信号输入
        .req_fpu_i          (logic_req_fpu),
        .fpu_op_fadd_s_i    (logic_fpu_op_fadd_s),
        .fpu_op_fsub_s_i    (logic_fpu_op_fsub_s),
        .fpu_op_fmul_s_i    (logic_fpu_op_fmul_s),
        .fpu_op_fdiv_s_i    (logic_fpu_op_fdiv_s),
        .fpu_op_fsqrt_s_i   (logic_fpu_op_fsqrt_s),
        .fpu_op_fsgnj_s_i   (logic_fpu_op_fsgnj_s),
        .fpu_op_fmax_s_i    (logic_fpu_op_fmax_s),
        .fpu_op_fcmp_s_i    (logic_fpu_op_fcmp_s),
        .fpu_op_fcvt_f2i_s_i(logic_fpu_op_fcvt_f2i_s),
        .fpu_op_fcvt_i2f_s_i(logic_fpu_op_fcvt_i2f_s),
        .fpu_op_fmadd_s_i   (logic_fpu_op_fmadd_s),
        .fpu_op_fmsub_s_i   (logic_fpu_op_fmsub_s),
        .fpu_op_fnmadd_s_i  (logic_fpu_op_fnmadd_s),
        .fpu_op_fnmsub_s_i  (logic_fpu_op_fnmsub_s),
        .fpu_op_fmv_i2f_s_i (logic_fpu_op_fmv_i2f_s),
        .fpu_op_fmv_f2i_s_i (logic_fpu_op_fmv_f2i_s),
        .fpu_op_fclass_s_i  (logic_fpu_op_fclass_s),
        .fpu_op1_i          (logic_fpu_op1),
        .fpu_op2_i          (logic_fpu_op2),
        .fpu_op3_i          (logic_fpu_op3),
        .frm_i              (logic_frm),
        .fcvt_op_i          (logic_fcvt_op),

        // 指令地址和ID输出
        .inst_addr_o   (pipe_inst_addr_o),
        .inst_o        (pipe_inst_o),
        .commit_id_o   (commit_id_o),
        .inst_valid_o  (pipe_inst_valid_o),
        .reg_we_o      (pipe_reg_we_o),
        .reg_waddr_o   (pipe_reg_waddr_o),
        .csr_we_o      (pipe_csr_we_o),
        .csr_waddr_o   (pipe_csr_waddr_o),
        .csr_raddr_o   (pipe_csr_raddr_o),
        .dec_imm_o     (pipe_dec_imm_o),
        .dec_info_bus_o(pipe_dec_info_bus_o),
        .rs1_rdata_o   (pipe_rs1_rdata_o),
        .rs2_rdata_o   (pipe_rs2_rdata_o),

        // ALU信号输出
        .req_alu_o    (req_alu_o),
        .alu_op1_o    (alu_op1_o),
        .alu_op2_o    (alu_op2_o),
        .alu_op_info_o(alu_op_info_o),

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

        // MULDIV信号输出
        .req_muldiv_o       (req_muldiv_o),
        .muldiv_op1_o       (muldiv_op1_o),
        .muldiv_op2_o       (muldiv_op2_o),
        .muldiv_op_mul_o    (muldiv_op_mul_o),
        .muldiv_op_mulh_o   (muldiv_op_mulh_o),
        .muldiv_op_mulhsu_o (muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_o  (muldiv_op_mulhu_o),
        .muldiv_op_div_o    (muldiv_op_div_o),
        .muldiv_op_divu_o   (muldiv_op_divu_o),
        .muldiv_op_rem_o    (muldiv_op_rem_o),
        .muldiv_op_remu_o   (muldiv_op_remu_o),
        .muldiv_op_mul_all_o(muldiv_op_mul_all_o),
        .muldiv_op_div_all_o(muldiv_op_div_all_o),

        // CSR信号输出
        .req_csr_o  (req_csr_o),
        .csr_op1_o  (csr_op1_o),
        .csr_addr_o (csr_addr_o),
        .csr_csrrw_o(csr_csrrw_o),
        .csr_csrrs_o(csr_csrrs_o),
        .csr_csrrc_o(csr_csrrc_o),

        // MEM信号输出
        .req_mem_o     (req_mem_o),
        .mem_op_lb_o   (mem_op_lb_o),
        .mem_op_lh_o   (mem_op_lh_o),
        .mem_op_lw_o   (mem_op_lw_o),
        .mem_op_lbu_o  (mem_op_lbu_o),
        .mem_op_lhu_o  (mem_op_lhu_o),
        .mem_op_load_o (mem_op_load_o),
        .mem_op_store_o(mem_op_store_o),
        .mem_addr_o    (mem_addr_o),
        .mem_wmask_o   (mem_wmask_o),
        .mem_wdata_o   (mem_wdata_o),

        // SYS信号输出
        .sys_op_nop_o      (sys_op_nop_o),
        .sys_op_mret_o     (sys_op_mret_o),
        .sys_op_ecall_o    (sys_op_ecall_o),
        .sys_op_ebreak_o   (sys_op_ebreak_o),
        .sys_op_fence_o    (sys_op_fence_o),
        .sys_op_dret_o     (sys_op_dret_o),
        .is_pred_branch_o  (is_pred_branch_o),
        .misaligned_load_o (misaligned_load_o),
        .misaligned_store_o(misaligned_store_o),
        .illegal_inst_o    (illegal_inst_o),

        // FPU信号输出
        .req_fpu_o          (req_fpu_o),
        .fpu_op_fadd_s_o    (fpu_op_fadd_s_o),
        .fpu_op_fsub_s_o    (fpu_op_fsub_s_o),
        .fpu_op_fmul_s_o    (fpu_op_fmul_s_o),
        .fpu_op_fdiv_s_o    (fpu_op_fdiv_s_o),
        .fpu_op_fsqrt_s_o   (fpu_op_fsqrt_s_o),
        .fpu_op_fsgnj_s_o   (fpu_op_fsgnj_s_o),
        .fpu_op_fmax_s_o    (fpu_op_fmax_s_o),
        .fpu_op_fcmp_s_o    (fpu_op_fcmp_s_o),
        .fpu_op_fcvt_f2i_s_o(fpu_op_fcvt_f2i_s_o),
        .fpu_op_fcvt_i2f_s_o(fpu_op_fcvt_i2f_s_o),
        .fpu_op_fmadd_s_o   (fpu_op_fmadd_s_o),
        .fpu_op_fmsub_s_o   (fpu_op_fmsub_s_o),
        .fpu_op_fnmadd_s_o  (fpu_op_fnmadd_s_o),
        .fpu_op_fnmsub_s_o  (fpu_op_fnmsub_s_o),
        .fpu_op_fmv_i2f_s_o (fpu_op_fmv_i2f_s_o),
        .fpu_op_fmv_f2i_s_o (fpu_op_fmv_f2i_s_o),
        .fpu_op_fclass_s_o  (fpu_op_fclass_s_o),
        .fpu_op1_o          (fpu_op1_o),
        .fpu_op2_o          (fpu_op2_o),
        .fpu_op3_o          (fpu_op3_o),
        .frm_o              (frm_o),
        .fcvt_op_o          (fcvt_op_o)
    );

endmodule
