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

    input wire [`HOLD_BUS_WIDTH-1:0] hold_flag_i,  // 流水线暂停标志

    output wire [`INST_DATA_WIDTH-1:0] inst_o,      // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o  // 指令地址

);

    wire hold_en = (hold_flag_i >= `Hold_If);
    wire hold_en_r;
    gnrl_dff #(1) hold_en_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (hold_en),
        .qout (hold_en_r)
    );

    assign inst_o = hold_en_r ? `INST_NOP : inst_i;

    wire [`INST_ADDR_WIDTH-1:0] inst_addr;
    // 选择指令地址：如果暂停则选择ZeroWord，否则选择输入地址
    wire [`INST_ADDR_WIDTH-1:0] addr_selected = hold_en ? `ZeroWord : inst_addr_i;

    gnrl_dff #(`INST_ADDR_WIDTH) inst_addr_ff (
        .clk  (clk),
        .rst_n(rst_n),
        .dnxt (addr_selected),
        .qout (inst_addr)
    );
    assign inst_addr_o = inst_addr;

endmodule
