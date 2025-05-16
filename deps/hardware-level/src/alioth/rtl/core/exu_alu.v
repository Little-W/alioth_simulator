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

// 算术逻辑单元
module exu_alu(
    input wire rst,
    
    // 指令和操作数输入
    input wire[`INST_DATA_WIDTH-1:0] inst_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op1_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op2_i,
    input wire[`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire[`REG_DATA_WIDTH-1:0] reg2_rdata_i,
    
    // 中断信号
    input wire int_assert_i,
    
    // 结果输出
    output reg[`REG_DATA_WIDTH-1:0] result_o,
    output reg reg_we_o,
    output reg[`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // 内部信号
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[31:0] op1_add_op2_res;
    wire[31:0] op1_sub_op2_res;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire[31:0] sr_shift;
    wire[31:0] sri_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] sri_shift_mask;
    
    reg[`REG_DATA_WIDTH-1:0] mul_op1;
    reg[`REG_DATA_WIDTH-1:0] mul_op2;
    wire[`DOUBLE_REG_WIDTH-1:0] mul_temp;
    wire[`DOUBLE_REG_WIDTH-1:0] mul_temp_invert;
    wire[31:0] reg1_data_invert;
    wire[31:0] reg2_data_invert;
    
    // 从指令中提取操作码和功能码
    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    
    // 基本运算结果
    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_sub_op2_res = op1_i - op2_i;
    
    // 比较结果
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);
    
    // 移位操作结果
    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];
    
    // 乘法操作
    assign reg1_data_invert = ~reg1_rdata_i + 1;
    assign reg2_data_invert = ~reg2_rdata_i + 1;
    assign mul_temp = mul_op1 * mul_op2;
    assign mul_temp_invert = ~mul_temp + 1;
    
    // 乘法操作数选择
    always @(*) begin
        if ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001)) begin
            case (funct3)
                `INST_MUL, `INST_MULHU: begin
                    mul_op1 = reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
                `INST_MULHSU: begin
                    mul_op1 = (reg1_rdata_i[31] == 1'b1) ? (reg1_data_invert) : reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
                `INST_MULH: begin
                    mul_op1 = (reg1_rdata_i[31] == 1'b1) ? (reg1_data_invert) : reg1_rdata_i;
                    mul_op2 = (reg2_rdata_i[31] == 1'b1) ? (reg2_data_invert) : reg2_rdata_i;
                end
                default: begin
                    mul_op1 = reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
            endcase
        end else begin
            mul_op1 = reg1_rdata_i;
            mul_op2 = reg2_rdata_i;
        end
    end
    
    // ALU逻辑
    always @(*) begin
        // 默认值
        result_o = `ZeroWord;
        reg_we_o = `WriteDisable;
        reg_waddr_o = 5'b0;
        
        // 响应中断时不进行操作
        if (int_assert_i == `INT_ASSERT) begin
            reg_we_o = `WriteDisable;
        end else begin
            case (opcode)
                `INST_TYPE_I: begin
                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    
                    case (funct3)
                        `INST_ADDI: result_o = op1_add_op2_res;
                        `INST_SLTI: result_o = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        `INST_SLTIU: result_o = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        `INST_XORI: result_o = op1_i ^ op2_i;
                        `INST_ORI: result_o = op1_i | op2_i;
                        `INST_ANDI: result_o = op1_i & op2_i;
                        `INST_SLLI: result_o = reg1_rdata_i << inst_i[24:20];
                        `INST_SRI: begin
                            if (inst_i[30] == 1'b1) begin
                                // 算术右移
                                result_o = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                            end else begin
                                // 逻辑右移
                                result_o = reg1_rdata_i >> inst_i[24:20];
                            end
                        end
                        default: result_o = `ZeroWord;
                    endcase
                end
                
                `INST_TYPE_R_M: begin
                    if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        
                        case (funct3)
                            `INST_ADD_SUB: begin
                                if (inst_i[30] == 1'b0) begin
                                    result_o = op1_add_op2_res;
                                end else begin
                                    result_o = op1_sub_op2_res;
                                end
                            end
                            `INST_SLL: result_o = op1_i << op2_i[4:0];
                            `INST_SLT: result_o = {32{(~op1_ge_op2_signed)}} & 32'h1;
                            `INST_SLTU: result_o = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                            `INST_XOR: result_o = op1_i ^ op2_i;
                            `INST_SR: begin
                                if (inst_i[30] == 1'b1) begin
                                    // 算术右移
                                    result_o = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                                end else begin
                                    // 逻辑右移
                                    result_o = reg1_rdata_i >> reg2_rdata_i[4:0];
                                end
                            end
                            `INST_OR: result_o = op1_i | op2_i;
                            `INST_AND: result_o = op1_i & op2_i;
                            default: result_o = `ZeroWord;
                        endcase
                    end else if (funct7 == 7'b0000001) begin
                        // 乘法指令
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        
                        case (funct3)
                            `INST_MUL: begin
                                result_o = mul_temp[31:0];
                            end
                            `INST_MULHU: begin
                                result_o = mul_temp[63:32];
                            end
                            `INST_MULH: begin
                                case ({reg1_rdata_i[31], reg2_rdata_i[31]})
                                    2'b00: result_o = mul_temp[63:32];
                                    2'b11: result_o = mul_temp[63:32];
                                    2'b10: result_o = mul_temp_invert[63:32];
                                    default: result_o = mul_temp_invert[63:32];
                                endcase
                            end
                            `INST_MULHSU: begin
                                if (reg1_rdata_i[31] == 1'b1) begin
                                    result_o = mul_temp_invert[63:32];
                                end else begin
                                    result_o = mul_temp[63:32];
                                end
                            end
                            default: result_o = `ZeroWord;
                        endcase
                    end else begin
                        reg_we_o = `WriteDisable;
                        result_o = `ZeroWord;
                    end
                end
                
                `INST_LUI, `INST_AUIPC: begin
                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    result_o = op1_add_op2_res;
                end
                
                `INST_JAL, `INST_JALR: begin
                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    result_o = op1_add_op2_res;
                end
                
                default: begin
                    reg_we_o = `WriteDisable;
                    result_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule
