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

// 寄存器写回FIFO模块 - 用于缓冲写回数据
module reg_wb_fifo #(
    parameter FIFO_DEPTH = 2
) (
    input wire clk,
    input wire rst_n,

    // 输入端口
    input wire [`REG_DATA_WIDTH-1:0] wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 控制信号
    input wire push,  // 推入使能
    input wire pop,   // 弹出使能

    // 输出端口
    output wire [`REG_DATA_WIDTH-1:0] wdata_o,
    output wire [`REG_ADDR_WIDTH-1:0] waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,

    // 状态信号
    output wire full,
    output wire empty,
    output wire [$clog2(FIFO_DEPTH):0] count
);

    // 内部数据结构
    typedef struct packed {
        logic [`REG_DATA_WIDTH-1:0] wdata;
        logic [`REG_ADDR_WIDTH-1:0] waddr;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
    } reg_entry_t;

    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);

    // FIFO存储
    reg_entry_t fifo_mem [0:FIFO_DEPTH-1];
    reg [FIFO_PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    reg [FIFO_PTR_WIDTH:0] entry_count;

    // 操作控制
    wire [1:0] fifo_op = {push, pop};

    // FIFO操作逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            entry_count <= '0;
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                fifo_mem[i] <= '0;
            end
        end else begin
            case (fifo_op)
                2'b10: begin  // 只推入
                    if (!full) begin
                        fifo_mem[wr_ptr] <= '{
                            wdata: wdata_i,
                            waddr: waddr_i,
                            commit_id: commit_id_i
                        };
                        wr_ptr <= wr_ptr + 1'd1;
                        entry_count <= entry_count + 1'd1;
                    end
                end
                2'b01: begin  // 只弹出
                    if (!empty) begin
                        rd_ptr <= rd_ptr + 1'd1;
                        entry_count <= entry_count - 1'd1;
                    end
                end
                2'b11: begin  // 同时推入和弹出
                    if (!empty) begin
                        fifo_mem[wr_ptr] <= '{
                            wdata: wdata_i,
                            waddr: waddr_i,
                            commit_id: commit_id_i
                        };
                        wr_ptr <= wr_ptr + 1'd1;
                        rd_ptr <= rd_ptr + 1'd1;
                        // entry_count保持不变
                    end
                end
                default: begin  // 2'b00: 无操作
                    // 保持当前状态
                end
            endcase
        end
    end

    // 状态信号
    assign full = (entry_count == FIFO_DEPTH);
    assign empty = (entry_count == 0);
    assign count = entry_count;

    // 输出信号
    assign wdata_o = empty ? '0 : fifo_mem[rd_ptr].wdata;
    assign waddr_o = empty ? '0 : fifo_mem[rd_ptr].waddr;
    assign commit_id_o = empty ? '0 : fifo_mem[rd_ptr].commit_id;

endmodule
