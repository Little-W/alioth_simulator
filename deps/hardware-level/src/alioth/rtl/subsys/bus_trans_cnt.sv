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

// 事务计数器模块 - 用于跟踪AXI未完成事务
module bus_trans_cnt #(
    parameter int COUNTER_WIDTH = 4  // 计数器位宽
) (
    input  wire clk,
    input  wire rst_n,

    // 事务控制信号
    input  wire transaction_start,  // 事务开始
    input  wire transaction_end,    // 事务结束

    // 输出
    output wire [COUNTER_WIDTH-1:0] outstanding_count,     // 当前未完成事务数
    output wire [COUNTER_WIDTH-1:0] outstanding_count_nxt, // 下一周期未完成事务数
    output wire has_active_transaction,                    // 是否有活跃事务
    output wire has_active_transaction_nxt                 // 下一周期是否有活跃事务
);

    // 计数器更新逻辑
    wire counter_inc = transaction_start & ~transaction_end;
    wire counter_dec = ~transaction_start & transaction_end;
    wire counter_keep = (transaction_start & transaction_end) |
                        (~transaction_start & ~transaction_end);

    assign outstanding_count_nxt =
        ({COUNTER_WIDTH{counter_inc}} & (outstanding_count + {{COUNTER_WIDTH-1{1'b0}}, 1'b1})) |
        ({COUNTER_WIDTH{counter_dec}} & (outstanding_count - {{COUNTER_WIDTH-1{1'b0}}, 1'b1})) |
        ({COUNTER_WIDTH{counter_keep}} & outstanding_count);

    // 活跃事务标志
    assign has_active_transaction = outstanding_count > 0;
    assign has_active_transaction_nxt = outstanding_count_nxt > 0;

    // 计数器寄存器
    gnrl_dfflr #(
        .DW(COUNTER_WIDTH)
    ) counter_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (outstanding_count_nxt),
        .qout (outstanding_count)
    );

endmodule