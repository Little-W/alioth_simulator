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

// 写回单元 - 负责寄存器写回逻辑和延迟
module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ALU数据
    input wire [`REG_DATA_WIDTH-1:0] alu_reg_wdata_i,
    input wire                       alu_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] alu_reg_waddr_i,

    // 来自EXU的MULDIV数据
    input wire [`REG_DATA_WIDTH-1:0] muldiv_reg_wdata_i,
    input wire                       muldiv_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] muldiv_reg_waddr_i,

    // 来自EXU的CSR数据
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire                       csr_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,

    // 来自EXU的AGU/LSU数据
    input wire [`REG_DATA_WIDTH-1:0] agu_reg_wdata_i,
    input wire                       agu_reg_we_i,
    input wire [`REG_ADDR_WIDTH-1:0] agu_reg_waddr_i,

    // 中断信号
    input wire int_assert_i,

    // 寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // 延迟信号声明
    wire [`REG_DATA_WIDTH-1:0] alu_result_delay;
    wire                       alu_reg_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] alu_reg_waddr_delay;

    wire [`REG_DATA_WIDTH-1:0] muldiv_wdata_delay;
    wire                       muldiv_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] muldiv_waddr_delay;

    wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_delay;
    wire                       csr_reg_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_delay;

    // 使用D触发器延迟ALU结果一个周期
    gnrl_dff #(
        .DW(`REG_DATA_WIDTH)
    ) u_alu_result_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (alu_reg_wdata_i),
        .qout (alu_result_delay)
    );

    gnrl_dff #(
        .DW(1)
    ) u_alu_we_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (alu_reg_we_i),
        .qout (alu_reg_we_delay)
    );

    gnrl_dff #(
        .DW(`REG_ADDR_WIDTH)
    ) u_alu_waddr_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (alu_reg_waddr_i),
        .qout (alu_reg_waddr_delay)
    );

    // 使用D触发器延迟MULDIV结果一个周期
    gnrl_dff #(
        .DW(`REG_DATA_WIDTH)
    ) u_muldiv_data_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (muldiv_reg_wdata_i),
        .qout (muldiv_wdata_delay)
    );

    gnrl_dff #(
        .DW(1)
    ) u_muldiv_we_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (muldiv_reg_we_i),
        .qout (muldiv_we_delay)
    );

    gnrl_dff #(
        .DW(`REG_ADDR_WIDTH)
    ) u_muldiv_waddr_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (muldiv_reg_waddr_i),
        .qout (muldiv_waddr_delay)
    );

    // 使用D触发器延迟CSR结果一个周期
    gnrl_dff #(
        .DW(`REG_DATA_WIDTH)
    ) u_csr_data_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (csr_reg_wdata_i),
        .qout (csr_reg_wdata_delay)
    );

    gnrl_dff #(
        .DW(1)
    ) u_csr_we_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (csr_reg_we_i),
        .qout (csr_reg_we_delay)
    );

    gnrl_dff #(
        .DW(`REG_ADDR_WIDTH)
    ) u_csr_waddr_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (csr_reg_waddr_i),
        .qout (csr_reg_waddr_delay)
    );

    // 选择优先级：AGU(LSU) > MULDIV > ALU > CSR
    // 注意AGU/LSU数据已经在LSU内部延迟，所以直接使用
    wire [`REG_DATA_WIDTH-1:0] reg_wdata_r;
    wire                       reg_we_r;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_r;

    // 使用assign语句实现优先级选择逻辑，避免X不定态传播
    assign reg_wdata_r = (int_assert_i == `INT_ASSERT) ? `ZeroWord :
                         agu_reg_we_i ? agu_reg_wdata_i :
                         muldiv_we_delay ? muldiv_wdata_delay :
                         alu_reg_we_delay ? alu_result_delay :
                         csr_reg_we_delay ? csr_reg_wdata_delay :
                         `ZeroWord;

    assign reg_we_r = (int_assert_i == `INT_ASSERT) ? `WriteDisable :
                      agu_reg_we_i ? agu_reg_we_i :
                      muldiv_we_delay ? muldiv_we_delay :
                      alu_reg_we_delay ? alu_reg_we_delay :
                      csr_reg_we_delay ? csr_reg_we_delay :
                      `WriteDisable;

    assign reg_waddr_r = (int_assert_i == `INT_ASSERT) ? `ZeroReg :
                         agu_reg_we_i ? agu_reg_waddr_i :
                         muldiv_we_delay ? muldiv_waddr_delay :
                         alu_reg_we_delay ? alu_reg_waddr_delay :
                         csr_reg_we_delay ? csr_reg_waddr_delay :
                         `ZeroReg;

    // 输出赋值
    assign reg_wdata_o = reg_wdata_r;
    assign reg_we_o = reg_we_r;
    assign reg_waddr_o = reg_waddr_r;

endmodule
