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
    parameter C_M_AXI_ID_WIDTH   = 3,                 // AXI ID宽度，3位支持8个并发事务
    parameter C_M_AXI_ADDR_WIDTH = 32,                // AXI地址宽度
    parameter C_M_AXI_DATA_WIDTH = 64                 // AXI数据宽度，64位双发射总线
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
    output wire [`BUS_DATA_WIDTH-1:0] inst_data_o,   // 指令数据输出
    output wire [`BUS_ADDR_WIDTH-1:0] inst_addr_o,   // 指令地址输出
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

    localparam FIFO_DEPTH = 8;  // 双发射FIFO深度，支持更多outstanding事务
    // AXI参数定义
    localparam C_M_AXI_BURST_LEN = 1;  // 突发长度为1，每次读取8字节（双发射：两个32位指令）

    // 内部寄存器
    reg error_reg;  // 错误寄存器
    reg [C_M_AXI_ID_WIDTH-1:0] arid_reg;  // ARID寄存器

    // 循环FIFO实现 - 只保存地址
    reg [`INST_ADDR_WIDTH-1:0] fifo_addr[0:FIFO_DEPTH-1];  // 参数化FIFO地址
    reg [$clog2(FIFO_DEPTH)-1:0] rd_ptr;  // 读指针
    reg [$clog2(FIFO_DEPTH)-1:0] wr_ptr;  // 写指针
    reg [$clog2(FIFO_DEPTH):0] fifo_count;  // FIFO中数据数量
    wire fifo_empty;  // FIFO为空标志
    wire fifo_full;  // FIFO已满标志

    // 控制信号
    wire push_fifo;  // 推入数据到FIFO
    wire pop_fifo;  // 从FIFO读取数据
    wire same_cycle_resp;  // 同一周期响应
    wire [1:0] fifo_op;  // FIFO操作类型: {push, pop}
    wire rid_match;  // RID匹配信号
    wire read_hsked;  // 读握手完成
    wire valid_resp;  // 有效响应信号

    // FIFO状态信号
    assign fifo_empty      = (fifo_count == 0);
    assign fifo_full       = (fifo_count == FIFO_DEPTH);

    // RID匹配检查
    assign rid_match       = (M_AXI_RID == arid_reg);

    assign read_hsked      = M_AXI_RVALID && M_AXI_RREADY && !M_AXI_RRESP[1];

    assign valid_resp      = read_hsked && rid_match;

    // PC暂停信号输出
    assign pc_stall_o      = (M_AXI_ARVALID && !M_AXI_ARREADY) || fifo_full;

    // 同一周期响应检测
    assign same_cycle_resp = M_AXI_ARVALID && M_AXI_ARREADY && valid_resp && fifo_empty;

    // 推入条件：收到有效地址响应且RID匹配且不是同一周期响应且FIFO未满
    assign push_fifo       = M_AXI_ARVALID && M_AXI_ARREADY && !same_cycle_resp && !fifo_full;

    // 弹出条件：不冲刷且FIFO非空或同一周期有响应
    assign pop_fifo        = !stall_axi_i && (!fifo_empty && valid_resp);

    // FIFO操作类型
    assign fifo_op         = {push_fifo, pop_fifo && !same_cycle_resp};

    // I/O连接
    // 读地址通道
    assign M_AXI_ARID      = arid_reg;  // 使用ARID寄存器
    assign M_AXI_ARADDR    = pc_i;  // 直接使用PC指针作为地址
    assign M_AXI_ARLEN     = C_M_AXI_BURST_LEN - 1;  // 突发长度
    assign M_AXI_ARSIZE    = 3'b011;  // 64位数据宽度(8字节)，用于双发射取两个32位指令
    assign M_AXI_ARBURST   = 2'b01;  // INCR类型突发
    assign M_AXI_ARLOCK    = 1'b0;
    assign M_AXI_ARCACHE   = 4'b0010;  // Normal Non-cacheable Non-bufferable
    assign M_AXI_ARPROT    = 3'h0;
    assign M_AXI_ARQOS     = 4'h0;
    assign M_AXI_ARUSER    = 4'h0;
    assign M_AXI_ARVALID   = !stall_axi_i && !fifo_full;  // 当不冲刷且FIFO未满时有效
    assign M_AXI_RREADY    = !stall_axi_i;  // flush_flag有效时拉低rready，否则为1

    // 读响应错误检测
    wire read_resp_error;
    assign read_resp_error   = M_AXI_RREADY & M_AXI_RVALID & M_AXI_RRESP[1] & rid_match;
    assign read_resp_error_o = error_reg;  // 输出错误状态

    // FIFO管理和ARID控制逻辑
    always @(posedge clk) begin
        if (rst_n == 1'b0) begin
            rd_ptr     <= 0;
            wr_ptr     <= 0;
            fifo_count <= 0;
            error_reg  <= 1'b0;
            arid_reg   <= {C_M_AXI_ID_WIDTH{1'b0}};  // 初始化ARID
        end else begin
            // 跳转处理：翻转ARID，清空FIFO
            if (jump_flag_i) begin
                arid_reg   <= arid_reg + 1;  // 循环切换ID
                rd_ptr     <= 0;
                wr_ptr     <= 0;
                fifo_count <= 0;
            end else begin
                // 错误寄存器更新
                if (read_resp_error) begin
                    error_reg <= 1'b1;
                end

                // 处理FIFO推入和弹出
                case (fifo_op)
                    2'b10: begin  // 只推入
                        fifo_addr[wr_ptr] <= M_AXI_ARADDR;  // 仅保存地址
                        wr_ptr            <= wr_ptr + 1'd1;  // 循环指针
                        if (wr_ptr == FIFO_DEPTH - 1) wr_ptr <= 0;  // 循环回到0
                        fifo_count <= fifo_count + 1'd1;
                    end
                    2'b01: begin  // 只弹出
                        if (fifo_count > 0) begin
                            // 仅当FIFO非空时才弹出
                            rd_ptr <= rd_ptr + 1'd1;  // 循环指针
                            if (rd_ptr == FIFO_DEPTH - 1) rd_ptr <= 0;  // 循环回到0
                            fifo_count <= fifo_count - 1'd1;
                        end
                    end
                    2'b11: begin  // 同时推入和弹出
                        fifo_addr[wr_ptr] <= M_AXI_ARADDR;  // 仅保存地址
                        wr_ptr            <= wr_ptr + 1'd1;
                        if (wr_ptr == FIFO_DEPTH - 1) wr_ptr <= 0;  // 循环回到0
                        rd_ptr <= rd_ptr + 1'd1;
                        if (rd_ptr == FIFO_DEPTH - 1) rd_ptr <= 0;  // 循环回到0
                        // fifo_count保持不变
                    end
                    default: begin  // 2'b00: 无操作
                        // 保持当前状态
                    end
                endcase
            end
        end
    end

    // 输出逻辑 - 数据直接连接到输出
    assign inst_data_o  = M_AXI_RDATA;  // 数据直接从AXI连接到输出

    // 地址仍然从FIFO输出
    assign inst_addr_o  = (!fifo_empty) ? fifo_addr[rd_ptr] : (same_cycle_resp) ? M_AXI_ARADDR : 0;
    assign inst_valid_o = valid_resp;

endmodule
