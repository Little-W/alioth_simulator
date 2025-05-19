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

// 带使能信号的D触发器
module gnrl_dfflr #(
    parameter DW = 32
) (

    input clk,
    input rst_n,

    input           lden,  // 使能信号
    input  [DW-1:0] dnxt,  // 下一个数据
    output [DW-1:0] qout   // 输出数据
);

    reg [DW-1:0] qout_r;

    always @(posedge clk) begin : DFFLR_PROC
        if (!rst_n) qout_r <= {DW{1'b0}};  // 复位时输出0
        else if (lden) qout_r <= #1 dnxt;  // 使能时更新数据
    end

    assign qout = qout_r;

endmodule

// 无使能信号的D触发器
module gnrl_dff #(
    parameter DW = 32
) (

    input clk,
    input rst_n,

    input  [DW-1:0] dnxt,  // 下一个数据
    output [DW-1:0] qout   // 输出数据
);

    reg [DW-1:0] qout_r;

    always @(posedge clk) begin : DFF_PROC
        if (!rst_n) qout_r <= {DW{1'b0}};  // 复位时输出0
        else qout_r <= #1 dnxt;            // 正常情况下更新数据
    end

    assign qout = qout_r;

endmodule
