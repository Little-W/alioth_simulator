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
    input wire rst_n,

    // 指令和操作数输入
    input wire                       req_csr_i,
    input wire [               31:0] csr_op1_i,
    input wire [               31:0] csr_addr_i,
    input wire                       csr_csrrw_i,
    input wire                       csr_csrrs_i,
    input wire                       csr_csrrc_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,

    // 中断信号
    input wire int_assert_i,

    // CSR写数据输出
    output reg [`REG_DATA_WIDTH-1:0] csr_wdata_o,

    // 寄存器写回数据
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o
);  // CSR处理单元逻辑
    always @(*) begin
        // 默认值
        csr_wdata_o = `ZeroWord;
        reg_wdata_o = `ZeroWord;

        // 响应中断时不进行CSR操作
        if (int_assert_i == `INT_ASSERT) begin
            // 不执行任何操作
        end else if (req_csr_i) begin
            reg_wdata_o = csr_rdata_i;  // 所有CSR指令都将CSR的值读出来放入目标寄存器

            // 使用并行选择逻辑实现CSR写入值的计算
            csr_wdata_o = ({`REG_DATA_WIDTH{csr_csrrw_i}} & csr_op1_i) |
                          ({`REG_DATA_WIDTH{csr_csrrs_i}} & (csr_op1_i | csr_rdata_i)) |
                          ({`REG_DATA_WIDTH{csr_csrrc_i}} & (csr_rdata_i & (~csr_op1_i)));
        end
    end

endmodule
