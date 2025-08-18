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

// CSR处理单元 - 处理CSR寄存器操作
module exu_csr_unit (
    input wire clk,   // 添加时钟信号
    input wire rst_n,

    // 控制信号
    input wire [`INST_ADDR_WIDTH-1:0] pc_i,  // PC信号

    // 第一路指令和操作数输入-来自dispatch
    input wire                        req_csr_0_i,
    input wire [                31:0] csr_op1_0_i,
    input wire [                31:0] csr_addr_0_i,
    input wire                        csr_csrrw_0_i,
    input wire                        csr_csrrs_0_i,
    input wire                        csr_csrrc_0_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_0_i,   // CSR指令ID
    input wire                        csr_we_0_i,      // CSR寄存器写使能信号
    input wire                        csr_reg_we_0_i,  // 保留寄存器写使能信号
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_0_i,   // CSR寄存器写地址
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_0_i,   // 寄存器写地址输入

    // 第二路指令和操作数输入-来自dispatch
    input wire                        req_csr_1_i,
    input wire [                31:0] csr_op1_1_i,
    input wire [                31:0] csr_addr_1_i,
    input wire                        csr_csrrw_1_i,
    input wire                        csr_csrrs_1_i,
    input wire                        csr_csrrc_1_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_1_i,   // CSR指令ID
    input wire                        csr_we_1_i,      // CSR寄存器写使能信号
    input wire                        csr_reg_we_1_i,  // 保留寄存器写使能信号
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_1_i,   // CSR寄存器写地址
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_1_i,   // 寄存器写地址输入

    //csr-reg 提供的数据
    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,


    // 握手信号和控制
    input  wire wb_ready_i,  // 写回单元准备好接收CSR结果
    output wire csr_stall_o, // CSR暂停信号

    // 中断信号
    input wire int_assert_i,

    // CSR读地址输出 - 用于访问CSR寄存器
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // CSR读地址

    // CSR写数据输出 - 完整输出所有CSR相关信号
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,  // CSR写数据
    output wire                       csr_we_o,     // CSR写使能
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,  // CSR写地址

    // 寄存器写回数据 - 用于对通用寄存器的写回
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,  // 寄存器写地址输出
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,  // 输出指令ID
    output wire                        csr_reg_we_o  // 保留寄存器写使能输出
);

    // FIFO参数定义
    localparam FIFO_DEPTH = 4;
    localparam FIFO_PTR_WIDTH = 2;

    // FIFO信号定义
    typedef struct packed {
        logic [31:0]                 csr_op1;
        logic [31:0]                 csr_addr;
        logic                        csr_csrrw;
        logic                        csr_csrrs;
        logic                        csr_csrrc;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
        logic                        csr_we;
        logic                        csr_reg_we;
        logic [`BUS_ADDR_WIDTH-1:0]  csr_waddr;
        logic [`REG_ADDR_WIDTH-1:0]  reg_waddr;
    } fifo_entry_t;

    fifo_entry_t fifo_mem[FIFO_DEPTH-1:0];
    reg [FIFO_PTR_WIDTH:0] fifo_wr_ptr, fifo_rd_ptr;
    wire [FIFO_PTR_WIDTH:0] fifo_wr_ptr_nxt, fifo_rd_ptr_nxt;
    wire fifo_empty, fifo_full;
    wire [FIFO_PTR_WIDTH:0] fifo_count;

    // FIFO状态信号
    assign fifo_count = fifo_wr_ptr - fifo_rd_ptr;
    assign fifo_empty = (fifo_count == 0);
    assign fifo_full  = (fifo_count == FIFO_DEPTH);

    // 输入有效性判断
    wire req_csr_0_valid = req_csr_0_i;
    wire req_csr_1_valid = req_csr_1_i;
    wire both_valid = req_csr_0_valid & req_csr_1_valid;
    wire only_0_valid = req_csr_0_valid & ~req_csr_1_valid;
    wire only_1_valid = ~req_csr_0_valid & req_csr_1_valid;

    // FIFO控制逻辑
    wire push_two, push_one, pop_one;
    wire can_push_two = (fifo_count <= (FIFO_DEPTH - 2));
    wire can_push_one = ~fifo_full;

    assign push_two = both_valid & ~fifo_empty & can_push_two;
    assign push_one = (both_valid & fifo_empty & can_push_one) |
                      ((only_0_valid | only_1_valid) & ~fifo_empty & can_push_one);
    assign pop_one = ~fifo_empty & wb_ready_i;

    // 暂停逻辑
    assign csr_stall_o = (both_valid & fifo_full) |
                         (both_valid & ~fifo_empty & ~can_push_two) |
                         ((only_0_valid | only_1_valid) & ~fifo_empty & fifo_full);

    // FIFO指针更新
    assign fifo_wr_ptr_nxt = push_two ? (fifo_wr_ptr + 2) :
                             push_one ? (fifo_wr_ptr + 1) : fifo_wr_ptr;
    assign fifo_rd_ptr_nxt = pop_one ? (fifo_rd_ptr + 1) : fifo_rd_ptr;

    // FIFO指针寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
        end else begin
            fifo_wr_ptr <= fifo_wr_ptr_nxt;
            fifo_rd_ptr <= fifo_rd_ptr_nxt;
        end
    end

    // FIFO写入逻辑
    fifo_entry_t fifo_entry_0, fifo_entry_1;
    assign fifo_entry_0.csr_op1    = csr_op1_0_i;
    assign fifo_entry_0.csr_addr   = csr_addr_0_i;
    assign fifo_entry_0.csr_csrrw  = csr_csrrw_0_i;
    assign fifo_entry_0.csr_csrrs  = csr_csrrs_0_i;
    assign fifo_entry_0.csr_csrrc  = csr_csrrc_0_i;
    assign fifo_entry_0.commit_id  = commit_id_0_i;
    assign fifo_entry_0.csr_we     = csr_we_0_i;
    assign fifo_entry_0.csr_reg_we = csr_reg_we_0_i;
    assign fifo_entry_0.csr_waddr  = csr_waddr_0_i;
    assign fifo_entry_0.reg_waddr  = reg_waddr_0_i;

    assign fifo_entry_1.csr_op1    = csr_op1_1_i;
    assign fifo_entry_1.csr_addr   = csr_addr_1_i;
    assign fifo_entry_1.csr_csrrw  = csr_csrrw_1_i;
    assign fifo_entry_1.csr_csrrs  = csr_csrrs_1_i;
    assign fifo_entry_1.csr_csrrc  = csr_csrrc_1_i;
    assign fifo_entry_1.commit_id  = commit_id_1_i;
    assign fifo_entry_1.csr_we     = csr_we_1_i;
    assign fifo_entry_1.csr_reg_we = csr_reg_we_1_i;
    assign fifo_entry_1.csr_waddr  = csr_waddr_1_i;
    assign fifo_entry_1.reg_waddr  = reg_waddr_1_i;

    always_ff @(posedge clk) begin
        if (push_two) begin
            fifo_mem[fifo_wr_ptr[FIFO_PTR_WIDTH-1:0]]                <= fifo_entry_1;
            fifo_mem[(fifo_wr_ptr[FIFO_PTR_WIDTH-1:0]+1)%FIFO_DEPTH] <= fifo_entry_0;
        end else if (push_one) begin
            if (both_valid & fifo_empty) begin
                fifo_mem[fifo_wr_ptr[FIFO_PTR_WIDTH-1:0]] <= fifo_entry_1;
            end else if (only_0_valid) begin
                fifo_mem[fifo_wr_ptr[FIFO_PTR_WIDTH-1:0]] <= fifo_entry_0;
            end else if (only_1_valid) begin
                fifo_mem[fifo_wr_ptr[FIFO_PTR_WIDTH-1:0]] <= fifo_entry_1;
            end
        end
    end

    // 输出选择逻辑
    fifo_entry_t current_output_entry;
    wire use_direct_output = (both_valid & fifo_empty) | 
                             ((only_0_valid | only_1_valid) & fifo_empty);

    always_comb begin
        if (use_direct_output) begin
            if (both_valid & fifo_empty) begin
                current_output_entry = fifo_entry_0;
            end else if (only_0_valid & fifo_empty) begin
                current_output_entry = fifo_entry_0;
            end else if (only_1_valid & fifo_empty) begin
                current_output_entry = fifo_entry_1;
            end else begin
                current_output_entry = '0;
            end
        end else if (~fifo_empty) begin
            current_output_entry = fifo_mem[fifo_rd_ptr[FIFO_PTR_WIDTH-1:0]];
        end else begin
            current_output_entry = '0;
        end
    end

    // CSR读地址输出 - 只要不stall就输出
    assign csr_raddr_o = csr_stall_o ? '0 : current_output_entry.csr_addr[`BUS_ADDR_WIDTH-1:0];

    // 内部CSR操作信号
    wire                        req_csr_i = ~csr_stall_o & (use_direct_output | ~fifo_empty);
    wire [                31:0] csr_op1_i = current_output_entry.csr_op1;
    wire [                31:0] csr_addr_i = current_output_entry.csr_addr;
    wire                        csr_csrrw_i = current_output_entry.csr_csrrw;
    wire                        csr_csrrs_i = current_output_entry.csr_csrrs;
    wire                        csr_csrrc_i = current_output_entry.csr_csrrc;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_i = current_output_entry.commit_id;
    wire                        csr_we_i = current_output_entry.csr_we;
    wire                        csr_reg_we_i = current_output_entry.csr_reg_we;
    wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i = current_output_entry.csr_waddr;
    wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i = current_output_entry.reg_waddr;

    wire [ `REG_DATA_WIDTH-1:0] csr_wdata_nxt;
    wire [ `REG_DATA_WIDTH-1:0] reg_wdata_nxt;

    assign csr_wdata_nxt = int_assert_i ? `ZeroWord :
        ({`REG_DATA_WIDTH{csr_csrrw_i}} & csr_op1_i) |
        ({`REG_DATA_WIDTH{csr_csrrs_i}} & (csr_op1_i | csr_rdata_i)) |
        ({`REG_DATA_WIDTH{csr_csrrc_i}} & (csr_rdata_i & (~csr_op1_i)));

    assign reg_wdata_nxt = int_assert_i ? `ZeroWord : (req_csr_i ? csr_rdata_i : `ZeroWord);

    // 握手信号控制逻辑
    wire valid_csr_op = req_csr_i & ~int_assert_i;  // 当前有有效的CSR操作

    wire csr_reg_we_nxt = (valid_csr_op & csr_reg_we_i) ? `WriteEnable : `WriteDisable;

    // 仿照csr_reg_we_nxt，统一风格
    wire csr_we_nxt = (valid_csr_op & csr_we_i) ? `WriteEnable : `WriteDisable;

    // 直接输出信号赋值
    assign csr_wdata_o  = csr_wdata_nxt;
    assign reg_wdata_o  = reg_wdata_nxt;
    assign csr_we_o     = csr_we_nxt;
    assign csr_waddr_o  = csr_waddr_i;
    assign reg_waddr_o  = reg_waddr_i;
    assign commit_id_o  = commit_id_i;  // 输出commit ID
    assign csr_reg_we_o = csr_reg_we_nxt;
endmodule
