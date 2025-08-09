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
module ifu_ifetch (

    input wire clk,
    input wire rst_n,

    input wire                        jump_flag_i,   // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,   // 跳转地址
    input wire                        stall_pc_i,    // PC暂停信号
    input wire                        axi_arready_i, // AXI读地址通道准备好信号

    output wire [`INST_ADDR_WIDTH-1:0] pc_o,  // PC指针
    // 新增输出：非对齐取指信号
    output wire pc_misaligned_o
);

    // 下一个PC值
    wire [`INST_ADDR_WIDTH-1:0] pc_nxt;

    // 计算实际的PC暂停信号：原有暂停信号或AXI未就绪
    wire                        stall_pc_actual = stall_pc_i || !axi_arready_i;

    // 根据控制信号计算下一个PC值
    assign pc_nxt = (!rst_n) ? `PC_RESET_ADDR :  // 复位
        (jump_flag_i == `JumpEnable) ? jump_addr_i :  // 跳转
        (stall_pc_actual) ? pc_o :  // 暂停（包括AXI未就绪的情况）
        pc_o + 4'h8;  // 地址加8

    // 64位访存中的PC对齐判断：检查PC[2]，因为64位访存时PC[2:0]中只有PC[2]有意义
    // PC[2]=0: 指令在低32位, PC[2]=1: 指令在高32位
    assign pc_misaligned_o = pc_o[2];

    // 使用gnrl_dff模块实现PC寄存器
    gnrl_dff #(
        .DW(`INST_ADDR_WIDTH)
    ) pc_dff (
        .clk  (clk),
        .rst_n(1'b1),  // 不需要复位
        .dnxt (pc_nxt),
        .qout (pc_o)
    );

endmodule
