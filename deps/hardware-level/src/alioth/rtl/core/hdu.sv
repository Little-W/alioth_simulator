/*                                                                      
 Copyright 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "defines.svh"

// 简化后的冒险检测单元模块 - 仅检测RAW数据冲突
module hdu (
    input wire clk,   // 时钟信号
    input wire rst_n, // 复位信号

    // 指令有效信号
    input wire inst_valid,  // 指令有效标志

    // 指令解码信息
    input wire [4:0] rs1,         // 源寄存器1地址
    input wire [4:0] rs2,         // 源寄存器2地址
    input wire [4:0] rd,          // 目标寄存器地址
    input wire       reg_we,      // 寄存器写使能
    input wire       access_rs1,  // 是否访问源寄存器1
    input wire       access_rs2,  // 是否访问源寄存器2

    // 执行阶段信息
    input wire       ex_reg_we,    // 执行阶段寄存器写使能
    input wire [4:0] ex_reg_waddr, // 执行阶段写寄存器地址

    // 写回阶段信息
    input wire wb_done,     // 写回完成信号
    input wire wb_prepared, // 写回准备信号，为1时取消暂停

    // 输出信号
    output wire hold_flag  // 暂停信号
);

    // 将FIFO深度改为3
    localparam FIFO_DEPTH = 3;

    // 简化FIFO结构，只保留必要信息
    reg  [4:0] rd_fifo                      [FIFO_DEPTH-1:0];  // 目标寄存器FIFO
    reg        valid_fifo                   [FIFO_DEPTH-1:0];  // 有效标志FIFO

    reg  [1:0] fifo_head;  // FIFO头指针
    reg  [1:0] fifo_tail;  // FIFO尾指针
    wire       fifo_empty;  // FIFO空标志
    wire       fifo_full;  // FIFO满标志

    // FIFO状态逻辑
    assign fifo_empty = (fifo_head == fifo_tail) && !valid_fifo[fifo_head];
    assign fifo_full  = (fifo_head == fifo_tail) && valid_fifo[fifo_head];

    // FIFO操作控制信号 - 只存储需要写回寄存器的指令
    wire    push_en = inst_valid && reg_we && (rd != 5'h0) && !fifo_full;
    wire    pop_en = wb_done && !fifo_empty;

    // 简化的RAW冲突检测逻辑
    reg     data_hazard;
    integer i;

    always @(*) begin
        data_hazard = 1'b0;

        // 如果写回已准备好，取消暂停
        if (wb_prepared) begin
            data_hazard = 1'b0;
        end  // 否则检测RAW冲突
        else if (inst_valid) begin
            // 仅检查RAW冲突 (Read-After-Write)
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                if (valid_fifo[i]) begin
                    // 如果数据已在执行阶段可用，不需要暂停（数据前推处理）
                    if ((rd_fifo[i] == rs1 && rs1 != 0 && access_rs1) && !(ex_reg_we && ex_reg_waddr == rs1)) begin
                        data_hazard = 1'b1;
                    end

                    if ((rd_fifo[i] == rs2 && rs2 != 0 && access_rs2) && !(ex_reg_we && ex_reg_waddr == rs2)) begin
                        data_hazard = 1'b1;
                    end
                end
            end
        end
    end

    // 暂停信号输出
    assign hold_flag = data_hazard ? `HoldEnable : `HoldDisable;

    // FIFO操作 - 时序逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位所有FIFO和指针
            fifo_head <= 2'b0;
            fifo_tail <= 2'b0;
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                rd_fifo[i]    <= 5'b0;
                valid_fifo[i] <= 1'b0;
            end
        end else begin
            // 推入新指令 - 只有需要写寄存器的指令才入队
            if (push_en) begin
                rd_fifo[fifo_tail]    <= rd;
                valid_fifo[fifo_tail] <= 1'b1;
                fifo_tail             <= fifo_tail + 1'b1;
            end

            // 弹出完成的指令
            if (pop_en) begin
                valid_fifo[fifo_head] <= 1'b0;
                fifo_head             <= fifo_head + 1'b1;
            end
        end
    end

endmodule
