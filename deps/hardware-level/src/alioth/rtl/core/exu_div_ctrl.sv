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

`include "defines.svh"

// 除法控制单元 - 处理除法指令的控制和结果写回
module exu_div_ctrl (
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

    // 中断信号
    input wire int_assert_i,

    // 除法控制输出
    output reg                       div_start_o,
    output reg [`REG_DATA_WIDTH-1:0] div_dividend_o,
    output reg [`REG_DATA_WIDTH-1:0] div_divisor_o,
    output reg [                2:0] div_op_o,
    output reg [`REG_ADDR_WIDTH-1:0] div_reg_waddr_o,

    // 控制输出
    output reg                        div_hold_flag_o,
    output reg                        div_jump_flag_o,
    output reg [`INST_ADDR_WIDTH-1:0] div_jump_addr_o,

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // 内部信号
    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;
    wire [31:0] op1_jump_add_op2_jump_res;

    // 从指令中提取操作码和功能码
    assign opcode                    = inst_i[6:0];
    assign funct3                    = inst_i[14:12];
    assign funct7                    = inst_i[31:25];

    // 计算跳转地址
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    // 除法控制逻辑
    always @(*) begin
        // 默认值
        div_dividend_o  = reg1_rdata_i;
        div_divisor_o   = reg2_rdata_i;
        div_op_o        = funct3;
        div_reg_waddr_o = reg_waddr_i;

        div_start_o     = `DivStop;
        div_hold_flag_o = `HoldDisable;
        div_jump_flag_o = `JumpDisable;
        div_jump_addr_o = `ZeroWord;

        reg_wdata_o     = `ZeroWord;
        reg_we_o        = `WriteDisable;
        reg_waddr_o     = `ZeroWord;

        // 响应中断时不进行除法操作
        if (int_assert_i == `INT_ASSERT) begin
            div_start_o = `DivStop;
        end else if ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001)) begin
            case (funct3)
                `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                    div_start_o     = `DivStart;
                    div_jump_flag_o = `JumpEnable;
                    div_hold_flag_o = `HoldEnable;
                    div_jump_addr_o = op1_jump_add_op2_jump_res;
                    reg_we_o        = `WriteDisable;
                end
                default: begin
                    div_start_o     = `DivStop;
                    div_jump_flag_o = `JumpDisable;
                    div_hold_flag_o = `HoldDisable;
                    div_jump_addr_o = `ZeroWord;
                end
            endcase
        end else begin
            div_jump_flag_o = `JumpDisable;
            div_jump_addr_o = `ZeroWord;

            if (div_busy_i == `True) begin
                div_start_o     = `DivStart;
                div_hold_flag_o = `HoldEnable;
                reg_we_o        = `WriteDisable;
            end else begin
                div_start_o     = `DivStop;
                div_hold_flag_o = `HoldDisable;

                if (div_ready_i == `DivResultReady) begin
                    reg_wdata_o = div_result_i;
                    reg_waddr_o = div_reg_waddr_i;
                    reg_we_o    = `WriteEnable;
                end else begin
                    reg_we_o = `WriteDisable;
                end
            end
        end
    end

endmodule
