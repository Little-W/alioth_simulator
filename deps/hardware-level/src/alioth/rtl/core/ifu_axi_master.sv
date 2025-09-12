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

// 指令获取模块的AXI主机接口
module ifu_axi_master #(
    parameter C_M_AXI_ID_WIDTH   = 2,   // AXI ID宽度
    parameter C_M_AXI_ADDR_WIDTH = 32,  // AXI地址宽度
    parameter C_M_AXI_DATA_WIDTH = 32   // AXI数据宽度
) (
    // 基本信号
    input wire clk,
    input wire rst_n,

    // 控制信号
    input wire stall_axi_i,  // 无法接受新的指令(Flush或者Stall)
    input wire jump_flag_i,  // 跳转标志信号
    input wire [`INST_ADDR_WIDTH-1:0] pc_i,  // PC指针
    output wire read_resp_error_o,  // 读响应错误信号

    // 新增输出
    output wire [`INST_DATA_WIDTH-1:0] inst_data_o,   // 指令数据输出
    output wire [`INST_ADDR_WIDTH-1:0] inst_addr_o,   // 指令地址输出
    output wire                        inst_valid_o,  // 指令有效信号输出
    output wire                        pc_stall_o,    // PC暂停信号输出

    // AXI读地址通道
    output wire [  C_M_AXI_ID_WIDTH-1:0] M_AXI_ARID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                   7:0] M_AXI_ARLEN,
    output wire [                   2:0] M_AXI_ARSIZE,
    output wire [                   1:0] M_AXI_ARBURST,
    output wire                          M_AXI_ARLOCK,
    output wire [                   3:0] M_AXI_ARCACHE,
    output wire [                   2:0] M_AXI_ARPROT,
    output wire [                   3:0] M_AXI_ARQOS,
    output wire [                   3:0] M_AXI_ARUSER,
    output wire                          M_AXI_ARVALID,
    input  wire                          M_AXI_ARREADY,

    // AXI读数据通道
    input  wire [  C_M_AXI_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                   1:0] M_AXI_RRESP,
    input  wire                          M_AXI_RLAST,
    input  wire [                   3:0] M_AXI_RUSER,
    input  wire                          M_AXI_RVALID,
    output wire                          M_AXI_RREADY
);

    localparam ADDR_FIFO_DEPTH = 4;  // 地址FIFO深度参数化
    localparam INST_FIFO_DEPTH = 4;  // 指令FIFO深度
    // AXI参数定义
    localparam C_M_AXI_BURST_LEN = 1;  // 突发长度为1，每次只读取一条指令

    // 内部寄存器
    reg error_reg;  // 错误寄存器
    reg [C_M_AXI_ID_WIDTH-1:0] arid_reg;  // ARID寄存器

    // 地址FIFO实现 - 保存待处理的地址请求
    reg [`INST_ADDR_WIDTH-1:0] addr_fifo[0:ADDR_FIFO_DEPTH-1];  // 地址FIFO
    reg [$clog2(ADDR_FIFO_DEPTH)-1:0] addr_rd_ptr;  // 地址FIFO读指针
    reg [$clog2(ADDR_FIFO_DEPTH)-1:0] addr_wr_ptr;  // 地址FIFO写指针
    reg [$clog2(ADDR_FIFO_DEPTH):0] addr_fifo_count;  // 地址FIFO中数据数量
    wire addr_fifo_empty;  // 地址FIFO为空标志
    wire addr_fifo_full;  // 地址FIFO已满标志

    // 指令FIFO实现 - 用于在stall期间缓存收到的指令响应
    reg [`INST_DATA_WIDTH-1:0] inst_fifo_data[0:INST_FIFO_DEPTH-1];  // 指令数据FIFO
    // reg [`INST_ADDR_WIDTH-1:0] inst_fifo_addr[0:INST_FIFO_DEPTH-1];  // 指令地址FIFO - 删除
    reg [$clog2(INST_FIFO_DEPTH)-1:0] inst_rd_ptr;  // 指令FIFO读指针
    reg [$clog2(INST_FIFO_DEPTH)-1:0] inst_wr_ptr;  // 指令FIFO写指针
    reg [$clog2(INST_FIFO_DEPTH):0] inst_fifo_count;  // 指令FIFO中数据数量
    wire inst_fifo_empty;  // 指令FIFO为空标志
    wire inst_fifo_full;  // 指令FIFO已满标志
    reg stall_prev;  // 前一周期的stall状态

    // 控制信号
    wire push_addr_fifo;  // 推入数据到地址FIFO
    wire pop_addr_fifo;  // 从地址FIFO读取数据
    wire push_inst_fifo;  // 推入数据到指令FIFO
    wire pop_inst_fifo;  // 从指令FIFO读取数据
    wire same_cycle_resp;  // 同一周期响应
    wire [1:0] addr_fifo_op;  // 地址FIFO操作类型: {push, pop}
    wire [1:0] inst_fifo_op;  // 指令FIFO操作类型: {push, pop}
    wire rid_match;  // RID匹配信号
    wire read_hsked;  // 读握手完成
    wire valid_resp;  // 有效响应信号

    // FIFO状态信号
    assign addr_fifo_empty = (addr_fifo_count == 0);
    assign addr_fifo_full = (addr_fifo_count == ADDR_FIFO_DEPTH);

    // 指令FIFO状态信号
    assign inst_fifo_empty = (inst_fifo_count == 0);
    assign inst_fifo_full = (inst_fifo_count == INST_FIFO_DEPTH);

    // RID匹配检查
    assign rid_match = (M_AXI_RID == arid_reg);

    assign read_hsked = M_AXI_RVALID && M_AXI_RREADY && !M_AXI_RRESP[1];

    assign valid_resp = read_hsked && rid_match;

    // PC暂停信号输出 - 当指令FIFO不为空时需要暂停PC
    assign pc_stall_o = (M_AXI_ARVALID && !M_AXI_ARREADY) || addr_fifo_full || !inst_fifo_empty;

    // 同一周期响应检测
    assign same_cycle_resp = M_AXI_ARVALID && M_AXI_ARREADY && valid_resp && addr_fifo_empty;

    // 推入条件：收到有效地址响应且RID匹配且不是同一周期响应且FIFO未满
    assign push_addr_fifo = M_AXI_ARVALID && M_AXI_ARREADY && !same_cycle_resp && !addr_fifo_full;

    // 弹出条件：不冲刷且FIFO非空或同一周期有响应
    assign pop_addr_fifo = !stall_axi_i && (!addr_fifo_empty && (valid_resp || pop_inst_fifo));

    // 地址FIFO操作类型
    assign addr_fifo_op = {push_addr_fifo, pop_addr_fifo && !same_cycle_resp};

    // 指令FIFO控制信号
    // 推入条件： 收到有效响应且处于stall状态，或者指令FIFO非空，且FIFO未满
    assign push_inst_fifo = ((valid_resp && (stall_axi_i || !inst_fifo_empty)) && !inst_fifo_full);

    // 弹出条件：不处于stall状态且指令FIFO非空
    assign pop_inst_fifo = !stall_axi_i && !inst_fifo_empty;

    // 指令FIFO操作类型
    assign inst_fifo_op = {push_inst_fifo, pop_inst_fifo};

    // I/O连接
    // 读地址通道
    assign M_AXI_ARID = arid_reg;  // 使用ARID寄存器
    assign M_AXI_ARADDR = pc_i;  // 直接使用PC指针作为地址
    assign M_AXI_ARLEN = C_M_AXI_BURST_LEN - 1;  // 突发长度
    assign M_AXI_ARSIZE = $clog2((C_M_AXI_DATA_WIDTH / 8));  // 数据宽度
    assign M_AXI_ARBURST = 2'b01;  // INCR类型突发
    assign M_AXI_ARLOCK = 1'b0;
    assign M_AXI_ARCACHE = 4'b0010;  // Normal Non-cacheable Non-bufferable
    assign M_AXI_ARPROT = 3'h0;
    assign M_AXI_ARQOS = 4'h0;
    assign M_AXI_ARUSER = 4'h0;
    assign M_AXI_ARVALID = !stall_axi_i && !addr_fifo_full && inst_fifo_empty;
    assign M_AXI_RREADY = !inst_fifo_full;  // 当指令FIFO未满时才接收数据

    // 读响应错误检测
    wire read_resp_error;
    assign read_resp_error   = M_AXI_RREADY & M_AXI_RVALID & M_AXI_RRESP[1] & rid_match;
    assign read_resp_error_o = error_reg;  // 输出错误状态

    // FIFO管理和ARID控制逻辑
    always @(posedge clk) begin
        if (rst_n == 1'b0) begin
            addr_rd_ptr     <= 0;
            addr_wr_ptr     <= 0;
            addr_fifo_count <= 0;
            inst_rd_ptr     <= 0;
            inst_wr_ptr     <= 0;
            inst_fifo_count <= 0;
            error_reg       <= 1'b0;
            arid_reg        <= {C_M_AXI_ID_WIDTH{1'b0}};  // 初始化ARID
            stall_prev      <= 1'b0;
        end else begin
            stall_prev <= stall_axi_i;

            // 跳转处理：翻转ARID，清空FIFO
            if (jump_flag_i) begin
                arid_reg        <= arid_reg + 1;  // 循环切换ID
                addr_rd_ptr     <= 0;
                addr_wr_ptr     <= 0;
                addr_fifo_count <= 0;
                inst_rd_ptr     <= 0;
                inst_wr_ptr     <= 0;
                inst_fifo_count <= 0;
            end else begin
                // 错误寄存器更新
                if (read_resp_error) begin
                    error_reg <= 1'b1;
                end

                // 指令FIFO管理 - 使用统一的操作逻辑
                case (inst_fifo_op)
                    2'b10: begin  // 只推入
                        inst_fifo_data[inst_wr_ptr] <= M_AXI_RDATA;
                        // inst_fifo_addr[inst_wr_ptr] <= (!addr_fifo_empty) ? addr_fifo[addr_rd_ptr] :
                        //                                (same_cycle_resp) ? M_AXI_ARADDR : 32'h0; - 删除
                        inst_wr_ptr <= inst_wr_ptr + 1'd1;
                        if (inst_wr_ptr == INST_FIFO_DEPTH - 1) inst_wr_ptr <= 0;
                        inst_fifo_count <= inst_fifo_count + 1'd1;
                    end
                    2'b01: begin  // 只弹出
                        if (inst_fifo_count > 0) begin
                            // 仅当FIFO非空时才弹出
                            inst_rd_ptr <= inst_rd_ptr + 1'd1;
                            if (inst_rd_ptr == INST_FIFO_DEPTH - 1) inst_rd_ptr <= 0;
                            inst_fifo_count <= inst_fifo_count - 1'd1;
                        end
                    end
                    2'b11: begin  // 同时推入和弹出
                        inst_fifo_data[inst_wr_ptr] <= M_AXI_RDATA;
                        // inst_fifo_addr[inst_wr_ptr] <= (!addr_fifo_empty) ? addr_fifo[addr_rd_ptr] :
                        //                                (same_cycle_resp) ? M_AXI_ARADDR : 32'h0; - 删除
                        inst_wr_ptr <= inst_wr_ptr + 1'd1;
                        if (inst_wr_ptr == INST_FIFO_DEPTH - 1) inst_wr_ptr <= 0;
                        inst_rd_ptr <= inst_rd_ptr + 1'd1;
                        if (inst_rd_ptr == INST_FIFO_DEPTH - 1) inst_rd_ptr <= 0;
                        // inst_fifo_count保持不变
                    end
                    default: begin  // 2'b00: 无操作
                        // 保持当前状态
                    end
                endcase

                // 处理FIFO推入和弹出
                case (addr_fifo_op)
                    2'b10: begin  // 只推入
                        addr_fifo[addr_wr_ptr] <= M_AXI_ARADDR;  // 仅保存地址
                        addr_wr_ptr            <= addr_wr_ptr + 1'd1;  // 循环指针
                        if (addr_wr_ptr == ADDR_FIFO_DEPTH - 1) addr_wr_ptr <= 0;  // 循环回到0
                        addr_fifo_count <= addr_fifo_count + 1'd1;
                    end
                    2'b01: begin  // 只弹出
                        if (addr_fifo_count > 0) begin
                            // 仅当FIFO非空时才弹出
                            addr_rd_ptr <= addr_rd_ptr + 1'd1;  // 循环指针
                            if (addr_rd_ptr == ADDR_FIFO_DEPTH - 1)
                                addr_rd_ptr <= 0;  // 循环回到0
                            addr_fifo_count <= addr_fifo_count - 1'd1;
                        end
                    end
                    2'b11: begin  // 同时推入和弹出
                        addr_fifo[addr_wr_ptr] <= M_AXI_ARADDR;  // 仅保存地址
                        addr_wr_ptr            <= addr_wr_ptr + 1'd1;
                        if (addr_wr_ptr == ADDR_FIFO_DEPTH - 1) addr_wr_ptr <= 0;  // 循环回到0
                        addr_rd_ptr <= addr_rd_ptr + 1'd1;
                        if (addr_rd_ptr == ADDR_FIFO_DEPTH - 1) addr_rd_ptr <= 0;  // 循环回到0
                        // addr_fifo_count保持不变
                    end
                    default: begin  // 2'b00: 无操作
                        // 保持当前状态
                    end
                endcase
            end
        end
    end

    // 输出逻辑 - 当指令FIFO不空时从FIFO输出，否则直接输出
    assign inst_data_o = !inst_fifo_empty ? inst_fifo_data[inst_rd_ptr] : M_AXI_RDATA;
    assign inst_addr_o = (!addr_fifo_empty) ? addr_fifo[addr_rd_ptr] :
                         (same_cycle_resp) ? M_AXI_ARADDR : 0;
    assign inst_valid_o = !inst_fifo_empty || valid_resp;

endmodule
