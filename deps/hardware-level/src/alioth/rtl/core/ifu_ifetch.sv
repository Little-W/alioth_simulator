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

// PC寄存器模�??
module ifu_ifetch (

    input wire clk,
    input wire rst_n,

    input wire                        jump_flag_i,   // 跳转标志
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,   // 跳转地址
    input wire                        stall_pc_i,    // PC暂停信号
    input wire                        axi_arready_i, // AXI读地�??通道准备好信�??

    // ifu_pipe �??�??的输�??
    input wire [`INST_DATA_WIDTH-1:0] inst_i,        // 指令内容
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,   // 指令地址
    input wire                        flush_flag_i,  // 流水线冲刷标�??
    input wire                        inst_valid_i,  // 指令有效信号
    input wire                        stall_if_i,    // IF阶段保持信号

    output wire [`INST_ADDR_WIDTH-1:0] pc_o,  // PC指针

    // ifu_pipe 的输�??
    output wire [`INST_DATA_WIDTH-1:0] inst_o,       // 指令内容
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,  // 指令地址
    output wire [`INST_ADDR_WIDTH-1:0] old_pc        // 旧的PC地址
);

    // 下一个PC�??
    wire [`INST_ADDR_WIDTH-1:0] pc_nxt;

    // 计算实际的PC暂停信号：原有暂停信号或AXI未就�??
    wire                        stall_pc_actual = stall_pc_i || !axi_arready_i;

    // 根据控制信号计算下一个PC�??
    assign pc_nxt = (!rst_n) ? `PC_RESET_ADDR :  // 复位
        (jump_flag_i == `JumpEnable) ? jump_addr_i :  // 跳转
        (stall_pc_actual) ? pc_o :  // 暂停（包括AXI未就绪的情况�??
        (branch_taken) ? branch_addr :  // 分支预测跳转
        pc_o + 4'h4;  // 地址�??4

    // 使用gnrl_dff模块实现PC寄存�??
    gnrl_dff #(
        .DW(`INST_ADDR_WIDTH)
    ) pc_dff (
        .clk  (clk),
        .rst_n(1'b1),  // 不需要复�??
        .dnxt (pc_nxt),
        .qout (pc_o)
    );

    // 实例化ifu_pipe模块
    ifu_pipe u_ifu_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .inst_i      (inst_i),
        .inst_addr_i (inst_addr_i),
        .flush_flag_i(flush_flag_i),
        .inst_valid_i(inst_valid_i),
        .stall_i     (stall_if_i),
        .old_pc_i    (old_pc_pipe),  // 连接当前PC作为旧的PC地址
        .inst_o      (inst_o),
        .inst_addr_o (inst_addr_o),
        .old_pc_o    (old_pc)  // 输出旧的PC地址

    );

wire [`INST_ADDR_WIDTH-1:0] old_pc_pipe;  // 用于存储旧的PC地址
wire branch_taken;  // 分支预测结果
wire [`INST_ADDR_WIDTH-1:0] branch_addr;  // 分支地址
parameter branchprediction_enable = `branchprediction_enable;  // 分支预测使能参数

if (branchprediction_enable) begin: go_branchprediction
    // 分支预测模块实例�??
    ifu_sbpu u_ifu_sbpu (
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_i         (inst_i),
        .inst_valid_i   (inst_valid_i),
        .pc_i           (pc_o),
        .branch_taken_o (branch_taken),
        .branch_addr_o  (branch_addr),
        .old_pc_o       (old_pc_pipe)  // 旧的PC地址
    );
end else begin: no_branchprediction
    // 如果不启用分支预测，则实例化�??个空模块
    assign branch_taken = 1'b0 ;
    assign branch_addr_o = 32'h0;  // 默认分支地址
    assign old_pc_pipe = 32'h0;  // 旧的PC地址直接连接到当前PC

end

endmodule
