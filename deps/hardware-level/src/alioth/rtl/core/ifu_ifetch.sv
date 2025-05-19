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

// 将指令向译码模块传递
module ifu_ifetch (

    input wire clk,
    input wire rst_n,

    input wire [`INST_DATA_WIDTH-1:0] inst_i,      // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i, // 指令地址

    input wire [`HOLD_BUS_WIDTH-1:0] hold_flag_i,  // 流水线暂停标志

    output wire [`INST_DATA_WIDTH-1:0] inst_o,      // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o  // 指令地址

);

    wire flush_en = (hold_flag_i >= `Hold_If);
    wire flush_en_r;
    gnrl_dff #(1) flush_en_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (flush_en),
        .qout (flush_en_r)
    );

    assign inst_o = flush_en_r ? `INST_NOP : inst_i;

    wire [`INST_ADDR_WIDTH-1:0] inst_addr;
    // 选择指令地址：如果暂停则选择ZeroWord，否则选择输入地址
    wire [`INST_ADDR_WIDTH-1:0] addr_selected = flush_en ? `ZeroWord : inst_addr_i;

    gnrl_dff #(`INST_ADDR_WIDTH) inst_addr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (addr_selected),
        .qout (inst_addr)
    );
    assign inst_addr_o = inst_addr;

endmodule
