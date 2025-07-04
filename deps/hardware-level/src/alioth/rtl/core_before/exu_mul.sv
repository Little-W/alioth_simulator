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

// 乘法模块
// 使用Booth算法实现32位整数乘法
module exu_mul (
    input wire clk,
    input wire rst_n,

    // from ex
    input wire [`REG_DATA_WIDTH-1:0] multiplicand_i,  // 被乘数
    input wire [`REG_DATA_WIDTH-1:0] multiplier_i,    // 乘数
    input wire                       start_i,         // 开始信号，与除法器一致，运算期间需保持有效
    input wire [                3:0] op_i,            // 操作类型

    // to ex
    output reg [`REG_DATA_WIDTH-1:0] result_o,    // 乘法结果
    output reg                       busy_o,      // 正在运算信号
    output reg                       valid_o      // 输出有效信号
);

    // 状态定义
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        CALC   = 2'b01,
        OUTPUT = 2'b10
    } state_t;

    // 内部寄存器
    state_t current_state, next_state;
    reg  [                  4:0] count;  // 迭代计数器，32位需要16次迭代
    reg  [                  3:0] op_r;
    reg  [  `REG_DATA_WIDTH-1:0] multiplicand_r;
    reg  [  `REG_DATA_WIDTH-1:0] multiplier_r;

    // booth算法相关寄存器
    reg  [2*`REG_DATA_WIDTH+2:0] add1;  // +1倍被乘数
    reg  [2*`REG_DATA_WIDTH+2:0] sub1;  // -1倍被乘数
    reg  [2*`REG_DATA_WIDTH+2:0] add_x2;  // +2倍被乘数
    reg  [2*`REG_DATA_WIDTH+2:0] sub_x2;  // -2倍被乘数
    reg  [2*`REG_DATA_WIDTH+2:0] p_reg;  // 部分积
    reg  [2*`REG_DATA_WIDTH+2:0] temp_result; // Booth算法临时结果

    // 把高 32 位先拿出来
    wire [  `REG_DATA_WIDTH-1:0] mult_tmp_high;
    wire [  `REG_DATA_WIDTH-1:0] mult_tmp_low;

    assign mult_tmp_high = p_reg[2*`REG_DATA_WIDTH:(`REG_DATA_WIDTH+1)];
    assign mult_tmp_low  = p_reg[`REG_DATA_WIDTH:1];

    // 含无符号数乘法的结果修复
    // 如果被乘数最高位是 1，则误多算了 -2^32*multiplier，所以加回 multiplier
    wire [`REG_DATA_WIDTH-1:0] add_mul;
    assign add_mul = multiplicand_r[`REG_DATA_WIDTH-1] ? multiplier_r : {`REG_DATA_WIDTH{1'b0}};

    // 如果乘数最高位是 1，则误多算了 -2^32*multiplicand，所以加回 multiplicand
    wire [`REG_DATA_WIDTH-1:0] add_mcand;
    assign add_mcand = multiplier_r[`REG_DATA_WIDTH-1] ? multiplicand_r : {`REG_DATA_WIDTH{1'b0}};

    // 状态转换逻辑
    always @(*) begin
        case (current_state)
            IDLE:    if (start_i) next_state = CALC;
                     else next_state = IDLE;
            CALC:    if (count == 5'd15) next_state = OUTPUT;  // 32位乘法需要16次迭代
                     else next_state = CALC;
            OUTPUT:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // 状态寄存器更新
    always @(posedge clk) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    // 操作执行
    always @(posedge clk) begin
        if (!rst_n) begin
            busy_o                              <= 1'b0;
            result_o                            <= `ZeroWord;
            valid_o                             <= 1'b0;
            count                               <= 5'd0;
            op_r                                <= 4'h0;
            multiplicand_r                      <= `ZeroWord;
            multiplier_r                        <= `ZeroWord;
            {add1, sub1, add_x2, sub_x2, p_reg} <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    valid_o            <= 1'b0;
                    if (start_i) begin
                        // 保存操作数和指令类型
                        multiplicand_r <= multiplicand_i;
                        multiplier_r   <= multiplier_i;
                        op_r           <= op_i;

                        // 初始化Booth Radix-4乘法器相关寄存器
                        add1           <= {{2{multiplicand_i[31]}}, multiplicand_i, {`REG_DATA_WIDTH + 1{1'b0}}};
                        sub1           <= {-{{2{multiplicand_i[31]}}, multiplicand_i}, {`REG_DATA_WIDTH + 1{1'b0}}};
                        add_x2         <= {{multiplicand_i[31], multiplicand_i, 1'b0}, {`REG_DATA_WIDTH + 1{1'b0}}};
                        sub_x2         <= {-{multiplicand_i[31], multiplicand_i, 1'b0}, {`REG_DATA_WIDTH + 1{1'b0}}};
                        p_reg          <= {{`REG_DATA_WIDTH + 1{1'b0}}, multiplier_i, 1'b0};

                        count          <= 5'd0;
                        busy_o         <= 1'b1;
                    end else begin
                        busy_o         <= 1'b0;
                    end
                end

                CALC: begin
                    valid_o <= 1'b0;

                    // Radix-4 Booth算法核心计算 - 根据乘数的低3位决定操作
                    case (p_reg[2:0])
                        3'b000, 3'b111: temp_result = p_reg;  // 不操作
                        3'b001, 3'b010: temp_result = p_reg + add1;  // +1倍被乘数
                        3'b101, 3'b110: temp_result = p_reg + sub1;  // -1倍被乘数
                        3'b011:         temp_result = p_reg + add_x2;  // +2倍被乘数
                        3'b100:         temp_result = p_reg + sub_x2;  // -2倍被乘数
                        default:        temp_result = p_reg;
                    endcase

                    // 算术右移2位（Radix-4）
                    p_reg <= {
                        temp_result[2*`REG_DATA_WIDTH+2],
                        temp_result[2*`REG_DATA_WIDTH+2],
                        temp_result[2*`REG_DATA_WIDTH+2:2]
                    };
                    count <= count + 5'd1;  // 计数增加
                end

                OUTPUT: begin
                    // 根据指令类型选择输出结果
                    case (op_r)
                        4'b0001: begin  // MUL - 取低32位
                            result_o <= mult_tmp_low;
                        end
                        4'b0010: begin  // MULH - 有符号*有符号=有符号
                            result_o <= mult_tmp_high;
                        end
                        4'b0100: begin  // MULHSU - 有符号*无符号=有符号
                            result_o <= mult_tmp_high + add_mcand;
                        end
                        4'b1000: begin  // MULHU - 无符号*无符号=无符号
                            result_o <= mult_tmp_high + add_mul + add_mcand;
                        end
                        default: begin
                            result_o <= mult_tmp_low;
                        end
                    endcase
                    valid_o <= 1'b1;
                    busy_o  <= 1'b0;
                end
            endcase
        end
    end

endmodule
