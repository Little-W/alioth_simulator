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

// 将指令向译码模块传递
module ifu_pipe (

    input wire clk,
    input wire rst_n,

    input wire [`INST_DATA_WIDTH-1:0] inst_i,            // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,       // 指令地址
    input wire                        is_pred_branch_i,  // 是否为预测分支指令
    input wire                        is_pred_jalr_i,    // 是否为预测JALR指令
    input wire [`INST_ADDR_WIDTH-1:0] branch_addr_i,     // 预测的分支地址

    input wire flush_flag_i,  // 流水线冲刷标志
    input wire inst_valid_i,  // 指令有效信号
    input wire stall_i,       // 保持信号，为1时触发器保持不更新

    output wire [`INST_DATA_WIDTH-1:0] inst_o,            // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,       // 指令地址
    output wire                        is_pred_branch_o,  // 输出到ID/EXU的预测分支标志
    output wire                        is_pred_jalr_o,    // 输出到ID/EXU的预测JALR标志
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o      // 输出到ID/EXU的预测分支地址
);

    // 直接使用flush_flag_i，不再寄存
    wire                        flush_en = flush_flag_i;

    // 在指令无效或冲刷信号有效时，选择 NOP 作为寄存器输入
    wire [`INST_DATA_WIDTH-1:0] inst_selected = (flush_en || !inst_valid_i) ? `INST_NOP : inst_i;

    // 储存指令内容
    wire [`INST_DATA_WIDTH-1:0] inst_r;
    gnrl_dfflr #(`INST_DATA_WIDTH) inst_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (inst_selected),
        .qout (inst_r)
    );

    // 直接输出寄存器内容
    assign inst_o = inst_r;

    wire [`INST_ADDR_WIDTH-1:0] inst_addr;
    // 选择指令地址：如果需要冲刷水线则选择ZeroWord，否则选择输入地址
    wire [`INST_ADDR_WIDTH-1:0] addr_selected = flush_en ? `ZeroWord : inst_addr_i;

    gnrl_dfflr #(`INST_ADDR_WIDTH) inst_addr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (addr_selected),
        .qout (inst_addr)
    );
    assign inst_addr_o = inst_addr;

    // 寄存预测分支指令标志
    wire is_pred_branch_r;
    gnrl_dfflr #(1) is_pred_branch_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),                            // 当stall_i为1时不更新
        .dnxt (flush_en ? 1'b0 : is_pred_branch_i),
        .qout (is_pred_branch_r)
    );
    assign is_pred_branch_o = is_pred_branch_r;

    // 寄存预测JALR指令标志
    wire is_pred_jalr_r;
    gnrl_dfflr #(1) is_pred_jalr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),                          // 当stall_i为1时不更新
        .dnxt (flush_en ? 1'b0 : is_pred_jalr_i),
        .qout (is_pred_jalr_r)
    );
    assign is_pred_jalr_o = is_pred_jalr_r;

    // 寄存预测分支地址
    wire [`INST_ADDR_WIDTH-1:0] branch_addr_r;
    gnrl_dfflr #(`INST_ADDR_WIDTH) branch_addr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),                              // 当stall_i为1时不更新
        .dnxt (flush_en ? `ZeroWord : branch_addr_i),
        .qout (branch_addr_r)
    );
    assign branch_addr_o = branch_addr_r;

endmodule
