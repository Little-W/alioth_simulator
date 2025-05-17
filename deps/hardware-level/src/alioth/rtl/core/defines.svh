/*                                                                      
 Copyright 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "config.svh"

`define CpuResetAddr 32'h0

`define RstEnable 1'b0
`define RstDisable 1'b1
`define ZeroWord 32'h0
`define ZeroReg 5'h0
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define True 1'b1
`define False 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define JumpEnable 1'b1
`define JumpDisable 1'b0
`define DivResultNotReady 1'b0
`define DivResultReady 1'b1
`define DivStart 1'b1
`define DivStop 1'b0
`define HoldEnable 1'b1
`define HoldDisable 1'b0
`define Stop 1'b1
`define NoStop 1'b0
`define INT_ASSERT 1'b1
`define INT_DEASSERT 1'b0

`define INT_BUS 7:0
`define INT_NONE 8'h0
`define INT_RET 8'hff
`define INT_TIMER0 8'b00000001
`define INT_TIMER0_ENTRY_ADDR 32'h4

`define Hold_Flag_Bus 2:0
`define Hold_None 3'b000
`define Hold_Pc 3'b001
`define Hold_If 3'b010
`define Hold_Id 3'b011

// I type inst
`define INST_TYPE_I 7'b0010011
`define INST_ADDI 3'b000
`define INST_SLTI 3'b010
`define INST_SLTIU 3'b011
`define INST_XORI 3'b100
`define INST_ORI 3'b110
`define INST_ANDI 3'b111
`define INST_SLLI 3'b001
`define INST_SRI 3'b101

// L type inst
`define INST_TYPE_L 7'b0000011
`define INST_LB 3'b000
`define INST_LH 3'b001
`define INST_LW 3'b010
`define INST_LBU 3'b100
`define INST_LHU 3'b101

// S type inst
`define INST_TYPE_S 7'b0100011
`define INST_SB 3'b000
`define INST_SH 3'b001
`define INST_SW 3'b010

// R and M type inst
`define INST_TYPE_R_M 7'b0110011
// R type inst
`define INST_ADD_SUB 3'b000
`define INST_SLL 3'b001
`define INST_SLT 3'b010
`define INST_SLTU 3'b011
`define INST_XOR 3'b100
`define INST_SR 3'b101
`define INST_OR 3'b110
`define INST_AND 3'b111
// M type inst
`define INST_MUL 3'b000
`define INST_MULH 3'b001
`define INST_MULHSU 3'b010
`define INST_MULHU 3'b011
`define INST_DIV 3'b100
`define INST_DIVU 3'b101
`define INST_REM 3'b110
`define INST_REMU 3'b111

// J type inst
`define INST_JAL 7'b1101111
`define INST_JALR 7'b1100111

`define INST_LUI 7'b0110111
`define INST_AUIPC 7'b0010111
`define INST_RET 32'h00008067

`define INST_FENCE 7'b0001111
// `define INST_ECALL  32'h73
// `define INST_EBREAK 32'h00100073

// J type inst
`define INST_TYPE_B 7'b1100011
`define INST_BEQ 3'b000
`define INST_BNE 3'b001
`define INST_BLT 3'b100
`define INST_BGE 3'b101
`define INST_BLTU 3'b110
`define INST_BGEU 3'b111

// CSR inst
`define INST_CSR 7'b1110011
`define INST_CSRRW 3'b001
`define INST_CSRRS 3'b010
`define INST_CSRRC 3'b011
`define INST_CSRRWI 3'b101
`define INST_CSRRSI 3'b110
`define INST_CSRRCI 3'b111

// CSR reg addr
`define CSR_CYCLE 12'hc00
`define CSR_CYCLEH 12'hc80
`define CSR_MTVEC 12'h305
`define CSR_MCAUSE 12'h342
`define CSR_MEPC 12'h341
`define CSR_MIE 12'h304
`define CSR_MSTATUS 12'h300
`define CSR_MSCRATCH 12'h340


// 指令译码信息
`define INST_NOP 32'h00000013
`define INST_MRET 32'h30200073
`define INST_ECALL 32'h00000073
`define INST_EBREAK 32'h00100073
`define INST_DRET 32'h7b200073


`define DECINFO_GRP_BUS 2:0
`define DECINFO_GRP_WIDTH 3
`define DECINFO_GRP_ALU `DECINFO_GRP_WIDTH'd1
`define DECINFO_GRP_BJP `DECINFO_GRP_WIDTH'd2
`define DECINFO_GRP_MULDIV `DECINFO_GRP_WIDTH'd3
`define DECINFO_GRP_CSR `DECINFO_GRP_WIDTH'd4
`define DECINFO_GRP_MEM `DECINFO_GRP_WIDTH'd5
`define DECINFO_GRP_SYS `DECINFO_GRP_WIDTH'd6

`define DECINFO_ALU_BUS_WIDTH (`DECINFO_GRP_WIDTH+14)
`define DECINFO_ALU_LUI (`DECINFO_GRP_WIDTH+0)
`define DECINFO_ALU_AUIPC (`DECINFO_GRP_WIDTH+1)
`define DECINFO_ALU_ADD (`DECINFO_GRP_WIDTH+2)
`define DECINFO_ALU_SUB (`DECINFO_GRP_WIDTH+3)
`define DECINFO_ALU_SLL (`DECINFO_GRP_WIDTH+4)
`define DECINFO_ALU_SLT (`DECINFO_GRP_WIDTH+5)
`define DECINFO_ALU_SLTU (`DECINFO_GRP_WIDTH+6)
`define DECINFO_ALU_XOR (`DECINFO_GRP_WIDTH+7)
`define DECINFO_ALU_SRL (`DECINFO_GRP_WIDTH+8)
`define DECINFO_ALU_SRA (`DECINFO_GRP_WIDTH+9)
`define DECINFO_ALU_OR (`DECINFO_GRP_WIDTH+10)
`define DECINFO_ALU_AND (`DECINFO_GRP_WIDTH+11)
`define DECINFO_ALU_OP2IMM (`DECINFO_GRP_WIDTH+12)
`define DECINFO_ALU_OP1PC (`DECINFO_GRP_WIDTH+13)

`define DECINFO_BJP_BUS_WIDTH (`DECINFO_GRP_WIDTH+8)
`define DECINFO_BJP_JUMP (`DECINFO_GRP_WIDTH+0)
`define DECINFO_BJP_BEQ (`DECINFO_GRP_WIDTH+1)
`define DECINFO_BJP_BNE (`DECINFO_GRP_WIDTH+2)
`define DECINFO_BJP_BLT (`DECINFO_GRP_WIDTH+3)
`define DECINFO_BJP_BGE (`DECINFO_GRP_WIDTH+4)
`define DECINFO_BJP_BLTU (`DECINFO_GRP_WIDTH+5)
`define DECINFO_BJP_BGEU (`DECINFO_GRP_WIDTH+6)
`define DECINFO_BJP_OP1RS1 (`DECINFO_GRP_WIDTH+7)

`define DECINFO_MULDIV_BUS_WIDTH (`DECINFO_GRP_WIDTH+10) // 增加两位宽度
`define DECINFO_MULDIV_MUL (`DECINFO_GRP_WIDTH+0)
`define DECINFO_MULDIV_MULH (`DECINFO_GRP_WIDTH+1)
`define DECINFO_MULDIV_MULHSU (`DECINFO_GRP_WIDTH+2)
`define DECINFO_MULDIV_MULHU (`DECINFO_GRP_WIDTH+3)
`define DECINFO_MULDIV_DIV (`DECINFO_GRP_WIDTH+4)
`define DECINFO_MULDIV_DIVU (`DECINFO_GRP_WIDTH+5)
`define DECINFO_MULDIV_REM (`DECINFO_GRP_WIDTH+6)
`define DECINFO_MULDIV_REMU (`DECINFO_GRP_WIDTH+7)
`define DECINFO_MULDIV_OP_MUL (`DECINFO_GRP_WIDTH+8)  // 所有乘法指令的总信号
`define DECINFO_MULDIV_OP_DIV (`DECINFO_GRP_WIDTH+9)  // 所有除法指令的总信号

`define DECINFO_CSR_BUS_WIDTH (`DECINFO_GRP_WIDTH+16)
`define DECINFO_CSR_CSRRW (`DECINFO_GRP_WIDTH+0)
`define DECINFO_CSR_CSRRS (`DECINFO_GRP_WIDTH+1)
`define DECINFO_CSR_CSRRC (`DECINFO_GRP_WIDTH+2)
`define DECINFO_CSR_RS1IMM (`DECINFO_GRP_WIDTH+3)
`define DECINFO_CSR_CSRADDR `DECINFO_GRP_WIDTH+4+12-1:`DECINFO_GRP_WIDTH+4

`define DECINFO_MEM_BUS_WIDTH (`DECINFO_GRP_WIDTH+10) // 增加宽度以容纳新的信号
`define DECINFO_MEM_LB (`DECINFO_GRP_WIDTH+0)
`define DECINFO_MEM_LH (`DECINFO_GRP_WIDTH+1)
`define DECINFO_MEM_LW (`DECINFO_GRP_WIDTH+2)
`define DECINFO_MEM_LBU (`DECINFO_GRP_WIDTH+3)
`define DECINFO_MEM_LHU (`DECINFO_GRP_WIDTH+4)
`define DECINFO_MEM_SB (`DECINFO_GRP_WIDTH+5)
`define DECINFO_MEM_SH (`DECINFO_GRP_WIDTH+6)
`define DECINFO_MEM_SW (`DECINFO_GRP_WIDTH+7)
`define DECINFO_MEM_OP_LOAD (`DECINFO_GRP_WIDTH+8)  // 所有加载指令的总信号
`define DECINFO_MEM_OP_STORE (`DECINFO_GRP_WIDTH+9) // 所有存储指令的总信号

`define DECINFO_SYS_BUS_WIDTH (`DECINFO_GRP_WIDTH+6)
`define DECINFO_SYS_ECALL (`DECINFO_GRP_WIDTH+0)
`define DECINFO_SYS_EBREAK (`DECINFO_GRP_WIDTH+1)
`define DECINFO_SYS_NOP (`DECINFO_GRP_WIDTH+2)
`define DECINFO_SYS_MRET (`DECINFO_GRP_WIDTH+3)
`define DECINFO_SYS_FENCE (`DECINFO_GRP_WIDTH+4)
`define DECINFO_SYS_DRET (`DECINFO_GRP_WIDTH+5)

// 最长的那组
`define DECINFO_WIDTH `DECINFO_CSR_BUS_WIDTH

//exu_alu的数据通路
`define DATAPATH_MUX_WIDTH (32+32+16)
