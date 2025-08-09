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

    input wire                        inst1_csr_type_i,    // 指令1 CSR类型信号
    input wire                        inst2_csr_type_i,    // 指令2 CSR类型信号

    // 控制信号
    output wire new_issue_stall_o,  // 新发射暂停信号，控制发射级之前的流水线暂停
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
    reg inst1_jump;
    reg [2:0] pending_inst1_id;
    wire fifo_full;

    // 检测x0寄存器（x0忽略）
    wire inst1_rs1_check = (inst1_rs1_addr != 5'h0) && inst1_valid;
    wire inst1_rs2_check = (inst1_rs2_addr != 5'h0) && inst1_valid;
    wire inst1_rd_check  = (inst1_rd_addr  != 5'h0) && inst1_rd_we && inst1_valid;
    wire inst2_rs1_check = (inst2_rs1_addr != 5'h0) && inst2_valid;
    wire inst2_rs2_check = (inst2_rs2_addr != 5'h0) && inst2_valid;
    wire inst2_rd_check  = (inst2_rd_addr  != 5'h0) && inst2_rd_we && inst2_valid;
    wire jump_true = jump_flag_i;

    // 冒险检测逻辑（RAW + 新增 WAW）
    always @(*) begin
        raw_hazard_inst1_fifo  = 1'b0;
        raw_hazard_inst2_fifo  = 1'b0;
        raw_hazard_inst2_inst1 = 1'b0;
        waw_hazard_inst1_fifo  = 1'b0;
        waw_hazard_inst2_fifo  = 1'b0;
        waw_hazard_inst2_inst1 = 1'b0;
        inst1_jump = 1'b0;
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
            if ((inst2_rs1_check && inst1_rd_check && inst2_rs1_addr == inst1_rd_addr) ||
                (inst1_csr_type_i == inst2_csr_type_i)) begin
                raw_hazard_inst2_inst1 = 1'b1;
            end
            // inst1 为跳转/分支也视为与 inst2 有相关性，需要序列化
            if (inst1_jump_i || inst1_branch_i) begin
                inst1_jump = 1'b1;
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

    // 发射控制逻辑
    reg [1:0] issue_inst_reg;
    always @(*) begin
        issue_inst_reg = 2'b11; // 默认都可发射
        if (inst1_jump) begin
            issue_inst_reg = jump_true ? 2'b11 : 2'b01; // 序列化等待跳转确认
        end else if (!hazard_inst1_fifo && !hazard_inst2_fifo) begin
            if (hazard_inst2_inst1) issue_inst_reg = 2'b01; // 序列化
            else issue_inst_reg = 2'b11;
        end else if (hazard_inst1_fifo && !hazard_inst2_fifo) begin
            if (hazard_inst2_inst1) issue_inst_reg = 2'b00; // 双阻塞
            else issue_inst_reg = 2'b10; // 只发射B
        end else if (!hazard_inst1_fifo && hazard_inst2_fifo) begin
            issue_inst_reg = 2'b01; // 只发射A
        end else begin // 两者都有 FIFO 冲突
            issue_inst_reg = 2'b00; // 等待解除
        end
    end

    // new_issue_stall: 不是双发射或 FIFO 满
    assign new_issue_stall_o = (issue_inst_reg != 2'b11) || fifo_full;
    assign issue_inst_o = fifo_full ? 2'b00 : issue_inst_reg;

    // FIFO满
    assign fifo_full = &fifo_valid;

    // ID 分配
    wire [2:0] next_id1, next_id2;
    wire can_alloc_two;
    wire [3:0] fifo_used_count = fifo_valid[0] + fifo_valid[1] + fifo_valid[2] + fifo_valid[3] +
                                 fifo_valid[4] + fifo_valid[5] + fifo_valid[6] + fifo_valid[7];
    assign can_alloc_two = (fifo_used_count <= 6);
    assign next_id1 = (~fifo_valid[0]) ? 3'd0 :
                      (~fifo_valid[1]) ? 3'd1 :
                      (~fifo_valid[2]) ? 3'd2 :
                      (~fifo_valid[3]) ? 3'd3 :
                      (~fifo_valid[4]) ? 3'd4 :
                      (~fifo_valid[5]) ? 3'd5 :
                      (~fifo_valid[6]) ? 3'd6 :
                      (~fifo_valid[7]) ? 3'd7 : 3'd0;
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

    assign inst1_commit_id_o = (inst1_valid && issue_inst_o[0]) ? next_id1 : 3'd0;
    assign inst2_commit_id_o = (inst2_valid && issue_inst_o[1]) ? next_id2 : 3'd0;

    // FIFO 更新
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (int i = 0; i < 8; i = i + 1) begin
                fifo_valid[i]   <= 1'b0;
                fifo_rd_addr[i] <= 5'h0;
            end
        end else begin
            if (commit_valid_i)  fifo_valid[commit_id_i]  <= 1'b0;
            if (commit_valid2_i) fifo_valid[commit_id2_i] <= 1'b0;
            if (inst1_valid && issue_inst_o[0]) begin
                fifo_valid[next_id1]   <= inst1_rd_check; // 仅写指令进入
                fifo_rd_addr[next_id1] <= inst1_rd_addr;
            end
            if (inst2_valid && issue_inst_o[1]) begin
                fifo_valid[next_id2]   <= inst2_rd_check;
                fifo_rd_addr[next_id2] <= inst2_rd_addr;
            end
        end
        // 若 inst2 与 inst1 存在（RAW 或 WAW）相关性被序列化，记录 pending ID
        pending_inst1_id <= (inst1_valid && hazard_inst2_inst1) ? next_id1 : 3'd0;
    end

    // 原子锁：FIFO 中尚有未完成指令
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule
