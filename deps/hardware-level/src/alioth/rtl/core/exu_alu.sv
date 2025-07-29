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

// 算术逻辑单元 - 采用复用设计
module exu_alu (
    input wire clk,   // 添加时钟信号
    input wire rst_n,

    // ALU
    input  wire                        req_alu_i,
    input  wire                        hazard_stall_i,  // 来自HDU的冒险暂停信号
    input  wire [                31:0] alu_op1_i,
    input  wire [                31:0] alu_op2_i,
    input  wire [   `ALU_OP_WIDTH-1:0] alu_op_info_i,   // 统一的ALU操作信息信号
    input  wire [                 4:0] alu_rd_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,     // ALU指令ID
    // 握手信号和控制
    input  wire                        wb_ready_i,      // 写回单元准备好接收ALU结果
    input  wire                        reg_we_i,        // ALU结果写回寄存器使能
    output wire                        alu_stall_o,     // ALU暂停信号

    // 中断信号
    input wire int_assert_i,

    // 新增：misaligned_fetch输入信号
    input wire misaligned_fetch_i,

    // 结果输出
    output wire [ `REG_DATA_WIDTH-1:0] result_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o   // 输出指令ID
);

    // ALU操作数选择 - 统一的运算器输入
    wire [31:0] mux_op1 = alu_op1_i;
    wire [31:0] mux_op2 = alu_op2_i;

    // ALU运算类型选择(包括R与I类型)
    wire        op_add = alu_op_info_i[`ALU_OP_ADD];
    wire        op_sub = alu_op_info_i[`ALU_OP_SUB];
    wire        op_sll = alu_op_info_i[`ALU_OP_SLL];
    wire        op_slt = alu_op_info_i[`ALU_OP_SLT];
    wire        op_sltu = alu_op_info_i[`ALU_OP_SLTU];
    wire        op_xor = alu_op_info_i[`ALU_OP_XOR];
    wire        op_srl = alu_op_info_i[`ALU_OP_SRL];
    wire        op_sra = alu_op_info_i[`ALU_OP_SRA];
    wire        op_or = alu_op_info_i[`ALU_OP_OR];
    wire        op_and = alu_op_info_i[`ALU_OP_AND];
    wire        op_lui = alu_op_info_i[`ALU_OP_LUI];
    wire        op_auipc = alu_op_info_i[`ALU_OP_AUIPC];
    wire        op_jump = alu_op_info_i[`ALU_OP_JUMP];

    // 指令分类信号 - 便于复用运算器
    wire        op_addsub = op_add | op_sub;  // 加减法操作
    wire        op_shift = op_sll | op_srl | op_sra;  // 移位操作
    wire        op_logic = op_xor | op_or | op_and;  // 逻辑操作
    wire        op_compare = op_slt | op_sltu;  // 比较操作
    wire        op_mvop2 = op_lui;  // 直接使用操作数2

    //////////////////////////////////////////////////////////////
    // 1. 实现移位器 - 统一实现左移，右移通过输入翻转实现
    //////////////////////////////////////////////////////////////
    wire [31:0] shifter_in1;
    wire [ 4:0] shifter_in2;
    wire [31:0] shifter_res;

    // 为右移操作翻转输入位
    assign shifter_in1 = {32{op_shift}} & ((op_sra | op_srl) ? {  // 输入位反转
        mux_op1[00],mux_op1[01],mux_op1[02],mux_op1[03],
            mux_op1[04],mux_op1[05],mux_op1[06],mux_op1[07],
            mux_op1[08],mux_op1[09],mux_op1[10],mux_op1[11],
            mux_op1[12],mux_op1[13],mux_op1[14],mux_op1[15],
            mux_op1[16],mux_op1[17],mux_op1[18],mux_op1[19],
            mux_op1[20],mux_op1[21],mux_op1[22],mux_op1[23],
            mux_op1[24],mux_op1[25],mux_op1[26],mux_op1[27],
            mux_op1[28],mux_op1[29],mux_op1[30],mux_op1[31]
        } : mux_op1
    );

    assign shifter_in2 = {5{op_shift}} & mux_op2[4:0];

    // 执行左移操作
    assign shifter_res = (shifter_in1 << shifter_in2);

    // 左移结果
    wire [31:0] sll_res = shifter_res;

    // 逻辑右移结果 - 通过反转左移结果
    wire [31:0] srl_res = {
        shifter_res[00],
        shifter_res[01],
        shifter_res[02],
        shifter_res[03],
        shifter_res[04],
        shifter_res[05],
        shifter_res[06],
        shifter_res[07],
        shifter_res[08],
        shifter_res[09],
        shifter_res[10],
        shifter_res[11],
        shifter_res[12],
        shifter_res[13],
        shifter_res[14],
        shifter_res[15],
        shifter_res[16],
        shifter_res[17],
        shifter_res[18],
        shifter_res[19],
        shifter_res[20],
        shifter_res[21],
        shifter_res[22],
        shifter_res[23],
        shifter_res[24],
        shifter_res[25],
        shifter_res[26],
        shifter_res[27],
        shifter_res[28],
        shifter_res[29],
        shifter_res[30],
        shifter_res[31]
    };

    // 算术右移结果 - 在逻辑右移基础上处理符号位
    wire [31:0] shift_mask = ~(32'hffffffff >> shifter_in2);
    wire [31:0] sra_res = (srl_res & (~shift_mask)) | ({32{mux_op1[31]}} & shift_mask);

    //////////////////////////////////////////////////////////////
    // 2. 实现加减法器 - 统一处理加减法和比较操作
    //////////////////////////////////////////////////////////////
    wire [31:0] adder_in1;
    wire [31:0] adder_in2;
    wire adder_cin;
    wire [32:0] adder_res;  // 33位，包含进位信息

    // 标识无符号操作
    wire op_unsigned = op_sltu;

    // 加减法操作 - 复用于加减法、比较、地址计算等
    wire adder_op = op_addsub | op_compare | op_auipc | op_jump;

    // 操作数选择 - 使用门控优化
    // 无符号操作时不进行符号扩展
    assign adder_in1 = {32{adder_op}} & mux_op1;
    assign adder_in2 = {32{adder_op}} & (op_sub | op_compare ? ~mux_op2 : mux_op2);
    assign adder_cin = adder_op & (op_sub | op_compare);

    // 执行加法运算
    assign adder_res = {1'b0, adder_in1} + {1'b0, adder_in2} + {{32{1'b0}}, adder_cin};

    //////////////////////////////////////////////////////////////
    // 3. 实现逻辑运算单元 - XOR, OR, AND
    //////////////////////////////////////////////////////////////
    wire [31:0] xor_res = {32{op_xor}} & (mux_op1 ^ mux_op2);
    wire [31:0] or_res = {32{op_or}} & (mux_op1 | mux_op2);
    wire [31:0] and_res = {32{op_and}} & (mux_op1 & mux_op2);

    //////////////////////////////////////////////////////////////
    // 4. 实现比较运算结果
    //////////////////////////////////////////////////////////////
    // 有符号比较结果: mux_op1 < mux_op2
    // 对于有符号比较，需要考虑两种情况：
    // 1. 如果两个操作数符号不同，则负数 < 正数
    // 2. 如果两个操作数符号相同，则比较减法结果的符号位
    wire op1_sign = mux_op1[31];
    wire op2_sign = mux_op2[31];
    wire signs_differ = op1_sign != op2_sign;

    // 当符号不同时，op1为负数则op1<op2
    // 当符号相同时，检查减法结果的符号位
    wire is_lt_signed = signs_differ ? op1_sign : adder_res[31];

    // 无符号比较结果: mux_op1 < mux_op2
    // 对于无符号比较，直接检查加法器的进位输出
    // 注意：进行减法运算时为(A + ~B + 1)，如果结果有进位，则表示A >= B
    // 如果无进位(adder_res[32]=0)，则表示发生借位，即A < B
    wire is_lt_unsigned = ~adder_res[32];

    // 生成比较结果，将最低位设置为比较结果，高位全为0
    wire [31:0] slt_res = {31'b0, is_lt_signed};
    wire [31:0] sltu_res = {31'b0, is_lt_unsigned};

    //////////////////////////////////////////////////////////////
    // 5. LUI操作结果 - 直接使用操作数2
    //////////////////////////////////////////////////////////////
    wire [31:0] lui_res = mux_op2;

    //////////////////////////////////////////////////////////////
    // 6. 结果选择器 - 根据操作类型选择最终结果
    //////////////////////////////////////////////////////////////
    wire [31:0] alu_res =
        ({32{int_assert_i == `INT_ASSERT}} & 32'h0) |
        ({32{!req_alu_i && !op_jump}} & 32'h0) |
        ({32{op_add | op_auipc | op_jump}} & adder_res[31:0]) |
        ({32{op_sub}} & adder_res[31:0]) |
        ({32{op_xor}} & xor_res) |
        ({32{op_or}} & or_res) |
        ({32{op_and}} & and_res) |
        ({32{op_sll}} & sll_res) |
        ({32{op_srl}} & srl_res) |
        ({32{op_sra}} & sra_res) |
        ({32{op_slt}} & slt_res) |
        ({32{op_sltu}} & sltu_res) |
        ({32{op_lui}} & lui_res);

    // 所有算术逻辑操作都需要写回寄存器
    // 如果misaligned_fetch_i为1，则忽略op_jump
    wire alu_r_we = !(int_assert_i == `INT_ASSERT) && (req_alu_i | op_jump) && reg_we_i;

    // 目标寄存器地址逻辑
    wire [4:0] alu_r_waddr = (int_assert_i == `INT_ASSERT || misaligned_fetch_i) ? 5'b0 : alu_rd_i;

    // 握手信号控制逻辑
    wire update_output = (wb_ready_i | ~reg_we_o);

    // 使用gnrl_dfflr实例化输出级寄存器
    wire [`REG_DATA_WIDTH-1:0] result_r;
    wire reg_we_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_r;  // commit ID寄存器

    // 握手失败时输出stall信号
    assign alu_stall_o = reg_we_r & ~wb_ready_i;

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
