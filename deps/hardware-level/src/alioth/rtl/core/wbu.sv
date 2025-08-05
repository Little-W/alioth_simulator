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

    // === 增加各输入端口的缓冲区（不含lsu） ===
    typedef struct packed {
        logic valid;
        logic [`REG_DATA_WIDTH-1:0] wdata;
        logic [`REG_ADDR_WIDTH-1:0] waddr;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
    } reg_buf_t;

    // 定义一个零对象
    localparam reg_buf_t REG_BUF_ZERO = '{valid: 1'b0, wdata: '0, waddr: '0, commit_id: '0};

    reg_buf_t mul_buf, div_buf, alu_buf, csr_buf;
    reg_buf_t mul_buf_nxt, div_buf_nxt, alu_buf_nxt, csr_buf_nxt;

    // === 缓冲区写入逻辑（不含lsu） ===
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_buf <= REG_BUF_ZERO;
            div_buf <= REG_BUF_ZERO;
            alu_buf <= REG_BUF_ZERO;
            csr_buf <= REG_BUF_ZERO;
        end else begin
            mul_buf <= mul_buf_nxt;
            div_buf <= div_buf_nxt;
            alu_buf <= alu_buf_nxt;
            csr_buf <= csr_buf_nxt;
        end
    end

    // === 冲突判断 ===
    // 优先级: lsu > 缓冲区(mul > div > csr > alu) > 普通输入(mul > div > csr > alu)
    wire lsu_active = lsu_reg_we_i;
    wire mul_active = mul_reg_we_i & mul_ready_o;
    wire div_active = div_reg_we_i & div_ready_o;
    wire csr_reg_active = csr_reg_we_i & csr_ready_o;
    wire alu_active = alu_reg_we_i & alu_ready_o;

    wire any_buf_valid = mul_buf.valid || div_buf.valid || alu_buf.valid || csr_buf.valid;

    // 冲突条件，优先级高的活跃信号和所有缓冲区有效信号
    wire mul_conflict      = lsu_active || any_buf_valid;
    wire div_conflict      = lsu_active || mul_active || any_buf_valid;
    wire csr_reg_conflict  = lsu_active || mul_active || div_active || any_buf_valid;
    wire alu_conflict      = lsu_active || mul_active || div_active || csr_reg_active || any_buf_valid;

    // === 缓冲区写入条件（不含lsu） ===
    always_comb begin
        mul_buf_nxt = mul_buf;
        div_buf_nxt = div_buf;
        alu_buf_nxt = alu_buf;
        csr_buf_nxt = csr_buf;

        // MUL
        if (mul_active && mul_conflict) begin
            mul_buf_nxt.valid     = 1'b1;
            mul_buf_nxt.wdata     = mul_reg_wdata_i;
            mul_buf_nxt.waddr     = mul_reg_waddr_i;
            mul_buf_nxt.commit_id = mul_commit_id_i;
        end else if (mul_buf_en) begin
            mul_buf_nxt.valid = 1'b0;
        end

        // DIV
        if (div_active && div_conflict) begin
            div_buf_nxt.valid     = 1'b1;
            div_buf_nxt.wdata     = div_reg_wdata_i;
            div_buf_nxt.waddr     = div_reg_waddr_i;
            div_buf_nxt.commit_id = div_commit_id_i;
        end else if (div_buf_en) begin
            div_buf_nxt.valid = 1'b0;
        end

        // ALU
        if (alu_active && alu_conflict) begin
            alu_buf_nxt.valid     = 1'b1;
            alu_buf_nxt.wdata     = alu_reg_wdata_i;
            alu_buf_nxt.waddr     = alu_reg_waddr_i;
            alu_buf_nxt.commit_id = alu_commit_id_i;
        end else if (alu_buf_en) begin
            alu_buf_nxt.valid = 1'b0;
        end

        // CSR对通用寄存器写回
        if (csr_reg_active && csr_reg_conflict) begin
            csr_buf_nxt.valid     = 1'b1;
            csr_buf_nxt.wdata     = csr_reg_wdata_i;
            csr_buf_nxt.waddr     = csr_reg_waddr_i;
            csr_buf_nxt.commit_id = csr_commit_id_i;
        end else if (csr_buf_en) begin
            csr_buf_nxt.valid = 1'b0;
        end
    end

    // === ready信号修改为!buffered_req_valid（无lsu相关） ===
    assign mul_ready_o = !mul_buf.valid;
    assign div_ready_o = !div_buf.valid;
    assign alu_ready_o = !alu_buf.valid;
    assign csr_ready_o = !csr_buf.valid;

    // === 写回仲裁，lsu始终最高优先，buf_valid仅在lsu无写回时有效 ===
    wire mul_buf_en = mul_buf.valid && !lsu_active;
    wire div_buf_en = div_buf.valid && !lsu_active && !mul_buf.valid;
    wire csr_buf_en = csr_buf.valid && !lsu_active && !mul_buf.valid && !div_buf.valid;
    wire alu_buf_en = alu_buf.valid && !lsu_active && !mul_buf.valid && !div_buf.valid && !csr_buf.valid;

    // 普通输入使能条件，mul > div > csr > alu，且都需 lsu 不活跃且上级缓冲区/输入不活跃
    wire mul_en = mul_active && !mul_conflict;
    wire div_en = div_active && !div_conflict;
    wire csr_en = csr_reg_active && !csr_reg_conflict;
    wire alu_en = alu_active && !alu_conflict;

    // === 写数据和地址多路选择器，全部与或逻辑 ===
    wire [`REG_DATA_WIDTH-1:0] reg_wdata_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_r;

    assign reg_wdata_r =
        ({`REG_DATA_WIDTH{lsu_active}}      & lsu_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{mul_buf_en}}      & mul_buf.wdata)     |
        ({`REG_DATA_WIDTH{div_buf_en}}      & div_buf.wdata)     |
        ({`REG_DATA_WIDTH{alu_buf_en}}      & alu_buf.wdata)     |
        ({`REG_DATA_WIDTH{csr_buf_en}}      & csr_buf.wdata)     |
        ({`REG_DATA_WIDTH{mul_en}}          & mul_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{div_en}}          & div_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{alu_en}}          & alu_reg_wdata_i)   |
        ({`REG_DATA_WIDTH{csr_en}}          & csr_reg_wdata_i);

    assign reg_waddr_r =
        ({`REG_ADDR_WIDTH{lsu_active}}      & lsu_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{mul_buf_en}}      & mul_buf.waddr)     |
        ({`REG_ADDR_WIDTH{div_buf_en}}      & div_buf.waddr)     |
        ({`REG_ADDR_WIDTH{alu_buf_en}}      & alu_buf.waddr)     |
        ({`REG_ADDR_WIDTH{csr_buf_en}}      & csr_buf.waddr)     |
        ({`REG_ADDR_WIDTH{mul_en}}          & mul_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{div_en}}          & div_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{alu_en}}          & alu_reg_waddr_i)   |
        ({`REG_ADDR_WIDTH{csr_en}}          & csr_reg_waddr_i);

    assign commit_id_r =
        ({`COMMIT_ID_WIDTH{lsu_active}}     & lsu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{mul_buf_en}}     & mul_buf.commit_id) |
        ({`COMMIT_ID_WIDTH{div_buf_en}}     & div_buf.commit_id) |
        ({`COMMIT_ID_WIDTH{alu_buf_en}}     & alu_buf.commit_id) |
        ({`COMMIT_ID_WIDTH{csr_buf_en}}     & csr_buf.commit_id) |
        ({`COMMIT_ID_WIDTH{mul_en}}         & mul_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{div_en}}         & div_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{alu_en}}         & alu_commit_id_i)   |
        ({`COMMIT_ID_WIDTH{csr_en}}         & csr_commit_id_i);

    // 输出到寄存器文件的信号
    assign reg_we_o = mul_buf_en || div_buf_en || alu_buf_en || csr_buf_en ||
                      mul_en || div_en || alu_en || csr_en || lsu_active;
    assign reg_wdata_o = reg_wdata_r;
    assign reg_waddr_o = reg_waddr_r;

    // CSR寄存器写回信号无需仲裁和缓冲
    assign csr_we_o = csr_we_i;
    assign csr_wdata_o = csr_wdata_i;
    assign csr_waddr_o = csr_waddr_i;

    // 长指令完成信号（缓冲区优先）
    assign commit_valid_o = mul_buf_en || div_buf_en || alu_buf_en || csr_buf_en ||
                            mul_en || div_en || alu_en || csr_en || lsu_active;
    assign commit_id_o = commit_id_r;

endmodule
