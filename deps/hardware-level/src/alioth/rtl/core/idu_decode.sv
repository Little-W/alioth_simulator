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

// 译码模块
// 纯组合逻辑电路
module idu_decode (
    input wire rst_n,

    // from if_id
    input wire [`INST_DATA_WIDTH-1:0] inst_i,       // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,  // 指令地址
    input wire                        inst_valid_i,

    // to regs
    output wire [`REG_ADDR_WIDTH-1:0] reg1_raddr_o,  // 读通用寄存器1地址
    output wire [`REG_ADDR_WIDTH-1:0] reg2_raddr_o,  // 读通用寄存器2地址

    output wire rs1_re_o,
    output wire rs2_re_o,

    // to csr reg
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // 读CSR寄存器地址

    // to ex
    output wire [                  31:0] dec_imm_o,       // 立即数
    output wire [    `DECINFO_WIDTH-1:0] dec_info_bus_o,  // 译码信息  [18:0] 
    output wire [  `INST_ADDR_WIDTH-1:0] inst_addr_o,     // 指令地址
    output wire                          reg_we_o,        // 写通用寄存器标志
    output wire [   `REG_ADDR_WIDTH-1:0] reg_waddr_o,     // 写通用寄存器地址
    output wire                          csr_we_o,        // 写CSR寄存器标志
    output wire [   `BUS_ADDR_WIDTH-1:0] csr_waddr_o,     // 写CSR寄存器地址
    output wire                          illegal_inst_o,
    output wire [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus_o    // 新增：ex单元类型输出
);

    assign inst_addr_o = inst_addr_i;

    wire [31:0] inst = inst_i;
    //取出指令域
    wire [6:0] opcode = inst_i[6:0];
    wire [2:0] funct3 = inst_i[14:12];
    wire [6:0] funct7 = inst_i[31:25];
    wire [4:0] rd = inst_i[11:7];
    wire [4:0] rs1 = inst_i[19:15];
    wire [4:0] rs2 = inst_i[24:20];
    // 指令中的立即数，拓展为32位
    wire [31:0] inst_u_type_imm = {inst[31:12], 12'b0};
    wire [31:0] inst_j_type_imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    wire [31:0] inst_jr_type_imm = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] inst_b_type_imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [31:0] inst_s_type_imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    wire [31:0] inst_i_type_imm = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] inst_csr_type_imm = {27'h0, inst[19:15]};
    wire [31:0] inst_shift_type_imm = {27'h0, inst[24:20]};

    // 指令opcode域的取值
    wire opcode_0110111 = (opcode == 7'b0110111);
    wire opcode_0010111 = (opcode == 7'b0010111);
    wire opcode_1101111 = (opcode == 7'b1101111);
    wire opcode_1100111 = (opcode == 7'b1100111);
    wire opcode_1100011 = (opcode == 7'b1100011);
    wire opcode_0000011 = (opcode == 7'b0000011);
    wire opcode_0100011 = (opcode == 7'b0100011);
    wire opcode_0010011 = (opcode == 7'b0010011);
    wire opcode_0110011 = (opcode == 7'b0110011);
    wire opcode_0001111 = (opcode == 7'b0001111);
    wire opcode_1110011 = (opcode == 7'b1110011);

    // 指令funct3域的取值
    wire funct3_000 = (funct3 == 3'b000);
    wire funct3_001 = (funct3 == 3'b001);
    wire funct3_010 = (funct3 == 3'b010);
    wire funct3_011 = (funct3 == 3'b011);
    wire funct3_100 = (funct3 == 3'b100);
    wire funct3_101 = (funct3 == 3'b101);
    wire funct3_110 = (funct3 == 3'b110);
    wire funct3_111 = (funct3 == 3'b111);

    // 指令funct7域的取值
    wire funct7_0000000 = (funct7 == 7'b0000000);
    wire funct7_0100000 = (funct7 == 7'b0100000);
    wire funct7_0000001 = (funct7 == 7'b0000001);

    // 译码出具体指令控制信号
    wire inst_lui = opcode_0110111;
    wire inst_auipc = opcode_0010111;
    wire inst_jal = opcode_1101111;
    wire inst_jalr = opcode_1100111 & funct3_000;
    wire inst_beq = opcode_1100011 & funct3_000;
    wire inst_bne = opcode_1100011 & funct3_001;
    wire inst_blt = opcode_1100011 & funct3_100;
    wire inst_bge = opcode_1100011 & funct3_101;
    wire inst_bltu = opcode_1100011 & funct3_110;
    wire inst_bgeu = opcode_1100011 & funct3_111;
    wire inst_lb = opcode_0000011 & funct3_000;
    wire inst_lh = opcode_0000011 & funct3_001;
    wire inst_lw = opcode_0000011 & funct3_010;
    wire inst_lbu = opcode_0000011 & funct3_100;
    wire inst_lhu = opcode_0000011 & funct3_101;
    wire inst_sb = opcode_0100011 & funct3_000;
    wire inst_sh = opcode_0100011 & funct3_001;
    wire inst_sw = opcode_0100011 & funct3_010;
    wire inst_addi = opcode_0010011 & funct3_000;
    wire inst_slti = opcode_0010011 & funct3_010;
    wire inst_sltiu = opcode_0010011 & funct3_011;
    wire inst_xori = opcode_0010011 & funct3_100;
    wire inst_ori = opcode_0010011 & funct3_110;
    wire inst_andi = opcode_0010011 & funct3_111;
    wire inst_slli = opcode_0010011 & funct3_001 & funct7_0000000;
    wire inst_srli = opcode_0010011 & funct3_101 & funct7_0000000;
    wire inst_srai = opcode_0010011 & funct3_101 & funct7_0100000;
    wire inst_add = opcode_0110011 & funct3_000 & funct7_0000000;
    wire inst_sub = opcode_0110011 & funct3_000 & funct7_0100000;
    wire inst_sll = opcode_0110011 & funct3_001 & funct7_0000000;
    wire inst_slt = opcode_0110011 & funct3_010 & funct7_0000000;
    wire inst_sltu = opcode_0110011 & funct3_011 & funct7_0000000;
    wire inst_xor = opcode_0110011 & funct3_100 & funct7_0000000;
    wire inst_srl = opcode_0110011 & funct3_101 & funct7_0000000;
    wire inst_sra = opcode_0110011 & funct3_101 & funct7_0100000;
    wire inst_or = opcode_0110011 & funct3_110 & funct7_0000000;
    wire inst_and = opcode_0110011 & funct3_111 & funct7_0000000;
    wire inst_fence = opcode_0001111 & funct3_000;
    wire inst_ecall = (inst == `INST_ECALL);
    wire inst_ebreak = (inst == `INST_EBREAK);
    wire inst_fence_i = opcode_0001111 & funct3_001;
    wire inst_csrrw = opcode_1110011 & funct3_001;
    wire inst_csrrs = opcode_1110011 & funct3_010;
    wire inst_csrrc = opcode_1110011 & funct3_011;
    wire inst_csrrwi = opcode_1110011 & funct3_101;
    wire inst_csrrsi = opcode_1110011 & funct3_110;
    wire inst_csrrci = opcode_1110011 & funct3_111;
    wire inst_mul = opcode_0110011 & funct3_000 & funct7_0000001;
    wire inst_mulh = opcode_0110011 & funct3_001 & funct7_0000001;
    wire inst_mulhsu = opcode_0110011 & funct3_010 & funct7_0000001;
    wire inst_mulhu = opcode_0110011 & funct3_011 & funct7_0000001;
    wire inst_div = opcode_0110011 & funct3_100 & funct7_0000001;
    wire inst_divu = opcode_0110011 & funct3_101 & funct7_0000001;
    wire inst_rem = opcode_0110011 & funct3_110 & funct7_0000001;
    wire inst_remu = opcode_0110011 & funct3_111 & funct7_0000001;
    wire inst_nop = (inst == `INST_NOP);
    wire inst_mret = (inst == `INST_MRET);
    wire inst_dret = (inst == `INST_DRET);

    // 将指令分类 - 提前计算常用指令类型分组，避免重复判断
    wire inst_type_load = opcode_0000011;
    wire inst_type_store = opcode_0100011;
    wire inst_type_branch = opcode_1100011;
    wire insr_type_cstr = opcode_1110011;

    // 优化乘除法类型指令判断，避免重复逻辑
    wire inst_type_mul = inst_mul | inst_mulh | inst_mulhsu | inst_mulhu;
    wire inst_type_div = inst_div | inst_divu | inst_rem | inst_remu;
    wire inst_type_muldiv = inst_type_mul | inst_type_div;

    // 立即数指令分组
    wire inst_i_type = inst_addi | inst_slti | inst_sltiu | inst_xori | inst_ori | inst_andi | inst_type_load | inst_jalr;
    wire inst_shift_i_type = inst_slli | inst_srli | inst_srai;
    wire inst_csr_i_type = inst_csrrwi | inst_csrrsi | inst_csrrci;

    // 立即数控制信号优化
    wire inst_sel_u_imm = inst_lui | inst_auipc;
    wire inst_sel_j_imm = inst_jal;
    wire inst_sel_jr_imm = inst_jalr;
    wire inst_sel_b_imm = inst_type_branch;
    wire inst_sel_s_imm = inst_type_store;
    wire inst_sel_i_imm = inst_i_type;
    wire inst_sel_csr_imm = inst_csr_i_type;
    wire inst_sel_shift_imm = inst_shift_i_type;

    // 立即数选择
    assign dec_imm_o = ({32{inst_sel_u_imm}} & inst_u_type_imm) |
                       ({32{inst_sel_j_imm}} & inst_j_type_imm) |
                       ({32{inst_sel_jr_imm}} & inst_jr_type_imm) |
                       ({32{inst_sel_b_imm}} & inst_b_type_imm) |
                       ({32{inst_sel_s_imm}} & inst_s_type_imm) |
                       ({32{inst_sel_i_imm}} & inst_i_type_imm) |
                       ({32{inst_sel_csr_imm}} & inst_csr_type_imm) |
                       ({32{inst_sel_shift_imm}} & inst_shift_type_imm);

    wire [`DECINFO_ALU_BUS_WIDTH-1:0] dec_alu_info_bus;
    assign dec_alu_info_bus[`DECINFO_GRP_BUS]    = `DECINFO_GRP_ALU;
    assign dec_alu_info_bus[`DECINFO_ALU_LUI]    = inst_lui;
    assign dec_alu_info_bus[`DECINFO_ALU_AUIPC]  = inst_auipc;
    assign dec_alu_info_bus[`DECINFO_ALU_ADD]    = inst_add | inst_addi;
    assign dec_alu_info_bus[`DECINFO_ALU_SUB]    = inst_sub;
    assign dec_alu_info_bus[`DECINFO_ALU_SLL]    = inst_sll | inst_slli;
    assign dec_alu_info_bus[`DECINFO_ALU_SLT]    = inst_slt | inst_slti;
    assign dec_alu_info_bus[`DECINFO_ALU_SLTU]   = inst_sltu | inst_sltiu;
    assign dec_alu_info_bus[`DECINFO_ALU_XOR]    = (inst_xor | inst_xori);
    assign dec_alu_info_bus[`DECINFO_ALU_SRL]    = inst_srl | inst_srli;
    assign dec_alu_info_bus[`DECINFO_ALU_SRA]    = inst_sra | inst_srai;
    assign dec_alu_info_bus[`DECINFO_ALU_OR]     = inst_or | inst_ori;
    assign dec_alu_info_bus[`DECINFO_ALU_AND]    = inst_and | inst_andi;
    assign dec_alu_info_bus[`DECINFO_ALU_OP2IMM] = opcode_0010011 | inst_lui | inst_auipc;
    assign dec_alu_info_bus[`DECINFO_ALU_OP1PC]  = inst_auipc;

    wire [`DECINFO_BJP_BUS_WIDTH-1:0] dec_bjp_info_bus;
    assign dec_bjp_info_bus[`DECINFO_GRP_BUS]    = `DECINFO_GRP_BJP;
    assign dec_bjp_info_bus[`DECINFO_BJP_JUMP]   = inst_jal | inst_jalr;
    assign dec_bjp_info_bus[`DECINFO_BJP_BEQ]    = inst_beq;
    assign dec_bjp_info_bus[`DECINFO_BJP_BNE]    = inst_bne;
    assign dec_bjp_info_bus[`DECINFO_BJP_BLT]    = inst_blt;
    assign dec_bjp_info_bus[`DECINFO_BJP_BGE]    = inst_bge;
    assign dec_bjp_info_bus[`DECINFO_BJP_BLTU]   = inst_bltu;
    assign dec_bjp_info_bus[`DECINFO_BJP_BGEU]   = inst_bgeu;
    assign dec_bjp_info_bus[`DECINFO_BJP_OP1RS1] = inst_jalr;

    wire [`DECINFO_MULDIV_BUS_WIDTH-1:0] dec_muldiv_info_bus;
    assign dec_muldiv_info_bus[`DECINFO_GRP_BUS]       = `DECINFO_GRP_MULDIV;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_MUL]    = inst_mul;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_MULH]   = inst_mulh;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_MULHSU] = inst_mulhsu;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_MULHU]  = inst_mulhu;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_DIV]    = inst_div;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_DIVU]   = inst_divu;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_REM]    = inst_rem;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_REMU]   = inst_remu;

    assign dec_muldiv_info_bus[`DECINFO_MULDIV_OP_MUL] = inst_type_mul;
    assign dec_muldiv_info_bus[`DECINFO_MULDIV_OP_DIV] = inst_type_div;

    wire [`DECINFO_CSR_BUS_WIDTH-1:0] dec_csr_info_bus;
    assign dec_csr_info_bus[`DECINFO_GRP_BUS]     = `DECINFO_GRP_CSR;
    assign dec_csr_info_bus[`DECINFO_CSR_CSRRW]   = inst_csrrw | inst_csrrwi;
    assign dec_csr_info_bus[`DECINFO_CSR_CSRRS]   = inst_csrrs | inst_csrrsi;
    assign dec_csr_info_bus[`DECINFO_CSR_CSRRC]   = inst_csrrc | inst_csrrci;
    assign dec_csr_info_bus[`DECINFO_CSR_RS1IMM]  = inst_csrrwi | inst_csrrsi | inst_csrrci;
    assign dec_csr_info_bus[`DECINFO_CSR_CSRADDR] = inst[31:20];

    wire [`DECINFO_MEM_BUS_WIDTH-1:0] dec_mem_info_bus;
    assign dec_mem_info_bus[`DECINFO_GRP_BUS]      = `DECINFO_GRP_MEM;
    assign dec_mem_info_bus[`DECINFO_MEM_LB]       = inst_lb;
    assign dec_mem_info_bus[`DECINFO_MEM_LH]       = inst_lh;
    assign dec_mem_info_bus[`DECINFO_MEM_LW]       = inst_lw;
    assign dec_mem_info_bus[`DECINFO_MEM_LBU]      = inst_lbu;
    assign dec_mem_info_bus[`DECINFO_MEM_LHU]      = inst_lhu;
    assign dec_mem_info_bus[`DECINFO_MEM_SB]       = inst_sb;
    assign dec_mem_info_bus[`DECINFO_MEM_SH]       = inst_sh;
    assign dec_mem_info_bus[`DECINFO_MEM_SW]       = inst_sw;
    // 直接使用之前定义的类型信号
    assign dec_mem_info_bus[`DECINFO_MEM_OP_LOAD]  = inst_type_load;
    assign dec_mem_info_bus[`DECINFO_MEM_OP_STORE] = inst_type_store;

    wire [`DECINFO_SYS_BUS_WIDTH-1:0] dec_sys_info_bus;
    assign dec_sys_info_bus[`DECINFO_GRP_BUS]    = `DECINFO_GRP_SYS;
    assign dec_sys_info_bus[`DECINFO_SYS_ECALL]  = inst_ecall;
    assign dec_sys_info_bus[`DECINFO_SYS_EBREAK] = inst_ebreak;
    assign dec_sys_info_bus[`DECINFO_SYS_NOP]    = inst_nop;
    assign dec_sys_info_bus[`DECINFO_SYS_MRET]   = inst_mret;
    assign dec_sys_info_bus[`DECINFO_SYS_DRET]   = inst_dret;
    assign dec_sys_info_bus[`DECINFO_SYS_FENCE]  = inst_fence | inst_fence_i;

    // 操作码逻辑优化
    wire op_alu = (inst_lui | inst_auipc | (opcode_0010011 & (~inst_nop)) | (opcode_0110011 & (~inst_type_muldiv)));
    wire op_bjp = inst_jal | inst_jalr | inst_type_branch;
    wire op_muldiv = inst_type_muldiv;
    wire op_csr = insr_type_cstr & (funct3_001 | funct3_010 | funct3_011 | funct3_101 | funct3_110 | funct3_111);
    wire op_sys = inst_ebreak | inst_ecall | inst_nop | inst_mret | inst_fence | inst_fence_i | inst_dret;
    wire op_mem = inst_type_load | inst_type_store;

    assign dec_info_bus_o = ({`DECINFO_WIDTH{op_alu}} & {{`DECINFO_WIDTH-`DECINFO_ALU_BUS_WIDTH{1'b0}}, dec_alu_info_bus}) |
                            ({`DECINFO_WIDTH{op_bjp}} & {{`DECINFO_WIDTH-`DECINFO_BJP_BUS_WIDTH{1'b0}}, dec_bjp_info_bus}) |
                            ({`DECINFO_WIDTH{op_muldiv}} & {{`DECINFO_WIDTH-`DECINFO_MULDIV_BUS_WIDTH{1'b0}}, dec_muldiv_info_bus}) |
                            ({`DECINFO_WIDTH{op_csr}} & {{`DECINFO_WIDTH-`DECINFO_CSR_BUS_WIDTH{1'b0}}, dec_csr_info_bus}) |
                            ({`DECINFO_WIDTH{op_mem}} & {{`DECINFO_WIDTH-`DECINFO_MEM_BUS_WIDTH{1'b0}}, dec_mem_info_bus}) |
                            ({`DECINFO_WIDTH{op_sys}} & {{`DECINFO_WIDTH-`DECINFO_SYS_BUS_WIDTH{1'b0}}, dec_sys_info_bus});


    // 是否需要访问rs1寄存器 - 优化为使用指令类型判断
    wire access_rs1 = (~inst_lui) & (~inst_auipc) & (~inst_jal) & 
                      (~inst_ecall) & (~inst_ebreak) & (~inst_csr_i_type) & 
                      (~inst_nop) & (~inst_fence) & (~inst_fence_i) & (~inst_mret);

    assign reg1_raddr_o = access_rs1 ? rs1 : 5'h0;
    assign rs1_re_o     = access_rs1 && (rs1 != 0);

    // 是否需要访问rs2寄存器
    wire access_rs2 = opcode_0110011 | inst_type_store | inst_type_branch;

    assign reg2_raddr_o = access_rs2 ? rs2 : 5'h0;
    assign rs2_re_o     = access_rs2 && (rs2 != 0);

    // 是否需要访问rd寄存器，优化逻辑：
    // 1. 只有真正需要写回的指令才会置位access_rd
    // 2. 当rd=x0时不进行写回操作（RISC-V架构规定）
    wire rd_not_zero = (rd != 5'h0);
    wire access_rd = (inst_lui | inst_auipc | inst_jal | inst_jalr | 
                     inst_type_load | (opcode_0010011 & (~inst_nop)) | opcode_0110011 | 
                     op_csr) & rd_not_zero;

    assign reg_waddr_o = access_rd ? rd : 5'h0;
    assign reg_we_o    = access_rd;

    assign csr_waddr_o = insr_type_cstr ? {20'h0, inst_i[31:20]} : `ZeroWord;
    assign csr_we_o    = insr_type_cstr;
    assign csr_raddr_o = csr_we_o ? inst[31:20] : `ZeroWord;

    // 增加对slli非法移位量的检测
    wire slli_illegal_shamt = opcode_0010011 & funct3_001 & funct7_0000001;

    // 增加非法指令检测输出
    assign illegal_inst_o = (
        ((dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_NONE) && inst_valid_i)
        || slli_illegal_shamt
    );

    // ex_info_bus_o类型编码
    assign ex_info_bus_o =
        op_alu        ? `EX_INFO_ALU   :
        inst_type_mul ? `EX_INFO_MUL   :
        inst_type_div ? `EX_INFO_DIV   :
        op_csr        ? `EX_INFO_CSR   :
        op_bjp        ? `EX_INFO_BJP   :
        inst_type_load ? `EX_INFO_LOAD :
        `EX_INFO_OTHER; // 默认设置为其他类型

endmodule
