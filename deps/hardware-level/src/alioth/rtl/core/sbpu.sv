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

 `include "defines.sv"

 //静�?�分支预测模�?
 module sbpu(
    input wire clk,
    input wire rst_n,

    input wire [`INST_DATA_WIDTH-1:0] inst_i,        // 指令内容
    input wire inst_valid_i,                          // 指令有效信号
    input wire [`INST_ADDR_WIDTH-1:0] pc_i,          // PC指针

    output wire branch_taken_o,                        // 预测是否为分�?
    output wire [`INST_ADDR_WIDTH-1:0] branch_addr_o,   //  预测的分支地�?

    output wire old_pc_o // 旧的PC地址

 );
    wire[6:0] opcode = inst_i[6:0];

    wire opcode_1100011 = (opcode == 7'b1100011);
    wire opcode_1101111 = (opcode == 7'b1101111);
    wire opcode_1100111 = (opcode == 7'b1100111);

    wire inst_type_branch = opcode_1100011;
    wire inst_jal = opcode_1101111; 
    wire inst_jalr = opcode_1100111;

    wire[31:0] inst_b_type_imm = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire[31:0] inst_j_type_imm = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};

    wire branch_taken = (inst_type_branch & inst_b_type_imm[31]) | inst_jal;

    reg[31:0] branch_addr;

    always @ (*) begin
        branch_addr = pc_i + inst_b_type_imm;

        case (1'b1)
            inst_type_branch: branch_addr = pc_i + inst_b_type_imm;
            inst_jal:         branch_addr = pc_i + inst_j_type_imm;

            default: ;
        endcase
    end
    assign branch_taken_o = inst_valid_i ? branch_taken : 1'b0;
    assign branch_addr_o = branch_addr;

    assign old_pc_o = pc_i ; // 旧的PC地址

 endmodule