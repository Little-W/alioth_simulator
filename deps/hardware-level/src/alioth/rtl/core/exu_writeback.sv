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

// 写回模块 - 统一处理不同指令类型的寄存器写回操作
module exu_writeback (
    input wire clk,
    input wire rst_n,
    
    // 来自AGU模块的load数据
    input wire [`REG_DATA_WIDTH-1:0] agu_reg_wdata_i,
    input wire                       agu_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] agu_reg_waddr_i,
    
    // 来自ALU模块的数据（经过D触发器延迟后）
    input wire [`REG_DATA_WIDTH-1:0] alu_reg_wdata_i,
    input wire                       alu_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] alu_reg_waddr_i,
    
    // 来自MULDIV模块的数据（经过D触发器延迟后）
    input wire [`REG_DATA_WIDTH-1:0] muldiv_reg_wdata_i,
    input wire                       muldiv_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] muldiv_reg_waddr_i,
    
    // 来自CSR模块的数据（经过D触发器延迟后）
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire                       csr_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,
    
    // 中断信号
    input wire                       int_assert_i,
    
    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o,
    
    // 写回完成信号 - 用于HDU
    output reg                       wb_done_o
);

    // 选择优先级：AGU > MULDIV > ALU > CSR
    always @(*) begin
        if (int_assert_i == `INT_ASSERT) begin
            // 中断情况下，禁止写回
            reg_wdata_o = `ZeroWord;
            reg_we_o = `WriteDisable;
            reg_waddr_o = `ZeroReg;
            wb_done_o = 1'b0;
        end else if (agu_reg_we_i) begin
            // AGU写回（load指令）
            reg_wdata_o = agu_reg_wdata_i;
            reg_we_o = agu_reg_we_i;
            reg_waddr_o = agu_reg_waddr_i;
            wb_done_o = 1'b1;
        end else if (muldiv_reg_we_i) begin
            // 乘除法结果写回
            reg_wdata_o = muldiv_reg_wdata_i;
            reg_we_o = muldiv_reg_we_i;
            reg_waddr_o = muldiv_reg_waddr_i;
            wb_done_o = 1'b1;
        end else if (alu_reg_we_i) begin
            // ALU结果写回
            reg_wdata_o = alu_reg_wdata_i;
            reg_we_o = alu_reg_we_i;
            reg_waddr_o = alu_reg_waddr_i;
            wb_done_o = 1'b1;
        end else if (csr_reg_we_i) begin
            // CSR结果写回
            reg_wdata_o = csr_reg_wdata_i;
            reg_we_o = csr_reg_we_i;
            reg_waddr_o = csr_reg_waddr_i;
            wb_done_o = 1'b1;
        end else begin
            // 默认情况
            reg_wdata_o = `ZeroWord;
            reg_we_o = `WriteDisable;
            reg_waddr_o = `ZeroReg;
            wb_done_o = 1'b0;
        end
    end

endmodule
