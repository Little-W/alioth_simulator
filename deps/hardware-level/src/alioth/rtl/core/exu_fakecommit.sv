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

// 伪提交单元 - 用于处理inst1跳转同时inst2的伪提交-防止hdu中FIFO卡死
module exu_fakecommit (
    input wire clk,
    input wire rst_n,

    // 来自dispatch的输入信号
    input wire                        req_fakecommit_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 握手信号
    input  wire wb_ready_i,      // 写回单元准备好接收伪提交结果

    // 中断信号
    input wire int_assert_i,

    // 结果输出到WBU
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 握手信号控制逻辑
    wire update_output = wb_ready_i | ~reg_we_o;

    // 写回数据逻辑
    wire [`REG_DATA_WIDTH-1:0] fake_wdata = (int_assert_i) ? '0 : (req_fakecommit_i ? '0 : '0);
    wire                        fake_we    = (int_assert_i) ? 1'b0 : (req_fakecommit_i ? 1'b1 : 1'b0);
    wire [`REG_ADDR_WIDTH-1:0]  fake_waddr = (int_assert_i) ? {`REG_ADDR_WIDTH{1'b0}} : (req_fakecommit_i ? `ZeroReg : {`REG_ADDR_WIDTH{1'b0}});
    wire [`COMMIT_ID_WIDTH-1:0] fake_commit_id = (int_assert_i) ? {`COMMIT_ID_WIDTH{1'b0}} : (req_fakecommit_i ? commit_id_i : {`COMMIT_ID_WIDTH{1'b0}});

    // 输出级寄存器
    wire [`REG_DATA_WIDTH-1:0] reg_wdata_r;
    wire                        reg_we_r;
    wire [`REG_ADDR_WIDTH-1:0]  reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_r;

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) u_wdata_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fake_wdata),
        .qout (reg_wdata_r)
    );

    gnrl_dfflr #(
        .DW(1)
    ) u_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fake_we),
        .qout (reg_we_r)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) u_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fake_waddr),
        .qout (reg_waddr_r)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) u_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fake_commit_id),
        .qout (commit_id_r)
    );

    assign reg_wdata_o = reg_wdata_r;
    assign reg_we_o    = reg_we_r;
    assign reg_waddr_o = reg_waddr_r;
    assign commit_id_o = commit_id_r;
endmodule

