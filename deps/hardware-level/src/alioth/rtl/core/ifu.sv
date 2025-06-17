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
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FITCM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "defines.svh"

// 指令获取模块(顶层)
module ifu (

    input wire clk,
    input wire rst_n,

    // 来自控制模块
    input wire                        jump_flag_i,  // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,  // 跳转地址
    input wire [ `HOLD_BUS_WIDTH-1:0] stall_flag_i, // 流水线暂停标志

    // 输出到ID阶段的信息
    output wire [`INST_DATA_WIDTH-1:0] inst_o,            // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,       // 指令地址
    output wire                        read_resp_error_o, // AXI读响应错误信号

    // AXI接口
    // AXI读地址通道
    output wire [                 3:0] M_AXI_ARID,
    output wire [`INST_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                 7:0] M_AXI_ARLEN,
    output wire [                 2:0] M_AXI_ARSIZE,
    output wire [                 1:0] M_AXI_ARBURST,
    output wire                        M_AXI_ARLOCK,
    output wire [                 3:0] M_AXI_ARCACHE,
    output wire [                 2:0] M_AXI_ARPROT,
    output wire [                 3:0] M_AXI_ARQOS,
    output wire [                 3:0] M_AXI_ARUSER,
    output wire                        M_AXI_ARVALID,
    input  wire                        M_AXI_ARREADY,
    // AXI读数据通道
    input  wire [                 3:0] M_AXI_RID,
    input  wire [`INST_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                 1:0] M_AXI_RRESP,
    input  wire                        M_AXI_RLAST,
    input  wire [                 3:0] M_AXI_RUSER,
    input  wire                        M_AXI_RVALID,
    output wire                        M_AXI_RREADY
);

    // 在顶层处理stall_flag_i信号
    wire axi_pc_stall;
    wire stall_pc = (stall_flag_i != 0) || axi_pc_stall;  // PC暂停信号
    wire stall_if = (stall_flag_i >= `Hold_If);  // IF暂停信号
    wire flush_flag = (stall_flag_i >= `Hold_Flush);  // 流水线冲刷信号

    // 内部信号定义
    wire [`INST_ADDR_WIDTH-1:0] pc;  // 内部PC信号
    wire [`INST_DATA_WIDTH-1:0] inst_data;  // 从AXI读取的指令数据
    wire [`INST_ADDR_WIDTH-1:0] inst_addr;  // 从AXI读取的指令地址
    wire inst_valid;  // 指令有效信号

    // 实例化IFetch模块，现包含ifu_pipe功能
    ifu_ifetch u_ifu_ifetch (
        .clk          (clk),
        .rst_n        (rst_n),
        .jump_flag_i  (jump_flag_i),
        .jump_addr_i  (jump_addr_i),
        .stall_pc_i   (stall_pc),
        .axi_arready_i(M_AXI_ARREADY),  // 连接AXI读地址通道准备好信号
        .inst_i       (inst_data),      // 使用从AXI读取的指令
        .inst_addr_i  (inst_addr),      // 使用从AXI读取的指令地址
        .flush_flag_i (flush_flag),
        .inst_valid_i (inst_valid),     // 从AXI控制器获取的有效信号
        .stall_if_i   (stall_if),       // 连接IF阶段暂停信号
        .pc_o         (pc),             // PC输出
        .inst_o       (inst_o),         // 指令输出
        .inst_addr_o  (inst_addr_o)     // 指令地址输出
    );

    // 实例化AXI主机模块
    ifu_axi_master u_ifu_axi_master (
        .clk              (clk),
        .rst_n            (rst_n),
        .flush_flag_i     (flush_flag),
        .jump_flag_i      (jump_flag_i),        // 连接跳转标志信号
        .pc_i             (pc),
        .read_resp_error_o(read_resp_error_o),
        .inst_data_o      (inst_data),          // 连接指令数据输出
        .inst_addr_o      (inst_addr),          // 连接指令地址输出
        .inst_valid_o     (inst_valid),         // 连接指令有效信号输出
        .pc_stall_o       (axi_pc_stall),       // 连接PC暂停信号输出

        // AXI读地址通道
        .M_AXI_ARID   (M_AXI_ARID),
        .M_AXI_ARADDR (M_AXI_ARADDR),
        .M_AXI_ARLEN  (M_AXI_ARLEN),
        .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),
        .M_AXI_ARLOCK (M_AXI_ARLOCK),
        .M_AXI_ARCACHE(M_AXI_ARCACHE),
        .M_AXI_ARPROT (M_AXI_ARPROT),
        .M_AXI_ARQOS  (M_AXI_ARQOS),
        .M_AXI_ARUSER (M_AXI_ARUSER),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),

        // AXI读数据通道
        .M_AXI_RID   (M_AXI_RID),
        .M_AXI_RDATA (M_AXI_RDATA),
        .M_AXI_RRESP (M_AXI_RRESP),
        .M_AXI_RLAST (M_AXI_RLAST),
        .M_AXI_RUSER (M_AXI_RUSER),
        .M_AXI_RVALID(M_AXI_RVALID),
        .M_AXI_RREADY(M_AXI_RREADY)
    );

endmodule
