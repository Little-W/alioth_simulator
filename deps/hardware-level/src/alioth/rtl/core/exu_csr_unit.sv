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

// CSR处理单元 - 处理CSR寄存器操作


module exu_csr_unit (
    input wire rst,

    // 指令和操作数输入
    input wire                       req_csr_i,
    input wire [               31:0] csr_op1_i,
    input wire [               31:0] csr_addr_i,
    input wire                       csr_csrrw_i,
    input wire                       csr_csrrs_i,
    input wire                       csr_csrrc_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,

    // 中断信号
    input wire int_assert_i,

    // CSR写数据输出
    output reg [`REG_DATA_WIDTH-1:0] csr_wdata_o,

    // 寄存器写回数据
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o
);  // CSR处理单元逻辑
    always @(*) begin
        // 默认值
        csr_wdata_o = `ZeroWord;
        reg_wdata_o = `ZeroWord;

        // 响应中断时不进行CSR操作
        if (int_assert_i == `INT_ASSERT) begin
            // 不执行任何操作
        end else if (req_csr_i) begin
            reg_wdata_o = csr_rdata_i;  // 所有CSR指令都将CSR的值读出来放入目标寄存器

            // 基于dispatch传来的信号确定CSR写入值
            if (csr_csrrw_i) begin
                // CSRRW: 将rs1的值写入CSR
                csr_wdata_o = csr_op1_i;
            end else if (csr_csrrs_i) begin
                // CSRRS: 将rs1的值与CSR的值按位或，结果写入CSR
                csr_wdata_o = csr_op1_i | csr_rdata_i;
            end else if (csr_csrrc_i) begin
                // CSRRC: 将CSR的值与rs1的值按位与非，结果写入CSR
                csr_wdata_o = csr_rdata_i & (~csr_op1_i);
            end
        end
    end

endmodule
