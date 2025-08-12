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

module agu #(
    parameter FIFO_DEPTH = 8
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        op_valid_i, // AGU操作有效信号
    input  wire                        exu_stall_i, // 来自EXU的暂停信号
    input  wire                        op_mem,
    input  wire [  `DECINFO_WIDTH-1:0] mem_info,
    input  wire [`GREG_DATA_WIDTH-1:0] rs1_rdata_i,
    input  wire [`GREG_DATA_WIDTH-1:0] rs2_rdata_i,
    input  wire [                31:0] dec_imm_i,
    input  wire [`FREG_DATA_WIDTH-1:0] frs2_rdata_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,        // 修改：输入commit_id宽度
    input  wire [`REG_ADDR_WIDTH-1:0]  mem_reg_waddr_i,    // 新增：输入寄存器写地址
    output wire                        mem_op_lb_o,
    output wire                        mem_op_lh_o,
    output wire                        mem_op_lw_o,
    output wire                        mem_op_lbu_o,
    output wire                        mem_op_lhu_o,
    output wire                        mem_op_ldh_o,       // 新增：加载高位
    output wire                        mem_op_ldl_o,       // 新增：加载低位
    output wire                        mem_op_sb_o,
    output wire                        mem_op_sh_o,
    output wire                        mem_op_sw_o,
    output wire                        mem_op_load_o,
    output wire                        mem_op_store_o,
    output wire                        mem_req_o,          // 新增：有效内存请求
    output wire                        agu_atom_lock,      // 新增：FIFO非空指示
    output wire                        agu_stall_req_o,    // 新增：stall请求
    output wire [                31:0] mem_addr_o,
    output wire [                 3:0] mem_wmask_o,
    output wire [                31:0] mem_wdata_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,        // 修改：输出commit_id宽度
    output wire [`REG_ADDR_WIDTH-1:0]  mem_reg_waddr_o,    // 新增：输出寄存器写地址
    output wire                        misaligned_load_o,
    output wire                        misaligned_store_o
);

    localparam FIFO_WIDTH = $clog2(FIFO_DEPTH);

    // mem op类型信号
    wire mem_op_lb = mem_info[`DECINFO_MEM_LB];
    wire mem_op_lh = mem_info[`DECINFO_MEM_LH];
    wire mem_op_lw = mem_info[`DECINFO_MEM_LW];
    wire mem_op_lbu = mem_info[`DECINFO_MEM_LBU];
    wire mem_op_lhu = mem_info[`DECINFO_MEM_LHU];
    wire mem_op_sb = mem_info[`DECINFO_MEM_SB];
    wire mem_op_sh = mem_info[`DECINFO_MEM_SH];
    wire mem_op_sw = mem_info[`DECINFO_MEM_SW];

    // 浮点内存操作
    wire mem_op_flw = mem_info[`DECINFO_MEM_FLW];
    wire mem_op_fsw = mem_info[`DECINFO_MEM_FSW];
    wire mem_op_fld = mem_info[`DECINFO_MEM_FLD];  // 新增：FLD加载双精度
    wire mem_op_fsd = mem_info[`DECINFO_MEM_FSD];  // 新增：FSD存储双精度

    // FIFO相关定义
    typedef struct packed {
        logic                        op_lb;
        logic                        op_lh;
        logic                        op_lw;
        logic                        op_lbu;
        logic                        op_lhu;
        logic                        op_ldh;
        logic                        op_ldl;
        logic                        op_sb;
        logic                        op_sh;
        logic                        op_sw;
        logic                        op_load;
        logic                        op_store;
        logic [31:0]                 addr;
        logic [3:0]                  wmask;
        logic [31:0]                 wdata;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;  // 修改：commit_id字段宽度
        logic [`REG_ADDR_WIDTH-1:0]  reg_waddr;  // 新增：寄存器写地址
    } mem_req_t;

    mem_req_t fifo[0:FIFO_DEPTH-1];
    logic [FIFO_WIDTH-1:0] fifo_head, fifo_tail;
    logic [FIFO_WIDTH:0] fifo_count;
    wire                 fifo_empty = (fifo_count == 0);
    wire                 fifo_full = (fifo_count == FIFO_DEPTH);
    wire                 fifo_has_two_space = (fifo_count <= FIFO_DEPTH - 2);

    // 当前请求生成
    wire  [        31:0] current_addr = rs1_rdata_i + dec_imm_i;
    wire                 current_valid = op_mem && op_valid_i;

    // 64位操作检测
    wire                 is_64bit_op = mem_op_fld || mem_op_fsd;

    // 生成当前请求
    mem_req_t current_req_low, current_req_high;

    always_comb begin
        // 低位请求（对于64位操作是低32位，对于32位操作就是完整操作）
        current_req_low.op_lb     = mem_op_lb;
        current_req_low.op_lh     = mem_op_lh;
        current_req_low.op_lw     = mem_op_lw || mem_op_flw;
        current_req_low.op_lbu    = mem_op_lbu;
        current_req_low.op_lhu    = mem_op_lhu;
        current_req_low.op_ldh    = 1'b0;
        current_req_low.op_ldl    = mem_op_fld;
        current_req_low.op_sb     = mem_op_sb;
        current_req_low.op_sh     = mem_op_sh;
        current_req_low.op_sw     = mem_op_sw || mem_op_fsw || mem_op_fsd;
        current_req_low.op_load   = mem_info[`DECINFO_MEM_OP_LOAD] || mem_op_flw || mem_op_fld;
        current_req_low.op_store  = mem_info[`DECINFO_MEM_OP_STORE] || mem_op_fsw || mem_op_fsd;
        current_req_low.addr      = current_addr;
        current_req_low.commit_id = commit_id_i;  // 宽度已自动适配
        current_req_low.reg_waddr = mem_reg_waddr_i; // 新增
        // 删除: current_req_low.reg_we    = mem_reg_we_i;    // 新增
        // 修复 wmask 和 wdata 设置，使用位拼接
        unique case (1'b1)
            mem_op_sb: begin
                case (current_addr[1:0])
                    2'b00: begin
                        current_req_low.wmask = 4'b0001;
                        current_req_low.wdata = {24'b0, rs2_rdata_i[7:0]};
                    end
                    2'b01: begin
                        current_req_low.wmask = 4'b0010;
                        current_req_low.wdata = {16'b0, rs2_rdata_i[7:0], 8'b0};
                    end
                    2'b10: begin
                        current_req_low.wmask = 4'b0100;
                        current_req_low.wdata = {8'b0, rs2_rdata_i[7:0], 16'b0};
                    end
                    2'b11: begin
                        current_req_low.wmask = 4'b1000;
                        current_req_low.wdata = {rs2_rdata_i[7:0], 24'b0};
                    end
                    default: begin
                        current_req_low.wmask = 4'b0000;
                        current_req_low.wdata = 32'b0;
                    end
                endcase
            end
            mem_op_sh: begin
                case (current_addr[1])
                    1'b0: begin
                        current_req_low.wmask = 4'b0011;
                        current_req_low.wdata = {16'b0, rs2_rdata_i[15:0]};
                    end
                    1'b1: begin
                        current_req_low.wmask = 4'b1100;
                        current_req_low.wdata = {rs2_rdata_i[15:0], 16'b0};
                    end
                    default: begin
                        current_req_low.wmask = 4'b0000;
                        current_req_low.wdata = 32'b0;
                    end
                endcase
            end
            mem_op_sw: begin
                current_req_low.wmask = 4'b1111;
                current_req_low.wdata = rs2_rdata_i;
            end
            mem_op_fsw, mem_op_fsd: begin
                current_req_low.wmask = 4'b1111;
                current_req_low.wdata = frs2_rdata_i[31:0];
            end
            default: begin
                current_req_low.wmask = 4'b0000;
                current_req_low.wdata = 32'b0;
            end
        endcase

        // 高位请求（仅用于64位操作）
        current_req_high.op_lb     = 1'b0;
        current_req_high.op_lh     = 1'b0;
        current_req_high.op_lw     = 1'b0;
        current_req_high.op_lbu    = 1'b0;
        current_req_high.op_lhu    = 1'b0;
        current_req_high.op_ldh    = mem_op_fld;
        current_req_high.op_ldl    = 1'b0;
        current_req_high.op_sb     = 1'b0;
        current_req_high.op_sh     = 1'b0;
        current_req_high.op_sw     = mem_op_fsd;
        current_req_high.op_load   = mem_op_fld;
        current_req_high.op_store  = mem_op_fsd;
        current_req_high.addr      = current_addr + 4;
        current_req_high.wmask     = 4'b1111;
        current_req_high.wdata     = frs2_rdata_i[63:32];
        current_req_high.commit_id = commit_id_i;  // 宽度已自动适配
        current_req_high.reg_waddr = mem_reg_waddr_i; // 新增
        // 删除: current_req_high.reg_we    = mem_reg_we_i;    // 新增
    end

    // FIFO push/pop逻辑
    wire       fifo_pop = !exu_stall_i && !fifo_empty;
    wire       fifo_push_single = current_valid && !is_64bit_op && !fifo_empty && !fifo_full;
    wire       fifo_push_double = current_valid && is_64bit_op && !fifo_empty && fifo_has_two_space;
    wire       fifo_push_high_only = current_valid && is_64bit_op && fifo_empty && !fifo_full;

    // FIFO操作编码
    wire [1:0] fifo_op;
    assign fifo_op = {(fifo_push_single || fifo_push_double || fifo_push_high_only), fifo_pop};

    // 地址计算的中间变量
    logic [FIFO_WIDTH-1:0] next_tail_1, next_tail_2;
    always_comb begin
        next_tail_1 = (fifo_tail + 1 >= FIFO_DEPTH) ? 0 : fifo_tail + 1;
        next_tail_2 = (fifo_tail + 2 >= FIFO_DEPTH) ? fifo_tail + 2 - FIFO_DEPTH : fifo_tail + 2;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_head  <= 0;
            fifo_tail  <= 0;
            fifo_count <= 0;
        end else begin
            case (fifo_op)
                2'b10: begin  // 只推入
                    if (fifo_push_double) begin
                        // 64位操作且FIFO非空：push两个请求
                        fifo[fifo_tail]   <= current_req_low;
                        fifo[next_tail_1] <= current_req_high;
                        fifo_tail         <= next_tail_2;
                        fifo_count        <= fifo_count + 2;
                    end else if (fifo_push_high_only) begin
                        // 64位操作且FIFO为空：只push高位请求
                        fifo[fifo_tail] <= current_req_high;
                        fifo_tail       <= next_tail_1;
                        fifo_count      <= fifo_count + 1;
                    end else if (fifo_push_single) begin
                        // 32位操作且FIFO非空：push一个请求
                        fifo[fifo_tail] <= current_req_low;
                        fifo_tail       <= next_tail_1;
                        fifo_count      <= fifo_count + 1;
                    end
                end
                2'b01: begin  // 只弹出
                    if (!fifo_empty) begin
                        fifo_head  <= (fifo_head + 1 >= FIFO_DEPTH) ? 0 : fifo_head + 1;
                        fifo_count <= fifo_count - 1;
                    end
                end
                2'b11: begin  // 同时推入和弹出
                    if (fifo_push_double) begin
                        // 双推入单弹出
                        fifo[fifo_tail]   <= current_req_low;
                        fifo[next_tail_1] <= current_req_high;
                        fifo_tail         <= next_tail_2;
                        fifo_head         <= (fifo_head + 1 >= FIFO_DEPTH) ? 0 : fifo_head + 1;
                        fifo_count        <= fifo_count + 1;
                    end else begin
                        // 单推入单弹出
                        if (fifo_push_high_only) begin
                            fifo[fifo_tail] <= current_req_high;
                        end else if (fifo_push_single) begin
                            fifo[fifo_tail] <= current_req_low;
                        end
                        fifo_tail <= next_tail_1;
                        fifo_head <= (fifo_head + 1 >= FIFO_DEPTH) ? 0 : fifo_head + 1;
                        // fifo_count保持不变
                    end
                end
                default: begin  // 2'b00: 无操作
                    // 保持当前状态
                end
            endcase
        end
    end

    // 输出选择：优先FIFO中的请求
    mem_req_t output_req;
    assign output_req = fifo_empty ? current_req_low : fifo[fifo_head];

    // 输出信号
    assign mem_req_o = (current_valid || !fifo_empty);
    assign agu_atom_lock = !fifo_empty;
    assign agu_stall_req_o = current_valid && (
        (is_64bit_op && !fifo_has_two_space) ||
        (!is_64bit_op && fifo_full)
    );

    assign mem_op_lb_o = output_req.op_lb;
    assign mem_op_lh_o = output_req.op_lh;
    assign mem_op_lw_o = output_req.op_lw;
    assign mem_op_lbu_o = output_req.op_lbu;
    assign mem_op_lhu_o = output_req.op_lhu;
    assign mem_op_ldh_o = output_req.op_ldh;
    assign mem_op_ldl_o = output_req.op_ldl;
    assign mem_op_sb_o = output_req.op_sb;
    assign mem_op_sh_o = output_req.op_sh;
    assign mem_op_sw_o = output_req.op_sw;
    assign mem_op_load_o = output_req.op_load;
    assign mem_op_store_o = output_req.op_store;

    assign mem_addr_o = output_req.addr;
    assign mem_wmask_o = output_req.wmask;
    assign mem_wdata_o = output_req.wdata;
    assign commit_id_o     = fifo_empty ? commit_id_i     : output_req.commit_id;  // 宽度已自动适配
    assign mem_reg_waddr_o = fifo_empty ? mem_reg_waddr_i : output_req.reg_waddr;  // 新增

    // 地址对齐检测逻辑
    assign misaligned_load_o  = mem_op_load_o  & (
        (mem_op_lw_o  && (mem_addr_o[1:0] != 2'b00)) ||
        ((mem_op_lh_o | mem_op_lhu_o) && (mem_addr_o[0] != 1'b0))
    );

    assign misaligned_store_o = mem_op_store_o & (
        (mem_op_sw_o && (mem_addr_o[1:0] != 2'b00)) ||
        (mem_op_sh_o && (mem_addr_o[0] != 1'b0))
    );

endmodule
