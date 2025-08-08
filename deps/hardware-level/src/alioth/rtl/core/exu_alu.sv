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

// 算术逻辑单元 - 模块化设计，用于双发射
module exu_alu (
    input wire clk,
    input wire rst_n,

    // 来自dispatch的输入信号
    input wire                        req_alu_i,
    input wire [                31:0] alu_op1_i,
    input wire [                31:0] alu_op2_i,
    input wire [   `ALU_OP_WIDTH-1:0] alu_op_info_i,
    input wire [                 4:0] alu_rd_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,
    input wire                        reg_we_i,        // 寄存器写使能

    // 握手信号
    input  wire wb_ready_i,      // 写回单元准备好接收ALU结果
    output wire alu_stall_o,     // ALU暂停信号

    // 中断信号
    input wire int_assert_i,

    // 结果输出到WBU
    output wire [ `REG_DATA_WIDTH-1:0] result_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // ALU操作数选择
    wire [31:0] mux_op1 = alu_op1_i;
    wire [31:0] mux_op2 = alu_op2_i;

    // ALU运算类型选择
    wire op_add = alu_op_info_i[`ALU_OP_ADD];
    wire op_sub = alu_op_info_i[`ALU_OP_SUB];
    wire op_sll = alu_op_info_i[`ALU_OP_SLL];
    wire op_slt = alu_op_info_i[`ALU_OP_SLT];
    wire op_sltu = alu_op_info_i[`ALU_OP_SLTU];
    wire op_xor = alu_op_info_i[`ALU_OP_XOR];
    wire op_srl = alu_op_info_i[`ALU_OP_SRL];
    wire op_sra = alu_op_info_i[`ALU_OP_SRA];
    wire op_or = alu_op_info_i[`ALU_OP_OR];
    wire op_and = alu_op_info_i[`ALU_OP_AND];
    wire op_lui = alu_op_info_i[`ALU_OP_LUI];
    wire op_auipc = alu_op_info_i[`ALU_OP_AUIPC];
    wire op_jump = alu_op_info_i[`ALU_OP_JUMP];

    // 加法器子模块的结果
    wire [31:0] add_result;
    wire [31:0] sub_result;
    wire [31:0] slt_result;
    wire [31:0] sltu_result;
    wire [31:0] auipc_result;

    // 移位器子模块的结果
    wire [31:0] sll_result;
    wire [31:0] srl_result;
    wire [31:0] sra_result;
    wire [31:0] xor_result;
    wire [31:0] or_result;
    wire [31:0] and_result;

    // 实例化加法器子模块
    exu_alu_adder u_alu_adder (
        .op1_i         (mux_op1),
        .op2_i         (mux_op2),
        .op_add_i      (op_add),
        .op_sub_i      (op_sub),
        .op_slt_i      (op_slt),
        .op_sltu_i     (op_sltu),
        .op_auipc_i    (op_auipc),
        .add_result_o  (add_result),
        .sub_result_o  (sub_result),
        .slt_result_o  (slt_result),
        .sltu_result_o (sltu_result),
        .auipc_result_o(auipc_result)
    );

    // 实例化移位器子模块
    exu_alu_shifter u_alu_shifter (
        .op1_i         (mux_op1),
        .op2_i         (mux_op2),
        .op_sll_i      (op_sll),
        .op_srl_i      (op_srl),
        .op_sra_i      (op_sra),
        .op_xor_i      (op_xor),
        .op_or_i       (op_or),
        .op_and_i      (op_and),
        .sll_result_o  (sll_result),
        .srl_result_o  (srl_result),
        .sra_result_o  (sra_result),
        .xor_result_o  (xor_result),
        .or_result_o   (or_result),
        .and_result_o  (and_result)
    );

    // LUI操作结果
    wire [31:0] lui_result = mux_op2;

    // 结果选择器
    wire [31:0] alu_res =
        ({32{int_assert_i == `INT_ASSERT}} & 32'h0) |
        ({32{!req_alu_i && !op_jump}} & 32'h0) |
        ({32{op_add | op_auipc | op_jump}} & add_result) |
        ({32{op_sub}} & sub_result) |
        ({32{op_xor}} & xor_result) |
        ({32{op_or}} & or_result) |
        ({32{op_and}} & and_result) |
        ({32{op_sll}} & sll_result) |
        ({32{op_srl}} & srl_result) |
        ({32{op_sra}} & sra_result) |
        ({32{op_slt}} & slt_result) |
        ({32{op_sltu}} & sltu_result) |
        ({32{op_lui}} & lui_result);

    // 写回使能逻辑
    wire alu_r_we = !(int_assert_i) && (req_alu_i) && reg_we_i;

    // 目标寄存器地址逻辑
    wire [4:0] alu_r_waddr = (int_assert_i == `INT_ASSERT) ? 5'b0 : alu_rd_i;

    // 握手信号控制逻辑
    wire update_output = (wb_ready_i | ~reg_we_o);

    // 输出级寄存器
    wire [`REG_DATA_WIDTH-1:0] result_r;
    wire reg_we_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_r;

    // 握手失败时输出stall信号
    assign alu_stall_o = reg_we_r & ~wb_ready_i && alu_r_we;

    // 结果寄存器
    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) u_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (alu_res),
        .qout (result_r)
    );

    // 写使能寄存器
    gnrl_dfflr #(
        .DW(1)
    ) u_r_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (alu_r_we),
        .qout (reg_we_r)
    );

    // 写地址寄存器
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) u_r_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (alu_r_waddr),
        .qout (reg_waddr_r)
    );

    // commit ID寄存器
    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) u_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (commit_id_i),
        .qout (commit_id_r)
    );

    // 输出信号赋值
    assign result_o    = result_r;
    assign reg_we_o    = reg_we_r;
    assign reg_waddr_o = reg_waddr_r;
    assign commit_id_o = commit_id_r;

endmodule
