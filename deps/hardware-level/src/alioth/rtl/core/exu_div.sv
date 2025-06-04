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

// 除法模块
// 试商法实现32位整数除法
// 每次除法运算至少需要33个时钟周期才能完成
module exu_div (

    input wire clk,
    input wire rst_n,

    // from ex
    input wire [`REG_DATA_WIDTH-1:0] dividend_i,  // 被除数
    input wire [`REG_DATA_WIDTH-1:0] divisor_i,   // 除数
    input wire                       start_i,     // 开始信号，仅用于触发计算开始
    input wire [                3:0] op_i,        // 操作类型

    // to ex
    output reg [`REG_DATA_WIDTH-1:0] result_o,    // 除法结果，高32位是余数，低32位是商
    output reg                       busy_o,      // 正在运算信号
    output reg                       valid_o      // 输出有效信号

);

    // 状态定义
    typedef enum logic [3:0] {
        STATE_IDLE  = 4'b0001,
        STATE_START = 4'b0010,
        STATE_CALC  = 4'b0100,
        STATE_END   = 4'b1000
    } state_t;

    state_t state;
    reg [`REG_DATA_WIDTH-1:0] dividend_r;
    reg [`REG_DATA_WIDTH-1:0] divisor_r;
    reg [3:0] op_r;
    reg [31:0] count;
    reg [`REG_DATA_WIDTH-1:0] div_result;
    reg [`REG_DATA_WIDTH-1:0] div_remain;
    reg [`REG_DATA_WIDTH-1:0] minuend;
    reg invert_result;

    // 从op_i解析具体操作类型
    wire op_div = op_r[0];
    wire op_divu = op_r[1];
    wire op_rem = op_r[2];
    wire op_remu = op_r[3];

    wire [31:0] dividend_invert = (-dividend_r);
    wire [31:0] divisor_invert = (-divisor_r);
    wire minuend_ge_divisor = minuend >= divisor_r;
    wire [31:0] minuend_sub_res = minuend - divisor_r;
    wire [31:0] div_result_tmp = minuend_ge_divisor ? ({div_result[30:0], 1'b1}) : ({div_result[30:0], 1'b0});
    wire [31:0] minuend_tmp = minuend_ge_divisor ? minuend_sub_res[30:0] : minuend[30:0];

    // 状态机实现
    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= STATE_IDLE;
            result_o      <= `ZeroWord;
            div_result    <= `ZeroWord;
            div_remain    <= `ZeroWord;
            op_r          <= 4'h0;
            dividend_r    <= `ZeroWord;
            divisor_r     <= `ZeroWord;
            minuend       <= `ZeroWord;
            invert_result <= 1'b0;
            busy_o        <= 1'b0;
            valid_o       <= 1'b0;
            count         <= `ZeroWord;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start_i == 1'b1) begin
                        op_r        <= op_i;
                        dividend_r  <= dividend_i;
                        divisor_r   <= divisor_i;
                        state       <= STATE_START;
                        busy_o      <= 1'b1;
                        valid_o     <= 1'b0;
                    end else begin
                        op_r        <= 3'h0;
                        dividend_r  <= `ZeroWord;
                        divisor_r   <= `ZeroWord;
                        result_o    <= `ZeroWord;
                        busy_o      <= 1'b0;
                        valid_o     <= 1'b0;
                    end
                end

                STATE_START: begin
                    valid_o <= 1'b0;
                    // 除数为0
                    if (divisor_r == `ZeroWord) begin
                        if (op_div | op_divu) begin
                            result_o <= 32'hffffffff;
                        end else begin
                            result_o <= dividend_r;
                        end
                        state   <= STATE_IDLE;
                        busy_o  <= 1'b0;
                    // 除数不为0
                    end else begin
                        busy_o     <= 1'b1;
                        count      <= 32'h40000000;
                        state      <= STATE_CALC;
                        div_result <= `ZeroWord;
                        div_remain <= `ZeroWord;

                        // DIV和REM这两条指令是有符号数运算指令
                        if (op_div | op_rem) begin
                            // 被除数求补码
                            if (dividend_r[31] == 1'b1) begin
                                dividend_r <= dividend_invert;
                                minuend    <= dividend_invert[31];
                            end else begin
                                minuend <= dividend_r[31];
                            end
                            // 除数求补码
                            if (divisor_r[31] == 1'b1) begin
                                divisor_r <= divisor_invert;
                            end
                        end else begin
                            minuend <= dividend_r[31];
                        end

                        // 运算结束后是否要对结果取补码
                        if ((op_div && (dividend_r[31] ^ divisor_r[31] == 1'b1))
                            || (op_rem && (dividend_r[31] == 1'b1))) begin
                            invert_result <= 1'b1;
                        end else begin
                            invert_result <= 1'b0;
                        end
                    end
                end

                STATE_CALC: begin
                    valid_o <= 1'b0;
                    dividend_r <= {dividend_r[30:0], 1'b0};
                    div_result <= div_result_tmp;
                    count      <= {1'b0, count[31:1]};
                    if (|count) begin
                        minuend <= {minuend_tmp[30:0], dividend_r[30]};
                    end else begin
                        state <= STATE_END;
                        if (minuend_ge_divisor) begin
                            div_remain <= minuend_sub_res;
                        end else begin
                            div_remain <= minuend;
                        end
                    end
                end

                STATE_END: begin
                    state   <= STATE_IDLE;
                    busy_o  <= 1'b0;
                    valid_o <= 1'b1;
                    if (op_div | op_divu) begin
                        if (invert_result) begin
                            result_o <= (-div_result);
                        end else begin
                            result_o <= div_result;
                        end
                    end else begin
                        if (invert_result) begin
                            result_o <= (-div_remain);
                        end else begin
                            result_o <= div_remain;
                        end
                    end
                end

            endcase
        end
    end

endmodule
