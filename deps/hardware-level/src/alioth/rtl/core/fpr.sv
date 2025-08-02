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

// 浮点寄存器模块
module fpr (

    input wire clk,
    input wire rst_n,

    // from ex
    input wire                        we_i,     // 写寄存器标志
    input wire [`FREG_ADDR_WIDTH-1:0] waddr_i,  // 写寄存器地址
    input wire [`FREG_DATA_WIDTH-1:0] wdata_i,  // 写寄存器数据

    // from id
    input wire [`FREG_ADDR_WIDTH-1:0] raddr1_i,  // 读寄存器1地址
    input wire [`FREG_ADDR_WIDTH-1:0] raddr2_i,  // 读寄存器2地址
    input wire [`FREG_ADDR_WIDTH-1:0] raddr3_i,  // 读寄存器3地址

    // to id
    output wire [`FREG_DATA_WIDTH-1:0] rdata1_o,  // 读寄存器1数据
    output wire [`FREG_DATA_WIDTH-1:0] rdata2_o,  // 读寄存器2数据
    output wire [`FREG_DATA_WIDTH-1:0] rdata3_o   // 读寄存器3数据

);

    wire [`FREG_DATA_WIDTH-1:0] fregs [0:`REG_NUM - 1];
    wire [        `REG_NUM-1:0] reg_we;  // 每个寄存器的写使能信号

    // 为每个寄存器生成写使能信号
    genvar i;
    generate
        for (i = 0; i < `REG_NUM; i = i + 1) begin : gen_reg_we
            assign reg_we[i] = (we_i == `WriteEnable) && (waddr_i == i) && rst_n;
        end
    endgenerate

    generate
        for (i = 0; i < `REG_NUM; i = i + 1) begin : gen_fregs
            gnrl_dfflr #(
                .DW(`FREG_DATA_WIDTH)
            ) reg_dfflr (
                .clk  (clk),
                .rst_n(rst_n),
                .lden (reg_we[i]),
                .dnxt (wdata_i),
                .qout (fregs[i])
            );
        end
    endgenerate

    // 读寄存器1
    assign rdata1_o = ((raddr1_i == waddr_i) && (we_i == `WriteEnable)) ? wdata_i :
                      fregs[raddr1_i];

    // 读寄存器2
    assign rdata2_o = ((raddr2_i == waddr_i) && (we_i == `WriteEnable)) ? wdata_i :
                      fregs[raddr2_i];

    // 读寄存器3
    assign rdata3_o = ((raddr3_i == waddr_i) && (we_i == `WriteEnable)) ? wdata_i :
                      fregs[raddr3_i];

endmodule
