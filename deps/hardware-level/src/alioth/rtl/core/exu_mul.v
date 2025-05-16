/*                                                                      
 Copyright 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "defines.v"

// 乘法模块
// 使用Booth算法实现32位整数乘法
module exu_mul (
    input wire clk,
    input wire rst,

    // from ex
    input wire [`REG_DATA_WIDTH-1:0] multiplicand_i,  // 被乘数
    input wire [`REG_DATA_WIDTH-1:0] multiplier_i,    // 乘数
    input wire                       start_i,         // 开始信号，与除法器一致，运算期间需保持有效
    input wire [                2:0] op_i,            // 具体是哪一条指令
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,     // 运算结束后需要写的寄存器

    // to ex
    output reg [`REG_DATA_WIDTH-1:0] result_o,    // 乘法结果
    output reg                       ready_o,     // 运算结束信号
    output reg                       busy_o,      // 正在运算信号
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o  // 运算结束后需要写的寄存器
);

    // 状态定义 - 使用与参考代码相同的状态定义
    localparam IDLE = 2'b00;
    localparam ADD = 2'b01;
    localparam SHIFT = 2'b11;
    localparam OUTPUT = 2'b10;

    // 内部寄存器
    reg [1:0] current_state, next_state;
    reg [4:0] count;  // 迭代计数器，32位需要16次迭代
    reg [2:0] op_r;
    reg [`REG_DATA_WIDTH-1:0] multiplicand_r;
    reg [`REG_DATA_WIDTH-1:0] multiplier_r;
    reg [`REG_ADDR_WIDTH-1:0] reg_waddr_r;

    // booth算法相关寄存器
    reg [2*`REG_DATA_WIDTH+2:0] add1;  // +1倍被乘数
    reg [2*`REG_DATA_WIDTH+2:0] sub1;  // -1倍被乘数
    reg [2*`REG_DATA_WIDTH+2:0] add_x2;  // +2倍被乘数
    reg [2*`REG_DATA_WIDTH+2:0] sub_x2;  // -2倍被乘数
    reg [2*`REG_DATA_WIDTH+2:0] p_reg;  // 部分积

    // 把高 32 位先拿出来
    wire [`REG_DATA_WIDTH-1:0] mult_tmp_high;
    wire [`REG_DATA_WIDTH-1:0] mult_tmp_low;

    assign mult_tmp_high = p_reg[2*`REG_DATA_WIDTH:(`REG_DATA_WIDTH+1)];
    assign mult_tmp_low  = p_reg[`REG_DATA_WIDTH:1];

    // 含无符号数乘法的结果修复
    // 如果被乘数最高位是 1，则误多算了 -2^32*multiplier，所以加回 multiplier
    wire [`REG_DATA_WIDTH-1:0] add_mul;
    assign add_mul = multiplicand_r[`REG_DATA_WIDTH-1] ? multiplier_r : {`REG_DATA_WIDTH{1'b0}};

    // 如果乘数最高位是 1，则误多算了 -2^32*multiplicand，所以加回 multiplicand
    wire [`REG_DATA_WIDTH-1:0] add_mcand;
    assign add_mcand = multiplier_r[`REG_DATA_WIDTH-1] ? multiplicand_r : {`REG_DATA_WIDTH{1'b0}};

    // 符号处理相关变量
    wire is_signed_op1;
    wire is_signed_op2;

    // 根据指令类型确定是否进行符号处理
    assign is_signed_op1 = (op_i == `INST_MULH || op_i == `INST_MULHSU);
    assign is_signed_op2 = (op_i == `INST_MULH);

    // 状态转换逻辑
    always @(*) begin
        next_state = 2'bxx;
        case (current_state)
            IDLE:    if (start_i) next_state = ADD;
 else next_state = IDLE;
            ADD:     next_state = SHIFT;
            SHIFT:   if (count == 5'd16) next_state = OUTPUT;  // 32位乘法需要16次迭代
 else next_state = ADD;
            OUTPUT:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // 状态寄存器更新
    always @(posedge clk) begin
        if (rst == `RstEnable) current_state <= IDLE;
        else if (!start_i) current_state <= IDLE;
        else current_state <= next_state;
    end

    // 操作执行
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            ready_o                             <= 1'b0;
            busy_o                              <= `False;
            result_o                            <= `ZeroWord;
            count                               <= 5'd0;
            op_r                                <= 3'h0;
            multiplicand_r                      <= `ZeroWord;
            multiplier_r                        <= `ZeroWord;
            reg_waddr_o                         <= `ZeroWord;
            reg_waddr_r                         <= `ZeroWord;
            {add1, sub1, add_x2, sub_x2, p_reg} <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start_i) begin
                        // 保存操作数和指令类型
                        multiplicand_r <= multiplicand_i;
                        multiplier_r <= multiplier_i;
                        op_r <= op_i;
                        reg_waddr_r <= reg_waddr_i;
                        reg_waddr_o <= reg_waddr_i;

                        // 初始化Booth Radix-4乘法器相关寄存器
                        add1    <= {{2{multiplicand_i[31]}}, multiplicand_i, {`REG_DATA_WIDTH+1{1'b0}}};
                        sub1    <= { -{{2{multiplicand_i[31]}}, multiplicand_i}, {`REG_DATA_WIDTH+1{1'b0}} };
                        add_x2  <= { {multiplicand_i[31], multiplicand_i, 1'b0}, {`REG_DATA_WIDTH+1{1'b0}} };
                        sub_x2  <= { -{multiplicand_i[31], multiplicand_i, 1'b0}, {`REG_DATA_WIDTH+1{1'b0}} };
                        p_reg   <= {{`REG_DATA_WIDTH+1{1'b0}}, multiplier_i, 1'b0};

                        count <= 5'd0;
                        busy_o <= `True;
                        ready_o <= 1'b0;
                    end else begin
                        busy_o  <= `False;
                        ready_o <= 1'b0;
                    end
                end

                ADD: begin
                    // Radix-4 Booth算法核心计算 - 根据乘数的低3位决定操作
                    case (p_reg[2:0])
                        3'b000, 3'b111: p_reg <= p_reg;  // 不操作
                        3'b001, 3'b010: p_reg <= p_reg + add1;  // +1倍被乘数
                        3'b101, 3'b110: p_reg <= p_reg + sub1;  // -1倍被乘数
                        3'b011:         p_reg <= p_reg + add_x2;  // +2倍被乘数
                        3'b100:         p_reg <= p_reg + sub_x2;  // -2倍被乘数
                        default:        p_reg <= p_reg;
                    endcase
                    count <= count + 5'd1;  // 计数增加
                end

                SHIFT: begin
                    // 算术右移2位（Radix-4）
                    p_reg <= {p_reg[2*`REG_DATA_WIDTH+2], p_reg[2*`REG_DATA_WIDTH+2], p_reg[2*`REG_DATA_WIDTH+2:2]};
                end

                OUTPUT: begin
                    // 根据指令类型选择输出结果
                    case (op_r)
                        `INST_MUL: result_o <= p_reg[`REG_DATA_WIDTH:1];  // 取低32位
                        `INST_MULH: begin
                            result_o <= p_reg[2*`REG_DATA_WIDTH:(`REG_DATA_WIDTH+1)];
                        end
                        `INST_MULHSU: begin
                            result_o <= mult_tmp_high + add_mcand;
                        end
                        `INST_MULHU:
                            result_o <= mult_tmp_high + add_mul + add_mcand;  // 无符号*无符号=无符号
                        default: result_o <= p_reg[`REG_DATA_WIDTH:1];
                    endcase

                    ready_o <= 1'b1;
                    busy_o  <= `False;
                end
            endcase
        end
    end

endmodule
