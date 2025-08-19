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

module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ALU数据 (双发射，原 adder+shifter)
    input  wire [ `REG_DATA_WIDTH-1:0] alu1_reg_wdata_i,
    input  wire                        alu1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu1_commit_id_i,
    output wire                        alu1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] alu2_reg_wdata_i,
    input  wire                        alu2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu2_commit_id_i,
    output wire                        alu2_ready_o,

    // 来自EXU的MUL数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] mul1_reg_wdata_i,
    input  wire                        mul1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul1_commit_id_i,
    output wire                        mul1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] mul2_reg_wdata_i,
    input  wire                        mul2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul2_commit_id_i,
    output wire                        mul2_ready_o,

    // 来自EXU的DIV数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] div1_reg_wdata_i,
    input  wire                        div1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div1_commit_id_i,
    output wire                        div1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] div2_reg_wdata_i,
    input  wire                        div2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div2_commit_id_i,
    output wire                        div2_ready_o,

    // 来自EXU的CSR数据 (单路)
    input  wire [ `REG_DATA_WIDTH-1:0] csr_wdata_i,
    input  wire                        csr_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_i,
    output wire                        csr_ready_o,

    // CSR寄存器写数据输入 (单路)
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,
    input wire                       csr_reg_we_i,

    // 来自EXU的LSU数据 (单路)
    input  wire [ `REG_DATA_WIDTH-1:0] lsu_reg_wdata_i,
    input  wire                        lsu_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_i,
    output wire                        lsu_ready_o,

    // 提交输出
    output wire                        commit_valid1_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id1_o,
    output wire                        commit_valid2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id2_o,

    // 通用寄存器写回（双通道）
    output wire [`REG_DATA_WIDTH-1:0] reg1_wdata_o,
    output wire                       reg1_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg1_waddr_o,

    output wire [`REG_DATA_WIDTH-1:0] reg2_wdata_o,
    output wire                       reg2_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg2_waddr_o,

    // CSR写回
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o
);

    // === 端口1: MUL无条件写回，优先级最高，无需fifo ===
    // 端口1 FIFO: div/alu/csr
    localparam FIFO_DEPTH = 2;

    // DIV1 FIFO
    wire [ `REG_DATA_WIDTH-1:0] div1_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] div1_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] div1_fifo_commit_id;
    wire div1_fifo_push, div1_fifo_pop;
    wire div1_fifo_full, div1_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] div1_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) div1_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (div1_reg_wdata_i),
        .waddr_i    (div1_reg_waddr_i),
        .commit_id_i(div1_commit_id_i),
        .push       (div1_fifo_push),
        .pop        (div1_fifo_pop),
        .wdata_o    (div1_fifo_wdata),
        .waddr_o    (div1_fifo_waddr),
        .commit_id_o(div1_fifo_commit_id),
        .full       (div1_fifo_full),
        .empty      (div1_fifo_empty),
        .count      (div1_fifo_count)
    );

    // ALU1 FIFO
    wire [ `REG_DATA_WIDTH-1:0] alu1_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] alu1_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] alu1_fifo_commit_id;
    wire alu1_fifo_push, alu1_fifo_pop;
    wire alu1_fifo_full, alu1_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] alu1_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) alu1_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (alu1_reg_wdata_i),
        .waddr_i    (alu1_reg_waddr_i),
        .commit_id_i(alu1_commit_id_i),
        .push       (alu1_fifo_push),
        .pop        (alu1_fifo_pop),
        .wdata_o    (alu1_fifo_wdata),
        .waddr_o    (alu1_fifo_waddr),
        .commit_id_o(alu1_fifo_commit_id),
        .full       (alu1_fifo_full),
        .empty      (alu1_fifo_empty),
        .count      (alu1_fifo_count)
    );

    // CSR FIFO（端口1）
    wire [ `REG_DATA_WIDTH-1:0] csr_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] csr_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] csr_fifo_commit_id;
    wire csr_fifo_push, csr_fifo_pop;
    wire csr_fifo_full, csr_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] csr_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) csr_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (csr_reg_wdata_i),
        .waddr_i    (csr_reg_waddr_i),
        .commit_id_i(csr_commit_id_i),
        .push       (csr_fifo_push),
        .pop        (csr_fifo_pop),
        .wdata_o    (csr_fifo_wdata),
        .waddr_o    (csr_fifo_waddr),
        .commit_id_o(csr_fifo_commit_id),
        .full       (csr_fifo_full),
        .empty      (csr_fifo_empty),
        .count      (csr_fifo_count)
    );

    // === 端口2: lsu无条件写回，mul优先级最高 ===
    // MUL2 FIFO
    wire [ `REG_DATA_WIDTH-1:0] mul2_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] mul2_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] mul2_fifo_commit_id;
    wire mul2_fifo_push, mul2_fifo_pop;
    wire mul2_fifo_full, mul2_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] mul2_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) mul2_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (mul2_reg_wdata_i),
        .waddr_i    (mul2_reg_waddr_i),
        .commit_id_i(mul2_commit_id_i),
        .push       (mul2_fifo_push),
        .pop        (mul2_fifo_pop),
        .wdata_o    (mul2_fifo_wdata),
        .waddr_o    (mul2_fifo_waddr),
        .commit_id_o(mul2_fifo_commit_id),
        .full       (mul2_fifo_full),
        .empty      (mul2_fifo_empty),
        .count      (mul2_fifo_count)
    );

    // DIV2 FIFO
    wire [ `REG_DATA_WIDTH-1:0] div2_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] div2_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] div2_fifo_commit_id;
    wire div2_fifo_push, div2_fifo_pop;
    wire div2_fifo_full, div2_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] div2_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) div2_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (div2_reg_wdata_i),
        .waddr_i    (div2_reg_waddr_i),
        .commit_id_i(div2_commit_id_i),
        .push       (div2_fifo_push),
        .pop        (div2_fifo_pop),
        .wdata_o    (div2_fifo_wdata),
        .waddr_o    (div2_fifo_waddr),
        .commit_id_o(div2_fifo_commit_id),
        .full       (div2_fifo_full),
        .empty      (div2_fifo_empty),
        .count      (div2_fifo_count)
    );

    // ALU2 FIFO
    wire [ `REG_DATA_WIDTH-1:0] alu2_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] alu2_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] alu2_fifo_commit_id;
    wire alu2_fifo_push, alu2_fifo_pop;
    wire alu2_fifo_full, alu2_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] alu2_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) alu2_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (alu2_reg_wdata_i),
        .waddr_i    (alu2_reg_waddr_i),
        .commit_id_i(alu2_commit_id_i),
        .push       (alu2_fifo_push),
        .pop        (alu2_fifo_pop),
        .wdata_o    (alu2_fifo_wdata),
        .waddr_o    (alu2_fifo_waddr),
        .commit_id_o(alu2_fifo_commit_id),
        .full       (alu2_fifo_full),
        .empty      (alu2_fifo_empty),
        .count      (alu2_fifo_count)
    );

    // === ready信号 ===
    assign alu1_ready_o = !alu1_fifo_full;
    assign div1_ready_o = !div1_fifo_full;
    assign csr_ready_o  = !csr_fifo_full;
    assign mul1_ready_o = 1'b1; // MUL1无条件写回

    assign mul2_ready_o = !mul2_fifo_full;
    assign div2_ready_o = !div2_fifo_full;
    assign alu2_ready_o = !alu2_fifo_full;
    // csr2_ready_o 可选

    // === 端口1仲裁 ===
    // mul1无条件写回
    wire mul1_en = mul1_reg_we_i;
    // 端口1 FIFO输出优先级: div1 > alu1 > csr
    wire div1_fifo_en = !div1_fifo_empty && !mul1_en;
    wire alu1_fifo_en = !alu1_fifo_empty && !mul1_en && div1_fifo_empty;
    wire csr_fifo_en = !csr_fifo_empty && !mul1_en && div1_fifo_empty && alu1_fifo_empty;

    // 普通输入使能
    wire div1_en = div1_reg_we_i && !mul1_en && div1_fifo_empty && alu1_fifo_empty && csr_fifo_empty;
    wire alu1_en = alu1_reg_we_i && !mul1_en && div1_fifo_empty && alu1_fifo_empty && csr_fifo_empty && !div1_reg_we_i;
    wire csr_en  = csr_reg_we_i  && !mul1_en && div1_fifo_empty && alu1_fifo_empty && csr_fifo_empty && !div1_reg_we_i && !alu1_reg_we_i;

    // FIFO操作
    assign div1_fifo_push = div1_reg_we_i && div1_ready_o && (mul1_en || alu1_reg_we_i || csr_reg_we_i || (alu1_fifo_count > 0) || (csr_fifo_count > 0));
    assign div1_fifo_pop = div1_fifo_en;

    assign alu1_fifo_push = alu1_reg_we_i && alu1_ready_o && (mul1_en || div1_reg_we_i || csr_reg_we_i || (div1_fifo_count > 0) || (csr_fifo_count > 0));
    assign alu1_fifo_pop = alu1_fifo_en;

    assign csr_fifo_push  = csr_reg_we_i && csr_ready_o && (mul1_en || div1_reg_we_i || alu1_reg_we_i || (div1_fifo_count > 0) || (alu1_fifo_count > 0));
    assign csr_fifo_pop = csr_fifo_en;

    // === 端口2仲裁 ===
    // lsu无条件写回
    wire lsu_en = lsu_reg_we_i;
    // 端口2 FIFO输出优先级: mul2 > div2 > alu2
    wire mul2_fifo_en = !mul2_fifo_empty && !lsu_en;
    wire div2_fifo_en = !div2_fifo_empty && !lsu_en && mul2_fifo_empty;
    wire alu2_fifo_en = !alu2_fifo_empty && !lsu_en && mul2_fifo_empty && div2_fifo_empty;

    // 普通输入使能
    wire mul2_en = mul2_reg_we_i && !lsu_en && mul2_fifo_empty && div2_fifo_empty && alu2_fifo_empty;
    wire div2_en = div2_reg_we_i && !lsu_en && mul2_fifo_empty && div2_fifo_empty && alu2_fifo_empty && !mul2_reg_we_i;
    wire alu2_en = alu2_reg_we_i && !lsu_en && mul2_fifo_empty && div2_fifo_empty && alu2_fifo_empty && !mul2_reg_we_i && !div2_reg_we_i;

    // FIFO操作
    assign mul2_fifo_push = mul2_reg_we_i && mul2_ready_o && (lsu_en || div2_reg_we_i || alu2_reg_we_i || (div2_fifo_count > 0) || (alu2_fifo_count > 0));
    assign mul2_fifo_pop = mul2_fifo_en;

    assign div2_fifo_push = div2_reg_we_i && div2_ready_o && (lsu_en || mul2_reg_we_i || alu2_reg_we_i || (mul2_fifo_count > 0) || (alu2_fifo_count > 0));
    assign div2_fifo_pop = div2_fifo_en;

    assign alu2_fifo_push = alu2_reg_we_i && alu2_ready_o && (lsu_en || mul2_reg_we_i || div2_reg_we_i || (mul2_fifo_count > 0) || (div2_fifo_count > 0));
    assign alu2_fifo_pop = alu2_fifo_en;

    // === 写数据和地址多路选择器 ===
    // 端口1
    wire [ `REG_DATA_WIDTH-1:0] reg1_wdata_r;
    wire [ `REG_ADDR_WIDTH-1:0] reg1_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id1_r;
    wire                        reg1_we_r;
    wire                        commit_valid1_r;

    assign reg1_wdata_r =
        ({`REG_DATA_WIDTH{mul1_en}}        & mul1_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{div1_fifo_en}}   & div1_fifo_wdata)    |
        ({`REG_DATA_WIDTH{alu1_fifo_en}}   & alu1_fifo_wdata)    |
        ({`REG_DATA_WIDTH{csr_fifo_en}}    & csr_fifo_wdata)     |
        ({`REG_DATA_WIDTH{div1_en}}        & div1_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{alu1_en}}        & alu1_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{csr_en}}         & csr_reg_wdata_i);

    assign reg1_waddr_r =
        ({`REG_ADDR_WIDTH{mul1_en}}        & mul1_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{div1_fifo_en}}   & div1_fifo_waddr)    |
        ({`REG_ADDR_WIDTH{alu1_fifo_en}}   & alu1_fifo_waddr)    |
        ({`REG_ADDR_WIDTH{csr_fifo_en}}    & csr_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{div1_en}}        & div1_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{alu1_en}}        & alu1_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{csr_en}}         & csr_reg_waddr_i);

    assign commit_id1_r =
        ({`COMMIT_ID_WIDTH{mul1_en}}       & mul1_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{div1_fifo_en}}  & div1_fifo_commit_id)|
        ({`COMMIT_ID_WIDTH{alu1_fifo_en}}  & alu1_fifo_commit_id)|
        ({`COMMIT_ID_WIDTH{csr_fifo_en}}   & csr_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{div1_en}}       & div1_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{alu1_en}}       & alu1_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{csr_en}}        & csr_commit_id_i);

    assign reg1_we_r = mul1_en || div1_fifo_en || alu1_fifo_en || csr_fifo_en ||
                       div1_en || alu1_en || csr_en;
    assign commit_valid1_r = reg1_we_r;

    // 端口2
    wire [ `REG_DATA_WIDTH-1:0] reg2_wdata_r;
    wire [ `REG_ADDR_WIDTH-1:0] reg2_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id2_r;
    wire                        reg2_we_r;
    wire                        commit_valid2_r;

    assign reg2_wdata_r =
        ({`REG_DATA_WIDTH{lsu_en}}         & lsu_reg_wdata_i)    |
        ({`REG_DATA_WIDTH{mul2_fifo_en}}   & mul2_fifo_wdata)    |
        ({`REG_DATA_WIDTH{div2_fifo_en}}   & div2_fifo_wdata)    |
        ({`REG_DATA_WIDTH{alu2_fifo_en}}   & alu2_fifo_wdata)    |
        ({`REG_DATA_WIDTH{mul2_en}}        & mul2_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{div2_en}}        & div2_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{alu2_en}}        & alu2_reg_wdata_i);

    assign reg2_waddr_r =
        ({`REG_ADDR_WIDTH{lsu_en}}         & lsu_reg_waddr_i)    |
        ({`REG_ADDR_WIDTH{mul2_fifo_en}}   & mul2_fifo_waddr)    |
        ({`REG_ADDR_WIDTH{div2_fifo_en}}   & div2_fifo_waddr)    |
        ({`REG_ADDR_WIDTH{alu2_fifo_en}}   & alu2_fifo_waddr)    |
        ({`REG_ADDR_WIDTH{mul2_en}}        & mul2_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{div2_en}}        & div2_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{alu2_en}}        & alu2_reg_waddr_i);

    assign commit_id2_r =
        ({`COMMIT_ID_WIDTH{lsu_en}}        & lsu_commit_id_i)    |
        ({`COMMIT_ID_WIDTH{mul2_fifo_en}}  & mul2_fifo_commit_id)|
        ({`COMMIT_ID_WIDTH{div2_fifo_en}}  & div2_fifo_commit_id)|
        ({`COMMIT_ID_WIDTH{alu2_fifo_en}}  & alu2_fifo_commit_id)|
        ({`COMMIT_ID_WIDTH{mul2_en}}       & mul2_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{div2_en}}       & div2_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{alu2_en}}       & alu2_commit_id_i);

    assign reg2_we_r = lsu_en || mul2_fifo_en || div2_fifo_en || alu2_fifo_en ||
                       mul2_en || div2_en || alu2_en;
    assign commit_valid2_r = reg2_we_r;

    // === 写回输出一级流水寄存器 ===
    reg [`REG_DATA_WIDTH-1:0] reg1_wdata_ff, reg2_wdata_ff;
    reg [`REG_ADDR_WIDTH-1:0] reg1_waddr_ff, reg2_waddr_ff;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id1_ff, commit_id2_ff;
    reg reg1_we_ff, reg2_we_ff;
    reg commit_valid1_ff, commit_valid2_ff;
    // CSR打一拍寄存器
    reg csr_we_ff;
    reg [`REG_DATA_WIDTH-1:0] csr_wdata_ff;
    reg [`BUS_ADDR_WIDTH-1:0] csr_waddr_ff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg1_wdata_ff    <= '0;
            reg1_waddr_ff    <= '0;
            commit_id1_ff    <= '0;
            reg1_we_ff       <= 1'b0;
            commit_valid1_ff <= 1'b0;
            reg2_wdata_ff    <= '0;
            reg2_waddr_ff    <= '0;
            commit_id2_ff    <= '0;
            reg2_we_ff       <= 1'b0;
            commit_valid2_ff <= 1'b0;
            // csr打一拍复位
            csr_we_ff        <= 1'b0;
            csr_wdata_ff     <= '0;
            csr_waddr_ff     <= '0;
        end else begin
            reg1_wdata_ff    <= reg1_wdata_r;
            reg1_waddr_ff    <= reg1_waddr_r;
            commit_id1_ff    <= commit_id1_r;
            reg1_we_ff       <= reg1_we_r;
            commit_valid1_ff <= commit_valid1_r;
            reg2_wdata_ff    <= reg2_wdata_r;
            reg2_waddr_ff    <= reg2_waddr_r;
            commit_id2_ff    <= commit_id2_r;
            reg2_we_ff       <= reg2_we_r;
            commit_valid2_ff <= commit_valid2_r;
            // csr打一拍
            csr_we_ff        <= csr_we_i;
            csr_wdata_ff     <= csr_wdata_i;
            csr_waddr_ff     <= csr_waddr_i;
        end
    end

    // 输出到寄存器文件的信号（改为流水寄存器输出）
    assign reg1_we_o       = reg1_we_ff;
    assign reg1_wdata_o    = reg1_wdata_ff;
    assign reg1_waddr_o    = reg1_waddr_ff;
    assign reg2_we_o       = reg2_we_ff;
    assign reg2_wdata_o    = reg2_wdata_ff;
    assign reg2_waddr_o    = reg2_waddr_ff;

    // CSR寄存器写回信号打一拍输出
    assign csr_we_o        = csr_we_ff;
    assign csr_wdata_o     = csr_wdata_ff;
    assign csr_waddr_o     = csr_waddr_ff;

    // 长指令完成信号（改为流水寄存器输出）
    assign commit_valid1_o = commit_valid1_ff;
    assign commit_id1_o    = commit_id1_ff;
    assign commit_valid2_o = commit_valid2_ff;
    assign commit_id2_o    = commit_id2_ff;

endmodule
