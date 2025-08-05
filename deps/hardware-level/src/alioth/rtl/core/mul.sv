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
 分块乘法实现，支持有符号和无符号32位整数乘法指令（MUL/MULH/MULHSU/MULHU）
 采用移位相加法，按16位分块，复用乘法器和加法器，4个周期完成运算
 支持操作数符号处理，输出高/低32位结果，兼容RISC-V乘法扩展指令
*/
module mul (
    input wire clk,
    input wire rst_n,

    // 来自执行单元的输入
    input wire [`REG_DATA_WIDTH-1:0] multiplicand_i,  // 被乘数
    input wire [`REG_DATA_WIDTH-1:0] multiplier_i,  // 乘数
    input wire start_i,  // 运算开始信号，运算期间需保持有效
    input wire ctrl_ready_i,  // 控制器准备好信号
    input wire [3:0] op_i,  // 操作类型（指令编码）

    // 输出到执行单元
    output reg [`REG_DATA_WIDTH-1:0] result_o,  // 乘法结果
    output reg                       busy_o,    // 运算忙信号
    output reg                       valid_o    // 结果有效信号
);

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE   = 2'b00,  // 空闲
        CALC   = 2'b01,  // 运算中
        OUTPUT = 2'b10   // 输出结果
    } state_t;

    // 内部寄存器
    state_t current_state, next_state;
    reg [                  2:0] count;  // 迭代计数器，4次分块迭代
    reg [                  3:0] op_r;  // 操作类型寄存器
    reg [  `REG_DATA_WIDTH-1:0] abs_multiplicand_r;  // 被乘数绝对值
    reg [  `REG_DATA_WIDTH-1:0] abs_multiplier_r;  // 乘数绝对值
    reg                         result_sign_r;  // 结果符号

    // 分块乘法相关寄存器
    reg [2*`REG_DATA_WIDTH-1:0] p_reg;  // 部分积寄存器
    reg [15:0] a_low, a_high;  // 被乘数低/高16位
    reg [15:0] b_low, b_high;  // 乘数低/高16位

    // 临时变量
    wire [31:0] mcand_tmp, mplier_tmp;

    // 分块选择逻辑：每次迭代选择对应的16位块参与乘法
    wire [15:0] mul_a, mul_b;
    assign mul_a = (count[1] == 1'b0) ? a_low : a_high;
    assign mul_b = (count[0] == 1'b0) ? b_low : b_high;

    // 单周期16位乘法器及移位累加逻辑
    wire [                 31:0] mul_result;
    wire [2*`REG_DATA_WIDTH-1:0] add_result;
    wire [2*`REG_DATA_WIDTH-1:0] shifted_mul_result;

    assign mul_result = mul_a * mul_b;
    // 按分块位置移位累加，4次迭代分别对应不同移位量
    assign shifted_mul_result = {{(2*`REG_DATA_WIDTH-32){1'b0}}, mul_result} << (count == 3'd0 ? 0 :
                                                                               count == 3'd1 ? 16 :
                                                                               count == 3'd2 ? 16 : 32);
    assign add_result = p_reg + shifted_mul_result;

    // 部分积高/低32位
    wire [`REG_DATA_WIDTH-1:0] mult_tmp_high;
    wire [`REG_DATA_WIDTH-1:0] mult_tmp_low;

    assign mult_tmp_high = p_reg[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];
    assign mult_tmp_low  = p_reg[`REG_DATA_WIDTH-1:0];

    // 操作类型相关信号：用于符号处理和绝对值计算
    wire mcand_signed  = (op_i == 4'b0001) || (op_i == 4'b0010) || (op_i == 4'b0100); // MUL, MULH, MULHSU
    wire mplier_signed = (op_i == 4'b0001) || (op_i == 4'b0010);  // MUL, MULH
    wire both_unsigned = (op_i == 4'b1000);  // MULHU
    wire mcand_is_neg = mcand_signed && multiplicand_i[`REG_DATA_WIDTH-1];
    wire mplier_is_neg = mplier_signed && multiplier_i[`REG_DATA_WIDTH-1];

    // 绝对值选择逻辑
    assign mcand_tmp  = both_unsigned ? multiplicand_i : (mcand_is_neg ? -multiplicand_i : multiplicand_i);
    assign mplier_tmp = both_unsigned ? multiplier_i   : (mplier_is_neg ? -multiplier_i : multiplier_i);

    // 状态机转换逻辑
    always @(*) begin
        case (current_state)
            IDLE:
            if (start_i) next_state = CALC;
            else next_state = IDLE;
            CALC:
            if (count == 3'd3) next_state = OUTPUT;  // 4次迭代完成
            else next_state = CALC;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // 状态寄存器更新
    always @(posedge clk) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    // 运算流程
    always @(posedge clk) begin
        if (!rst_n) begin
            busy_o                         <= 1'b0;
            result_o                       <= `ZeroWord;
            valid_o                        <= 1'b0;
            count                          <= 3'd0;
            op_r                           <= 4'h0;
            abs_multiplicand_r             <= `ZeroWord;
            abs_multiplier_r               <= `ZeroWord;
            result_sign_r                  <= 1'b0;
            p_reg                          <= 0;
            {a_low, a_high, b_low, b_high} <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (ctrl_ready_i) begin
                        valid_o <= 1'b0;
                        if (start_i) begin
                            op_r <= op_i;

                            // 操作数绝对值计算
                            abs_multiplicand_r <= both_unsigned ? multiplicand_i : (mcand_is_neg ? -multiplicand_i : multiplicand_i);
                            abs_multiplier_r   <= both_unsigned ? multiplier_i   : (mplier_is_neg ? -multiplier_i : multiplier_i);

                            // 结果符号计算（仅有符号乘法需要）
                            result_sign_r <= both_unsigned ? 1'b0 : ((mcand_is_neg ^ mplier_is_neg) && (mcand_signed || mplier_signed));

                            // 拆分为16位块
                            a_low <= mcand_tmp[15:0];
                            a_high <= mcand_tmp[31:16];
                            b_low <= mplier_tmp[15:0];
                            b_high <= mplier_tmp[31:16];

                            // 初始化部分积
                            p_reg <= 0;
                            count <= 3'd0;
                            busy_o <= 1'b1;
                        end else begin
                            busy_o <= 1'b0;
                        end
                    end
                end

                CALC: begin
                    valid_o <= 1'b0;
                    // 分块乘法累加，4次迭代，每次累加对应块的乘积
                    case (count)
                        3'd0: p_reg <= shifted_mul_result;
                        3'd1: p_reg <= add_result;
                        3'd2: p_reg <= add_result;
                        3'd3: p_reg <= add_result;
                    endcase
                    count <= count + 3'd1;
                end

                OUTPUT: begin
                    logic [2*`REG_DATA_WIDTH-1:0] final_result;
                    // MULHU无符号乘法直接输出，其他类型需恢复符号
                    if (op_r == 4'b1000) begin
                        final_result = p_reg;
                    end else begin
                        final_result = result_sign_r ? -p_reg : p_reg;
                    end

                    // 指令类型选择输出高/低32位
                    case (op_r)
                        4'b0001: result_o <= final_result[`REG_DATA_WIDTH-1:0];  // MUL，低32位
                        4'b0010:
                        result_o <= final_result[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];  // MULH，高32位
                        4'b0100:
                        result_o <= final_result[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];  // MULHSU，高32位
                        4'b1000:
                        result_o <= final_result[2*`REG_DATA_WIDTH-1:`REG_DATA_WIDTH];  // MULHU，高32位
                        default: result_o <= final_result[`REG_DATA_WIDTH-1:0];
                    endcase
                    valid_o <= 1'b1;
                    busy_o  <= 1'b0;
                end
            endcase
        end
    end

endmodule
