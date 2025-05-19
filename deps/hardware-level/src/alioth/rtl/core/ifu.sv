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

// 指令获取模块(顶层)
module ifu (

    input wire clk,
    input wire rst_n,

    // 来自控制模块
    input wire                        jump_flag_i,  // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,  // 跳转地址
    input wire [   `HOLD_BUS_WIDTH-1:0] hold_flag_i,  // 流水线暂停标志

    // 从ROM读取的指令
    input wire [`INST_DATA_WIDTH-1:0] inst_i,  // 指令内容

    // 输出到ROM的地址
    output wire [`INST_ADDR_WIDTH-1:0] pc_o,  // PC指针

    // 输出到ID阶段的信息
    output wire [`INST_DATA_WIDTH-1:0] inst_o,      // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o  // 指令地址
);

    // 实例化PC寄存器模块
    ifu_pc_nxt u_ifu_pc_nxt (
        .clk        (clk),
        .rst_n      (rst_n),
        .jump_flag_i(jump_flag_i),
        .jump_addr_i(jump_addr_i),
        .hold_flag_i(hold_flag_i),
        .pc_o       (pc_o)
    );

    // 实例化IF/ID模块
    ifu_ifetch u_ifu_ifetch (
        .clk        (clk),
        .rst_n      (rst_n),
        .inst_i     (inst_i),
        .inst_addr_i(pc_o),
        .hold_flag_i(hold_flag_i),
        .inst_o     (inst_o),
        .inst_addr_o(inst_addr_o)
    );

endmodule
