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
    input  wire [ `REG_DATA_WIDTH-1:0] alu_reg_wdata_i,
    input  wire                        alu_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu_commit_id_i,  // ALU指令ID
    output wire                        alu_ready_o,      // ALU握手信号

    // 来自EXU的乘法数据
    input  wire [ `REG_DATA_WIDTH-1:0] mul_reg_wdata_i,
    input  wire                        mul_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul_commit_id_i,  // 乘法指令ID
    output wire                        mul_ready_o,      // MUL握手信号

    // 来自EXU的除法数据
    input  wire [ `REG_DATA_WIDTH-1:0] div_reg_wdata_i,
    input  wire                        div_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div_commit_id_i,  // 除法指令ID
    output wire                        div_ready_o,      // DIV握手信号

    // 来自EXU的CSR数据
    input  wire [ `REG_DATA_WIDTH-1:0] csr_wdata_i,
    input  wire                        csr_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_i,  // CSR指令ID
    output wire                        csr_ready_o,      // CSR握手信号

    // CSR寄存器写数据输入
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,  // 保留寄存器写地址输入
    input wire                       csr_reg_we_i,     // 新增：csr写回使能输入

    // 来自EXU的lsu/LSU数据
    input wire [ `REG_DATA_WIDTH-1:0] lsu_reg_wdata_i,
    input wire                        lsu_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_i,  // LSU指令ID，修改为3位

    input wire [`REG_ADDR_WIDTH-1:0] idu_reg_waddr_i,

    // 长指令完成信号（对接hazard_detection）
    output wire                        commit_valid_o,  // 指令完成有效信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,     // 完成指令ID

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
    wire lsu_active = lsu_reg_we_i;
    wire mul_active = mul_reg_we_i;
    wire div_active = div_reg_we_i;
    wire csr_active = csr_reg_we_i;
    wire alu_active = alu_reg_we_i;

    // 根据优先级判断冲突
    wire mul_conflict = lsu_active && mul_active;
    wire div_conflict = (lsu_active || mul_active) && div_active;
    wire csr_conflict = (lsu_active || mul_active || div_active) && csr_active && (~csr_reg_we_i);
    wire alu_conflict = (lsu_active || mul_active || div_active || csr_active) && alu_active;

    // 各单元ready信号，当无冲突或者是最高优先级时为1
    assign mul_ready_o = !mul_conflict;
    assign div_ready_o = !div_conflict;
    assign csr_ready_o = !csr_conflict;
    assign alu_ready_o = !alu_conflict;

    // 定义各单元的最终使能信号
    wire                        lsu_en = lsu_active;
    wire                        mul_en = mul_active && !mul_conflict;
    wire                        div_en = div_active && !div_conflict;
    wire                        csr_en = csr_active && !csr_conflict;
    wire                        alu_en = alu_active && !alu_conflict;
    wire                        idu_en = !lsu_en && !mul_en && !div_en && !csr_en && !alu_en;

    // 最终生效的写信号
    wire                        reg_we_effective = (lsu_en || mul_en || div_en || csr_en || alu_en);

    // 写数据和地址多路选择器，使用与或逻辑实现
    wire [ `REG_DATA_WIDTH-1:0] reg_wdata_nxt;
    wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_nxt;
    wire                        reg_we_nxt;
    wire                        commit_valid_nxt;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_nxt;

    assign reg_wdata_nxt = ({`REG_DATA_WIDTH{lsu_en}} & lsu_reg_wdata_i) |
                         ({`REG_DATA_WIDTH{mul_en}} & mul_reg_wdata_i) |
                         ({`REG_DATA_WIDTH{div_en}} & div_reg_wdata_i) |
                         ({`REG_DATA_WIDTH{csr_en}} & csr_reg_wdata_i) |
                         ({`REG_DATA_WIDTH{alu_en}} & alu_reg_wdata_i);

    assign reg_waddr_nxt = ({`REG_ADDR_WIDTH{lsu_en}} & lsu_reg_waddr_i) |
                         ({`REG_ADDR_WIDTH{mul_en}} & mul_reg_waddr_i) |
                         ({`REG_ADDR_WIDTH{div_en}} & div_reg_waddr_i) |
                         ({`REG_ADDR_WIDTH{csr_en}} & csr_reg_waddr_i) |
                         ({`REG_ADDR_WIDTH{alu_en}} & alu_reg_waddr_i) |
                         ({`REG_ADDR_WIDTH{idu_en}} & idu_reg_waddr_i);

    assign reg_we_nxt = reg_we_effective;
    assign commit_valid_nxt = reg_we_nxt;

    assign commit_id_nxt = lsu_active  ? lsu_commit_id_i  :
                         mul_active  ? mul_commit_id_i  :
                         div_active  ? div_commit_id_i  :
                         csr_active  ? csr_commit_id_i  :
                         alu_commit_id_i;

    // === 写回输出一级流水寄存器 ===
    reg [ `REG_DATA_WIDTH-1:0] reg_wdata_ff;
    reg [ `REG_ADDR_WIDTH-1:0] reg_waddr_ff;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_ff;
    reg                        reg_we_ff;
    reg                        commit_valid_ff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_wdata_ff    <= '0;
            reg_waddr_ff    <= '0;
            commit_id_ff    <= '0;
            reg_we_ff       <= 1'b0;
            commit_valid_ff <= 1'b0;
        end else begin
            reg_wdata_ff    <= reg_wdata_nxt;
            reg_waddr_ff    <= reg_waddr_nxt;
            commit_id_ff    <= commit_id_nxt;
            reg_we_ff       <= reg_we_nxt;
            commit_valid_ff <= commit_valid_nxt;
        end
    end

    // 输出到寄存器文件的信号（改为流水寄存器输出）
    assign reg_we_o       = reg_we_ff;
    assign reg_wdata_o    = reg_wdata_ff;
    assign reg_waddr_o    = reg_waddr_ff;

    // CSR写回信号
    assign csr_we_o       = csr_we_i;
    assign csr_wdata_o    = csr_wdata_i;
    assign csr_waddr_o    = csr_waddr_i;

    // 长指令完成信号（改为流水寄存器输出）
    assign commit_valid_o = commit_valid_ff;
    assign commit_id_o    = commit_id_ff;

endmodule
