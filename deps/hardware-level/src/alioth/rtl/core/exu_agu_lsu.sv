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

// 地址生成单元 - 处理内存访问和相关寄存器操作
module agu (
    input wire rst,

    input wire        req_mem_i,
    input wire [31:0] mem_op1_i,
    input wire [31:0] mem_op2_i,
    input wire [31:0] mem_rs2_data_i,
    input wire        mem_op_lb_i,
    input wire        mem_op_lh_i,
    input wire        mem_op_lw_i,
    input wire        mem_op_lbu_i,
    input wire        mem_op_lhu_i,
    input wire        mem_op_sb_i,
    input wire        mem_op_sh_i,
    input wire        mem_op_sw_i,
    input wire [ 4:0] rd_addr_i,

    // 内存数据输入
    input wire [`BUS_DATA_WIDTH-1:0] mem_rdata_i,

    // 中断信号
    input wire int_assert_i,

    // 内存接口输出
    output reg [`BUS_DATA_WIDTH-1:0] mem_wdata_o,
    output reg [`BUS_ADDR_WIDTH-1:0] mem_raddr_o,
    output reg [`BUS_ADDR_WIDTH-1:0] mem_waddr_o,
    output reg                       mem_we_o,
    output reg                       mem_req_o,
    output reg [                3:0] mem_wmask_o,  // 字节写入掩码，4位分别对应4个字节

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);  // 内部信号
    wire [1:0] mem_addr_index;

    // 计算内存访问的字节索引
    assign mem_addr_index = (mem_op1_i + mem_op2_i) & 2'b11;

    // AGU逻辑
    always @(*) begin
        // 默认值
        mem_wdata_o = `ZeroWord;
        mem_raddr_o = `ZeroWord;
        mem_waddr_o = `ZeroWord;
        mem_we_o    = `WriteDisable;
        mem_req_o   = `RIB_NREQ;
        mem_wmask_o = 4'b0000;  // 默认所有字节不写入
        reg_wdata_o = `ZeroWord;
        reg_we_o    = `WriteDisable;
        reg_waddr_o = `ZeroWord;

        // 响应中断时不访问内存
        if (int_assert_i == `INT_ASSERT) begin
            mem_we_o  = `WriteDisable;
            mem_req_o = `RIB_NREQ;
            reg_we_o  = `WriteDisable;  // 确保中断时不写回寄存器
        end else if (req_mem_i) begin
            if (mem_op_lb_i || mem_op_lh_i || mem_op_lw_i || mem_op_lbu_i || mem_op_lhu_i) begin
                // 加载指令
                mem_req_o   = `RIB_REQ;
                mem_raddr_o = mem_op1_i + mem_op2_i;
                reg_we_o    = `WriteEnable;
                reg_waddr_o = rd_addr_i;  // 使用输入的目标寄存器地址

                if (mem_op_lb_i) begin
                    // 有符号字节加载
                    case (mem_addr_index)
                        2'b00:   reg_wdata_o = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                        2'b01:   reg_wdata_o = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                        2'b10:   reg_wdata_o = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                        default: reg_wdata_o = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                    endcase
                end else if (mem_op_lh_i) begin
                    // 有符号半字加载
                    if (mem_addr_index == 2'b00) begin
                        reg_wdata_o = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                    end else begin
                        reg_wdata_o = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                    end
                end else if (mem_op_lw_i) begin
                    // 字加载
                    reg_wdata_o = mem_rdata_i;
                end else if (mem_op_lbu_i) begin
                    // 无符号字节加载
                    case (mem_addr_index)
                        2'b00:   reg_wdata_o = {24'h0, mem_rdata_i[7:0]};
                        2'b01:   reg_wdata_o = {24'h0, mem_rdata_i[15:8]};
                        2'b10:   reg_wdata_o = {24'h0, mem_rdata_i[23:16]};
                        default: reg_wdata_o = {24'h0, mem_rdata_i[31:24]};
                    endcase
                end else if (mem_op_lhu_i) begin
                    // 无符号半字加载
                    if (mem_addr_index == 2'b00) begin
                        reg_wdata_o = {16'h0, mem_rdata_i[15:0]};
                    end else begin
                        reg_wdata_o = {16'h0, mem_rdata_i[31:16]};
                    end
                end
            end else if (mem_op_sb_i || mem_op_sh_i || mem_op_sw_i) begin
                // 存储指令
                mem_req_o   = `RIB_REQ;
                mem_we_o    = `WriteEnable;
                mem_waddr_o = mem_op1_i + mem_op2_i;
                reg_we_o    = `WriteDisable;  // 存储指令不需要写回寄存器
                mem_wmask_o = 4'b0000;  // 默认所有字节不写入

                if (mem_op_sb_i) begin
                    // 字节存储
                    case (mem_addr_index)
                        2'b00: begin
                            mem_wmask_o = 4'b0001;  // 只写最低字节
                            mem_wdata_o = {24'b0, mem_rs2_data_i[7:0]};
                        end
                        2'b01: begin
                            mem_wmask_o = 4'b0010;  // 只写次低字节
                            mem_wdata_o = {16'b0, mem_rs2_data_i[7:0], 8'b0};
                        end
                        2'b10: begin
                            mem_wmask_o = 4'b0100;  // 只写次高字节
                            mem_wdata_o = {8'b0, mem_rs2_data_i[7:0], 16'b0};
                        end
                        default: begin
                            mem_wmask_o = 4'b1000;  // 只写最高字节
                            mem_wdata_o = {mem_rs2_data_i[7:0], 24'b0};
                        end
                    endcase
                end else if (mem_op_sh_i) begin
                    // 半字存储
                    if (mem_addr_index == 2'b00) begin
                        mem_wmask_o = 4'b0011;  // 写入低两个字节
                        mem_wdata_o = {16'b0, mem_rs2_data_i[15:0]};
                    end else begin
                        mem_wmask_o = 4'b1100;  // 写入高两个字节
                        mem_wdata_o = {mem_rs2_data_i[15:0], 16'b0};
                    end
                end else if (mem_op_sw_i) begin
                    // 字存储
                    mem_wmask_o = 4'b1111;  // 写入所有四个字节
                    mem_wdata_o = mem_rs2_data_i;
                end
            end
        end
    end

endmodule
