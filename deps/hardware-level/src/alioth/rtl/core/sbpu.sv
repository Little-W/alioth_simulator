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

//静态分支预测模块（双发射版本）
module sbpu (
    input wire clk,
    input wire rst_n,

    // 双指令输入
    input wire [`INST_DATA_WIDTH-1:0] inst0_i,         // 第一条指令内容
    input wire [`INST_DATA_WIDTH-1:0] inst1_i,         // 第二条指令内容
    input wire                        inst0_valid_i,   // 第一条指令有效信号
    input wire                        inst1_valid_i,   // 第二条指令有效信号
    input wire [`INST_ADDR_WIDTH-1:0] pc0_i,           // 第一条指令PC
    input wire [`INST_ADDR_WIDTH-1:0] pc1_i,           // 第二条指令PC
    input wire                        any_stall_i,     // 流水线暂停信号
    input wire                        jalr_executed_i, // JALR执行完成信号

    // 双指令输出
    output wire                        branch_taken_o,     // 预测是否为分支
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o,      // 预测的分支地址
    output wire                        is_pred_branch0_o,  // 第一条指令是经过预测的有条件分支指令
    output wire                        is_pred_branch1_o,  // 第二条指令是经过预测的有条件分支指令
    output wire                        wait_for_jalr_o,    // JALR等待信号
    output wire                        branch_inst_slot_o, // 分支指令所在槽位 (0=第一条, 1=第二条)
    output wire                        inst1_disable_o     // 指令1为JAL时，禁用指令2通道
);
    // 第一条指令解析
    wire [6:0] opcode0 = inst0_i[6:0];
    wire       opcode0_1100011 = (opcode0 == 7'b1100011);
    wire       opcode0_1101111 = (opcode0 == 7'b1101111);
    wire       opcode0_1100111 = (opcode0 == 7'b1100111);
    wire       inst0_type_branch = opcode0_1100011;
    wire       inst0_jal = opcode0_1101111;
    wire       inst0_jalr = opcode0_1100111;

    // 第二条指令解析
    wire [6:0] opcode1 = inst1_i[6:0];
    wire       opcode1_1100011 = (opcode1 == 7'b1100011);
    wire       opcode1_1101111 = (opcode1 == 7'b1101111);
    wire       opcode1_1100111 = (opcode1 == 7'b1100111);
    wire       inst1_type_branch = opcode1_1100011;
    wire       inst1_jal = opcode1_1101111;
    wire       inst1_jalr = opcode1_1100111;

    // 第一条指令立即数提取
    wire [31:0] inst0_b_type_imm = {{20{inst0_i[31]}}, inst0_i[7], inst0_i[30:25], inst0_i[11:8], 1'b0};
    wire [31:0] inst0_j_type_imm = {
        {12{inst0_i[31]}}, inst0_i[19:12], inst0_i[20], inst0_i[30:21], 1'b0
    };

    // 第二条指令立即数提取
    wire [31:0] inst1_b_type_imm = {{20{inst1_i[31]}}, inst1_i[7], inst1_i[30:25], inst1_i[11:8], 1'b0};
    wire [31:0] inst1_j_type_imm = {
        {12{inst1_i[31]}}, inst1_i[19:12], inst1_i[20], inst1_i[30:21], 1'b0
    };

    // 第一条指令预测信号
    wire is_pred_branch0 = inst0_valid_i & (inst0_type_branch & inst0_b_type_imm[31]);
    wire is_pred_jal0 = inst0_valid_i & (inst0_jal);

    // 第二条指令预测信号 - 当指令0为JAL时，指令1被禁用
    wire inst1_active = inst1_valid_i & ~(inst0_valid_i & inst0_jal);
    wire is_pred_branch1 = inst1_active & (inst1_type_branch & inst1_b_type_imm[31]);
    wire is_pred_jal1 = inst1_active & (inst1_jal);

    // 分支预测结果（第一条指令优先）
    wire branch_taken0 = is_pred_branch0 | is_pred_jal0;
    wire branch_taken1 = is_pred_branch1 | is_pred_jal1;

    // 按优先级输出：第一条指令优先，如果第一条不是分支则考虑第二条
    wire final_branch_taken = branch_taken0 | (branch_taken1 & ~branch_taken0);
    wire branch_from_inst1 = branch_taken1 & ~branch_taken0;

    // 指令1为JAL时禁用指令2通道的信号
    assign inst1_disable_o = inst0_valid_i & inst0_jal;

    // 输出分支指令所在的槽位
    assign branch_inst_slot_o = branch_from_inst1;
    
    // 输出每条指令的预测分支信号
    assign is_pred_branch0_o = is_pred_branch0;
    assign is_pred_branch1_o = is_pred_branch1;

    reg  [31:0] branch_addr;

    always @(*) begin
        // 默认值，避免锁存器
        if (branch_from_inst1) begin
            // 如果分支来自第二条指令
            branch_addr = pc1_i + 4;  // 默认：第二条指令的下一条
            case (1'b1)
                inst1_type_branch: branch_addr = pc1_i + inst1_b_type_imm;
                inst1_jal:         branch_addr = pc1_i + inst1_j_type_imm;
                default:           ;
            endcase
        end else begin
            // 如果分支来自第一条指令或无分支
            branch_addr = pc0_i + 4;  // 默认：第一条指令的下一条
            case (1'b1)
                inst0_type_branch: branch_addr = pc0_i + inst0_b_type_imm;
                inst0_jal:         branch_addr = pc0_i + inst0_j_type_imm;
                default:           ;
            endcase
        end
    end

    assign branch_taken_o = final_branch_taken & ~any_stall_i;  // 分支预测结果，且不在暂停状态
    assign branch_addr_o = branch_addr;

    // JALR等待状态寄存器（支持双指令）
    reg wait_for_jalr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            wait_for_jalr <= 1'b0;
        else if ((inst0_valid_i && inst0_jalr) || (inst1_valid_i && inst1_jalr))
            wait_for_jalr <= 1'b1;      // 任一指令为JALR时设置等待
        else if (jalr_executed_i) 
            wait_for_jalr <= 1'b0;      // JALR执行完成，清除等待
    end

    assign wait_for_jalr_o = wait_for_jalr;

    // 预测跳但实际没跳的情况的处理逻辑在EXU
endmodule
