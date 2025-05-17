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
module agu (    input wire rst,

    input wire req_mem_i,
    input wire[31:0] mem_op1_i,
    input wire[31:0] mem_op2_i,
    input wire[31:0] mem_rs2_data_i,
    input wire mem_op_lb_i,
    input wire mem_op_lh_i,
    input wire mem_op_lw_i,
    input wire mem_op_lbu_i,
    input wire mem_op_lhu_i,
    input wire mem_op_sb_i,
    input wire mem_op_sh_i,
    input wire mem_op_sw_i,
    input wire [4:0] rd_addr_i,

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

    // 寄存器写回接口
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);    // 内部信号
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
        reg_wdata_o = `ZeroWord;
        reg_we_o    = `WriteDisable;
        reg_waddr_o = `ZeroWord;

        // 响应中断时不访问内存
        if (int_assert_i == `INT_ASSERT) begin
            mem_we_o  = `WriteDisable;
            mem_req_o = `RIB_NREQ;
            reg_we_o  = `WriteDisable; // 确保中断时不写回寄存器
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
                mem_raddr_o = mem_op1_i + mem_op2_i;  // 需要先读取用于部分写入
                reg_we_o    = `WriteDisable; // 存储指令不需要写回寄存器
                
                if (mem_op_sb_i) begin
                    // 字节存储
                    case (mem_addr_index)
                        2'b00:   mem_wdata_o = {mem_rdata_i[31:8], mem_rs2_data_i[7:0]};
                        2'b01:   mem_wdata_o = {mem_rdata_i[31:16], mem_rs2_data_i[7:0], mem_rdata_i[7:0]};
                        2'b10:   mem_wdata_o = {mem_rdata_i[31:24], mem_rs2_data_i[7:0], mem_rdata_i[15:0]};
                        default: mem_wdata_o = {mem_rs2_data_i[7:0], mem_rdata_i[23:0]};
                    endcase
                end else if (mem_op_sh_i) begin
                    // 半字存储
                    if (mem_addr_index == 2'b00) begin
                        mem_wdata_o = {mem_rdata_i[31:16], mem_rs2_data_i[15:0]};
                    end else begin
                        mem_wdata_o = {mem_rs2_data_i[15:0], mem_rdata_i[15:0]};
                    end
                end else if (mem_op_sw_i) begin
                    // 字存储
                    mem_wdata_o = mem_rs2_data_i;
                end
            end
        end
    end

endmodule




// // 地址生成单元 - 处理内存访问和相关寄存器操作
// module agu (
//     input wire rst,

//     // 来自dispatch模块的输入
//     input wire [ `BUS_ADDR_WIDTH-1:0] op1_i,
//     input wire [ `BUS_ADDR_WIDTH-1:0] op2_i,
//     input wire [ `REG_DATA_WIDTH-1:0] rs2_data_i,
//     input wire [4:0] rd_addr_i,
    
//     // 内存操作类型信号
//     input wire op_lb_i,
//     input wire op_lh_i,
//     input wire op_lw_i,
//     input wire op_lbu_i,
//     input wire op_lhu_i,
//     input wire op_sb_i,
//     input wire op_sh_i,
//     input wire op_sw_i,

//     // 内存数据输入
//     input wire [`BUS_DATA_WIDTH-1:0] mem_rdata_i,

//     // 中断信号
//     input wire int_assert_i,

//     // 内存接口输出
//     output reg [`BUS_DATA_WIDTH-1:0] mem_wdata_o,
//     output reg [`BUS_ADDR_WIDTH-1:0] mem_raddr_o,
//     output reg [`BUS_ADDR_WIDTH-1:0] mem_waddr_o,
//     output reg                       mem_we_o,
//     output reg                       mem_req_o,

//     // 寄存器写回接口
//     output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
//     output reg                       reg_we_o,
//     output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o
// );    


// // 内部信号
//     wire [1:0] mem_raddr_index;
//     wire [1:0] mem_waddr_index;

//     // 计算内存访问的字节索引
//     assign mem_raddr_index = (op1_i + op2_i) & 2'b11;
//     assign mem_waddr_index = (op1_i + op2_i) & 2'b11;

//     // AGU逻辑
//     always @(*) begin
//         // 默认值
//         mem_wdata_o = `ZeroWord;
//         mem_raddr_o = `ZeroWord;
//         mem_waddr_o = `ZeroWord;
//         mem_we_o    = `WriteDisable;
//         mem_req_o   = `RIB_NREQ;
//         reg_wdata_o = `ZeroWord;
//         reg_we_o    = `WriteDisable;
//         reg_waddr_o = `ZeroWord;

//         // 响应中断时不访问内存
//         if (int_assert_i == `INT_ASSERT) begin
//             mem_we_o  = `WriteDisable;
//             mem_req_o = `RIB_NREQ;
//         end else begin
//             // 处理内存读写请求
//             if (op_lb_i || op_lh_i || op_lw_i || op_lbu_i || op_lhu_i) begin
//                 mem_req_o   = `RIB_REQ;
//                 mem_raddr_o = op1_i + op2_i;
//                 reg_we_o    = `WriteEnable;
//                 reg_waddr_o = rd_addr_i;  // 从指令中提取目标寄存器地址

//                 // 根据操作类型选择数据
//                 case ({op_lb_i, op_lh_i, op_lw_i, op_lbu_i, op_lhu_i})
//                     5'b10000: begin // LB
//                         case (mem_raddr_index)
//                             2'b00:   reg_wdata_o = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
//                             2'b01:   reg_wdata_o = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
//                             2'b10:   reg_wdata_o = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
//                             default: reg_wdata_o = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
//                         endcase
//                     end
//                     5'b01000: begin // LH
//                         if (mem_raddr_index == 2'b0) begin
//                             reg_wdata_o = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
//                         end else begin
//                             reg_wdata_o = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
//                         end
//                     end
//                     5'b00100: begin // LW
//                         reg_wdata_o = mem_rdata_i;
//                     end
//                     5'b00010: begin // LBU
//                         case (mem_raddr_index)
//                             2'b00:   reg_wdata_o = {24'h0, mem_rdata_i[7:0]};
//                             2'b01:   reg_wdata_o = {24'h0, mem_rdata_i[15:8]};
//                             2'b10:   reg_wdata_o = {24'h0, mem_rdata_i[23:16]};
//                             default: reg_wdata_o = {24'h0, mem_rdata_i[31:24]};
//                         endcase
//                     end
//                     5'b00001: begin // LHU
//                         if (mem_raddr_index == 2'b0) begin
//                             reg_wdata_o = {16'h0, mem_rdata_i[15:0]};
//                         end else begin
//                             reg_wdata_o = {16'h0, mem_rdata_i[31:16]};
//                         end
//                     end
//                     default: begin
//                         reg_wdata_o = `ZeroWord;
//                     end
//                 endcase
//             end

//             if (op_sb_i || op_sh_i || op_sw_i) begin
//                 mem_req_o   = `RIB_REQ;
//                 mem_we_o    = `WriteEnable;
//                 mem_waddr_o = op1_i + op2_i;
//                 mem_raddr_o = op1_i + op2_i;

//                 // 根据操作类型选择数据
//                 case ({op_sb_i, op_sh_i, op_sw_i})
//                     3'b100: begin // SB
//                         case (mem_waddr_index)
//                             2'b00:   mem_wdata_o = {mem_rdata_i[31:8], rs2_data_i[7:0]};
//                             2'b01:   mem_wdata_o = {mem_rdata_i[31:16], rs2_data_i[7:0], mem_rdata_i[7:0]};
//                             2'b10:   mem_wdata_o = {mem_rdata_i[31:24], rs2_data_i[7:0], mem_rdata_i[15:0]};
//                             default: mem_wdata_o = {rs2_data_i[7:0], mem_rdata_i[23:0]};
//                         endcase
//                     end
//                     3'b010: begin // SH
//                         if (mem_waddr_index == 2'b00) begin
//                             mem_wdata_o = {mem_rdata_i[31:16], rs2_data_i[15:0]};
//                         end else begin
//                             mem_wdata_o = {rs2_data_i[15:0], mem_rdata_i[15:0]};
//                         end
//                     end
//                     3'b001: begin // SW
//                         mem_wdata_o = rs2_data_i;
//                     end
//                     default: begin
//                         mem_wdata_o = `ZeroWord;
//                     end
//                 endcase
//             end
//         end
//     end

// endmodule
