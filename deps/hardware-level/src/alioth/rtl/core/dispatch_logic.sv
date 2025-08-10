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


module dispatch_logic (

    input wire [`DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [              31:0] dec_imm_i,
    input wire [              31:0] dec_pc_i,
    input wire [              31:0] rs1_rdata_i,
    input wire [              31:0] rs2_rdata_i,

    // dispatch to ALU
    output wire                     req_alu_o,
    output wire [             31:0] alu_op1_o,
    output wire [             31:0] alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] alu_op_info_o,

    // dispatch to Bru
    output wire req_bjp_o,
    output wire bjp_op_jal_o,
    output wire bjp_op_beq_o,
    output wire bjp_op_bne_o,
    output wire bjp_op_blt_o,
    output wire bjp_op_bltu_o,
    output wire bjp_op_bge_o,
    output wire bjp_op_bgeu_o,
    output wire bjp_op_jalr_o,

    // 新增输出
    output wire [31:0] bjp_adder_result_o,
    output wire [31:0] bjp_next_pc_o,
    output wire        op1_eq_op2_o,
    output wire        op1_ge_op2_signed_o,
    output wire        op1_ge_op2_unsigned_o,

    // dispatch to MUL
    output wire [31:0] mul_op1_o,
    output wire [31:0] mul_op2_o,
    output wire        mul_op_mul_o,
    output wire        mul_op_mulh_o,
    output wire        mul_op_mulhsu_o,
    output wire        mul_op_mulhu_o,
    output wire        req_mul_o,

    // dispatch to DIV
    output wire [31:0] div_op1_o,
    output wire [31:0] div_op2_o,
    output wire        div_op_div_o,
    output wire        div_op_divu_o,
    output wire        div_op_rem_o,
    output wire        div_op_remu_o,
    output wire        req_div_o,

    // dispatch to CSR
    output wire        req_csr_o,
    output wire [31:0] csr_op1_o,
    output wire [31:0] csr_addr_o,
    output wire        csr_csrrw_o,
    output wire        csr_csrrs_o,
    output wire        csr_csrrc_o,

    // dispatch to MEM
    output wire req_mem_o,
    output wire mem_op_lb_o,
    output wire mem_op_lh_o,
    output wire mem_op_lw_o,
    output wire mem_op_lbu_o,
    output wire mem_op_lhu_o,
    output wire mem_op_load_o,
    output wire mem_op_store_o,

    // 直接计算的内存地址和掩码/数据
    output wire [31:0] mem_addr_o,
    output wire [ 3:0] mem_wmask_o,
    output wire [31:0] mem_wdata_o,

    // dispatch to SYS
    output wire sys_op_nop_o,
    output wire sys_op_mret_o,
    output wire sys_op_ecall_o,
    output wire sys_op_ebreak_o,
    output wire sys_op_fence_o,
    output wire sys_op_dret_o,

    // 新增：未对齐访存异常输出
    output wire misaligned_load_o,
    output wire misaligned_store_o
);

    wire [`DECINFO_GRP_WIDTH-1:0] disp_info_grp = dec_info_bus_i[`DECINFO_GRP_BUS];

    wire [`DECINFO_WIDTH-1:0] bjp_info;
    // ALU info
    wire bjp_wb_req = bjp_info[`DECINFO_BJP_JUMP];
    wire op_alu = (disp_info_grp == `DECINFO_GRP_ALU);
    wire [`DECINFO_WIDTH-1:0] alu_info = {`DECINFO_WIDTH{op_alu}} & dec_info_bus_i;
    // ALU op1
    wire alu_op1_pc = alu_info[`DECINFO_ALU_OP1PC];  // 使用PC作为操作数1 (AUIPC指令)
    wire alu_op1_zero = alu_info[`DECINFO_ALU_LUI];  // 使用0作为操作数1 (LUI指令)
    wire [31:0] alu_op1 = (alu_op1_pc | bjp_wb_req) ? dec_pc_i : alu_op1_zero ? 32'h0 : rs1_rdata_i;
    assign alu_op1_o = (op_alu | bjp_wb_req) ? alu_op1 : 32'h0;  // ALU指令的操作数1

    // ALU op2
    wire alu_op2_imm = alu_info[`DECINFO_ALU_OP2IMM];  // 使用立即数作为操作数2 (I型指令、LUI、AUIPC)
    wire [31:0] alu_op2 = alu_op2_imm ? dec_imm_i : rs2_rdata_i;
    assign alu_op2_o = bjp_wb_req ? 32'h4 : op_alu ? alu_op2 : 32'h0;

    assign alu_op_info_o = {
        bjp_wb_req,  // ALU_OP_JUMP
        alu_info[`DECINFO_ALU_AUIPC],  // ALU_OP_AUIPC
        alu_info[`DECINFO_ALU_LUI],  // ALU_OP_LUI
        alu_info[`DECINFO_ALU_AND],  // ALU_OP_AND
        alu_info[`DECINFO_ALU_OR],  // ALU_OP_OR
        alu_info[`DECINFO_ALU_SRA],  // ALU_OP_SRA
        alu_info[`DECINFO_ALU_SRL],  // ALU_OP_SRL
        alu_info[`DECINFO_ALU_XOR],  // ALU_OP_XOR
        alu_info[`DECINFO_ALU_SLTU],  // ALU_OP_SLTU
        alu_info[`DECINFO_ALU_SLT],  // ALU_OP_SLT
        alu_info[`DECINFO_ALU_SLL],  // ALU_OP_SLL
        alu_info[`DECINFO_ALU_SUB],  // ALU_OP_SUB
        alu_info[`DECINFO_ALU_ADD]  // ALU_OP_ADD
    };

    assign req_alu_o = op_alu | bjp_wb_req;

    // MULDIV info
    wire                      op_muldiv = (disp_info_grp == `DECINFO_GRP_MULDIV);
    wire [`DECINFO_WIDTH-1:0] muldiv_info = {`DECINFO_WIDTH{op_muldiv}} & dec_info_bus_i;
    // MULDIV op1
    wire [              31:0] muldiv_op1 = op_muldiv ? rs1_rdata_i : 32'h0;  // rs1寄存器值
    // MULDIV op2
    wire [              31:0] muldiv_op2 = op_muldiv ? rs2_rdata_i : 32'h0;  // rs2寄存器值

    // MUL signals
    assign req_mul_o       = muldiv_info[`DECINFO_MULDIV_OP_MUL];  // 所有乘法指令
    assign mul_op1_o       = req_mul_o ? muldiv_op1 : 32'h0;
    assign mul_op2_o       = req_mul_o ? muldiv_op2 : 32'h0;
    assign mul_op_mul_o    = muldiv_info[`DECINFO_MULDIV_MUL];  // MUL指令
    assign mul_op_mulh_o   = muldiv_info[`DECINFO_MULDIV_MULH];  // MULH指令
    assign mul_op_mulhu_o  = muldiv_info[`DECINFO_MULDIV_MULHU];  // MULHU指令
    assign mul_op_mulhsu_o = muldiv_info[`DECINFO_MULDIV_MULHSU];  // MULHSU指令

    // DIV signals
    assign req_div_o       = muldiv_info[`DECINFO_MULDIV_OP_DIV];  // 所有除法指令
    assign div_op1_o       = req_div_o ? muldiv_op1 : 32'h0;
    assign div_op2_o       = req_div_o ? muldiv_op2 : 32'h0;
    assign div_op_div_o    = muldiv_info[`DECINFO_MULDIV_DIV];  // DIV指令
    assign div_op_divu_o   = muldiv_info[`DECINFO_MULDIV_DIVU];  // DIVU指令
    assign div_op_rem_o    = muldiv_info[`DECINFO_MULDIV_REM];  // REM指令
    assign div_op_remu_o   = muldiv_info[`DECINFO_MULDIV_REMU];  // REMU指令

    // Bru info

    wire op_bjp = (disp_info_grp == `DECINFO_GRP_BJP);
    assign bjp_info = {`DECINFO_WIDTH{op_bjp}} & dec_info_bus_i;
    // BJP op1
    wire bjp_op1_rs1 = bjp_info[`DECINFO_BJP_OP1RS1];  // 使用rs1寄存器作为跳转基地址 (JALR指令)
    assign bjp_op_beq_o  = bjp_info[`DECINFO_BJP_BEQ];  // BEQ指令
    assign bjp_op_bne_o  = bjp_info[`DECINFO_BJP_BNE];  // BNE指令
    assign bjp_op_blt_o  = bjp_info[`DECINFO_BJP_BLT];  // BLT指令
    assign bjp_op_bltu_o = bjp_info[`DECINFO_BJP_BLTU];  // BLTU指令
    assign bjp_op_bge_o  = bjp_info[`DECINFO_BJP_BGE];  // BGE指令
    assign bjp_op_bgeu_o = bjp_info[`DECINFO_BJP_BGEU];  // BGEU指令
    assign req_bjp_o     = op_bjp;
    assign bjp_op_jal_o  = bjp_info[`DECINFO_BJP_JUMP] && !bjp_op1_rs1;  // JAL指令标志
    assign bjp_op_jalr_o = bjp_op1_rs1;  // JALR指令标志

    wire [31:0] bjp_jump_op1 = bjp_op1_rs1 ? rs1_rdata_i : dec_pc_i;
    wire [31:0] bjp_jump_op2 = dec_imm_i;  // 使用立即数作为跳转偏移量
    assign bjp_adder_result_o = bjp_jump_op1 + bjp_jump_op2;
    assign bjp_next_pc_o      = dec_pc_i + 32'h4;  // 默认下一条指令地址

    wire [31:0] bjp_op1 = op_bjp ? rs1_rdata_i : 32'h0;  // 用于分支指令的比较操作数1
    wire [31:0] bjp_op2 = op_bjp ? rs2_rdata_i : 32'h0;  // 用于分支指令的比较操作数2
    assign op1_eq_op2_o          = (bjp_op1 == bjp_op2);
    assign op1_ge_op2_signed_o   = $signed(bjp_op1) >= $signed(bjp_op2);
    assign op1_ge_op2_unsigned_o = bjp_op1 >= bjp_op2;

    // CSR info

    wire op_csr = (disp_info_grp == `DECINFO_GRP_CSR);
    wire [`DECINFO_WIDTH-1:0] csr_info = {`DECINFO_WIDTH{op_csr}} & dec_info_bus_i;
    // CSR op1
    wire csr_rs1imm = csr_info[`DECINFO_CSR_RS1IMM];  // 使用立即数作为操作数 (CSRxxI指令)
    wire [31:0] csr_rs1 = csr_rs1imm ? dec_imm_i : rs1_rdata_i;
    assign csr_op1_o   = op_csr ? csr_rs1 : 32'h0;
    assign csr_addr_o  = {{20{1'b0}}, csr_info[`DECINFO_CSR_CSRADDR]};  // CSR地址
    assign csr_csrrw_o = csr_info[`DECINFO_CSR_CSRRW];  // CSRRW/CSRRWI指令
    assign csr_csrrs_o = csr_info[`DECINFO_CSR_CSRRS];  // CSRRS/CSRRSI指令
    assign csr_csrrc_o = csr_info[`DECINFO_CSR_CSRRC];  // CSRRC/CSRRCI指令
    assign req_csr_o   = op_csr;

    // MEM info

    wire                      op_mem = (disp_info_grp == `DECINFO_GRP_MEM);
    wire [`DECINFO_WIDTH-1:0] mem_info = {`DECINFO_WIDTH{op_mem}} & dec_info_bus_i;

    // AGU实例化，负责所有mem op相关输出
    wire agu_mem_op_lb, agu_mem_op_lh, agu_mem_op_lw, agu_mem_op_lbu, agu_mem_op_lhu;
    wire agu_mem_op_sb, agu_mem_op_sh, agu_mem_op_sw;
    wire agu_mem_op_load, agu_mem_op_store;
    wire [31:0] agu_mem_addr;
    wire [ 3:0] agu_mem_wmask;
    wire [31:0] agu_mem_wdata;
    wire agu_misaligned_load, agu_misaligned_store;

    agu u_agu (
        .op_mem        (op_mem),
        .mem_info      (mem_info),
        .rs1_rdata_i   (rs1_rdata_i),
        .rs2_rdata_i   (rs2_rdata_i),
        .dec_imm_i     (dec_imm_i),
        .mem_op_lb_o   (agu_mem_op_lb),
        .mem_op_lh_o   (agu_mem_op_lh),
        .mem_op_lw_o   (agu_mem_op_lw),
        .mem_op_lbu_o  (agu_mem_op_lbu),
        .mem_op_lhu_o  (agu_mem_op_lhu),
        .mem_op_sb_o   (agu_mem_op_sb),
        .mem_op_sh_o   (agu_mem_op_sh),
        .mem_op_sw_o   (agu_mem_op_sw),
        .mem_op_load_o (agu_mem_op_load),
        .mem_op_store_o(agu_mem_op_store),
        .mem_addr_o    (agu_mem_addr),
        .mem_wmask_o   (agu_mem_wmask),
        .mem_wdata_o   (agu_mem_wdata),
        .misaligned_load_o  (agu_misaligned_load),
        .misaligned_store_o (agu_misaligned_store)
    );

    assign req_mem_o      = op_mem;
    assign mem_op_lb_o    = agu_mem_op_lb;
    assign mem_op_lh_o    = agu_mem_op_lh;
    assign mem_op_lw_o    = agu_mem_op_lw;
    assign mem_op_lbu_o   = agu_mem_op_lbu;
    assign mem_op_lhu_o   = agu_mem_op_lhu;
    assign mem_op_load_o  = agu_mem_op_load;
    assign mem_op_store_o = agu_mem_op_store;
    assign mem_addr_o     = agu_mem_addr;
    assign mem_wmask_o    = agu_mem_wmask;
    assign mem_wdata_o    = agu_mem_wdata;

    // 地址对齐检测逻辑直接由agu输出
    assign misaligned_load_o  = agu_misaligned_load;
    assign misaligned_store_o = agu_misaligned_store;

    // SYS info

    wire                      op_sys = (disp_info_grp == `DECINFO_GRP_SYS);
    wire [`DECINFO_WIDTH-1:0] sys_info = {`DECINFO_WIDTH{op_sys}} & dec_info_bus_i;
    assign sys_op_nop_o    = sys_info[`DECINFO_SYS_NOP];  // NOP指令
    assign sys_op_mret_o   = sys_info[`DECINFO_SYS_MRET];  // MRET指令：从机器模式返回
    assign sys_op_ecall_o  = sys_info[`DECINFO_SYS_ECALL];  // ECALL指令：环境调用
    assign sys_op_ebreak_o = sys_info[`DECINFO_SYS_EBREAK];  // EBREAK指令：断点
    assign sys_op_fence_o  = sys_info[`DECINFO_SYS_FENCE];  // FENCE指令：内存屏障
    assign sys_op_dret_o   = sys_info[`DECINFO_SYS_DRET];  // DRET指令：从调试模式返回

endmodule
