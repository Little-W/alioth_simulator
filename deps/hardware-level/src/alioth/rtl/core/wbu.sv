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

// 写回单元 - 负责寄存器写回逻辑和仲裁优先级
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

    // 寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,

    // CSR寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o
);

    // === 使用FIFO模块实例化各种缓冲区 ===
    localparam FIFO_DEPTH = 2;

    // MUL FIFO
    wire [`REG_DATA_WIDTH-1:0] mul_fifo_wdata;
    wire [`REG_ADDR_WIDTH-1:0] mul_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] mul_fifo_commit_id;
    wire mul_fifo_push, mul_fifo_pop;
    wire mul_fifo_full, mul_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] mul_fifo_count;

    reg_wb_fifo #(.FIFO_DEPTH(FIFO_DEPTH)) mul_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wdata_i(mul_reg_wdata_i),
        .waddr_i(mul_reg_waddr_i),
        .commit_id_i(mul_commit_id_i),
        .push(mul_fifo_push),
        .pop(mul_fifo_pop),
        .wdata_o(mul_fifo_wdata),
        .waddr_o(mul_fifo_waddr),
        .commit_id_o(mul_fifo_commit_id),
        .full(mul_fifo_full),
        .empty(mul_fifo_empty),
        .count(mul_fifo_count)
    );

    // DIV FIFO
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

    // ALU FIFO
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

    // CSR FIFO
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

    // === 冲突判断 ===
    // 优先级: lsu > FIFO输出(mul > div > csr > alu) > 普通输入(mul > div > csr > alu)
    wire lsu_active = lsu_reg_we_i;
    wire mul_active = mul_reg_we_i;
    wire div_active = div_reg_we_i;
    wire csr_reg_active = csr_reg_we_i;
    wire alu_active = alu_reg_we_i;

    wire any_fifo_valid = (mul_fifo_count > 0) || (div_fifo_count > 0) || (alu_fifo_count > 0) || (csr_fifo_count > 0);

    // === ready信号修改为FIFO未满 ===
    assign mul_ready_o = !mul_fifo_full;
    assign div_ready_o = !div_fifo_full;
    assign alu_ready_o = !alu_fifo_full;
    assign csr_ready_o = !csr_fifo_full;

    // === 写回仲裁，lsu始终最高优先，FIFO输出仅在lsu无写回时有效 ===
    wire mul_fifo_en = !mul_fifo_empty && !lsu_active;
    wire div_fifo_en = !div_fifo_empty && !lsu_active && mul_fifo_empty;
    wire csr_fifo_en = !csr_fifo_empty && !lsu_active && mul_fifo_empty && div_fifo_empty;
    wire alu_fifo_en = !alu_fifo_empty && !lsu_active && mul_fifo_empty && div_fifo_empty && csr_fifo_empty;

    // 普通输入使能条件，mul > div > csr > alu，且都需 lsu 不活跃且上级FIFO为空
    wire mul_en = mul_active && !lsu_active && mul_fifo_empty && !any_fifo_valid;
    wire div_en = div_active && !lsu_active && mul_fifo_empty && div_fifo_empty && !mul_active && !(csr_fifo_count > 0) && !(alu_fifo_count > 0);
    wire csr_en = csr_reg_active && !lsu_active && mul_fifo_empty && div_fifo_empty && csr_fifo_empty && !mul_active && !div_active && !(alu_fifo_count > 0);
    wire alu_en = alu_active && !lsu_active && mul_fifo_empty && div_fifo_empty && csr_fifo_empty && alu_fifo_empty && !mul_active && !div_active && !csr_reg_active;

    // FIFO操作控制
    assign mul_fifo_push = mul_active && mul_ready_o && (lsu_active || any_fifo_valid);
    assign mul_fifo_pop = mul_fifo_en;

    assign div_fifo_push = div_active && div_ready_o && (lsu_active || mul_active || (mul_fifo_count > 0) || (csr_fifo_count > 0) || (alu_fifo_count > 0));
    assign div_fifo_pop = div_fifo_en;

    assign csr_fifo_push = csr_reg_active && csr_ready_o && (lsu_active || mul_active || div_active || (mul_fifo_count > 0) || (div_fifo_count > 0) || (alu_fifo_count > 0));
    assign csr_fifo_pop = csr_fifo_en;

    assign alu_fifo_push = alu_active && alu_ready_o && (lsu_active || mul_active || div_active || csr_reg_active || any_fifo_valid);
    assign alu_fifo_pop = alu_fifo_en;

    // === 写数据和地址多路选择器，全部与或逻辑 ===
    wire [`REG_DATA_WIDTH-1:0] reg_wdata_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_r;
    wire reg_we_r;
    wire commit_valid_r;

    assign reg_wdata_r =
        ({`REG_DATA_WIDTH{lsu_active}}      & lsu_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{mul_fifo_en}}     & mul_fifo_wdata)     |
        ({`REG_DATA_WIDTH{div_fifo_en}}     & div_fifo_wdata)     |
        ({`REG_DATA_WIDTH{alu_fifo_en}}     & alu_fifo_wdata)     |
        ({`REG_DATA_WIDTH{csr_fifo_en}}     & csr_fifo_wdata)     |
        ({`REG_DATA_WIDTH{mul_en}}          & mul_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{div_en}}          & div_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{alu_en}}          & alu_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{csr_en}}          & csr_reg_wdata_i);

    assign reg_waddr_r =
        ({`REG_ADDR_WIDTH{lsu_active}}      & lsu_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{mul_fifo_en}}     & mul_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{div_fifo_en}}     & div_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{alu_fifo_en}}     & alu_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{csr_fifo_en}}     & csr_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{mul_en}}          & mul_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{div_en}}          & div_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{alu_en}}          & alu_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{csr_en}}          & csr_reg_waddr_i);

    assign commit_id_r =
        ({`COMMIT_ID_WIDTH{lsu_active}}     & lsu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{mul_fifo_en}}    & mul_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{div_fifo_en}}    & div_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{alu_fifo_en}}    & alu_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{csr_fifo_en}}    & csr_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{mul_en}}         & mul_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{div_en}}         & div_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{alu_en}}         & alu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{csr_en}}         & csr_commit_id_i);

    assign reg_we_r = mul_fifo_en || div_fifo_en || alu_fifo_en || csr_fifo_en ||
                      mul_en || div_en || alu_en || csr_en || lsu_active;
    assign commit_valid_r = reg_we_r;

    // === 写回输出一级流水寄存器 ===
    reg [`REG_DATA_WIDTH-1:0] reg_wdata_ff;
    reg [`REG_ADDR_WIDTH-1:0] reg_waddr_ff;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_ff;
    reg reg_we_ff;
    reg commit_valid_ff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_wdata_ff    <= '0;
            reg_waddr_ff    <= '0;
            commit_id_ff    <= '0;
            reg_we_ff       <= 1'b0;
            commit_valid_ff <= 1'b0;
        end else begin
            reg_wdata_ff    <= reg_wdata_r;
            reg_waddr_ff    <= reg_waddr_r;
            commit_id_ff    <= commit_id_r;
            reg_we_ff       <= reg_we_r;
            commit_valid_ff <= commit_valid_r;
        end
    end

    // 输出到寄存器文件的信号（改为流水寄存器输出）
    assign reg_we_o      = reg_we_ff;
    assign reg_wdata_o   = reg_wdata_ff;
    assign reg_waddr_o   = reg_waddr_ff;

    // CSR寄存器写回信号无需仲裁和缓冲
    assign csr_we_o      = csr_we_i;
    assign csr_wdata_o   = csr_wdata_i;
    assign csr_waddr_o   = csr_waddr_i;

    // 长指令完成信号（改为流水寄存器输出）
    assign commit_valid_o = commit_valid_ff;
    assign commit_id_o    = commit_id_ff;

endmodule