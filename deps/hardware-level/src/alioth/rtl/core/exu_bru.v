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

// 分支单元 - 处理跳转和分支指令
module exu_bru(
    input wire rst,
    
    // 指令和操作数输入
    input wire[`INST_DATA_WIDTH-1:0] inst_i,
    input wire[`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op1_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op2_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op1_jump_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op2_jump_i,
    
    // 中断信号
    input wire int_assert_i,
    input wire[`INST_ADDR_WIDTH-1:0] int_addr_i,
    
    // 跳转输出
    output reg jump_flag_o,
    output reg[`INST_ADDR_WIDTH-1:0] jump_addr_o
);

    // 内部信号
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire op1_eq_op2;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire[31:0] op1_jump_add_op2_jump_res;
    
    // 从指令中提取操作码和功能码
    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    
    // 比较结果
    assign op1_eq_op2 = (op1_i == op2_i);
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    
    // 计算跳转地址
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;
    
    // 分支单元逻辑
    always @(*) begin
        // 默认值
        jump_flag_o = `JumpDisable;
        jump_addr_o = `ZeroWord;
        
        // 中断处理
        if (int_assert_i == `INT_ASSERT) begin
            jump_flag_o = `JumpEnable;
            jump_addr_o = int_addr_i;
        end else begin
            case (opcode)
                `INST_TYPE_B: begin
                    case (funct3)
                        `INST_BEQ: begin
                            jump_flag_o = op1_eq_op2 & `JumpEnable;
                            jump_addr_o = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                        end
                        `INST_BNE: begin
                            jump_flag_o = (~op1_eq_op2) & `JumpEnable;
                            jump_addr_o = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                        end
                        `INST_BLT: begin
                            jump_flag_o = (~op1_ge_op2_signed) & `JumpEnable;
                            jump_addr_o = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                        end
                        `INST_BGE: begin
                            jump_flag_o = (op1_ge_op2_signed) & `JumpEnable;
                            jump_addr_o = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                        end
                        `INST_BLTU: begin
                            jump_flag_o = (~op1_ge_op2_unsigned) & `JumpEnable;
                            jump_addr_o = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                        end
                        `INST_BGEU: begin
                            jump_flag_o = (op1_ge_op2_unsigned) & `JumpEnable;
                            jump_addr_o = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                        end
                        default: begin
                            jump_flag_o = `JumpDisable;
                            jump_addr_o = `ZeroWord;
                        end
                    endcase
                end
                
                `INST_JAL, `INST_JALR: begin
                    jump_flag_o = `JumpEnable;
                    jump_addr_o = op1_jump_add_op2_jump_res;
                end
                
                `INST_FENCE: begin
                    jump_flag_o = `JumpEnable;
                    jump_addr_o = op1_jump_add_op2_jump_res;
                end
                
                default: begin
                    jump_flag_o = `JumpDisable;
                    jump_addr_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule
