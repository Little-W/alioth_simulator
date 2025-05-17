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

// 将指令向译码模块传递
module ifu_ifetch (

    input wire clk,
    input wire rst_n,

    input wire [`INST_DATA_WIDTH-1:0] inst_i,      // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i, // 指令地址

    input wire [`Hold_Flag_Bus] hold_flag_i,  // 流水线暂停标志

    output wire [`INST_DATA_WIDTH-1:0] inst_o,      // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o  // 指令地址

);

    wire hold_en = (hold_flag_i >= `Hold_If);

    wire [`INST_DATA_WIDTH-1:0] inst;
    gnrl_pipe_dff #(32) inst_ff (
        clk,
        rst_n,
        hold_en,
        `INST_NOP,
        inst_i,
        inst
    );
    assign inst_o = inst;

    wire [`INST_ADDR_WIDTH-1:0] inst_addr;
    gnrl_pipe_dff #(32) inst_addr_ff (
        clk,
        rst_n,
        hold_en,
        `ZeroWord,
        inst_addr_i,
        inst_addr
    );
    assign inst_addr_o = inst_addr;

endmodule
