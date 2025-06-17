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

// 控制模块
// 发出跳转、暂停流水线信号
module ctrl (

    input wire rst_n,

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        hold_flag_ex_i,

    // from clint
    input wire hold_flag_clint_i,

    // from hdu
    input wire hold_flag_hdu_i,

    output wire [`HOLD_BUS_WIDTH-1:0] hold_flag_o,

    // to pc_reg
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o

);

    assign jump_addr_o = jump_addr_i;
    assign jump_flag_o = jump_flag_i & ~hold_flag_ex_i & ~hold_flag_hdu_i & ~hold_flag_clint_i;

    assign hold_flag_o = (hold_flag_ex_i == `HoldEnable || hold_flag_hdu_i == `HoldEnable) ? `Hold_Id :
                         (jump_flag_i == `JumpEnable || hold_flag_clint_i == `HoldEnable) ? `Hold_Flush:
                         `Hold_None;

endmodule
