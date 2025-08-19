/*         
 The MIT License (MIT)

 Copyright © 2025
                                                                          
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

// 双发射AGU：
// - 不涉及FPU/64位访存指令，仅处理RV32的LB/LH/LW/SB/SH/SW
// - 适配64位数据总线：输出8位写掩码与64位写数据
// - 每路独立计算地址/掩码/写数据与未对齐检测
// - 冲突/串行化依然交由现有LSU处理（LSU已包含并发/RAW转发/串行化与1-entry FIFO）
module agu_dual (
    input wire                        clk,
    input wire                        rst_n,
    input wire                        exu_lsu_stall,
    // 第一路输入
    input wire                        inst1_valid_i,
    input wire                        valid_op1_i,
    input wire [                31:0] rs1_1_i,
    input wire [                31:0] rs2_1_i,
    input wire [                31:0] imm_1_i,
    input wire [  `DECINFO_WIDTH-1:0] dec_1_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_1_i,
    input wire [ `REG_ADDR_WIDTH-1:0] mem_reg_waddr_1_i,
    // 第二路输入
    input wire                        inst2_valid_i,
    input wire                        valid_op2_i,
    input wire [                31:0] rs1_2_i,
    input wire [                31:0] rs2_2_i,
    input wire [                31:0] imm_2_i,
    input wire [  `DECINFO_WIDTH-1:0] dec_2_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_2_i,
    input wire [ `REG_ADDR_WIDTH-1:0] mem_reg_waddr_2_i,

    // 第一路输出（64位总线编码）
    output wire [                31:0] addr_o,
    output wire [                 7:0] wmask_o,
    output wire [                63:0] wdata_o,
    output wire                        mem_req_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,
    output wire [ `REG_ADDR_WIDTH-1:0] mem_reg_waddr_o,
    // MEM操作类型导出
    output wire                        mem_op_lb_o,
    output wire                        mem_op_lh_o,
    output wire                        mem_op_lw_o,
    output wire                        mem_op_lbu_o,
    output wire                        mem_op_lhu_o,
    output wire                        mem_op_load_o,
    output wire                        mem_op_store_o,
    output wire                        misaligned_load_o,
    output wire                        misaligned_store_o,
    //控制类信号输出
    output wire                        agu_atom_lock,
    output wire                        agu_stall_req
);
    wire mem_valid_1, mem_valid_2;
    // FIFO相关信号定义
    localparam FIFO_DEPTH = 4;
    typedef struct packed {
        logic [31:0] rs1;
        logic [31:0] rs2;
        logic [31:0] imm;
        logic [`DECINFO_WIDTH-1:0] dec;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
        logic [`REG_ADDR_WIDTH-1:0] mem_reg_waddr;
        logic inst_valid;
    } fifo_entry_t;

    fifo_entry_t [FIFO_DEPTH-1:0] fifo_buffer;
    logic [2:0] fifo_head, fifo_tail;
    logic [2:0] fifo_count;
    wire        fifo_empty = (fifo_count == 0);
    wire        fifo_full = (fifo_count == FIFO_DEPTH);
    wire        fifo_has_two_space = (fifo_count <= FIFO_DEPTH - 2);



    // FIFO读写控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_head  <= 3'b000;
            fifo_tail  <= 3'b000;
            fifo_count <= 3'b000;
        end else begin
            // 同时处理推入和弹出操作
            case ({
                fifo_push && !fifo_full, fifo_pop && !fifo_empty
            })
                2'b00: begin
                    // 既不推入也不弹出
                end
                2'b01: begin
                    // 只弹出
                    fifo_head  <= (fifo_head + 1'b1) % FIFO_DEPTH;
                    fifo_count <= fifo_count - 1;
                end
                2'b10: begin
                    // 只推入
                    if (fifo_push_double) begin
                        // 双推入
                        fifo_tail  <= (fifo_tail + 2) % FIFO_DEPTH;
                        fifo_count <= fifo_count + 2;
                    end else begin
                        // 单推入
                        fifo_tail  <= (fifo_tail + 1'b1) % FIFO_DEPTH;
                        fifo_count <= fifo_count + 1;
                    end
                end
                2'b11: begin
                    // 同时推入和弹出
                    fifo_head <= (fifo_head + 1'b1) % FIFO_DEPTH;
                    if (fifo_push_double) begin
                        // 双推入单弹出：净增加1
                        fifo_tail  <= (fifo_tail + 2) % FIFO_DEPTH;
                        fifo_count <= fifo_count + 1;
                    end else begin
                        // 单推入单弹出：数量不变
                        fifo_tail <= (fifo_tail + 1'b1) % FIFO_DEPTH;
                    end
                end
            endcase
        end
    end

    // FIFO数据存储
    always_ff @(posedge clk) begin
        if (fifo_push && !fifo_full) begin
            if (fifo_push_double) begin
                // 双推入：先推第一路，再推第二路
                fifo_buffer[fifo_tail] <= '{
                    rs1_1_i,
                    rs2_1_i,
                    imm_1_i,
                    dec_1_i,
                    commit_id_1_i,
                    mem_reg_waddr_1_i,
                    inst1_valid_i
                };
                fifo_buffer[(fifo_tail+1)%FIFO_DEPTH] <= '{
                    rs1_2_i,
                    rs2_2_i,
                    imm_2_i,
                    dec_2_i,
                    commit_id_2_i,
                    mem_reg_waddr_2_i,
                    inst2_valid_i
                };
            end else begin
                // 单推入：根据push_sel决定存入通道1还是通道2的数据
                case (push_sel)
                    2'b01:
                    fifo_buffer[fifo_tail] <= '{
                        rs1_1_i,
                        rs2_1_i,
                        imm_1_i,
                        dec_1_i,
                        commit_id_1_i,
                        mem_reg_waddr_1_i,
                        inst1_valid_i
                    };
                    2'b10:
                    fifo_buffer[fifo_tail] <= '{
                        rs1_2_i,
                        rs2_2_i,
                        imm_2_i,
                        dec_2_i,
                        commit_id_2_i,
                        mem_reg_waddr_2_i,
                        inst2_valid_i
                    };
                    default: ;  // 不应该发生
                endcase
            end
        end
    end

    // 从FIFO读取的数据
    wire [                31:0] fifo_rs1 = fifo_buffer[fifo_head].rs1;
    wire [                31:0] fifo_rs2 = fifo_buffer[fifo_head].rs2;
    wire [                31:0] fifo_imm = fifo_buffer[fifo_head].imm;
    wire [  `DECINFO_WIDTH-1:0] fifo_dec = fifo_buffer[fifo_head].dec;
    wire [`COMMIT_ID_WIDTH-1:0] fifo_commit_id = fifo_buffer[fifo_head].commit_id;
    wire [ `REG_ADDR_WIDTH-1:0] fifo_mem_reg_waddr = fifo_buffer[fifo_head].mem_reg_waddr;
    wire                        fifo_inst_valid = fifo_buffer[fifo_head].inst_valid;

    // 提取两路的MEM信息位
    wire                        op1_mem = (dec_1_i[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire [  `DECINFO_WIDTH-1:0] mem_info1 = {`DECINFO_WIDTH{op1_mem}} & dec_1_i;
    wire                        op2_mem = (dec_2_i[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire [  `DECINFO_WIDTH-1:0] mem_info2 = {`DECINFO_WIDTH{op2_mem}} & dec_2_i;
    assign mem_valid_1 = op1_mem & inst1_valid_i & valid_op1_i;
    assign mem_valid_2 = op2_mem & inst2_valid_i & valid_op2_i;

    // 检测输入操作类型
    wire op1_load = mem_info1[`DECINFO_MEM_OP_LOAD];
    wire op1_store = mem_info1[`DECINFO_MEM_OP_STORE];
    wire op2_load = mem_info2[`DECINFO_MEM_OP_LOAD];
    wire op2_store = mem_info2[`DECINFO_MEM_OP_STORE];

    // FIFO控制逻辑
    // 只有当mem_valid为1时才进行FIFO判断
    wire both_mem_valid = mem_valid_1 & mem_valid_2;
    wire same_type = both_mem_valid & ((op1_load & op2_load) | (op1_store & op2_store));
    wire only_one_valid = (mem_valid_1 & !mem_valid_2) | (!mem_valid_1 & mem_valid_2);
    wire neither_valid = !mem_valid_1 & !mem_valid_2;

    logic fifo_push;
    logic fifo_pop;
    logic [1:0] push_sel; // 00=无推入, 01=仅通道1进FIFO, 10=仅通道2进FIFO, 11=两通道都进FIFO
    logic fifo_push_double;  // 双推入标志

    // FIFO推入弹出逻辑
    always_comb begin
        fifo_push        = 1'b0;
        fifo_pop         = 1'b0;
        push_sel         = 2'b00;
        fifo_push_double = 1'b0;

        if (both_mem_valid) begin
            if (fifo_full) begin
                // 情况1：两路都有效但FIFO满，拉高stall，不推入，允许弹出
                fifo_push = 1'b0;
                fifo_pop  = !exu_lsu_stall && !fifo_empty;
            end else if (same_type) begin
                // 情况2：两路都有效且同类型
                if (!fifo_empty) begin
                    // FIFO非空，双推入（如果空间足够）
                    if (fifo_has_two_space) begin
                        fifo_push        = 1'b1;
                        fifo_push_double = 1'b1;
                        push_sel         = 2'b11;
                        fifo_pop         = !exu_lsu_stall;
                    end else begin
                        // FIFO不能容纳两路，拉高stall
                        fifo_push = 1'b0;
                        fifo_pop  = !exu_lsu_stall && !fifo_empty;
                    end
                end else begin
                    // FIFO为空，单推入第二路，第一路直接输出
                    fifo_push = 1'b1;
                    push_sel  = 2'b10;
                    fifo_pop  = 1'b0;
                end
            end else begin
                // 情况3：两路都有效但不同类型，优先输出store路，load路推入FIFO
                if (!fifo_full) begin
                    fifo_push = 1'b1;
                    // 根据哪路是load来决定推入哪路
                    push_sel  = op1_load ? 2'b01 : 2'b10;
                    fifo_pop  = 1'b0;
                end else begin
                    // FIFO满，拉高stall
                    fifo_push = 1'b0;
                    fifo_pop  = !exu_lsu_stall && !fifo_empty;
                end
            end
        end else if (only_one_valid) begin
            // 情况4：只有一路有效
            if (!fifo_empty) begin
                // FIFO非空，单推入这一路，弹出最早的
                if (!fifo_full) begin
                    fifo_push = 1'b1;
                    push_sel  = mem_valid_1 ? 2'b01 : 2'b10;
                    fifo_pop  = !exu_lsu_stall;
                end else begin
                    // FIFO满，拉高stall
                    fifo_push = 1'b0;
                    fifo_pop  = !exu_lsu_stall;
                end
            end else begin
                // FIFO空，直接输出这一路
                fifo_push = 1'b0;
                fifo_pop  = 1'b0;
            end
        end else begin
            // 情况5：没有输入有效
            fifo_push = 1'b0;
            fifo_pop  = !exu_lsu_stall && !fifo_empty;
        end
    end

    // 输出通道选择逻辑
    // 根据不同情况选择输出
    wire use_fifo_for_output = !fifo_empty && fifo_pop;
    wire use_store_priority_output = both_mem_valid && !same_type && !use_fifo_for_output; // 两路不同类型时优先输出store

    // 输出数据选择
    logic [31:0] output_rs1, output_rs2, output_imm;
    logic [  `DECINFO_WIDTH-1:0] output_dec;
    logic [`COMMIT_ID_WIDTH-1:0] output_commit_id;
    logic [ `REG_ADDR_WIDTH-1:0] output_mem_reg_waddr;
    logic                        output_inst_valid;

    always_comb begin
        if (use_fifo_for_output) begin
            // 从FIFO弹出数据
            output_rs1           = fifo_rs1;
            output_rs2           = fifo_rs2;
            output_imm           = fifo_imm;
            output_dec           = fifo_dec;
            output_commit_id     = fifo_commit_id;
            output_mem_reg_waddr = fifo_mem_reg_waddr;
            output_inst_valid    = fifo_inst_valid;
        end else if (use_store_priority_output) begin
            // 两路不同类型时，优先输出store那路
            if (op1_store) begin
                // 通道1是store，输出通道1
                output_rs1           = rs1_1_i;
                output_rs2           = rs2_1_i;
                output_imm           = imm_1_i;
                output_dec           = dec_1_i;
                output_commit_id     = commit_id_1_i;
                output_mem_reg_waddr = mem_reg_waddr_1_i;
                output_inst_valid    = inst1_valid_i;
            end else begin
                // 通道2是store，输出通道2
                output_rs1           = rs1_2_i;
                output_rs2           = rs2_2_i;
                output_imm           = imm_2_i;
                output_dec           = dec_2_i;
                output_commit_id     = commit_id_2_i;
                output_mem_reg_waddr = mem_reg_waddr_2_i;
                output_inst_valid    = inst2_valid_i;
            end
        end else begin
            // 其他情况：优先使用有效的通道
            if (mem_valid_1) begin
                output_rs1           = rs1_1_i;
                output_rs2           = rs2_1_i;
                output_imm           = imm_1_i;
                output_dec           = dec_1_i;
                output_commit_id     = commit_id_1_i;
                output_mem_reg_waddr = mem_reg_waddr_1_i;
                output_inst_valid    = inst1_valid_i;
            end else if (mem_valid_2) begin
                output_rs1           = rs1_2_i;
                output_rs2           = rs2_2_i;
                output_imm           = imm_2_i;
                output_dec           = dec_2_i;
                output_commit_id     = commit_id_2_i;
                output_mem_reg_waddr = mem_reg_waddr_2_i;
                output_inst_valid    = inst2_valid_i;
            end else begin
                output_rs1           = 32'b0;
                output_rs2           = 32'b0;
                output_imm           = 32'b0;
                output_dec           = 0;
                output_commit_id     = 0;
                output_mem_reg_waddr = 0;
                output_inst_valid    = 1'b0;
            end
        end
    end

    // 重新计算MEM信息位（基于实际使用的输入）
    wire                      output_op_mem = (output_dec[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire [`DECINFO_WIDTH-1:0] output_mem_info = {`DECINFO_WIDTH{output_op_mem}} & output_dec;

    // 输出操作类型
    wire                      op_lb = output_mem_info[`DECINFO_MEM_LB];
    wire                      op_lh = output_mem_info[`DECINFO_MEM_LH];
    wire                      op_lw = output_mem_info[`DECINFO_MEM_LW];
    wire                      op_lbu = output_mem_info[`DECINFO_MEM_LBU];
    wire                      op_lhu = output_mem_info[`DECINFO_MEM_LHU];
    wire                      op_sb = output_mem_info[`DECINFO_MEM_SB];
    wire                      op_sh = output_mem_info[`DECINFO_MEM_SH];
    wire                      op_sw = output_mem_info[`DECINFO_MEM_SW];
    wire                      op_load = output_mem_info[`DECINFO_MEM_OP_LOAD];
    wire                      op_store = output_mem_info[`DECINFO_MEM_OP_STORE];

    // 地址计算
    wire [              31:0] addr = output_rs1 + output_imm;
    assign addr_o = addr;

    // 写掩码/写数据选择（基于输出数据进行计算）
    // 注意：虽然总线是64位，但实际只使用32位，因此只需要4位写掩码
    logic [ 7:0] wmask;
    logic [63:0] wdata;
    always_comb begin
        wmask = 8'b0;
        wdata = 64'b0;
        unique case (1'b1)
            op_sb: begin
                unique case (addr[2:0])
                    3'b000: begin
                        wmask = 8'b0000_0001;
                        wdata = {56'b0, output_rs2[7:0]};
                    end
                    3'b001: begin
                        wmask = 8'b0000_0010;
                        wdata = {48'b0, output_rs2[7:0], 8'b0};
                    end
                    3'b010: begin
                        wmask = 8'b0000_0100;
                        wdata = {40'b0, output_rs2[7:0], 16'b0};
                    end
                    3'b011: begin
                        wmask = 8'b0000_1000;
                        wdata = {32'b0, output_rs2[7:0], 24'b0};
                    end
                    3'b100: begin
                        wmask = 8'b0001_0000;
                        wdata = {24'b0, output_rs2[7:0], 32'b0};
                    end
                    3'b101: begin
                        wmask = 8'b0010_0000;
                        wdata = {16'b0, output_rs2[7:0], 40'b0};
                    end
                    3'b110: begin
                        wmask = 8'b0100_0000;
                        wdata = {8'b0, output_rs2[7:0], 48'b0};
                    end
                    3'b111: begin
                        wmask = 8'b1000_0000;
                        wdata = {output_rs2[7:0], 56'b0};
                    end
                endcase
            end
            op_sh: begin
                unique case (addr[2:1])
                    2'b00: begin
                        wmask = 8'b0000_0011;
                        wdata = {48'b0, output_rs2[15:0]};
                    end
                    2'b01: begin
                        wmask = 8'b0000_1100;
                        wdata = {32'b0, output_rs2[15:0], 16'b0};
                    end
                    2'b10: begin
                        wmask = 8'b0011_0000;
                        wdata = {16'b0, output_rs2[15:0], 32'b0};
                    end
                    2'b11: begin
                        wmask = 8'b1100_0000;
                        wdata = {output_rs2[15:0], 48'b0};
                    end
                endcase
            end
            op_sw: begin
                unique case (addr[2])
                    1'b0: begin
                        wmask = 8'b0000_1111;
                        wdata = {32'b0, output_rs2};
                    end
                    1'b1: begin
                        wmask = 8'b1111_0000;
                        wdata = {output_rs2, 32'b0};
                    end
                endcase
            end
            default: begin
            end
        endcase
    end

    assign wmask_o = wmask;
    assign wdata_o = wdata;
    assign commit_id_o = output_commit_id;
    assign mem_reg_waddr_o = output_mem_reg_waddr;
    assign mem_req_o = output_op_mem & output_inst_valid;

    // 导出MEM操作类型
    assign mem_op_lb_o = op_lb;
    assign mem_op_lh_o = op_lh;
    assign mem_op_lw_o = op_lw;
    assign mem_op_lbu_o = op_lbu;
    assign mem_op_lhu_o = op_lhu;
    assign mem_op_load_o = op_load;
    assign mem_op_store_o = op_store;

    // 未对齐检测
    assign misaligned_load_o  = op_load & (
        (op_lw  && (addr[1:0] != 2'b00)) ||
        ((op_lh | op_lhu) && (addr[0] != 1'b0))
    );
    assign misaligned_store_o = op_store & (
        (op_sw && (addr[1:0] != 2'b00)) ||
        (op_sh && (addr[0] != 1'b0))
    );

    assign agu_atom_lock = !fifo_empty;
    assign agu_stall_req = (both_mem_valid && fifo_full) || 
                          (both_mem_valid && same_type && !fifo_empty && !fifo_has_two_space) ||
                          (both_mem_valid && !same_type && fifo_full) ||
                          (only_one_valid && !fifo_empty && fifo_full);

endmodule
