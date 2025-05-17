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

// 带默认值和控制信号的流水线触发器
module gnrl_pipe_dff #(
    parameter DW = 32
) (

    input wire clk,
    input wire rst_n,
    input wire hold_en,  // 暂停使能信号

    input  wire [DW-1:0] def_val,  // 默认值
    input  wire [DW-1:0] din,      // 输入数据
    output wire [DW-1:0] qout      // 输出数据

);

    reg [DW-1:0] qout_r;

    always @(posedge clk) begin : PIPE_DFF
        if (!rst_n) begin
            qout_r <= def_val;  // 复位时输出默认值
        end else if (hold_en) begin
            qout_r <= def_val;  // 暂停时输出默认值
        end else begin
            qout_r <= din;      // 正常情况下输出输入数据
        end
    end

    assign qout = qout_r;
endmodule

// 带使能信号的D触发器
module gnrl_dfflr #(
    parameter DW = 32
) (

    input clk,
    input rst_n,

    input           lden,  // 使能信号
    input  [DW-1:0] dnxt,  // 下一个数据
    output [DW-1:0] qout   // 输出数据
);

    reg [DW-1:0] qout_r;

    always @(posedge clk) begin : DFFLR_PROC
        if (!rst_n) qout_r <= {DW{1'b0}};  // 复位时输出0
        else if (lden) qout_r <= #1 dnxt;  // 使能时更新数据
    end

    assign qout = qout_r;

endmodule

// 无使能信号的D触发器
module gnrl_dff #(
    parameter DW = 32
) (

    input clk,
    input rst_n,

    input  [DW-1:0] dnxt,  // 下一个数据
    output [DW-1:0] qout   // 输出数据
);

    reg [DW-1:0] qout_r;

    always @(posedge clk) begin : DFF_PROC
        if (!rst_n) qout_r <= {DW{1'b0}};  // 复位时输出0
        else qout_r <= #1 dnxt;            // 正常情况下更新数据
    end

    assign qout = qout_r;

endmodule
