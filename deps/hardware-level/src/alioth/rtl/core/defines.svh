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

`include "config.svh"

`define ZeroWord 32'h0
`define ZeroReg 5'h0
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define JumpEnable 1'b1
`define JumpDisable 1'b0
`define HoldEnable 1'b1
`define HoldDisable 1'b0

`define INT_ASSERT 1'b1
`define INT_DEASSERT 1'b0
`define INT_BUS 7:0
`define INT_NONE 8'h0
`define INT_RET 8'hff
`define INT_TIMER0 8'b00000001
`define INT_TIMER0_ENTRY_ADDR 32'h4

`define CU_BUS_WIDTH 3
`define CU_FLUSH 0
`define CU_STALL 1
`define CU_STALL_DISPATCH 2

`define TIMESTAMP_WIDTH 32

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
// 用户级CSR地址 (User Level CSRs)
`define CSR_USTATUS 12'h000   // 用户状态寄存器
`define CSR_UIE 12'h004   // 用户中断使能寄存器
`define CSR_UTVEC 12'h005   // 用户中断向量寄存器
`define CSR_USCRATCH 12'h040   // 用户暂存寄存器
`define CSR_UEPC 12'h041   // 用户异常程序计数器
`define CSR_UCAUSE 12'h042   // 用户异常原因寄存器
`define CSR_UTVAL 12'h043   // 用户陷入值寄存器
`define CSR_UIP 12'h044   // 用户中断挂起寄存器

// 监管者级CSR地址 (Supervisor Level CSRs)
`define CSR_SSTATUS 12'h100   // 监管者状态寄存器
`define CSR_SIE 12'h104   // 监管者中断使能寄存器
`define CSR_STVEC 12'h105   // 监管者中断向量寄存器
`define CSR_SCOUNTEREN 12'h106   // 监管者计数器使能寄存器
`define CSR_SSCRATCH 12'h140   // 监管者暂存寄存器
`define CSR_SEPC 12'h141   // 监管者异常程序计数器
`define CSR_SCAUSE 12'h142   // 监管者异常原因寄存器
`define CSR_STVAL 12'h143   // 监管者陷入值寄存器
`define CSR_SIP 12'h144   // 监管者中断挂起寄存器

// 机器级CSR地址 (Machine Level CSRs)
`define CSR_MVENDORID 12'hF11   // 厂商ID寄存器
`define CSR_MARCHID 12'hF12   // 架构ID寄存器
`define CSR_MIMPID 12'hF13   // 实现ID寄存器
`define CSR_MHARTID 12'hF14   // 硬件线程ID寄存器
`define CSR_MSTATUS 12'h300   // 机器状态寄存器
`define CSR_MISA 12'h301   // ISA与扩展支持寄存器
`define CSR_MEDELEG 12'h302   // 机器异常委托寄存器
`define CSR_MIDELEG 12'h303   // 机器中断委托寄存器
`define CSR_MIE 12'h304   // 机器中断使能寄存器
`define CSR_MTVEC 12'h305   // 机器陷阱处理基地址
`define CSR_MCOUNTEREN 12'h306   // 机器计数器使能寄存器
`define CSR_MSCRATCH 12'h340   // 机器暂存寄存器
`define CSR_MEPC 12'h341   // 机器异常程序计数器
`define CSR_MCAUSE 12'h342   // 机器陷阱原因寄存器
`define CSR_MTVAL 12'h343   // 机器陷入值寄存器
`define CSR_MIP 12'h344   // 机器中断挂起寄存器

// 计数器CSR地址 (Counter CSRs)
`define CSR_TIME 12'hC01   // 时间计数器低32位
`define CSR_TIMEH 12'hC81   // 时间计数器高32位
`define CSR_CYCLE 12'hC00   // 周期计数器低32位
`define CSR_CYCLEH 12'hC80   // 周期计数器高32位

// 机器模式计数器CSR地址 (Machine Counter CSRs)
`define CSR_MCYCLE 12'hB00   // 机器模式周期计数器低32位
`define CSR_MCYCLEH 12'hB80   // 机器模式周期计数器高32位
`define CSR_MINSTRET 12'hB02   // 机器模式指令计数器低32位
`define CSR_MINSTRETH 12'hB82   // 机器模式指令计数器高32位

// 硬件性能监控计数器 (Hardware Performance Monitor Counters)
`define CSR_HPMCOUNTER3 12'hC03   // 性能计数器3低32位
`define CSR_HPMCOUNTER4 12'hC04   // 性能计数器4低32位
`define CSR_HPMCOUNTER5 12'hC05   // 性能计数器5低32位
`define CSR_HPMCOUNTER6 12'hC06   // 性能计数器6低32位
`define CSR_HPMCOUNTER3H 12'hC83   // 性能计数器3高32位
`define CSR_HPMCOUNTER4H 12'hC84   // 性能计数器4高32位
`define CSR_HPMCOUNTER5H 12'hC85   // 性能计数器5高32位
`define CSR_HPMCOUNTER6H 12'hC86   // 性能计数器6高32位

// 机器计数器设置寄存器 (Machine Counter Setup)
`define CSR_MCOUNTINHIBIT 12'h320   // 机器计数器抑制寄存器
`define CSR_MHPMEVENT3 12'h323   // 机器性能监控事件选择器3
`define CSR_MHPMEVENT4 12'h324   // 机器性能监控事件选择器4
`define CSR_MHPMEVENT5 12'h325   // 机器性能监控事件选择器5
`define CSR_MHPMEVENT6 12'h326   // 机器性能监控事件选择器6

// 调试模式CSR地址 (Debug Mode CSRs)
`define CSR_DCSR 12'h7B0   // 调试控制和状态寄存器
`define CSR_DPC 12'h7B1   // 调试程序计数器
`define CSR_DSCRATCH0 12'h7B2   // 调试暂存寄存器0
`define CSR_DSCRATCH1 12'h7B3   // 调试暂存寄存器1

// 指令译码信息
`define INST_NOP 32'h00000013
`define INST_MRET 32'h30200073
`define INST_ECALL 32'h00000073
`define INST_EBREAK 32'h00100073
`define INST_DRET 32'h7b200073
`define INST_NONE 32'h00000000


`define DECINFO_GRP_BUS 2:0
`define DECINFO_GRP_WIDTH 3
`define DECINFO_GRP_NONE `DECINFO_GRP_WIDTH'd0
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

`define DECINFO_MULDIV_BUS_WIDTH (`DECINFO_GRP_WIDTH+10)
`define DECINFO_MULDIV_MUL (`DECINFO_GRP_WIDTH+0)
`define DECINFO_MULDIV_MULH (`DECINFO_GRP_WIDTH+1)
`define DECINFO_MULDIV_MULHSU (`DECINFO_GRP_WIDTH+2)
`define DECINFO_MULDIV_MULHU (`DECINFO_GRP_WIDTH+3)
`define DECINFO_MULDIV_DIV (`DECINFO_GRP_WIDTH+4)
`define DECINFO_MULDIV_DIVU (`DECINFO_GRP_WIDTH+5)
`define DECINFO_MULDIV_REM (`DECINFO_GRP_WIDTH+6)
`define DECINFO_MULDIV_REMU (`DECINFO_GRP_WIDTH+7)
`define DECINFO_MULDIV_OP_MUL (`DECINFO_GRP_WIDTH+8)
`define DECINFO_MULDIV_OP_DIV (`DECINFO_GRP_WIDTH+9)

`define DECINFO_CSR_BUS_WIDTH (`DECINFO_GRP_WIDTH+16)
`define DECINFO_CSR_CSRRW (`DECINFO_GRP_WIDTH+0)
`define DECINFO_CSR_CSRRS (`DECINFO_GRP_WIDTH+1)
`define DECINFO_CSR_CSRRC (`DECINFO_GRP_WIDTH+2)
`define DECINFO_CSR_RS1IMM (`DECINFO_GRP_WIDTH+3)
`define DECINFO_CSR_CSRADDR `DECINFO_GRP_WIDTH+4+12-1:`DECINFO_GRP_WIDTH+4

`define DECINFO_MEM_BUS_WIDTH (`DECINFO_GRP_WIDTH+10)
`define DECINFO_MEM_LB (`DECINFO_GRP_WIDTH+0)
`define DECINFO_MEM_LH (`DECINFO_GRP_WIDTH+1)
`define DECINFO_MEM_LW (`DECINFO_GRP_WIDTH+2)
`define DECINFO_MEM_LBU (`DECINFO_GRP_WIDTH+3)
`define DECINFO_MEM_LHU (`DECINFO_GRP_WIDTH+4)
`define DECINFO_MEM_SB (`DECINFO_GRP_WIDTH+5)
`define DECINFO_MEM_SH (`DECINFO_GRP_WIDTH+6)
`define DECINFO_MEM_SW (`DECINFO_GRP_WIDTH+7)
`define DECINFO_MEM_OP_LOAD (`DECINFO_GRP_WIDTH+8)
`define DECINFO_MEM_OP_STORE (`DECINFO_GRP_WIDTH+9)

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

// ALU操作信息位定义
`define ALU_OP_WIDTH 13
`define ALU_OP_ADD 0
`define ALU_OP_SUB 1
`define ALU_OP_SLL 2
`define ALU_OP_SLT 3
`define ALU_OP_SLTU 4
`define ALU_OP_XOR 5
`define ALU_OP_SRL 6
`define ALU_OP_SRA 7
`define ALU_OP_OR 8
`define ALU_OP_AND 9
`define ALU_OP_LUI 10
`define ALU_OP_AUIPC 11
`define ALU_OP_JUMP 12

// CPU字长和指令集扩展定义
// CPU字长定义
`define MISA_MXL_32 2'b01      // 32位CPU
`define MISA_MXL_64 2'b10      // 64位CPU
`define MISA_MXL_128 2'b11      // 128位CPU

// 当前CPU字长
`define MISA_MXL `MISA_MXL_32

// 指令集扩展位定义
`define MISA_A_SUPPORT 1'b0  // 原子指令扩展
`define MISA_B_SUPPORT 1'b0  // 保留
`define MISA_C_SUPPORT 1'b0  // 压缩指令扩展
`define MISA_D_SUPPORT 1'b0  // 双精度浮点扩展
`define MISA_E_SUPPORT 1'b0  // RV32E基础整数指令集(嵌入式)
`define MISA_F_SUPPORT 1'b0  // 单精度浮点扩展
`define MISA_G_SUPPORT 1'b0  // 保留
`define MISA_H_SUPPORT 1'b0  // 超级用户扩展
`define MISA_I_SUPPORT 1'b1  // 基础整数指令集
`define MISA_J_SUPPORT 1'b0  // 保留
`define MISA_K_SUPPORT 1'b0  // 保留
`define MISA_L_SUPPORT 1'b0  // 保留
`define MISA_M_SUPPORT 1'b1  // 乘法除法扩展
`define MISA_N_SUPPORT 1'b0  // 用户级中断
`define MISA_O_SUPPORT 1'b0  // 保留
`define MISA_P_SUPPORT 1'b0  // 保留
`define MISA_Q_SUPPORT 1'b0  // 四精度浮点扩展
`define MISA_R_SUPPORT 1'b0  // 保留
`define MISA_S_SUPPORT 1'b0  // 监管者模式支持
`define MISA_T_SUPPORT 1'b0  // 保留
`define MISA_U_SUPPORT 1'b0  // 用户模式支持
`define MISA_V_SUPPORT 1'b0  // 向量扩展
`define MISA_W_SUPPORT 1'b0  // 保留
`define MISA_X_SUPPORT 1'b0  // 非标准扩展
`define MISA_Y_SUPPORT 1'b0  // 保留
`define MISA_Z_SUPPORT 1'b0  // 保留

`define CLINT_AXI_DATA_WIDTH 64  // 改为64位支持总线
`define CLINT_AXI_ADDR_WIDTH 16

// CLINT寄存器地址（RISC-V官方推荐）
`define CLINT_MSIP_ADDR 16'h0000
`define CLINT_MTIMECMP_ADDR 16'h4000
`define CLINT_MTIMECMP_ADDR_H 16'h4004
`define CLINT_MTIME_ADDR 16'hBFF8
`define CLINT_MTIME_ADDR_H 16'hBFFC

`define PLIC_AXI_DATA_WIDTH 64  // 改为64位支持总线
`define PLIC_AXI_ADDR_WIDTH 16
`define PLIC_INT_EN_ADDR 16'h0000
`define PLIC_INT_MVEC_ADDR 16'h0100
`define PLIC_INT_MARG_ADDR 16'h0104
`define PLIC_INT_PRI_ADDR 16'h1000
`define PLIC_INT_VECTABLE_ADDR 16'h2000
`define PLIC_INT_OBJS_ADDR 16'h3000
`define PLIC_NUM_SOURCES 11
