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

//静态分支预测模块
module sbpu (
    input wire clk,
    input wire rst_n,

    input wire [`INST_DATA_WIDTH-1:0] inst_i,        // 指令内容
    input wire                        inst_valid_i,  // 指令有效信号
    input wire [`INST_ADDR_WIDTH-1:0] pc_i,          // PC指针
    input wire                        any_stall_i,   // 流水线暂停信号

    output wire branch_taken_o,  // 预测是否为分支
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o,  // 预测的分支地址
    // 添加新的输出信号传递给EXU
    output wire is_pred_branch_o  // 当前指令是经过预测的有条件分支指令
    // 删除与预测验证相关的接口，因为已移至EXU
);
    wire [6:0] opcode = inst_i[6:0];

    wire       opcode_1100011 = (opcode == 7'b1100011);
    wire       opcode_1101111 = (opcode == 7'b1101111);
    wire       opcode_1100111 = (opcode == 7'b1100111);

    wire       inst_type_branch = opcode_1100011;
    wire       inst_jal = opcode_1101111;
    wire       inst_jalr = opcode_1100111;

    // 内部信号
    wire       is_pred_branch = inst_valid_i & (inst_type_branch & inst_b_type_imm[31]);
    wire       is_pred_jal = inst_valid_i & (inst_jal);

    // 标识当前指令是否为分支指令（用于传递给EXU）
    // 加回JALR和JAL判断
    assign is_pred_branch_o = is_pred_branch;

    wire [31:0] inst_b_type_imm = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire [31:0] inst_j_type_imm = {
        {12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0
    };
    // wire [31:0] inst_i_type_imm = {{20{inst_i[31]}}, inst_i[31:20]};  // 为JALR添加I-type立即数

    // 只预测条件分支指令和JAL
    // 我们不预测JALR，因为我们无法在这个阶段读取寄存器
    wire branch_taken = is_pred_branch | is_pred_jal;

    reg [31:0] branch_addr;

    always @(*) begin
        // 默认值，避免锁存器
        branch_addr = pc_i + 4;

        case (1'b1)
            inst_type_branch: branch_addr = pc_i + inst_b_type_imm;
            inst_jal:         branch_addr = pc_i + inst_j_type_imm;
            // JALR不计算预测地址，因为需要寄存器值
            default:          ;
        endcase
    end

    assign branch_taken_o = branch_taken & ~any_stall_i;  // 分支预测结果，且不在暂停状态
    assign branch_addr_o  = branch_addr;

    // 预测跳但实际没跳的情况的处理逻辑在EXU
endmodule
