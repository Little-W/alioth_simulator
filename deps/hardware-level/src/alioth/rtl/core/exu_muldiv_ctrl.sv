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

// 乘除法控制单元 - 处理乘除法指令的控制和结果写回
module exu_muldiv_ctrl (
    input wire rst_n,

    // 指令和操作数输入
    input wire [`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`BUS_ADDR_WIDTH-1:0] op1_jump_i,
    input wire [`BUS_ADDR_WIDTH-1:0] op2_jump_i,

    // 从dispatch接收的译码输入
    input wire req_muldiv_i,
    input wire muldiv_op_mul_i,
    input wire muldiv_op_mulh_i,
    input wire muldiv_op_mulhsu_i,
    input wire muldiv_op_mulhu_i,
    input wire muldiv_op_div_i,
    input wire muldiv_op_divu_i,
    input wire muldiv_op_rem_i,
    input wire muldiv_op_remu_i,
    input wire muldiv_op_mul_all_i,  // 新增：总乘法操作标志
    input wire muldiv_op_div_all_i,  // 新增：总除法操作标志

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
    output reg [                3:0] div_op_o,
    output reg [`REG_ADDR_WIDTH-1:0] div_reg_waddr_o,

    // 乘法控制输出
    output reg                       mul_start_o,
    output reg [`REG_DATA_WIDTH-1:0] mul_multiplicand_o,
    output reg [`REG_DATA_WIDTH-1:0] mul_multiplier_o,
    output reg [                3:0] mul_op_o,
    output reg [`REG_ADDR_WIDTH-1:0] mul_reg_waddr_o,

    // 控制输出
    output reg muldiv_hold_flag_o,
    output reg muldiv_jump_flag_o,

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // 生成div_op_o的组合逻辑
    wire [3:0] div_op_sel;
    assign div_op_sel = {muldiv_op_remu_i, muldiv_op_rem_i, muldiv_op_divu_i, muldiv_op_div_i};

    // 生成mul_op_o的组合逻辑
    wire [3:0] mul_op_sel;
    assign mul_op_sel = {muldiv_op_mulhu_i, muldiv_op_mulhsu_i, muldiv_op_mulh_i, muldiv_op_mul_i};

    // 直接使用输入的总乘法和总除法信号
    wire is_mul_op = muldiv_op_mul_all_i;
    wire is_div_op = muldiv_op_div_all_i;

    // 默认值设置
    assign div_dividend_o = reg1_rdata_i;        // 被除数为第一个寄存器的值
    assign div_divisor_o = reg2_rdata_i;         // 除数为第二个寄存器的值
    assign div_op_o = div_op_sel;                // 除法操作类型
    assign div_reg_waddr_o = reg_waddr_i;        // 除法结果写回地址

    assign mul_multiplicand_o = reg1_rdata_i;    // 被乘数为第一个寄存器的值
    assign mul_multiplier_o = reg2_rdata_i;      // 乘数为第二个寄存器的值
    assign mul_op_o = mul_op_sel;                // 乘法操作类型
    assign mul_reg_waddr_o = reg_waddr_i;        // 乘法结果写回地址

    // 除法启动控制逻辑（优先级选择）
    // 响应中断时不进行除法操作，如果请求除法且是除法指令，根据除法器状态决定操作
    assign div_start_o = (int_assert_i == `INT_ASSERT) ? `DivStop : 
                         (req_muldiv_i && is_div_op) ? 
                            ((div_busy_i == `True) ? `DivStart :        // 已经开始除法运算
                             (div_ready_i == `DivResultReady) ? `DivStop : `DivStart) :  // 除法运算结果已准备好或开始新运算
                         (div_busy_i == `True) ? `DivStart : `DivStop;  // 除法器在忙，继续保持

    // 乘法启动控制逻辑（优先级选择）
    // 响应中断时不进行乘法操作，如果请求乘法且是乘法指令，根据乘法器状态决定操作
    assign mul_start_o = (int_assert_i == `INT_ASSERT) ? 1'b0 : 
                         (req_muldiv_i && is_mul_op) ? 
                            ((mul_busy_i == 1'b1) ? 1'b1 :              // 已经开始乘法运算
                             (mul_ready_i == 1'b1) ? 1'b0 : 1'b1) :     // 乘法运算结果已准备好或开始新运算
                         (mul_busy_i == 1'b1) ? 1'b1 : 1'b0;            // 乘法器在忙，继续保持

    // 流水线保持控制逻辑
    // 如果乘除法器在工作或需要启动新操作，则保持流水线
    assign muldiv_hold_flag_o = (req_muldiv_i && is_mul_op && (mul_busy_i == 1'b1 || mul_ready_i != 1'b1)) ? `HoldEnable :
                               (req_muldiv_i && is_div_op && (div_busy_i == `True || div_ready_i != `DivResultReady)) ? `HoldEnable :
                               (div_busy_i == `True || mul_busy_i == 1'b1) ? `HoldEnable : `HoldDisable;

    // 跳转控制逻辑
    // 开始新乘除法运算时需要进行跳转
    assign muldiv_jump_flag_o = (req_muldiv_i && is_mul_op && mul_busy_i != 1'b1 && mul_ready_i != 1'b1) ? `JumpEnable :
                               (req_muldiv_i && is_div_op && div_busy_i != `True && div_ready_i != `DivResultReady) ? `JumpEnable : 
                               `JumpDisable;

    // 结果写回数据选择逻辑
    // 根据乘除法指令类型和结果就绪状态选择写回数据
    assign reg_wdata_o = (req_muldiv_i && is_mul_op && mul_ready_i == 1'b1) ? mul_result_i :
                         (req_muldiv_i && is_div_op && div_ready_i == `DivResultReady) ? div_result_i :
                         (!req_muldiv_i && div_ready_i == `DivResultReady) ? div_result_i :
                         (!req_muldiv_i && mul_ready_i == 1'b1) ? mul_result_i : `ZeroWord;

    // 结果写回地址选择逻辑
    assign reg_waddr_o = (req_muldiv_i && is_mul_op && mul_ready_i == 1'b1) ? mul_reg_waddr_i :
                         (req_muldiv_i && is_div_op && div_ready_i == `DivResultReady) ? div_reg_waddr_i :
                         (!req_muldiv_i && div_ready_i == `DivResultReady) ? div_reg_waddr_i :
                         (!req_muldiv_i && mul_ready_i == 1'b1) ? mul_reg_waddr_i : `ZeroWord;

    // 结果写回使能控制逻辑
    // 乘除法结果准备好时开启写回
    assign reg_we_o = (req_muldiv_i && is_mul_op && mul_ready_i == 1'b1) ? `WriteEnable :
                      (req_muldiv_i && is_div_op && div_ready_i == `DivResultReady) ? `WriteEnable :
                      (!req_muldiv_i && (div_ready_i == `DivResultReady || mul_ready_i == 1'b1)) ? `WriteEnable : 
                      `WriteDisable;

endmodule
