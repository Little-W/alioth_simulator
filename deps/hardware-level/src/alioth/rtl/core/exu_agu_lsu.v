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

`include "defines.v"

// 地址生成单元 - 处理内存访问和相关寄存器操作
module agu (
    input wire rst,

    // 指令和操作数输入
    input wire [`INST_DATA_WIDTH-1:0] inst_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] op1_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] op2_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,

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
    output reg [3:0]                 mem_wmask_o,  // 字节写入掩码，4位分别对应4个字节

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // 内部信号
    wire [1:0] mem_raddr_index;
    wire [1:0] mem_waddr_index;
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [4:0] rd;

    // 从指令中提取操作码、功能码和目标寄存器地址
    assign opcode          = inst_i[6:0];
    assign funct3          = inst_i[14:12];
    assign rd              = inst_i[11:7];

    // 计算内存访问的字节索引
    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;

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
        end else begin
            case (opcode)
                `INST_TYPE_L: begin
                    mem_req_o   = `RIB_REQ;
                    mem_raddr_o = op1_i + op2_i;
                    reg_we_o    = `WriteEnable;
                    reg_waddr_o = rd;  // 从指令中提取目标寄存器地址

                    case (funct3)
                        `INST_LB: begin
                            case (mem_raddr_index)
                                2'b00:   reg_wdata_o = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                                2'b01:   reg_wdata_o = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                                2'b10:   reg_wdata_o = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                                default: reg_wdata_o = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                            endcase
                        end
                        `INST_LH: begin
                            if (mem_raddr_index == 2'b0) begin
                                reg_wdata_o = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                            end else begin
                                reg_wdata_o = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                            end
                        end
                        `INST_LW: begin
                            reg_wdata_o = mem_rdata_i;
                        end
                        `INST_LBU: begin
                            case (mem_raddr_index)
                                2'b00:   reg_wdata_o = {24'h0, mem_rdata_i[7:0]};
                                2'b01:   reg_wdata_o = {24'h0, mem_rdata_i[15:8]};
                                2'b10:   reg_wdata_o = {24'h0, mem_rdata_i[23:16]};
                                default: reg_wdata_o = {24'h0, mem_rdata_i[31:24]};
                            endcase
                        end
                        `INST_LHU: begin
                            if (mem_raddr_index == 2'b0) begin
                                reg_wdata_o = {16'h0, mem_rdata_i[15:0]};
                            end else begin
                                reg_wdata_o = {16'h0, mem_rdata_i[31:16]};
                            end
                        end
                        default: begin
                            reg_wdata_o = `ZeroWord;
                        end
                    endcase
                end

                `INST_TYPE_S: begin
                    mem_req_o   = `RIB_REQ;
                    mem_we_o    = `WriteEnable;
                    mem_waddr_o = op1_i + op2_i;

                    case (funct3)
                        `INST_SB: begin
                            // 针对不同字节位置，设置对应的掩码和数据
                            case (mem_waddr_index)
                                2'b00: begin
                                    mem_wmask_o = 4'b0001;  // 只写最低字节
                                    mem_wdata_o = {24'b0, reg2_rdata_i[7:0]};
                                end
                                2'b01: begin
                                    mem_wmask_o = 4'b0010;  // 只写次低字节
                                    mem_wdata_o = {16'b0, reg2_rdata_i[7:0], 8'b0};
                                end
                                2'b10: begin
                                    mem_wmask_o = 4'b0100;  // 只写次高字节
                                    mem_wdata_o = {8'b0, reg2_rdata_i[7:0], 16'b0};
                                end
                                default: begin
                                    mem_wmask_o = 4'b1000;  // 只写最高字节
                                    mem_wdata_o = {reg2_rdata_i[7:0], 24'b0};
                                end
                            endcase
                        end
                        `INST_SH: begin
                            // 针对半字写入，设置对应的掩码和数据
                            if (mem_waddr_index == 2'b00) begin
                                mem_wmask_o = 4'b0011;  // 写入低两个字节
                                mem_wdata_o = {16'b0, reg2_rdata_i[15:0]};
                            end else begin
                                mem_wmask_o = 4'b1100;  // 写入高两个字节
                                mem_wdata_o = {reg2_rdata_i[15:0], 16'b0};
                            end
                        end
                        `INST_SW: begin
                            mem_wmask_o = 4'b1111;  // 写入所有四个字节
                            mem_wdata_o = reg2_rdata_i;
                        end
                        default: begin
                            mem_wmask_o = 4'b0000;  // 默认不写入
                            mem_wdata_o = `ZeroWord;
                        end
                    endcase
                end

                default: begin
                    // 非内存指令
                end
            endcase
        end
    end

endmodule
