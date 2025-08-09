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

    input wire [31:0] inst1_i,      // 第一条指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i, // 第一条指令地址
    input wire [31:0] inst2_i,      // 第二条指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i, // 第二条指令地址
    input wire                        is_pred_branch1_i, // 第一条指令是否为预测分支指令
    input wire                        is_pred_branch2_i, // 第二条指令是否为预测分支指令

    input wire flush_flag_i,  // 流水线冲刷标志
    input wire inst_valid_i,  // 指令有效信号
    input wire pc_misaligned_i, // PC非对齐信号（PC[2]=1）
    input wire stall_i,       // 保持信号，为1时触发器保持不更新

    output wire [31:0] inst1_o,      // 第一条指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o, // 第一条指令地址
    output wire [31:0] inst2_o,      // 第二条指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o, // 第二条指令地址
    output wire                        is_pred_branch1_o,  // 第一条指令输出到ID/EXU的预测分支标志
    output wire                        is_pred_branch2_o,  // 第二条指令输出到ID/EXU的预测分支标志
    output wire                        inst_valid_o       // 输出指令有效信号
);

    // 直接使用flush_flag_i，不再寄存
    wire                        flush_en = flush_flag_i;

    // 根据PC对齐状态选择指令 - 64位访存指令分配逻辑
    // 当PC[2]=0时: inst1=低32位指令, inst2=高32位指令 (双发射)
    // 当PC[2]=1时: inst1=高32位指令, inst2=NOP (单发射)
    wire [31:0] selected_inst1 = pc_misaligned_i ? inst2_i : inst1_i;
    wire [31:0] selected_inst2 = pc_misaligned_i ? `INST_NOP : inst2_i;
    
    // 在指令无效或冲刷信号有效时，选择填充NOP作为寄存器输入
    wire [31:0] inst1_selected = (flush_en || !inst_valid_i) ? `INST_NOP : selected_inst1;
    wire [31:0] inst2_selected = (flush_en || !inst_valid_i) ? `INST_NOP : selected_inst2;

    // 储存第一条指令内容
    wire [31:0] inst1_r;
    gnrl_dfflr #(32) inst1_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (inst1_selected),
        .qout (inst1_r)
    );

    // 储存第二条指令内容
    wire [31:0] inst2_r;
    gnrl_dfflr #(32) inst2_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (inst2_selected),
        .qout (inst2_r)
    );

    // 直接输出寄存器内容
    assign inst1_o = inst1_r;
    assign inst2_o = inst2_r;

    wire [`INST_ADDR_WIDTH-1:0] inst1_addr;
    wire [`INST_ADDR_WIDTH-1:0] inst2_addr;
    
    // 根据PC对齐状态选择地址 - 与指令选择逻辑保持一致
    wire [`INST_ADDR_WIDTH-1:0] selected_addr1 = pc_misaligned_i ? inst2_addr_i : inst1_addr_i;
    wire [`INST_ADDR_WIDTH-1:0] selected_addr2 = pc_misaligned_i ? `ZeroWord : inst2_addr_i;
    
    // 选择指令地址：如果需要冲刷水线则选择ZeroWord，否则选择处理后的地址
    wire [`INST_ADDR_WIDTH-1:0] addr1_selected = flush_en ? `ZeroWord : selected_addr1;
    wire [`INST_ADDR_WIDTH-1:0] addr2_selected = flush_en ? `ZeroWord : selected_addr2;

    gnrl_dfflr #(`INST_ADDR_WIDTH) inst1_addr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (addr1_selected),
        .qout (inst1_addr)
    );
    
    gnrl_dfflr #(`INST_ADDR_WIDTH) inst2_addr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (addr2_selected),
        .qout (inst2_addr)
    );
    
    assign inst1_addr_o = inst1_addr;
    assign inst2_addr_o = inst2_addr;

    // 根据PC对齐状态选择分支预测信号
    wire selected_branch1 = pc_misaligned_i ? is_pred_branch2_i : is_pred_branch1_i;
    wire selected_branch2 = pc_misaligned_i ? 1'b0 : is_pred_branch2_i;

    // 寄存预测分支指令标志（第一条指令）
    wire is_pred_branch1_r;
    gnrl_dfflr #(1) is_pred_branch1_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (flush_en ? 1'b0 : selected_branch1),
        .qout (is_pred_branch1_r)
    );
    assign is_pred_branch1_o = is_pred_branch1_r;

    // 寄存预测分支指令标志（第二条指令）
    wire is_pred_branch2_r;
    gnrl_dfflr #(1) is_pred_branch2_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (flush_en ? 1'b0 : selected_branch2),
        .qout (is_pred_branch2_r)
    );
    assign is_pred_branch2_o = is_pred_branch2_r;

    // 寄存指令有效信号
    wire inst_valid_r;
    gnrl_dfflr #(1) inst_valid_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (!stall_i),       // 当stall_i为1时不更新
        .dnxt (flush_en ? 1'b0 : inst_valid_i),
        .qout (inst_valid_r)
    );
    assign inst_valid_o = inst_valid_r;

endmodule
