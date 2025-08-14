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

    // 从ICU接收的第一路指令信息
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i,
    input wire                        inst1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_i,
    input wire [ 31:0] inst1_csr_waddr_i,
    input wire [ 31:0] inst1_csr_raddr_i,
    input wire                        inst1_csr_we_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst1_i,
    input wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_i,

    // 从ICU接收的第二路指令信息
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire [ 31:0] inst2_csr_waddr_i,
    input wire [ 31:0] inst2_csr_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    input wire                        inst2_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst2_i,
    input wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_i,

    // 从GPR读取的寄存器数据
    input wire [ `REG_DATA_WIDTH-1:0] inst1_rs1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] inst1_rs2_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] inst2_rs1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] inst2_rs2_rdata_i,

    // 指令有效信号和异常信号
    input wire inst1_valid_i,
    input wire inst2_valid_i,
    input wire inst1_illegal_inst_i,
    input wire inst2_illegal_inst_i,

    //分发到各功能单元的输出接口
    // dispatch to alu (第一路)
    output wire        inst1_req_alu_o,
    output wire [31:0] inst1_alu_op1_o,
    output wire [31:0] inst1_alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] inst1_alu_op_info_o,

    // dispatch to alu (第二路)
    output wire        inst2_req_alu_o,
    output wire [31:0] inst2_alu_op1_o,
    output wire [31:0] inst2_alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] inst2_alu_op_info_o,

    // dispatch to Bru (合并单路输出)
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
    output wire        inst_is_pred_branch_o,

    // dispatch to MUL & DIV (第一路)
    // dispatch to MUL
    output wire                        inst1_req_mul_o,
    output wire                        inst1_mul_op_mul_o,
    output wire                        inst1_mul_op_mulh_o,
    output wire                        inst1_mul_op_mulhsu_o,
    output wire                        inst1_mul_op_mulhu_o,
    output wire [                31:0] inst1_mul_op1_o,
    output wire [                31:0] inst1_mul_op2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_mul_commit_id_o,

    // dispatch to DIV
    output wire                        inst1_req_div_o,
    output wire                        inst1_div_op_div_o,
    output wire                        inst1_div_op_divu_o,
    output wire                        inst1_div_op_rem_o,
    output wire                        inst1_div_op_remu_o,
    output wire [                31:0] inst1_div_op1_o,
    output wire [                31:0] inst1_div_op2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_div_commit_id_o,

    // dispatch to MUL & DIV (第二路)
    // dispatch to MUL
    output wire                        inst2_req_mul_o,
    output wire                        inst2_mul_op_mul_o,
    output wire                        inst2_mul_op_mulh_o,
    output wire                        inst2_mul_op_mulhsu_o,
    output wire                        inst2_mul_op_mulhu_o,
    output wire [                31:0] inst2_mul_op1_o,
    output wire [                31:0] inst2_mul_op2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_mul_commit_id_o,

    // dispatch to DIV
    output wire                        inst2_req_div_o,
    output wire                        inst2_div_op_div_o,
    output wire                        inst2_div_op_divu_o,
    output wire                        inst2_div_op_rem_o,
    output wire                        inst2_div_op_remu_o,
    output wire [                31:0] inst2_div_op1_o,
    output wire [                31:0] inst2_div_op2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_div_commit_id_o,
    // dispatch to CSR (合并单路输出)
    output wire        req_csr_o,
    output wire [31:0] csr_op1_o,
    output wire [31:0] csr_addr_o,
    output wire        csr_csrrw_o,
    output wire        csr_csrrs_o,
    output wire        csr_csrrc_o,
    output wire        csr_we_o,
    output wire [31:0] csr_waddr_o,
    output wire [31:0] csr_raddr_o,
    output wire        csr_reg_we_o,
    output wire [31:0] csr_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_o,

    // dispatch to MEM (第一路)
    output wire                        inst1_req_mem_o,
    output wire                        inst1_mem_op_lb_o,
    output wire                        inst1_mem_op_lh_o,
    output wire                        inst1_mem_op_lw_o,
    output wire                        inst1_mem_op_lbu_o,
    output wire                        inst1_mem_op_lhu_o,
    output wire                        inst1_mem_op_load_o,
    output wire                        inst1_mem_op_store_o,
    output wire [                31:0] inst1_mem_addr_o,
    output wire [                 7:0] inst1_mem_wmask_o,
    output wire [                64:0] inst1_mem_wdata_o,

    // dispatch to MEM (第二路)
    output wire                        inst2_req_mem_o,
    output wire                        inst2_mem_op_lb_o,
    output wire                        inst2_mem_op_lh_o,
    output wire                        inst2_mem_op_lw_o,
    output wire                        inst2_mem_op_lbu_o,
    output wire                        inst2_mem_op_lhu_o,
    output wire                        inst2_mem_op_load_o,
    output wire                        inst2_mem_op_store_o,
    output wire [                31:0] inst2_mem_addr_o,
    output wire [                 7:0] inst2_mem_wmask_o,
    output wire [                64:0] inst2_mem_wdata_o,

    // dispatch to SYS (合并单路输出)
    output wire sys_op_nop_o,
    output wire sys_op_mret_o,
    output wire sys_op_ecall_o,
    output wire sys_op_ebreak_o,
    output wire sys_op_fence_o,
    output wire sys_op_dret_o,

    //指令其他信号（第一路）
    output wire inst1_misaligned_load_o,
    output wire inst1_misaligned_store_o,
    output wire inst1_illegal_inst_o,
    
    //指令其他信号（第二路）
    output wire inst2_misaligned_load_o,
    output wire inst2_misaligned_store_o,
    output wire inst2_illegal_inst_o,

    //fake_commit信号，inst1的输出空置
    output wire req_fake_commit_o,
    output wire [31:0] fake_commit_id_o,

    // 输出指令地址和提交ID以及保留到后续模块的其他指令信息
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,
    output wire [31:0] inst1_o,
    output wire [31:0] inst2_o,
    output wire inst1_valid_o,
    output wire inst2_valid_o,
    output wire inst1_reg_we_o,
    output wire inst2_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,
    output wire [                31:0] inst1_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o,
    output wire [                31:0] inst2_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o,
    output wire [               31:0] inst1_rs1_rdata_o,
    output wire [               31:0] inst1_rs2_rdata_o,
    output wire [               31:0] inst2_rs1_rdata_o,
    output wire [               31:0] inst2_rs2_rdata_o,
    output wire [3:0] inst1_commit_id_o,
    output wire [3:0] inst2_commit_id_o
);

    // 内部连线，用于连接dispatch_logic和dispatch_pipe

    // 第一路和第二路CSR内部信号
    wire        pipe_inst1_req_csr_o;
    wire [31:0] pipe_inst1_csr_op1_o;
    wire [31:0] pipe_inst1_csr_addr_o;
    wire        pipe_inst1_csr_csrrw_o;
    wire        pipe_inst1_csr_csrrs_o;
    wire        pipe_inst1_csr_csrrc_o;
    wire        pipe_inst1_csr_we_o;
    wire [31:0] pipe_inst1_csr_waddr_o;
    wire [31:0] pipe_inst1_csr_raddr_o;

    wire        pipe_inst2_req_csr_o;
    wire [31:0] pipe_inst2_csr_op1_o;
    wire [31:0] pipe_inst2_csr_addr_o;
    wire        pipe_inst2_csr_csrrw_o;
    wire        pipe_inst2_csr_csrrs_o;
    wire        pipe_inst2_csr_csrrc_o;
    wire        pipe_inst2_csr_we_o;
    wire [31:0] pipe_inst2_csr_waddr_o;
    wire [31:0] pipe_inst2_csr_raddr_o;

    wire        pipe_inst1_req_bjp_o;
    wire [31:0] pipe_inst1_bjp_op1_o;
    wire [31:0] pipe_inst1_bjp_op2_o;
    wire [31:0] pipe_inst1_bjp_jump_op1_o;
    wire [31:0] pipe_inst1_bjp_jump_op2_o;
    wire        pipe_inst1_bjp_op_jal_o;
    wire        pipe_inst1_bjp_op_beq_o;
    wire        pipe_inst1_bjp_op_bne_o;
    wire        pipe_inst1_bjp_op_blt_o;
    wire        pipe_inst1_bjp_op_bltu_o;
    wire        pipe_inst1_bjp_op_bge_o;
    wire        pipe_inst1_bjp_op_bgeu_o;
    wire        pipe_inst1_bjp_op_jalr_o;

    wire        pipe_inst2_req_bjp_o;
    wire [31:0] pipe_inst2_bjp_op1_o;
    wire [31:0] pipe_inst2_bjp_op2_o;
    wire [31:0] pipe_inst2_bjp_jump_op1_o;
    wire [31:0] pipe_inst2_bjp_jump_op2_o;
    wire        pipe_inst2_bjp_op_jal_o;
    wire        pipe_inst2_bjp_op_beq_o;
    wire        pipe_inst2_bjp_op_bne_o;
    wire        pipe_inst2_bjp_op_blt_o;
    wire        pipe_inst2_bjp_op_bltu_o;
    wire        pipe_inst2_bjp_op_bge_o;
    wire        pipe_inst2_bjp_op_bgeu_o;
    wire        pipe_inst2_bjp_op_jalr_o;

    // 第一路和第二路SYS内部信号
    wire        pipe_inst1_sys_op_nop_o;
    wire        pipe_inst1_sys_op_mret_o;
    wire        pipe_inst1_sys_op_ecall_o;
    wire        pipe_inst1_sys_op_ebreak_o;
    wire        pipe_inst1_sys_op_fence_o;
    wire        pipe_inst1_sys_op_dret_o;

    wire        pipe_inst2_sys_op_nop_o;
    wire        pipe_inst2_sys_op_mret_o;
    wire        pipe_inst2_sys_op_ecall_o;
    wire        pipe_inst2_sys_op_ebreak_o;
    wire        pipe_inst2_sys_op_fence_o;
    wire        pipe_inst2_sys_op_dret_o;

    // 第一路和第二路预测跳转信号
    wire        pipe_inst1_is_pred_branch;
    wire        pipe_inst2_is_pred_branch;

    // 第一路dispatch_logic输出信号
    wire                        inst1_logic_req_alu;
    wire [                31:0] inst1_logic_alu_op1;
    wire [                31:0] inst1_logic_alu_op2;
    wire [   `ALU_OP_WIDTH-1:0] inst1_logic_alu_op_info;

    wire                        inst1_logic_req_bjp;
    wire [                31:0] inst1_logic_bjp_op1;
    wire [                31:0] inst1_logic_bjp_op2;
    wire [                31:0] inst1_logic_bjp_jump_op1;
    wire [                31:0] inst1_logic_bjp_jump_op2;
    wire                        inst1_logic_bjp_op_jal;
    wire                        inst1_logic_bjp_op_beq;
    wire                        inst1_logic_bjp_op_bne;
    wire                        inst1_logic_bjp_op_blt;
    wire                        inst1_logic_bjp_op_bltu;
    wire                        inst1_logic_bjp_op_bge;
    wire                        inst1_logic_bjp_op_bgeu;
    wire                        inst1_logic_bjp_op_jalr;

    wire                        inst1_logic_req_mul;
    wire [                31:0] inst1_logic_mul_op1;
    wire [                31:0] inst1_logic_mul_op2;
    wire                        inst1_logic_mul_op_mul;
    wire                        inst1_logic_mul_op_mulh;
    wire                        inst1_logic_mul_op_mulhsu;
    wire                        inst1_logic_mul_op_mulhu;

    wire                        inst1_logic_req_div;
    wire [                31:0] inst1_logic_div_op1;
    wire [                31:0] inst1_logic_div_op2;
    wire                        inst1_logic_div_op_div;
    wire                        inst1_logic_div_op_divu;
    wire                        inst1_logic_div_op_rem;
    wire                        inst1_logic_div_op_remu;

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
    wire [                 7:0] inst1_logic_mem_wmask;
    wire [                63:0] inst1_logic_mem_wdata;

    wire                        inst1_logic_sys_op_nop;
    wire                        inst1_logic_sys_op_mret;
    wire                        inst1_logic_sys_op_ecall;
    wire                        inst1_logic_sys_op_ebreak;
    wire                        inst1_logic_sys_op_fence;
    wire                        inst1_logic_sys_op_dret;

    wire                        inst1_logic_misaligned_load;
    wire                        inst1_logic_misaligned_store;

    // 第二路dispatch_logic输出信号
    wire                        inst2_logic_req_alu;
    wire [                31:0] inst2_logic_alu_op1;
    wire [                31:0] inst2_logic_alu_op2;
    wire [   `ALU_OP_WIDTH-1:0] inst2_logic_alu_op_info;

    wire                        inst2_logic_req_bjp;
    wire [                31:0] inst2_logic_bjp_op1;
    wire [                31:0] inst2_logic_bjp_op2;
    wire [                31:0] inst2_logic_bjp_jump_op1;
    wire [                31:0] inst2_logic_bjp_jump_op2;
    wire                        inst2_logic_bjp_op_jal;
    wire                        inst2_logic_bjp_op_beq;
    wire                        inst2_logic_bjp_op_bne;
    wire                        inst2_logic_bjp_op_blt;
    wire                        inst2_logic_bjp_op_bltu;
    wire                        inst2_logic_bjp_op_bge;
    wire                        inst2_logic_bjp_op_bgeu;
    wire                        inst2_logic_bjp_op_jalr;

    wire                        inst2_logic_req_mul;
    wire [                31:0] inst2_logic_mul_op1;
    wire [                31:0] inst2_logic_mul_op2;
    wire                        inst2_logic_mul_op_mul;
    wire                        inst2_logic_mul_op_mulh;
    wire                        inst2_logic_mul_op_mulhsu;
    wire                        inst2_logic_mul_op_mulhu;

    wire                        inst2_logic_req_div;
    wire [                31:0] inst2_logic_div_op1;
    wire [                31:0] inst2_logic_div_op2;
    wire                        inst2_logic_div_op_div;
    wire                        inst2_logic_div_op_divu;
    wire                        inst2_logic_div_op_rem;
    wire                        inst2_logic_div_op_remu;

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
    wire [                 7:0] inst2_logic_mem_wmask;
    wire [                63:0] inst2_logic_mem_wdata;

    wire                        inst2_logic_sys_op_nop;
    wire                        inst2_logic_sys_op_mret;
    wire                        inst2_logic_sys_op_ecall;
    wire                        inst2_logic_sys_op_ebreak;
    wire                        inst2_logic_sys_op_fence;
    wire                        inst2_logic_sys_op_dret;

    wire                        inst2_logic_misaligned_load;
    wire                        inst2_logic_misaligned_store;

    // 实例化dispatch_logic模块 (第一路)
    dispatch_logic u_inst1_dispatch_logic (
        .dec_info_bus_i(inst1_dec_info_bus_i),
        .dec_imm_i     (inst1_dec_imm_i),
        .dec_pc_i      (inst1_addr_i),
        .rs1_rdata_i   (inst1_rs1_rdata_i),
        .rs2_rdata_i   (inst1_rs2_rdata_i),

        // ALU信号
        .req_alu_o    (inst1_logic_req_alu),
        .alu_op1_o    (inst1_logic_alu_op1),
        .alu_op2_o    (inst1_logic_alu_op2),
        .alu_op_info_o(inst1_logic_alu_op_info),

        // BJP信号
        .req_bjp_o     (inst1_logic_req_bjp),
        .bjp_op1_o     (inst1_logic_bjp_op1),
        .bjp_op2_o     (inst1_logic_bjp_op2),
        .bjp_jump_op1_o(inst1_logic_bjp_jump_op1),
        .bjp_jump_op2_o(inst1_logic_bjp_jump_op2),
        .bjp_op_jal_o  (inst1_logic_bjp_op_jal),
        .bjp_op_beq_o  (inst1_logic_bjp_op_beq),
        .bjp_op_bne_o  (inst1_logic_bjp_op_bne),
        .bjp_op_blt_o  (inst1_logic_bjp_op_blt),
        .bjp_op_bltu_o (inst1_logic_bjp_op_bltu),
        .bjp_op_bge_o  (inst1_logic_bjp_op_bge),
        .bjp_op_bgeu_o (inst1_logic_bjp_op_bgeu),
        .bjp_op_jalr_o (inst1_logic_bjp_op_jalr),

        // MUL信号
        .req_mul_o      (inst1_logic_req_mul),
        .mul_op1_o      (inst1_logic_mul_op1),
        .mul_op2_o      (inst1_logic_mul_op2),
        .mul_op_mul_o   (inst1_logic_mul_op_mul),
        .mul_op_mulh_o  (inst1_logic_mul_op_mulh),
        .mul_op_mulhsu_o(inst1_logic_mul_op_mulhsu),
        .mul_op_mulhu_o (inst1_logic_mul_op_mulhu),

        // DIV信号
        .req_div_o    (inst1_logic_req_div),
        .div_op1_o    (inst1_logic_div_op1),
        .div_op2_o    (inst1_logic_div_op2),
        .div_op_div_o (inst1_logic_div_op_div),
        .div_op_divu_o(inst1_logic_div_op_divu),
        .div_op_rem_o (inst1_logic_div_op_rem),
        .div_op_remu_o(inst1_logic_div_op_remu),

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


    // 实例化dispatch_pipe模块 - 第一路
    dispatch_pipe u_inst1_dispatch_pipe (
        .clk                  (clk),
        .rst_n                (rst_n),
        .stall_flag_i         (stall_flag_i),
        .inst_valid_i         (inst1_valid_i),
        .inst_i               (inst1_i),
        .inst_addr_i          (inst1_addr_i),
        .commit_id_i          (inst1_commit_id_i),

        .reg_we_i             (inst1_reg_we_i),
        .reg_waddr_i          (inst1_reg_waddr_i),
        .rs1_rdata_i         (inst1_rs1_rdata_i),
        .rs2_rdata_i         (inst1_rs1_rdata_i),
        .csr_we_i             (inst1_csr_we_i),
        .csr_waddr_i          (inst1_csr_waddr_i),
        .csr_raddr_i          (inst1_csr_raddr_i),
        .dec_imm_i            (inst1_dec_imm_i),
        .dec_info_bus_i       (inst1_dec_info_bus_i),
        .is_pred_branch_i     (inst1_is_pred_branch_i),
        .illegal_inst_i      (inst1_illegal_inst_i),
        // alu信号
        .req_alu_i          (inst1_logic_req_alu),
        .alu_op1_i          (inst1_logic_alu_op1),
        .alu_op2_i          (inst1_logic_alu_op2),
        .alu_op_info_i      (inst1_logic_alu_op_info),
        // BJP信号
        .req_bjp_i          (inst1_logic_req_bjp),
        .bjp_op1_i          (inst1_logic_bjp_op1),
        .bjp_op2_i          (inst1_logic_bjp_op2),
        .bjp_jump_op1_i     (inst1_logic_bjp_jump_op1),
        .bjp_jump_op2_i     (inst1_logic_bjp_jump_op2),
        .bjp_op_jal_i       (inst1_logic_bjp_op_jal),
        .bjp_op_beq_i       (inst1_logic_bjp_op_beq),
        .bjp_op_bne_i       (inst1_logic_bjp_op_bne),
        .bjp_op_blt_i       (inst1_logic_bjp_op_blt),
        .bjp_op_bltu_i      (inst1_logic_bjp_op_bltu),
        .bjp_op_bge_i       (inst1_logic_bjp_op_bge),
        .bjp_op_bgeu_i      (inst1_logic_bjp_op_bgeu),
        .bjp_op_jalr_i      (inst1_logic_bjp_op_jalr),
         // MUL信号输入
        .req_mul_i      (inst1_logic_req_mul),
        .mul_op1_i      (inst1_logic_mul_op1),
        .mul_op2_i      (inst1_logic_mul_op2),
        .mul_op_mul_i   (inst1_logic_mul_op_mul),
        .mul_op_mulh_i  (inst1_logic_mul_op_mulh),
        .mul_op_mulhsu_i(inst1_logic_mul_op_mulhsu),
        .mul_op_mulhu_i (inst1_logic_mul_op_mulhu),

        // DIV信号输入
        .req_div_i    (inst1_logic_req_div),
        .div_op1_i    (inst1_logic_div_op1),
        .div_op2_i    (inst1_logic_div_op2),
        .div_op_div_i (inst1_logic_div_op_div),
        .div_op_divu_i(inst1_logic_div_op_divu),
        .div_op_rem_i (inst1_logic_div_op_rem),
        .div_op_remu_i(inst1_logic_div_op_remu),

        // CSR信号
        .req_csr_i          (inst1_logic_req_csr),
        .csr_op1_i          (inst1_logic_csr_op1),
        .csr_addr_i         (inst1_logic_csr_addr),
        .csr_csrrw_i       (inst1_logic_csr_csrrw),
        .csr_csrrs_i       (inst1_logic_csr_csrrs),
        .csr_csrrc_i       (inst1_logic_csr_csrrc),
        // MEM信号
        .req_mem_i          (inst1_logic_req_mem),
        .mem_op_lb_i        (inst1_logic_mem_op_lb),
        .mem_op_lh_i        (inst1_logic_mem_op_lh),
        .mem_op_lw_i        (inst1_logic_mem_op_lw),    
        .mem_op_lbu_i       (inst1_logic_mem_op_lbu),
        .mem_op_lhu_i       (inst1_logic_mem_op_lhu),
        .mem_op_load_i      (inst1_logic_mem_op_load),
        .mem_op_store_i     (inst1_logic_mem_op_store),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_i         (inst1_logic_mem_addr),
        .mem_wmask_i        (inst1_logic_mem_wmask),
        .mem_wdata_i        (inst1_logic_mem_wdata),
        // SYS信号
        .sys_op_nop_i       (inst1_logic_sys_op_nop),
        .sys_op_mret_i      (inst1_logic_sys_op_mret),
        .sys_op_ecall_i     (inst1_logic_sys_op_ecall),
        .sys_op_ebreak_i    (inst1_logic_sys_op_ebreak),
        .sys_op_fence_i     (inst1_logic_sys_op_fence),
        .sys_op_dret_i      (inst1_logic_sys_op_dret),
        // 新增：未对齐访存异常
        .misaligned_load_i  (inst1_logic_misaligned_load),
        .misaligned_store_i (inst1_logic_misaligned_store),

        //输出
        .inst_addr_o          (inst1_addr_o),
        .commit_id_o          (inst1_commit_id_o),
        .inst_valid_o         (inst1_valid_o),
        .inst_o               (inst1_o),
        .reg_we_o             (inst1_reg_we_o),
        .reg_waddr_o          (inst1_reg_waddr_o),
        .csr_we_o             (pipe_inst1_csr_we_o),
        .csr_waddr_o          (pipe_inst1_csr_waddr_o),
        .csr_raddr_o          (pipe_inst1_csr_raddr_o),
        .dec_imm_o            (inst1_dec_imm_o),
        .dec_info_bus_o       (inst1_dec_info_bus_o),
        .rs1_rdata_o          (inst1_rs1_rdata_o),
        .rs2_rdata_o          (inst1_rs2_rdata_o),
        .is_pred_branch_o     (pipe_inst1_is_pred_branch),
        .illegal_inst_o       (inst1_illegal_inst_o),
        // Alu输出端口
        .req_alu_o            (inst1_req_alu_o),
        .alu_op1_o            (inst1_alu_op1_o),
        .alu_op2_o            (inst1_alu_op2_o),
        .alu_op_info_o        (inst1_alu_op_info_o),
        // BJP输出端口
        .req_bjp_o            (pipe_inst1_req_bjp_o),
        .bjp_op1_o            (pipe_inst1_bjp_op1_o),
        .bjp_op2_o            (pipe_inst1_bjp_op2_o),
        .bjp_jump_op1_o       (pipe_inst1_bjp_jump_op1_o),
        .bjp_jump_op2_o       (pipe_inst1_bjp_jump_op2_o),
        .bjp_op_jal_o        (pipe_inst1_bjp_op_jal_o),
        .bjp_op_beq_o       (pipe_inst1_bjp_op_beq_o),
        .bjp_op_bne_o       (pipe_inst1_bjp_op_bne_o),
        .bjp_op_blt_o       (pipe_inst1_bjp_op_blt_o),
        .bjp_op_bltu_o      (pipe_inst1_bjp_op_bltu_o),
        .bjp_op_bge_o       (pipe_inst1_bjp_op_bge_o),
        .bjp_op_bgeu_o      (pipe_inst1_bjp_op_bgeu_o),
        .bjp_op_jalr_o      (pipe_inst1_bjp_op_jalr_o),
        // MUL信号输出
        .req_mul_o      (inst1_req_mul_o),
        .mul_op1_o      (inst1_mul_op1_o),
        .mul_op2_o      (inst1_mul_op2_o),
        .mul_op_mul_o   (inst1_mul_op_mul_o),
        .mul_op_mulh_o  (inst1_mul_op_mulh_o),
        .mul_op_mulhsu_o(inst1_mul_op_mulhsu_o),
        .mul_op_mulhu_o (inst1_mul_op_mulhu_o),
        // DIV信号输出
        .req_div_o    (inst1_req_div_o),
        .div_op1_o    (inst1_div_op1_o),
        .div_op2_o    (inst1_div_op2_o),
        .div_op_div_o (inst1_div_op_div_o),
        .div_op_divu_o(inst1_div_op_divu_o),
        .div_op_rem_o (inst1_div_op_rem_o),
        .div_op_remu_o(inst1_div_op_remu_o),
        // CSR输出端口
        .req_csr_o           (pipe_inst1_req_csr_o),
        .csr_op1_o           (pipe_inst1_csr_op1_o),
        .csr_addr_o          (pipe_inst1_csr_addr_o),
        .csr_csrrw_o        (pipe_inst1_csr_csrrw_o),
        .csr_csrrs_o        (pipe_inst1_csr_csrrs_o),
        .csr_csrrc_o        (pipe_inst1_csr_csrrc_o),
        // MEM输出端口
        .req_mem_o           (inst1_req_mem_o),
        .mem_op_lb_o        (inst1_mem_op_lb_o),
        .mem_op_lh_o        (inst1_mem_op_lh_o),
        .mem_op_lw_o        (inst1_mem_op_lw_o),
        .mem_op_lbu_o       (inst1_mem_op_lbu_o),
        .mem_op_lhu_o       (inst1_mem_op_lhu_o),
        .mem_op_load_o      (inst1_mem_op_load_o),
        .mem_op_store_o     (inst1_mem_op_store_o),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_o         (inst1_mem_addr_o),
        .mem_wmask_o       (inst1_mem_wmask_o),
        .mem_wdata_o       (inst1_mem_wdata_o),
        // 新增：未对齐访存异常输出
        .misaligned_load_o  (inst1_misaligned_load_o),
        .misaligned_store_o  (inst1_misaligned_store_o),
        // SYS输出端口
        .sys_op_nop_o       (pipe_inst1_sys_op_nop_o),
        .sys_op_mret_o      (pipe_inst1_sys_op_mret_o),
        .sys_op_ecall_o     (pipe_inst1_sys_op_ecall_o),
        .sys_op_ebreak_o    (pipe_inst1_sys_op_ebreak_o),
        .sys_op_fence_o     (pipe_inst1_sys_op_fence_o),
        .sys_op_dret_o      (pipe_inst1_sys_op_dret_o),
        //fake_commit信号，inst1的输出空置
        .req_fake_commit_o  (),
        .fake_commit_id_o  ()
    );

    // 实例化dispatch_logic模块 (第二路)
    dispatch_logic u_inst2_dispatch_logic (
        .dec_info_bus_i(inst2_dec_info_bus_i),
        .dec_imm_i     (inst2_dec_imm_i),
        .dec_pc_i      (inst2_addr_i),
        .rs1_rdata_i   (inst2_rs1_rdata_i),
        .rs2_rdata_i   (inst2_rs2_rdata_i),

        // Alu信号
        .req_alu_o    (inst2_logic_req_alu),
        .alu_op1_o    (inst2_logic_alu_op1),
        .alu_op2_o    (inst2_logic_alu_op2),
        .alu_op_info_o(inst2_logic_alu_op_info),
        // BJP信号
        .req_bjp_o     (inst2_logic_req_bjp),
        .bjp_op1_o     (inst2_logic_bjp_op1),
        .bjp_op2_o     (inst2_logic_bjp_op2),
        .bjp_jump_op1_o(inst2_logic_bjp_jump_op1),
        .bjp_jump_op2_o(inst2_logic_bjp_jump_op2),
        .bjp_op_jal_o  (inst2_logic_bjp_op_jal),
        .bjp_op_beq_o  (inst2_logic_bjp_op_beq),
        .bjp_op_bne_o  (inst2_logic_bjp_op_bne),
        .bjp_op_blt_o  (inst2_logic_bjp_op_blt),
        .bjp_op_bltu_o (inst2_logic_bjp_op_bltu),
        .bjp_op_bge_o  (inst2_logic_bjp_op_bge),
        .bjp_op_bgeu_o (inst2_logic_bjp_op_bgeu),
        .bjp_op_jalr_o (inst2_logic_bjp_op_jalr),
        // MUL信号
        .req_mul_o      (inst2_logic_req_mul),
        .mul_op1_o      (inst2_logic_mul_op1),
        .mul_op2_o      (inst2_logic_mul_op2),
        .mul_op_mul_o   (inst2_logic_mul_op_mul),
        .mul_op_mulh_o  (inst2_logic_mul_op_mulh),
        .mul_op_mulhsu_o(inst2_logic_mul_op_mulhsu),
        .mul_op_mulhu_o (inst2_logic_mul_op_mulhu),

        // DIV信号
        .req_div_o    (inst2_logic_req_div),
        .div_op1_o    (inst2_logic_div_op1),
        .div_op2_o    (inst2_logic_div_op2),
        .div_op_div_o (inst2_logic_div_op_div),
        .div_op_divu_o(inst2_logic_div_op_divu),
        .div_op_rem_o (inst2_logic_div_op_rem),
        .div_op_remu_o(inst2_logic_div_op_remu),
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


       // 实例化dispatch_pipe模块 - 第二路
    dispatch_pipe u_inst2_dispatch_pipe (
        .clk                  (clk),
        .rst_n                (rst_n),
        .stall_flag_i         (stall_flag_i),
        .inst_valid_i         (inst2_valid_i),
        .inst_i               (inst2_i),
        .inst_addr_i          (inst2_addr_i),
        .commit_id_i          (inst2_commit_id_i),

        .reg_we_i             (inst2_reg_we_i),
        .reg_waddr_i          (inst2_reg_waddr_i),
        .rs1_rdata_i         (inst2_rs1_rdata_i),
        .rs2_rdata_i         (inst2_rs2_rdata_i),
        .csr_we_i             (inst2_csr_we_i),
        .csr_waddr_i          (inst2_csr_waddr_i),
        .csr_raddr_i          (inst2_csr_raddr_i),
        .dec_imm_i            (inst2_dec_imm_i),
        .dec_info_bus_i       (inst2_dec_info_bus_i),
        .is_pred_branch_i     (inst2_is_pred_branch_i),
        .illegal_inst_i      (inst2_illegal_inst_i),
        // alu信号
        .req_alu_i            (inst2_logic_req_alu),
        .alu_op1_i            (inst2_logic_alu_op1),
        .alu_op2_i            (inst2_logic_alu_op2),
        .alu_op_info_i        (inst2_logic_alu_op_info),
        // BJP信号
        .req_bjp_i          (inst2_logic_req_bjp),
        .bjp_op1_i          (inst2_logic_bjp_op1),
        .bjp_op2_i          (inst2_logic_bjp_op2),
        .bjp_jump_op1_i     (inst2_logic_bjp_jump_op1),
        .bjp_jump_op2_i     (inst2_logic_bjp_jump_op2),
        .bjp_op_jal_i       (inst2_logic_bjp_op_jal),
        .bjp_op_beq_i       (inst2_logic_bjp_op_beq),
        .bjp_op_bne_i       (inst2_logic_bjp_op_bne),
        .bjp_op_blt_i       (inst2_logic_bjp_op_blt),
        .bjp_op_bltu_i      (inst2_logic_bjp_op_bltu),
        .bjp_op_bge_i       (inst2_logic_bjp_op_bge),
        .bjp_op_bgeu_i      (inst2_logic_bjp_op_bgeu),
        .bjp_op_jalr_i      (inst2_logic_bjp_op_jalr),
        // MUL信号输入
        .req_mul_i      (inst2_logic_req_mul),
        .mul_op1_i      (inst2_logic_mul_op1),
        .mul_op2_i      (inst2_logic_mul_op2),
        .mul_op_mul_i   (inst2_logic_mul_op_mul),
        .mul_op_mulh_i  (inst2_logic_mul_op_mulh),
        .mul_op_mulhsu_i(inst2_logic_mul_op_mulhsu),
        .mul_op_mulhu_i (inst2_logic_mul_op_mulhu),

        // DIV信号输入
        .req_div_i    (inst2_logic_req_div),
        .div_op1_i    (inst2_logic_div_op1),
        .div_op2_i    (inst2_logic_div_op2),
        .div_op_div_i (inst2_logic_div_op_div),
        .div_op_divu_i(inst2_logic_div_op_divu),
        .div_op_rem_i (inst2_logic_div_op_rem),
        .div_op_remu_i(inst2_logic_div_op_remu),
        // CSR信号
        .req_csr_i          (inst2_logic_req_csr),
        .csr_op1_i          (inst2_logic_csr_op1),
        .csr_addr_i         (inst2_logic_csr_addr),
        .csr_csrrw_i       (inst2_logic_csr_csrrw),
        .csr_csrrs_i       (inst2_logic_csr_csrrs),
        .csr_csrrc_i       (inst2_logic_csr_csrrc),
        // MEM信号
        .req_mem_i          (inst2_logic_req_mem),
        .mem_op_lb_i        (inst2_logic_mem_op_lb),
        .mem_op_lh_i        (inst2_logic_mem_op_lh),
        .mem_op_lw_i        (inst2_logic_mem_op_lw),
        .mem_op_lbu_i       (inst2_logic_mem_op_lbu),
        .mem_op_lhu_i       (inst2_logic_mem_op_lhu),
        .mem_op_load_i      (inst2_logic_mem_op_load),
        .mem_op_store_i     (inst2_logic_mem_op_store),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_i         (inst2_logic_mem_addr),
        .mem_wmask_i        (inst2_logic_mem_wmask),
        .mem_wdata_i        (inst2_logic_mem_wdata),
        // SYS信号
        .sys_op_nop_i       (inst2_logic_sys_op_nop),
        .sys_op_mret_i      (inst2_logic_sys_op_mret),
        .sys_op_ecall_i     (inst2_logic_sys_op_ecall),
        .sys_op_ebreak_i    (inst2_logic_sys_op_ebreak),
        .sys_op_fence_i     (inst2_logic_sys_op_fence),
        .sys_op_dret_i      (inst2_logic_sys_op_dret),
        // 新增：未对齐访存异常
        .misaligned_load_i  (inst2_logic_misaligned_load),
        .misaligned_store_i (inst2_logic_misaligned_store),

        //输出
        .inst_addr_o          (inst2_addr_o),
        .commit_id_o          (inst2_commit_id_o),
        .inst_valid_o         (inst2_valid_o),
        .inst_o               (inst2_o),
        .reg_we_o             (inst2_reg_we_o),
        .reg_waddr_o          (inst2_reg_waddr_o),
        .csr_we_o             (pipe_inst2_csr_we_o),
        .csr_waddr_o          (pipe_inst2_csr_waddr_o),
        .csr_raddr_o          (pipe_inst2_csr_raddr_o),
        .dec_imm_o            (inst2_dec_imm_o),
        .dec_info_bus_o       (inst2_dec_info_bus_o),
        .rs1_rdata_o          (inst2_rs1_rdata_o),
        .rs2_rdata_o          (inst2_rs2_rdata_o),
        .is_pred_branch_o     (pipe_inst2_is_pred_branch),
        .illegal_inst_o       (inst2_illegal_inst_o),
        // Alu输出端口
        .req_alu_o            (inst2_req_alu_o),
        .alu_op1_o            (inst2_alu_op1_o),
        .alu_op2_o            (inst2_alu_op2_o),
        .alu_op_info_o        (inst2_alu_op_info_o),
        // BJP输出端口
        .req_bjp_o            (pipe_inst2_req_bjp_o),
        .bjp_op1_o            (pipe_inst2_bjp_op1_o),
        .bjp_op2_o            (pipe_inst2_bjp_op2_o),
        .bjp_jump_op1_o       (pipe_inst2_bjp_jump_op1_o),
        .bjp_jump_op2_o       (pipe_inst2_bjp_jump_op2_o),
        .bjp_op_jal_o        (pipe_inst2_bjp_op_jal_o),
        .bjp_op_beq_o       (pipe_inst2_bjp_op_beq_o),
        .bjp_op_bne_o       (pipe_inst2_bjp_op_bne_o),
        .bjp_op_blt_o       (pipe_inst2_bjp_op_blt_o),
        .bjp_op_bltu_o      (pipe_inst2_bjp_op_bltu_o),
        .bjp_op_bge_o       (pipe_inst2_bjp_op_bge_o),
        .bjp_op_bgeu_o      (pipe_inst2_bjp_op_bgeu_o),
        .bjp_op_jalr_o      (pipe_inst2_bjp_op_jalr_o),
        // MUL信号输出
        .req_mul_o      (inst2_req_mul_o),
        .mul_op1_o      (inst2_mul_op1_o),
        .mul_op2_o      (inst2_mul_op2_o),
        .mul_op_mul_o   (inst2_mul_op_mul_o),
        .mul_op_mulh_o  (inst2_mul_op_mulh_o),
        .mul_op_mulhsu_o(inst2_mul_op_mulhsu_o),
        .mul_op_mulhu_o (inst2_mul_op_mulhu_o),
        // DIV信号输出
        .req_div_o    (inst2_req_div_o),
        .div_op1_o    (inst2_div_op1_o),
        .div_op2_o    (inst2_div_op2_o),
        .div_op_div_o (inst2_div_op_div_o),
        .div_op_divu_o(inst2_div_op_divu_o),
        .div_op_rem_o (inst2_div_op_rem_o),
        .div_op_remu_o(inst2_div_op_remu_o),
        // CSR输出端口
        .req_csr_o           (pipe_inst2_req_csr_o),
        .csr_op1_o           (pipe_inst2_csr_op1_o),
        .csr_addr_o          (pipe_inst2_csr_addr_o),
        .csr_csrrw_o        (pipe_inst2_csr_csrrw_o),
        .csr_csrrs_o        (pipe_inst2_csr_csrrs_o),
        .csr_csrrc_o        (pipe_inst2_csr_csrrc_o),
        // MEM输出端口
        .req_mem_o           (inst2_req_mem_o),
        .mem_op_lb_o        (inst2_mem_op_lb_o),
        .mem_op_lh_o        (inst2_mem_op_lh_o),
        .mem_op_lw_o        (inst2_mem_op_lw_o),
        .mem_op_lbu_o       (inst2_mem_op_lbu_o),
        .mem_op_lhu_o       (inst2_mem_op_lhu_o),
        .mem_op_load_o      (inst2_mem_op_load_o),
        .mem_op_store_o     (inst2_mem_op_store_o),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_o         (inst2_mem_addr_o),
        .mem_wmask_o       (inst2_mem_wmask_o),
        .mem_wdata_o       (inst2_mem_wdata_o),
        // 新增：未对齐访存异常输出
        .misaligned_load_o  (inst2_misaligned_load_o),
        .misaligned_store_o  (inst2_misaligned_store_o),
        // SYS输出端口
        .sys_op_nop_o       (pipe_inst2_sys_op_nop_o),
        .sys_op_mret_o      (pipe_inst2_sys_op_mret_o),
        .sys_op_ecall_o     (pipe_inst2_sys_op_ecall_o),
        .sys_op_ebreak_o    (pipe_inst2_sys_op_ebreak_o),
        .sys_op_fence_o     (pipe_inst2_sys_op_fence_o),
        .sys_op_dret_o      (pipe_inst2_sys_op_dret_o),
        //fake_commit信号，inst2的输出空置
        .req_fake_commit_o  (req_fake_commit_o),
        .fake_commit_id_o   (fake_commit_id_o)
    );
    // CSR合并逻辑
    // 由于ICU已经处理了两个指令都是CSR的情况（通过RAW冒险检测），
    // 这里只需要简单的OR逻辑来合并两路CSR输出
    // 优先级：如果第一路有有效的CSR请求，则使用第一路；否则使用第二路
    assign req_csr_o = pipe_inst1_req_csr_o | pipe_inst2_req_csr_o;

    // 当第一路有CSR请求时，使用第一路的信号；否则使用第二路的信号
    assign csr_op1_o  = pipe_inst1_req_csr_o ? pipe_inst1_csr_op1_o  : pipe_inst2_req_csr_o ? pipe_inst2_csr_op1_o : 32'b0;
    assign csr_addr_o = pipe_inst1_req_csr_o ? pipe_inst1_csr_addr_o : pipe_inst2_req_csr_o ? pipe_inst2_csr_addr_o : 32'b0;
    assign csr_csrrw_o = pipe_inst1_req_csr_o ? pipe_inst1_csr_csrrw_o : pipe_inst2_req_csr_o? pipe_inst2_csr_csrrw_o : 0;
    assign csr_csrrs_o = pipe_inst1_req_csr_o ? pipe_inst1_csr_csrrs_o : pipe_inst2_req_csr_o ? pipe_inst2_csr_csrrs_o : 0;
    assign csr_csrrc_o = pipe_inst1_req_csr_o ? pipe_inst1_csr_csrrc_o : pipe_inst2_req_csr_o ? pipe_inst2_csr_csrrc_o : 0;
    assign csr_we_o =  pipe_inst1_csr_we_o | pipe_inst2_csr_we_o;
    assign csr_waddr_o = pipe_inst1_csr_we_o ? pipe_inst1_csr_waddr_o : pipe_inst2_req_csr_o ? pipe_inst2_csr_waddr_o : 32'b0;
    assign csr_raddr_o = pipe_inst1_csr_we_o ? pipe_inst1_csr_raddr_o : pipe_inst2_req_csr_o ? pipe_inst2_csr_raddr_o : 32'b0;
    assign csr_reg_we_o = pipe_inst1_req_csr_o ? inst1_reg_we_o : pipe_inst2_req_csr_o ? inst2_reg_we_o : 1'b0;
    assign csr_reg_waddr_o = pipe_inst1_req_csr_o ? inst1_reg_waddr_o : pipe_inst2_req_csr_o ? inst2_reg_waddr_o : 5'b0;
    assign csr_commit_id_o = pipe_inst1_req_csr_o ? inst1_commit_id_o : pipe_inst2_req_csr_o ? inst2_commit_id_o : 3'b0;

    // BJP合并逻辑
    // 由于ICU已经处理了两个指令都是BJP的情况（通过RAW冒险检测），
    // 这里只需要简单的OR逻辑来合并两路BJP输出
    // 优先级：如果第一路有有效的BJP请求，则使用第一路；否则使用第二路
    assign req_bjp_o = pipe_inst1_req_bjp_o | pipe_inst2_req_bjp_o;
    // 当第一路有BJP请求时，使用第一路的信号；否则使用第二路的信号
    assign bjp_op1_o        = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op1_o        : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op1_o : 32'b0;
    assign bjp_op2_o        = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op2_o        : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op2_o : 32'b0;
    assign bjp_jump_op1_o   = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_jump_op1_o   : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_jump_op1_o : 32'b0;
    assign bjp_jump_op2_o   = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_jump_op2_o   : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_jump_op2_o : 32'b0;
    assign bjp_op_jal_o     = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_jal_o     : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_jal_o : 0;
    assign bjp_op_beq_o     = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_beq_o     : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_beq_o : 0;
    assign bjp_op_bne_o     = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_bne_o     : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_bne_o : 0;
    assign bjp_op_blt_o     = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_blt_o     : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_blt_o : 0;
    assign bjp_op_bltu_o    = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_bltu_o    : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_bltu_o : 0;
    assign bjp_op_bge_o     = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_bge_o     : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_bge_o : 0;
    assign bjp_op_bgeu_o    = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_bgeu_o    : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_bgeu_o : 0;
    assign bjp_op_jalr_o    = pipe_inst1_req_bjp_o ? pipe_inst1_bjp_op_jalr_o : pipe_inst2_req_bjp_o ? pipe_inst2_bjp_op_jalr_o : 0;

    assign inst_is_pred_branch_o = pipe_inst1_is_pred_branch | pipe_inst2_is_pred_branch;

    //sys合并逻辑
    //sys只留一路即可
    assign sys_op_nop_o   = pipe_inst1_sys_op_nop_o | pipe_inst2_sys_op_nop_o;
    assign sys_op_mret_o  = pipe_inst1_sys_op_mret_o | pipe_inst2_sys_op_mret_o;
    assign sys_op_ecall_o = pipe_inst1_sys_op_ecall_o | pipe_inst2_sys_op_ecall_o;
    assign sys_op_ebreak_o = pipe_inst1_sys_op_ebreak_o | pipe_inst2_sys_op_ebreak_o;
    assign sys_op_fence_o = pipe_inst1_sys_op_fence_o | pipe_inst2_sys_op_fence_o;
    assign sys_op_dret_o  = pipe_inst1_sys_op_dret_o | pipe_inst2_sys_op_dret_o;

    assign inst1_mul_commit_id_o = inst1_commit_id_o;
    assign inst2_mul_commit_id_o = inst2_commit_id_o;
    assign inst1_div_commit_id_o = inst1_commit_id_o;
    assign inst2_div_commit_id_o = inst2_commit_id_o;

endmodule