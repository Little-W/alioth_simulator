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

    output wire global_int_en_o,  // 全局中断使能标志

    // to clint
    output wire [`REG_DATA_WIDTH-1:0] clint_data_o,      // clint模块读寄存器数据
    output wire [`REG_DATA_WIDTH-1:0] clint_csr_mtvec,   // mtvec
    output wire [`REG_DATA_WIDTH-1:0] clint_csr_mepc,    // mepc
    output wire [`REG_DATA_WIDTH-1:0] clint_csr_mstatus, // mstatus

    // to ex
    output wire [`REG_DATA_WIDTH-1:0] data_o  // ex模块读寄存器数据

);

    wire [`DOUBLE_REG_WIDTH-1:0] cycle;
    wire [  `REG_DATA_WIDTH-1:0] mtvec;
    wire [  `REG_DATA_WIDTH-1:0] mcause;
    wire [  `REG_DATA_WIDTH-1:0] mepc;
    wire [  `REG_DATA_WIDTH-1:0] mie;
    wire [  `REG_DATA_WIDTH-1:0] mstatus;
    wire [  `REG_DATA_WIDTH-1:0] mscratch;

    // 内部寄存器的值更新信号
    wire [  `REG_DATA_WIDTH-1:0] mtvec_next;
    wire [  `REG_DATA_WIDTH-1:0] mcause_next;
    wire [  `REG_DATA_WIDTH-1:0] mepc_next;
    wire [  `REG_DATA_WIDTH-1:0] mie_next;
    wire [  `REG_DATA_WIDTH-1:0] mstatus_next;
    wire [  `REG_DATA_WIDTH-1:0] mscratch_next;
    wire [`DOUBLE_REG_WIDTH-1:0] cycle_next;

    // 寄存器写使能信号
    wire                         mtvec_we;
    wire                         mcause_we;
    wire                         mepc_we;
    wire                         mie_we;
    wire                         mstatus_we;
    wire                         mscratch_we;

    assign global_int_en_o   = (mstatus[3] == 1'b1) ? 1'b1 : 1'b0;

    assign clint_csr_mtvec   = mtvec;
    assign clint_csr_mepc    = mepc;
    assign clint_csr_mstatus = mstatus;

    // cycle counter
    // 复位撤销后就一直计数
    assign cycle_next        = cycle + 1'b1;

    gnrl_dff #(
        .DW(`DOUBLE_REG_WIDTH)
    ) cycle_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (cycle_next),
        .qout (cycle)
    );

    // 计算寄存器写使能信号和下一个值
    // 优先响应ex模块的写操作，其次是clint模块
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

    // 使用带使能信号的D触发器实现CSR寄存器
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

    // ex模块读CSR寄存器
    assign data_o = ((waddr_i[11:0] == raddr_i[11:0]) && (we_i == `WriteEnable)) ? data_i :
                   (raddr_i[11:0] == `CSR_CYCLE) ? cycle[31:0] :
                   (raddr_i[11:0] == `CSR_CYCLEH) ? cycle[63:32] :
                   (raddr_i[11:0] == `CSR_MTVEC) ? mtvec :
                   (raddr_i[11:0] == `CSR_MCAUSE) ? mcause :
                   (raddr_i[11:0] == `CSR_MEPC) ? mepc :
                   (raddr_i[11:0] == `CSR_MIE) ? mie :
                   (raddr_i[11:0] == `CSR_MSTATUS) ? mstatus :
                   (raddr_i[11:0] == `CSR_MSCRATCH) ? mscratch :
                   `ZeroWord;

    // clint模块读CSR寄存器
    assign clint_data_o = ((clint_waddr_i[11:0] == clint_raddr_i[11:0]) && (clint_we_i == `WriteEnable)) ? clint_data_i :
                         (clint_raddr_i[11:0] == `CSR_CYCLE) ? cycle[31:0] :
                         (clint_raddr_i[11:0] == `CSR_CYCLEH) ? cycle[63:32] :
                         (clint_raddr_i[11:0] == `CSR_MTVEC) ? mtvec :
                         (clint_raddr_i[11:0] == `CSR_MCAUSE) ? mcause :
                         (clint_raddr_i[11:0] == `CSR_MEPC) ? mepc :
                         (clint_raddr_i[11:0] == `CSR_MIE) ? mie :
                         (clint_raddr_i[11:0] == `CSR_MSTATUS) ? mstatus :
                         (clint_raddr_i[11:0] == `CSR_MSCRATCH) ? mscratch :
                         `ZeroWord;

endmodule
