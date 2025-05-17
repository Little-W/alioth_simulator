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


module exu_bru (
    input wire        rst,
    input wire        req_bjp_i,
    input wire [31:0] bjp_op1_i,
    input wire [31:0] bjp_op2_i,
    input wire [31:0] bjp_jump_op1_i,
    input wire [31:0] bjp_jump_op2_i,
    input wire        bjp_op_jump_i,   // JAL/JALR指令
    input wire        bjp_op_beq_i,
    input wire        bjp_op_bne_i,
    input wire        bjp_op_blt_i,
    input wire        bjp_op_bltu_i,
    input wire        bjp_op_bge_i,
    input wire        bjp_op_bgeu_i,
    input wire        bjp_op_jalr_i,   // JALR指令标志

    input wire                        sys_op_fence_i,  // FENCE指令
    // 中断信号
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 跳转输出
    output reg                        jump_flag_o,
    output reg [`INST_ADDR_WIDTH-1:0] jump_addr_o
);
    // 内部信号
    wire        op1_eq_op2;
    wire        op1_ge_op2_signed;
    wire        op1_ge_op2_unsigned;
    wire [31:0] op1_jump_add_op2_jump_res;

    // 比较结果
    assign op1_eq_op2                = (bjp_op1_i == bjp_op2_i);
    assign op1_ge_op2_signed         = $signed(bjp_op1_i) >= $signed(bjp_op2_i);
    assign op1_ge_op2_unsigned       = bjp_op1_i >= bjp_op2_i;

    // 计算跳转地址
    assign op1_jump_add_op2_jump_res = bjp_jump_op1_i + bjp_jump_op2_i;

    // 分支单元逻辑
    always @(*) begin
        // 默认值
        jump_flag_o = `JumpDisable;
        jump_addr_o = `ZeroWord;

        // 中断处理
        if (int_assert_i == `INT_ASSERT) begin
            jump_flag_o = `JumpEnable;
            jump_addr_o = int_addr_i;
        end else if (req_bjp_i) begin
            if (bjp_op_jump_i) begin  // JAL指令
                jump_flag_o = `JumpEnable;
                jump_addr_o = op1_jump_add_op2_jump_res;
            end else if (bjp_op_jalr_i) begin  // JALR指令
                jump_flag_o = `JumpEnable;
                jump_addr_o = op1_jump_add_op2_jump_res;
            end else if (bjp_op_beq_i) begin  // BEQ指令
                jump_flag_o = op1_eq_op2 ? `JumpEnable : `JumpDisable;
                jump_addr_o = op1_eq_op2 ? op1_jump_add_op2_jump_res : `ZeroWord;
            end else if (bjp_op_bne_i) begin  // BNE指令
                jump_flag_o = ~op1_eq_op2 ? `JumpEnable : `JumpDisable;
                jump_addr_o = ~op1_eq_op2 ? op1_jump_add_op2_jump_res : `ZeroWord;
            end else if (bjp_op_blt_i) begin  // BLT指令
                jump_flag_o = ~op1_ge_op2_signed ? `JumpEnable : `JumpDisable;
                jump_addr_o = ~op1_ge_op2_signed ? op1_jump_add_op2_jump_res : `ZeroWord;
            end else if (bjp_op_bge_i) begin  // BGE指令
                jump_flag_o = op1_ge_op2_signed ? `JumpEnable : `JumpDisable;
                jump_addr_o = op1_ge_op2_signed ? op1_jump_add_op2_jump_res : `ZeroWord;
            end else if (bjp_op_bltu_i) begin  // BLTU指令
                jump_flag_o = ~op1_ge_op2_unsigned ? `JumpEnable : `JumpDisable;
                jump_addr_o = ~op1_ge_op2_unsigned ? op1_jump_add_op2_jump_res : `ZeroWord;
            end else if (bjp_op_bgeu_i) begin  // BGEU指令
                jump_flag_o = op1_ge_op2_unsigned ? `JumpEnable : `JumpDisable;
                jump_addr_o = op1_ge_op2_unsigned ? op1_jump_add_op2_jump_res : `ZeroWord;
            end else begin
                jump_flag_o = `JumpDisable;
                jump_addr_o = `ZeroWord;
            end
        end else if (sys_op_fence_i) begin  // FENCE指令
            jump_flag_o = `JumpEnable;
            jump_addr_o = op1_jump_add_op2_jump_res;
        end
    end

endmodule


// // 分支单元 - 处理跳转和分支指令
// module exu_bru(
//     input wire rst,

//     // 指令和操作数输入
//     input wire[`INST_DATA_WIDTH-1:0] inst_i,
//     input wire[`INST_ADDR_WIDTH-1:0] inst_addr_i,
//     input wire[`BUS_ADDR_WIDTH-1:0] op1_i,
//     input wire[`BUS_ADDR_WIDTH-1:0] op2_i,
//     input wire[`BUS_ADDR_WIDTH-1:0] op1_jump_i,
//     input wire[`BUS_ADDR_WIDTH-1:0] op2_jump_i,

//     // dispatch模块传来的译码信号
//     input wire bjp_op_jump_i,      // JAL或JALR指令
//     input wire bjp_op_beq_i,       // BEQ指令
//     input wire bjp_op_bne_i,       // BNE指令
//     input wire bjp_op_blt_i,       // BLT指令
//     input wire bjp_op_bltu_i,      // BLTU指令
//     input wire bjp_op_bge_i,       // BGE指令
//     input wire bjp_op_bgeu_i,      // BGEU指令
//     input wire bjp_op_jalr_i,      // JALR指令
//     input wire sys_op_fence_i,     // FENCE指令

//     // 中断信号
//     input wire int_assert_i,
//     input wire[`INST_ADDR_WIDTH-1:0] int_addr_i,

//     // 跳转输出
//     output reg jump_flag_o,
//     output reg[`INST_ADDR_WIDTH-1:0] jump_addr_o
// );

//     // 内部信号
//     wire op1_eq_op2;
//     wire op1_ge_op2_signed;
//     wire op1_ge_op2_unsigned;
//     wire[31:0] op1_jump_add_op2_jump_res;

//     // 比较结果
//     assign op1_eq_op2 = (op1_i == op2_i);
//     assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
//     assign op1_ge_op2_unsigned = op1_i >= op2_i;

//     // 计算跳转地址
//     assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

//     // 分支单元逻辑
//     always @(*) begin
//         // 默认值
//         jump_flag_o = `JumpDisable;
//         jump_addr_o = `ZeroWord;

//         // 中断处理
//         if (int_assert_i == `INT_ASSERT) begin
//             jump_flag_o = `JumpEnable;
//             jump_addr_o = int_addr_i;
//         end else begin
//             if (bjp_op_jump_i || bjp_op_jalr_i) begin  // JAL和JALR指令
//                 jump_flag_o = `JumpEnable;
//                 jump_addr_o = op1_jump_add_op2_jump_res;
//             end else if (bjp_op_beq_i) begin  // BEQ指令
//                 jump_flag_o = op1_eq_op2 & `JumpEnable;
//                 jump_addr_o = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
//             end else if (bjp_op_bne_i) begin  // BNE指令
//                 jump_flag_o = (~op1_eq_op2) & `JumpEnable;
//                 jump_addr_o = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
//             end else if (bjp_op_blt_i) begin  // BLT指令
//                 jump_flag_o = (~op1_ge_op2_signed) & `JumpEnable;
//                 jump_addr_o = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
//             end else if (bjp_op_bge_i) begin  // BGE指令
//                 jump_flag_o = (op1_ge_op2_signed) & `JumpEnable;
//                 jump_addr_o = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
//             end else if (bjp_op_bltu_i) begin  // BLTU指令
//                 jump_flag_o = (~op1_ge_op2_unsigned) & `JumpEnable;
//                 jump_addr_o = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
//             end else if (bjp_op_bgeu_i) begin  // BGEU指令
//                 jump_flag_o = (op1_ge_op2_unsigned) & `JumpEnable;
//                 jump_addr_o = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
//             end else if (sys_op_fence_i) begin  // FENCE指令
//                 jump_flag_o = `JumpEnable;
//                 jump_addr_o = op1_jump_add_op2_jump_res;
//             end else begin
//                 jump_flag_o = `JumpDisable;
//                 jump_addr_o = `ZeroWord;
//             end
//         end
//     end

// endmodule
