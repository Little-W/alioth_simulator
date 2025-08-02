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

    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,
    input wire [                31:0] dec_pc_i,
    input wire [`GREG_DATA_WIDTH-1:0] rs1_rdata_i,
    input wire [`GREG_DATA_WIDTH-1:0] rs2_rdata_i,
    input wire [`FREG_DATA_WIDTH-1:0] frs1_rdata_i,
    input wire [`FREG_DATA_WIDTH-1:0] frs2_rdata_i,
    input wire [`FREG_DATA_WIDTH-1:0] frs3_rdata_i,

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

    output wire misaligned_load_o,
    output wire misaligned_store_o,

    // FPU接口
    output logic                        req_fpu_o,
    output logic                        fpu_op_fadd_s_o,
    output logic                        fpu_op_fsub_s_o,
    output logic                        fpu_op_fmul_s_o,
    output logic                        fpu_op_fdiv_s_o,
    output logic                        fpu_op_fsqrt_s_o,
    output logic                        fpu_op_fsgnj_s_o,
    output logic                        fpu_op_fmax_s_o,
    output logic                        fpu_op_fcmp_s_o,
    output logic                        fpu_op_fcvt_f2i_s_o,
    output logic                        fpu_op_fcvt_i2f_s_o,
    output logic                        fpu_op_fmadd_s_o,
    output logic                        fpu_op_fmsub_s_o,
    output logic                        fpu_op_fnmadd_s_o,
    output logic                        fpu_op_fnmsub_s_o,
    output logic                        fpu_op_fmv_i2f_s_o,
    output logic                        fpu_op_fmv_f2i_s_o,
    output logic                        fpu_op_fclass_s_o,
    output logic [`FREG_DATA_WIDTH-1:0] fpu_op1_o,
    output logic [`FREG_DATA_WIDTH-1:0] fpu_op2_o,
    output logic [`FREG_DATA_WIDTH-1:0] fpu_op3_o,
    output logic [                 2:0] frm_o,
    output logic [                 1:0] fcvt_op_o
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
    assign muldiv_op1_o        = op_muldiv ? rs1_rdata_i : 32'h0;  // rs1寄存器值
    // MULDIV op2
    assign muldiv_op2_o        = op_muldiv ? rs2_rdata_i : 32'h0;  // rs2寄存器值
    assign muldiv_op_mul_o     = muldiv_info[`DECINFO_MULDIV_MUL];  // MUL指令
    assign muldiv_op_mulh_o    = muldiv_info[`DECINFO_MULDIV_MULH];  // MULH指令
    assign muldiv_op_mulhu_o   = muldiv_info[`DECINFO_MULDIV_MULHU];  // MULHU指令
    assign muldiv_op_mulhsu_o  = muldiv_info[`DECINFO_MULDIV_MULHSU];  // MULHSU指令
    assign muldiv_op_div_o     = muldiv_info[`DECINFO_MULDIV_DIV];  // DIV指令
    assign muldiv_op_divu_o    = muldiv_info[`DECINFO_MULDIV_DIVU];  // DIVU指令
    assign muldiv_op_rem_o     = muldiv_info[`DECINFO_MULDIV_REM];  // REM指令
    assign muldiv_op_remu_o    = muldiv_info[`DECINFO_MULDIV_REMU];  // REMU指令
    // 总的乘法和除法操作信号
    assign muldiv_op_mul_all_o = muldiv_info[`DECINFO_MULDIV_OP_MUL];  // 所有乘法指令
    assign muldiv_op_div_all_o = muldiv_info[`DECINFO_MULDIV_OP_DIV];  // 所有除法指令
    assign req_muldiv_o        = op_muldiv;

    // Bru info

    wire op_bjp = (disp_info_grp == `DECINFO_GRP_BJP);
    assign bjp_info = {`DECINFO_WIDTH{op_bjp}} & dec_info_bus_i;
    // BJP op1
    wire bjp_op1_rs1 = bjp_info[`DECINFO_BJP_OP1RS1];  // 使用rs1寄存器作为跳转基地址 (JALR指令)
    wire [31:0] bjp_op1 = bjp_op1_rs1 ? rs1_rdata_i : dec_pc_i;
    assign bjp_jump_op1_o = (sys_op_fence_o | op_bjp) ? bjp_op1 : 32'h0;
    // BJP op2
    wire [31:0] bjp_op2 = dec_imm_i;  // 使用立即数作为跳转偏移量
    assign bjp_jump_op2_o = (sys_op_fence_o) ? 32'h4 : op_bjp ? bjp_op2 : 32'h0;
    assign bjp_op1_o      = op_bjp ? rs1_rdata_i : 32'h0;  // 用于分支指令的比较操作数1
    assign bjp_op2_o      = op_bjp ? rs2_rdata_i : 32'h0;  // 用于分支指令的比较操作数2
    assign bjp_op_beq_o   = bjp_info[`DECINFO_BJP_BEQ];  // BEQ指令
    assign bjp_op_bne_o   = bjp_info[`DECINFO_BJP_BNE];  // BNE指令
    assign bjp_op_blt_o   = bjp_info[`DECINFO_BJP_BLT];  // BLT指令
    assign bjp_op_bltu_o  = bjp_info[`DECINFO_BJP_BLTU];  // BLTU指令
    assign bjp_op_bge_o   = bjp_info[`DECINFO_BJP_BGE];  // BGE指令
    assign bjp_op_bgeu_o  = bjp_info[`DECINFO_BJP_BGEU];  // BGEU指令
    assign req_bjp_o      = op_bjp;
    assign bjp_op_jal_o   = bjp_info[`DECINFO_BJP_JUMP] && !bjp_op1_rs1;  // JAL指令标志
    assign bjp_op_jalr_o  = bjp_op1_rs1;  // JALR指令标志

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
    wire op_mem = (disp_info_grp == `DECINFO_GRP_MEM);
    wire [`DECINFO_WIDTH-1:0] mem_info = {`DECINFO_WIDTH{op_mem}} & dec_info_bus_i;

    // 这些信号不再是输出，但内部仍然需要使用
    wire mem_op_lb = mem_info[`DECINFO_MEM_LB];  // LB指令：符号位扩展的字节加载
    wire mem_op_lh = mem_info[`DECINFO_MEM_LH];  // LH指令：符号位扩展的半字加载
    wire mem_op_lw = mem_info[`DECINFO_MEM_LW];  // LW指令：加载一个字
    wire mem_op_lbu = mem_info[`DECINFO_MEM_LBU];  // LBU指令：无符号字节加载
    wire mem_op_lhu = mem_info[`DECINFO_MEM_LHU];  // LHU指令：无符号半字加载
    wire mem_op_sb = mem_info[`DECINFO_MEM_SB];  // SB指令：存储一个字节
    wire mem_op_sh = mem_info[`DECINFO_MEM_SH];  // SH指令：存储一个半字
    wire mem_op_sw = mem_info[`DECINFO_MEM_SW];  // SW指令：存储一个字
    // 新增：浮点内存操作
    wire mem_op_flw = mem_info[`DECINFO_MEM_FLW];  // FLW加载一个浮点字
    wire mem_op_fsw = mem_info[`DECINFO_MEM_FSW];  // FSW存储一个浮点字

    // 这些信号仍然作为输出
    assign mem_op_lb_o = mem_op_lb;
    assign mem_op_lh_o = mem_op_lh;
    assign mem_op_lw_o = mem_op_lw | mem_op_flw;  // LW和FLW都加载一个字
    assign mem_op_lbu_o = mem_op_lbu;
    assign mem_op_lhu_o = mem_op_lhu;
    assign mem_op_load_o = mem_info[`DECINFO_MEM_OP_LOAD] | mem_op_flw;  // 所有加载指令，包括FLW
    assign mem_op_store_o = mem_info[`DECINFO_MEM_OP_STORE] | mem_op_fsw;  // 所有存储指令，包括FSW

    // 内部信号，不再作为输出
    wire [31:0] mem_op1 = op_mem ? rs1_rdata_i : 32'h0;  // 基地址 (rs1)
    wire [31:0] mem_op2 = op_mem ? dec_imm_i : 32'h0;  // 偏移量 (立即数)
    wire [31:0] mem_rs2_data = op_mem ? rs2_rdata_i : 32'h0;  // 存储指令的数据 (rs2)

    assign req_mem_o = op_mem;

    // 直接计算内存地址
    wire [31:0] mem_addr = rs1_rdata_i + dec_imm_i;
    wire [ 1:0] mem_addr_index = mem_addr[1:0];  // 地址低两位用于字节选择
    wire        valid_op = op_mem;  // 仅在内存操作有效时计算

    // 存储操作的掩码和数据计算
    // 字节存储掩码和数据
    wire [ 3:0] sb_mask;
    wire [31:0] sb_data;

    assign sb_mask = ({4{mem_addr_index == 2'b00}} & 4'b0001) |
                     ({4{mem_addr_index == 2'b01}} & 4'b0010) |
                     ({4{mem_addr_index == 2'b10}} & 4'b0100) |
                     ({4{mem_addr_index == 2'b11}} & 4'b1000);

    assign sb_data = ({32{mem_addr_index == 2'b00}} & {24'b0, rs2_rdata_i[7:0]}) |
                     ({32{mem_addr_index == 2'b01}} & {16'b0, rs2_rdata_i[7:0], 8'b0}) |
                     ({32{mem_addr_index == 2'b10}} & {8'b0, rs2_rdata_i[7:0], 16'b0}) |
                     ({32{mem_addr_index == 2'b11}} & {rs2_rdata_i[7:0], 24'b0});

    // 半字存储掩码和数据
    wire [ 3:0] sh_mask;
    wire [31:0] sh_data;

    assign sh_mask = ({4{mem_addr_index[1] == 1'b0}} & 4'b0011) | 
                     ({4{mem_addr_index[1] == 1'b1}} & 4'b1100);

    assign sh_data = ({32{mem_addr_index[1] == 1'b0}} & {16'b0, rs2_rdata_i[15:0]}) |
                     ({32{mem_addr_index[1] == 1'b1}} & {rs2_rdata_i[15:0], 16'b0});

    // 字存储掩码和数据
    wire [ 3:0] sw_mask;
    wire [31:0] sw_data;

    assign sw_mask = 4'b1111;
    assign sw_data = rs2_rdata_i;

    // 浮点字存储掩码和数据 (FSW指令)
    wire [ 3:0] fsw_mask;
    wire [31:0] fsw_data;

    assign fsw_mask = 4'b1111;  // FSW也是32位字存储
    assign fsw_data = frs2_rdata_i;  // 使用浮点寄存器数据

    // 并行选择最终的存储掩码和数据
    wire [ 3:0] mem_wmask;
    wire [31:0] mem_wdata;

    assign mem_wmask = ({4{valid_op & mem_op_sb}} & sb_mask) |
                       ({4{valid_op & mem_op_sh}} & sh_mask) |
                       ({4{valid_op & mem_op_sw}} & sw_mask) |
                       ({4{valid_op & mem_op_fsw}} & fsw_mask);

    assign mem_wdata = ({32{valid_op & mem_op_sb}} & sb_data) |
                       ({32{valid_op & mem_op_sh}} & sh_data) |
                       ({32{valid_op & mem_op_sw}} & sw_data) |
                       ({32{valid_op & mem_op_fsw}} & fsw_data);

    // 输出计算结果
    assign mem_addr_o = mem_addr;
    assign mem_wmask_o = mem_wmask;
    assign mem_wdata_o = mem_wdata;

    // 地址对齐检测逻辑
    wire is_word_access = mem_op_lw | mem_op_sw | mem_op_flw | mem_op_fsw;  // lw/sw/flw/fsw
    wire is_half_access = mem_op_lh | mem_op_lhu | mem_op_sh;  // lh/lhu/sh
    wire is_byte_access = mem_op_lb | mem_op_lbu | mem_op_sb;  // lb/lbu/sb

    // load对齐检测 (包括浮点加载)
    assign misaligned_load_o  = mem_op_load_o  & (
        ((mem_op_lw | mem_op_flw) && (mem_addr[1:0] != 2'b00)) ||
        ((mem_op_lh | mem_op_lhu) && (mem_addr[0] != 1'b0))
    );

    // store对齐检测 (包括浮点存储)
    assign misaligned_store_o = mem_op_store_o & (
        ((mem_op_sw | mem_op_fsw) && (mem_addr[1:0] != 2'b00)) ||
        (mem_op_sh && (mem_addr[0] != 1'b0))
    );

    // SYS info

    wire                      op_sys = (disp_info_grp == `DECINFO_GRP_SYS);
    wire [`DECINFO_WIDTH-1:0] sys_info = {`DECINFO_WIDTH{op_sys}} & dec_info_bus_i;
    assign sys_op_nop_o    = sys_info[`DECINFO_SYS_NOP];  // NOP指令
    assign sys_op_mret_o   = sys_info[`DECINFO_SYS_MRET];  // MRET指令：从机器模式返回
    assign sys_op_ecall_o  = sys_info[`DECINFO_SYS_ECALL];  // ECALL指令：环境调用
    assign sys_op_ebreak_o = sys_info[`DECINFO_SYS_EBREAK];  // EBREAK指令：断点
    assign sys_op_fence_o  = sys_info[`DECINFO_SYS_FENCE];  // FENCE指令：内存屏障
    assign sys_op_dret_o   = sys_info[`DECINFO_SYS_DRET];  // DRET指令：从调试模式返回

    // 浮点指令分组判定与信号分解
    wire op_sfpu = (disp_info_grp == `DECINFO_GRP_SFPU);
    wire [`DECINFO_SFPU_BUS_WIDTH-1:0] sfpu_info = {`DECINFO_SFPU_BUS_WIDTH{op_sfpu}} & dec_info_bus_i;

    // 浮点指令操作数类型判断
    wire fpu_op1_use_int = sfpu_info[`DECINFO_SFPU_FCVT_I2F_S] | sfpu_info[`DECINFO_SFPU_FMV_I2F_S];

    assign req_fpu_o           = op_sfpu;
    assign fpu_op_fadd_s_o     = sfpu_info[`DECINFO_SFPU_FADD_S];
    assign fpu_op_fsub_s_o     = sfpu_info[`DECINFO_SFPU_FSUB_S];
    assign fpu_op_fmul_s_o     = sfpu_info[`DECINFO_SFPU_FMUL_S];
    assign fpu_op_fdiv_s_o     = sfpu_info[`DECINFO_SFPU_FDIV_S];
    assign fpu_op_fsqrt_s_o    = sfpu_info[`DECINFO_SFPU_FSQRT_S];
    assign fpu_op_fsgnj_s_o    = sfpu_info[`DECINFO_SFPU_FSGNJ_S];
    assign fpu_op_fmax_s_o     = sfpu_info[`DECINFO_SFPU_FMAX_S];
    assign fpu_op_fcmp_s_o     = sfpu_info[`DECINFO_SFPU_FCMP_S];
    assign fpu_op_fcvt_f2i_s_o = sfpu_info[`DECINFO_SFPU_FCVT_F2I_S];
    assign fpu_op_fcvt_i2f_s_o = sfpu_info[`DECINFO_SFPU_FCVT_I2F_S];
    assign fpu_op_fmadd_s_o    = sfpu_info[`DECINFO_SFPU_FMADD_S];
    assign fpu_op_fmsub_s_o    = sfpu_info[`DECINFO_SFPU_FMSUB_S];
    assign fpu_op_fnmadd_s_o   = sfpu_info[`DECINFO_SFPU_FNMADD_S];
    assign fpu_op_fnmsub_s_o   = sfpu_info[`DECINFO_SFPU_FNMSUB_S];
    assign fpu_op_fmv_i2f_s_o  = sfpu_info[`DECINFO_SFPU_FMV_I2F_S];
    assign fpu_op_fmv_f2i_s_o  = sfpu_info[`DECINFO_SFPU_FMV_F2I_S];
    assign fpu_op_fclass_s_o   = sfpu_info[`DECINFO_SFPU_FCLASS_S];

    // 根据指令类型选择正确的操作数源
    assign fpu_op1_o           = op_sfpu ? (fpu_op1_use_int ? rs1_rdata_i : frs1_rdata_i) : 32'h0;
    assign fpu_op2_o           = op_sfpu ? frs2_rdata_i : 32'h0;
    assign fpu_op3_o           = op_sfpu ? frs3_rdata_i : 32'h0;
    assign frm_o               = op_sfpu ? sfpu_info[`DECINFO_SFPU_FRM] : 3'b000;
    assign fcvt_op_o           = op_sfpu ? sfpu_info[`DECINFO_SFPU_FCVT_OP] : 2'b00;

endmodule
