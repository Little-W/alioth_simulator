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

//指令发射控制单元
module icu (
    input wire clk,
    input wire rst_n,

    // from idu
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i,
    input wire                        inst1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_i,
    input wire                        inst1_csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_waddr_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_raddr_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,

    // from idu - 第二路
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_waddr_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_raddr_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    input wire                        is_raw,
    input wire                        reg_inst,
    input wire                        is_long_inst,
    
    // 指令发射控制输出 - 8 entry
    output reg                        entry_valid_o[7:0],
    output reg [`INST_ADDR_WIDTH-1:0] entry_inst_addr_o[7:0],
    output reg                        entry_reg_we_o[7:0],
    output reg [`REG_ADDR_WIDTH-1:0]  entry_reg_waddr_o[7:0],
    output reg [`REG_DATA_WIDTH-1:0]  entry_reg1_rdata_o[7:0],
    output reg [`REG_DATA_WIDTH-1:0]  entry_reg2_rdata_o[7:0],
    output reg                        entry_csr_we_o[7:0],
    output reg [`BUS_ADDR_WIDTH-1:0]  entry_csr_waddr_o[7:0],
    output reg [`BUS_ADDR_WIDTH-1:0]  entry_csr_raddr_o[7:0],
    output reg [31:0]                 entry_dec_imm_o[7:0],
    output reg [`DECINFO_WIDTH-1:0]   entry_dec_info_bus_o[7:0],
    
    // 寄存器文件接口
    output reg [`REG_ADDR_WIDTH-1:0]  reg1_raddr_o[7:0],
    output reg [`REG_ADDR_WIDTH-1:0]  reg2_raddr_o[7:0],
    input wire [`REG_DATA_WIDTH-1:0]  reg1_rdata_i[7:0],
    input wire [`REG_DATA_WIDTH-1:0]  reg2_rdata_i[7:0]
);

    // 指令队列状态
    reg [7:0] entry_busy;     // 标记每个entry是否被占用
    reg [2:0] issue_ptr;      // 指向下一个可发射的entry
    reg [2:0] dispatch_ptr;   // 指向下一个可分配的entry
    
    // 指令发射逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位逻辑
            entry_busy <= 8'b0;
            issue_ptr <= 3'b0;
            dispatch_ptr <= 3'b0;
            
            for (int i = 0; i < 8; i++) begin
                entry_valid_o[i] <= 1'b0;
                entry_inst_addr_o[i] <= 'b0;
                entry_reg_we_o[i] <= 1'b0;
                entry_reg_waddr_o[i] <= 'b0;
                entry_csr_we_o[i] <= 1'b0;
                entry_csr_waddr_o[i] <= 'b0;
                entry_csr_raddr_o[i] <= 'b0;
                entry_dec_imm_o[i] <= 32'b0;
                entry_dec_info_bus_o[i] <= 'b0;
                reg1_raddr_o[i] <= 'b0;
                reg2_raddr_o[i] <= 'b0;
            end
        end else begin
            // 指令发射控制逻辑
            
            // 1. 分配新的entry（最多2个，双发射）
            if (!is_raw && !is_long_inst) begin
                // 第一条指令分配
                if (!entry_busy[dispatch_ptr]) begin
                    // 分配第一条指令到entry
                    reg1_raddr_o[dispatch_ptr] <= inst1_reg1_raddr_i;
                    reg2_raddr_o[dispatch_ptr] <= inst1_reg2_raddr_i;
                    
                    entry_inst_addr_o[dispatch_ptr] <= inst1_addr_i;
                    entry_reg_we_o[dispatch_ptr] <= inst1_reg_we_i;
                    entry_reg_waddr_o[dispatch_ptr] <= inst1_reg_waddr_i;
                    entry_csr_we_o[dispatch_ptr] <= inst1_csr_we_i;
                    entry_csr_waddr_o[dispatch_ptr] <= inst1_csr_waddr_i;
                    entry_csr_raddr_o[dispatch_ptr] <= inst1_csr_raddr_i;
                    entry_dec_imm_o[dispatch_ptr] <= inst1_dec_imm_i;
                    entry_dec_info_bus_o[dispatch_ptr] <= inst1_dec_info_bus_i;
                    
                    entry_busy[dispatch_ptr] <= 1'b1;
                    dispatch_ptr <= dispatch_ptr + 1;
                    
                    // 第二条指令分配（如果可以）
                    if (!entry_busy[(dispatch_ptr + 1) % 8] && reg_inst) begin
                        reg1_raddr_o[(dispatch_ptr + 1) % 8] <= inst2_reg1_raddr_i;
                        reg2_raddr_o[(dispatch_ptr + 1) % 8] <= inst2_reg2_raddr_i;
                        
                        entry_inst_addr_o[(dispatch_ptr + 1) % 8] <= inst2_addr_i;
                        entry_reg_we_o[(dispatch_ptr + 1) % 8] <= inst2_reg_we_i;
                        entry_reg_waddr_o[(dispatch_ptr + 1) % 8] <= inst2_reg_waddr_i;
                        entry_csr_we_o[(dispatch_ptr + 1) % 8] <= inst2_csr_we_i;
                        entry_csr_waddr_o[(dispatch_ptr + 1) % 8] <= inst2_csr_waddr_i;
                        entry_csr_raddr_o[(dispatch_ptr + 1) % 8] <= inst2_csr_raddr_i;
                        entry_dec_imm_o[(dispatch_ptr + 1) % 8] <= inst2_dec_imm_i;
                        entry_dec_info_bus_o[(dispatch_ptr + 1) % 8] <= inst2_dec_info_bus_i;
                        
                        entry_busy[(dispatch_ptr + 1) % 8] <= 1'b1;
                        dispatch_ptr <= (dispatch_ptr + 2) % 8;
                    end
                end
            end
            
            // 2. 处理寄存器读取数据
            for (int i = 0; i < 8; i++) begin
                if (entry_busy[i]) begin
                    entry_reg1_rdata_o[i] <= reg1_rdata_i[i];
                    entry_reg2_rdata_o[i] <= reg2_rdata_i[i];
                end
            end
            
            // 3. 发射指令（设置valid信号）- 支持双发射
            for (int i = 0; i < 8; i++) begin
                entry_valid_o[i] <= 1'b0; // 默认所有entry无效
            end
            
            // 尝试同时发射两条指令
            if (entry_busy[issue_ptr]) begin
                // 发射第一条指令
                entry_valid_o[issue_ptr] <= 1'b1;
                entry_busy[issue_ptr] <= 1'b0;  // 发射后释放entry
                
                // 检查是否可以发射第二条指令
                if (entry_busy[(issue_ptr + 1) % 8]) begin
                    entry_valid_o[(issue_ptr + 1) % 8] <= 1'b1;
                    entry_busy[(issue_ptr + 1) % 8] <= 1'b0;
                    issue_ptr <= (issue_ptr + 2) % 8; // 跳过两个entry
                end else begin
                    issue_ptr <= (issue_ptr + 1) % 8; // 只跳过一个entry
                end
            end else if (entry_busy[(issue_ptr + 1) % 8]) begin
                // 只有第二个位置有指令
                entry_valid_o[(issue_ptr + 1) % 8] <= 1'b1;
                entry_busy[(issue_ptr + 1) % 8] <= 1'b0;
                issue_ptr <= (issue_ptr + 2) % 8;
            end
        end
    end

endmodule