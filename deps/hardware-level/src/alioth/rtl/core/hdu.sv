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
    input wire new_long_inst_valid,  // 新长指令有效
    input  wire [`REG_ADDR_WIDTH-1:0]  new_inst_rd_addr,  // 新指令写寄存器地址
    input  wire [`REG_ADDR_WIDTH-1:0]  new_inst_rs1_addr, // 新指令读寄存器1地址
    input  wire [`REG_ADDR_WIDTH-1:0]  new_inst_rs2_addr, // 新指令读寄存器2地址
    input wire new_inst_rd_we,  // 新指令是否写寄存器

    // 长指令完成信号
    input wire       commit_valid,  // 长指令执行完成有效信号
    input wire [1:0] commit_id,     // 执行完成的长指令ID

    // 控制信号
    output wire       hold,         // 暂停流水线信号
    output reg  [1:0] long_inst_id,  // 为新的长指令分配的ID
    output wire       long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
);

    // 定义FIFO表项结构
    reg fifo_valid[0:3];  // 有效位
    reg [`REG_ADDR_WIDTH-1:0] fifo_rd_addr[0:3];  // 目标寄存器地址

    // 冒险检测信号
    reg raw_hazard;  // 读后写冒险
    reg waw_hazard;  // 写后写冒险
    wire hazard;  // 总冒险信号

    // 寄存器为x0时不需要检测冒险（x0永远为0）
    wire rs1_check = (new_inst_rs1_addr != 5'h0);
    wire rs2_check = (new_inst_rs2_addr != 5'h0);
    wire rd_check = (new_inst_rd_addr != 5'h0) && new_inst_rd_we;

    // 冒险检测逻辑
    always @(*) begin
        // 默认无冒险
        raw_hazard = 1'b0;
        waw_hazard = 1'b0;

        // 检查FIFO中的每个有效表项
        for (int i = 0; i < 4; i = i + 1) begin
            if (fifo_valid[i]) begin
                // RAW冒险：新指令读取的寄存器是FIFO中长指令的目标寄存器
                if ((rs1_check && new_inst_rs1_addr == fifo_rd_addr[i]) || 
                    (rs2_check && new_inst_rs2_addr == fifo_rd_addr[i])) begin
                    raw_hazard = 1'b1;
                end

                // WAW冒险：新指令写入的寄存器是FIFO中长指令的目标寄存器
                if (rd_check && new_inst_rd_addr == fifo_rd_addr[i]) begin
                    waw_hazard = 1'b1;
                end
            end
        end
    end

    // 只有在有新指令且存在冒险时才暂停流水线
    assign hazard = (raw_hazard || waw_hazard) && new_long_inst_valid;
    assign hold   = hazard;

    // 为新的长指令分配ID并更新FIFO
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 复位时清空FIFO
            for (int i = 0; i < 4; i = i + 1) begin
                fifo_valid[i]   <= 1'b0;
                fifo_rd_addr[i] <= 5'h0;
            end
            long_inst_id <= 2'h0;
        end else begin
            // 清除已完成的长指令
            if (commit_valid) begin
                fifo_valid[commit_id] <= 1'b0;
            end

            // 添加新的长指令到FIFO
            if (new_long_inst_valid && ~hazard) begin
                // 查找空闲位置
                if (~fifo_valid[0]) begin
                    fifo_valid[0]   <= 1'b1;
                    fifo_rd_addr[0] <= new_inst_rd_addr;
                    long_inst_id    <= 2'h0;
                end else if (~fifo_valid[1]) begin
                    fifo_valid[1]   <= 1'b1;
                    fifo_rd_addr[1] <= new_inst_rd_addr;
                    long_inst_id    <= 2'h1;
                end else if (~fifo_valid[2]) begin
                    fifo_valid[2]   <= 1'b1;
                    fifo_rd_addr[2] <= new_inst_rd_addr;
                    long_inst_id    <= 2'h2;
                end else if (~fifo_valid[3]) begin
                    fifo_valid[3]   <= 1'b1;
                    fifo_rd_addr[3] <= new_inst_rd_addr;
                    long_inst_id    <= 2'h3;
                end
                // 如果所有位置都满了，应该已经触发了hazard信号阻止新指令
            end
        end
    end

    // 生成原子锁信号 - 当FIFO中有任何一个有效的长指令时为1
    assign long_inst_atom_lock_o = fifo_valid[0] | fifo_valid[1] | fifo_valid[2] | fifo_valid[3];

endmodule
