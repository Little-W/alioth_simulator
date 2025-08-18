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

// 通用寄存器模块 - 支持4路读取和2路写回
module gpr (

    input wire clk,
    input wire rst_n,

    // from wbu - 双写回端口
    input wire                       we1_i,     // 写寄存器1标志
    input wire [`REG_ADDR_WIDTH-1:0] waddr1_i,  // 写寄存器1地址
    input wire [`REG_DATA_WIDTH-1:0] wdata1_i,  // 写寄存器1数据

    input wire                       we2_i,     // 写寄存器2标志
    input wire [`REG_ADDR_WIDTH-1:0] waddr2_i,  // 写寄存器2地址
    input wire [`REG_DATA_WIDTH-1:0] wdata2_i,  // 写寄存器2数据

    // from icu - 4路读取端口 (inst1的rs1, rs2和inst2的rs1, rs2)
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rs1_raddr_i,  // 读寄存器1地址 (inst1_rs1)
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rs2_raddr_i,  // 读寄存器2地址 (inst1_rs2)
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rs1_raddr_i,  // 读寄存器3地址 (inst2_rs1)
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rs2_raddr_i,  // 读寄存器4地址 (inst2_rs2)

    // to icu - 4路读取输出
    output wire [`REG_DATA_WIDTH-1:0] inst1_rs1_rdata_o,  // 读寄存器1数据 (inst1_rs1)
    output wire [`REG_DATA_WIDTH-1:0] inst1_rs2_rdata_o,  // 读寄存器2数据 (inst1_rs2)
    output wire [`REG_DATA_WIDTH-1:0] inst2_rs1_rdata_o,  // 读寄存器3数据 (inst2_rs1)
    output wire [`REG_DATA_WIDTH-1:0] inst2_rs2_rdata_o   // 读寄存器4数据 (inst2_rs2)

);

    wire [`REG_DATA_WIDTH-1:0] regs[0:`REG_NUM - 1];
    wire [`REG_NUM-1:0] reg_we;  // 每个寄存器的写使能信号

    // 为每个寄存器生成写使能信号
    // 零寄存器(x0)永远不能被写入
    assign reg_we[0] = 1'b0;

    // 为其他寄存器生成写使能信号
    genvar i;
    generate
        for (i = 1; i < `REG_NUM; i = i + 1) begin : gen_reg_we
            // 双写回端口的写使能逻辑
            assign reg_we[i] = ((we1_i && (waddr1_i == i)) || (we2_i && (waddr2_i == i))) && rst_n;
        end
    endgenerate

    // 为每个寄存器选择写数据
    // 如果两个写端口同时写同一个寄存器，优先选择端口1
    wire [`REG_DATA_WIDTH-1:0] write_data[0:`REG_NUM - 1];
    generate
        for (i = 0; i < `REG_NUM; i = i + 1) begin : gen_write_data
            assign write_data[i] = (we1_i && (waddr1_i == i)) ? wdata1_i : wdata2_i;
        end
    endgenerate

    generate
        for (i = 0; i < `REG_NUM; i = i + 1) begin : gen_regs
            gnrl_dfflr #(
                .DW(`REG_DATA_WIDTH)
            ) reg_dfflr (
                .clk(clk),
                .rst_n(rst_n),
                .lden(reg_we[i]),
                .dnxt(write_data[i]),
                .qout(regs[i])
            );
        end
    endgenerate

    // 4路读寄存器输出 (同周期写前递逻辑)
    assign inst1_rs1_rdata_o = (inst1_rs1_raddr_i == `ZeroReg) ? `ZeroWord :
                               ((inst1_rs1_raddr_i == waddr1_i) && (we1_i == `WriteEnable)) ? wdata1_i : regs[inst1_rs1_raddr_i];
    assign inst1_rs2_rdata_o = (inst1_rs2_raddr_i == `ZeroReg) ? `ZeroWord :
                               ((inst1_rs2_raddr_i == waddr1_i) && (we1_i == `WriteEnable)) ? wdata1_i : regs[inst1_rs2_raddr_i];
    assign inst2_rs1_rdata_o = (inst2_rs1_raddr_i == `ZeroReg) ? `ZeroWord :
                               ((inst2_rs1_raddr_i == waddr2_i) && (we2_i == `WriteEnable)) ? wdata2_i : regs[inst2_rs1_raddr_i];
    assign inst2_rs2_rdata_o = (inst2_rs2_raddr_i == `ZeroReg) ? `ZeroWord :
                               ((inst2_rs2_raddr_i == waddr2_i) && (we2_i == `WriteEnable)) ? wdata2_i : regs[inst2_rs2_raddr_i];

endmodule
