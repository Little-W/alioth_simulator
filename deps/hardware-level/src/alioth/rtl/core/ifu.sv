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
    input wire                        jump_flag_i,     // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,     // 跳转地址
    input wire [   `CU_BUS_WIDTH-1:0] stall_flag_i,    // 流水线暂停标志

    // 输出到ID阶段的信息
    output wire [`INST_DATA_WIDTH-1:0] inst_o,             // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,        // 指令地址
    output wire                        read_resp_error_o,  // AXI读响应错误信号
    output wire                        is_pred_branch_o,   // 添加预测分支指令标志输出
    output wire                        inst_valid_o,        // 添加指令有效信号输出

    // AXI接口
    // AXI读地址通道
    output wire [   `BUS_ID_WIDTH-1:0] M_AXI_ARID,     // 使用BUS_ID_WIDTH定义宽度
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
    input  wire [   `BUS_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [`INST_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                 1:0] M_AXI_RRESP,
    input  wire                        M_AXI_RLAST,
    input  wire [                 3:0] M_AXI_RUSER,
    input  wire                        M_AXI_RVALID,
    output wire                        M_AXI_RREADY
);
    // 内部信号定义
    wire [`INST_ADDR_WIDTH-1:0] pc;  // 内部PC信号
    wire [`INST_DATA_WIDTH-1:0] inst_data;  // 从AXI读取的指令数据
    wire [`INST_ADDR_WIDTH-1:0] inst_addr;  // 从AXI读取的指令地址
    wire inst_valid;  // 指令有效信号

    // 分支预测相关信号
    wire branch_taken;  // 分支预测结果：是否跳转
    wire [`INST_ADDR_WIDTH-1:0] branch_addr;  // 预测的分支目标地址
    wire is_pred_branch;  // 当前指令是否为预测分支指令
    wire is_pred_branch_r;  // 预测分支信号寄存后

    // 合并跳转信号和地址
    wire jump_flag = jump_flag_i | branch_taken;  // 跳转标志
    wire [`INST_ADDR_WIDTH-1:0] jump_addr = jump_flag_i ? jump_addr_i : branch_addr;  // 跳转地址

    wire pc_misaligned;  // 新增：PC非对齐信号

    wire axi_pc_stall;
    wire stall_axi = (stall_flag_i != 0) | pc_misaligned;  // AXI暂停信号，增加pc_misaligned
    wire stall_pc = stall_axi || axi_pc_stall;  // PC暂停信号
    wire stall_if = stall_flag_i[`CU_STALL];  // IF阶段暂停信号
    wire flush_flag = stall_flag_i[`CU_FLUSH];  // 冲刷信号
    // 实例化静态分支预测单元
    sbpu u_sbpu (
        .clk             (clk),
        .rst_n           (rst_n),
        .inst_i          (inst_data),        // 指令内容
        .inst_valid_i    (inst_valid),       // 指令有效信号
        .pc_i            (inst_addr),        // 指令地址
        .any_stall_i     (stall_axi),        // 流水线暂停信号
        .branch_taken_o  (branch_taken),     // 预测是否为分支
        .branch_addr_o   (branch_addr),      // 预测的分支地址
        .is_pred_branch_o(is_pred_branch)  // 当前指令是否为预测分支
    );

    // 实例化IFetch模块，现不再包含ifu_pipe功能
    ifu_ifetch u_ifu_ifetch (
        .clk               (clk),
        .rst_n             (rst_n),
        .jump_flag_i       (jump_flag),      // 使用合并后的跳转标志
        .jump_addr_i       (jump_addr),      // 使用合并后的跳转地址
        .stall_pc_i        (stall_pc),
        .axi_arready_i     (M_AXI_ARREADY),  // 连接AXI读地址通道准备好信号
        .pc_o              (pc),             // PC输出
        .pc_misaligned_o(pc_misaligned)   // 新增：连接PC非对齐信号
    );

    // 实例化ifu_pipe模块
    ifu_pipe u_ifu_pipe (
        .clk             (clk),
        .rst_n           (rst_n),
        .inst_i          (inst_data),        // 使用从AXI读取的指令
        .inst_addr_i     (inst_addr),        // 使用从AXI读取的指令地址
        .is_pred_branch_i(is_pred_branch),   // 连接预测分支信号
        .flush_flag_i    (flush_flag),
        .inst_valid_i    (inst_valid),       // 从AXI控制器获取的有效信号
        .stall_i         (stall_if),         // 连接IF阶段暂停信号
        .inst_o          (inst_o),           // 指令输出
        .inst_addr_o     (inst_addr_o),      // 指令地址输出
        .is_pred_branch_o(is_pred_branch_r), // 连接预测分支信号输出
        .inst_valid_o    (inst_valid_o)      // 连接指令有效信号输出
    );

    // 将内部信号连接到输出端口
    assign is_pred_branch_o = is_pred_branch_r;

    // 实例化AXI主机模块
    ifu_axi_master #(
        .C_M_AXI_ID_WIDTH  (`BUS_ID_WIDTH),
        .C_M_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
        .C_M_AXI_ADDR_WIDTH(`BUS_ADDR_WIDTH)
    ) u_ifu_axi_master (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall_axi_i      (stall_axi),
        .jump_flag_i      (jump_flag),          // 连接跳转标志信号
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
