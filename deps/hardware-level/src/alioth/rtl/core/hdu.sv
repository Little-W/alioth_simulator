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

    // 指令完成信号
    input wire                        commit_valid_i,  // 指令执行完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,     // 执行完成的指令ID（第一个）
    input wire                        commit_valid2_i, // 第二条指令完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id2_i,    // 执行完成的指令ID（第二个）

    // 跳转控制信号
    input wire                        jump_flag_i,     // 跳转标志 
    input wire                        inst1_jump_i,    // 指令1跳转信号
    input wire                        inst1_branch_i,  // 指令1分支信号

    // 控制信号
    output wire new_issue_stall_o,  // 新发射暂停信号，控制发射级之前的流水线暂停
    output wire [1:0] issue_inst_o,  // 发射指令标志[1:0]，bit0控制指令A，bit1控制指令B
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,  // 为指令1分配的ID
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,  // 为指令2分配的ID
    output wire long_inst_atom_lock_o,  // 原子锁信号，FIFO中有未销毁的长指令时为1
    
    // 新增输出信号给WBU
    output wire [`REG_ADDR_WIDTH-1:0] inst1_rd_addr_o,  // 指令1目标寄存器地址
    output wire [`REG_ADDR_WIDTH-1:0] inst2_rd_addr_o,  // 指令2目标寄存器地址
    output wire [31:0] inst1_timestamp,  // 指令1时间戳
    output wire [31:0] inst2_timestamp   // 指令2时间戳
);

    // 定义FIFO表项结构 - 深度为8
    reg [7:0] fifo_valid;  // 有效位
    reg [`REG_ADDR_WIDTH-1:0] fifo_rd_addr[0:7];  // 目标寄存器地址

    // 时间戳相关信号
    reg [32:0] timestamp;  // 33位时间戳，包含监控位
    wire timestamp_full;   // 时间戳溢出信号
    reg [31:0] inst1_timestamp_reg;  // 指令1时间戳寄存器
    reg [31:0] inst2_timestamp_reg;  // 指令2时间戳寄存器

    // 冒险检测信号
    reg raw_hazard_inst1_fifo;   // 指令1与FIFO的RAW冒险
    reg raw_hazard_inst2_fifo;   // 指令2与FIFO的RAW冒险
    reg raw_hazard_inst2_inst1;  // 指令2读取指令1写入的寄存器(B读A写的寄存器)
    reg inst1_jump;  // 指令1跳转信号
    reg [2:0] pending_inst1_id; // 保存导致阻塞的指令1的ID
    wire fifo_full;              // FIFO满标志

    // 检测x0寄存器（x0永远为0，不需要检测冒险）
    wire inst1_rs1_check = (inst1_rs1_addr != 5'h0) && inst1_valid;
    wire inst1_rs2_check = (inst1_rs2_addr != 5'h0) && inst1_valid;
    wire inst1_rd_check = (inst1_rd_addr != 5'h0) && inst1_rd_we && inst1_valid;
    
    wire inst2_rs1_check = (inst2_rs1_addr != 5'h0) && inst2_valid;
    wire inst2_rs2_check = (inst2_rs2_addr != 5'h0) && inst2_valid;
    wire inst2_rd_check = (inst2_rd_addr != 5'h0) && inst2_rd_we && inst2_valid;
    wire jump_true = jump_flag_i;

    // 时间戳溢出检测
    assign timestamp_full = timestamp[32];  // 监控位

    // 冒险检测逻辑
    always @(*) begin
        // 默认无冒险
        raw_hazard_inst1_fifo = 1'b0;
        raw_hazard_inst2_fifo = 1'b0;
        raw_hazard_inst2_inst1 = 1'b0;
        inst1_jump = 1'b0;

        // 检查指令1与FIFO中的每个有效表项
        for (int i = 0; i < 8; i = i + 1) begin
            if (fifo_valid[i]) begin
                // 如果该长指令正在完成，则跳过冒险检测
                if (!((commit_valid_i && commit_id_i == i) || (commit_valid2_i && commit_id2_i == i))) begin
                    // RAW冒险：指令1读取的寄存器是FIFO中长指令的目标寄存器
                    if ((inst1_rs1_check && inst1_rs1_addr == fifo_rd_addr[i]) || 
                        (inst1_rs2_check && inst1_rs2_addr == fifo_rd_addr[i])) begin
                        raw_hazard_inst1_fifo = 1'b1;
                    end

                    // RAW冒险：指令2读取的寄存器是FIFO中长指令的目标寄存器
                    if ((inst2_rs1_check && inst2_rs1_addr == fifo_rd_addr[i]) || 
                        (inst2_rs2_check && inst2_rs2_addr == fifo_rd_addr[i])) begin
                        raw_hazard_inst2_fifo= 1'b1;
                    end
                end
            end
        end

        // 检查指令2读取指令1写入的寄存器(B读A写的寄存器)
        if (!(commit_valid_i && commit_id_i == pending_inst1_id)) begin
            // RAW冒险：指令2读取的寄存器是指令1写入的寄存器
            if (inst2_rs1_check && inst1_rd_check && inst2_rs1_addr == inst1_rd_addr) begin
                raw_hazard_inst2_inst1 = 1'b1;
            end
            //inst1跳转也视为inst1与inst2存在冒险
            if (inst1_jump_i || inst1_branch_i) begin 
                inst1_jump = 1'b1;
            end
        end
    end

    // 发射控制逻辑
    reg [1:0] issue_inst_reg;
    
    // 计算发射控制状态
    always @(*) begin
        // 默认状态：两个指令都可以发射
        issue_inst_reg = 2'b11;  // 默认发射两个指令

        if(inst1_jump) begin
            // 如果指令1确实跳转，则停止暂停，指令B会被stall_flag_i[`CU_FLUSH]信号被冲刷掉，下个周期新的指令对会进入
            // 如果指令1没有确认是否跳转，只先发射指令1，指令B位置通过~issue_inst[1]置0
            //  如果指令1不需要跳转，相当于进行了一次raw冒险，指令1提交后issue_inst变为默认的11，此时B发射
            issue_inst_reg = jump_true ? 2'b11: 2'b01;
        end
        // 情况1: 指令A，B与FIFO中指令均无RAW冲突时
        else if (!raw_hazard_inst1_fifo && !raw_hazard_inst2_fifo) begin
            if (raw_hazard_inst2_inst1) begin
                // 1.1: 指令B读取指令A要写入的寄存器
                issue_inst_reg = 2'b01;  // 只发射指令A
            end else begin
                // 1.2: 指令A，B间无RAW冲突
                issue_inst_reg = 2'b11;  // 正常发射两个指令
            end
        end
        // 情况2: 指令A与FIFO中指令有RAW冲突，B没有
        else if (raw_hazard_inst1_fifo && !raw_hazard_inst2_fifo) begin
            if (raw_hazard_inst2_inst1) begin
                // 2.1: 指令B读取指令A要写入的寄存器
                issue_inst_reg = 2'b00;  // 都不发射
            end else begin
                // 2.2: 指令AB间无RAW冲突
                issue_inst_reg = 2'b10;  // 只发射指令B
            end
        end
        // 情况3: 指令B与FIFO中指令有RAW冲突，A没有
        else if (!raw_hazard_inst1_fifo && raw_hazard_inst2_fifo) begin
            issue_inst_reg = 2'b01;  // 只发射指令A
        end
        // 情况4: 指令A，B均与FIFO中指令有RAW冲突
        else if (raw_hazard_inst1_fifo && raw_hazard_inst2_fifo) begin
            if (raw_hazard_inst2_inst1) begin
                // 4.1: 指令B读取指令A要写入的寄存器
                issue_inst_reg = 2'b00;  // 都不发射
            end else begin
                // 4.2: 指令A，B之间无RAW冲突
                issue_inst_reg = 2'b00;  // 都不发射，等待FIFO中冲突解决
            end
        end
    end

    // 新发射暂停信号：当不是所有指令都能发射或fifo满或时间戳溢出时拉高
    assign new_issue_stall_o = (issue_inst_reg != 2'b11) || fifo_full || timestamp_full;
    
    // 发射指令标志输出
    assign issue_inst_o = fifo_full ? 2'b00 : issue_inst_reg;

    // FIFO满检测
    assign fifo_full = &fifo_valid;  // 所有8位都为1时FIFO满
    
    // 输出信号给WBU
    assign inst1_rd_addr_o = inst1_rd_addr;
    assign inst2_rd_addr_o = inst2_rd_addr;
    assign inst1_timestamp = inst1_timestamp_reg;
    assign inst2_timestamp = inst2_timestamp_reg;

    // 为两条指令分配ID
    wire [2:0] next_id1, next_id2;
    wire can_alloc_two;  // 是否能同时分配两个ID
    
    // 检查是否有足够的FIFO空间分配两个ID
    wire [3:0] fifo_used_count = fifo_valid[0] + fifo_valid[1] + fifo_valid[2] + fifo_valid[3] + 
                                 fifo_valid[4] + fifo_valid[5] + fifo_valid[6] + fifo_valid[7];
    assign can_alloc_two = (fifo_used_count <= 6);  // 最多使用6个位置，留2个给新指令
    
    // 为指令1分配ID - 按序分配，寻找第一个空闲位置
    assign next_id1 = (~fifo_valid[0]) ? 3'd0 :
                      (~fifo_valid[1]) ? 3'd1 :
                      (~fifo_valid[2]) ? 3'd2 :
                      (~fifo_valid[3]) ? 3'd3 :
                      (~fifo_valid[4]) ? 3'd4 :
                      (~fifo_valid[5]) ? 3'd5 :
                      (~fifo_valid[6]) ? 3'd6 :
                      (~fifo_valid[7]) ? 3'd7 : 3'd0;
    
    // 为指令2分配ID - 除指令1占用的ID外，寻找下一个空闲ID  
    assign next_id2 = (inst1_valid && inst2_valid && can_alloc_two) ?
                      ((next_id1 == 3'd0) ? 
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : 
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd7)))))) :
                       (next_id1 == 3'd1) ?
                          (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : 
                          (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : 3'd0)))))) :
                       (next_id1 == 3'd2) ?
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : 
                          (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : 3'd1)))))) :
                       (next_id1 == 3'd3) ?
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 
                          (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : 3'd2)))))) :
                       (next_id1 == 3'd4) ?
                          (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : 
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 3'd3)))))) :
                       (next_id1 == 3'd5) ?
                          (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : 
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : 3'd4)))))) :
                       (next_id1 == 3'd6) ?
                          (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : 
                          (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : 3'd5)))))) :
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : 3'd6))))))) :
                      next_id1;
    
    // 输出分配的ID
    assign inst1_commit_id_o = (inst1_valid && issue_inst_o[0]) ? next_id1 : 3'd0;
    assign inst2_commit_id_o = (inst2_valid && issue_inst_o[1]) ? next_id2 : 3'd0;

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
            if (commit_valid2_i) begin
                fifo_valid[commit_id2_i] <= 1'b0;
            end

            // 添加新的长指令到FIFO
            // 指令1：当issue_inst_o[0]为1时进入FIFO
            if (inst1_valid && issue_inst_o[0]) begin
                fifo_valid[next_id1] <= 1'b1;
                fifo_rd_addr[next_id1] <= inst1_rd_addr;
            end
            
            // 指令2：当issue_inst_o[1]为1时进入FIFO
            if (inst2_valid && issue_inst_o[1]) begin
                fifo_valid[next_id2] <= 1'b1;
                fifo_rd_addr[next_id2] <= inst2_rd_addr;
            end
        end
        // 更新pending_inst1_id
        pending_inst1_id <= (inst1_valid && raw_hazard_inst2_inst1) ? next_id1 : 3'd0;
    end

    // 时间戳更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            timestamp <= 33'h0;
            inst1_timestamp_reg <= 32'h0;
            inst2_timestamp_reg <= 32'h0;
        end else begin
            // 当原子锁信号为0时，清除溢出标志并重置时间戳
            if (!long_inst_atom_lock_o && timestamp_full) begin
                timestamp <= 33'h0;
                inst1_timestamp_reg <= 32'h0;
                inst2_timestamp_reg <= 32'h0;
            end 
            // 只有在未溢出时才更新时间戳
            else if (!timestamp_full) begin
                // 根据指令有效性更新时间戳和分配时间戳
                if (inst1_valid && inst2_valid) begin
                    // A和B都有效：A时间戳为n+1，B时间戳为n+2，timestamp+2
                    inst1_timestamp_reg <= timestamp[31:0] + 32'h1;
                    inst2_timestamp_reg <= timestamp[31:0] + 32'h2;
                    timestamp <= timestamp + 33'h2;
                end else if (inst1_valid && !inst2_valid) begin
                    // A有效，B无效：A时间戳为n+1，B时间戳为0，timestamp+1
                    inst1_timestamp_reg <= timestamp[31:0] + 32'h1;
                    inst2_timestamp_reg <= 32'h0;
                    timestamp <= timestamp + 33'h1;
                end else if (!inst1_valid && inst2_valid) begin
                    // A无效，B有效：A时间戳为0，B时间戳为n+1，timestamp+1
                    inst1_timestamp_reg <= 32'h0;
                    inst2_timestamp_reg <= timestamp[31:0] + 32'h1;
                    timestamp <= timestamp + 33'h1;
                end else begin
                    // 都无效：AB时间戳输出都为0，timestamp不变
                    inst1_timestamp_reg <= 32'h0;
                    inst2_timestamp_reg <= 32'h0;
                    // timestamp保持不变
                end
            end
        end
    end

    // 生成原子锁信号 - 当FIFO中有任何一个有效的长指令时为1
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule
