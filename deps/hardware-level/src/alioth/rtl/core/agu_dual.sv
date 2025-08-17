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
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        exu_lsu_stall,
    // 第一路输入
    input  wire                        inst1_valid_i,
    input  wire [                31:0] rs1_1_i,
    input  wire [                31:0] rs2_1_i,
    input  wire [                31:0] imm_1_i,
    input  wire [ `DECINFO_WIDTH-1:0] dec_1_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] commit_id_1_i,
    input  wire [`REG_ADDR_WIDTH-1:0]  mem_reg_waddr_1_i,
    // 第二路输入
    input  wire                        inst2_valid_i,
    input  wire [                31:0] rs1_2_i,
    input  wire [                31:0] rs2_2_i,
    input  wire [                31:0] imm_2_i,
    input  wire [ `DECINFO_WIDTH-1:0]  dec_2_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] commit_id_2_i,
    input  wire [`REG_ADDR_WIDTH-1:0]  mem_reg_waddr_2_i,

    // 第一路输出（64位总线编码）
    output wire [                31:0] addr_o,
    output wire [                 7:0] wmask_o,
    output wire [                63:0] wdata_o,
    output wire                        mem_req_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,
    output wire [`REG_ADDR_WIDTH-1:0]  mem_reg_waddr_o,
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
    typedef struct packed {
        logic [31:0] rs1;
        logic [31:0] rs2;
        logic [31:0] imm;
        logic [`DECINFO_WIDTH-1:0] dec;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
        logic [`REG_ADDR_WIDTH-1:0] mem_reg_waddr;
        logic inst_valid;
    } fifo_entry_t;

    fifo_entry_t [1:0] fifo_buffer;
    logic [1:0] fifo_head, fifo_tail;
    logic fifo_empty, fifo_full;
    logic fifo_push, fifo_pop;

    // FIFO状态控制
    assign fifo_empty = (fifo_head == fifo_tail);
    assign fifo_full = ((fifo_tail + 1'b1) & 2'b01) == fifo_head;

    // FIFO读写控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_head <= 2'b00;
            fifo_tail <= 2'b00;
        end else begin
            if (fifo_push && !fifo_full) begin
                fifo_tail <= (fifo_tail + 1'b1) & 2'b01;
            end
            if (fifo_pop && !fifo_empty) begin
                fifo_head <= (fifo_head + 1'b1) & 2'b01;
            end
        end
    end

    // FIFO数据存储
    always_ff @(posedge clk) begin
        if (fifo_push && !fifo_full) begin
            // 根据push_sel决定存入通道1还是通道2的数据
            case (push_sel)
                2'b01: fifo_buffer[fifo_tail] <= '{rs1_1_i, rs2_1_i, imm_1_i, dec_1_i, commit_id_1_i, mem_reg_waddr_1_i, inst1_valid_i};
                2'b10: fifo_buffer[fifo_tail] <= '{rs1_2_i, rs2_2_i, imm_2_i, dec_2_i, commit_id_2_i, mem_reg_waddr_2_i, inst2_valid_i};
                default: ; // 不应该发生
            endcase
        end
    end

    // 从FIFO读取的数据
    wire [31:0] fifo_rs1 = fifo_buffer[fifo_head].rs1;
    wire [31:0] fifo_rs2 = fifo_buffer[fifo_head].rs2;
    wire [31:0] fifo_imm = fifo_buffer[fifo_head].imm;
    wire [`DECINFO_WIDTH-1:0] fifo_dec = fifo_buffer[fifo_head].dec;
    wire [`COMMIT_ID_WIDTH-1:0] fifo_commit_id = fifo_buffer[fifo_head].commit_id;
    wire [`REG_ADDR_WIDTH-1:0] fifo_mem_reg_waddr = fifo_buffer[fifo_head].mem_reg_waddr;
    wire fifo_inst_valid = fifo_buffer[fifo_head].inst_valid;

    // 提取两路的MEM信息位
    wire op1_mem = (dec_1_i[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire [`DECINFO_WIDTH-1:0] mem_info1 = {`DECINFO_WIDTH{op1_mem}} & dec_1_i;
    wire op2_mem = (dec_2_i[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire [`DECINFO_WIDTH-1:0] mem_info2 = {`DECINFO_WIDTH{op2_mem}} & dec_2_i;
    assign mem_valid_1 = op1_mem & inst1_valid_i;
    assign mem_valid_2 = op2_mem & inst2_valid_i;

    // 检测输入操作类型
    wire op1_load  = mem_info1[`DECINFO_MEM_OP_LOAD];
    wire op1_store = mem_info1[`DECINFO_MEM_OP_STORE];
    wire op2_load  = mem_info2[`DECINFO_MEM_OP_LOAD];
    wire op2_store = mem_info2[`DECINFO_MEM_OP_STORE];

    // FIFO控制逻辑
    // 只有当mem_valid为1时才进行FIFO判断
    wire both_mem_valid = mem_valid_1 & mem_valid_2;
    wire same_type = both_mem_valid & ((op1_load & op2_load) | (op1_store & op2_store));
    logic [1:0] push_sel; // 00=无推入, 01=仅通道1进FIFO, 10=仅通道2进FIFO, 11=两通道都进FIFO
    
    // FIFO推入逻辑
    always_comb begin
        fifo_push = 1'b0;
        push_sel = 2'b00;
        
        if (!fifo_full) begin
            if (both_mem_valid) begin
                if (same_type) begin
                    // 两路同类型，通道2进FIFO，通道1直接输出
                    fifo_push = 1'b1;
                    push_sel = 2'b10;
                end else begin
                    // 两路不同类型，不需要进FIFO等待
                    fifo_push = 1'b0;
                    push_sel = 2'b00;
                end
            end else if (!fifo_empty) begin
                // FIFO非空，任何有效通道都需要进FIFO等待
                if (mem_valid_1) begin
                    fifo_push = 1'b1;
                    push_sel = 2'b01;
                end else if (mem_valid_2) begin
                    fifo_push = 1'b1;
                    push_sel = 2'b10;
                end
            end
        end
    end
    
    // 当exu_lsu_stall不为1时，FIFO弹出
    assign fifo_pop = !exu_lsu_stall && !fifo_empty;

    // 输出通道选择逻辑
    // 优先从FIFO弹出，否则使用当前输入
    wire use_fifo_for_output = !fifo_empty && !exu_lsu_stall;
    
    // 输出数据选择：如果FIFO有数据且可以弹出，则使用FIFO数据，否则使用通道1数据
    wire [31:0] output_rs1 = use_fifo_for_output ? fifo_rs1 : rs1_1_i;
    wire [31:0] output_rs2 = use_fifo_for_output ? fifo_rs2 : rs2_1_i;
    wire [31:0] output_imm = use_fifo_for_output ? fifo_imm : imm_1_i;
    wire [`DECINFO_WIDTH-1:0] output_dec = use_fifo_for_output ? fifo_dec : dec_1_i;
    wire [`COMMIT_ID_WIDTH-1:0] output_commit_id = use_fifo_for_output ? fifo_commit_id : commit_id_1_i;
    wire [`REG_ADDR_WIDTH-1:0] output_mem_reg_waddr = use_fifo_for_output ? fifo_mem_reg_waddr : mem_reg_waddr_1_i;
    wire output_inst_valid = use_fifo_for_output ? fifo_inst_valid : inst1_valid_i;

    // 重新计算MEM信息位（基于实际使用的输入）
    wire output_op_mem = (output_dec[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM);
    wire [`DECINFO_WIDTH-1:0] output_mem_info = {`DECINFO_WIDTH{output_op_mem}} & output_dec;

    // 输出操作类型
    wire op_lb    = output_mem_info[`DECINFO_MEM_LB];
    wire op_lh    = output_mem_info[`DECINFO_MEM_LH];
    wire op_lw    = output_mem_info[`DECINFO_MEM_LW];
    wire op_lbu   = output_mem_info[`DECINFO_MEM_LBU];
    wire op_lhu   = output_mem_info[`DECINFO_MEM_LHU];
    wire op_sb    = output_mem_info[`DECINFO_MEM_SB];
    wire op_sh    = output_mem_info[`DECINFO_MEM_SH];
    wire op_sw    = output_mem_info[`DECINFO_MEM_SW];
    wire op_load  = output_mem_info[`DECINFO_MEM_OP_LOAD];
    wire op_store = output_mem_info[`DECINFO_MEM_OP_STORE];

    // 地址计算
    wire [31:0] addr = output_rs1 + output_imm;
    assign addr_o = addr;

    // 写掩码/写数据选择（基于输出数据进行计算）
    logic [7:0]  wmask;
    logic [63:0] wdata;
    always_comb begin
        wmask = 8'b0;
        wdata = 64'b0;
        unique case (1'b1)
            op_sb: begin
                unique case (addr[2:0])
                    3'b000: begin wmask = 8'b0000_0001; wdata = {56'b0, output_rs2[7:0]}; end
                    3'b001: begin wmask = 8'b0000_0010; wdata = {48'b0, output_rs2[7:0], 8'b0}; end
                    3'b010: begin wmask = 8'b0000_0100; wdata = {40'b0, output_rs2[7:0], 16'b0}; end
                    3'b011: begin wmask = 8'b0000_1000; wdata = {32'b0, output_rs2[7:0], 24'b0}; end
                    3'b100: begin wmask = 8'b0001_0000; wdata = {24'b0, output_rs2[7:0], 32'b0}; end
                    3'b101: begin wmask = 8'b0010_0000; wdata = {16'b0, output_rs2[7:0], 40'b0}; end
                    3'b110: begin wmask = 8'b0100_0000; wdata = { 8'b0, output_rs2[7:0], 48'b0}; end
                    3'b111: begin wmask = 8'b1000_0000; wdata = {output_rs2[7:0], 56'b0}; end
                endcase
            end
            op_sh: begin
                unique case (addr[2:1])
                    2'b00: begin wmask = 8'b0000_0011; wdata = {48'b0, output_rs2[15:0]}; end
                    2'b01: begin wmask = 8'b0000_1100; wdata = {32'b0, output_rs2[15:0], 16'b0}; end
                    2'b10: begin wmask = 8'b0011_0000; wdata = {16'b0, output_rs2[15:0], 32'b0}; end
                    2'b11: begin wmask = 8'b1100_0000; wdata = {output_rs2[15:0], 48'b0}; end
                endcase
            end
            op_sw: begin
                unique case (addr[2])
                    1'b0: begin wmask = 8'b0000_1111; wdata = {32'b0, output_rs2}; end
                    1'b1: begin wmask = 8'b1111_0000; wdata = {output_rs2, 32'b0}; end
                endcase
            end
            default: begin end
        endcase
    end

    assign wmask_o = wmask;
    assign wdata_o = wdata;
    assign commit_id_o = output_commit_id;
    assign mem_reg_waddr_o = output_mem_reg_waddr;
    assign mem_req_o = output_op_mem & output_inst_valid;

    // 导出MEM操作类型
    assign mem_op_lb_o    = op_lb;
    assign mem_op_lh_o    = op_lh;
    assign mem_op_lw_o    = op_lw;
    assign mem_op_lbu_o   = op_lbu;
    assign mem_op_lhu_o   = op_lhu;
    assign mem_op_load_o  = op_load;
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

    assign agu_atom_lock = ! fifo_empty;
    assign agu_stall_req = (mem_valid_1 | mem_valid_2 ) && fifo_full;

endmodule
