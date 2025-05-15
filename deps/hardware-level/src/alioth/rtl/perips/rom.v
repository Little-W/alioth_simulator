/*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
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

`include "../core/defines.v"

// ROM模块 - 使用宏定义的地址宽度
module rom (
    input wire clk,
    input wire rst,

    input wire we_i,                           // write enable
    input wire[`ROM_ADDR_WIDTH-1:0] addr_i,    // addr
    input wire[`BUS_DATA_WIDTH-1:0] data_i,

    output reg[`BUS_DATA_WIDTH-1:0] data_o     // read data
);

    // 字节地址到字地址转换的偏移量（每个字4字节，需要右移2位）
    localparam ADDR_OFFSET = 2;
    
    // 自动计算深度 = 2^(`ROM_ADDR_WIDTH - ADDR_OFFSET)，因为是按字寻址
    localparam DEPTH = (1 << (`ROM_ADDR_WIDTH - ADDR_OFFSET));
    
    // 使用计算出的深度定义存储器
    reg[`BUS_DATA_WIDTH-1:0] _rom[0:DEPTH-1];

    // 从字节地址计算出字地址
    wire[`ROM_ADDR_WIDTH-ADDR_OFFSET-1:0] word_addr;
    assign word_addr = addr_i[`ROM_ADDR_WIDTH-1:ADDR_OFFSET];

    always @ (posedge clk) begin
        if (we_i == `WriteEnable) begin
            _rom[word_addr] <= data_i;
        end
    end

    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = {`BUS_DATA_WIDTH{1'b0}};
        end else begin
            data_o = _rom[word_addr];
        end
    end

endmodule
