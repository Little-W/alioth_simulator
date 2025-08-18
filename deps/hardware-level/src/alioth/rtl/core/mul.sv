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

/*
 乘法模块
 3级流水线实现，支持有符号和无符号32位整数乘法指令（MUL/MULH/MULHSU/MULHU）
 第一级：符号处理和操作数准备
 第二级：分块乘法计算
 第三级：结果累加和输出选择
 支持流水线暂停控制，兼容RISC-V乘法扩展指令
*/
module mul (
    input wire clk,
    input wire rst_n,

    // 来自执行单元的输入
    input wire [`REG_DATA_WIDTH-1:0] multiplicand_i,  // 被乘数
    input wire [`REG_DATA_WIDTH-1:0] multiplier_i,    // 乘数
    input wire                       valid_in,        // 输入有效信号
    input wire                       ctrl_ready_i,    // 控制器准备好信号
    input wire [                3:0] op_i,            // 操作类型（指令编码）
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,    // 写回地址
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,    // 提交ID

    // 输出到执行单元
    output reg [`REG_DATA_WIDTH-1:0] result_o,        // 乘法结果
    output reg                       valid_o,         // 结果有效信号
    output reg [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,    // 写回地址输出
    output reg [`COMMIT_ID_WIDTH-1:0] commit_id_o     // 提交ID输出
);

    // 流水线暂停控制信号
    wire                       pipeline_enable = ctrl_ready_i;

    // 第一级流水线寄存器
    reg  [                3:0] op_s1;
    reg  [`REG_DATA_WIDTH-1:0] abs_multiplicand_s1;
    reg  [`REG_DATA_WIDTH-1:0] abs_multiplier_s1;
    reg                        result_sign_s1;
    reg [15:0] a_low_s1, a_high_s1;
    reg [15:0] b_low_s1, b_high_s1;
    reg valid_s1;
    reg [ `REG_ADDR_WIDTH-1:0] reg_waddr_s1;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_s1;

    // 第二级流水线寄存器
    reg [3:0] op_s2;
    reg result_sign_s2;
    reg [31:0] mul_blk_s2[0:3];
    reg valid_s2;
    reg [ `REG_ADDR_WIDTH-1:0] reg_waddr_s2;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_s2;

    // 操作类型相关信号：用于符号处理和绝对值计算
    wire mcand_signed = (op_i == 4'b0001) || (op_i == 4'b0010) || (op_i == 4'b0100);
    wire mplier_signed = (op_i == 4'b0001) || (op_i == 4'b0010);
    wire both_unsigned = (op_i == 4'b1000);
    wire mcand_is_neg = mcand_signed && multiplicand_i[`REG_DATA_WIDTH-1];
    wire mplier_is_neg = mplier_signed && multiplier_i[`REG_DATA_WIDTH-1];

    // 绝对值选择逻辑
    wire [`REG_DATA_WIDTH-1:0] mcand_tmp  = both_unsigned ? multiplicand_i : (mcand_is_neg ? -multiplicand_i : multiplicand_i);
    wire [`REG_DATA_WIDTH-1:0] mplier_tmp = both_unsigned ? multiplier_i   : (mplier_is_neg ? -multiplier_i : multiplier_i);

    // 第一级流水线：符号处理和操作数准备
    always @(posedge clk) begin
        if (!rst_n) begin
            op_s1                                      <= 4'h0;
            abs_multiplicand_s1                        <= `ZeroWord;
            abs_multiplier_s1                          <= `ZeroWord;
            result_sign_s1                             <= 1'b0;
            {a_low_s1, a_high_s1, b_low_s1, b_high_s1} <= 0;
            valid_s1                                   <= 1'b0;
            reg_waddr_s1                               <= {`REG_ADDR_WIDTH{1'b0}};
            commit_id_s1                               <= {`COMMIT_ID_WIDTH{1'b0}};
        end else if (pipeline_enable) begin
            op_s1 <= op_i;

            // 操作数绝对值计算
            abs_multiplicand_s1 <= mcand_tmp;
            abs_multiplier_s1 <= mplier_tmp;

            // 结果符号计算（仅有符号乘法需要）
            result_sign_s1 <= both_unsigned ? 1'b0 : ((mcand_is_neg ^ mplier_is_neg) && (mcand_signed || mplier_signed));

            // 拆分为16位块
            a_low_s1 <= mcand_tmp[15:0];
            a_high_s1 <= mcand_tmp[31:16];
            b_low_s1 <= mplier_tmp[15:0];
            b_high_s1 <= mplier_tmp[31:16];

            valid_s1 <= valid_in;
            reg_waddr_s1 <= reg_waddr_i;
            commit_id_s1 <= commit_id_i;
        end
    end

    // 第二级流水线：分块乘法计算
    always @(posedge clk) begin
        if (!rst_n) begin
            op_s2          <= 4'h0;
            result_sign_s2 <= 1'b0;
            mul_blk_s2[0]  <= 32'b0;
            mul_blk_s2[1]  <= 32'b0;
            mul_blk_s2[2]  <= 32'b0;
            mul_blk_s2[3]  <= 32'b0;
            valid_s2       <= 1'b0;
            reg_waddr_s2   <= {`REG_ADDR_WIDTH{1'b0}};
            commit_id_s2   <= {`COMMIT_ID_WIDTH{1'b0}};
        end else if (pipeline_enable) begin
            op_s2          <= op_s1;
            result_sign_s2 <= result_sign_s1;

            // 一次性计算4个分块乘法结果
            mul_blk_s2[0]  <= a_low_s1 * b_low_s1;
            mul_blk_s2[1]  <= a_high_s1 * b_low_s1;
            mul_blk_s2[2]  <= a_low_s1 * b_high_s1;
            mul_blk_s2[3]  <= a_high_s1 * b_high_s1;

            valid_s2       <= valid_s1;
            reg_waddr_s2   <= reg_waddr_s1;
            commit_id_s2   <= commit_id_s1;
        end
    end

    // 第三级流水线：结果累加和输出选择
    always @(posedge clk) begin
        if (!rst_n) begin
            result_o <= `ZeroWord;
            valid_o  <= 1'b0;
            reg_waddr_o <= {`REG_ADDR_WIDTH{1'b0}};
            commit_id_o <= {`COMMIT_ID_WIDTH{1'b0}};
        end else if (pipeline_enable) begin
            logic [2*`REG_DATA_WIDTH-1:0] final_result;

            // 统一移位和累加
            final_result = {32'b0, mul_blk_s2[0]} +
                          ({16'b0, mul_blk_s2[1], 16'b0}) +
                          ({16'b0, mul_blk_s2[2], 16'b0}) +
                          ({mul_blk_s2[3], 32'b0});

            // MULHU无符号乘法直接输出，其他类型需恢复符号
            if (op_s2 != 4'b1000) begin
                final_result = result_sign_s2 ? -final_result : final_result;
            end

            // 指令类型选择输出高/低32位
            case (op_s2)
                4'b0001: result_o <= final_result[`REG_DATA_WIDTH-1:0];  // MUL，低32位
                4'b0010:
                result_o <= final_result[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];  // MULH，高32位
                4'b0100:
                result_o <= final_result[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];  // MULHSU，高32位
                4'b1000:
                result_o <= final_result[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];  // MULHU，高32位
                default: result_o <= final_result[`REG_DATA_WIDTH-1:0];
            endcase

            valid_o <= valid_s2;
            reg_waddr_o <= reg_waddr_s2;
            commit_id_o <= commit_id_s2;
        end
    end

endmodule
