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
    // 新增：已发射保持标志（来自issue stage），若已发射则不再参与FIFO冒险判断

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
    //icu_issue发来的写回信号
    input wire                        jump_commit_valid_i,  // 指令执行完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] jump_commit_id_i,     // 执行完成的指令ID（第一个）
    input wire                        jump_commit_valid2_i, // 第二条指令完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] jump_commit_id2_i,    // 执行完成的指令ID（第二个）
    input wire [`COMMIT_ID_WIDTH-1:0] pending_inst1_id_i,

    // 跳转控制信号
    input wire                        jump_flag_i,     // 跳转标志 (保留，与新序列化策略无直接关系，可用于后续扩展)
    input wire                        idu_flush_i,        //此时忽视来自idu的指令，防止它们进入FIFO
    input wire                        inst1_jump_i,    // 指令1跳转信号
    input wire                        clint_req_valid, //中断请求有效信号
    input wire                        inst1_branch_i,  // 指令1分支信号

    input wire                        inst1_csr_type_i,    // 指令1 CSR类型信号
    input wire                        inst2_csr_type_i,    // 指令2 CSR类型信号

    // 控制信号
    output wire [1:0] issue_inst_o,  // 发射指令标志[1:0]，bit0控制指令A，bit1控制指令B
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,  // 为指令1分配的ID
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,  // 为指令2分配的ID
    output wire long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
);

    // FIFO表项（跟踪未完成写回的长指令目的寄存器，用于RAW/WAW检测）
    reg [7:0] fifo_valid;
    reg [`REG_ADDR_WIDTH-1:0] fifo_rd_addr[0:7];

    // RAW/WAW冒险检测信号
    reg raw_hazard_inst1_fifo;
    reg raw_hazard_inst2_fifo;
    reg raw_hazard_inst2_inst1; // inst2 读 inst1 写
    reg waw_hazard_inst1_fifo;  // inst1 写 与 FIFO 里未完成写回冲突
    reg waw_hazard_inst2_fifo;  // inst2 写 与 FIFO 里未完成写回冲突
    reg waw_hazard_inst2_inst1; // inst2 写 与 inst1 写同一寄存器
    reg [2:0] pending_inst1_id;
    // 立即序列化：branch_serialize_pulse 为检测到 jump/branch 后保持的高电平（若与 FIFO 冒险则保持，直到冒险解除）
    // 首拍通过 branch_edge 保证立即生效
    reg branch_detect_d1; // 上一拍检测寄存器
    wire branch_detect_now = inst1_valid & inst1_branch_i;
    wire branch_edge = branch_detect_now & ~branch_detect_d1; // 首次检测到的边沿
    reg branch_serialize_pulse; // 改为保持寄存器

    wire sys_jump_detect_now = inst1_valid & inst1_jump_i;
    wire sys_jump_edge = sys_jump_detect_now & ~sys_jump_detect_d1; // 首次检测到的边沿
    reg  sys_jump_detect_d1;

    // 检测x0寄存器（x0忽略）
    wire inst1_rs1_check = (inst1_rs1_addr != 5'h0) && inst1_valid;
    wire inst1_rs2_check = (inst1_rs2_addr != 5'h0) && inst1_valid;
    wire inst1_rd_check  = (inst1_rd_addr  != 5'h0) && inst1_rd_we && inst1_valid;
    wire inst2_rs1_check = (inst2_rs1_addr != 5'h0) && inst2_valid;
    wire inst2_rs2_check = (inst2_rs2_addr != 5'h0) && inst2_valid;
    wire inst2_rd_check  = (inst2_rd_addr  != 5'h0) && inst2_rd_we && inst2_valid;

    wire can_into_fifo_inst1;
    wire can_into_fifo_inst2;
    // wire jump_true = jump_flag_i; // 不再需要

    // 冒险检测逻辑（RAW + 新增 WAW）
    always @(*) begin
        raw_hazard_inst1_fifo  = 1'b0;
        raw_hazard_inst2_fifo  = 1'b0;
        raw_hazard_inst2_inst1 = 1'b0;
        waw_hazard_inst1_fifo  = 1'b0;
        waw_hazard_inst2_fifo  = 1'b0;
        waw_hazard_inst2_inst1 = 1'b0;
        // FIFO遍历
        for (int i = 0; i < 8; i = i + 1) begin
            if (fifo_valid[i]) begin
                // 跳过本周期提交的表项
                if (!((commit_valid_i && commit_id_i == i) || (commit_valid2_i && commit_id2_i == i))) begin
                    // RAW: inst1 读
                    if ((inst1_rs1_check && inst1_rs1_addr == fifo_rd_addr[i]) || 
                        (inst1_rs2_check && inst1_rs2_addr == fifo_rd_addr[i])) begin
                        raw_hazard_inst1_fifo = 1'b1;
                    end
                    // RAW: inst2 读
                    if ((inst2_rs1_check && inst2_rs1_addr == fifo_rd_addr[i]) || 
                        (inst2_rs2_check && inst2_rs2_addr == fifo_rd_addr[i])) begin
                        raw_hazard_inst2_fifo = 1'b1;
                    end
                    // WAW: inst1 写
                    if (inst1_rd_check && inst1_rd_addr == fifo_rd_addr[i]) begin
                        waw_hazard_inst1_fifo = 1'b1;
                    end
                    // WAW: inst2 写
                    if (inst2_rd_check && inst2_rd_addr == fifo_rd_addr[i]) begin
                        waw_hazard_inst2_fifo = 1'b1;
                    end
                end
            end
        end
        // inst2 依赖 inst1 的 RAW (读 inst1 写)
        if (!(commit_valid_i && commit_id_i == pending_inst1_id)) begin
            if ((inst2_rs1_check && inst1_rd_check && (inst2_rs1_addr == inst1_rd_addr)) 
            || (inst2_rs2_check && inst1_rd_check && (inst2_rs2_addr == inst1_rd_addr))
            || (inst1_csr_type_i && inst2_csr_type_i)) begin
                raw_hazard_inst2_inst1 = 1'b1;
            end

            // WAW: inst2 写 与 inst1 写同一寄存器
            if (inst1_rd_check && inst2_rd_check && inst2_rd_addr == inst1_rd_addr) begin
                waw_hazard_inst2_inst1 = 1'b1;
            end
        end
    end


    // 综合 RAW + WAW 冒险（统一用于发射控制）
    wire hazard_inst1_fifo  = raw_hazard_inst1_fifo  | waw_hazard_inst1_fifo;
    wire hazard_inst2_fifo  = raw_hazard_inst2_fifo  | waw_hazard_inst2_fifo;
    wire hazard_inst2_inst1 = raw_hazard_inst2_inst1 | waw_hazard_inst2_inst1;

    // 发射控制逻辑：按优先级判断 hazard 与 branch_serialize_effect
    reg [1:0] issue_inst_reg;
    wire branch_serialize_effect = branch_edge | branch_serialize_pulse; // 组合效果
    always @(*) begin
        // 默认设为 11 默认双发射
        issue_inst_reg = 2'b11;
        if(clint_req_valid || idu_flush_i) begin
            issue_inst_reg = 2'b00;
        end
        else if (hazard_inst1_fifo) begin
            if (branch_serialize_effect) begin
                issue_inst_reg = 2'b00;         // inst1 有 FIFO 冒险且需要序列化 -> 全停
            end else begin
            if(sys_jump_edge) begin
                issue_inst_reg = 2'b01;     //inst1为sys跳转-仅发射inst1
            end else begin
                if (!hazard_inst2_fifo) begin
                    if (!hazard_inst2_inst1)    issue_inst_reg = 2'b10; // 只发射 B
                    else                        issue_inst_reg = 2'b00; // 相关 -> 全停
                end else begin
                    issue_inst_reg = 2'b00;     // 两侧或 B 也有 FIFO 冒险 -> 全停
                end
            end
            end
        end else begin // inst1 无 FIFO 冒险
        if(sys_jump_edge) begin
                issue_inst_reg = 2'b01;     //inst1为sys跳转-仅发射inst1
            end else begin
            if (branch_serialize_effect) begin
                issue_inst_reg = 2'b01;         // 序列化：仅发射 A
            end else begin
                if (!hazard_inst2_fifo) begin
                    if (!hazard_inst2_inst1)    issue_inst_reg = 2'b11; // 双发射
                    else                        issue_inst_reg = 2'b01; // B 依赖 A -> 只发射 A
                end else begin
                    issue_inst_reg = 2'b01;     // B 有 FIFO 冒险 -> 只发 A
                end
            end
        end
        end
    end

    // issue_inst_o: 发射指令选择
    assign issue_inst_o = fifo_full ? 2'b00 : issue_inst_reg;

    // FIFO满 (忽略 index 0，因其保留)
    // assign fifo_full = &fifo_valid; // 旧逻辑
    wire fifo_full; // 前置声明位置保持不变
    // ID 分配
    wire [2:0] next_id1, next_id2;
    wire can_alloc_two;
    // 仅统计 1..7 七个有效槽位
    wire [3:0] fifo_used_count = fifo_valid[1] + fifo_valid[2] + fifo_valid[3] + fifo_valid[4] +
                                 fifo_valid[5] + fifo_valid[6] + fifo_valid[7];
    // 当已使用 <=5 时，说明剩余至少 2 个空槽位，可双分配
    assign can_alloc_two = (fifo_used_count <= 4'd5);

    // 选择最先空闲的 1..7 槽位；若全部占用则给 0（后续因 fifo_full=1 会阻止发射）
    assign next_id1 = inst1_valid ? ((~fifo_valid[1]) ? 3'd1 :
                      (~fifo_valid[2]) ? 3'd2 :
                      (~fifo_valid[3]) ? 3'd3 :
                      (~fifo_valid[4]) ? 3'd4 :
                      (~fifo_valid[5]) ? 3'd5 :
                      (~fifo_valid[6]) ? 3'd6 :
                      (~fifo_valid[7]) ? 3'd7 : 3'd0) : 3'd0;

    // 基于 next_id1 的 next_id2 选择（循环扫描 1..7，跳过已选的 next_id1）
    assign next_id2 = (inst2_valid && can_alloc_two) ?
                      ((next_id1 == 3'd1) ?
                          (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 :
                          (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : 3'd0)))))) :
                       (next_id1 == 3'd2) ?
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 :
                          (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : (~fifo_valid[1] ? 3'd1 : 3'd0)))))) :
                       (next_id1 == 3'd3) ?
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 :
                          (~fifo_valid[7] ? 3'd7 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 3'd0)))))) :
                       (next_id1 == 3'd4) ?
                          (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 :
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : 3'd0)))))) :
                       (next_id1 == 3'd5) ?
                          (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : (~fifo_valid[1] ? 3'd1 :
                          (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : 3'd0)))))) :
                       (next_id1 == 3'd6) ?
                          (~fifo_valid[7] ? 3'd7 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 :
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : 3'd0)))))) :
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 :
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 3'd0))))))) :
                      next_id1;

    // 输出时若未发射或无效则为 0；有效永不输出 0
    assign inst1_commit_id_o = (inst1_valid && issue_inst_o[0]) ? next_id1 : 3'd0;
    assign inst2_commit_id_o = (inst2_valid && issue_inst_o[1]) ? next_id2 : 3'd0;
    //仅当指令有效、发射且写寄存器（或不写寄存器但是是csr）时写入
    assign can_into_fifo_inst1 =  (inst1_rd_check | inst1_csr_type_i) && issue_inst_o[0];
    assign can_into_fifo_inst2 =  (inst2_rd_check | inst2_csr_type_i) && issue_inst_o[1];

    // FIFO 与 序列化状态 更新（仅记录上一拍跳转检测用于形成单拍脉冲）
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (int i = 0; i < 8; i = i + 1) begin
                fifo_valid[i]   <= 1'b0;
                fifo_rd_addr[i] <= 5'h0;
            end
            branch_detect_d1 <= 1'b0;
            sys_jump_detect_d1 <=1'b0;
            branch_serialize_pulse <= 1'b0;
        end else begin
            // 释放时忽略 commit_id == 0（理论上不会出现）
            if (commit_valid_i  && commit_id_i  != 3'd0) fifo_valid[commit_id_i]  <= 1'b0;
            if (commit_valid2_i && commit_id2_i != 3'd0) fifo_valid[commit_id2_i] <= 1'b0;
            if (jump_commit_valid_i  && jump_commit_id_i  != 3'd0) fifo_valid[jump_commit_id_i]  <= 1'b0;
            if (jump_commit_valid2_i  && jump_commit_id2_i  != 3'd0) fifo_valid[jump_commit_id2_i]  <= 1'b0;
            //进入FIFO
            if (can_into_fifo_inst1) begin
                fifo_valid[inst1_commit_id_o]   <= 1'b1;
                fifo_rd_addr[inst1_commit_id_o] <= inst1_rd_addr;
            end
            if (can_into_fifo_inst2) begin
                fifo_valid[inst2_commit_id_o]   <= 1'b1;
                fifo_rd_addr[inst2_commit_id_o] <= inst2_rd_addr;
            end
            // branch_serialize_pulse 保持逻辑：检测到跳转置 1；若仍存在 inst1 与 FIFO 冒险则保持；冒险解除后清零
            if (branch_edge) begin
                branch_serialize_pulse <= 1'b1;
            end else if ( !hazard_inst1_fifo) begin
                branch_serialize_pulse <= 1'b0;
            end
            branch_detect_d1 <= branch_detect_now; // 保存上一拍
            sys_jump_detect_d1 <= sys_jump_detect_now; // 保存上一拍
        end
        // pending_inst1_id 逻辑保持，但不会出现 0 分配导致的依赖问题
        if (hazard_inst2_inst1) begin
            // 如果当前pending_inst1_id为0，则更新为pending_inst1_id_i，否则保持当前值
            if (pending_inst1_id == 3'd0) begin
                pending_inst1_id <= inst1_commit_id_o;
            end
            // 如果pending_inst1_id非0，则保持不变
            else begin
                pending_inst1_id <= pending_inst1_id;
            end
        end else begin
            // hazard_inst2_inst1为0时清零
            pending_inst1_id <= 3'd0;
        end
    end

    // 原子锁：FIFO 中尚有未完成指令
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule