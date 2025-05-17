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

// 通用寄存器模块
module regs (

    input wire clk,
    input wire rst_n,

    // from ex
    input wire                       we_i,     // 写寄存器标志
    input wire [`REG_ADDR_WIDTH-1:0] waddr_i,  // 写寄存器地址
    input wire [`REG_DATA_WIDTH-1:0] wdata_i,  // 写寄存器数据

    // from id
    input wire [`REG_ADDR_WIDTH-1:0] raddr1_i,  // 读寄存器1地址

    // to id
    output reg [`REG_DATA_WIDTH-1:0] rdata1_o,  // 读寄存器1数据

    // from id
    input wire [`REG_ADDR_WIDTH-1:0] raddr2_i,  // 读寄存器2地址

    // to id
    output reg [`REG_DATA_WIDTH-1:0] rdata2_o  // 读寄存器2数据

);

    reg [`REG_DATA_WIDTH-1:0] regs[0:`REG_NUM - 1];

    // 写寄存器
    always @(posedge clk) begin
        if (rst_n == `RstDisable) begin
            // 优先ex模块写操作
            if ((we_i == `WriteEnable) && (waddr_i != `ZeroReg)) begin
                regs[waddr_i] <= wdata_i;
            end
        end
    end

    // 读寄存器1
    always @(*) begin
        if (raddr1_i == `ZeroReg) begin
            rdata1_o = `ZeroWord;
            // 如果读地址等于写地址，并且正在写操作，则直接返回写数据
        end else if (raddr1_i == waddr_i && we_i == `WriteEnable) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = regs[raddr1_i];
        end
    end

    // 读寄存器2
    always @(*) begin
        if (raddr2_i == `ZeroReg) begin
            rdata2_o = `ZeroWord;
            // 如果读地址等于写地址，并且正在写操作，则直接返回写数据
        end else if (raddr2_i == waddr_i && we_i == `WriteEnable) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = regs[raddr2_i];
        end
    end

endmodule
