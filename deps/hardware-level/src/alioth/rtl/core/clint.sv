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

// core local interruptor module
module clint (

    input wire clk,
    input wire rst_n,

    // from id
    input wire [`INST_DATA_WIDTH-1:0] inst_i,
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        div_started_i,

    // from ctrl
    input wire [`Hold_Flag_Bus] hold_flag_i,

    // from csr_reg
    input wire [`REG_DATA_WIDTH-1:0] data_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_mtvec,
    input wire [`REG_DATA_WIDTH-1:0] csr_mepc,
    input wire [`REG_DATA_WIDTH-1:0] csr_mstatus,

    input wire global_int_en_i,  // 全局中断使能标志

    // to ctrl
    output wire hold_flag_o,

    // to csr_reg
    output reg                       we_o,
    output reg [`BUS_ADDR_WIDTH-1:0] waddr_o,
    output reg [`BUS_ADDR_WIDTH-1:0] raddr_o,
    output reg [`REG_DATA_WIDTH-1:0] data_o,

    // to ex
    output reg [`INST_ADDR_WIDTH-1:0] int_addr_o,   //ecall和ebreak的返回地址
    output reg                        int_assert_o  //ecall和ebreak的中断信号
);


    // interrupt state machine
    localparam S_INT_IDLE = 4'b0001;  // 空闲状态
    localparam S_INT_SYNC_ASSERT = 4'b0010;  // 同步中断断言状态
    localparam S_INT_ASYNC_ASSERT = 4'b0100;  // 异步中断断言状态 
    localparam S_INT_MRET = 4'b1000;  // 中断返回状态

    // CSR write state machine
    localparam S_CSR_IDLE = 5'b00001;  // CSR写入空闲状态
    localparam S_CSR_MSTATUS = 5'b00010;  // 写入mstatus寄存器状态
    localparam S_CSR_MEPC = 5'b00100;  // 写入mepc寄存器状态
    localparam S_CSR_MSTATUS_MRET = 5'b01000;  // 中断返回时写入mstatus寄存器状态
    localparam S_CSR_MCAUSE = 5'b10000;  // 写入mcause寄存器状态

    // 状态机和相关信号声明
    wire [                 3:0] int_state;  // 中断状态机当前状态
    wire [                 4:0] csr_state;  // CSR写状态机当前状态
    wire [`INST_ADDR_WIDTH-1:0] inst_addr;  // 保存的指令地址
    wire [                31:0] cause;  // 中断原因代码

    // 下一个状态信号声明
    wire [                 4:0] next_csr_state;  // CSR写状态机下一状态
    wire [`INST_ADDR_WIDTH-1:0] next_inst_addr;  // 下一个保存的指令地址
    wire [                31:0] next_cause;  // 下一个中断原因代码

    // 暂停信号产生逻辑 - 当中断状态机或CSR写状态机不在空闲状态时暂停流水线
    assign hold_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE)) ? `HoldEnable : `HoldDisable;

    // 中断处理逻辑 - 使用assign替代always @(*)，避免优先级选择电路的问题
    assign int_state = (rst_n == `RstEnable) ? S_INT_IDLE :
                      ((inst_i == `INST_ECALL || inst_i == `INST_EBREAK) && div_started_i == `DivStop) ? S_INT_SYNC_ASSERT :
                      (inst_i == `INST_MRET) ? S_INT_MRET :
                      S_INT_IDLE;

    // CSR写状态机的组合逻辑部分 - 计算下一个CSR写状态
    assign next_csr_state = 
        (rst_n == `RstEnable) ? S_CSR_IDLE :
        (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) ? S_CSR_MEPC :       // 发生同步中断，先保存PC
        (csr_state == S_CSR_IDLE && int_state == S_INT_MRET) ? S_CSR_MSTATUS_MRET :  // 中断返回，恢复mstatus
        (csr_state == S_CSR_MEPC) ? S_CSR_MSTATUS :  // 保存PC后，修改mstatus
        (csr_state == S_CSR_MSTATUS) ? S_CSR_MCAUSE :  // 修改mstatus后，写入中断原因
        (csr_state == S_CSR_MCAUSE || csr_state == S_CSR_MSTATUS_MRET) ? S_CSR_IDLE :    // 完成中断处理，返回空闲状态
        S_CSR_IDLE;

    // 下一个中断原因cause值的逻辑
    assign next_cause = 
        (rst_n == `RstEnable) ? `ZeroWord :
        (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) ? 
            (inst_i == `INST_ECALL) ? 32'd11 :    // 环境调用异常
        (inst_i == `INST_EBREAK) ? 32'd3 :  // 断点异常
        32'd10 :  // 其他异常默认值
        cause;

    // 下一个保存的指令地址inst_addr值的逻辑
    assign next_inst_addr = 
        (rst_n == `RstEnable) ? `ZeroWord :
        (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) ? 
            (jump_flag_i == `JumpEnable) ? jump_addr_i - 4'h4 : inst_addr_i :  // 如果跳转发生，保存跳转目标地址-4
        inst_addr;

    gnrl_dff #(
        .DW(5)
    ) csr_state_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_csr_state),
        .qout (csr_state)
    );

    gnrl_dff #(
        .DW(32)
    ) cause_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_cause),
        .qout (cause)
    );

    gnrl_dff #(
        .DW(`INST_ADDR_WIDTH)
    ) inst_addr_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_inst_addr),
        .qout (inst_addr)
    );

    // 写入CSR寄存器的组合逻辑 - 计算下一个写使能信号
    wire                       next_we_o;  // 下一个写使能信号
    wire [`BUS_ADDR_WIDTH-1:0] next_waddr_o;  // 下一个写地址
    wire [`REG_DATA_WIDTH-1:0] next_data_o;  // 下一个写数据

    // 计算写使能信号 - 当需要写入任何CSR寄存器时置为WriteEnable
    assign next_we_o = (rst_n == `RstEnable) ? `WriteDisable :
                      (csr_state == S_CSR_MEPC || csr_state == S_CSR_MCAUSE || 
                       csr_state == S_CSR_MSTATUS || csr_state == S_CSR_MSTATUS_MRET) ? `WriteEnable :
                      `WriteDisable;

    // 计算写地址 - 基于当前状态选择要写入的CSR寄存器地址
    assign next_waddr_o = (rst_n == `RstEnable) ? `ZeroWord :
                         (csr_state == S_CSR_MEPC) ? {20'h0, `CSR_MEPC} :            // 写入mepc寄存器
        (csr_state == S_CSR_MCAUSE) ? {20'h0, `CSR_MCAUSE} :  // 写入mcause寄存器
        (csr_state == S_CSR_MSTATUS || csr_state == S_CSR_MSTATUS_MRET) ? {20'h0, `CSR_MSTATUS} : // 写入mstatus寄存器
        `ZeroWord;

    // 计算写数据 - 基于当前状态确定要写入CSR寄存器的数据
    assign next_data_o = (rst_n == `RstEnable) ? `ZeroWord :
                        (csr_state == S_CSR_MEPC) ? inst_addr :                     // 保存当前指令地址到mepc
        (csr_state == S_CSR_MCAUSE) ? cause :  // 写入中断原因到mcause
        (csr_state == S_CSR_MSTATUS) ? {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]} :      // 中断发生时修改mstatus，关闭全局中断
        (csr_state == S_CSR_MSTATUS_MRET) ? {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]} : // 中断返回时恢复mstatus
        `ZeroWord;

    // 发送中断信号到ex模块的组合逻辑
    wire                        next_int_assert_o;  // 下一个中断断言信号
    wire [`INST_ADDR_WIDTH-1:0] next_int_addr_o;  // 下一个中断地址

    // 计算中断断言信号 - 在完成CSR写入或中断返回时断言
    assign next_int_assert_o = (rst_n == `RstEnable) ? `INT_DEASSERT :
                              (csr_state == S_CSR_MCAUSE || csr_state == S_CSR_MSTATUS_MRET) ? `INT_ASSERT :
                              `INT_DEASSERT;

    // 计算中断地址 - 中断处理或中断返回的目标地址
    assign next_int_addr_o = (rst_n == `RstEnable) ? `ZeroWord :
                            (csr_state == S_CSR_MCAUSE) ? csr_mtvec :      // 中断发生时跳转到mtvec
        (csr_state == S_CSR_MSTATUS_MRET) ? csr_mepc :  // 中断返回时跳转到mepc
        `ZeroWord;

    gnrl_dff #(
        .DW(1)
    ) we_o_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_we_o),
        .qout (we_o)
    );

    gnrl_dff #(
        .DW(`BUS_ADDR_WIDTH)
    ) waddr_o_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_waddr_o),
        .qout (waddr_o)
    );

    gnrl_dff #(
        .DW(`REG_DATA_WIDTH)
    ) data_o_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_data_o),
        .qout (data_o)
    );

    gnrl_dff #(
        .DW(1)
    ) int_assert_o_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_int_assert_o),
        .qout (int_assert_o)
    );

    gnrl_dff #(
        .DW(`INST_ADDR_WIDTH)
    ) int_addr_o_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (next_int_addr_o),
        .qout (int_addr_o)
    );

    gnrl_dff #(
        .DW(`BUS_ADDR_WIDTH)
    ) raddr_o_dff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (`ZeroWord),
        .qout (raddr_o)
    );

endmodule
