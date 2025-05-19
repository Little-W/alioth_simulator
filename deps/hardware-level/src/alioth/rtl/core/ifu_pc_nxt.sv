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

// PC寄存器模块
module ifu_pc_nxt (

    input wire clk,
    input wire rst_n,

    input wire                        jump_flag_i,  // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,  // 跳转地址
    input wire [ `HOLD_BUS_WIDTH-1:0] hold_flag_i,  // 流水线暂停标志

    output wire [`INST_ADDR_WIDTH-1:0] pc_o  // PC指针

);

    // 下一个PC值
    wire [`INST_ADDR_WIDTH-1:0] pc_nxt;

    // 根据控制信号计算下一个PC值
    assign pc_nxt = (rst_n == `RstEnable) ? `CpuResetAddr :  // 复位
        (jump_flag_i == `JumpEnable) ? jump_addr_i :  // 跳转
        (hold_flag_i >= `Hold_Pc) ? pc_o :  // 暂停
        pc_o + 4'h4;  // 地址加4

    // 使用gnrl_dff模块实现PC寄存器
    gnrl_dff #(
        .DW(`INST_ADDR_WIDTH)
    ) pc_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (pc_nxt),
        .qout (pc_o)
    );

endmodule
