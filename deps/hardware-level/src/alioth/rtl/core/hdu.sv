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

    // 新指令信息
    input wire                       inst_valid,         // 新长指令有效
    input wire [`REG_ADDR_WIDTH-1:0] new_inst_rd_addr,   // 新指令写寄存器地址
    input wire [`REG_ADDR_WIDTH-1:0] new_inst_rs1_addr,  // 新指令读寄存器1地址
    input wire [`REG_ADDR_WIDTH-1:0] new_inst_rs2_addr,  // 新指令读寄存器2地址
    input wire [`REG_ADDR_WIDTH-1:0] new_inst_rs3_addr,  // 新指令读寄存器3地址
    input wire                       new_inst_rd_we,     // 新指令是否写寄存器

    // 长指令完成信号（支持两路）
    input wire                        commit_valid_int_i,  // 整数指令完成有效
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_int_i,     // 整数指令ID
    input wire                        commit_valid_fp_i,   // 浮点指令完成有效
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_fp_i,      // 浮点指令ID

    // 控制信号
    output wire hazard_stall_o,  // 暂停流水线信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,  // 为新的长指令分配的ID
    output wire long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
);

    // 定义FIFO表项结构
    reg [7:0] fifo_valid;  // 有效位，深度8
    reg [`REG_ADDR_WIDTH-1:0] fifo_rd_addr[0:7];  // 目标寄存器地址，深度8

    // 冒险检测信号
    reg raw_hazard;  // 读后写冒险
    reg waw_hazard;  // 写后写冒险
    wire hazard;  // 总冒险信号

    // 寄存器为x0时不需要检测冒险（x0永远为0）
    wire rs1_check = (new_inst_rs1_addr != 0);
    wire rs2_check = (new_inst_rs2_addr != 0);
    wire rs3_check = (new_inst_rs3_addr != 0);
    wire rd_check = (new_inst_rd_addr != 0) && new_inst_rd_we;

    // 冒险检测逻辑
    always @(*) begin
        // 默认无冒险
        raw_hazard = 1'b0;
        waw_hazard = 1'b0;

        // 检查FIFO中的每个有效表项
        for (int i = 0; i < 8; i = i + 1) begin
            if (fifo_valid[i]) begin
                // RAW冒险：新指令读取的寄存器是FIFO中长指令的目标寄存器
                // 如果该长指令正在完成(commit_valid_int_i=1且commit_id_int_i=i 或 commit_valid_fp_i=1且commit_id_fp_i=i)，则跳过冒险检测
                if (!( (commit_valid_int_i && commit_id_int_i == i) || (commit_valid_fp_i && commit_id_fp_i == i) )) begin
                    if (((rs1_check && new_inst_rs1_addr == fifo_rd_addr[i]) ||
                         (rs2_check && new_inst_rs2_addr == fifo_rd_addr[i]) ||
                         (rs3_check && new_inst_rs3_addr == fifo_rd_addr[i]))) begin
                        raw_hazard = 1'b1;
                    end

                    // WAW冒险：新指令写入的寄存器是FIFO中长指令的目标寄存器
                    if (rd_check && new_inst_rd_addr == fifo_rd_addr[i]) begin
                        waw_hazard = 1'b1;
                    end
                end
            end
        end
    end

    // 只有在有新指令且存在冒险时才暂停流水线
    assign hazard = (raw_hazard || waw_hazard);
    assign hazard_stall_o = hazard;

    // 为新的长指令分配ID - 使用assign语句
    assign commit_id_o = (inst_valid && ~hazard) ? 
        ( ~fifo_valid[0] ? 0 :
          ~fifo_valid[1] ? 1 :
          ~fifo_valid[2] ? 2 :
          ~fifo_valid[3] ? 3 :
          ~fifo_valid[4] ? 4 :
          ~fifo_valid[5] ? 5 :
          ~fifo_valid[6] ? 6 :
          ~fifo_valid[7] ? 7 : 0 ) : 0;

    // 更新FIFO
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 复位时清空FIFO
            for (int i = 0; i < 8; i = i + 1) begin
                fifo_valid[i]   <= 1'b0;
                fifo_rd_addr[i] <= 0;
            end
        end else begin
            // 清除已完成的长指令（支持两路ID）
            if (commit_valid_int_i) begin
                fifo_valid[commit_id_int_i] <= 1'b0;
            end
            if (commit_valid_fp_i) begin
                fifo_valid[commit_id_fp_i] <= 1'b0;
            end

            // 添加新的长指令到FIFO
            if (inst_valid && ~hazard) begin
                // 使用组合逻辑分配的ID更新FIFO
                fifo_valid[commit_id_o]   <= 1'b1;
                fifo_rd_addr[commit_id_o] <= new_inst_rd_addr;
            end
        end
    end

    // 生成原子锁信号 - 当FIFO中有任何一个有效的长指令时为1
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule
