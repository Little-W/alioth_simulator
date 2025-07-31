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

    // dispatch to ADDER
    output wire        req_adder_o,
    output wire [31:0] adder_op1_o,
    output wire [31:0] adder_op2_o,
    output wire [6:0]  adder_op_info_o,  // {op_jump, op_sltu, op_slt, op_sub, op_add, op_lui, op_auipc}

    // dispatch to SHIFTER
    output wire        req_shifter_o,
    output wire [31:0] shifter_op1_o,
    output wire [31:0] shifter_op2_o,
    output wire [5:0]  shifter_op_info_o,  // {op_and, op_or, op_xor, op_sra, op_srl, op_sll}


    // dispatch to Bru
    output wire        req_bjp_o,
    output wire [31:0] bjp_op1_o,
    output wire [31:0] bjp_op2_o,
    output wire [31:0] bjp_jump_op1_o,
    output wire [31:0] bjp_jump_op2_o,
    output wire        bjp_op_jump_o,
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

    // 新增：未对齐访存异常输出
    output wire misaligned_load_o,
    output wire misaligned_store_o
);

    wire [`DECINFO_GRP_WIDTH-1:0] disp_info_grp = dec_info_bus_i[`DECINFO_GRP_BUS];

    // ALU info

    wire op_alu = (disp_info_grp == `DECINFO_GRP_ALU);
    wire [`DECINFO_WIDTH-1:0] alu_info = {`DECINFO_WIDTH{op_alu}} & dec_info_bus_i;
    
    // ALU操作分类
    wire alu_op_add = alu_info[`DECINFO_ALU_ADD];
    wire alu_op_sub = alu_info[`DECINFO_ALU_SUB];
    wire alu_op_slt = alu_info[`DECINFO_ALU_SLT];
    wire alu_op_sltu = alu_info[`DECINFO_ALU_SLTU];
    wire alu_op_sll = alu_info[`DECINFO_ALU_SLL];
    wire alu_op_srl = alu_info[`DECINFO_ALU_SRL];
    wire alu_op_sra = alu_info[`DECINFO_ALU_SRA];
    wire alu_op_and = alu_info[`DECINFO_ALU_AND];
    wire alu_op_or = alu_info[`DECINFO_ALU_OR];
    wire alu_op_xor = alu_info[`DECINFO_ALU_XOR];
    wire alu_op_lui = alu_info[`DECINFO_ALU_LUI];
    wire alu_op_auipc = alu_info[`DECINFO_ALU_AUIPC];
    
    // 加法器操作：加法、减法、比较、LUI、AUIPC
    wire op_adder = op_alu & (alu_op_add | alu_op_sub | alu_op_slt | alu_op_sltu | alu_op_lui | alu_op_auipc);
    
    // 移位器操作：左移、右移、逻辑运算
    wire op_shifter = op_alu & (alu_op_sll | alu_op_srl | alu_op_sra | alu_op_and | alu_op_or | alu_op_xor);
    
    // ALU op1
    wire alu_op1_pc = alu_info[`DECINFO_ALU_OP1PC];  // 使用PC作为操作数1 (AUIPC指令)
    wire alu_op1_zero = alu_info[`DECINFO_ALU_LUI];  // 使用0作为操作数1 (LUI指令)
    wire [31:0] alu_op1 = (alu_op1_pc | bjp_op_jump_o) ? dec_pc_i : alu_op1_zero ? 32'h0 : rs1_rdata_i;
    
    // ALU op2
    wire alu_op2_imm = alu_info[`DECINFO_ALU_OP2IMM];  // 使用立即数作为操作数2 (I型指令、LUI、AUIPC)
    wire [31:0] alu_op2 = alu_op2_imm ? dec_imm_i : rs2_rdata_i;

    // ADDER输出
    assign req_adder_o = op_adder | bjp_op_jump_o;
    assign adder_op1_o = (op_adder | bjp_op_jump_o) ? alu_op1 : 32'h0;
    assign adder_op2_o = bjp_op_jump_o ? 32'h4 : op_adder ? alu_op2 : 32'h0;
    assign adder_op_info_o = {
        bjp_op_jump_o,  // op_jump (用于JALR指令)
        alu_info[`DECINFO_ALU_SLTU],  // op_sltu
        alu_info[`DECINFO_ALU_SLT],   // op_slt
        alu_info[`DECINFO_ALU_SUB],   // op_sub
        alu_info[`DECINFO_ALU_ADD],   // op_add
        alu_info[`DECINFO_ALU_LUI],   // op_lui
        alu_info[`DECINFO_ALU_AUIPC]  // op_auipc
    };

    // SHIFTER输出
    assign req_shifter_o = op_shifter;
    assign shifter_op1_o = op_shifter ? rs1_rdata_i : 32'h0;
    assign shifter_op2_o = op_shifter ? alu_op2 : 32'h0;
    assign shifter_op_info_o = {
        alu_info[`DECINFO_ALU_AND],  // op_and
        alu_info[`DECINFO_ALU_OR],   // op_or
        alu_info[`DECINFO_ALU_XOR],  // op_xor
        alu_info[`DECINFO_ALU_SRA],  // op_sra
        alu_info[`DECINFO_ALU_SRL],  // op_srl
        alu_info[`DECINFO_ALU_SLL]   // op_sll
    };


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
    wire [`DECINFO_WIDTH-1:0] bjp_info = {`DECINFO_WIDTH{op_bjp}} & dec_info_bus_i;
    // BJP op1
    wire bjp_op1_rs1 = bjp_info[`DECINFO_BJP_OP1RS1];  // 使用rs1寄存器作为跳转基地址 (JALR指令)
    wire [31:0] bjp_op1 = bjp_op1_rs1 ? rs1_rdata_i : dec_pc_i;
    assign bjp_jump_op1_o = (sys_op_fence_o | op_bjp) ? bjp_op1 : 32'h0;
    // BJP op2
    wire [31:0] bjp_op2 = dec_imm_i;  // 使用立即数作为跳转偏移量
    assign bjp_jump_op2_o = (sys_op_fence_o) ? 32'h4 : op_bjp ? bjp_op2 : 32'h0;
    assign bjp_op1_o      = op_bjp ? rs1_rdata_i : 32'h0;  // 用于分支指令的比较操作数1
    assign bjp_op2_o      = op_bjp ? rs2_rdata_i : 32'h0;  // 用于分支指令的比较操作数2
    assign bjp_op_jump_o  = bjp_info[`DECINFO_BJP_JUMP];  // JAL/JALR指令
    assign bjp_op_beq_o   = bjp_info[`DECINFO_BJP_BEQ];  // BEQ指令
    assign bjp_op_bne_o   = bjp_info[`DECINFO_BJP_BNE];  // BNE指令
    assign bjp_op_blt_o   = bjp_info[`DECINFO_BJP_BLT];  // BLT指令
    assign bjp_op_bltu_o  = bjp_info[`DECINFO_BJP_BLTU];  // BLTU指令
    assign bjp_op_bge_o   = bjp_info[`DECINFO_BJP_BGE];  // BGE指令
    assign bjp_op_bgeu_o  = bjp_info[`DECINFO_BJP_BGEU];  // BGEU指令
    assign req_bjp_o      = op_bjp;
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

    // 这些信号仍然作为输出
    assign mem_op_lb_o    = mem_op_lb;
    assign mem_op_lh_o    = mem_op_lh;
    assign mem_op_lw_o    = mem_op_lw;
    assign mem_op_lbu_o   = mem_op_lbu;
    assign mem_op_lhu_o   = mem_op_lhu;
    assign mem_op_load_o  = mem_info[`DECINFO_MEM_OP_LOAD];  // 所有加载指令
    assign mem_op_store_o = mem_info[`DECINFO_MEM_OP_STORE];  // 所有存储指令

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

    // 并行选择最终的存储掩码和数据
    wire [ 3:0] mem_wmask;
    wire [31:0] mem_wdata;

    assign mem_wmask = ({4{valid_op & mem_op_sb}} & sb_mask) |
                       ({4{valid_op & mem_op_sh}} & sh_mask) |
                       ({4{valid_op & mem_op_sw}} & sw_mask);

    assign mem_wdata = ({32{valid_op & mem_op_sb}} & sb_data) |
                       ({32{valid_op & mem_op_sh}} & sh_data) |
                       ({32{valid_op & mem_op_sw}} & sw_data);

    // 输出计算结果
    assign mem_addr_o = mem_addr;
    assign mem_wmask_o = mem_wmask;
    assign mem_wdata_o = mem_wdata;

    // 地址对齐检测逻辑
    wire is_word_access = mem_op_lw | mem_op_sw;  // lw/sw
    wire is_half_access = mem_op_lh | mem_op_lhu | mem_op_sh;  // lh/lhu/sh
    wire is_byte_access = mem_op_lb | mem_op_lbu | mem_op_sb;  // lb/lbu/sb

    // load对齐检测
    assign misaligned_load_o  = mem_op_load_o  & (
        (mem_op_lw  && (mem_addr[1:0] != 2'b00)) ||
        ((mem_op_lh | mem_op_lhu) && (mem_addr[0] != 1'b0))
    );

    // store对齐检测
    assign misaligned_store_o = mem_op_store_o & (
        (mem_op_sw && (mem_addr[1:0] != 2'b00)) ||
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

endmodule
