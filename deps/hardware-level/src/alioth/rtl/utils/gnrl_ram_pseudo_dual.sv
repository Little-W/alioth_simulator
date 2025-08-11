/*         
 The MIT License (MIT)

 Copyright © 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
                                                                         
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
                                                                         
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "defines.svh"

// 伪双端口RAM模块 - 支持读写分离
module gnrl_ram_pseudo_dual #(
    parameter ADDR_WIDTH = 16,  // 地址宽度参数
    parameter DATA_WIDTH = 32,  // 数据宽度参数
    parameter INIT_MEM = 1,     // 是否初始化内存，1表示初始化，0表示不初始化
    parameter INIT_FILE = "prog.mem"  // 初始化文件路径
) (
    input wire clk,
    input wire rst_n,

    // 写端口
    input wire                       we_i,       // write enable
    input wire [(DATA_WIDTH/8)-1:0]  we_mask_i,  // 字节写入掩码 (byte write enable)
    input wire [     ADDR_WIDTH-1:0] waddr_i,    // write addr
    input wire [     DATA_WIDTH-1:0] data_i,     // write data

    // 读端口
    input  wire [ADDR_WIDTH-1:0] raddr_i,   // read addr
    output reg  [DATA_WIDTH-1:0] data_o     // read data
);

    // 字节地址到字地址转换的偏移量
    // 32位数据：每个字4字节，需要右移2位
    // 64位数据：每个字8字节，需要右移3位
    localparam ADDR_OFFSET = (DATA_WIDTH == 64) ? 3 : 2;

    // 自动计算深度 = 2^(ADDR_WIDTH - ADDR_OFFSET)，因为是按字寻址
    localparam DEPTH = (1 << (ADDR_WIDTH - ADDR_OFFSET));

    // 使用计算出的深度定义存储器
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem_r[0:DEPTH-1];

    initial begin
        if (INIT_MEM) begin
            if (DATA_WIDTH == 64) begin
                // 64位模式：从32位指令文件读取并组合成64位数据
                reg [31:0] temp_mem[0:DEPTH*2-1];
                integer i;
                $readmemh(INIT_FILE, temp_mem);
                for (i = 0; i < DEPTH; i = i + 1) begin
                    // 组合两个连续的32位指令成64位：{inst1, inst0}
                    mem_r[i] = {temp_mem[i*2+1], temp_mem[i*2]};
                end
            end else begin
                // 非64位模式：直接读取
                $readmemh(INIT_FILE, mem_r);
            end
        end
    end

    // 从字节地址计算出字地址
    wire [ADDR_WIDTH-ADDR_OFFSET-1:0] rword_addr;
    wire [ADDR_WIDTH-ADDR_OFFSET-1:0] wword_addr;
    assign rword_addr = raddr_i[ADDR_WIDTH-1:ADDR_OFFSET];
    assign wword_addr = waddr_i[ADDR_WIDTH-1:ADDR_OFFSET];

    // 写入逻辑 - 支持任意DATA_WIDTH
    genvar i;
    generate
        for (i = 0; i < (DATA_WIDTH/8); i = i + 1) begin : gen_write_mask
            always @(posedge clk) begin
                if (we_i == 1'b1 && we_mask_i[i]) begin
                    mem_r[wword_addr][i*8+7:i*8] <= data_i[i*8+7:i*8];
                end
            end
        end
    endgenerate

    // 同步读取逻辑
    always @(posedge clk) begin
        if (!rst_n) begin
            data_o <= {DATA_WIDTH{1'b0}};
        end else begin
            data_o <= mem_r[rword_addr];
        end
    end

endmodule
