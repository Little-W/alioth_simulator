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

`include "../core/defines.v"

// 通用RAM模块 - 参数化设计
module gnrl_ram #(
    parameter ADDR_WIDTH = 16,  // 地址宽度参数
    parameter DATA_WIDTH = 32,   // 数据宽度参数
    parameter INIT_MEM   = 1,    // 是否初始化内存，1表示初始化，0表示不初始化
    parameter INIT_FILE  = "/media/5/Projects/RISC-V/tinyriscv/tools/prog.mem" // 初始化文件路径
) (
    input wire clk,
    input wire rst,

    input wire                  we_i,       // write enable
    input wire [3:0]            we_mask_i,  // 字节写入掩码 (byte write enable)
    input wire [ADDR_WIDTH-1:0] addr_i,     // addr
    input wire [DATA_WIDTH-1:0] data_i,     // write data

    output reg [DATA_WIDTH-1:0] data_o      // read data
);

    // 字节地址到字地址转换的偏移量（每个字4字节，需要右移2位）
    localparam ADDR_OFFSET = 2;

    // 自动计算深度 = 2^(ADDR_WIDTH - ADDR_OFFSET)，因为是按字寻址
    localparam DEPTH = (1 << (ADDR_WIDTH - ADDR_OFFSET));

    // 使用计算出的深度定义存储器
    reg [DATA_WIDTH-1:0] mem_r[0:DEPTH-1];

    initial begin
        if (INIT_MEM) begin
            $readmemh(INIT_FILE, mem_r);
        end
    end

    // 从字节地址计算出字地址
    wire [ADDR_WIDTH-ADDR_OFFSET-1:0] word_addr;
    assign word_addr = addr_i[ADDR_WIDTH-1:ADDR_OFFSET];

    always @(posedge clk) begin
        if (we_i == `WriteEnable) begin
            // 根据掩码对每个字节单独处理
            if (we_mask_i[0]) mem_r[word_addr][7:0]    <= data_i[7:0];
            if (we_mask_i[1]) mem_r[word_addr][15:8]   <= data_i[15:8];
            if (we_mask_i[2]) mem_r[word_addr][23:16]  <= data_i[23:16];
            if (we_mask_i[3]) mem_r[word_addr][31:24]  <= data_i[31:24];
        end
    end

    always @(*) begin
        if (rst == `RstEnable) begin
            data_o = {DATA_WIDTH{1'b0}};
        end else begin
            data_o = mem_r[word_addr];
        end
    end

endmodule
