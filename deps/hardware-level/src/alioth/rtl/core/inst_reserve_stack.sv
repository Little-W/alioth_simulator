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

// 保留栈FIFO模块 - 用于暂存idu输入信号
module inst_reserve_stack #(
    parameter FIFO_DEPTH = 4
) (
    input wire clk,
    input wire rst_n,

    // FIFO控制信号
    input  wire push_req_i,
    input  wire fifo_stall_i,
    input  wire fifo_flush_i,
    output wire fifo_full_o,

    // from if_id
    input wire [`INST_DATA_WIDTH-1:0] inst_i,            // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 指令地址
    input wire                        is_pred_branch_i,  // 预测分支指令标志
    input wire                        inst_valid_i,      // 指令有效

    // 输出信号组
    output wire [`INST_DATA_WIDTH-1:0] inst_o,
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,
    output wire                        is_pred_branch_o,
    output wire                        inst_valid_o
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

    // 打包输入数据结构
    typedef struct packed {
        logic [`INST_DATA_WIDTH-1:0] inst;
        logic [`INST_ADDR_WIDTH-1:0] inst_addr;
        logic                        is_pred_branch;
        logic                        inst_valid;
    } fifo_data_t;

    // FIFO存储器
    fifo_data_t fifo_mem   [FIFO_DEPTH-1:0];

    // 输入数据打包
    fifo_data_t input_data;
    assign input_data.inst           = inst_i;
    assign input_data.inst_addr      = inst_addr_i;
    assign input_data.is_pred_branch = is_pred_branch_i;
    assign input_data.inst_valid     = inst_valid_i;

    // FIFO输出数据
    fifo_data_t output_data;

    // 输出逻辑：FIFO为空时直连输入，否则输出FIFO数据
    assign output_data      = fifo_empty ? input_data : fifo_mem[rd_ptr];

    // 解包输出数据
    assign inst_o           = output_data.inst;
    assign inst_addr_o      = output_data.inst_addr;
    assign is_pred_branch_o = output_data.is_pred_branch;
    assign inst_valid_o     = output_data.inst_valid;

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
