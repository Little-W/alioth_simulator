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

// 保留栈FIFO模块 - 用于暂存dispatch输入信号
module dispatch_reserve_stack #(
    parameter FIFO_DEPTH = 4
) (
    input wire clk,
    input wire rst_n,

    // FIFO控制信号
    input  wire push_req_i,
    input  wire fifo_stall_i,
    input  wire fifo_flush_i,
    output wire fifo_full_o,

    // 输入信号组
    input wire                          inst_valid_i,
    input wire                          illegal_inst_i,
    input wire [    `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                  31:0] dec_imm_i,
    input wire [  `INST_ADDR_WIDTH-1:0] dec_pc_i,
    input wire [  `INST_DATA_WIDTH-1:0] inst_i,
    input wire                          is_pred_branch_i,
    input wire [   `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [   `REG_ADDR_WIDTH-1:0] reg1_raddr_i,
    input wire [   `REG_ADDR_WIDTH-1:0] reg2_raddr_i,
    input wire                          reg_we_i,
    input wire                          rs1_re_i,
    input wire                          rs2_re_i,
    input wire                          csr_we_i,
    input wire [   `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [   `BUS_ADDR_WIDTH-1:0] csr_raddr_i,
    input wire [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus_i,
    input wire                          rd_we_i,

    // 输出信号组
    output wire                          inst_valid_o,
    output wire                          illegal_inst_o,
    output wire [    `DECINFO_WIDTH-1:0] dec_info_bus_o,
    output wire [                  31:0] dec_imm_o,
    output wire [  `INST_ADDR_WIDTH-1:0] dec_pc_o,
    output wire [  `INST_DATA_WIDTH-1:0] inst_o,
    output wire                          is_pred_branch_o,
    output wire [   `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [   `REG_ADDR_WIDTH-1:0] reg1_raddr_o,
    output wire [   `REG_ADDR_WIDTH-1:0] reg2_raddr_o,
    output wire                          reg_we_o,
    output wire                          rs1_re_o,
    output wire                          rs2_re_o,
    output wire                          csr_we_o,
    output wire [   `BUS_ADDR_WIDTH-1:0] csr_waddr_o,
    output wire [   `BUS_ADDR_WIDTH-1:0] csr_raddr_o,
    output wire [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus_o,
    output wire                          rd_we_o
);

    // FIFO状态信号
    reg  [  $clog2(FIFO_DEPTH):0] fifo_count;
    reg  [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    reg  [$clog2(FIFO_DEPTH)-1:0] rd_ptr;

    // FIFO满和空状态
    wire                          fifo_empty = (fifo_count == 0);
    wire                          fifo_full = (fifo_count == FIFO_DEPTH);

    // 推入和弹出条件
    wire                          push_en = inst_valid_i && (push_req_i || !fifo_empty);
    wire                          pop_en = !fifo_empty && !fifo_stall_i;

    // FIFO操作控制
    wire [                   1:0] fifo_op = {push_en && !fifo_full, pop_en};

    wire                          output_data_valid;
    assign output_data_valid = !(fifo_flush_i || fifo_stall_i);

    // 打包输入数据结构
    typedef struct packed {
        logic inst_valid;
        logic illegal_inst;
        logic [`DECINFO_WIDTH-1:0] dec_info_bus;
        logic [31:0] dec_imm;
        logic [`INST_ADDR_WIDTH-1:0] dec_pc;
        logic [`INST_DATA_WIDTH-1:0] inst;
        logic is_pred_branch;
        logic [`REG_ADDR_WIDTH-1:0] reg_waddr;
        logic [`REG_ADDR_WIDTH-1:0] reg1_raddr;
        logic [`REG_ADDR_WIDTH-1:0] reg2_raddr;
        logic reg_we;
        logic rs1_re;
        logic rs2_re;
        logic csr_we;
        logic [`BUS_ADDR_WIDTH-1:0] csr_waddr;
        logic [`BUS_ADDR_WIDTH-1:0] csr_raddr;
        logic [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus;
        logic rd_we;
    } fifo_data_t;

    // FIFO存储器
    fifo_data_t fifo_mem   [FIFO_DEPTH-1:0];

    // 输入数据打包
    fifo_data_t input_data;
    assign input_data.inst_valid     = inst_valid_i;
    assign input_data.illegal_inst   = illegal_inst_i;
    assign input_data.dec_info_bus   = dec_info_bus_i;
    assign input_data.dec_imm        = dec_imm_i;
    assign input_data.dec_pc         = dec_pc_i;
    assign input_data.inst           = inst_i;
    assign input_data.is_pred_branch = is_pred_branch_i;
    assign input_data.reg_waddr      = reg_waddr_i;
    assign input_data.reg1_raddr     = reg1_raddr_i;
    assign input_data.reg2_raddr     = reg2_raddr_i;
    assign input_data.reg_we         = reg_we_i;
    assign input_data.rs1_re         = rs1_re_i;
    assign input_data.rs2_re         = rs2_re_i;
    assign input_data.csr_we         = csr_we_i;
    assign input_data.csr_waddr      = csr_waddr_i;
    assign input_data.csr_raddr      = csr_raddr_i;
    assign input_data.ex_info_bus    = ex_info_bus_i;
    assign input_data.rd_we          = rd_we_i;

    // FIFO输出数据
    fifo_data_t output_data;

    // 输出逻辑：FIFO为空时直连输入，否则输出FIFO数据
    assign output_data      = fifo_empty ? input_data : fifo_mem[rd_ptr];

    // 解包输出数据
    assign inst_valid_o     = output_data_valid ? output_data.inst_valid : 1'b0;
    assign illegal_inst_o   = output_data.illegal_inst;
    assign dec_info_bus_o   = output_data_valid ? output_data.dec_info_bus : '0;
    assign dec_imm_o        = output_data.dec_imm;
    assign dec_pc_o         = output_data.dec_pc;
    assign inst_o           = output_data.inst;
    assign is_pred_branch_o = output_data.is_pred_branch;
    assign reg_waddr_o      = output_data.reg_waddr;
    assign reg1_raddr_o     = output_data.reg1_raddr;
    assign reg2_raddr_o     = output_data.reg2_raddr;
    assign reg_we_o         = output_data.reg_we;
    assign rs1_re_o         = output_data.rs1_re;
    assign rs2_re_o         = output_data.rs2_re;
    assign csr_we_o         = output_data.csr_we;
    assign csr_waddr_o      = output_data.csr_waddr;
    assign csr_raddr_o      = output_data.csr_raddr;
    assign ex_info_bus_o    = output_data.ex_info_bus;
    assign rd_we_o          = output_data_valid ? output_data.rd_we : 1'b0;

    // FIFO满状态输出
    assign fifo_full_o      = fifo_full;

    // FIFO控制逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || fifo_flush_i) begin  // 修改：添加flush条件
            fifo_count <= 0;
            wr_ptr     <= 0;
            rd_ptr     <= 0;
        end else begin
            // 处理FIFO推入和弹出
            case (fifo_op)
                2'b10: begin  // 只推入
                    fifo_mem[wr_ptr] <= input_data;
                    wr_ptr           <= wr_ptr + 1'd1;
                    if (wr_ptr == FIFO_DEPTH - 1) wr_ptr <= 0;
                    fifo_count <= fifo_count + 1'd1;
                end
                2'b01: begin  // 只弹出
                    if (fifo_count > 0) begin
                        rd_ptr <= rd_ptr + 1'd1;
                        if (rd_ptr == FIFO_DEPTH - 1) rd_ptr <= 0;
                        fifo_count <= fifo_count - 1'd1;
                    end
                end
                2'b11: begin  // 同时推入和弹出
                    fifo_mem[wr_ptr] <= input_data;
                    wr_ptr           <= wr_ptr + 1'd1;
                    if (wr_ptr == FIFO_DEPTH - 1) wr_ptr <= 0;
                    rd_ptr <= rd_ptr + 1'd1;
                    if (rd_ptr == FIFO_DEPTH - 1) rd_ptr <= 0;
                    // fifo_count保持不变
                end
                default: begin  // 2'b00: 无操作
                    // 保持当前状态
                end
            endcase
        end
    end

endmodule
