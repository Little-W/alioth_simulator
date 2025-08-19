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
    // 流水线暂停标志
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_dis_i,

    // 从ICU接收的第一路指令信息
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i,
    input wire                        inst1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_i,
    input wire [                31:0] inst1_csr_waddr_i,
    input wire [                31:0] inst1_csr_raddr_i,
    input wire                        inst1_csr_we_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst1_i,

    // 从ICU接收的第二路指令信息
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire [                31:0] inst2_csr_waddr_i,
    input wire [                31:0] inst2_csr_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    input wire                        inst2_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst2_i,

    // 从GPR读取的寄存器数据
    input wire [`REG_DATA_WIDTH-1:0] inst1_rs1_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] inst1_rs2_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] inst2_rs1_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] inst2_rs2_rdata_i,

    // 指令有效信号和异常信号
    input wire inst1_valid_i,
    input wire inst2_valid_i,
    input wire inst1_illegal_inst_i,
    input wire inst2_illegal_inst_i,

    input wire                          exu_lsu_stall_i,
    //hdu所需输入
    input wire                          clint_req_valid_i,
    //来自idu
    input wire [`EX_INFO_BUS_WIDTH-1:0] inst1_ex_info_bus_i,
    input wire [`EX_INFO_BUS_WIDTH-1:0] inst2_ex_info_bus_i,
    input wire                          inst1_jump_i,
    input wire                          inst1_branch_i,
    //来自wbu
    input wire                          inst1_commit_valid_i,
    input wire                          inst2_commit_valid_i,
    input wire [  `COMMIT_ID_WIDTH-1:0] inst1_wb_commit_id_i,
    input wire [  `COMMIT_ID_WIDTH-1:0] inst2_wb_commit_id_i,
    //来自bru
    input wire                          pred_taken_i,

    //分发到各功能单元的输出接口
    // dispatch to alu (第一路)
    output wire                     inst1_req_alu_o,
    output wire [             31:0] inst1_alu_op1_o,
    output wire [             31:0] inst1_alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] inst1_alu_op_info_o,

    // dispatch to alu (第二路)
    output wire                     inst2_req_alu_o,
    output wire [             31:0] inst2_alu_op1_o,
    output wire [             31:0] inst2_alu_op2_o,
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
    // dispatch to CSR (第一路)
    output wire                        inst1_req_csr_o,
    output wire [                31:0] inst1_csr_op1_o,
    output wire [                31:0] inst1_csr_addr_o,
    output wire                        inst1_csr_csrrw_o,
    output wire                        inst1_csr_csrrs_o,
    output wire                        inst1_csr_csrrc_o,
    output wire                        inst1_csr_we_o,
    output wire [                31:0] inst1_csr_waddr_o,
    output wire [                31:0] inst1_csr_raddr_o,
    output wire                        inst1_csr_reg_we_o,
    output wire [                 4:0] inst1_csr_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_csr_commit_id_o,

    // dispatch to CSR (第二路)
    output wire                        inst2_req_csr_o,
    output wire [                31:0] inst2_csr_op1_o,
    output wire [                31:0] inst2_csr_addr_o,
    output wire                        inst2_csr_csrrw_o,
    output wire                        inst2_csr_csrrs_o,
    output wire                        inst2_csr_csrrc_o,
    output wire                        inst2_csr_we_o,
    output wire [                31:0] inst2_csr_waddr_o,
    output wire [                31:0] inst2_csr_raddr_o,
    output wire                        inst2_csr_reg_we_o,
    output wire [                 4:0] inst2_csr_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_csr_commit_id_o,

    // dispatch to MEM
    output wire        req_mem_o,
    output wire        mem_op_lb_o,
    output wire        mem_op_lh_o,
    output wire        mem_op_lw_o,
    output wire        mem_op_lbu_o,
    output wire        mem_op_lhu_o,
    output wire        mem_op_load_o,
    output wire        mem_op_store_o,
    output wire [31:0] mem_addr_o,
    output wire [ 7:0] mem_wmask_o,
    output wire [63:0] mem_wdata_o,
    output wire [ 2:0] mem_commit_id_o,
    output wire [ 4:0] mem_reg_waddr_o,
    output wire        misaligned_load_o,
    output wire        misaligned_store_o,
    output wire        mem_stall_req_o,

    // dispatch to SYS (合并单路输出)
    output wire sys_op_nop_o,
    output wire sys_op_mret_o,
    output wire sys_op_ecall_o,
    output wire sys_op_ebreak_o,
    output wire sys_op_fence_o,
    output wire sys_op_dret_o,

    //指令其他信号（第一路）
    output wire inst1_illegal_inst_o,

    //指令其他信号（第二路）
    output wire inst2_illegal_inst_o,

    // 输出指令地址和提交ID以及保留到后续模块的其他指令信息
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,
    output wire [                31:0] inst1_o,
    output wire [                31:0] inst2_o,
    output wire                        inst1_valid_o,
    output wire                        inst2_valid_o,
    output wire                        inst1_reg_we_o,
    output wire                        inst2_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,
    output wire [                31:0] inst1_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o,
    output wire [                31:0] inst2_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o,
    output wire [                31:0] inst1_rs1_rdata_o,
    output wire [                31:0] inst1_rs2_rdata_o,
    output wire [                31:0] inst2_rs1_rdata_o,
    output wire [                31:0] inst2_rs2_rdata_o,
    output wire [                 2:0] inst1_commit_id_o,
    output wire [                 2:0] inst2_commit_id_o,
    //hdu 直接输出信号
    // to ctrl
    output wire [                 1:0] issue_inst_o,
    //to clint
    output wire                        dispatch_atom_lock_o,

    // HDU流水线输出信号 (第一路)
    output wire inst1_alu_pass_alu2_op1_o,
    output wire inst1_alu_pass_alu2_op2_o,
    output wire inst1_mul_pass_alu2_op1_o,
    output wire inst1_mul_pass_alu2_op2_o,
    output wire inst1_div_pass_alu2_op1_o,
    output wire inst1_div_pass_alu2_op2_o,
    output wire inst1_alu_pass_alu1_op1_o,
    output wire inst1_alu_pass_alu1_op2_o,
    output wire inst1_mul_pass_alu1_op1_o,
    output wire inst1_mul_pass_alu1_op2_o,
    output wire inst1_div_pass_alu1_op1_o,
    output wire inst1_div_pass_alu1_op2_o,

    // HDU流水线输出信号 (第二路)
    output wire inst2_alu_pass_alu1_op1_o,
    output wire inst2_alu_pass_alu1_op2_o,
    output wire inst2_mul_pass_alu1_op1_o,
    output wire inst2_mul_pass_alu1_op2_o,
    output wire inst2_div_pass_alu1_op1_o,
    output wire inst2_div_pass_alu1_op2_o,
    output wire inst2_alu_pass_alu2_op1_o,
    output wire inst2_alu_pass_alu2_op2_o,
    output wire inst2_mul_pass_alu2_op1_o,
    output wire inst2_mul_pass_alu2_op2_o,
    output wire inst2_div_pass_alu2_op1_o,
    output wire inst2_div_pass_alu2_op2_o
);

    // 内部连线，用于连接dispatch_logic和dispatch_pipe

    // === 新增：AGU单路输出连线 ===
    wire [31:0] agu_addr;
    wire [7:0] agu_wmask;
    wire [63:0] agu_wdata;
    wire agu_mis_ld;
    wire agu_mis_st;
    // 新增：AGU导出的MEM操作类型
    wire agu_req_mem;
    wire agu_mem_lb;
    wire agu_mem_lh;
    wire agu_mem_lw;
    wire agu_mem_lbu;
    wire agu_mem_lhu;
    wire agu_mem_load;
    wire agu_mem_store;
    wire [2:0] agu_commit_id;
    wire [4:0] agu_mem_reg_waddr;
    wire agu_atom_lock;
    wire agu_stall_req;

    // HDU相关信号
    wire hdu_inst1_valid = inst1_valid_i && !stall_flag_dis_i && !clint_req_valid_i;
    wire hdu_inst2_valid = inst2_valid_i && !stall_flag_dis_i && !clint_req_valid_i && !pred_taken_i;
    wire [1:0] hdu_issue_inst;
    wire [2:0] hdu_inst1_commit_id;
    wire [2:0] hdu_inst2_commit_id;
    wire hdu_alu1_pass_alu1_op1;
    wire hdu_alu1_pass_alu1_op2;
    wire hdu_alu1_pass_alu2_op1;
    wire hdu_alu1_pass_alu2_op2;
    wire hdu_mul1_pass_alu1_op1;
    wire hdu_mul1_pass_alu1_op2;
    wire hdu_mul1_pass_alu2_op1;
    wire hdu_mul1_pass_alu2_op2;
    wire hdu_div1_pass_alu1_op1;
    wire hdu_div1_pass_alu1_op2;
    wire hdu_div1_pass_alu2_op1;
    wire hdu_div1_pass_alu2_op2;
    wire hdu_alu2_pass_alu2_op1;
    wire hdu_alu2_pass_alu2_op2;
    wire hdu_alu2_pass_alu1_op1;
    wire hdu_alu2_pass_alu1_op2;
    wire hdu_mul2_pass_alu1_op1;
    wire hdu_mul2_pass_alu1_op2;
    wire hdu_mul2_pass_alu2_op1;
    wire hdu_mul2_pass_alu2_op2;
    wire hdu_div2_pass_alu1_op1;
    wire hdu_div2_pass_alu1_op2;
    wire hdu_div2_pass_alu2_op1;
    wire hdu_div2_pass_alu2_op2;
    wire hdu_long_inst_atom_lock;

    // 第一路和第二路CSR内部信号
    wire pipe_inst1_req_csr_o;
    wire [31:0] pipe_inst1_csr_op1_o;
    wire [31:0] pipe_inst1_csr_addr_o;
    wire pipe_inst1_csr_csrrw_o;
    wire pipe_inst1_csr_csrrs_o;
    wire pipe_inst1_csr_csrrc_o;
    wire pipe_inst1_csr_we_o;
    wire [31:0] pipe_inst1_csr_waddr_o;
    wire [31:0] pipe_inst1_csr_raddr_o;

    wire pipe_inst2_req_csr_o;
    wire [31:0] pipe_inst2_csr_op1_o;
    wire [31:0] pipe_inst2_csr_addr_o;
    wire pipe_inst2_csr_csrrw_o;
    wire pipe_inst2_csr_csrrs_o;
    wire pipe_inst2_csr_csrrc_o;
    wire pipe_inst2_csr_we_o;
    wire [31:0] pipe_inst2_csr_waddr_o;
    wire [31:0] pipe_inst2_csr_raddr_o;

    wire pipe_inst1_req_bjp_o;
    wire [31:0] pipe_inst1_bjp_op1_o;
    wire [31:0] pipe_inst1_bjp_op2_o;
    wire [31:0] pipe_inst1_bjp_jump_op1_o;
    wire [31:0] pipe_inst1_bjp_jump_op2_o;
    wire pipe_inst1_bjp_op_jal_o;
    wire pipe_inst1_bjp_op_beq_o;
    wire pipe_inst1_bjp_op_bne_o;
    wire pipe_inst1_bjp_op_blt_o;
    wire pipe_inst1_bjp_op_bltu_o;
    wire pipe_inst1_bjp_op_bge_o;
    wire pipe_inst1_bjp_op_bgeu_o;
    wire pipe_inst1_bjp_op_jalr_o;

    wire pipe_inst2_req_bjp_o;
    wire [31:0] pipe_inst2_bjp_op1_o;
    wire [31:0] pipe_inst2_bjp_op2_o;
    wire [31:0] pipe_inst2_bjp_jump_op1_o;
    wire [31:0] pipe_inst2_bjp_jump_op2_o;
    wire pipe_inst2_bjp_op_jal_o;
    wire pipe_inst2_bjp_op_beq_o;
    wire pipe_inst2_bjp_op_bne_o;
    wire pipe_inst2_bjp_op_blt_o;
    wire pipe_inst2_bjp_op_bltu_o;
    wire pipe_inst2_bjp_op_bge_o;
    wire pipe_inst2_bjp_op_bgeu_o;
    wire pipe_inst2_bjp_op_jalr_o;

    // 第一路和第二路SYS内部信号
    wire pipe_inst1_sys_op_nop_o;
    wire pipe_inst1_sys_op_mret_o;
    wire pipe_inst1_sys_op_ecall_o;
    wire pipe_inst1_sys_op_ebreak_o;
    wire pipe_inst1_sys_op_fence_o;
    wire pipe_inst1_sys_op_dret_o;

    wire pipe_inst2_sys_op_nop_o;
    wire pipe_inst2_sys_op_mret_o;
    wire pipe_inst2_sys_op_ecall_o;
    wire pipe_inst2_sys_op_ebreak_o;
    wire pipe_inst2_sys_op_fence_o;
    wire pipe_inst2_sys_op_dret_o;

    // 第一路和第二路预测跳转信号
    wire pipe_inst1_is_pred_branch;
    wire pipe_inst2_is_pred_branch;

    // 第一路dispatch_logic输出信号
    wire inst1_logic_req_alu;
    wire [31:0] inst1_logic_alu_op1;
    wire [31:0] inst1_logic_alu_op2;
    wire [`ALU_OP_WIDTH-1:0] inst1_logic_alu_op_info;

    wire inst1_logic_req_bjp;
    wire [31:0] inst1_logic_bjp_op1;
    wire [31:0] inst1_logic_bjp_op2;
    wire [31:0] inst1_logic_bjp_jump_op1;
    wire [31:0] inst1_logic_bjp_jump_op2;
    wire inst1_logic_bjp_op_jal;
    wire inst1_logic_bjp_op_beq;
    wire inst1_logic_bjp_op_bne;
    wire inst1_logic_bjp_op_blt;
    wire inst1_logic_bjp_op_bltu;
    wire inst1_logic_bjp_op_bge;
    wire inst1_logic_bjp_op_bgeu;
    wire inst1_logic_bjp_op_jalr;

    wire inst1_logic_req_mul;
    wire [31:0] inst1_logic_mul_op1;
    wire [31:0] inst1_logic_mul_op2;
    wire inst1_logic_mul_op_mul;
    wire inst1_logic_mul_op_mulh;
    wire inst1_logic_mul_op_mulhsu;
    wire inst1_logic_mul_op_mulhu;

    wire inst1_logic_req_div;
    wire [31:0] inst1_logic_div_op1;
    wire [31:0] inst1_logic_div_op2;
    wire inst1_logic_div_op_div;
    wire inst1_logic_div_op_divu;
    wire inst1_logic_div_op_rem;
    wire inst1_logic_div_op_remu;

    wire inst1_logic_req_csr;
    wire [31:0] inst1_logic_csr_op1;
    wire [31:0] inst1_logic_csr_addr;
    wire inst1_logic_csr_csrrw;
    wire inst1_logic_csr_csrrs;
    wire inst1_logic_csr_csrrc;

    wire inst1_logic_sys_op_nop;
    wire inst1_logic_sys_op_mret;
    wire inst1_logic_sys_op_ecall;
    wire inst1_logic_sys_op_ebreak;
    wire inst1_logic_sys_op_fence;
    wire inst1_logic_sys_op_dret;

    // AGU已经接管地址/掩码/数据与未对齐标志

    // 第二路dispatch_logic输出信号
    wire inst2_logic_req_alu;
    wire [31:0] inst2_logic_alu_op1;
    wire [31:0] inst2_logic_alu_op2;
    wire [`ALU_OP_WIDTH-1:0] inst2_logic_alu_op_info;

    wire inst2_logic_req_bjp;
    wire [31:0] inst2_logic_bjp_op1;
    wire [31:0] inst2_logic_bjp_op2;
    wire [31:0] inst2_logic_bjp_jump_op1;
    wire [31:0] inst2_logic_bjp_jump_op2;
    wire inst2_logic_bjp_op_jal;
    wire inst2_logic_bjp_op_beq;
    wire inst2_logic_bjp_op_bne;
    wire inst2_logic_bjp_op_blt;
    wire inst2_logic_bjp_op_bltu;
    wire inst2_logic_bjp_op_bge;
    wire inst2_logic_bjp_op_bgeu;
    wire inst2_logic_bjp_op_jalr;

    wire inst2_logic_req_mul;
    wire [31:0] inst2_logic_mul_op1;
    wire [31:0] inst2_logic_mul_op2;
    wire inst2_logic_mul_op_mul;
    wire inst2_logic_mul_op_mulh;
    wire inst2_logic_mul_op_mulhsu;
    wire inst2_logic_mul_op_mulhu;

    wire inst2_logic_req_div;
    wire [31:0] inst2_logic_div_op1;
    wire [31:0] inst2_logic_div_op2;
    wire inst2_logic_div_op_div;
    wire inst2_logic_div_op_divu;
    wire inst2_logic_div_op_rem;
    wire inst2_logic_div_op_remu;

    wire inst2_logic_req_csr;
    wire [31:0] inst2_logic_csr_op1;
    wire [31:0] inst2_logic_csr_addr;
    wire inst2_logic_csr_csrrw;
    wire inst2_logic_csr_csrrs;
    wire inst2_logic_csr_csrrc;
    wire inst2_logic_sys_op_nop;
    wire inst2_logic_sys_op_mret;
    wire inst2_logic_sys_op_ecall;
    wire inst2_logic_sys_op_ebreak;
    wire inst2_logic_sys_op_fence;
    wire inst2_logic_sys_op_dret;

    wire flush_en1;
    wire flush_en2;
    wire stall_en1;
    wire stall_en2;
    wire inst1_branch_flush_en2;
    wire common_flush_en = stall_flag_dis_i[`CU_FLUSH] || stall_flag_dis_i[`CU_STALL_AGU] || clint_req_valid_i;
    wire mem_op1_valid, mem_op2_valid;
    wire any_exu_stall;

    assign flush_en1 = common_flush_en || (~hdu_issue_inst[0])  || stall_flag_dis_i[`CU_STALL_DISPATCH_2];
    assign flush_en2 = common_flush_en || (~hdu_issue_inst[1])  || stall_flag_dis_i[`CU_STALL_DISPATCH_1] || inst1_branch_flush_en2;
    assign stall_en1 = stall_flag_dis_i[`CU_STALL_DISPATCH_1];
    assign stall_en2 = stall_flag_dis_i[`CU_STALL_DISPATCH_2];
    assign mem_stall_req_o = agu_stall_req;
    // 还原出exu stall
    assign any_exu_stall = stall_flag_dis_i[`CU_STALL_DISPATCH_1] | stall_flag_dis_i[`CU_STALL_DISPATCH_2];
    assign mem_op1_valid = !(stall_flag_dis_i[`CU_FLUSH] | any_exu_stall | clint_req_valid_i);
    assign mem_op2_valid = !(stall_flag_dis_i[`CU_FLUSH] | any_exu_stall | clint_req_valid_i);

    // AGU已经接管地址/掩码/数据与未对齐标志
    // 实例化双发射AGU：计算两路地址/掩码/写数据与未对齐
    agu_dual u_agu_dual (
        .clk          (clk),
        .rst_n        (rst_n),
        .exu_lsu_stall(exu_lsu_stall_i),

        // 第一路输入
        .inst1_valid_i    (inst1_valid_i & hdu_issue_inst[0]),  //内部连到
        .valid_op1_i      (mem_op1_valid),
        .rs1_1_i          (inst1_rs1_rdata_i),
        .rs2_1_i          (inst1_rs2_rdata_i),
        .imm_1_i          (inst1_dec_imm_i),
        .dec_1_i          (inst1_dec_info_bus_i),
        .commit_id_1_i    (hdu_inst1_commit_id),
        .mem_reg_waddr_1_i(inst1_reg_waddr_i),

        // 第二路输入
        .inst2_valid_i    (inst2_valid_i & hdu_issue_inst[1]),  //内部连到
        .valid_op2_i      (mem_op2_valid),
        .rs1_2_i          (inst2_rs1_rdata_i),
        .rs2_2_i          (inst2_rs2_rdata_i),
        .imm_2_i          (inst2_dec_imm_i),
        .dec_2_i          (inst2_dec_info_bus_i),
        .commit_id_2_i    (hdu_inst2_commit_id),
        .mem_reg_waddr_2_i(inst2_reg_waddr_i),

        // 单路输出（64位总线编码）
        .addr_o         (agu_addr),
        .wmask_o        (agu_wmask),
        .wdata_o        (agu_wdata),
        .mem_req_o      (agu_req_mem),
        .commit_id_o    (agu_commit_id),
        .mem_reg_waddr_o(agu_mem_reg_waddr),

        // MEM操作类型导出
        .mem_op_lb_o       (agu_mem_lb),
        .mem_op_lh_o       (agu_mem_lh),
        .mem_op_lw_o       (agu_mem_lw),
        .mem_op_lbu_o      (agu_mem_lbu),
        .mem_op_lhu_o      (agu_mem_lhu),
        .mem_op_load_o     (agu_mem_load),
        .mem_op_store_o    (agu_mem_store),
        .misaligned_load_o (agu_mis_ld),
        .misaligned_store_o(agu_mis_st),

        // 控制类信号输出
        .agu_atom_lock(agu_atom_lock),
        .agu_stall_req(agu_stall_req)
    );

    // 实例化HDU模块
    hdu u_hdu (
        .clk  (clk),
        .rst_n(rst_n),

        // 指令1信息
        .inst1_valid      (hdu_inst1_valid),
        .inst1_rd_addr    (inst1_reg_waddr_i),
        .inst1_rs1_addr   (inst1_reg1_raddr_i),
        .inst1_rs2_addr   (inst1_reg2_raddr_i),
        .inst1_rd_we      (inst1_reg_we_i),
        .inst1_ex_info_bus(inst1_ex_info_bus_i),

        // 指令2信息
        .inst2_valid      (hdu_inst2_valid),
        .inst2_rd_addr    (inst2_reg_waddr_i),
        .inst2_rs1_addr   (inst2_reg1_raddr_i),
        .inst2_rs2_addr   (inst2_reg2_raddr_i),
        .inst2_rd_we      (inst2_reg_we_i),
        .inst2_ex_info_bus(inst2_ex_info_bus_i),

        // 指令完成信号（需要从后续模块连接）
        .commit_valid_i (inst1_commit_valid_i),
        .commit_id_i    (inst1_wb_commit_id_i),
        .commit_valid2_i(inst2_commit_valid_i),
        .commit_id2_i   (inst2_wb_commit_id_i),

        // 跳转控制信号（需要从其他模块连接）
        .inst1_jump_i   (inst1_jump_i),
        .clint_req_valid(clint_req_valid_i),
        .inst1_branch_i (inst1_branch_i),

        // 输出信号
        .issue_inst_o         (hdu_issue_inst),
        .inst1_commit_id_o    (hdu_inst1_commit_id),
        .inst2_commit_id_o    (hdu_inst2_commit_id),
        .alu1_pass_alu1_op1_o (hdu_alu1_pass_alu1_op1),
        .alu1_pass_alu1_op2_o (hdu_alu1_pass_alu1_op2),
        .alu1_pass_alu2_op1_o (hdu_alu1_pass_alu2_op1),
        .alu1_pass_alu2_op2_o (hdu_alu1_pass_alu2_op2),
        .mul1_pass_alu1_op1_o (hdu_mul1_pass_alu1_op1),
        .mul1_pass_alu1_op2_o (hdu_mul1_pass_alu1_op2),
        .mul1_pass_alu2_op1_o (hdu_mul1_pass_alu2_op1),
        .mul1_pass_alu2_op2_o (hdu_mul1_pass_alu2_op2),
        .div1_pass_alu1_op1_o (hdu_div1_pass_alu1_op1),
        .div1_pass_alu1_op2_o (hdu_div1_pass_alu1_op2),
        .div1_pass_alu2_op1_o (hdu_div1_pass_alu2_op1),
        .div1_pass_alu2_op2_o (hdu_div1_pass_alu2_op2),
        .alu2_pass_alu1_op1_o (hdu_alu2_pass_alu1_op1),
        .alu2_pass_alu1_op2_o (hdu_alu2_pass_alu1_op2),
        .alu2_pass_alu2_op1_o (hdu_alu2_pass_alu2_op1),
        .alu2_pass_alu2_op2_o (hdu_alu2_pass_alu2_op2),
        .mul2_pass_alu1_op1_o (hdu_mul2_pass_alu1_op1),
        .mul2_pass_alu1_op2_o (hdu_mul2_pass_alu1_op2),
        .mul2_pass_alu2_op1_o (hdu_mul2_pass_alu2_op1),
        .mul2_pass_alu2_op2_o (hdu_mul2_pass_alu2_op2),
        .div2_pass_alu1_op1_o (hdu_div2_pass_alu1_op1),
        .div2_pass_alu1_op2_o (hdu_div2_pass_alu1_op2),
        .div2_pass_alu2_op1_o (hdu_div2_pass_alu2_op1),
        .div2_pass_alu2_op2_o (hdu_div2_pass_alu2_op2),
        .long_inst_atom_lock_o(hdu_long_inst_atom_lock)
    );

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

        // MEM信号（操作类型由AGU提供，仅保留请求）

        // SYS信号
        .sys_op_nop_o   (inst1_logic_sys_op_nop),
        .sys_op_mret_o  (inst1_logic_sys_op_mret),
        .sys_op_ecall_o (inst1_logic_sys_op_ecall),
        .sys_op_ebreak_o(inst1_logic_sys_op_ebreak),
        .sys_op_fence_o (inst1_logic_sys_op_fence),
        .sys_op_dret_o  (inst1_logic_sys_op_dret)

        // 未对齐访存异常信号已由AGU提供
    );


    // 实例化dispatch_pipe模块 - 第一路
    dispatch_pipe u_inst1_dispatch_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_en    (stall_en1),
        .flush_en    (flush_en1),
        .inst_valid_i(inst1_valid_i),       // 仅当HDU发出指令1时才有效
        .inst_i      (inst1_i),
        .inst_addr_i (inst1_addr_i),
        .commit_id_i (hdu_inst1_commit_id),
        .mem_atom_lock(agu_atom_lock),

        .reg_we_i           (inst1_reg_we_i),
        .reg_waddr_i        (inst1_reg_waddr_i),
        .rs1_rdata_i        (inst1_rs1_rdata_i),
        .rs2_rdata_i        (inst1_rs2_rdata_i),
        .csr_we_i           (inst1_csr_we_i),
        .csr_waddr_i        (inst1_csr_waddr_i),
        .csr_raddr_i        (inst1_csr_raddr_i),
        .dec_imm_i          (inst1_dec_imm_i),
        .dec_info_bus_i     (inst1_dec_info_bus_i),
        .is_pred_branch_i   (inst1_is_pred_branch_i),
        .illegal_inst_i     (inst1_illegal_inst_i),
        // HDU信号输入
        .alu_pass_alu1_op1_i(hdu_alu1_pass_alu1_op1),
        .alu_pass_alu1_op2_i(hdu_alu1_pass_alu1_op2),
        .mul_pass_alu1_op1_i(hdu_mul1_pass_alu1_op1),
        .mul_pass_alu1_op2_i(hdu_mul1_pass_alu1_op2),
        .div_pass_alu1_op1_i(hdu_div1_pass_alu1_op1),
        .div_pass_alu1_op2_i(hdu_div1_pass_alu1_op2),
        .mul_pass_alu2_op1_i(hdu_mul1_pass_alu2_op1),
        .mul_pass_alu2_op2_i(hdu_mul1_pass_alu2_op2),
        .div_pass_alu2_op1_i(hdu_div1_pass_alu2_op1),
        .div_pass_alu2_op2_i(hdu_div1_pass_alu2_op2),
        .alu_pass_alu2_op1_i(hdu_alu1_pass_alu2_op1),
        .alu_pass_alu2_op2_i(hdu_alu1_pass_alu2_op2),

        // alu信号
        .req_alu_i      (inst1_logic_req_alu),
        .alu_op1_i      (inst1_logic_alu_op1),
        .alu_op2_i      (inst1_logic_alu_op2),
        .alu_op_info_i  (inst1_logic_alu_op_info),
        // BJP信号
        .req_bjp_i      (inst1_logic_req_bjp),
        .bjp_op1_i      (inst1_logic_bjp_op1),
        .bjp_op2_i      (inst1_logic_bjp_op2),
        .bjp_jump_op1_i (inst1_logic_bjp_jump_op1),
        .bjp_jump_op2_i (inst1_logic_bjp_jump_op2),
        .bjp_op_jal_i   (inst1_logic_bjp_op_jal),
        .bjp_op_beq_i   (inst1_logic_bjp_op_beq),
        .bjp_op_bne_i   (inst1_logic_bjp_op_bne),
        .bjp_op_blt_i   (inst1_logic_bjp_op_blt),
        .bjp_op_bltu_i  (inst1_logic_bjp_op_bltu),
        .bjp_op_bge_i   (inst1_logic_bjp_op_bge),
        .bjp_op_bgeu_i  (inst1_logic_bjp_op_bgeu),
        .bjp_op_jalr_i  (inst1_logic_bjp_op_jalr),
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
        .req_csr_i         (inst1_logic_req_csr),
        .csr_op1_i         (inst1_logic_csr_op1),
        .csr_addr_i        (inst1_logic_csr_addr),
        .csr_csrrw_i       (inst1_logic_csr_csrrw),
        .csr_csrrs_i       (inst1_logic_csr_csrrs),
        .csr_csrrc_i       (inst1_logic_csr_csrrc),
        // MEM信号
        .req_mem_i         (agu_req_mem),
        .mem_op_lb_i       (agu_mem_lb),
        .mem_op_lh_i       (agu_mem_lh),
        .mem_op_lw_i       (agu_mem_lw),
        .mem_op_lbu_i      (agu_mem_lbu),
        .mem_op_lhu_i      (agu_mem_lhu),
        .mem_op_load_i     (agu_mem_load),
        .mem_op_store_i    (agu_mem_store),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_i        (agu_addr),
        .mem_wmask_i       (agu_wmask),
        .mem_wdata_i       (agu_wdata),
        .mem_commit_id_i   (agu_commit_id),
        .mem_reg_waddr_i   (agu_mem_reg_waddr),
        // SYS信号
        .sys_op_nop_i      (inst1_logic_sys_op_nop),
        .sys_op_mret_i     (inst1_logic_sys_op_mret),
        .sys_op_ecall_i    (inst1_logic_sys_op_ecall),
        .sys_op_ebreak_i   (inst1_logic_sys_op_ebreak),
        .sys_op_fence_i    (inst1_logic_sys_op_fence),
        .sys_op_dret_i     (inst1_logic_sys_op_dret),
        // 新增：未对齐访存异常
        .misaligned_load_i (agu_mis_ld),
        .misaligned_store_i(agu_mis_st),

        //输出
        .inst_addr_o        (inst1_addr_o),
        .commit_id_o        (inst1_commit_id_o),
        .inst_valid_o       (inst1_valid_o),
        .inst_o             (inst1_o),
        .reg_we_o           (inst1_reg_we_o),
        .reg_waddr_o        (inst1_reg_waddr_o),
        .csr_we_o           (pipe_inst1_csr_we_o),
        .csr_waddr_o        (pipe_inst1_csr_waddr_o),
        .csr_raddr_o        (pipe_inst1_csr_raddr_o),
        .dec_imm_o          (inst1_dec_imm_o),
        .dec_info_bus_o     (inst1_dec_info_bus_o),
        .rs1_rdata_o        (inst1_rs1_rdata_o),
        .rs2_rdata_o        (inst1_rs2_rdata_o),
        .is_pred_branch_o   (pipe_inst1_is_pred_branch),
        .illegal_inst_o     (inst1_illegal_inst_o),
        // Alu输出端口
        .req_alu_o          (inst1_req_alu_o),
        .alu_op1_o          (inst1_alu_op1_o),
        .alu_op2_o          (inst1_alu_op2_o),
        .alu_op_info_o      (inst1_alu_op_info_o),
        // BJP输出端口
        .req_bjp_o          (pipe_inst1_req_bjp_o),
        .bjp_op1_o          (pipe_inst1_bjp_op1_o),
        .bjp_op2_o          (pipe_inst1_bjp_op2_o),
        .bjp_jump_op1_o     (pipe_inst1_bjp_jump_op1_o),
        .bjp_jump_op2_o     (pipe_inst1_bjp_jump_op2_o),
        .bjp_op_jal_o       (pipe_inst1_bjp_op_jal_o),
        .bjp_op_beq_o       (pipe_inst1_bjp_op_beq_o),
        .bjp_op_bne_o       (pipe_inst1_bjp_op_bne_o),
        .bjp_op_blt_o       (pipe_inst1_bjp_op_blt_o),
        .bjp_op_bltu_o      (pipe_inst1_bjp_op_bltu_o),
        .bjp_op_bge_o       (pipe_inst1_bjp_op_bge_o),
        .bjp_op_bgeu_o      (pipe_inst1_bjp_op_bgeu_o),
        .bjp_op_jalr_o      (pipe_inst1_bjp_op_jalr_o),
        // MUL信号输出
        .req_mul_o          (inst1_req_mul_o),
        .mul_op1_o          (inst1_mul_op1_o),
        .mul_op2_o          (inst1_mul_op2_o),
        .mul_op_mul_o       (inst1_mul_op_mul_o),
        .mul_op_mulh_o      (inst1_mul_op_mulh_o),
        .mul_op_mulhsu_o    (inst1_mul_op_mulhsu_o),
        .mul_op_mulhu_o     (inst1_mul_op_mulhu_o),
        // DIV信号输出
        .req_div_o          (inst1_req_div_o),
        .div_op1_o          (inst1_div_op1_o),
        .div_op2_o          (inst1_div_op2_o),
        .div_op_div_o       (inst1_div_op_div_o),
        .div_op_divu_o      (inst1_div_op_divu_o),
        .div_op_rem_o       (inst1_div_op_rem_o),
        .div_op_remu_o      (inst1_div_op_remu_o),
        // CSR输出端口
        .req_csr_o          (pipe_inst1_req_csr_o),
        .csr_op1_o          (pipe_inst1_csr_op1_o),
        .csr_addr_o         (pipe_inst1_csr_addr_o),
        .csr_csrrw_o        (pipe_inst1_csr_csrrw_o),
        .csr_csrrs_o        (pipe_inst1_csr_csrrs_o),
        .csr_csrrc_o        (pipe_inst1_csr_csrrc_o),
        // MEM输出端口
        .req_mem_o          (req_mem_o),
        .mem_op_lb_o        (mem_op_lb_o),
        .mem_op_lh_o        (mem_op_lh_o),
        .mem_op_lw_o        (mem_op_lw_o),
        .mem_op_lbu_o       (mem_op_lbu_o),
        .mem_op_lhu_o       (mem_op_lhu_o),
        .mem_op_load_o      (mem_op_load_o),
        .mem_op_store_o     (mem_op_store_o),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_o         (mem_addr_o),
        .mem_wmask_o        (mem_wmask_o),
        .mem_wdata_o        (mem_wdata_o),
        .mem_commit_id_o    (mem_commit_id_o),
        .mem_reg_waddr_o    (mem_reg_waddr_o),
        // 新增：未对齐访存异常输出
        .misaligned_load_o  (misaligned_load_o),
        .misaligned_store_o (misaligned_store_o),
        // SYS输出端口
        .sys_op_nop_o       (pipe_inst1_sys_op_nop_o),
        .sys_op_mret_o      (pipe_inst1_sys_op_mret_o),
        .sys_op_ecall_o     (pipe_inst1_sys_op_ecall_o),
        .sys_op_ebreak_o    (pipe_inst1_sys_op_ebreak_o),
        .sys_op_fence_o     (pipe_inst1_sys_op_fence_o),
        .sys_op_dret_o      (pipe_inst1_sys_op_dret_o),
        // HDU信号输出
        .alu_pass_alu1_op1_o(inst1_alu_pass_alu1_op1_o),
        .alu_pass_alu1_op2_o(inst1_alu_pass_alu1_op2_o),
        .alu_pass_alu2_op1_o(inst1_alu_pass_alu2_op1_o),
        .alu_pass_alu2_op2_o(inst1_alu_pass_alu2_op2_o),
        .mul_pass_alu1_op1_o(inst1_mul_pass_alu1_op1_o),
        .mul_pass_alu1_op2_o(inst1_mul_pass_alu1_op2_o),
        .mul_pass_alu2_op1_o(inst1_mul_pass_alu2_op1_o),
        .mul_pass_alu2_op2_o(inst1_mul_pass_alu2_op2_o),
        .div_pass_alu1_op1_o(inst1_div_pass_alu1_op1_o),
        .div_pass_alu1_op2_o(inst1_div_pass_alu1_op2_o),
        .div_pass_alu2_op1_o(inst1_div_pass_alu2_op1_o),
        .div_pass_alu2_op2_o(inst1_div_pass_alu2_op2_o)
    );

    // 实例化dispatch_logic模块 (第二路)
    dispatch_logic u_inst2_dispatch_logic (
        .dec_info_bus_i(inst2_dec_info_bus_i),
        .dec_imm_i     (inst2_dec_imm_i),
        .dec_pc_i      (inst2_addr_i),
        .rs1_rdata_i   (inst2_rs1_rdata_i),
        .rs2_rdata_i   (inst2_rs2_rdata_i),

        // Alu信号
        .req_alu_o      (inst2_logic_req_alu),
        .alu_op1_o      (inst2_logic_alu_op1),
        .alu_op2_o      (inst2_logic_alu_op2),
        .alu_op_info_o  (inst2_logic_alu_op_info),
        // BJP信号
        .req_bjp_o      (inst2_logic_req_bjp),
        .bjp_op1_o      (inst2_logic_bjp_op1),
        .bjp_op2_o      (inst2_logic_bjp_op2),
        .bjp_jump_op1_o (inst2_logic_bjp_jump_op1),
        .bjp_jump_op2_o (inst2_logic_bjp_jump_op2),
        .bjp_op_jal_o   (inst2_logic_bjp_op_jal),
        .bjp_op_beq_o   (inst2_logic_bjp_op_beq),
        .bjp_op_bne_o   (inst2_logic_bjp_op_bne),
        .bjp_op_blt_o   (inst2_logic_bjp_op_blt),
        .bjp_op_bltu_o  (inst2_logic_bjp_op_bltu),
        .bjp_op_bge_o   (inst2_logic_bjp_op_bge),
        .bjp_op_bgeu_o  (inst2_logic_bjp_op_bgeu),
        .bjp_op_jalr_o  (inst2_logic_bjp_op_jalr),
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
        .req_csr_o    (inst2_logic_req_csr),
        .csr_op1_o    (inst2_logic_csr_op1),
        .csr_addr_o   (inst2_logic_csr_addr),
        .csr_csrrw_o  (inst2_logic_csr_csrrw),
        .csr_csrrs_o  (inst2_logic_csr_csrrs),
        .csr_csrrc_o  (inst2_logic_csr_csrrc),


        // SYS信号
        .sys_op_nop_o   (inst2_logic_sys_op_nop),
        .sys_op_mret_o  (inst2_logic_sys_op_mret),
        .sys_op_ecall_o (inst2_logic_sys_op_ecall),
        .sys_op_ebreak_o(inst2_logic_sys_op_ebreak),
        .sys_op_fence_o (inst2_logic_sys_op_fence),
        .sys_op_dret_o  (inst2_logic_sys_op_dret)

        // 未对齐访存异常信号已由AGU提供
    );


    // 实例化dispatch_pipe模块 - 第二路
    dispatch_pipe u_inst2_dispatch_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_en    (stall_en2),
        .flush_en    (flush_en2),
        .inst_valid_i(inst2_valid_i),
        .inst_i      (inst2_i),
        .inst_addr_i (inst2_addr_i),
        .commit_id_i (hdu_inst2_commit_id),

        .reg_we_i           (inst2_reg_we_i),
        .reg_waddr_i        (inst2_reg_waddr_i),
        .rs1_rdata_i        (inst2_rs1_rdata_i),
        .rs2_rdata_i        (inst2_rs2_rdata_i),
        .csr_we_i           (inst2_csr_we_i),
        .csr_waddr_i        (inst2_csr_waddr_i),
        .csr_raddr_i        (inst2_csr_raddr_i),
        .dec_imm_i          (inst2_dec_imm_i),
        .dec_info_bus_i     (inst2_dec_info_bus_i),
        .is_pred_branch_i   (inst2_is_pred_branch_i),
        .illegal_inst_i     (inst2_illegal_inst_i),
        // HDU信号输入
        .alu_pass_alu1_op1_i(hdu_alu2_pass_alu1_op1),
        .alu_pass_alu1_op2_i(hdu_alu2_pass_alu1_op2),
        .mul_pass_alu1_op1_i(hdu_mul2_pass_alu1_op1),
        .mul_pass_alu1_op2_i(hdu_mul2_pass_alu1_op2),
        .div_pass_alu1_op1_i(hdu_div2_pass_alu1_op1),
        .div_pass_alu1_op2_i(hdu_div2_pass_alu1_op2),
        .mul_pass_alu2_op1_i(hdu_mul2_pass_alu2_op1),
        .mul_pass_alu2_op2_i(hdu_mul2_pass_alu2_op2),
        .div_pass_alu2_op1_i(hdu_div2_pass_alu2_op1),
        .div_pass_alu2_op2_i(hdu_div2_pass_alu2_op2),
        .alu_pass_alu2_op1_i(hdu_alu2_pass_alu2_op1),
        .alu_pass_alu2_op2_i(hdu_alu2_pass_alu2_op2),
        // alu信号
        .req_alu_i          (inst2_logic_req_alu),
        .alu_op1_i          (inst2_logic_alu_op1),
        .alu_op2_i          (inst2_logic_alu_op2),
        .alu_op_info_i      (inst2_logic_alu_op_info),
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
        .req_mul_i          (inst2_logic_req_mul),
        .mul_op1_i          (inst2_logic_mul_op1),
        .mul_op2_i          (inst2_logic_mul_op2),
        .mul_op_mul_i       (inst2_logic_mul_op_mul),
        .mul_op_mulh_i      (inst2_logic_mul_op_mulh),
        .mul_op_mulhsu_i    (inst2_logic_mul_op_mulhsu),
        .mul_op_mulhu_i     (inst2_logic_mul_op_mulhu),

        // DIV信号输入
        .req_div_i         (inst2_logic_req_div),
        .div_op1_i         (inst2_logic_div_op1),
        .div_op2_i         (inst2_logic_div_op2),
        .div_op_div_i      (inst2_logic_div_op_div),
        .div_op_divu_i     (inst2_logic_div_op_divu),
        .div_op_rem_i      (inst2_logic_div_op_rem),
        .div_op_remu_i     (inst2_logic_div_op_remu),
        // CSR信号
        .req_csr_i         (inst2_logic_req_csr),
        .csr_op1_i         (inst2_logic_csr_op1),
        .csr_addr_i        (inst2_logic_csr_addr),
        .csr_csrrw_i       (inst2_logic_csr_csrrw),
        .csr_csrrs_i       (inst2_logic_csr_csrrs),
        .csr_csrrc_i       (inst2_logic_csr_csrrc),
        // MEM信号
        .req_mem_i         (1'b0),
        .mem_op_lb_i       (1'b0),                       // 第二路不使用AGU，保持为0
        .mem_op_lh_i       (1'b0),
        .mem_op_lw_i       (1'b0),
        .mem_op_lbu_i      (1'b0),
        .mem_op_lhu_i      (1'b0),
        .mem_op_load_i     (1'b0),
        .mem_op_store_i    (1'b0),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_i        (32'b0),
        .mem_wmask_i       (8'b0),
        .mem_wdata_i       (64'b0),
        .mem_commit_id_i   (3'b0),
        .mem_reg_waddr_i   (5'b0),
        // SYS信号
        .sys_op_nop_i      (inst2_logic_sys_op_nop),
        .sys_op_mret_i     (inst2_logic_sys_op_mret),
        .sys_op_ecall_i    (inst2_logic_sys_op_ecall),
        .sys_op_ebreak_i   (inst2_logic_sys_op_ebreak),
        .sys_op_fence_i    (inst2_logic_sys_op_fence),
        .sys_op_dret_i     (inst2_logic_sys_op_dret),
        // 新增：未对齐访存异常
        .misaligned_load_i (1'b0),                       // 第二路不使用AGU，保持为0
        .misaligned_store_i(1'b0),

        //输出
        .inst_addr_o        (inst2_addr_o),
        .commit_id_o        (inst2_commit_id_o),
        .inst_valid_o       (inst2_valid_o),
        .inst_o             (inst2_o),
        .reg_we_o           (inst2_reg_we_o),
        .reg_waddr_o        (inst2_reg_waddr_o),
        .csr_we_o           (pipe_inst2_csr_we_o),
        .csr_waddr_o        (pipe_inst2_csr_waddr_o),
        .csr_raddr_o        (pipe_inst2_csr_raddr_o),
        .dec_imm_o          (inst2_dec_imm_o),
        .dec_info_bus_o     (inst2_dec_info_bus_o),
        .rs1_rdata_o        (inst2_rs1_rdata_o),
        .rs2_rdata_o        (inst2_rs2_rdata_o),
        .is_pred_branch_o   (pipe_inst2_is_pred_branch),
        .illegal_inst_o     (inst2_illegal_inst_o),
        // Alu输出端口
        .req_alu_o          (inst2_req_alu_o),
        .alu_op1_o          (inst2_alu_op1_o),
        .alu_op2_o          (inst2_alu_op2_o),
        .alu_op_info_o      (inst2_alu_op_info_o),
        // BJP输出端口
        .req_bjp_o          (pipe_inst2_req_bjp_o),
        .bjp_op1_o          (pipe_inst2_bjp_op1_o),
        .bjp_op2_o          (pipe_inst2_bjp_op2_o),
        .bjp_jump_op1_o     (pipe_inst2_bjp_jump_op1_o),
        .bjp_jump_op2_o     (pipe_inst2_bjp_jump_op2_o),
        .bjp_op_jal_o       (pipe_inst2_bjp_op_jal_o),
        .bjp_op_beq_o       (pipe_inst2_bjp_op_beq_o),
        .bjp_op_bne_o       (pipe_inst2_bjp_op_bne_o),
        .bjp_op_blt_o       (pipe_inst2_bjp_op_blt_o),
        .bjp_op_bltu_o      (pipe_inst2_bjp_op_bltu_o),
        .bjp_op_bge_o       (pipe_inst2_bjp_op_bge_o),
        .bjp_op_bgeu_o      (pipe_inst2_bjp_op_bgeu_o),
        .bjp_op_jalr_o      (pipe_inst2_bjp_op_jalr_o),
        // MUL信号输出
        .req_mul_o          (inst2_req_mul_o),
        .mul_op1_o          (inst2_mul_op1_o),
        .mul_op2_o          (inst2_mul_op2_o),
        .mul_op_mul_o       (inst2_mul_op_mul_o),
        .mul_op_mulh_o      (inst2_mul_op_mulh_o),
        .mul_op_mulhsu_o    (inst2_mul_op_mulhsu_o),
        .mul_op_mulhu_o     (inst2_mul_op_mulhu_o),
        // DIV信号输出
        .req_div_o          (inst2_req_div_o),
        .div_op1_o          (inst2_div_op1_o),
        .div_op2_o          (inst2_div_op2_o),
        .div_op_div_o       (inst2_div_op_div_o),
        .div_op_divu_o      (inst2_div_op_divu_o),
        .div_op_rem_o       (inst2_div_op_rem_o),
        .div_op_remu_o      (inst2_div_op_remu_o),
        // CSR输出端口
        .req_csr_o          (pipe_inst2_req_csr_o),
        .csr_op1_o          (pipe_inst2_csr_op1_o),
        .csr_addr_o         (pipe_inst2_csr_addr_o),
        .csr_csrrw_o        (pipe_inst2_csr_csrrw_o),
        .csr_csrrs_o        (pipe_inst2_csr_csrrs_o),
        .csr_csrrc_o        (pipe_inst2_csr_csrrc_o),
        // MEM输出端口 - 第二路不输出MEM信号
        .req_mem_o          (),
        .mem_op_lb_o        (),
        .mem_op_lh_o        (),
        .mem_op_lw_o        (),
        .mem_op_lbu_o       (),
        .mem_op_lhu_o       (),
        .mem_op_load_o      (),
        .mem_op_store_o     (),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_o         (),
        .mem_wmask_o        (),
        .mem_wdata_o        (),
        .mem_commit_id_o    (),
        .mem_reg_waddr_o    (),
        // 新增：未对齐访存异常输出
        .misaligned_load_o  (),
        .misaligned_store_o (),
        // SYS输出端口
        .sys_op_nop_o       (pipe_inst2_sys_op_nop_o),
        .sys_op_mret_o      (pipe_inst2_sys_op_mret_o),
        .sys_op_ecall_o     (pipe_inst2_sys_op_ecall_o),
        .sys_op_ebreak_o    (pipe_inst2_sys_op_ebreak_o),
        .sys_op_fence_o     (pipe_inst2_sys_op_fence_o),
        .sys_op_dret_o      (pipe_inst2_sys_op_dret_o),
        // HDU信号输出
        .alu_pass_alu1_op1_o(inst2_alu_pass_alu1_op1_o),
        .alu_pass_alu1_op2_o(inst2_alu_pass_alu1_op2_o),
        .alu_pass_alu2_op1_o(inst2_alu_pass_alu2_op1_o),
        .alu_pass_alu2_op2_o(inst2_alu_pass_alu2_op2_o),
        .mul_pass_alu1_op1_o(inst2_mul_pass_alu1_op1_o),
        .mul_pass_alu1_op2_o(inst2_mul_pass_alu1_op2_o),
        .mul_pass_alu2_op1_o(inst2_mul_pass_alu2_op1_o),
        .mul_pass_alu2_op2_o(inst2_mul_pass_alu2_op2_o),
        .div_pass_alu1_op1_o(inst2_div_pass_alu1_op1_o),
        .div_pass_alu1_op2_o(inst2_div_pass_alu1_op2_o),
        .div_pass_alu2_op1_o(inst2_div_pass_alu2_op1_o),
        .div_pass_alu2_op2_o(inst2_div_pass_alu2_op2_o)
    );
    assign dispatch_atom_lock_o = agu_atom_lock | hdu_long_inst_atom_lock;
    assign issue_inst_o = hdu_issue_inst;
    // CSR输出端口直接连接
    assign inst1_req_csr_o = pipe_inst1_req_csr_o;
    assign inst1_csr_op1_o = pipe_inst1_csr_op1_o;
    assign inst1_csr_addr_o = pipe_inst1_csr_addr_o;
    assign inst1_csr_csrrw_o = pipe_inst1_csr_csrrw_o;
    assign inst1_csr_csrrs_o = pipe_inst1_csr_csrrs_o;
    assign inst1_csr_csrrc_o = pipe_inst1_csr_csrrc_o;
    assign inst1_csr_we_o = pipe_inst1_csr_we_o;
    assign inst1_csr_waddr_o = pipe_inst1_csr_waddr_o;
    assign inst1_csr_raddr_o = pipe_inst1_csr_raddr_o;
    assign inst1_csr_reg_we_o = pipe_inst1_req_csr_o ? inst1_reg_we_o : 1'b0;
    assign inst1_csr_reg_waddr_o = pipe_inst1_req_csr_o ? inst1_reg_waddr_o : 5'b0;
    assign inst1_csr_commit_id_o = pipe_inst1_req_csr_o ? inst1_commit_id_o : 3'b0;

    assign inst2_req_csr_o = pipe_inst2_req_csr_o;
    assign inst2_csr_op1_o = pipe_inst2_csr_op1_o;
    assign inst2_csr_addr_o = pipe_inst2_csr_addr_o;
    assign inst2_csr_csrrw_o = pipe_inst2_csr_csrrw_o;
    assign inst2_csr_csrrs_o = pipe_inst2_csr_csrrs_o;
    assign inst2_csr_csrrc_o = pipe_inst2_csr_csrrc_o;
    assign inst2_csr_we_o = pipe_inst2_csr_we_o;
    assign inst2_csr_waddr_o = pipe_inst2_csr_waddr_o;
    assign inst2_csr_raddr_o = pipe_inst2_csr_raddr_o;
    assign inst2_csr_reg_we_o = pipe_inst2_req_csr_o ? inst2_reg_we_o : 1'b0;
    assign inst2_csr_reg_waddr_o = pipe_inst2_req_csr_o ? inst2_reg_waddr_o : 5'b0;
    assign inst2_csr_commit_id_o = pipe_inst2_req_csr_o ? inst2_commit_id_o : 3'b0;


    // BJP合并逻辑
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

    assign inst_is_pred_branch_o = pipe_inst1_req_bjp_o ? pipe_inst1_is_pred_branch : pipe_inst2_req_bjp_o ? pipe_inst2_is_pred_branch : 0;
    assign inst1_branch_flush_en2 = pred_taken_i;

    //sys合并逻辑
    //sys只留一路即可
    assign sys_op_nop_o = pipe_inst1_sys_op_nop_o | pipe_inst2_sys_op_nop_o;
    assign sys_op_mret_o = pipe_inst1_sys_op_mret_o | pipe_inst2_sys_op_mret_o;
    assign sys_op_ecall_o = pipe_inst1_sys_op_ecall_o | pipe_inst2_sys_op_ecall_o;
    assign sys_op_ebreak_o = pipe_inst1_sys_op_ebreak_o | pipe_inst2_sys_op_ebreak_o;
    assign sys_op_fence_o = pipe_inst1_sys_op_fence_o | pipe_inst2_sys_op_fence_o;
    assign sys_op_dret_o = pipe_inst1_sys_op_dret_o | pipe_inst2_sys_op_dret_o;

    assign inst1_mul_commit_id_o = inst1_commit_id_o;
    assign inst2_mul_commit_id_o = inst2_commit_id_o;
    assign inst1_div_commit_id_o = inst1_commit_id_o;
    assign inst2_div_commit_id_o = inst2_commit_id_o;

endmodule
