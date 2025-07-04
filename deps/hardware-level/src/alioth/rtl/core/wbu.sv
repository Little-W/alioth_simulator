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

// 写回单元 - 负责寄存器写回逻辑和仲裁优先级
module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ALU数据
    input  wire [`REG_DATA_WIDTH-1:0] alu_reg_wdata_i,
    input  wire                       alu_reg_we_i,
    input  wire [`REG_ADDR_WIDTH-1:0] alu_reg_waddr_i,
    output wire                       alu_ready_o,      // ALU握手信号

    // 来自EXU的MULDIV数据
    input  wire [`REG_DATA_WIDTH-1:0] muldiv_reg_wdata_i,
    input  wire                       muldiv_reg_we_i,
    input  wire [`REG_ADDR_WIDTH-1:0] muldiv_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] muldiv_inst_id_i,    // 乘除法指令ID，使用COMMIT_ID_WIDTH宏
    output wire                       muldiv_ready_o,      // MULDIV握手信号

    // 来自EXU的CSR数据
    input  wire [`REG_DATA_WIDTH-1:0] csr_wdata_i,
    input  wire                       csr_we_i,
    input  wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    output wire                       csr_ready_o,  // CSR握手信号

    // CSR寄存器写数据输入
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,  // 保留寄存器写地址输入

    // 来自EXU的AGU/LSU数据
    input wire [`REG_DATA_WIDTH-1:0] agu_reg_wdata_i,
    input wire                       agu_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] agu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] agu_inst_id_i,    // LSU指令ID，使用COMMIT_ID_WIDTH宏

    input wire [`REG_ADDR_WIDTH-1:0] idu_reg_waddr_i,

    // 中断信号
    input wire int_assert_i,

    // 长指令完成信号（对接hazard_detection）
    output wire                        commit_valid_o,  // 指令完成有效信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,     // 完成指令ID，使用COMMIT_ID_WIDTH宏

    // 寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,

    // CSR寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o
);

    // 确定各单元活动状态
    wire agu_active = agu_reg_we_i;
    wire muldiv_active = muldiv_reg_we_i;
    wire csr_active = csr_we_i;
    wire alu_active = alu_reg_we_i;

    // 根据优先级判断冲突
    wire muldiv_conflict = agu_active && muldiv_active;
    wire csr_conflict = (agu_active || muldiv_active) && csr_active;
    wire alu_conflict = (agu_active || muldiv_active || csr_active) && alu_active;

    // 各单元ready信号，当无冲突或者是最高优先级时为1
    assign muldiv_ready_o = !muldiv_conflict;
    assign csr_ready_o    = !csr_conflict;
    assign alu_ready_o    = !alu_conflict;

    // 定义各单元的最终使能信号
    wire agu_en = agu_active;
    wire muldiv_en = muldiv_active && !muldiv_conflict;
    wire csr_en = csr_active && !csr_conflict;
    wire alu_en = alu_active && !alu_conflict;
    wire idu_en = !agu_en && !muldiv_en && !csr_en && !alu_en;

    // 最终生效的写信号
    wire reg_we_effective = (int_assert_i != `INT_ASSERT) && (agu_en || muldiv_en || csr_en || alu_en);

    // 写数据和地址多路选择器，使用与或逻辑实现
    wire [`REG_DATA_WIDTH-1:0] reg_wdata_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;

    // 使用与或结构简化数据选择逻辑
    assign reg_wdata_r = ({`REG_DATA_WIDTH{agu_en}} & agu_reg_wdata_i) |
                        ({`REG_DATA_WIDTH{muldiv_en}} & muldiv_reg_wdata_i) |
                        ({`REG_DATA_WIDTH{csr_en}} & csr_reg_wdata_i) |
                        ({`REG_DATA_WIDTH{alu_en}} & alu_reg_wdata_i);

    assign reg_waddr_r = ({`REG_ADDR_WIDTH{agu_en}} & agu_reg_waddr_i) |
                        ({`REG_ADDR_WIDTH{muldiv_en}} & muldiv_reg_waddr_i) |
                        ({`REG_ADDR_WIDTH{csr_en}} & csr_reg_waddr_i) |
                        ({`REG_ADDR_WIDTH{alu_en}} & alu_reg_waddr_i) |
                        ({`REG_ADDR_WIDTH{idu_en}} & idu_reg_waddr_i);

    // 输出到寄存器文件的信号
    assign reg_we_o = reg_we_effective;
    assign reg_wdata_o = reg_wdata_r;
    assign reg_waddr_o = reg_waddr_r;

    // CSR写回信号
    assign csr_we_o = (int_assert_i != `INT_ASSERT) && csr_active && !csr_conflict;
    assign csr_wdata_o = csr_wdata_i;
    assign csr_waddr_o = csr_waddr_i;

    // 长指令完成信号（对接hazard_detection）
    assign commit_valid_o = (muldiv_active || agu_active) && (int_assert_i != `INT_ASSERT);
    assign commit_id_o = agu_active ? agu_inst_id_i : muldiv_inst_id_i;

endmodule
