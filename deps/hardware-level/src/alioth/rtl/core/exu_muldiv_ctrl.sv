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
    input wire muldiv_op_mul_all_i,
    input wire muldiv_op_div_all_i,

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
    assign div_dividend_o     = reg1_rdata_i;  // 被除数为第一个寄存器的值
    assign div_divisor_o      = reg2_rdata_i;  // 除数为第二个寄存器的值
    assign div_op_o           = div_op_sel;  // 除法操作类型
    assign div_reg_waddr_o    = reg_waddr_i;  // 除法结果写回地址

    assign mul_multiplicand_o = reg1_rdata_i;  // 被乘数为第一个寄存器的值
    assign mul_multiplier_o   = reg2_rdata_i;  // 乘数为第二个寄存器的值
    assign mul_op_o           = mul_op_sel;  // 乘法操作类型
    assign mul_reg_waddr_o    = reg_waddr_i;  // 乘法结果写回地址

    // 除法启动控制逻辑 - 条件定义
    wire div_int_cond = int_assert_i;
    wire div_op_busy_cond = is_div_op && div_busy_i;
    wire div_op_ready_cond = is_div_op && div_ready_i;
    wire div_op_start_cond = is_div_op && !div_busy_i && !div_ready_i;
    wire div_busy_cond = !is_div_op && div_busy_i;

    // 除法启动控制逻辑
    assign div_start_o = (div_op_busy_cond) | (div_op_start_cond) | (div_busy_cond);

    // 乘法启动控制逻辑
    wire mul_int_cond = int_assert_i;
    wire mul_op_busy_cond = is_mul_op && mul_busy_i;
    wire mul_op_ready_cond = is_mul_op && mul_ready_i;
    wire mul_op_start_cond = is_mul_op && !mul_busy_i && !mul_ready_i;
    wire mul_busy_cond = !is_mul_op && mul_busy_i;

    // 乘法启动控制逻辑
    assign mul_start_o = (mul_op_busy_cond) | (mul_op_start_cond) | (mul_busy_cond);

    // 条件信号定义 - 用于流水线保持逻辑
    wire hold_mul_cond = is_mul_op && (mul_busy_i || !mul_ready_i);
    wire hold_div_cond = is_div_op && (div_busy_i || !div_ready_i);
    wire hold_busy_cond = div_busy_i || mul_busy_i;

    // 流水线保持控制逻辑
    assign muldiv_hold_flag_o = hold_mul_cond | hold_div_cond | hold_busy_cond;

    // 条件信号定义
    wire is_mul_req = is_mul_op;
    wire mul_not_busy = !mul_busy_i;
    wire mul_not_ready = !mul_ready_i;

    wire is_div_req = is_div_op;
    wire div_not_busy = !div_busy_i;
    wire div_not_ready = !div_ready_i;

    // 跳转条件
    wire jump_mul_cond = is_mul_req & mul_not_busy & mul_not_ready;
    wire jump_div_cond = is_div_req & div_not_busy & div_not_ready;

    // 跳转控制逻辑
    assign muldiv_jump_flag_o = jump_mul_cond | jump_div_cond;

    // 选择信号定义
    wire sel_mul = is_mul_op && mul_ready_i;
    wire sel_div = is_div_op && div_ready_i;
    wire sel_div_other = div_ready_i && !is_div_op;
    wire sel_mul_other = mul_ready_i && !is_mul_op;

    // 结果写回数据选择逻辑
    assign reg_wdata_o = 
        ({`REG_DATA_WIDTH{sel_mul}} & mul_result_i) |
        ({`REG_DATA_WIDTH{sel_div}} & div_result_i) |
        ({`REG_DATA_WIDTH{sel_div_other}} & div_result_i) |
        ({`REG_DATA_WIDTH{sel_mul_other}} & mul_result_i);

    // 结果写回地址选择逻辑
    assign reg_waddr_o = 
        ({`REG_ADDR_WIDTH{sel_mul}} & mul_reg_waddr_i) |
        ({`REG_ADDR_WIDTH{sel_div}} & div_reg_waddr_i) |
        ({`REG_ADDR_WIDTH{sel_div_other}} & div_reg_waddr_i) |
        ({`REG_ADDR_WIDTH{sel_mul_other}} & mul_reg_waddr_i);

    // 结果写回使能控制逻辑
    assign reg_we_o = sel_mul | sel_div | sel_div_other | sel_mul_other;

endmodule
