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

// CSR处理单元 - 处理CSR寄存器操作
module exu_csr_unit (
    input wire clk,   // 添加时钟信号
    input wire rst_n,

    // 指令和操作数输入
    input wire                       req_csr_i,
    input wire [               31:0] csr_op1_i,
    input wire [               31:0] csr_addr_i,
    input wire                       csr_csrrw_i,
    input wire                       csr_csrrs_i,
    input wire                       csr_csrrc_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,

    // 从ID/EX阶段传入的CSR控制信号
    input wire                       csr_we_i,    // CSR寄存器写使能信号
    input wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_i, // CSR寄存器写地址

    // 寄存器写地址输入
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,  // 寄存器写地址输入

    // 握手信号和控制
    input  wire wb_ready_i,  // 写回单元准备好接收CSR结果
    output wire csr_hold_o,  // CSR暂停信号

    // 中断信号
    input wire int_assert_i,

    // CSR写数据输出 - 完整输出所有CSR相关信号
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,  // CSR写数据
    output wire                       csr_we_o,     // CSR写使能
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,  // CSR写地址

    // 寄存器写回数据 - 用于对通用寄存器的写回
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o   // 寄存器写地址输出
);
    // CSR处理单元逻辑 - 组合逻辑部分
    reg [`REG_DATA_WIDTH-1:0] csr_wdata_comb;
    reg [`REG_DATA_WIDTH-1:0] reg_wdata_comb;

    always @(*) begin
        // 默认值
        csr_wdata_comb = `ZeroWord;
        reg_wdata_comb = `ZeroWord;

        // 响应中断时不进行CSR操作
        if (int_assert_i == `INT_ASSERT) begin
            // 不执行任何操作
        end else if (req_csr_i) begin
            reg_wdata_comb = csr_rdata_i;  // 所有CSR指令都将CSR的值读出来放入目标寄存器

            // 使用并行选择逻辑实现CSR写入值的计算
            csr_wdata_comb = ({`REG_DATA_WIDTH{csr_csrrw_i}} & csr_op1_i) |
                          ({`REG_DATA_WIDTH{csr_csrrs_i}} & (csr_op1_i | csr_rdata_i)) |
                          ({`REG_DATA_WIDTH{csr_csrrc_i}} & (csr_rdata_i & (~csr_op1_i)));
        end
    end

    // 握手信号控制逻辑
    wire valid_csr_op = req_csr_i & (int_assert_i != `INT_ASSERT);  // 当前有有效的CSR操作
    wire update_output = wb_ready_i;  // 仅在有有效CSR操作且ready时更新输出

    // 握手失败时输出hold信号
    assign csr_hold_o = csr_we_o & ~wb_ready_i;

    // CSR写使能输出 - 只有在没有中断时才使能
    wire                       csr_we_comb = (int_assert_i == `INT_ASSERT) ? 1'b0 : csr_we_i;

    // 使用gnrl_dfflr实例化输出级寄存器
    wire [`REG_DATA_WIDTH-1:0] csr_wdata_r;
    wire [`REG_DATA_WIDTH-1:0] reg_wdata_r;
    wire                       csr_we_r;
    wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;

    // CSR写数据寄存器
    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) u_csr_wdata_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (csr_wdata_comb),
        .qout (csr_wdata_r)
    );

    // 寄存器写回数据寄存器
    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) u_r_wdata_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (reg_wdata_comb),
        .qout (reg_wdata_r)
    );

    // CSR写使能寄存器
    gnrl_dfflr #(
        .DW(1)
    ) u_csr_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (csr_we_comb),
        .qout (csr_we_r)
    );

    // CSR写地址寄存器
    gnrl_dfflr #(
        .DW(`BUS_ADDR_WIDTH)
    ) u_csr_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (csr_waddr_i),
        .qout (csr_waddr_r)
    );

    // 寄存器写地址寄存器
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) u_reg_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (reg_waddr_i),
        .qout (reg_waddr_r)
    );

    // 输出信号赋值
    assign csr_wdata_o = csr_wdata_r;
    assign reg_wdata_o = reg_wdata_r;
    assign csr_we_o    = csr_we_r;
    assign csr_waddr_o = csr_waddr_r;
    assign reg_waddr_o = reg_waddr_r;

endmodule
