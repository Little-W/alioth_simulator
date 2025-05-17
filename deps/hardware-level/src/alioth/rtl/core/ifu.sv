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

// 指令获取模块(顶层)
module ifu (

    input wire clk,
    input wire rst,

    // 来自控制模块
    input wire                        jump_flag_i,  // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,  // 跳转地址
    input wire [      `Hold_Flag_Bus] hold_flag_i,  // 流水线暂停标志

    // 从ROM读取的指令
    input wire [`INST_DATA_WIDTH-1:0] inst_i,  // 指令内容

    // 输出到ROM的地址
    output wire [`INST_ADDR_WIDTH-1:0] pc_o,  // PC指针

    // 输出到ID阶段的信息
    output wire [`INST_DATA_WIDTH-1:0] inst_o,      // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o  // 指令地址
);

    // 实例化PC寄存器模块
    ifu_pc_nxt u_ifu_pc_nxt (
        .clk        (clk),
        .rst        (rst),
        .jump_flag_i(jump_flag_i),
        .jump_addr_i(jump_addr_i),
        .hold_flag_i(hold_flag_i),
        .pc_o       (pc_o)
    );

    // 实例化IF/ID模块
    ifu_ifetch u_ifu_ifetch (
        .clk        (clk),
        .rst        (rst),
        .inst_i     (inst_i),
        .inst_addr_i(pc_o),
        .hold_flag_i(hold_flag_i),
        .inst_o     (inst_o),
        .inst_addr_o(inst_addr_o)
    );

endmodule
