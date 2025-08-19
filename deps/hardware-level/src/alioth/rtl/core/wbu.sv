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

// 写回单元 - 负责寄存器写回逻辑和仲裁优先级（双端口设计）
module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ALU数据
    input  wire [ `REG_DATA_WIDTH-1:0] alu_reg_wdata_i,
    input  wire                        alu_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu_commit_id_i,  // ALU指令ID
    output wire                        alu_ready_o,      // ALU握手信号

    // 来自EXU的乘法数据
    input  wire [ `REG_DATA_WIDTH-1:0] mul_reg_wdata_i,
    input  wire                        mul_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul_commit_id_i,  // 乘法指令ID
    output wire                        mul_ready_o,      // MUL握手信号

    // 来自EXU的除法数据
    input  wire [ `REG_DATA_WIDTH-1:0] div_reg_wdata_i,
    input  wire                        div_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div_commit_id_i,  // 除法指令ID
    output wire                        div_ready_o,      // DIV握手信号

    // 来自EXU的CSR数据
    input  wire [ `REG_DATA_WIDTH-1:0] csr_wdata_i,
    input  wire                        csr_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_i,  // CSR指令ID
    output wire                        csr_ready_o,      // CSR握手信号

    // CSR寄存器写数据输入
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,  // 保留寄存器写地址输入
    input wire                       csr_reg_we_i,     // 新增：csr写回使能输入

    // 来自EXU的lsu/LSU数据
    input wire [ `REG_DATA_WIDTH-1:0] lsu_reg_wdata_i,
    input wire                        lsu_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_i,  // LSU指令ID，修改为3位

    // 长指令完成信号（对接hazard_detection）
    output wire                        commit_valid_o,  // 指令完成有效信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,     // 完成指令ID
    output wire                        commit_valid2_o, // 第二路指令完成有效信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id2_o,    // 第二路完成指令ID

    // 端口1：寄存器写回接口（LSU + ALU）
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,

    // 端口2：寄存器写回接口（MUL + DIV + CSR）
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata2_o,
    output wire                       reg_we2_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr2_o,

    // CSR寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o
);

    // === 使用FIFO模块实例化各种缓冲区 ===
    localparam FIFO_DEPTH = 2;

    // ALU FIFO（端口1）
    wire [`REG_DATA_WIDTH-1:0] alu_fifo_wdata;
    wire [`REG_ADDR_WIDTH-1:0] alu_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] alu_fifo_commit_id;
    wire alu_fifo_push, alu_fifo_pop;
    wire alu_fifo_full, alu_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] alu_fifo_count;

    reg_wb_fifo #(.FIFO_DEPTH(FIFO_DEPTH)) alu_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wdata_i(alu_reg_wdata_i),
        .waddr_i(alu_reg_waddr_i),
        .commit_id_i(alu_commit_id_i),
        .push(alu_fifo_push),
        .pop(alu_fifo_pop),
        .wdata_o(alu_fifo_wdata),
        .waddr_o(alu_fifo_waddr),
        .commit_id_o(alu_fifo_commit_id),
        .full(alu_fifo_full),
        .empty(alu_fifo_empty),
        .count(alu_fifo_count)
    );

    // DIV FIFO（端口2）
    wire [`REG_DATA_WIDTH-1:0] div_fifo_wdata;
    wire [`REG_ADDR_WIDTH-1:0] div_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] div_fifo_commit_id;
    wire div_fifo_push, div_fifo_pop;
    wire div_fifo_full, div_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] div_fifo_count;

    reg_wb_fifo #(.FIFO_DEPTH(FIFO_DEPTH)) div_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wdata_i(div_reg_wdata_i),
        .waddr_i(div_reg_waddr_i),
        .commit_id_i(div_commit_id_i),
        .push(div_fifo_push),
        .pop(div_fifo_pop),
        .wdata_o(div_fifo_wdata),
        .waddr_o(div_fifo_waddr),
        .commit_id_o(div_fifo_commit_id),
        .full(div_fifo_full),
        .empty(div_fifo_empty),
        .count(div_fifo_count)
    );

    // CSR FIFO（端口2）
    wire [`REG_DATA_WIDTH-1:0] csr_fifo_wdata;
    wire [`REG_ADDR_WIDTH-1:0] csr_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] csr_fifo_commit_id;
    wire csr_fifo_push, csr_fifo_pop;
    wire csr_fifo_full, csr_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] csr_fifo_count;

    reg_wb_fifo #(.FIFO_DEPTH(FIFO_DEPTH)) csr_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wdata_i(csr_reg_wdata_i),
        .waddr_i(csr_reg_waddr_i),
        .commit_id_i(csr_commit_id_i),
        .push(csr_fifo_push),
        .pop(csr_fifo_pop),
        .wdata_o(csr_fifo_wdata),
        .waddr_o(csr_fifo_waddr),
        .commit_id_o(csr_fifo_commit_id),
        .full(csr_fifo_full),
        .empty(csr_fifo_empty),
        .count(csr_fifo_count)
    );

    // === 端口1：LSU + ALU 写回逻辑 ===
    // LSU无条件写回，ALU优先级低一级
    wire lsu_active = lsu_reg_we_i;
    wire alu_active = alu_reg_we_i;

    // ALU FIFO操作：当LSU活跃时，ALU需要进FIFO
    assign alu_fifo_push = alu_active && alu_ready_o && (lsu_active || !alu_fifo_empty);
    assign alu_fifo_pop = !alu_fifo_empty && !lsu_active;

    // ALU ready信号：FIFO未满
    assign alu_ready_o = !alu_fifo_full;

    // 端口1写回仲裁：LSU > ALU FIFO > ALU直接
    wire alu_fifo_en = !alu_fifo_empty && !lsu_active;
    wire alu_en = alu_active && !lsu_active && alu_fifo_empty;

    // 端口1写回数据选择
    wire [`REG_DATA_WIDTH-1:0] reg_wdata1_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr1_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id1_r;
    wire reg_we1_r;

    assign reg_wdata1_r =
        ({`REG_DATA_WIDTH{lsu_active}}   & lsu_reg_wdata_i) |
        ({`REG_DATA_WIDTH{alu_fifo_en}}  & alu_fifo_wdata)  |
        ({`REG_DATA_WIDTH{alu_en}}       & alu_reg_wdata_i);

    assign reg_waddr1_r =
        ({`REG_ADDR_WIDTH{lsu_active}}   & lsu_reg_waddr_i) |
        ({`REG_ADDR_WIDTH{alu_fifo_en}}  & alu_fifo_waddr)  |
        ({`REG_ADDR_WIDTH{alu_en}}       & alu_reg_waddr_i);

    assign commit_id1_r =
        ({`COMMIT_ID_WIDTH{lsu_active}}  & lsu_commit_id_i) |
        ({`COMMIT_ID_WIDTH{alu_fifo_en}} & alu_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{alu_en}}      & alu_commit_id_i);

    assign reg_we1_r = lsu_active || alu_fifo_en || alu_en;

    // === 端口2：MUL + DIV + CSR 写回逻辑 ===
    // MUL优先级最高且不需要FIFO，DIV和CSR需要FIFO
    wire mul_active = mul_reg_we_i;
    wire div_active = div_reg_we_i;
    wire csr_reg_active = csr_reg_we_i;

    // MUL ready信号始终为1
    assign mul_ready_o = 1'b1;

    // DIV和CSR的FIFO操作：当MUL活跃时需要进FIFO
    assign div_fifo_push = div_active && div_ready_o && (mul_active || !csr_fifo_empty || !div_fifo_empty);
    assign div_fifo_pop = !div_fifo_empty && !mul_active;

    assign csr_fifo_push = csr_reg_active && csr_ready_o && (mul_active || div_active || !div_fifo_empty || !csr_fifo_empty);
    assign csr_fifo_pop = !csr_fifo_empty && !mul_active && div_fifo_empty;

    // DIV和CSR ready信号：FIFO未满
    assign div_ready_o = !div_fifo_full;
    assign csr_ready_o = !csr_fifo_full;

    // 端口2写回仲裁：MUL > DIV FIFO > CSR FIFO > DIV直接 > CSR直接
    wire div_fifo_en = !div_fifo_empty && !mul_active;
    wire csr_fifo_en = !csr_fifo_empty && !mul_active && div_fifo_empty;
    wire div_en = div_active && !mul_active && div_fifo_empty && csr_fifo_empty;
    wire csr_en = csr_reg_active && !mul_active && div_fifo_empty && csr_fifo_empty && !div_active;

    // 端口2写回数据选择
    wire [`REG_DATA_WIDTH-1:0] reg_wdata2_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr2_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id2_r;
    wire reg_we2_r;

    assign reg_wdata2_r =
        ({`REG_DATA_WIDTH{mul_active}}   & mul_reg_wdata_i) |
        ({`REG_DATA_WIDTH{div_fifo_en}}  & div_fifo_wdata)  |
        ({`REG_DATA_WIDTH{csr_fifo_en}}  & csr_fifo_wdata)  |
        ({`REG_DATA_WIDTH{div_en}}       & div_reg_wdata_i) |
        ({`REG_DATA_WIDTH{csr_en}}       & csr_reg_wdata_i);

    assign reg_waddr2_r =
        ({`REG_ADDR_WIDTH{mul_active}}   & mul_reg_waddr_i) |
        ({`REG_ADDR_WIDTH{div_fifo_en}}  & div_fifo_waddr)  |
        ({`REG_ADDR_WIDTH{csr_fifo_en}}  & csr_fifo_waddr)  |
        ({`REG_ADDR_WIDTH{div_en}}       & div_reg_waddr_i) |
        ({`REG_ADDR_WIDTH{csr_en}}       & csr_reg_waddr_i);

    assign commit_id2_r =
        ({`COMMIT_ID_WIDTH{mul_active}}  & mul_commit_id_i) |
        ({`COMMIT_ID_WIDTH{div_fifo_en}} & div_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{csr_fifo_en}} & csr_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{div_en}}      & div_commit_id_i) |
        ({`COMMIT_ID_WIDTH{csr_en}}      & csr_commit_id_i);

    assign reg_we2_r = mul_active || div_fifo_en || csr_fifo_en || div_en || csr_en;

    // === 写回输出一级流水寄存器 ===
    reg [`REG_DATA_WIDTH-1:0] reg_wdata1_ff, reg_wdata2_ff;
    reg [`REG_ADDR_WIDTH-1:0] reg_waddr1_ff, reg_waddr2_ff;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id1_ff, commit_id2_ff;
    reg reg_we1_ff, reg_we2_ff;
    reg commit_valid1_ff, commit_valid2_ff;

    // csr输出打一拍
    reg csr_we_ff;
    reg [`REG_DATA_WIDTH-1:0] csr_wdata_ff;
    reg [`BUS_ADDR_WIDTH-1:0] csr_waddr_ff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_wdata1_ff   <= '0;
            reg_waddr1_ff   <= '0;
            reg_wdata2_ff   <= '0;
            reg_waddr2_ff   <= '0;
            commit_id1_ff   <= '0;
            commit_id2_ff   <= '0;
            reg_we1_ff      <= 1'b0;
            reg_we2_ff      <= 1'b0;
            commit_valid1_ff<= 1'b0;
            commit_valid2_ff<= 1'b0;
            // csr打一拍复位
            csr_we_ff       <= 1'b0;
            csr_wdata_ff    <= '0;
            csr_waddr_ff    <= '0;
        end else begin
            reg_wdata1_ff   <= reg_wdata1_r;
            reg_waddr1_ff   <= reg_waddr1_r;
            reg_wdata2_ff   <= reg_wdata2_r;
            reg_waddr2_ff   <= reg_waddr2_r;
            commit_id1_ff   <= commit_id1_r;
            commit_id2_ff   <= commit_id2_r;
            reg_we1_ff      <= reg_we1_r;
            reg_we2_ff      <= reg_we2_r;
            commit_valid1_ff<= reg_we1_r;
            commit_valid2_ff<= reg_we2_r;
            // csr打一拍
            csr_we_ff       <= csr_we_i;
            csr_wdata_ff    <= csr_wdata_i;
            csr_waddr_ff    <= csr_waddr_i;
        end
    end

    // 输出到寄存器文件的信号（改为流水寄存器输出）
    assign reg_we_o      = reg_we1_ff;
    assign reg_wdata_o   = reg_wdata1_ff;
    assign reg_waddr_o   = reg_waddr1_ff;

    assign reg_we2_o     = reg_we2_ff;
    assign reg_wdata2_o  = reg_wdata2_ff;
    assign reg_waddr2_o  = reg_waddr2_ff;

    // CSR寄存器写回信号打一拍输出
    assign csr_we_o      = csr_we_ff;
    assign csr_wdata_o   = csr_wdata_ff;
    assign csr_waddr_o   = csr_waddr_ff;

    // 长指令完成信号（双端口输出）
    assign commit_valid_o    = commit_valid1_ff;
    assign commit_id_o       = commit_id1_ff;
    // 新增：第二路commit信号
    assign commit_valid2_o   = commit_valid2_ff;
    assign commit_id2_o      = commit_id2_ff;

endmodule