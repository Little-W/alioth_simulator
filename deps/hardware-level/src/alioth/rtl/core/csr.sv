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

// CSR寄存器模块
module csr (

        input wire clk,
        input wire rst_n,

        // form ex
        input wire                       we_i,     // ex模块写寄存器标志
        input wire [`BUS_ADDR_WIDTH-1:0] raddr_i,  // ex模块读寄存器地址
        input wire [`BUS_ADDR_WIDTH-1:0] waddr_i,  // ex模块写寄存器地址
        input wire [`REG_DATA_WIDTH-1:0] data_i,   // ex模块写寄存器数据

        // from clint
        input wire                       clint_we_i,     // clint模块写寄存器标志
        input wire [`BUS_ADDR_WIDTH-1:0] clint_raddr_i,  // clint模块读寄存器地址
        input wire [`BUS_ADDR_WIDTH-1:0] clint_waddr_i,  // clint模块写寄存器地址
        input wire [`REG_DATA_WIDTH-1:0] clint_data_i,   // clint模块写寄存器数据

        input wire inst_valid_i,  // 指令有效信号

        output wire global_int_en_o,  // 全局中断使能标志

        // to clint
        output wire [`REG_DATA_WIDTH-1:0] clint_data_o,      // clint模块读寄存器数据
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mtvec,   // mtvec
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mepc,    // mepc
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mstatus, // mstatus
        // 新增输出to clint
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mie,     // mie寄存器

        // to ex
        output wire [`REG_DATA_WIDTH-1:0] data_o  // ex模块读寄存器数据

        // to clint
        output wire [`REG_DATA_WIDTH-1:0] clint_data_o,      // clint模块读寄存器数据
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mtvec,   // mtvec
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mepc,    // mepc
        output wire [`REG_DATA_WIDTH-1:0] clint_csr_mstatus, // mstatus

        // to ex
        output wire [`REG_DATA_WIDTH-1:0] data_o  // ex模块读寄存器数据

    );

    // 基本CSR寄存器
    wire [`DOUBLE_REG_WIDTH-1:0] mcycle;  // 改名为mcycle
    wire [`REG_DATA_WIDTH-1:0] mtvec;
    wire [`REG_DATA_WIDTH-1:0] mcause;
    wire [`REG_DATA_WIDTH-1:0] mepc;
    wire [`REG_DATA_WIDTH-1:0] mie;
    wire [`REG_DATA_WIDTH-1:0] mstatus;
    wire [`REG_DATA_WIDTH-1:0] mscratch;

    // 机器模式CSR寄存器
    wire [`REG_DATA_WIDTH-1:0] mvendorid;  // 供应商ID寄存器
    wire [`REG_DATA_WIDTH-1:0] marchid;  // 架构ID寄存器
    wire [`REG_DATA_WIDTH-1:0] mimpid;  // 实现ID寄存器
    wire [`REG_DATA_WIDTH-1:0] mhartid;  // 硬件线程ID寄存器
    // misa为只读寄存器，由宏定义配置
    wire [`REG_DATA_WIDTH-1:0] misa = {
             `MISA_MXL,
             4'b0,
             `MISA_Z_SUPPORT,
             `MISA_Y_SUPPORT,
             `MISA_X_SUPPORT,
             `MISA_W_SUPPORT,
             `MISA_V_SUPPORT,
             `MISA_U_SUPPORT,
             `MISA_T_SUPPORT,
             `MISA_S_SUPPORT,
             `MISA_R_SUPPORT,
             `MISA_Q_SUPPORT,
             `MISA_P_SUPPORT,
             `MISA_O_SUPPORT,
             `MISA_N_SUPPORT,
             `MISA_M_SUPPORT,
             `MISA_L_SUPPORT,
             `MISA_K_SUPPORT,
             `MISA_J_SUPPORT,
             `MISA_I_SUPPORT,
             `MISA_H_SUPPORT,
             `MISA_G_SUPPORT,
             `MISA_F_SUPPORT,
             `MISA_E_SUPPORT,
             `MISA_D_SUPPORT,
             `MISA_C_SUPPORT,
             `MISA_B_SUPPORT,
             `MISA_A_SUPPORT
         };  // ISA和扩展支持寄存器
    wire [`REG_DATA_WIDTH-1:0] medeleg;  // 机器异常委托寄存器
    wire [`REG_DATA_WIDTH-1:0] mideleg;  // 机器中断委托寄存器
    wire [`REG_DATA_WIDTH-1:0] mip;  // 待处理中断寄存器
    wire [`REG_DATA_WIDTH-1:0] mtval;  // 陷阱值寄存器
    wire [`REG_DATA_WIDTH-1:0] mcounteren;  // 计数器使能寄存器

    // 性能计数器
    wire [`DOUBLE_REG_WIDTH-1:0] minstret;  // 改名为minstret
    wire [`DOUBLE_REG_WIDTH-1:0] time_val;  // 实时时钟

    // 硬件性能监控计数器
    wire [`REG_DATA_WIDTH-1:0] hpmcounter3;
    wire [`REG_DATA_WIDTH-1:0] hpmcounter4;
    wire [`REG_DATA_WIDTH-1:0] hpmcounter5;
    wire [`REG_DATA_WIDTH-1:0] hpmcounter6;

    // 内部寄存器的值更新信号
    wire [`REG_DATA_WIDTH-1:0] mtvec_next;
    wire [`REG_DATA_WIDTH-1:0] mcause_next;
    wire [`REG_DATA_WIDTH-1:0] mepc_next;
    wire [`REG_DATA_WIDTH-1:0] mie_next;
    wire [`REG_DATA_WIDTH-1:0] mstatus_next;
    wire [`REG_DATA_WIDTH-1:0] mscratch_next;
    wire [`DOUBLE_REG_WIDTH-1:0] mcycle_next;  // 改名为mcycle_next

    // 机器模式
    wire [`REG_DATA_WIDTH-1:0] mvendorid_next;
    wire [`REG_DATA_WIDTH-1:0] marchid_next;
    wire [`REG_DATA_WIDTH-1:0] mimpid_next;
    wire [`REG_DATA_WIDTH-1:0] mhartid_next;
    // 移除misa_next因为misa是只读的
    wire [`REG_DATA_WIDTH-1:0] medeleg_next;
    wire [`REG_DATA_WIDTH-1:0] mideleg_next;
    wire [`REG_DATA_WIDTH-1:0] mip_next;
    wire [`REG_DATA_WIDTH-1:0] mtval_next;
    wire [`REG_DATA_WIDTH-1:0] mcounteren_next;

    // 性能计数器
    wire [`DOUBLE_REG_WIDTH-1:0] minstret_next;  // 改名为minstret_next
    wire [`DOUBLE_REG_WIDTH-1:0] time_next;

    // 硬件性能监控计数器
    wire [`REG_DATA_WIDTH-1:0] hpmcounter3_next;
    wire [`REG_DATA_WIDTH-1:0] hpmcounter4_next;
    wire [`REG_DATA_WIDTH-1:0] hpmcounter5_next;
    wire [`REG_DATA_WIDTH-1:0] hpmcounter6_next;

    // 寄存器写使能信号

    // 机器模式
    wire mtvec_we;
    wire mcause_we;
    wire mepc_we;
    wire mie_we;
    wire mstatus_we;
    wire mscratch_we;
    wire mvendorid_we;
    wire marchid_we;
    wire mimpid_we;
    wire mhartid_we;
    wire medeleg_we;
    wire mideleg_we;
    wire mip_we;
    wire mtval_we;
    wire mcounteren_we;

    // 性能计数器
    wire mcycle_we;
    wire mcycleh_we;
    wire minstret_we;
    wire minstreth_we;

    // 硬件性能监控计数器
    wire hpmcounter3_we;
    wire hpmcounter4_we;
    wire hpmcounter5_we;
    wire hpmcounter6_we;

    assign global_int_en_o = (mstatus[3] == 1'b1) ? 1'b1 : 1'b0;

    assign clint_csr_mtvec = mtvec;
    assign clint_csr_mepc = mepc;
    assign clint_csr_mstatus = mstatus;
    <<<<<<< Updated upstream
     =======

     //新增输出
     assign clint_csr_mie = mie;  // mie寄存器
    >>>>>>> Stashed changes

     // mcycle counter
     // 复位撤销后就一直计数，但现在还要考虑写操作
     assign mcycle_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MCYCLE) ||
     (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MCYCLE);
    assign mcycleh_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MCYCLEH) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MCYCLEH);

    // 如果有写操作，则更新对应的值，否则自增
    assign mcycle_next = mcycle_we ? {mcycle[63:32], (we_i == `WriteEnable ? data_i : clint_data_i)} :
           mcycleh_we ? {(we_i == `WriteEnable ? data_i : clint_data_i), mcycle[31:0]} :
           mcycle + 1'b1;

    // 指令完成计数器，可写入
    assign minstret_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MINSTRET) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MINSTRET);
    assign minstreth_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MINSTRETH) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MINSTRETH);

    // 如果有写操作，则更新对应的值，否则根据指令有效判断是否自增
    assign minstret_next = minstret_we ? {minstret[63:32], (we_i == `WriteEnable ? data_i : clint_data_i)} :
           minstreth_we ? {(we_i == `WriteEnable ? data_i : clint_data_i), minstret[31:0]} :
           inst_valid_i ? minstret + 1'b1 : minstret;

    // 实时时钟，每个周期自增
    assign time_next = time_val + 1'b1;

    gnrl_dff #(
                 .DW(`DOUBLE_REG_WIDTH)
             ) mcycle_dff (
                 .clk  (clk),
                 .rst_n(rst_n),
                 .dnxt (mcycle_next),
                 .qout (mcycle)
             );

    gnrl_dff #(
                 .DW(`DOUBLE_REG_WIDTH)
             ) minstret_dff (
                 .clk  (clk),
                 .rst_n(rst_n),
                 .dnxt (minstret_next),
                 .qout (minstret)
             );

    gnrl_dff #(
                 .DW(`DOUBLE_REG_WIDTH)
             ) time_dff (
                 .clk  (clk),
                 .rst_n(rst_n),
                 .dnxt (time_next),
                 .qout (time_val)
             );

    // 计算寄存器写使能信号和下一个值
    // 优先响应ex模块的写操作，其次是clint模块

    // 机器模式
    assign mtvec_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MTVEC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MTVEC);
    assign mtvec_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MTVEC) ? data_i : clint_data_i;

    assign mcause_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MCAUSE) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MCAUSE);
    assign mcause_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MCAUSE) ? data_i : clint_data_i;

    assign mepc_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MEPC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MEPC);
    assign mepc_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MEPC) ? data_i : clint_data_i;

    assign mie_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIE) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MIE);
    assign mie_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIE) ? data_i : clint_data_i;

    assign mstatus_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MSTATUS) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MSTATUS);
    assign mstatus_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MSTATUS) ? data_i : clint_data_i;

    assign mscratch_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MSCRATCH) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MSCRATCH);
    assign mscratch_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MSCRATCH) ? data_i : clint_data_i;

    assign mvendorid_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MVENDORID) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MVENDORID);
    assign mvendorid_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MVENDORID) ? data_i : clint_data_i;

    assign marchid_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MARCHID) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MARCHID);
    assign marchid_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MARCHID) ? data_i : clint_data_i;

    assign mimpid_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIMPID) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MIMPID);
    assign mimpid_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIMPID) ? data_i : clint_data_i;

    assign mhartid_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MHARTID) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MHARTID);
    assign mhartid_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MHARTID) ? data_i : clint_data_i;

    assign medeleg_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MEDELEG) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MEDELEG);
    assign medeleg_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MEDELEG) ? data_i : clint_data_i;

    assign mideleg_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIDELEG) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MIDELEG);
    assign mideleg_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIDELEG) ? data_i : clint_data_i;

    assign mip_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIP) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MIP);
    assign mip_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MIP) ? data_i : clint_data_i;

    assign mtval_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MTVAL) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MTVAL);
    assign mtval_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MTVAL) ? data_i : clint_data_i;

    assign mcounteren_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MCOUNTEREN) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_MCOUNTEREN);
    assign mcounteren_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_MCOUNTEREN) ? data_i : clint_data_i;



    //调试模式
    assign dpc_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DPC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_DPC);
    assign dpc_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DPC) ? data_i : clint_data_i;

    assign dcsr_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DCSR) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_DCSR);
    assign dcsr_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DCSR) ? data_i : clint_data_i;

    assign dscratch0_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DSCRATCH0) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_DSCRATCH0);
    assign dscratch0_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DSCRATCH0) ? data_i : clint_data_i;

    assign dscratch1_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_DSCRATCH1) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_DSCRATCH1);
    // 监管者模式
    assign sstatus_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SSTATUS) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SSTATUS);
    assign sstatus_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SSTATUS) ? data_i : clint_data_i;

    assign sie_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SIE) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SIE);
    assign sie_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SIE) ? data_i : clint_data_i;

    assign stvec_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_STVEC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_STVEC);
    assign stvec_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_STVEC) ? data_i : clint_data_i;

    assign scounteren_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SCOUNTEREN) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SCOUNTEREN);
    assign scounteren_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SCOUNTEREN) ? data_i : clint_data_i;

    assign sscratch_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SSCRATCH) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SSCRATCH);
    assign sscratch_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SSCRATCH) ? data_i : clint_data_i;

    assign sepc_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SEPC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SEPC);
    assign sepc_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SEPC) ? data_i : clint_data_i;

    assign scause_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SCAUSE) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SCAUSE);
    assign scause_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SCAUSE) ? data_i : clint_data_i;

    assign stval_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_STVAL) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_STVAL);
    assign stval_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_STVAL) ? data_i : clint_data_i;

    assign sip_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SIP) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_SIP);
    assign sip_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_SIP) ? data_i : clint_data_i;

    // 用户模式
    assign ustatus_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_USTATUS) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_USTATUS);
    assign ustatus_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_USTATUS) ? data_i : clint_data_i;

    assign uie_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UIE) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_UIE);
    assign uie_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UIE) ? data_i : clint_data_i;

    assign utvec_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UTVEC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_UTVEC);
    assign utvec_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UTVEC) ? data_i : clint_data_i;

    assign uscratch_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_USCRATCH) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_USCRATCH);
    assign uscratch_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_USCRATCH) ? data_i : clint_data_i;

    assign uepc_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UEPC) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_UEPC);
    assign uepc_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UEPC) ? data_i : clint_data_i;

    assign ucause_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UCAUSE) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_UCAUSE);
    assign ucause_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UCAUSE) ? data_i : clint_data_i;

    assign utval_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UTVAL) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_UTVAL);
    assign utval_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UTVAL) ? data_i : clint_data_i;

    assign uip_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UIP) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_UIP);
    assign uip_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_UIP) ? data_i : clint_data_i;


    // 硬件性能监控计数器
    assign hpmcounter3_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER3) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_HPMCOUNTER3);
    assign hpmcounter3_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER3) ? data_i : clint_data_i;

    assign hpmcounter4_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER4) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_HPMCOUNTER4);
    assign hpmcounter4_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER4) ? data_i : clint_data_i;

    assign hpmcounter5_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER5) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_HPMCOUNTER5);
    assign hpmcounter5_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER5) ? data_i : clint_data_i;

    assign hpmcounter6_we = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER6) ||
           (clint_we_i == `WriteEnable && clint_waddr_i[11:0] == `CSR_HPMCOUNTER6);
    assign hpmcounter6_next = (we_i == `WriteEnable && waddr_i[11:0] == `CSR_HPMCOUNTER6) ? data_i : clint_data_i;

    // 原有寄存器
    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mtvec_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mtvec_we),
                   .dnxt (mtvec_next),
                   .qout (mtvec)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mcause_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mcause_we),
                   .dnxt (mcause_next),
                   .qout (mcause)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mepc_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mepc_we),
                   .dnxt (mepc_next),
                   .qout (mepc)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mie_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mie_we),
                   .dnxt (mie_next),
                   .qout (mie)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mstatus_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mstatus_we),
                   .dnxt (mstatus_next),
                   .qout (mstatus)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mscratch_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mscratch_we),
                   .dnxt (mscratch_next),
                   .qout (mscratch)
               );

    // 新增寄存器的D触发器实例
    // 机器模式
    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mvendorid_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mvendorid_we),
                   .dnxt (mvendorid_next),
                   .qout (mvendorid)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) marchid_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (marchid_we),
                   .dnxt (marchid_next),
                   .qout (marchid)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mimpid_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mimpid_we),
                   .dnxt (mimpid_next),
                   .qout (mimpid)
               );

    gnrl_dfflr #(

                   .DW(`REG_DATA_WIDTH)
               ) mhartid_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mhartid_we),
                   .dnxt (mhartid_next),
                   .qout (mhartid)
               );

    gnrl_dfflr #(
                   .DW(`REG_DATA_WIDTH)
               ) mideleg_dfflr (
                   .clk  (clk),
                   .rst_n(rst_n),
                   .lden (mideleg_we),
                   .dnxt (mideleg_next),
                   .qout (mideleg)
               );

    .DW(`REG_DATA_WIDTH)
       ) mip_dfflr (
           .clk  (clk),
           .rst_n(rst_n),
           .lden (mip_we),
           .dnxt (mip_next),
           .qout (mip)
       );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) mtval_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mtval_we),
        .dnxt (mtval_next),
        .qout (mtval)
    );

    gnrl_dfflr #(

        .DW(`REG_DATA_WIDTH)
    ) mcounteren_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mcounteren_we),
        .dnxt (mcounteren_next),
        .qout (mcounteren)
    );


    // 硬件性能监控计数器
    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) hpmcounter3_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (hpmcounter3_we),
        .dnxt (hpmcounter3_next),
        .qout (hpmcounter3)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) hpmcounter4_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (hpmcounter4_we),
        .dnxt (hpmcounter4_next),
        .qout (hpmcounter4)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) hpmcounter5_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (hpmcounter5_we),
        .dnxt (hpmcounter5_next),
        .qout (hpmcounter5)
    );

    gnrl_dfflr #(

        .DW(`REG_DATA_WIDTH)
    ) hpmcounter6_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (hpmcounter6_we),
        .dnxt (hpmcounter6_next),
        .qout (hpmcounter6)
    );

    // ex模块读CSR寄存器
    assign data_o = ((waddr_i[11:0] == raddr_i[11:0]) && (we_i == `WriteEnable)) ? data_i :
    // 更新性能计数器读取的CSR地址名称
    (raddr_i[11:0] == `CSR_MCYCLE || raddr_i[11:0] == `CSR_MCYCLE) ? mcycle[31:0] :
    (raddr_i[11:0] == `CSR_MCYCLEH || raddr_i[11:0] == `CSR_MCYCLEH) ? mcycle[63:32] :
    (raddr_i[11:0] == `CSR_MINSTRET || raddr_i[11:0] == `CSR_MINSTRET) ? minstret[31:0] :
    (raddr_i[11:0] == `CSR_MINSTRETH || raddr_i[11:0] == `CSR_MINSTRETH) ? minstret[63:32] :
    (raddr_i[11:0] == `CSR_MTVEC) ? mtvec :
    (raddr_i[11:0] == `CSR_MCAUSE) ? mcause :
    (raddr_i[11:0] == `CSR_MEPC) ? mepc :
    (raddr_i[11:0] == `CSR_MIE) ? mie :
    (raddr_i[11:0] == `CSR_MSTATUS) ? mstatus :
    (raddr_i[11:0] == `CSR_MSCRATCH) ? mscratch :
    // 机器模式寄存器
    (raddr_i[11:0] == `CSR_MVENDORID) ? mvendorid :
    (raddr_i[11:0] == `CSR_MARCHID) ? marchid :
    (raddr_i[11:0] == `CSR_MIMPID) ? mimpid :
    (raddr_i[11:0] == `CSR_MHARTID) ? mhartid :
    (raddr_i[11:0] == `CSR_MISA) ? misa :
    (raddr_i[11:0] == `CSR_MEDELEG) ? medeleg :
    (raddr_i[11:0] == `CSR_MIDELEG) ? mideleg :
    (raddr_i[11:0] == `CSR_MIP) ? mip :
    (raddr_i[11:0] == `CSR_MTVAL) ? mtval :
    (raddr_i[11:0] == `CSR_MCOUNTEREN) ? mcounteren :
    // 性能计数器
    (raddr_i[11:0] == `CSR_TIME) ? time_val[31:0] :
    (raddr_i[11:0] == `CSR_TIMEH) ? time_val[63:32] :
    (raddr_i[11:0] == `CSR_MINSTRET) ? minstret[31:0] :
    (raddr_i[11:0] == `CSR_MINSTRETH) ? minstret[63:32] :
    // 硬件性能监控计数器
    (raddr_i[11:0] == `CSR_HPMCOUNTER3) ? hpmcounter3 :
    (raddr_i[11:0] == `CSR_HPMCOUNTER4) ? hpmcounter4 :
    (raddr_i[11:0] == `CSR_HPMCOUNTER5) ? hpmcounter5 :
    (raddr_i[11:0] == `CSR_HPMCOUNTER6) ? hpmcounter6 :
    `ZeroWord;

    // clint模块读CSR寄存器
    assign clint_data_o = ((clint_waddr_i[11:0] == clint_raddr_i[11:0]) && (clint_we_i == `WriteEnable)) ? clint_data_i :
    // 更新性能计数器读取的CSR地址名称
    (clint_raddr_i[11:0] == `CSR_MCYCLE || clint_raddr_i[11:0] == `CSR_MCYCLE) ? mcycle[31:0] :
    (clint_raddr_i[11:0] == `CSR_MCYCLEH || clint_raddr_i[11:0] == `CSR_MCYCLEH) ? mcycle[63:32] :
    (clint_raddr_i[11:0] == `CSR_MINSTRET || clint_raddr_i[11:0] == `CSR_MINSTRET) ? minstret[31:0] :
    (clint_raddr_i[11:0] == `CSR_MTVEC) ? mtvec :
    (clint_raddr_i[11:0] == `CSR_MCAUSE) ? mcause :
    (clint_raddr_i[11:0] == `CSR_MEPC) ? mepc :
    (clint_raddr_i[11:0] == `CSR_MIE) ? mie :
    (clint_raddr_i[11:0] == `CSR_MSTATUS) ? mstatus :
    (clint_raddr_i[11:0] == `CSR_MSCRATCH) ? mscratch :
    // 机器模式寄存器
    (clint_raddr_i[11:0] == `CSR_MVENDORID) ? mvendorid :
    (clint_raddr_i[11:0] == `CSR_MARCHID) ? marchid :
    (clint_raddr_i[11:0] == `CSR_MIMPID) ? mimpid :
    (clint_raddr_i[11:0] == `CSR_MHARTID) ? mhartid :
    (clint_raddr_i[11:0] == `CSR_MISA) ? misa :
    (clint_raddr_i[11:0] == `CSR_MEDELEG) ? medeleg :
    (clint_raddr_i[11:0] == `CSR_MIDELEG) ? mideleg :
    (clint_raddr_i[11:0] == `CSR_MIP) ? mip :
    (clint_raddr_i[11:0] == `CSR_MTVAL) ? mtval :
    (clint_raddr_i[11:0] == `CSR_MCOUNTEREN) ? mcounteren :
    // 性能计数器
    (clint_raddr_i[11:0] == `CSR_TIME) ? time_val[31:0] :
    (clint_raddr_i[11:0] == `CSR_TIMEH) ? time_val[63:32] :
    (clint_raddr_i[11:0] == `CSR_MINSTRET) ? minstret[31:0] :
    (clint_raddr_i[11:0] == `CSR_MINSTRETH) ? minstret[63:32] :
    // 硬件性能监控计数器
    (clint_raddr_i[11:0] == `CSR_HPMCOUNTER3) ? hpmcounter3 :
    (clint_raddr_i[11:0] == `CSR_HPMCOUNTER4) ? hpmcounter4 :
    (clint_raddr_i[11:0] == `CSR_HPMCOUNTER5) ? hpmcounter5 :
    (clint_raddr_i[11:0] == `CSR_HPMCOUNTER6) ? hpmcounter6 :
    `ZeroWord;


endmodule
