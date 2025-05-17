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
    localparam CALC = 2'b01;    // 合并了原来的ADD和SHIFT
    localparam OUTPUT = 2'b10;
    
    // Booth算法参数定义
    localparam RADIX = 4;                             // 基4 Booth算法
    localparam BITS_PER_ITER = 2;                     // 每次迭代处理的位数
    localparam NUM_ITERS = `REG_DATA_WIDTH/BITS_PER_ITER; // 迭代次数=32/2=16
    localparam COUNTER_WIDTH = $clog2(NUM_ITERS+1);   // 计数器位宽
    
    // 扩展位宽定义
    localparam EXTENDED_WIDTH = 2*`REG_DATA_WIDTH+3;  // 2*32+3=67位，包含符号位扩展和LSB
    localparam RESULT_MSB = 2*`REG_DATA_WIDTH+2;      // 结果的最高位(MSB)
    localparam HIGH_PART_MSB = 2*`REG_DATA_WIDTH;     // 高32位的MSB
    localparam HIGH_PART_LSB = `REG_DATA_WIDTH+1;     // 高32位的LSB
    localparam LOW_PART_MSB = `REG_DATA_WIDTH;        // 低32位的MSB
    localparam LOW_PART_LSB = 1;                      // 低32位的LSB，因为位0是附加位

    // 内部寄存器
    reg [1:0] current_state, next_state;
    reg [COUNTER_WIDTH-1:0] count;                    // 迭代计数器
    reg [2:0] op_r;
    reg [`REG_DATA_WIDTH-1:0] multiplicand_r;
    reg [`REG_DATA_WIDTH-1:0] multiplier_r;
    reg [`REG_ADDR_WIDTH-1:0] reg_waddr_r;

    // booth算法相关寄存器 - 位宽明确定义
    reg [EXTENDED_WIDTH-1:0] add1;    // +1倍被乘数
    reg [EXTENDED_WIDTH-1:0] sub1;    // -1倍被乘数
    reg [EXTENDED_WIDTH-1:0] add_x2;  // +2倍被乘数
    reg [EXTENDED_WIDTH-1:0] sub_x2;  // -2倍被乘数
    reg [EXTENDED_WIDTH-1:0] p_reg;   // 部分积寄存器，格式: [sign_extension(2*W+2:W+2) | product_high(W+1:2) | product_low(1:0)]
                                      // 其中product_low的最低位(位0)是为Booth算法附加的0

    // 使用参数化的位宽定义来提取高低32位
    wire [`REG_DATA_WIDTH-1:0] mult_tmp_high;
    wire [`REG_DATA_WIDTH-1:0] mult_tmp_low;

    assign mult_tmp_high = p_reg[HIGH_PART_MSB:HIGH_PART_LSB];
    assign mult_tmp_low  = p_reg[LOW_PART_MSB:LOW_PART_LSB];

    // 含无符号数乘法的结果修复
    // 如果被乘数最高位是 1，则误多算了 -2^32*multiplier，所以加回 multiplier
    wire [`REG_DATA_WIDTH-1:0] add_mul;
    assign add_mul = multiplicand_r[`REG_DATA_WIDTH-1] ? multiplier_r : {`REG_DATA_WIDTH{1'b0}};

    // 如果乘数最高位是 1，则误多算了 -2^32*multiplicand，所以加回 multiplicand
    wire [`REG_DATA_WIDTH-1:0] add_mcand;
    assign add_mcand = multiplier_r[`REG_DATA_WIDTH-1] ? multiplicand_r : {`REG_DATA_WIDTH{1'b0}};

    // 状态转换逻辑
    always @(*) begin
        next_state = 2'bxx;
        case (current_state)
            IDLE:    if (start_i) next_state = CALC;
                     else next_state = IDLE;
            CALC:    if (count == NUM_ITERS-1) next_state = OUTPUT;  // 使用参数化的迭代次数
                     else next_state = CALC;
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
            count                               <= {COUNTER_WIDTH{1'b0}};
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
                        // p_reg格式: [sign_extension | product_high | product_low]
                        // 其中product_low的LSB(位0)是为Radix-4 Booth算法附加的0
                        add1    <= {{2{multiplicand_i[`REG_DATA_WIDTH-1]}}, multiplicand_i, {`REG_DATA_WIDTH+1{1'b0}}};
                        sub1    <= {-{{2{multiplicand_i[`REG_DATA_WIDTH-1]}}, multiplicand_i}, {`REG_DATA_WIDTH+1{1'b0}}};
                        add_x2  <= {{multiplicand_i[`REG_DATA_WIDTH-1]}, multiplicand_i, 1'b0, {`REG_DATA_WIDTH+1{1'b0}}};
                        sub_x2  <= {-{multiplicand_i[`REG_DATA_WIDTH-1], multiplicand_i, 1'b0}, {`REG_DATA_WIDTH+1{1'b0}}};
                        
                        // 初始化p_reg，最低位附加0用于Booth编码
                        p_reg   <= {{`REG_DATA_WIDTH+1{1'b0}}, multiplier_i, 1'b0};

                        count <= {COUNTER_WIDTH{1'b0}};
                        busy_o <= `True;
                        ready_o <= 1'b0;
                    end else begin
                        busy_o  <= `False;
                        ready_o <= 1'b0;
                    end
                end

                CALC: begin
                    // 使用临时变量而不是寄存器，避免混合赋值问题
                    reg [EXTENDED_WIDTH-1:0] temp_result;
                    
                    // Radix-4 Booth算法核心计算 - 根据乘数的低3位决定操作
                    // 检查位范围[2:0]包含: 上一次处理的LSB(位0)和当前处理的2位(位2:1)
                    case (p_reg[2:0])
                        3'b000, 3'b111: temp_result = p_reg;         // 不操作 (0,-0)
                        3'b001, 3'b010: temp_result = p_reg + add1;  // +1倍被乘数 
                        3'b101, 3'b110: temp_result = p_reg + sub1;  // -1倍被乘数
                        3'b011:         temp_result = p_reg + add_x2; // +2倍被乘数
                        3'b100:         temp_result = p_reg + sub_x2; // -2倍被乘数
                        default:        temp_result = p_reg;
                    endcase
                    
                    // 算术右移2位（Radix-4，每次处理2位）
                    // 右移后符号位需要扩展，保持结果的符号一致性
                    p_reg <= {temp_result[RESULT_MSB],
                             temp_result[RESULT_MSB],
                             temp_result[RESULT_MSB:2]};
                    count <= count + 1'b1;
                end

                OUTPUT: begin
                    // 根据指令类型选择输出结果
                    case (op_r)
                        `INST_MUL: result_o <= mult_tmp_low;  // 取低32位
                        `INST_MULH: begin
                            result_o <= mult_tmp_high;
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
