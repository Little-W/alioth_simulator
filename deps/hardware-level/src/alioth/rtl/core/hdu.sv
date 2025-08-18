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
    input wire                       inst1_valid,     // 指令1有效
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rd_addr,   // 指令1写寄存器地址
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rs1_addr,  // 指令1读寄存器1地址
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rs2_addr,  // 指令1读寄存器2地址
    input wire                       inst1_rd_we,     // 指令1是否写寄存器
    // 新增：已发射保持标志（来自issue stage），若已发射则不再参与FIFO冒险判断

    // 指令2信息（标签2）
    input wire                       inst2_valid,     // 指令2有效
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rd_addr,   // 指令2写寄存器地址
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rs1_addr,  // 指令2读寄存器1地址
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rs2_addr,  // 指令2读寄存器2地址
    input wire                       inst2_rd_we,     // 指令2是否写寄存器

    // 指令完成信号
    input wire                        commit_valid_i,   // 指令执行完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,      // 执行完成的指令ID（第一个）
    input wire                        commit_valid2_i,  // 第二条指令完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id2_i,     // 执行完成的指令ID（第二个）
    //icu_issue发来的写回信号
    // input wire                        jump_commit_valid_i,  // 指令执行完成有效信号
    // input wire [`COMMIT_ID_WIDTH-1:0] jump_commit_id_i,     // 执行完成的指令ID（第一个）
    // input wire                        jump_commit_valid2_i, // 第二条指令完成有效信号
    // input wire [`COMMIT_ID_WIDTH-1:0] jump_commit_id2_i,    // 执行完成的指令ID（第二个）
    // input wire [`COMMIT_ID_WIDTH-1:0] pending_inst1_id_i,

    // 跳转控制信号
    input wire inst1_jump_i,     // 指令1跳转信号
    input wire clint_req_valid,  //中断请求有效信号
    input wire inst1_branch_i,   // 指令1分支信号

    input wire [`EX_INFO_BUS_WIDTH-1:0] inst1_ex_info_bus,
    input wire [`EX_INFO_BUS_WIDTH-1:0] inst2_ex_info_bus,
    // 控制信号
    output wire [1:0] issue_inst_o,  // 发射指令标志[1:0]，bit0控制指令A，bit1控制指令B
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,  // 为指令1分配的ID
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,  // 为指令2分配的ID
    output wire alu1_pass_alu1_op1_o,
    output wire alu1_pass_alu1_op2_o,
    output wire alu1_pass_alu2_op1_o,
    output wire alu1_pass_alu2_op2_o,
    output wire mul1_pass_alu1_op1_o,
    output wire mul1_pass_alu1_op2_o,
    output wire mul1_pass_alu2_op1_o,
    output wire mul1_pass_alu2_op2_o,
    output wire div1_pass_alu1_op1_o,
    output wire div1_pass_alu1_op2_o,
    output wire div1_pass_alu2_op1_o,
    output wire div1_pass_alu2_op2_o,
    output wire alu2_pass_alu2_op1_o,
    output wire alu2_pass_alu2_op2_o,
    output wire alu2_pass_alu1_op1_o,
    output wire alu2_pass_alu1_op2_o,
    output wire mul2_pass_alu1_op1_o,
    output wire mul2_pass_alu1_op2_o,
    output wire mul2_pass_alu2_op1_o,
    output wire mul2_pass_alu2_op2_o,
    output wire div2_pass_alu1_op1_o,
    output wire div2_pass_alu1_op2_o,
    output wire div2_pass_alu2_op1_o,
    output wire div2_pass_alu2_op2_o,
    output wire long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
);

    typedef struct packed {
        logic [`REG_ADDR_WIDTH-1:0] rd_addr;
        logic [`EX_INFO_BUS_WIDTH-1:0] exu_type;
    } fifo_entry_t;

    // FIFO表项（跟踪未完成写回的长指令目的寄存器，用于RAW/WAW检测）
    reg [7:0] fifo_valid;
    fifo_entry_t fifo_entry[0:7];  // 存储表项结构体，深度8

    // RAW/WAW冒险检测信号
    reg raw_hazard_inst1_fifo;
    reg raw_hazard_inst2_fifo;
    reg raw_hazard_inst2_inst1;  // inst2 读 inst1 写
    reg waw_hazard_inst1_fifo;  // inst1 写 与 FIFO 里未完成写回冲突
    reg waw_hazard_inst2_fifo;  // inst2 写 与 FIFO 里未完成写回冲突
    reg waw_hazard_inst2_inst1;  // inst2 写 与 inst1 写同一寄存器

    // 检测x0寄存器（x0忽略）
    wire inst1_rs1_check = (inst1_rs1_addr != 5'h0) && inst1_valid;
    wire inst1_rs2_check = (inst1_rs2_addr != 5'h0) && inst1_valid;
    wire inst1_rd_check = (inst1_rd_addr != 5'h0) && inst1_rd_we && inst1_valid;
    wire inst2_rs1_check = (inst2_rs1_addr != 5'h0) && inst2_valid;
    wire inst2_rs2_check = (inst2_rs2_addr != 5'h0) && inst2_valid;
    wire inst2_rd_check = (inst2_rd_addr != 5'h0) && inst2_rd_we && inst2_valid;

    // ALU RAW冒险掩码及其对应ID
    reg [7:0] alu1_raw_mask;
    reg [2:0] alu1_raw_mask_id;  // 记录当前mask对应的commit_id
    reg [7:0] alu2_raw_mask;
    reg [2:0] alu2_raw_mask_id;  // 记录当前mask对应的commit_id

    reg
        alu1_raw_alu1_rs1,
        alu1_raw_alu1_rs2,
        alu2_raw_alu2_rs1,
        alu2_raw_alu2_rs2,
        alu1_raw_alu2_rs1,
        alu1_raw_alu2_rs2,
        alu2_raw_alu1_rs1,
        alu2_raw_alu1_rs2;
    reg
        mul1_raw_alu1_rs1,
        mul1_raw_alu1_rs2,
        mul2_raw_alu2_rs1,
        mul2_raw_alu2_rs2,
        mul1_raw_alu2_rs1,
        mul1_raw_alu2_rs2,
        mul2_raw_alu1_rs1,
        mul2_raw_alu1_rs2;
    reg
        div1_raw_alu1_rs1,
        div1_raw_alu1_rs2,
        div2_raw_alu2_rs1,
        div2_raw_alu2_rs2,
        div1_raw_alu2_rs1,
        div1_raw_alu2_rs2,
        div2_raw_alu1_rs1,
        div2_raw_alu1_rs2;


    wire [7:0] inst1_raw_hazard_vec;
    wire [7:0] inst2_raw_hazard_vec;
    wire [7:0] inst1_waw_hazard_vec;
    wire [7:0] inst2_waw_hazard_vec;
    wire [7:0] masked_inst1_raw_hazard_vec;
    wire [7:0] masked_inst2_raw_hazard_vec;
    wire       hazard;

    wire       can_into_fifo_inst1;
    wire       can_into_fifo_inst2;

    wire       inst1_is_alu_inst = (inst1_ex_info_bus == `EX_INFO_ALU);
    wire       inst1_is_mul_inst = (inst1_ex_info_bus == `EX_INFO_MUL);
    wire       inst1_is_div_inst = (inst1_ex_info_bus == `EX_INFO_DIV);
    wire       inst1_is_csr_inst = (inst1_ex_info_bus == `EX_INFO_CSR);
    wire       inst1_is_alu_bypass_inst = (inst1_ex_info_bus[`EX_INFO_BYPASS_BIT] == 1'b0);

    wire       inst2_is_alu_inst = (inst2_ex_info_bus == `EX_INFO_ALU);
    wire       inst2_is_mul_inst = (inst2_ex_info_bus == `EX_INFO_MUL);
    wire       inst2_is_div_inst = (inst2_ex_info_bus == `EX_INFO_DIV);
    wire       inst2_is_csr_inst = (inst2_ex_info_bus == `EX_INFO_CSR);
    wire       inst2_is_alu_bypass_inst = (inst2_ex_info_bus[`EX_INFO_BYPASS_BIT] == 1'b0);

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : hazard_vec_gen
            // RAW hazard detection: inst1
            assign inst1_raw_hazard_vec[i] =
                (fifo_valid[i]) &&
                (!(commit_valid_i && (commit_id_i == i))) && (!(commit_valid2_i && (commit_id2_i == i))) &&
                (
                    (inst1_rs1_check && (inst1_rs1_addr == fifo_entry[i].rd_addr)) ||
                    (inst1_rs2_check && (inst1_rs2_addr == fifo_entry[i].rd_addr))
                );
            // RAW hazard detection: inst2
            assign inst2_raw_hazard_vec[i] =
                (fifo_valid[i]) &&
                (!(commit_valid_i && (commit_id_i == i))) && (!(commit_valid2_i && (commit_id2_i == i))) &&
                (
                    (inst2_rs1_check && (inst2_rs1_addr == fifo_entry[i].rd_addr)) ||
                    (inst2_rs2_check && (inst2_rs2_addr == fifo_entry[i].rd_addr))
                );
            // WAW hazard detection: only if exu_type is different
            assign inst1_waw_hazard_vec[i] =
                (fifo_valid[i]) &&
                (!(commit_valid_i && (commit_id_i == i))) && (!(commit_valid2_i && (commit_id2_i == i))) &&
                (
                    inst1_rd_check &&
                    (inst1_rd_addr == fifo_entry[i].rd_addr) &&
                    (inst1_ex_info_bus != fifo_entry[i].exu_type)
                );
            assign inst2_waw_hazard_vec[i] =
                (fifo_valid[i]) &&
                (!(commit_valid_i && (commit_id2_i == i))) && (!(commit_valid2_i && (commit_id2_i == i))) &&
                (
                    inst2_rd_check &&
                    (inst2_rd_addr == fifo_entry[i].rd_addr) &&
                    (inst2_ex_info_bus != fifo_entry[i].exu_type)
                );
        end
    endgenerate

    assign raw_hazard_inst2_inst1 =
        (inst2_rs1_check && inst1_rd_check && (inst2_rs1_addr == inst1_rd_addr)) ||
        (inst2_rs2_check && inst1_rd_check && (inst2_rs2_addr == inst1_rd_addr));
    assign waw_hazard_inst2_inst1 =
        (inst2_rd_check && inst1_rd_check && (inst2_rd_addr == inst1_rd_addr));

    // RAW冒险掩码更新
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            alu1_raw_mask    <= 8'hFF;
            alu1_raw_mask_id <= 3'd0;
            alu2_raw_mask    <= 8'hFF;
            alu2_raw_mask_id <= 3'd0;
        end else begin
            // 清除已完成的长指令
            if (commit_valid_i && (alu1_raw_mask_id == commit_id_i)) begin
                alu1_raw_mask    <= 8'hFF;
                alu1_raw_mask_id <= 3'd0;
            end
            // 添加新的ALU写寄存器指令，分配mask并记录id
            if (inst1_valid && issue_inst_o[0] && inst1_is_alu_inst && inst1_rd_check) begin
                alu1_raw_mask    <= ~(8'b1 << inst1_commit_id_o);
                alu1_raw_mask_id <= inst1_commit_id_o;
            end

            if (commit_valid2_i && (alu2_raw_mask_id == commit_id2_i)) begin
                alu2_raw_mask    <= 8'hFF;
                alu2_raw_mask_id <= 3'd0;
            end
            // 添加新的ALU写寄存器指令，分配mask并记录id
            if (inst2_valid && issue_inst_o[1] && inst2_is_alu_inst && inst2_rd_check) begin
                alu2_raw_mask    <= ~(8'b1 << inst2_commit_id_o);
                alu2_raw_mask_id <= inst2_commit_id_o;
            end
        end
    end
    assign masked_inst1_raw_hazard_vec = inst1_is_alu_bypass_inst ? (inst1_raw_hazard_vec & alu1_raw_mask) : inst1_raw_hazard_vec;
    assign masked_inst2_raw_hazard_vec = inst2_is_alu_bypass_inst ? (inst2_raw_hazard_vec & alu2_raw_mask) : inst2_raw_hazard_vec;
    assign raw_hazard_inst1_fifo = |masked_inst1_raw_hazard_vec;
    assign raw_hazard_inst2_fifo = |masked_inst2_raw_hazard_vec;
    assign waw_hazard_inst1_fifo = |inst1_waw_hazard_vec;
    assign waw_hazard_inst2_fifo = |inst2_waw_hazard_vec;

    // 综合 RAW + WAW 冒险（统一用于发射控制）
    wire hazard_inst1_fifo = raw_hazard_inst1_fifo | waw_hazard_inst1_fifo;
    wire hazard_inst2_fifo = raw_hazard_inst2_fifo | waw_hazard_inst2_fifo;
    wire hazard_inst2_inst1 = raw_hazard_inst2_inst1 | waw_hazard_inst2_inst1;
    assign hazard = hazard_inst1_fifo | hazard_inst2_fifo | hazard_inst2_inst1;

    // 发射控制逻辑：按优先级判断 hazard 与 branch_serialize_effect
    reg [1:0] issue_inst_reg;
    always @(*) begin
        // 默认设为 11 默认双发射
        if (!can_alloc_two) begin
            issue_inst_reg = 2'b00; // 如果fifo不能容纳新的2个指令，则不允许当前发射
        end else begin
            issue_inst_reg = 2'b11;
            if (clint_req_valid) begin
                issue_inst_reg = 2'b00;
            end
        else if (hazard_inst1_fifo) begin //inst1有FIFO冒险-全停，直到inst1冒险解除进入下面的判断
                issue_inst_reg = 2'b00;
            end else begin  // inst1 无 FIFO 冒险
                if (inst1_jump_i) begin
                    issue_inst_reg = 2'b01;  //inst1为sys跳转-仅发射inst1
                end else begin
                    if (inst1_branch_i) begin
                        issue_inst_reg = 2'b01;  // 序列化：仅发射 A
                    end else begin
                        if (!hazard_inst2_fifo) begin
                            if (!hazard_inst2_inst1) issue_inst_reg = 2'b11;  // 双发射
                            else issue_inst_reg = 2'b01;  // B 依赖 A -> 只发射 A
                        end else begin
                            issue_inst_reg = 2'b01;  // B 有 FIFO 冒险 -> 只发 A
                        end
                    end
                end
            end
        end
    end

    // issue_inst_o: 发射指令选择
    assign issue_inst_o = issue_inst_reg;

    // ID 分配
    wire [2:0] next_id1, next_id2;
    wire can_alloc_two;
    // 统计 0..7 八个有效槽位
    wire [3:0] fifo_used_count = fifo_valid[0] + fifo_valid[1] + fifo_valid[2] + fifo_valid[3] + 
                                 fifo_valid[4] + fifo_valid[5] + fifo_valid[6] + fifo_valid[7];
    // 当已使用 <=6 时，说明剩余至少 2 个空槽位，可双分配
    assign can_alloc_two = (fifo_used_count <= 3'd6);

    // 选择最先空闲的 0..7 槽位
    assign next_id1 = inst1_valid ? ((~fifo_valid[0]) ? 3'd0 :
                      (~fifo_valid[1]) ? 3'd1 :
                      (~fifo_valid[2]) ? 3'd2 :
                      (~fifo_valid[3]) ? 3'd3 :
                      (~fifo_valid[4]) ? 3'd4 :
                      (~fifo_valid[5]) ? 3'd5 :
                      (~fifo_valid[6]) ? 3'd6 :
                      (~fifo_valid[7]) ? 3'd7 : 3'd0) : 3'd0;

    // 基于 next_id1 的 next_id2 选择（循环扫描 0..7，跳过已选的 next_id1）
    assign next_id2 = (inst2_valid && can_alloc_two) ?
                      ((next_id1 == 3'd0) ?
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 :
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : 
                          (~fifo_valid[7] ? 3'd7 : 3'd0))))))) :
                       (next_id1 == 3'd1) ?
                          (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 :
                          (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : 
                          (~fifo_valid[0] ? 3'd0 : 3'd0))))))) :
                       (next_id1 == 3'd2) ?
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 :
                          (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : 
                          (~fifo_valid[1] ? 3'd1 : 3'd0))))))) :
                       (next_id1 == 3'd3) ?
                          (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 :
                          (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : 
                          (~fifo_valid[2] ? 3'd2 : 3'd0))))))) :
                       (next_id1 == 3'd4) ?
                          (~fifo_valid[5] ? 3'd5 : (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 :
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : 
                          (~fifo_valid[3] ? 3'd3 : 3'd0))))))) :
                       (next_id1 == 3'd5) ?
                          (~fifo_valid[6] ? 3'd6 : (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 :
                          (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : 
                          (~fifo_valid[4] ? 3'd4 : 3'd0))))))) :
                       (next_id1 == 3'd6) ?
                          (~fifo_valid[7] ? 3'd7 : (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 :
                          (~fifo_valid[2] ? 3'd2 : (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : 
                          (~fifo_valid[5] ? 3'd5 : 3'd0))))))) :
                          (~fifo_valid[0] ? 3'd0 : (~fifo_valid[1] ? 3'd1 : (~fifo_valid[2] ? 3'd2 :
                          (~fifo_valid[3] ? 3'd3 : (~fifo_valid[4] ? 3'd4 : (~fifo_valid[5] ? 3'd5 : 
                          (~fifo_valid[6] ? 3'd6 : 3'd0)))))))) :
                      3'd0;

    // 输出分配的ID（不再特殊处理0）
    assign inst1_commit_id_o = (issue_inst_o[0]) ? next_id1 : 3'd0;
    assign inst2_commit_id_o = (issue_inst_o[1]) ? next_id2 : 3'd0;
    //仅当指令有效、发射且写寄存器时写入
    assign can_into_fifo_inst1 = (inst1_rd_check) && issue_inst_o[0];
    assign can_into_fifo_inst2 =  (inst2_rd_check) && issue_inst_o[1] ;//&& inst2_commit_id_o != 3'd0

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 复位时清空FIFO
            for (int i = 0; i < 8; i = i + 1) begin
                fifo_valid[i]          <= 1'b0;
                fifo_entry[i].rd_addr  <= 5'h0;
                fifo_entry[i].exu_type <= {`EX_INFO_BUS_WIDTH{1'b0}};
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
            if (can_into_fifo_inst1) begin
                fifo_valid[inst1_commit_id_o]          <= 1'b1;
                fifo_entry[inst1_commit_id_o].rd_addr  <= inst1_rd_addr;
                fifo_entry[inst1_commit_id_o].exu_type <= inst1_ex_info_bus;
            end
            if (can_into_fifo_inst2) begin
                fifo_valid[inst2_commit_id_o]          <= 1'b1;
                fifo_entry[inst2_commit_id_o].rd_addr  <= inst2_rd_addr;
                fifo_entry[inst2_commit_id_o].exu_type <= inst2_ex_info_bus;
            end
        end
    end

    // RAW冒险对象检测（对ALU/MUL/DIV/CSR指令有效）
    always @(*) begin
        alu1_raw_alu1_rs1 = 1'b0;
        alu1_raw_alu1_rs2 = 1'b0;
        alu1_raw_alu2_rs1 = 1'b0;
        alu1_raw_alu2_rs2 = 1'b0;
        alu2_raw_alu2_rs1 = 1'b0;
        alu2_raw_alu2_rs2 = 1'b0;
        alu2_raw_alu1_rs1 = 1'b0;
        alu2_raw_alu1_rs2 = 1'b0;
        mul1_raw_alu1_rs1 = 1'b0;
        mul1_raw_alu1_rs2 = 1'b0;
        mul1_raw_alu2_rs1 = 1'b0;
        mul1_raw_alu2_rs2 = 1'b0;
        mul2_raw_alu2_rs1 = 1'b0;
        mul2_raw_alu2_rs2 = 1'b0;
        mul2_raw_alu1_rs1 = 1'b0;
        mul2_raw_alu1_rs2 = 1'b0;
        div1_raw_alu1_rs1 = 1'b0;
        div1_raw_alu1_rs2 = 1'b0;
        div1_raw_alu2_rs1 = 1'b0;
        div1_raw_alu2_rs2 = 1'b0;
        div2_raw_alu2_rs1 = 1'b0;
        div2_raw_alu2_rs2 = 1'b0;
        div2_raw_alu1_rs1 = 1'b0;
        div2_raw_alu1_rs2 = 1'b0;


        if (inst1_is_alu_inst) begin
            // 只需检查alu_raw_mask_id对应的FIFO表项
            if (fifo_valid[alu1_raw_mask_id] && (alu1_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu1_raw_mask_id)) begin
                if (inst1_rs1_check && inst1_rs1_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    alu1_raw_alu1_rs1 = 1'b1;
                if (inst1_rs2_check && inst1_rs2_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    alu1_raw_alu1_rs2 = 1'b1;
            end
            if (fifo_valid[alu2_raw_mask_id] && (alu2_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu2_raw_mask_id)) begin
                if (inst1_rs1_check && inst1_rs1_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    alu1_raw_alu2_rs1 = 1'b1;
                if (inst1_rs2_check && inst1_rs2_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    alu1_raw_alu2_rs2 = 1'b1;
            end
        end
        if (inst1_is_mul_inst) begin
            if (fifo_valid[alu1_raw_mask_id] && (alu1_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu1_raw_mask_id)) begin
                if (inst1_rs1_check && inst1_rs1_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    mul1_raw_alu1_rs1 = 1'b1;
                if (inst1_rs2_check && inst1_rs2_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    mul1_raw_alu1_rs2 = 1'b1;
            end
            if (fifo_valid[alu2_raw_mask_id] && (alu2_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu2_raw_mask_id)) begin
                if (inst1_rs1_check && inst1_rs1_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    mul1_raw_alu2_rs1 = 1'b1;
                if (inst1_rs2_check && inst1_rs2_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    mul1_raw_alu2_rs2 = 1'b1;
            end
        end
        if (inst1_is_div_inst) begin
            if (fifo_valid[alu1_raw_mask_id] && (alu1_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu1_raw_mask_id)) begin
                if (inst1_rs1_check && inst1_rs1_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    div1_raw_alu1_rs1 = 1'b1;
                if (inst1_rs2_check && inst1_rs2_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    div1_raw_alu1_rs2 = 1'b1;
            end
            if (fifo_valid[alu2_raw_mask_id] && (alu2_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu2_raw_mask_id)) begin
                if (inst1_rs1_check && inst1_rs1_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    div1_raw_alu2_rs1 = 1'b1;
                if (inst1_rs2_check && inst1_rs2_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    div1_raw_alu2_rs2 = 1'b1;
            end
        end

        if (inst2_is_alu_inst) begin
            // 只需检查alu_raw_mask_id对应的FIFO表项
            if (fifo_valid[alu2_raw_mask_id] && (alu2_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu2_raw_mask_id)) begin
                if (inst2_rs1_check && inst2_rs1_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    alu2_raw_alu2_rs1 = 1'b1;
                if (inst2_rs2_check && inst2_rs2_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    alu2_raw_alu2_rs2 = 1'b1;
            end
            if (fifo_valid[alu1_raw_mask_id] && (alu1_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu1_raw_mask_id)) begin
                if (inst2_rs1_check && inst2_rs1_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    alu2_raw_alu1_rs1 = 1'b1;
                if (inst2_rs2_check && inst2_rs2_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    alu2_raw_alu1_rs2 = 1'b1;
            end
        end
        if (inst2_is_mul_inst) begin
            if (fifo_valid[alu2_raw_mask_id] && (alu2_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu2_raw_mask_id)) begin
                if (inst2_rs1_check && inst2_rs1_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    mul2_raw_alu2_rs1 = 1'b1;
                if (inst2_rs2_check && inst2_rs2_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    mul2_raw_alu2_rs2 = 1'b1;
            end
            if (fifo_valid[alu1_raw_mask_id] && (alu1_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu1_raw_mask_id)) begin
                if (inst2_rs1_check && inst2_rs1_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    mul2_raw_alu1_rs1 = 1'b1;
                if (inst2_rs2_check && inst2_rs2_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    mul2_raw_alu1_rs2 = 1'b1;
            end
        end
        if (inst2_is_div_inst) begin
            if (fifo_valid[alu2_raw_mask_id] && (alu2_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu2_raw_mask_id)) begin
                if (inst2_rs1_check && inst2_rs1_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    div2_raw_alu2_rs1 = 1'b1;
                if (inst2_rs2_check && inst2_rs2_addr == fifo_entry[alu2_raw_mask_id].rd_addr)
                    div2_raw_alu2_rs2 = 1'b1;
            end
            if (fifo_valid[alu1_raw_mask_id] && (alu1_raw_mask != 8'hFF) && !(commit_valid_i && commit_id_i == alu1_raw_mask_id)) begin
                if (inst2_rs1_check && inst2_rs1_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    div2_raw_alu1_rs1 = 1'b1;
                if (inst2_rs2_check && inst2_rs2_addr == fifo_entry[alu1_raw_mask_id].rd_addr)
                    div2_raw_alu1_rs2 = 1'b1;
            end
        end
    end

    assign alu1_pass_alu1_op1_o  = alu1_raw_alu1_rs1;
    assign alu1_pass_alu1_op2_o  = alu1_raw_alu1_rs2;
    assign alu1_pass_alu2_op1_o  = alu1_raw_alu2_rs1;
    assign alu1_pass_alu2_op2_o  = alu1_raw_alu2_rs2;
    assign mul1_pass_alu1_op1_o  = mul1_raw_alu1_rs1;
    assign mul1_pass_alu1_op2_o  = mul1_raw_alu1_rs2;
    assign mul1_pass_alu2_op1_o  = mul1_raw_alu2_rs1;
    assign mul1_pass_alu2_op2_o  = mul1_raw_alu2_rs2;
    assign div1_pass_alu1_op1_o  = div1_raw_alu1_rs1;
    assign div1_pass_alu1_op2_o  = div1_raw_alu1_rs2;
    assign div1_pass_alu2_op1_o  = div1_raw_alu2_rs1;
    assign div1_pass_alu2_op2_o  = div1_raw_alu2_rs2;
    assign alu2_pass_alu1_op1_o  = alu2_raw_alu1_rs1;
    assign alu2_pass_alu1_op2_o  = alu2_raw_alu1_rs2;
    assign alu2_pass_alu2_op1_o  = alu2_raw_alu2_rs1;
    assign alu2_pass_alu2_op2_o  = alu2_raw_alu2_rs2;
    assign mul2_pass_alu1_op1_o  = mul2_raw_alu1_rs1;
    assign mul2_pass_alu1_op2_o  = mul2_raw_alu1_rs2;
    assign mul2_pass_alu2_op1_o  = mul2_raw_alu2_rs1;
    assign mul2_pass_alu2_op2_o  = mul2_raw_alu2_rs2;
    assign div2_pass_alu1_op1_o  = div2_raw_alu1_rs1;
    assign div2_pass_alu1_op2_o  = div2_raw_alu1_rs2;
    assign div2_pass_alu2_op1_o  = div2_raw_alu2_rs1;
    assign div2_pass_alu2_op2_o  = div2_raw_alu2_rs2;

    // 原子锁：FIFO 中尚有未完成指令
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule
