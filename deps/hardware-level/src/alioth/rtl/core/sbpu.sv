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

    // BTB更新接口
    input wire                        btb_update_i,        // BTB更新使能
    input wire [`INST_ADDR_WIDTH-1:0] btb_update_pc_i,     // 需要更新的PC
    input wire [`INST_ADDR_WIDTH-1:0] btb_update_target_i, // 更新的目标地址

    output wire branch_taken_o,  // 预测是否为分支
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o,  // 预测的分支地址
    output wire is_pred_branch_o,  // 当前指令是经过预测的有条件分支指令
    output wire is_pred_jalr_o  // 当前指令是经过预测的JALR指令
);
    wire [6:0] opcode = inst_i[6:0];

    wire       opcode_1100011 = (opcode == 7'b1100011);
    wire       opcode_1101111 = (opcode == 7'b1101111);
    wire       opcode_1100111 = (opcode == 7'b1100111);

    wire       inst_type_branch = opcode_1100011;
    wire       inst_jal = opcode_1101111;
    wire       inst_jalr = opcode_1100111;

    // BTB实现
    localparam BTB_INDEX_WIDTH = `BTB_INDEX_WIDTH;  // 先有索引位宽
    localparam BTB_SIZE = `BTB_SIZE;  // 再通过位宽计算大小

    // 仅为BTB更新接口信号寄存
    reg                        btb_update_reg;
    reg [`INST_ADDR_WIDTH-1:0] btb_update_pc_reg;
    reg [`INST_ADDR_WIDTH-1:0] btb_update_target_reg;

    // BTB更新接口信号寄存逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btb_update_reg       <= 1'b0;
            btb_update_pc_reg    <= '0;
            btb_update_target_reg <= '0;
        end else if (!any_stall_i) begin  // 流水线不暂停时更新
            btb_update_reg       <= btb_update_i;
            btb_update_pc_reg    <= btb_update_pc_i;
            btb_update_target_reg <= btb_update_target_i;
        end
    end

    // BTB表项结构
    reg btb_valid[BTB_SIZE-1:0];
    reg [`INST_ADDR_WIDTH-1:0] btb_pc[BTB_SIZE-1:0];
    reg [`INST_ADDR_WIDTH-1:0] btb_target[BTB_SIZE-1:0];

    // BTB索引计算
    wire [BTB_INDEX_WIDTH-1:0] btb_index = pc_i[BTB_INDEX_WIDTH+1:2];
    wire [BTB_INDEX_WIDTH-1:0] update_index = btb_update_pc_reg[BTB_INDEX_WIDTH+1:2];

    // BTB查找结果
    wire btb_hit = btb_valid[btb_index] && (btb_pc[btb_index] == pc_i);
    wire [`INST_ADDR_WIDTH-1:0] btb_target_addr = btb_target[btb_index];

    // BTB更新逻辑 - 使用寄存后的更新信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < BTB_SIZE; i++) begin
                btb_valid[i] <= 1'b0;
            end
        end else if (btb_update_reg) begin  // 使用寄存后的更新使能
            btb_valid[update_index]  <= 1'b1;
            btb_pc[update_index]     <= btb_update_pc_reg;
            btb_target[update_index] <= btb_update_target_reg;
        end
    end

    // 内部信号
    wire is_pred_branch = inst_valid_i & (inst_type_branch & inst_b_type_imm[31]);
    wire is_pred_jal = inst_valid_i & inst_jal;
    wire is_pred_jalr = inst_valid_i & inst_jalr;
    wire jalr_btb_hit = is_pred_jalr & btb_hit;

    // 标识当前指令类型（用于传递给EXU）
    assign is_pred_branch_o = is_pred_branch;
    assign is_pred_jalr_o   = is_pred_jalr;

    // 立即数生成
    wire [31:0] inst_b_type_imm = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire [31:0] inst_j_type_imm = {
        {12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0
    };
    wire [31:0] inst_i_type_imm = {{20{inst_i[31]}}, inst_i[31:20]};  // JALR使用I型立即数

    // 预测所有类型的分支指令
    wire branch_taken = is_pred_branch | is_pred_jal | (is_pred_jalr & btb_hit);

    reg [31:0] branch_addr;

    always @(*) begin
        // 默认值，避免锁存器
        branch_addr = pc_i + 4;

        case (1'b1)
            inst_type_branch: branch_addr = pc_i + inst_b_type_imm;
            inst_jal: branch_addr = pc_i + inst_j_type_imm;
            inst_jalr & btb_hit:  // 使用直接的BTB命中信号
            branch_addr = btb_target_addr;  // 使用直接的BTB目标地址
            default: ;
        endcase
    end

    // 跳转指令范围验证：确保跳转地址在ITCM有效范围内
    wire addr_in_valid_range = (branch_addr >= `ITCM_BASE_ADDR) && 
                               (branch_addr < (`ITCM_BASE_ADDR + `ITCM_SIZE));

    // 分支预测结果，需同时满足：预测跳转、不在暂停状态、地址在有效范围内
    assign branch_taken_o = branch_taken & ~any_stall_i & addr_in_valid_range;
    assign branch_addr_o  = branch_addr;

    // 预测跳但实际没跳的情况的处理逻辑在EXU
endmodule
