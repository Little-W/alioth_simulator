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

// 乘除法控制单元 - 处理乘除法指令的控制和结果写回
module exu_muldiv_ctrl (
    input wire rst,

    // 指令和操作数输入
    input wire [`INST_DATA_WIDTH-1:0] inst_i,
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] op1_jump_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] op2_jump_i,

    // 除法器接口
    input wire                       div_ready_i,
    input wire [`REG_DATA_WIDTH-1:0] div_result_i,
    input wire                       div_busy_i,
    input wire [`REG_ADDR_WIDTH-1:0] div_reg_waddr_i,

    // 乘法器接口
    input wire                       mul_ready_i,
    input wire [`REG_DATA_WIDTH-1:0] mul_result_i,
    input wire                       mul_busy_i,
    input wire [`REG_ADDR_WIDTH-1:0] mul_reg_waddr_i,

    // 中断信号
    input wire int_assert_i,

    // 除法控制输出
    output reg                       div_start_o,
    output reg [`REG_DATA_WIDTH-1:0] div_dividend_o,
    output reg [`REG_DATA_WIDTH-1:0] div_divisor_o,
    output reg [                2:0] div_op_o,
    output reg [`REG_ADDR_WIDTH-1:0] div_reg_waddr_o,

    // 乘法控制输出
    output reg                       mul_start_o,
    output reg [`REG_DATA_WIDTH-1:0] mul_multiplicand_o,
    output reg [`REG_DATA_WIDTH-1:0] mul_multiplier_o,
    output reg [                2:0] mul_op_o,
    output reg [`REG_ADDR_WIDTH-1:0] mul_reg_waddr_o,

    // 控制输出
    output reg                        muldiv_hold_flag_o,
    output reg                        muldiv_jump_flag_o,
    output reg [`INST_ADDR_WIDTH-1:0] muldiv_jump_addr_o,

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // 内部信号
    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;
    wire [ 4:0] rd;
    wire [31:0] op1_jump_add_op2_jump_res;

    // 从指令中提取操作码和功能码
    assign opcode                    = inst_i[6:0];
    assign funct3                    = inst_i[14:12];
    assign funct7                    = inst_i[31:25];
    assign rd                        = inst_i[11:7];

    // 计算跳转地址
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    // 乘除法控制逻辑
    always @(*) begin
        // 默认值
        div_dividend_o     = reg1_rdata_i;
        div_divisor_o      = reg2_rdata_i;
        div_op_o           = funct3;
        div_reg_waddr_o    = reg_waddr_i;

        mul_multiplicand_o = reg1_rdata_i;
        mul_multiplier_o   = reg2_rdata_i;
        mul_op_o           = funct3;
        mul_reg_waddr_o    = reg_waddr_i;

        div_start_o        = `DivStop;
        mul_start_o        = 1'b0;

        muldiv_hold_flag_o = `HoldDisable;
        muldiv_jump_flag_o = `JumpDisable;
        muldiv_jump_addr_o = `ZeroWord;

        reg_wdata_o        = `ZeroWord;
        reg_we_o           = `WriteDisable;
        reg_waddr_o        = `ZeroWord;

        // 响应中断时不进行乘除法操作
        if (int_assert_i == `INT_ASSERT) begin
            div_start_o = `DivStop;
            mul_start_o = 1'b0;
        end else begin
            case (opcode)
                `INST_TYPE_R_M: begin
                    if (funct7 == 7'b0000001) begin
                        muldiv_jump_addr_o = op1_jump_add_op2_jump_res;

                        // 根据funct3区分乘法和除法指令
                        case (funct3)
                            // 乘法指令
                            `INST_MUL, `INST_MULH, `INST_MULHSU, `INST_MULHU: begin
                                // 已经开始乘法运算
                                if (mul_busy_i == 1'b1) begin
                                    mul_start_o        = 1'b1;  // 保持乘法开始信号有效
                                    muldiv_hold_flag_o = `HoldEnable;
                                    muldiv_jump_flag_o = `JumpDisable;
                                    reg_we_o           = `WriteDisable;
                                    // 乘法运算结果已准备好
                                end else if (mul_ready_i == 1'b1) begin
                                    mul_start_o        = 1'b0;
                                    muldiv_hold_flag_o = `HoldDisable;
                                    muldiv_jump_flag_o = `JumpDisable;
                                    reg_wdata_o        = mul_result_i;
                                    reg_waddr_o        = mul_reg_waddr_i;
                                    reg_we_o           = `WriteEnable;
                                    // 开始一个新的乘法运算
                                end else begin
                                    mul_start_o        = 1'b1;
                                    muldiv_jump_flag_o = `JumpEnable;
                                    muldiv_hold_flag_o = `HoldEnable;
                                    reg_we_o           = `WriteDisable;
                                end
                            end

                            // 除法指令
                            `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                                // 已经开始除法运算
                                if (div_busy_i == `True) begin
                                    div_start_o        = `DivStart;
                                    muldiv_hold_flag_o = `HoldEnable;
                                    muldiv_jump_flag_o = `JumpDisable;
                                    reg_we_o           = `WriteDisable;
                                    // 除法运算结果已准备好
                                end else if (div_ready_i == `DivResultReady) begin
                                    div_start_o        = `DivStop;
                                    muldiv_hold_flag_o = `HoldDisable;
                                    muldiv_jump_flag_o = `JumpDisable;
                                    reg_wdata_o        = div_result_i;
                                    reg_waddr_o        = div_reg_waddr_i;
                                    reg_we_o           = `WriteEnable;
                                    // 开始一个新的除法运算
                                end else begin
                                    div_start_o        = `DivStart;
                                    muldiv_jump_flag_o = `JumpEnable;
                                    muldiv_hold_flag_o = `HoldEnable;
                                    reg_we_o           = `WriteDisable;
                                end
                            end

                            default: begin
                                div_start_o        = `DivStop;
                                mul_start_o        = 1'b0;
                                muldiv_jump_flag_o = `JumpDisable;
                                muldiv_hold_flag_o = `HoldDisable;
                            end
                        endcase
                    end else begin
                        div_start_o        = `DivStop;
                        mul_start_o        = 1'b0;
                        muldiv_jump_flag_o = `JumpDisable;
                        muldiv_hold_flag_o = `HoldDisable;
                    end
                end

                default: begin
                    muldiv_jump_flag_o = `JumpDisable;
                    muldiv_jump_addr_o = `ZeroWord;

                    // 乘除法器在忙，继续保持hold状态
                    if (div_busy_i == `True) begin
                        div_start_o        = `DivStart;
                        muldiv_hold_flag_o = `HoldEnable;
                        reg_we_o           = `WriteDisable;
                    end else if (mul_busy_i == 1'b1) begin
                        mul_start_o        = 1'b1;  // 保持乘法开始信号有效
                        muldiv_hold_flag_o = `HoldEnable;
                        reg_we_o           = `WriteDisable;
                        // 处理运算结果
                    end else begin
                        div_start_o        = `DivStop;
                        mul_start_o        = 1'b0;
                        muldiv_hold_flag_o = `HoldDisable;

                        if (div_ready_i == `DivResultReady) begin
                            reg_wdata_o = div_result_i;
                            reg_waddr_o = div_reg_waddr_i;
                            reg_we_o    = `WriteEnable;
                        end else if (mul_ready_i == 1'b1) begin
                            reg_wdata_o = mul_result_i;
                            reg_waddr_o = mul_reg_waddr_i;
                            reg_we_o    = `WriteEnable;
                        end else begin
                            reg_we_o = `WriteDisable;
                        end
                    end
                end
            endcase
        end
    end

endmodule
