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

// PC寄存器模块
module ifu_pc_nxt (

    input wire clk,
    input wire rst_n,

    input wire                        jump_flag_i,  // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,  // 跳转地址
    input wire [      `Hold_Flag_Bus] hold_flag_i,  // 流水线暂停标志

    output wire [`INST_ADDR_WIDTH-1:0] pc_o  // PC指针

);

    // 下一个PC值
    wire [`INST_ADDR_WIDTH-1:0] pc_nxt;

    // 根据控制信号计算下一个PC值
    assign pc_nxt = (rst_n == `RstEnable)         ? `CpuResetAddr :  // 复位
                    (jump_flag_i == `JumpEnable)  ? jump_addr_i   :  // 跳转
                    (hold_flag_i >= `Hold_Pc)     ? pc_o          :  // 暂停
                                                    pc_o + 4'h4;     // 地址加4

    // 使用gnrl_dff模块实现PC寄存器
    gnrl_dff #(
        .DW(`INST_ADDR_WIDTH)
    ) pc_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(pc_nxt),
        .qout(pc_o)
    );

endmodule
