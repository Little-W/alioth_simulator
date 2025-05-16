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

// CSR处理单元 - 处理CSR寄存器操作
module exu_csr_unit(
    input wire rst,
    
    // 指令和操作数输入
    input wire[`INST_DATA_WIDTH-1:0] inst_i,
    input wire[`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire[`REG_DATA_WIDTH-1:0] csr_rdata_i,
    
    // 中断信号
    input wire int_assert_i,
    
    // CSR写数据输出
    output reg[`REG_DATA_WIDTH-1:0] csr_wdata_o,
    
    // 寄存器写回数据
    output reg[`REG_DATA_WIDTH-1:0] reg_wdata_o
);

    // 内部信号
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[4:0] uimm;
    
    // 从指令中提取操作码和功能码
    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign uimm = inst_i[19:15];
    
    // CSR处理单元逻辑
    always @(*) begin
        // 默认值
        csr_wdata_o = `ZeroWord;
        reg_wdata_o = `ZeroWord;
        
        // 响应中断时不进行CSR操作
        if (int_assert_i == `INT_ASSERT) begin
            // 不执行任何操作
        end else if (opcode == `INST_CSR) begin
            // CSR操作
            case (funct3)
                `INST_CSRRW: begin
                    csr_wdata_o = reg1_rdata_i;
                    reg_wdata_o = csr_rdata_i;
                end
                `INST_CSRRS: begin
                    csr_wdata_o = reg1_rdata_i | csr_rdata_i;
                    reg_wdata_o = csr_rdata_i;
                end
                `INST_CSRRC: begin
                    csr_wdata_o = csr_rdata_i & (~reg1_rdata_i);
                    reg_wdata_o = csr_rdata_i;
                end
                `INST_CSRRWI: begin
                    csr_wdata_o = {27'h0, uimm};
                    reg_wdata_o = csr_rdata_i;
                end
                `INST_CSRRSI: begin
                    csr_wdata_o = {27'h0, uimm} | csr_rdata_i;
                    reg_wdata_o = csr_rdata_i;
                end
                `INST_CSRRCI: begin
                    csr_wdata_o = (~{27'h0, uimm}) & csr_rdata_i;
                    reg_wdata_o = csr_rdata_i;
                end
                default: begin
                    csr_wdata_o = `ZeroWord;
                    reg_wdata_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule
