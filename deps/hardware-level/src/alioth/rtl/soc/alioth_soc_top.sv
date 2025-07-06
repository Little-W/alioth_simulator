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

`include "../core/defines.svh"

// alioth soc顶层模块
module alioth_soc_top (

    input wire clk,
    input wire rst_n,

    // 外设相关引脚
    input  wire        cnt_clk,             // 计数器时钟
    input  wire [63:0] virtual_sw_input,    // 虚拟开关输入
    input  wire [ 7:0] virtual_key_input,   // 虚拟按键输入
    output wire [39:0] virtual_seg_output,  // 虚拟七段显示器输出
    output wire [31:0] virtual_led_output   // 虚拟LED输出
);

    // alioth处理器核模块例化
    cpu_top u_cpu_top (
        .clk  (clk),
        .rst_n(rst_n),

        // 外设相关引脚连接
        .virtual_sw_input  (virtual_sw_input),
        .virtual_key_input (virtual_key_input),
        .virtual_seg_output(virtual_seg_output),
        .virtual_led_output(virtual_led_output)
    );
endmodule
