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

// 冒险检测单元 - 处理长指令的RAW和WAW相关性
module hdu (
    input wire clk,   // 时钟
    input wire rst_n, // 复位信号，低电平有效

    // 指令1信息（标签1）
    input wire                       inst1_valid,      // 指令1有效
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rd_addr,   // 指令1写寄存器地址
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rs1_addr,  // 指令1读寄存器1地址
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rs2_addr,  // 指令1读寄存器2地址
    input wire                       inst1_rd_we,     // 指令1是否写寄存器

    // 指令2信息（标签2）
    input wire                       inst2_valid,      // 指令2有效
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rd_addr,   // 指令2写寄存器地址
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rs1_addr,  // 指令2读寄存器1地址
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rs2_addr,  // 指令2读寄存器2地址
    input wire                       inst2_rd_we,     // 指令2是否写寄存器

    // 长指令完成信号
    input wire                        commit_valid_i,  // 长指令执行完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,     // 执行完成的长指令ID

    // 控制信号
    output wire hazard_stall_o,  // 暂停流水线信号（仅RAW冲突）
    output wire waw_conflict_o,  // WAW冲突输出信号
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,  // 为指令1分配的ID
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,  // 为指令2分配的ID
    output wire long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
);

    // 定义FIFO表项结构 - 深度为8
    reg [7:0] fifo_valid;  // 有效位
    reg [`REG_ADDR_WIDTH-1:0] fifo_rd_addr[0:7];  // 目标寄存器地址

    // 冒险检测信号
    reg raw_hazard_inst1_fifo;   // 指令1与FIFO的RAW冒险
    reg waw_hazard_inst1_fifo;   // 指令1与FIFO的WAW冒险
    reg raw_hazard_inst2_fifo;   // 指令2与FIFO的RAW冒险
    reg waw_hazard_inst2_fifo;   // 指令2与FIFO的WAW冒险
    reg raw_hazard_inst1_inst2;  // 指令1与指令2的RAW冒险
    reg waw_hazard_inst1_inst2;  // 指令1与指令2的WAW冒险
    wire raw_hazard;             // 总RAW冒险
    wire waw_hazard;             // 总WAW冒险
    wire fifo_full;              // FIFO满标志

    // 检测x0寄存器（x0永远为0，不需要检测冒险）
    wire inst1_rs1_check = (inst1_rs1_addr != 5'h0) && inst1_valid;
    wire inst1_rs2_check = (inst1_rs2_addr != 5'h0) && inst1_valid;
    wire inst1_rd_check = (inst1_rd_addr != 5'h0) && inst1_rd_we && inst1_valid;
    
    wire inst2_rs1_check = (inst2_rs1_addr != 5'h0) && inst2_valid;
    wire inst2_rs2_check = (inst2_rs2_addr != 5'h0) && inst2_valid;
    wire inst2_rd_check = (inst2_rd_addr != 5'h0) && inst2_rd_we && inst2_valid;

    // 冒险检测逻辑
    always @(*) begin
        // 默认无冒险
        raw_hazard_inst1_fifo = 1'b0;
        waw_hazard_inst1_fifo = 1'b0;
        raw_hazard_inst2_fifo = 1'b0;
        waw_hazard_inst2_fifo = 1'b0;
        raw_hazard_inst1_inst2 = 1'b0;
        waw_hazard_inst1_inst2 = 1'b0;

        // 检查指令1与FIFO中的每个有效表项
        for (int i = 0; i < 8; i = i + 1) begin
            if (fifo_valid[i]) begin
                // 如果该长指令正在完成(commit_valid_i=1且commit_id_i=i)，则跳过冒险检测
                if (!(commit_valid_i && commit_id_i == i)) begin
                    // RAW冒险：指令1读取的寄存器是FIFO中长指令的目标寄存器
                    if ((inst1_rs1_check && inst1_rs1_addr == fifo_rd_addr[i]) || 
                        (inst1_rs2_check && inst1_rs2_addr == fifo_rd_addr[i])) begin
                        raw_hazard_inst1_fifo = 1'b1;
                    end

                    // WAW冒险：指令1写入的寄存器是FIFO中长指令的目标寄存器
                    if (inst1_rd_check && inst1_rd_addr == fifo_rd_addr[i]) begin
                        waw_hazard_inst1_fifo = 1'b1;
                    end

                    // RAW冒险：指令2读取的寄存器是FIFO中长指令的目标寄存器
                    if ((inst2_rs1_check && inst2_rs1_addr == fifo_rd_addr[i]) || 
                        (inst2_rs2_check && inst2_rs2_addr == fifo_rd_addr[i])) begin
                        raw_hazard_inst2_fifo = 1'b1;
                    end

                    // WAW冒险：指令2写入的寄存器是FIFO中长指令的目标寄存器
                    if (inst2_rd_check && inst2_rd_addr == fifo_rd_addr[i]) begin
                        waw_hazard_inst2_fifo = 1'b1;
                    end
                end
            end
        end

        // 检查指令1与指令2之间的冒险
        if (inst1_valid && inst2_valid) begin
            // RAW冒险：指令1读取的寄存器是指令2写入的寄存器
            if ((inst1_rs1_check && inst2_rd_check && inst1_rs1_addr == inst2_rd_addr) ||
                (inst1_rs2_check && inst2_rd_check && inst1_rs2_addr == inst2_rd_addr)) begin
                raw_hazard_inst1_inst2 = 1'b1;
            end

            // 反向RAW冒险：指令2读取的寄存器是指令1写入的寄存器
            if ((inst2_rs1_check && inst1_rd_check && inst2_rs1_addr == inst1_rd_addr) ||
                (inst2_rs2_check && inst1_rd_check && inst2_rs2_addr == inst1_rd_addr)) begin
                raw_hazard_inst1_inst2 = 1'b1;
            end

            // WAW冒险：指令1和指令2写入同一个寄存器
            if (inst1_rd_check && inst2_rd_check && inst1_rd_addr == inst2_rd_addr) begin
                waw_hazard_inst1_inst2 = 1'b1;
            end
        end
    end

    // 合并冒险信号
    assign raw_hazard = raw_hazard_inst1_fifo || raw_hazard_inst2_fifo || raw_hazard_inst1_inst2;
    assign waw_hazard = waw_hazard_inst1_fifo || waw_hazard_inst2_fifo || waw_hazard_inst1_inst2;

    // FIFO满检测
    assign fifo_full = &fifo_valid;  // 所有8位都为1时FIFO满

    // RAW冒险或FIFO满时暂停流水线
    assign hazard_stall_o = raw_hazard || fifo_full;
    
    // WAW冲突输出信号
    assign waw_conflict_o = waw_hazard;

    // 为两条指令分配ID
    wire [2:0] next_id1, next_id2;
    wire can_alloc_two;  // 是否能同时分配两个ID
    
    // 检查是否有足够的FIFO空间分配两个ID
    wire [3:0] fifo_used_count = fifo_valid[0] + fifo_valid[1] + fifo_valid[2] + fifo_valid[3] + 
                                 fifo_valid[4] + fifo_valid[5] + fifo_valid[6] + fifo_valid[7];
    assign can_alloc_two = (fifo_used_count <= 6);  // 最多使用6个位置，留2个给新指令
    
    // 为指令1分配ID
    assign next_id1 = (~fifo_valid[0]) ? 3'd0 :
                      (~fifo_valid[1]) ? 3'd1 :
                      (~fifo_valid[2]) ? 3'd2 :
                      (~fifo_valid[3]) ? 3'd3 :
                      (~fifo_valid[4]) ? 3'd4 :
                      (~fifo_valid[5]) ? 3'd5 :
                      (~fifo_valid[6]) ? 3'd6 :
                      (~fifo_valid[7]) ? 3'd7 : 3'd0;
    
    // 为指令2分配ID（需要跳过指令1已分配的ID）
    assign next_id2 = (inst1_valid && inst2_valid && can_alloc_two) ?
                      ((next_id1 == 3'd0) ? 
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : 
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd1) ?
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : 
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd2) ?
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[3] ? 3'd3 : 
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd3) ?
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd4) ?
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd5) ?
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd6) ?
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : 3'd7)))))) :
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : 3'd6))))))) :
                      next_id1;
    
    // 输出分配的ID
    assign inst1_commit_id_o = (inst1_valid && ~raw_hazard && ~fifo_full) ? next_id1 : 3'd0;
    assign inst2_commit_id_o = (inst2_valid && ~raw_hazard && ~fifo_full && can_alloc_two) ? next_id2 : 3'd0;

    // 更新FIFO
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 复位时清空FIFO
            for (int i = 0; i < 8; i = i + 1) begin
                fifo_valid[i]   <= 1'b0;
                fifo_rd_addr[i] <= 5'h0;
            end
        end else begin
            // 清除已完成的长指令
            if (commit_valid_i) begin
                fifo_valid[commit_id_i] <= 1'b0;
            end

            // 添加新的长指令到FIFO
            if (~raw_hazard && ~fifo_full) begin
                // 指令1有效且没有RAW冒险时添加到FIFO
                if (inst1_valid) begin
                    fifo_valid[next_id1] <= 1'b1;
                    fifo_rd_addr[next_id1] <= inst1_rd_addr;
                end
                
                // 指令2有效且有足够空间时添加到FIFO
                if (inst2_valid && can_alloc_two) begin
                    fifo_valid[next_id2] <= 1'b1;
                    fifo_rd_addr[next_id2] <= inst2_rd_addr;
                end
            end
        end
    end

    // 生成原子锁信号 - 当FIFO中有任何一个有效的长指令时为1
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule
