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

//分支预测模块
module sbpu (
    input wire clk,
    input wire rst_n,

    // -------- IF 侧接口 --------
    input wire [`INST_DATA_WIDTH-1:0] inst_i,        // 指令内容
    input wire                        inst_valid_i,  // 指令有效
    input wire [`INST_ADDR_WIDTH-1:0] pc_i,          // 当前 PC
    input wire                        any_stall_i,   // 流水线暂停

    output wire                        branch_taken_o,   // 预测是否跳
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o,    // 预测目标
    output wire                        is_pred_branch_o, // 本条是否为预测分支

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
    localparam OPC_JAL = 7'b1101111;
    localparam OPC_JALR = 7'b1100111;

    wire inst_branch = (opcode == OPC_BRANCH);
    wire inst_jal = (opcode == OPC_JAL);
    // JALR 此处仍不预测
    // -----------------------------------------------------------
    // 2. 立即数解码
    // -----------------------------------------------------------
    wire [31:0] imm_b = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire [31:0] imm_j = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};

    // -----------------------------------------------------------
    // 3. BHT 存储体 (同步写、组合读)
    // -----------------------------------------------------------
    // 使用宏定义BHT计数器位宽
    reg [`BHT_CNT_WIDTH-1:0] bht[0:`BHT_ENTRIES-1];

    // 读索引：PC对齐4B，取低`BHT_IDX_WIDTH位
    wire [`BHT_IDX_WIDTH-1:0] bht_ridx = pc_i[`BHT_IDX_WIDTH+1:2];
    wire [`BHT_CNT_WIDTH-1:0] bht_rval = bht[bht_ridx];

    // 简单2-bit饱和计数器预测：最高位决定预测结果
    wire bht_predict_taken = bht_rval[`BHT_CNT_WIDTH-1];

    // -----------------------------------------------------------
    // 4. 预测输出
    // -----------------------------------------------------------
    wire predict_taken = inst_valid_i & (inst_branch ? bht_predict_taken : inst_jal ? 1'b1 : 1'b0);

    reg [`INST_ADDR_WIDTH-1:0] predict_addr;
    always @(*) begin
        predict_addr = pc_i + 32'd4;
        if (inst_branch) predict_addr = pc_i + imm_b;
        else if (inst_jal) predict_addr = pc_i + imm_j;
        // JALR: Not predicted here
    end

    assign branch_taken_o   = predict_taken & ~any_stall_i;
    assign branch_addr_o    = predict_addr;
    assign is_pred_branch_o = inst_valid_i & inst_branch & branch_taken_o;

    // -----------------------------------------------------------
    // 5. BHT 更新逻辑
    // -----------------------------------------------------------
    wire [`BHT_IDX_WIDTH-1:0] bht_widx = update_pc_i[`BHT_IDX_WIDTH+1:2];
    reg  [`BHT_CNT_WIDTH-1:0] bht_wval;

    // 定义状态常量，提高可读性
    localparam [`BHT_CNT_WIDTH-1:0] STRONG_NOT_TAKEN = 2'b00;
    localparam [`BHT_CNT_WIDTH-1:0] WEAK_NOT_TAKEN   = 2'b01;
    localparam [`BHT_CNT_WIDTH-1:0] WEAK_TAKEN       = 2'b10;
    localparam [`BHT_CNT_WIDTH-1:0] STRONG_TAKEN     = 2'b11;

    always @(*) begin
        bht_wval = bht[bht_widx];
        if (update_valid_i) begin
            if (real_taken_i) begin
                // 实际跳转，状态向上饱和
                case (bht[bht_widx])
                    STRONG_NOT_TAKEN: bht_wval = WEAK_NOT_TAKEN;
                    WEAK_NOT_TAKEN:   bht_wval = WEAK_TAKEN;
                    WEAK_TAKEN:       bht_wval = STRONG_TAKEN;
                    STRONG_TAKEN:     bht_wval = STRONG_TAKEN;  // 饱和
                endcase
            end else begin
                // 实际不跳转，状态向下饱和
                case (bht[bht_widx])
                    STRONG_NOT_TAKEN: bht_wval = STRONG_NOT_TAKEN;  // 饱和
                    WEAK_NOT_TAKEN:   bht_wval = STRONG_NOT_TAKEN;
                    WEAK_TAKEN:       bht_wval = WEAK_NOT_TAKEN;
                    STRONG_TAKEN:     bht_wval = WEAK_TAKEN;
                endcase
            end
        end
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 初始化为弱不跳状态
            for (i = 0; i < `BHT_ENTRIES; i = i + 1) begin
                bht[i] = WEAK_NOT_TAKEN;
            end
        end else if (update_valid_i) begin
            bht[bht_widx] <= bht_wval;  // 保持非阻塞，正常时钟写
        end
    end

endmodule
