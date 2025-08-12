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

    // 来自EXU的LSU数据
    input wire [`FREG_DATA_WIDTH-1:0] lsu_reg_wdata_i,
    input wire                        lsu_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_i,  // LSU指令ID，修改为3位

    // 来自EXU的FPU数据
    input wire [`FREG_DATA_WIDTH-1:0] fpu_reg_wdata_i,
    input wire fpu_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] fpu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] fpu_commit_id_i,  // FPU指令ID
    output wire fpu_ready_o,  // FPU握手信号
    // 长指令完成信号（对接hazard_detection）
    output wire commit_valid_int_o,  // 整数寄存器指令完成有效信号
    output wire commit_valid_fp_o,  // 浮点寄存器指令完成有效信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_int_o,  // 整数寄存器完成指令ID
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_fp_o,  // 浮点寄存器完成指令ID

    // 寄存器写回接口
    output wire [`GREG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [`GREG_ADDR_WIDTH-1:0] reg_waddr_o,

    // CSR寄存器写回接口
    output wire [`GREG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                        csr_we_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,

    // 浮点寄存器写回接口
    output wire [`FREG_DATA_WIDTH-1:0] fpreg_wdata_o,
    output wire                        fpreg_we_o,
    output wire [`FREG_ADDR_WIDTH-1:0] fpreg_waddr_o
);

    // === 使用FIFO模块实例化各种缓冲区 ===
    localparam FIFO_DEPTH = 2;

    // 整数写回相关FIFO
    wire [`REG_DATA_WIDTH-1:0] mul_fifo_wdata, div_fifo_wdata, alu_fifo_wdata, csr_fifo_wdata, fpu_int_fifo_wdata;
    wire [`REG_ADDR_WIDTH-1:0] mul_fifo_waddr, div_fifo_waddr, alu_fifo_waddr, csr_fifo_waddr, fpu_int_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] mul_fifo_commit_id, div_fifo_commit_id, alu_fifo_commit_id, csr_fifo_commit_id, fpu_int_fifo_commit_id;
    wire mul_fifo_push, mul_fifo_pop, div_fifo_push, div_fifo_pop, alu_fifo_push, alu_fifo_pop, csr_fifo_push, csr_fifo_pop, fpu_int_fifo_push, fpu_int_fifo_pop;
    wire mul_fifo_full, mul_fifo_empty, div_fifo_full, div_fifo_empty, alu_fifo_full, alu_fifo_empty, csr_fifo_full, csr_fifo_empty, fpu_int_fifo_full, fpu_int_fifo_empty;
    wire [$clog2(
FIFO_DEPTH
):0] mul_fifo_count, div_fifo_count, alu_fifo_count, csr_fifo_count, fpu_int_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .REG_DATA_WIDTH(`REG_DATA_WIDTH)
    ) mul_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (mul_reg_wdata_i),
        .waddr_i    (mul_reg_waddr_i),
        .commit_id_i(mul_commit_id_i),
        .push       (mul_fifo_push),
        .pop        (mul_fifo_pop),
        .wdata_o    (mul_fifo_wdata),
        .waddr_o    (mul_fifo_waddr),
        .commit_id_o(mul_fifo_commit_id),
        .full       (mul_fifo_full),
        .empty      (mul_fifo_empty),
        .count      (mul_fifo_count)
    );

    reg_wb_fifo #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .REG_DATA_WIDTH(`REG_DATA_WIDTH)
    ) div_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (div_reg_wdata_i),
        .waddr_i    (div_reg_waddr_i),
        .commit_id_i(div_commit_id_i),
        .push       (div_fifo_push),
        .pop        (div_fifo_pop),
        .wdata_o    (div_fifo_wdata),
        .waddr_o    (div_fifo_waddr),
        .commit_id_o(div_fifo_commit_id),
        .full       (div_fifo_full),
        .empty      (div_fifo_empty),
        .count      (div_fifo_count)
    );

    reg_wb_fifo #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .REG_DATA_WIDTH(`REG_DATA_WIDTH)
    ) alu_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (alu_reg_wdata_i),
        .waddr_i    (alu_reg_waddr_i),
        .commit_id_i(alu_commit_id_i),
        .push       (alu_fifo_push),
        .pop        (alu_fifo_pop),
        .wdata_o    (alu_fifo_wdata),
        .waddr_o    (alu_fifo_waddr),
        .commit_id_o(alu_fifo_commit_id),
        .full       (alu_fifo_full),
        .empty      (alu_fifo_empty),
        .count      (alu_fifo_count)
    );

    reg_wb_fifo #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .REG_DATA_WIDTH(`REG_DATA_WIDTH)
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

    // FPU写回整数寄存器时的独立FIFO
    reg_wb_fifo #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .REG_DATA_WIDTH(`REG_DATA_WIDTH)
    ) fpu_int_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (fpu_reg_wdata_i),
        .waddr_i    (fpu_reg_waddr_i),
        .commit_id_i(fpu_commit_id_i),
        .push       (fpu_int_fifo_push),
        .pop        (fpu_int_fifo_pop),
        .wdata_o    (fpu_int_fifo_wdata),
        .waddr_o    (fpu_int_fifo_waddr),
        .commit_id_o(fpu_int_fifo_commit_id),
        .full       (fpu_int_fifo_full),
        .empty      (fpu_int_fifo_empty),
        .count      (fpu_int_fifo_count)
    );

    // 浮点写回相关FIFO
    // 浮点写回相关FIFO
    wire [ `REG_DATA_WIDTH-1:0] fpu_fp_fifo_wdata;
    wire [ `REG_ADDR_WIDTH-1:0] fpu_fp_fifo_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] fpu_fp_fifo_commit_id;
    wire fpu_fp_fifo_push, fpu_fp_fifo_pop;
    wire fpu_fp_fifo_full, fpu_fp_fifo_empty;
    wire [$clog2(FIFO_DEPTH):0] fpu_fp_fifo_count;

    reg_wb_fifo #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .REG_DATA_WIDTH(`FREG_DATA_WIDTH)
    ) fpu_fp_fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wdata_i    (fpu_reg_wdata_i),
        .waddr_i    (fpu_reg_waddr_i),
        .commit_id_i(fpu_commit_id_i),
        .push       (fpu_fp_fifo_push),
        .pop        (fpu_fp_fifo_pop),
        .wdata_o    (fpu_fp_fifo_wdata),
        .waddr_o    (fpu_fp_fifo_waddr),
        .commit_id_o(fpu_fp_fifo_commit_id),
        .full       (fpu_fp_fifo_full),
        .empty      (fpu_fp_fifo_empty),
        .count      (fpu_fp_fifo_count)
    );

    // === 整数与浮点写回分类 ===
    // LSU可以写回整数或浮点寄存器
    wire lsu_int_active = lsu_reg_we_i && !lsu_reg_waddr_i[`REG_ADDR_WIDTH-1];
    wire lsu_fp_active = lsu_reg_we_i && lsu_reg_waddr_i[`REG_ADDR_WIDTH-1];

    // FPU可以写回浮点寄存器或整数寄存器
    wire fpu_fp_active = fpu_reg_we_i && fpu_reg_waddr_i[`REG_ADDR_WIDTH-1];
    wire fpu_int_active = fpu_reg_we_i && !fpu_reg_waddr_i[`REG_ADDR_WIDTH-1];

    // 其他单元只写回整数寄存器
    wire mul_int_active = mul_reg_we_i;
    wire div_int_active = div_reg_we_i;
    wire csr_int_active = csr_reg_we_i;
    wire alu_int_active = alu_reg_we_i;

    // FIFO有效计数
    wire any_int_fifo_valid = (mul_fifo_count > 0) || (div_fifo_count > 0) || (alu_fifo_count > 0) || (csr_fifo_count > 0) || (fpu_int_fifo_count > 0);
    wire any_fp_fifo_valid = (fpu_fp_fifo_count > 0);

    // === ready信号：FIFO未满即可接受 ===
    assign mul_ready_o = !mul_fifo_full;
    assign div_ready_o = !div_fifo_full;
    assign alu_ready_o = !alu_fifo_full;
    assign csr_ready_o = !csr_fifo_full;
    assign fpu_ready_o = !fpu_fp_fifo_full && !fpu_int_fifo_full;

    // === 整数寄存器写回仲裁 ===
    // 优先级: lsu > mul_fifo > div_fifo > fpu_int_fifo > alu_fifo > csr_fifo > mul > div > fpu_int > alu > csr
    wire mul_fifo_en = !mul_fifo_empty && !lsu_int_active;
    wire div_fifo_en = !div_fifo_empty && !lsu_int_active && mul_fifo_empty;
    wire fpu_int_fifo_en  = !fpu_int_fifo_empty  && !lsu_int_active && mul_fifo_empty && div_fifo_empty;
    wire alu_fifo_en      = !alu_fifo_empty      && !lsu_int_active && mul_fifo_empty && div_fifo_empty && fpu_int_fifo_empty;
    wire csr_fifo_en      = !csr_fifo_empty      && !lsu_int_active && mul_fifo_empty && div_fifo_empty && fpu_int_fifo_empty && alu_fifo_empty;

    // 普通输入之间的优先级：mul > div > fpu_int > alu > csr
    wire mul_int_en = mul_int_active && !lsu_int_active && !any_int_fifo_valid;
    wire div_int_en = div_int_active && !lsu_int_active && !any_int_fifo_valid && !mul_int_active;
    wire fpu_int_en  = fpu_int_active && !lsu_int_active && !any_int_fifo_valid && !mul_int_active && !div_int_active;
    wire alu_int_en  = alu_int_active && !lsu_int_active && !any_int_fifo_valid && !mul_int_active && !div_int_active && !fpu_int_active;
    wire csr_int_en  = csr_int_active && !lsu_int_active && !any_int_fifo_valid && !mul_int_active && !div_int_active && !fpu_int_active && !alu_int_active;

    // === 浮点寄存器写回仲裁 ===
    // 优先级: lsu > fpu_fp_fifo > fpu_fp
    wire fpu_fp_fifo_en = !fpu_fp_fifo_empty && !lsu_fp_active;
    wire fpu_fp_en = fpu_fp_active && !lsu_fp_active && fpu_fp_fifo_empty;

    // === FIFO操作控制（优先级与仲裁一致） ===
    assign mul_fifo_push = mul_int_active && mul_ready_o && (lsu_int_active || any_int_fifo_valid);
    assign mul_fifo_pop = mul_fifo_en;

    assign div_fifo_push = div_int_active && div_ready_o && (lsu_int_active || mul_int_active || any_int_fifo_valid);
    assign div_fifo_pop = div_fifo_en;

    assign fpu_int_fifo_push = fpu_int_active && fpu_ready_o && (lsu_int_active || mul_int_active || div_int_active || any_int_fifo_valid);
    assign fpu_int_fifo_pop = fpu_int_fifo_en;

    assign alu_fifo_push = alu_int_active && alu_ready_o && (lsu_int_active || mul_int_active || div_int_active || fpu_int_active || any_int_fifo_valid);
    assign alu_fifo_pop = alu_fifo_en;

    assign csr_fifo_push = csr_int_active && csr_ready_o && (lsu_int_active || mul_int_active || div_int_active || fpu_int_active || alu_int_active || any_int_fifo_valid);
    assign csr_fifo_pop = csr_fifo_en;

    assign fpu_fp_fifo_push = fpu_fp_active && fpu_ready_o && (lsu_fp_active || any_fp_fifo_valid);
    assign fpu_fp_fifo_pop = fpu_fp_fifo_en;

    // === 整数寄存器写数据和地址多路选择器 ===
    wire [ `REG_DATA_WIDTH-1:0] int_reg_wdata_r;
    wire [ `REG_ADDR_WIDTH-1:0] int_reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] int_commit_id_r;
    wire                        int_reg_we_r;

    assign int_reg_wdata_r =
        ({`REG_DATA_WIDTH{lsu_int_active}}      & lsu_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{mul_fifo_en}}         & mul_fifo_wdata)     |
        ({`REG_DATA_WIDTH{div_fifo_en}}         & div_fifo_wdata)     |
        ({`REG_DATA_WIDTH{alu_fifo_en}}         & alu_fifo_wdata)     |
        ({`REG_DATA_WIDTH{csr_fifo_en}}         & csr_fifo_wdata)     |
        ({`REG_DATA_WIDTH{fpu_int_fifo_en}}     & fpu_int_fifo_wdata) |
        ({`REG_DATA_WIDTH{mul_int_en}}          & mul_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{div_int_en}}          & div_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{alu_int_en}}          & alu_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{csr_int_en}}          & csr_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{fpu_int_en}}          & fpu_reg_wdata_i);

    assign int_reg_waddr_r =
        ({`REG_ADDR_WIDTH{lsu_int_active}}      & lsu_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{mul_fifo_en}}         & mul_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{div_fifo_en}}         & div_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{alu_fifo_en}}         & alu_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{csr_fifo_en}}         & csr_fifo_waddr)     |
        ({`REG_ADDR_WIDTH{fpu_int_fifo_en}}     & fpu_int_fifo_waddr) |
        ({`REG_ADDR_WIDTH{mul_int_en}}          & mul_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{div_int_en}}          & div_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{alu_int_en}}          & alu_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{csr_int_en}}          & csr_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{fpu_int_en}}          & fpu_reg_waddr_i);

    assign int_commit_id_r =
        ({`COMMIT_ID_WIDTH{lsu_int_active}}     & lsu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{mul_fifo_en}}        & mul_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{div_fifo_en}}        & div_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{alu_fifo_en}}        & alu_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{csr_fifo_en}}        & csr_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{fpu_int_fifo_en}}    & fpu_int_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{mul_int_en}}         & mul_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{div_int_en}}         & div_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{alu_int_en}}         & alu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{csr_int_en}}         & csr_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{fpu_int_en}}         & fpu_commit_id_i);

    assign int_reg_we_r = mul_fifo_en || div_fifo_en || alu_fifo_en || csr_fifo_en || fpu_int_fifo_en ||
                          mul_int_en || div_int_en || alu_int_en || csr_int_en || fpu_int_en || lsu_int_active;

    // === 浮点寄存器写数据和地址多路选择器 ===
    wire [`FREG_DATA_WIDTH-1:0] fp_reg_wdata_r;
    wire [`FREG_ADDR_WIDTH-1:0] fp_reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] fp_commit_id_r;
    wire                        fp_reg_we_r;

    assign fp_reg_wdata_r =
        ({`FREG_DATA_WIDTH{lsu_fp_active}}       & lsu_reg_wdata_i)   |
        ({`FREG_DATA_WIDTH{fpu_fp_fifo_en}}      & fpu_fp_fifo_wdata) |
        ({`FREG_DATA_WIDTH{fpu_fp_en}}           & fpu_reg_wdata_i);

    assign fp_reg_waddr_r =
        ({`FREG_ADDR_WIDTH{lsu_fp_active}}       & lsu_reg_waddr_i[`FREG_ADDR_WIDTH-1:0])   |
        ({`FREG_ADDR_WIDTH{fpu_fp_fifo_en}}      & fpu_fp_fifo_waddr[`FREG_ADDR_WIDTH-1:0]) |
        ({`FREG_ADDR_WIDTH{fpu_fp_en}}           & fpu_reg_waddr_i[`FREG_ADDR_WIDTH-1:0]);

    assign fp_commit_id_r =
        ({`COMMIT_ID_WIDTH{lsu_fp_active}}      & lsu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{fpu_fp_fifo_en}}     & fpu_fp_fifo_commit_id) |
        ({`COMMIT_ID_WIDTH{fpu_fp_en}}          & fpu_commit_id_i);

    assign fp_reg_we_r = lsu_fp_active || fpu_fp_fifo_en || fpu_fp_en;

    // === 写回输出流水寄存器 ===
    // 整数寄存器流水寄存器
    reg [ `REG_DATA_WIDTH-1:0] int_reg_wdata_ff;
    reg [ `REG_ADDR_WIDTH-1:0] int_reg_waddr_ff;
    reg [`COMMIT_ID_WIDTH-1:0] int_commit_id_ff;
    reg                        int_reg_we_ff;

    // 浮点寄存器流水寄存器
    reg [`FREG_DATA_WIDTH-1:0] fp_reg_wdata_ff;
    reg [ `REG_ADDR_WIDTH-1:0] fp_reg_waddr_ff;
    reg [`COMMIT_ID_WIDTH-1:0] fp_commit_id_ff;
    reg                        fp_reg_we_ff;

    // CSR流水寄存器
    reg                        csr_we_ff;
    reg [ `REG_DATA_WIDTH-1:0] csr_wdata_ff;
    reg [ `BUS_ADDR_WIDTH-1:0] csr_waddr_ff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 整数寄存器流水寄存器复位
            int_reg_wdata_ff <= '0;
            int_reg_waddr_ff <= '0;
            int_commit_id_ff <= '0;
            int_reg_we_ff    <= 1'b0;
            // 浮点寄存器流水寄存器复位
            fp_reg_wdata_ff  <= '0;
            fp_reg_waddr_ff  <= '0;
            fp_commit_id_ff  <= '0;
            fp_reg_we_ff     <= 1'b0;
            // CSR流水寄存器复位
            csr_we_ff        <= 1'b0;
            csr_wdata_ff     <= '0;
            csr_waddr_ff     <= '0;
        end else begin
            // 整数寄存器流水寄存器更新
            int_reg_wdata_ff <= int_reg_wdata_r;
            int_reg_waddr_ff <= int_reg_waddr_r;
            int_commit_id_ff <= int_commit_id_r;
            int_reg_we_ff    <= int_reg_we_r;
            // 浮点寄存器流水寄存器更新
            fp_reg_wdata_ff  <= fp_reg_wdata_r;
            fp_reg_waddr_ff  <= fp_reg_waddr_r;
            fp_commit_id_ff  <= fp_commit_id_r;
            fp_reg_we_ff     <= fp_reg_we_r;
            // CSR流水寄存器更新
            csr_we_ff        <= csr_we_i;
            csr_wdata_ff     <= csr_wdata_i;
            csr_waddr_ff     <= csr_waddr_i;
        end
    end

    // === 输出信号分配 ===
    // 整数寄存器写回输出
    assign reg_we_o           = int_reg_we_ff;
    assign reg_wdata_o        = int_reg_wdata_ff;
    assign reg_waddr_o        = int_reg_waddr_ff;

    // 浮点寄存器写回输出
    assign fpreg_we_o         = fp_reg_we_ff;
    assign fpreg_wdata_o      = fp_reg_wdata_ff;
    assign fpreg_waddr_o      = fp_reg_waddr_ff[`FREG_ADDR_WIDTH-1:0];

    // CSR寄存器写回输出
    assign csr_we_o           = csr_we_ff;
    assign csr_wdata_o        = csr_wdata_ff;
    assign csr_waddr_o        = csr_waddr_ff;

    // 长指令完成信号输出
    assign commit_valid_int_o = int_reg_we_ff;
    assign commit_valid_fp_o  = fp_reg_we_ff;
    assign commit_id_int_o    = int_commit_id_ff;
    assign commit_id_fp_o     = fp_commit_id_ff;

endmodule
