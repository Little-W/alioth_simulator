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

module agu (
    input  wire        op_mem,
    input  wire [`DECINFO_WIDTH-1:0] mem_info,
    input  wire [31:0] rs1_rdata_i,
    input  wire [31:0] rs2_rdata_i,
    input  wire [31:0] dec_imm_i,
    input  wire [31:0] frs2_rdata_i, // 新增浮点寄存器输入
    output wire        mem_op_lb_o,
    output wire        mem_op_lh_o,
    output wire        mem_op_lw_o,
    output wire        mem_op_lbu_o,
    output wire        mem_op_lhu_o,
    output wire        mem_op_sb_o,
    output wire        mem_op_sh_o,
    output wire        mem_op_sw_o,
    output wire        mem_op_load_o,
    output wire        mem_op_store_o,
    output wire [31:0] mem_addr_o,
    output wire [ 3:0] mem_wmask_o,
    output wire [31:0] mem_wdata_o,
    output wire        misaligned_load_o,
    output wire        misaligned_store_o
);

    // mem op类型信号
    wire mem_op_lb = mem_info[`DECINFO_MEM_LB];
    wire mem_op_lh = mem_info[`DECINFO_MEM_LH];
    wire mem_op_lw = mem_info[`DECINFO_MEM_LW];
    wire mem_op_lbu = mem_info[`DECINFO_MEM_LBU];
    wire mem_op_lhu = mem_info[`DECINFO_MEM_LHU];
    wire mem_op_sb = mem_info[`DECINFO_MEM_SB];
    wire mem_op_sh = mem_info[`DECINFO_MEM_SH];
    wire mem_op_sw = mem_info[`DECINFO_MEM_SW];

    // 浮点内存操作
    wire mem_op_flw = mem_info[`DECINFO_MEM_FLW];  // FLW加载一个浮点字
    wire mem_op_fsw = mem_info[`DECINFO_MEM_FSW];  // FSW存储一个浮点字

    // 这些信号仍然作为输出
    assign mem_op_lb_o    = mem_op_lb;
    assign mem_op_lh_o    = mem_op_lh;
    assign mem_op_lw_o    = mem_op_lw | mem_op_flw;  // LW和FLW都加载一个字
    assign mem_op_lbu_o   = mem_op_lbu;
    assign mem_op_lhu_o   = mem_op_lhu;
    assign mem_op_sb_o    = mem_op_sb;
    assign mem_op_sh_o    = mem_op_sh;
    assign mem_op_sw_o    = mem_op_sw | mem_op_fsw;  // SW和FSW都存储一个字
    assign mem_op_load_o  = mem_info[`DECINFO_MEM_OP_LOAD] | mem_op_flw;  // 所有加载指令，包括FLW
    assign mem_op_store_o = mem_info[`DECINFO_MEM_OP_STORE] | mem_op_fsw;  // 所有存储指令，包括FSW

    // 直接计算内存地址
    wire [31:0] mem_addr = rs1_rdata_i + dec_imm_i;
    wire [ 1:0] mem_addr_index = mem_addr[1:0];
    wire        valid_op = op_mem;

    // 存储操作的掩码和数据计算
    wire [ 3:0] sb_mask;
    wire [31:0] sb_data;
    assign sb_mask = ({4{mem_addr_index == 2'b00}} & 4'b0001) |
                     ({4{mem_addr_index == 2'b01}} & 4'b0010) |
                     ({4{mem_addr_index == 2'b10}} & 4'b0100) |
                     ({4{mem_addr_index == 2'b11}} & 4'b1000);
    assign sb_data = ({32{mem_addr_index == 2'b00}} & {24'b0, rs2_rdata_i[7:0]}) |
                     ({32{mem_addr_index == 2'b01}} & {16'b0, rs2_rdata_i[7:0], 8'b0}) |
                     ({32{mem_addr_index == 2'b10}} & {8'b0, rs2_rdata_i[7:0], 16'b0}) |
                     ({32{mem_addr_index == 2'b11}} & {rs2_rdata_i[7:0], 24'b0});

    wire [ 3:0] sh_mask;
    wire [31:0] sh_data;
    assign sh_mask = ({4{mem_addr_index[1] == 1'b0}} & 4'b0011) | 
                     ({4{mem_addr_index[1] == 1'b1}} & 4'b1100);
    assign sh_data = ({32{mem_addr_index[1] == 1'b0}} & {16'b0, rs2_rdata_i[15:0]}) |
                     ({32{mem_addr_index[1] == 1'b1}} & {rs2_rdata_i[15:0], 16'b0});

    wire [ 3:0] sw_mask;
    wire [31:0] sw_data;
    assign sw_mask = 4'b1111;
    assign sw_data = rs2_rdata_i;

    // 浮点字存储掩码和数据 (FSW指令)
    wire [ 3:0] fsw_mask;
    wire [31:0] fsw_data;

    assign fsw_mask = 4'b1111;  // FSW也是32位字存储
    assign fsw_data = frs2_rdata_i;  // 使用浮点寄存器数据

    wire [ 3:0] mem_wmask;
    wire [31:0] mem_wdata;
    assign mem_wmask = ({4{valid_op & mem_op_sb}}  & sb_mask)  |
                       ({4{valid_op & mem_op_sh}}  & sh_mask)  |
                       ({4{valid_op & mem_op_sw}}  & sw_mask)  |
                       ({4{valid_op & mem_op_fsw}} & fsw_mask);
    assign mem_wdata = ({32{valid_op & mem_op_sb}}  & sb_data)  |
                       ({32{valid_op & mem_op_sh}}  & sh_data)  |
                       ({32{valid_op & mem_op_sw}}  & sw_data)  |
                       ({32{valid_op & mem_op_fsw}} & fsw_data);

    assign mem_addr_o = mem_addr;
    assign mem_wmask_o = mem_wmask;
    assign mem_wdata_o = mem_wdata;

    // 地址对齐检测逻辑
    assign misaligned_load_o  = mem_op_load_o  & (
        (mem_op_lw_o  && (mem_addr_o[1:0] != 2'b00)) ||
        ((mem_op_lh_o | mem_op_lhu_o) && (mem_addr_o[0] != 1'b0))
    );

    assign misaligned_store_o = mem_op_store_o & (
        (mem_op_sw_o && (mem_addr_o[1:0] != 2'b00)) ||
        (mem_op_sh_o && (mem_addr_o[0] != 1'b0))
    );

endmodule
