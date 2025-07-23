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

    input wire clk,
    input wire rst_n,

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        stall_flag_ex_i,
    input wire                        atom_opt_busy_i,  // 原子操作忙信号

    // from clint
    input wire flush_flag_clint_i,  // 添加中断刷新信号输入
    input wire stall_flag_clint_i,

    // from hdu
    input wire stall_flag_hdu_i,

    output wire [`CU_BUS_WIDTH-1:0] stall_flag_o,

    // to pc_reg
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o

);

    // 复合暂停信号 - 合并所有暂停条件
    wire any_stall = stall_flag_ex_i | stall_flag_hdu_i | stall_flag_clint_i;

    wire none_data_hazard_stall = stall_flag_ex_i | stall_flag_clint_i;

    // 原子操作相关的暂停条件
    wire atom_stall = atom_opt_busy_i & jump_flag_i;

    // 简化的跳转输出逻辑
    assign jump_addr_o = jump_addr_i;
    assign jump_flag_o = jump_flag_i & ~none_data_hazard_stall;

    // 更新暂停标志输出，区分stall和flush
    assign stall_flag_o[`CU_STALL] = stall_flag_ex_i | (stall_flag_hdu_i & ~jump_flag_i) | stall_flag_clint_i;
    assign stall_flag_o[`CU_FLUSH] = jump_flag_i | flush_flag_clint_i;
    assign stall_flag_o[`CU_STALL_DISPATCH] = none_data_hazard_stall;

endmodule
