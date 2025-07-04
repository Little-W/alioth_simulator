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

// 分支预测模块：结合动态预测和JALR支持
module bpu #(
    parameter  BHT_ENTRIES = 256,                 // 必须为 2 的幂
    localparam BHT_IDX_W   = $clog2(BHT_ENTRIES)
) (
    input wire clk,
    input wire rst_n,

    // -------- IF 侧接口 --------
    input wire [`INST_DATA_WIDTH-1:0] inst_i,        // 指令内容
    input wire                        inst_valid_i,  // 指令有效
    input wire [`INST_ADDR_WIDTH-1:0] pc_i,          // 当前 PC
    input wire                        any_stall_i,   // 流水线暂停

    // GPR接口 (用于JALR预测)
    output wire [`REG_ADDR_WIDTH-1:0] gpr_raddr_o,  // BPU向GPR请求的读地址
    input  wire [`REG_DATA_WIDTH-1:0] gpr_rdata_i,  // GPR返回给BPU的读数据

    output wire                        branch_taken_o,   // 预测是否跳
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o,    // 预测目标
    output wire                        is_pred_branch_o, // 本条是否为预测分支
    output wire                        is_pred_jalr_o,   // 本条是否为预测JALR

    // -------- EXU -> BHT 回写接口 --------
    input wire                        update_valid_i,  // 需更新?
    input wire [`INST_ADDR_WIDTH-1:0] update_pc_i,     // 被更新 PC
    input wire                        real_taken_i     // 实际结果
);

    // -----------------------------------------------------------
    // 1. 指令类型判定
    // -----------------------------------------------------------
    wire [6:0] opcode = inst_i[6:0];

    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;

    wire inst_branch = (opcode == OPC_BRANCH);
    wire inst_jal    = (opcode == OPC_JAL);
    wire inst_jalr   = (opcode == OPC_JALR);

    // -----------------------------------------------------------
    // 2. 立即数解码
    // -----------------------------------------------------------
    wire [31:0] imm_b = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire [31:0] imm_j = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
    wire [31:0] imm_i = {{20{inst_i[31]}}, inst_i[31:20]};  // JALR使用I型立即数

    // JALR使用的寄存器地址(rs1)
    wire [4:0] jalr_rs1 = inst_i[19:15];

    // 设置GPR读地址
    assign gpr_raddr_o = jalr_rs1;  // 读取JALR指令的基址寄存器

    // -----------------------------------------------------------
    // 3. BHT 存储体 (同步写、组合读)
    // -----------------------------------------------------------
    reg [1:0] bht[0:BHT_ENTRIES-1];

    // 读索引：PC 对齐 4B，可直接取低 BHT_IDX_W 位
    wire [BHT_IDX_W-1:0] bht_ridx = pc_i[BHT_IDX_W+1:2];
    wire [1:0] bht_rval = bht[bht_ridx];

    // 简单 2-bit 饱和计数器预测：高位决定
    wire bht_predict_taken = bht_rval[1];

    // -----------------------------------------------------------
    // 4. 预测输出
    // -----------------------------------------------------------
    // 内部信号
    wire is_pred_branch = inst_valid_i & inst_branch & bht_predict_taken;
    wire is_pred_jal    = inst_valid_i & inst_jal;
    wire is_pred_jalr   = inst_valid_i & inst_jalr;

    // 标识当前指令类型（用于传递给EXU）
    assign is_pred_branch_o = is_pred_branch;
    assign is_pred_jalr_o   = is_pred_jalr;

    // 预测所有类型的分支指令
    wire predict_taken = is_pred_branch | is_pred_jal | is_pred_jalr;

    reg [`INST_ADDR_WIDTH-1:0] predict_addr;
    always @(*) begin
        predict_addr = pc_i + 32'd4;  // 默认值
        if (inst_branch) 
            predict_addr = pc_i + imm_b;
        else if (inst_jal) 
            predict_addr = pc_i + imm_j;
        else if (inst_jalr)
            predict_addr = (gpr_rdata_i + imm_i) & ~32'h1;  // JALR目标地址计算，低位置0
    end

    // 跳转指令范围验证：确保跳转地址在ITCM有效范围内
    wire addr_in_valid_range = (predict_addr >= `ITCM_BASE_ADDR) && 
                              (predict_addr < (`ITCM_BASE_ADDR + `ITCM_SIZE));

    // 分支预测结果，需同时满足：预测跳转、不在暂停状态、地址在有效范围内
    assign branch_taken_o = predict_taken & ~any_stall_i & addr_in_valid_range;
    assign branch_addr_o  = predict_addr;

    // -----------------------------------------------------------
    // 5. BHT 更新逻辑
    // -----------------------------------------------------------
    wire [BHT_IDX_W-1:0] bht_widx = update_pc_i[BHT_IDX_W+1:2];
    reg  [          1:0] bht_wval;

    always @(*) begin
        bht_wval = bht[bht_widx];
        if (update_valid_i) begin
            case ({
                real_taken_i, bht[bht_widx]
            })
                // Not-Taken 路径（向 2'b00 收敛）
                3'b0_11: bht_wval = 2'b10;
                3'b0_10: bht_wval = 2'b01;
                3'b0_01: bht_wval = 2'b00;
                // Taken 路径（向 2'b11 收敛）
                3'b1_00: bht_wval = 2'b01;
                3'b1_01: bht_wval = 2'b10;
                3'b1_10: bht_wval = 2'b11;
                default: bht_wval = bht[bht_widx];  // 2'b00->00, 2'b11->11
            endcase
        end
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 改成阻塞赋值 (=) 并显式写循环增量
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht[i] = 2'b01;  // 初始化为弱不跳转
            end
        end else if (update_valid_i) begin
            bht[bht_widx] <= bht_wval;  // 保持非阻塞，正常时钟写
        end
    end

endmodule
