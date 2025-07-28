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

// 将dispatch分发结果向执行模块传递的流水线寄存器
module dispatch_pipe (
    input wire                     clk,
    input wire                     rst_n,
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i, // 流水线暂停标志

    // 新增：指令有效信号输入
    input wire                        inst_valid_i,
    input wire [`INST_DATA_WIDTH-1:0] inst_i,        // 指令内容

    // 指令信息输入端口
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 新增：额外的信号直接从IDU传递
    input wire                       reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire                       csr_we_i,
    input wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_i,
    input wire [               31:0] dec_imm_i,
    input wire [ `DECINFO_WIDTH-1:0] dec_info_bus_i,
    // 新增：寄存rs1/rs2数据
    input wire [               31:0] rs1_rdata_i,
    input wire [               31:0] rs2_rdata_i,
    input wire                       is_pred_branch_i,  // 新增：预测分支信号输入
    // 新增：非法指令信号输入
    input wire                       illegal_inst_i,

    // ALU输入端口
    input wire                     req_alu_i,
    input wire [             31:0] alu_op1_i,
    input wire [             31:0] alu_op2_i,
    input wire [`ALU_OP_WIDTH-1:0] alu_op_info_i,

    // BJP输入端口
    input wire        req_bjp_i,
    input wire [31:0] bjp_op1_i,
    input wire [31:0] bjp_op2_i,
    input wire [31:0] bjp_jump_op1_i,
    input wire [31:0] bjp_jump_op2_i,
    input wire        bjp_op_jal_i,
    input wire        bjp_op_beq_i,
    input wire        bjp_op_bne_i,
    input wire        bjp_op_blt_i,
    input wire        bjp_op_bltu_i,
    input wire        bjp_op_bge_i,
    input wire        bjp_op_bgeu_i,
    input wire        bjp_op_jalr_i,

    // MULDIV输入端口
    input wire        req_muldiv_i,
    input wire [31:0] muldiv_op1_i,
    input wire [31:0] muldiv_op2_i,
    input wire        muldiv_op_mul_i,
    input wire        muldiv_op_mulh_i,
    input wire        muldiv_op_mulhsu_i,
    input wire        muldiv_op_mulhu_i,
    input wire        muldiv_op_div_i,
    input wire        muldiv_op_divu_i,
    input wire        muldiv_op_rem_i,
    input wire        muldiv_op_remu_i,
    input wire        muldiv_op_mul_all_i,
    input wire        muldiv_op_div_all_i,

    // CSR输入端口
    input wire        req_csr_i,
    input wire [31:0] csr_op1_i,
    input wire [31:0] csr_addr_i,
    input wire        csr_csrrw_i,
    input wire        csr_csrrs_i,
    input wire        csr_csrrc_i,

    // MEM输入端口
    input wire req_mem_i,
    // 删除不再需要的输入信号
    input wire mem_op_lb_i,
    input wire mem_op_lh_i,
    input wire mem_op_lw_i,
    input wire mem_op_lbu_i,
    input wire mem_op_lhu_i,
    input wire mem_op_load_i,
    input wire mem_op_store_i,

    // 直接计算的内存地址和掩码/数据输入
    input wire [31:0] mem_addr_i,
    input wire [ 3:0] mem_wmask_i,
    input wire [31:0] mem_wdata_i,

    // 新增：未对齐访存异常输入
    input wire misaligned_load_i,
    input wire misaligned_store_i,

    // SYS输入端口
    input wire sys_op_nop_i,
    input wire sys_op_mret_i,
    input wire sys_op_ecall_i,
    input wire sys_op_ebreak_i,
    input wire sys_op_fence_i,
    input wire sys_op_dret_i,

    // 指令信息输出端口
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,
    // 新增：指令有效信号输出
    output wire                        inst_valid_o,
    output wire [`INST_DATA_WIDTH-1:0] inst_o,        // 指令内容

    // 新增：额外的信号输出到其他模块
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,
    output wire [               31:0] dec_imm_o,
    output wire [ `DECINFO_WIDTH-1:0] dec_info_bus_o,
    // 新增：寄存rs1/rs2数据
    output wire [               31:0] rs1_rdata_o,
    output wire [               31:0] rs2_rdata_o,

    // ALU输出端口
    output wire                     req_alu_o,
    output wire [             31:0] alu_op1_o,
    output wire [             31:0] alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] alu_op_info_o,

    // BJP输出端口
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

    // MULDIV输出端口
    output wire        req_muldiv_o,
    output wire [31:0] muldiv_op1_o,
    output wire [31:0] muldiv_op2_o,
    output wire        muldiv_op_mul_o,
    output wire        muldiv_op_mulh_o,
    output wire        muldiv_op_mulhsu_o,
    output wire        muldiv_op_mulhu_o,
    output wire        muldiv_op_div_o,
    output wire        muldiv_op_divu_o,
    output wire        muldiv_op_rem_o,
    output wire        muldiv_op_remu_o,
    output wire        muldiv_op_mul_all_o,
    output wire        muldiv_op_div_all_o,

    // CSR输出端口
    output wire        req_csr_o,
    output wire [31:0] csr_op1_o,
    output wire [31:0] csr_addr_o,
    output wire        csr_csrrw_o,
    output wire        csr_csrrs_o,
    output wire        csr_csrrc_o,

    // MEM输出端口
    output wire req_mem_o,
    output wire mem_op_lb_o,
    output wire mem_op_lh_o,
    output wire mem_op_lw_o,
    output wire mem_op_lbu_o,
    output wire mem_op_lhu_o,
    output wire mem_op_load_o,
    output wire mem_op_store_o,

    // 保留这些计算好的内存地址和掩码/数据输出
    output wire [31:0] mem_addr_o,
    output wire [ 3:0] mem_wmask_o,
    output wire [31:0] mem_wdata_o,

    // 新增：未对齐访存异常输出
    output wire misaligned_load_o,
    output wire misaligned_store_o,

    // SYS输出端口
    output wire sys_op_nop_o,
    output wire sys_op_mret_o,
    output wire sys_op_ecall_o,
    output wire sys_op_ebreak_o,
    output wire sys_op_fence_o,
    output wire sys_op_dret_o,
    output wire is_pred_branch_o,  // 新增：预测分支信号输出
    // 新增：非法指令信号输出
    output wire illegal_inst_o
);

    wire                        flush_en = |stall_flag_i;
    wire                        stall_en = stall_flag_i[`CU_STALL_DISPATCH];
    wire                        inst_info_stall_en = stall_flag_i[`CU_STALL];
    wire                        reg_update_en = ~stall_en;

    // 指令地址寄存器
    wire [`INST_ADDR_WIDTH-1:0] inst_addr_dnxt = flush_en ? `ZeroWord : inst_addr_i;
    wire [`INST_ADDR_WIDTH-1:0] inst_addr;
    gnrl_dfflr #(32) inst_addr_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        inst_addr_dnxt,
        inst_addr
    );
    assign inst_addr_o = inst_addr;

    // 指令ID寄存器
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_dnxt = commit_id_i;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id;
    gnrl_dfflr #(`COMMIT_ID_WIDTH) commit_id_ff (
        clk,
        rst_n,
        reg_update_en,
        commit_id_dnxt,
        commit_id
    );
    assign commit_id_o = commit_id;

    // 新增：寄存器写使能寄存器
    wire reg_we_dnxt = flush_en ? 1'b0 : reg_we_i;
    wire reg_we;
    gnrl_dfflr #(1) reg_we_ff (
        clk,
        rst_n,
        reg_update_en,
        reg_we_dnxt,
        reg_we
    );
    assign reg_we_o = reg_we;

    // 新增：寄存器写地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_dnxt = flush_en ? {`REG_ADDR_WIDTH{1'b0}} : reg_waddr_i;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) reg_waddr_ff (
        clk,
        rst_n,
        reg_update_en,
        reg_waddr_dnxt,
        reg_waddr
    );
    assign reg_waddr_o = reg_waddr;

    // 新增：CSR写使能寄存器
    wire csr_we_dnxt = flush_en ? 1'b0 : csr_we_i;
    wire csr_we;
    gnrl_dfflr #(1) csr_we_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_we_dnxt,
        csr_we
    );
    assign csr_we_o = csr_we;

    // 新增：CSR写地址寄存器
    wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_dnxt = flush_en ? {`BUS_ADDR_WIDTH{1'b0}} : csr_waddr_i;
    wire [`BUS_ADDR_WIDTH-1:0] csr_waddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) csr_waddr_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_waddr_dnxt,
        csr_waddr
    );
    assign csr_waddr_o = csr_waddr;

    // 新增：CSR读地址寄存器
    wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_dnxt = flush_en ? {`BUS_ADDR_WIDTH{1'b0}} : csr_raddr_i;
    wire [`BUS_ADDR_WIDTH-1:0] csr_raddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) csr_raddr_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_raddr_dnxt,
        csr_raddr
    );
    assign csr_raddr_o = csr_raddr;

    // 新增：立即数寄存器
    wire [31:0] dec_imm_dnxt = flush_en ? 32'b0 : dec_imm_i;
    wire [31:0] dec_imm;
    gnrl_dfflr #(32) dec_imm_ff (
        clk,
        rst_n,
        reg_update_en,
        dec_imm_dnxt,
        dec_imm
    );
    assign dec_imm_o = dec_imm;

    // 新增：译码信息总线寄存器
    wire [`DECINFO_WIDTH-1:0] dec_info_bus_dnxt = flush_en ? {`DECINFO_WIDTH{1'b0}} : dec_info_bus_i;
    wire [`DECINFO_WIDTH-1:0] dec_info_bus;
    gnrl_dfflr #(`DECINFO_WIDTH) dec_info_bus_ff (
        clk,
        rst_n,
        reg_update_en,
        dec_info_bus_dnxt,
        dec_info_bus
    );
    assign dec_info_bus_o = dec_info_bus;

    // ALU信号寄存
    wire req_alu_dnxt = flush_en ? 1'b0 : req_alu_i;
    wire req_alu;
    gnrl_dfflr #(1) req_alu_ff (
        clk,
        rst_n,
        reg_update_en,
        req_alu_dnxt,
        req_alu
    );
    assign req_alu_o = req_alu;

    wire [31:0] alu_op1_dnxt = flush_en ? `ZeroWord : alu_op1_i;
    wire [31:0] alu_op1;
    gnrl_dfflr #(32) alu_op1_ff (
        clk,
        rst_n,
        reg_update_en,
        alu_op1_dnxt,
        alu_op1
    );
    assign alu_op1_o = alu_op1;

    wire [31:0] alu_op2_dnxt = flush_en ? `ZeroWord : alu_op2_i;
    wire [31:0] alu_op2;
    gnrl_dfflr #(32) alu_op2_ff (
        clk,
        rst_n,
        reg_update_en,
        alu_op2_dnxt,
        alu_op2
    );
    assign alu_op2_o = alu_op2;

    wire [`ALU_OP_WIDTH-1:0] alu_op_info_dnxt = flush_en ? {`ALU_OP_WIDTH{1'b0}} : alu_op_info_i;
    wire [`ALU_OP_WIDTH-1:0] alu_op_info;
    gnrl_dfflr #(`ALU_OP_WIDTH) alu_op_info_ff (
        clk,
        rst_n,
        reg_update_en,
        alu_op_info_dnxt,
        alu_op_info
    );
    assign alu_op_info_o = alu_op_info;

    // BJP信号寄存
    wire req_bjp_dnxt = flush_en ? 1'b0 : req_bjp_i;
    wire req_bjp;
    gnrl_dfflr #(1) req_bjp_ff (
        clk,
        rst_n,
        reg_update_en,
        req_bjp_dnxt,
        req_bjp
    );
    assign req_bjp_o = req_bjp;

    wire [31:0] bjp_op1_dnxt = flush_en ? `ZeroWord : bjp_op1_i;
    wire [31:0] bjp_op1;
    gnrl_dfflr #(32) bjp_op1_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op1_dnxt,
        bjp_op1
    );
    assign bjp_op1_o = bjp_op1;

    wire [31:0] bjp_op2_dnxt = flush_en ? `ZeroWord : bjp_op2_i;
    wire [31:0] bjp_op2;
    gnrl_dfflr #(32) bjp_op2_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op2_dnxt,
        bjp_op2
    );
    assign bjp_op2_o = bjp_op2;

    wire [31:0] bjp_jump_op1_dnxt = flush_en ? `ZeroWord : bjp_jump_op1_i;
    wire [31:0] bjp_jump_op1;
    gnrl_dfflr #(32) bjp_jump_op1_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_jump_op1_dnxt,
        bjp_jump_op1
    );
    assign bjp_jump_op1_o = bjp_jump_op1;

    wire [31:0] bjp_jump_op2_dnxt = flush_en ? `ZeroWord : bjp_jump_op2_i;
    wire [31:0] bjp_jump_op2;
    gnrl_dfflr #(32) bjp_jump_op2_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_jump_op2_dnxt,
        bjp_jump_op2
    );
    assign bjp_jump_op2_o = bjp_jump_op2;

    wire bjp_op_jal_dnxt = flush_en ? 1'b0 : bjp_op_jal_i;
    wire bjp_op_jal;
    gnrl_dfflr #(1) bjp_op_jal_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        bjp_op_jal_dnxt,
        bjp_op_jal
    );
    assign bjp_op_jal_o = bjp_op_jal;

    wire bjp_op_beq_dnxt = flush_en ? 1'b0 : bjp_op_beq_i;
    wire bjp_op_beq;
    gnrl_dfflr #(1) bjp_op_beq_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_beq_dnxt,
        bjp_op_beq
    );
    assign bjp_op_beq_o = bjp_op_beq;

    wire bjp_op_bne_dnxt = flush_en ? 1'b0 : bjp_op_bne_i;
    wire bjp_op_bne;
    gnrl_dfflr #(1) bjp_op_bne_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_bne_dnxt,
        bjp_op_bne
    );
    assign bjp_op_bne_o = bjp_op_bne;

    wire bjp_op_blt_dnxt = flush_en ? 1'b0 : bjp_op_blt_i;
    wire bjp_op_blt;
    gnrl_dfflr #(1) bjp_op_blt_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_blt_dnxt,
        bjp_op_blt
    );
    assign bjp_op_blt_o = bjp_op_blt;

    wire bjp_op_bltu_dnxt = flush_en ? 1'b0 : bjp_op_bltu_i;
    wire bjp_op_bltu;
    gnrl_dfflr #(1) bjp_op_bltu_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_bltu_dnxt,
        bjp_op_bltu
    );
    assign bjp_op_bltu_o = bjp_op_bltu;

    wire bjp_op_bge_dnxt = flush_en ? 1'b0 : bjp_op_bge_i;
    wire bjp_op_bge;
    gnrl_dfflr #(1) bjp_op_bge_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_bge_dnxt,
        bjp_op_bge
    );
    assign bjp_op_bge_o = bjp_op_bge;

    wire bjp_op_bgeu_dnxt = flush_en ? 1'b0 : bjp_op_bgeu_i;
    wire bjp_op_bgeu;
    gnrl_dfflr #(1) bjp_op_bgeu_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_bgeu_dnxt,
        bjp_op_bgeu
    );
    assign bjp_op_bgeu_o = bjp_op_bgeu;

    wire bjp_op_jalr_dnxt = flush_en ? 1'b0 : bjp_op_jalr_i;
    wire bjp_op_jalr;
    gnrl_dfflr #(1) bjp_op_jalr_ff (
        clk,
        rst_n,
        reg_update_en,
        bjp_op_jalr_dnxt,
        bjp_op_jalr
    );
    assign bjp_op_jalr_o = bjp_op_jalr;

    // MULDIV信号寄存
    wire req_muldiv_dnxt = flush_en ? 1'b0 : req_muldiv_i;
    wire req_muldiv;
    gnrl_dfflr #(1) req_muldiv_ff (
        clk,
        rst_n,
        reg_update_en,
        req_muldiv_dnxt,
        req_muldiv
    );
    assign req_muldiv_o = req_muldiv;

    wire [31:0] muldiv_op1_dnxt = flush_en ? `ZeroWord : muldiv_op1_i;
    wire [31:0] muldiv_op1;
    gnrl_dfflr #(32) muldiv_op1_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op1_dnxt,
        muldiv_op1
    );
    assign muldiv_op1_o = muldiv_op1;

    wire [31:0] muldiv_op2_dnxt = flush_en ? `ZeroWord : muldiv_op2_i;
    wire [31:0] muldiv_op2;
    gnrl_dfflr #(32) muldiv_op2_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op2_dnxt,
        muldiv_op2
    );
    assign muldiv_op2_o = muldiv_op2;

    wire muldiv_op_mul_dnxt = flush_en ? 1'b0 : muldiv_op_mul_i;
    wire muldiv_op_mul;
    gnrl_dfflr #(1) muldiv_op_mul_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_mul_dnxt,
        muldiv_op_mul
    );
    assign muldiv_op_mul_o = muldiv_op_mul;

    wire muldiv_op_mulh_dnxt = flush_en ? 1'b0 : muldiv_op_mulh_i;
    wire muldiv_op_mulh;
    gnrl_dfflr #(1) muldiv_op_mulh_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_mulh_dnxt,
        muldiv_op_mulh
    );
    assign muldiv_op_mulh_o = muldiv_op_mulh;

    wire muldiv_op_mulhsu_dnxt = flush_en ? 1'b0 : muldiv_op_mulhsu_i;
    wire muldiv_op_mulhsu;
    gnrl_dfflr #(1) muldiv_op_mulhsu_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_mulhsu_dnxt,
        muldiv_op_mulhsu
    );
    assign muldiv_op_mulhsu_o = muldiv_op_mulhsu;

    wire muldiv_op_mulhu_dnxt = flush_en ? 1'b0 : muldiv_op_mulhu_i;
    wire muldiv_op_mulhu;
    gnrl_dfflr #(1) muldiv_op_mulhu_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_mulhu_dnxt,
        muldiv_op_mulhu
    );
    assign muldiv_op_mulhu_o = muldiv_op_mulhu;

    wire muldiv_op_div_dnxt = flush_en ? 1'b0 : muldiv_op_div_i;
    wire muldiv_op_div;
    gnrl_dfflr #(1) muldiv_op_div_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_div_dnxt,
        muldiv_op_div
    );
    assign muldiv_op_div_o = muldiv_op_div;

    wire muldiv_op_divu_dnxt = flush_en ? 1'b0 : muldiv_op_divu_i;
    wire muldiv_op_divu;
    gnrl_dfflr #(1) muldiv_op_divu_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_divu_dnxt,
        muldiv_op_divu
    );
    assign muldiv_op_divu_o = muldiv_op_divu;

    wire muldiv_op_rem_dnxt = flush_en ? 1'b0 : muldiv_op_rem_i;
    wire muldiv_op_rem;
    gnrl_dfflr #(1) muldiv_op_rem_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_rem_dnxt,
        muldiv_op_rem
    );
    assign muldiv_op_rem_o = muldiv_op_rem;

    wire muldiv_op_remu_dnxt = flush_en ? 1'b0 : muldiv_op_remu_i;
    wire muldiv_op_remu;
    gnrl_dfflr #(1) muldiv_op_remu_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_remu_dnxt,
        muldiv_op_remu
    );
    assign muldiv_op_remu_o = muldiv_op_remu;

    wire muldiv_op_mul_all_dnxt = flush_en ? 1'b0 : muldiv_op_mul_all_i;
    wire muldiv_op_mul_all;
    gnrl_dfflr #(1) muldiv_op_mul_all_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_mul_all_dnxt,
        muldiv_op_mul_all
    );
    assign muldiv_op_mul_all_o = muldiv_op_mul_all;

    wire muldiv_op_div_all_dnxt = flush_en ? 1'b0 : muldiv_op_div_all_i;
    wire muldiv_op_div_all;
    gnrl_dfflr #(1) muldiv_op_div_all_ff (
        clk,
        rst_n,
        reg_update_en,
        muldiv_op_div_all_dnxt,
        muldiv_op_div_all
    );
    assign muldiv_op_div_all_o = muldiv_op_div_all;

    // CSR信号寄存
    wire req_csr_dnxt = flush_en ? 1'b0 : req_csr_i;
    wire req_csr;
    gnrl_dfflr #(1) req_csr_ff (
        clk,
        rst_n,
        reg_update_en,
        req_csr_dnxt,
        req_csr
    );
    assign req_csr_o = req_csr;

    wire [31:0] csr_op1_dnxt = flush_en ? `ZeroWord : csr_op1_i;
    wire [31:0] csr_op1;
    gnrl_dfflr #(32) csr_op1_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_op1_dnxt,
        csr_op1
    );
    assign csr_op1_o = csr_op1;

    wire [31:0] csr_addr_dnxt = flush_en ? `ZeroWord : csr_addr_i;
    wire [31:0] csr_addr;
    gnrl_dfflr #(32) csr_addr_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_addr_dnxt,
        csr_addr
    );
    assign csr_addr_o = csr_addr;

    wire csr_csrrw_dnxt = flush_en ? 1'b0 : csr_csrrw_i;
    wire csr_csrrw;
    gnrl_dfflr #(1) csr_csrrw_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_csrrw_dnxt,
        csr_csrrw
    );
    assign csr_csrrw_o = csr_csrrw;

    wire csr_csrrs_dnxt = flush_en ? 1'b0 : csr_csrrs_i;
    wire csr_csrrs;
    gnrl_dfflr #(1) csr_csrrs_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_csrrs_dnxt,
        csr_csrrs
    );
    assign csr_csrrs_o = csr_csrrs;

    wire csr_csrrc_dnxt = flush_en ? 1'b0 : csr_csrrc_i;
    wire csr_csrrc;
    gnrl_dfflr #(1) csr_csrrc_ff (
        clk,
        rst_n,
        reg_update_en,
        csr_csrrc_dnxt,
        csr_csrrc
    );
    assign csr_csrrc_o = csr_csrrc;

    // MEM信号寄存
    wire req_mem_dnxt = flush_en ? 1'b0 : req_mem_i;
    wire req_mem;
    gnrl_dfflr #(1) req_mem_ff (
        clk,
        rst_n,
        reg_update_en,
        req_mem_dnxt,
        req_mem
    );
    assign req_mem_o = req_mem;

    wire mem_op_lb_dnxt = flush_en ? 1'b0 : mem_op_lb_i;
    wire mem_op_lb;
    gnrl_dfflr #(1) mem_op_lb_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_lb_dnxt,
        mem_op_lb
    );
    assign mem_op_lb_o = mem_op_lb;

    wire mem_op_lh_dnxt = flush_en ? 1'b0 : mem_op_lh_i;
    wire mem_op_lh;
    gnrl_dfflr #(1) mem_op_lh_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_lh_dnxt,
        mem_op_lh
    );
    assign mem_op_lh_o = mem_op_lh;

    wire mem_op_lw_dnxt = flush_en ? 1'b0 : mem_op_lw_i;
    wire mem_op_lw;
    gnrl_dfflr #(1) mem_op_lw_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_lw_dnxt,
        mem_op_lw
    );
    assign mem_op_lw_o = mem_op_lw;

    wire mem_op_lbu_dnxt = flush_en ? 1'b0 : mem_op_lbu_i;
    wire mem_op_lbu;
    gnrl_dfflr #(1) mem_op_lbu_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_lbu_dnxt,
        mem_op_lbu
    );
    assign mem_op_lbu_o = mem_op_lbu;

    wire mem_op_lhu_dnxt = flush_en ? 1'b0 : mem_op_lhu_i;
    wire mem_op_lhu;
    gnrl_dfflr #(1) mem_op_lhu_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_lhu_dnxt,
        mem_op_lhu
    );
    assign mem_op_lhu_o = mem_op_lhu;

    wire mem_op_load_dnxt = flush_en ? 1'b0 : mem_op_load_i;
    wire mem_op_load;
    gnrl_dfflr #(1) mem_op_load_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_load_dnxt,
        mem_op_load
    );
    assign mem_op_load_o = mem_op_load;

    wire mem_op_store_dnxt = flush_en ? 1'b0 : mem_op_store_i;
    wire mem_op_store;
    gnrl_dfflr #(1) mem_op_store_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_op_store_dnxt,
        mem_op_store
    );
    assign mem_op_store_o = mem_op_store;

    // SYS信号寄存
    wire sys_op_nop_dnxt = flush_en ? 1'b0 : sys_op_nop_i;
    wire sys_op_nop;
    gnrl_dfflr #(1) sys_op_nop_ff (
        clk,
        rst_n,
        reg_update_en,
        sys_op_nop_dnxt,
        sys_op_nop
    );
    assign sys_op_nop_o = sys_op_nop;

    wire sys_op_mret_dnxt = flush_en ? 1'b0 : sys_op_mret_i;
    wire sys_op_mret;
    gnrl_dfflr #(1) sys_op_mret_ff (
        clk,
        rst_n,
        reg_update_en,
        sys_op_mret_dnxt,
        sys_op_mret
    );
    assign sys_op_mret_o = sys_op_mret;

    wire sys_op_ecall_dnxt = flush_en ? 1'b0 : sys_op_ecall_i;
    wire sys_op_ecall;
    gnrl_dfflr #(1) sys_op_ecall_ff (
        clk,
        rst_n,
        reg_update_en,
        sys_op_ecall_dnxt,
        sys_op_ecall
    );
    assign sys_op_ecall_o = sys_op_ecall;

    wire sys_op_ebreak_dnxt = flush_en ? 1'b0 : sys_op_ebreak_i;
    wire sys_op_ebreak;
    gnrl_dfflr #(1) sys_op_ebreak_ff (
        clk,
        rst_n,
        reg_update_en,
        sys_op_ebreak_dnxt,
        sys_op_ebreak
    );
    assign sys_op_ebreak_o = sys_op_ebreak;

    wire sys_op_fence_dnxt = flush_en ? 1'b0 : sys_op_fence_i;
    wire sys_op_fence;
    gnrl_dfflr #(1) sys_op_fence_ff (
        clk,
        rst_n,
        reg_update_en,
        sys_op_fence_dnxt,
        sys_op_fence
    );
    assign sys_op_fence_o = sys_op_fence;

    wire sys_op_dret_dnxt = flush_en ? 1'b0 : sys_op_dret_i;
    wire sys_op_dret;
    gnrl_dfflr #(1) sys_op_dret_ff (
        clk,
        rst_n,
        reg_update_en,
        sys_op_dret_dnxt,
        sys_op_dret
    );
    assign sys_op_dret_o = sys_op_dret;

    // 新增：rs1_rdata寄存器
    wire [31:0] rs1_rdata_dnxt = flush_en ? 32'b0 : rs1_rdata_i;
    wire [31:0] rs1_rdata;
    gnrl_dfflr #(32) rs1_rdata_ff (
        clk,
        rst_n,
        reg_update_en,
        rs1_rdata_dnxt,
        rs1_rdata
    );
    assign rs1_rdata_o = rs1_rdata;

    // 新增：rs2_rdata寄存器
    wire [31:0] rs2_rdata_dnxt = flush_en ? 32'b0 : rs2_rdata_i;
    wire [31:0] rs2_rdata;
    gnrl_dfflr #(32) rs2_rdata_ff (
        clk,
        rst_n,
        reg_update_en,
        rs2_rdata_dnxt,
        rs2_rdata
    );
    assign rs2_rdata_o = rs2_rdata;

    // 新增：预测分支信号寄存器
    wire is_pred_branch_dnxt = flush_en ? 1'b0 : is_pred_branch_i;
    wire is_pred_branch;
    gnrl_dfflr #(1) is_pred_branch_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        is_pred_branch_dnxt,
        is_pred_branch
    );
    assign is_pred_branch_o = is_pred_branch;

    // 新增：内存地址寄存器
    wire [31:0] mem_addr_dnxt = flush_en ? `ZeroWord : mem_addr_i;
    wire [31:0] mem_addr;
    gnrl_dfflr #(32) mem_addr_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_addr_dnxt,
        mem_addr
    );
    assign mem_addr_o = mem_addr;

    // 新增：内存写掩码寄存器
    wire [3:0] mem_wmask_dnxt = flush_en ? 4'b0 : mem_wmask_i;
    wire [3:0] mem_wmask;
    gnrl_dfflr #(4) mem_wmask_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_wmask_dnxt,
        mem_wmask
    );
    assign mem_wmask_o = mem_wmask;

    // 新增：内存写数据寄存器
    wire [31:0] mem_wdata_dnxt = flush_en ? `ZeroWord : mem_wdata_i;
    wire [31:0] mem_wdata;
    gnrl_dfflr #(32) mem_wdata_ff (
        clk,
        rst_n,
        reg_update_en,
        mem_wdata_dnxt,
        mem_wdata
    );
    assign mem_wdata_o = mem_wdata;

    // 新增：指令有效信号寄存器
    wire inst_valid_dnxt = flush_en ? 1'b0 : inst_valid_i;
    wire inst_valid;
    gnrl_dfflr #(1) inst_valid_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        inst_valid_dnxt,
        inst_valid
    );
    assign inst_valid_o = inst_valid;

    // 新增：未对齐访存异常流水线寄存器
    wire misaligned_load_dnxt = flush_en ? 1'b0 : misaligned_load_i;
    wire misaligned_load;
    gnrl_dfflr #(1) misaligned_load_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        misaligned_load_dnxt,
        misaligned_load
    );
    assign misaligned_load_o = misaligned_load;

    wire misaligned_store_dnxt = flush_en ? 1'b0 : misaligned_store_i;
    wire misaligned_store;
    gnrl_dfflr #(1) misaligned_store_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        misaligned_store_dnxt,
        misaligned_store
    );
    assign misaligned_store_o = misaligned_store;

    // 新增：指令内容流水线寄存器
    wire [31:0] inst_dnxt = flush_en ? 32'b0 : inst_i;
    wire [31:0] inst;
    gnrl_dfflr #(32) inst_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        inst_dnxt,
        inst
    );
    assign inst_o = inst;

    // 新增：非法指令流水线寄存器
    wire illegal_inst_dnxt = flush_en ? 1'b0 : illegal_inst_i;
    wire illegal_inst;
    gnrl_dfflr #(1) illegal_inst_ff (
        clk,
        rst_n,
        ~inst_info_stall_en,
        illegal_inst_dnxt,
        illegal_inst
    );
    assign illegal_inst_o = illegal_inst;

endmodule
