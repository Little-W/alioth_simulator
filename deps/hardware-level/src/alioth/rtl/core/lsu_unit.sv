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

// LSU基础单元模块 - 单次操作LSU，支持64位AXI接口
module lsu_unit #(
    parameter C_M_AXI_ID_WIDTH     = `BUS_ID_WIDTH,
    parameter C_M_AXI_ADDR_WIDTH   = `BUS_ADDR_WIDTH,
    parameter C_M_AXI_DATA_WIDTH   = `BUS_DATA_WIDTH,
    parameter C_M_AXI_AWUSER_WIDTH = 1,
    parameter C_M_AXI_ARUSER_WIDTH = 1,
    parameter C_M_AXI_WUSER_WIDTH  = 1,
    parameter C_M_AXI_RUSER_WIDTH  = 1,
    parameter C_M_AXI_BUSER_WIDTH  = 1
)(
    input wire clk,
    input wire rst_n,

    // 控制信号
    input wire int_assert_i,

    // 访存请求信号
    input wire                        req_mem_i,
    input wire                        mem_op_lb_i,
    input wire                        mem_op_lh_i,
    input wire                        mem_op_lw_i,
    input wire                        mem_op_lbu_i,
    input wire                        mem_op_lhu_i,
    input wire                        mem_op_load_i,
    input wire                        mem_op_store_i,
    input wire [                 4:0] rd_addr_i,

    // 访存地址和数据
    input wire [                31:0] mem_addr_i,
    input wire [                31:0] mem_wdata_i,
    input wire [                 3:0] mem_wmask_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 访存阻塞和忙信号输出
    output wire mem_stall_o,

    // 寄存器写回接口
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,

    // AXI Master接口 - 64位
    output wire [    C_M_AXI_ID_WIDTH-1:0] M_AXI_AWID,
    output wire [  C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output wire [                     7:0] M_AXI_AWLEN,
    output wire [                     2:0] M_AXI_AWSIZE,
    output wire [                     1:0] M_AXI_AWBURST,
    output wire                            M_AXI_AWLOCK,
    output wire [                     3:0] M_AXI_AWCACHE,
    output wire [                     2:0] M_AXI_AWPROT,
    output wire [                     3:0] M_AXI_AWQOS,
    output wire [C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
    output wire                            M_AXI_AWVALID,
    input  wire                            M_AXI_AWREADY,

    output wire [  C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                            M_AXI_WLAST,
    output wire [ C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER,
    output wire                            M_AXI_WVALID,
    input  wire                            M_AXI_WREADY,

    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [                    1:0] M_AXI_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                           M_AXI_BVALID,
    output wire                           M_AXI_BREADY,

    output wire [    C_M_AXI_ID_WIDTH-1:0] M_AXI_ARID,
    output wire [  C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                     7:0] M_AXI_ARLEN,
    output wire [                     2:0] M_AXI_ARSIZE,
    output wire [                     1:0] M_AXI_ARBURST,
    output wire                            M_AXI_ARLOCK,
    output wire [                     3:0] M_AXI_ARCACHE,
    output wire [                     2:0] M_AXI_ARPROT,
    output wire [                     3:0] M_AXI_ARQOS,
    output wire [C_M_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER,
    output wire                            M_AXI_ARVALID,
    input  wire                            M_AXI_ARREADY,

    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [ C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                    1:0] M_AXI_RRESP,
    input  wire                           M_AXI_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                           M_AXI_RVALID,
    output wire                           M_AXI_RREADY
);

    // ===================================================================
    // 内部信号定义
    // ===================================================================
    
    // 地址和数据处理
    wire [31:0] aligned_addr = {mem_addr_i[31:2], 2'b00};  // 4字节对齐地址
    wire [2:0] addr_offset = mem_addr_i[2:0];  // 地址偏移，扩展为3位以支持64位访问
    
    // 写数据处理 - 扩展到64位AXI总线
    wire [63:0] expanded_wdata;
    wire [7:0] expanded_wstrb;
    
    // 读数据处理
    wire [31:0] extracted_rdata;
    
    // 状态机
    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_READ_ADDR,
        STATE_READ_DATA,
        STATE_WRITE_ADDR,
        STATE_WRITE_DATA,
        STATE_WRITE_RESP
    } lsu_state_t;
    
    lsu_state_t current_state, next_state;
    
    // 内部寄存器
    reg [4:0] saved_rd_addr;
    reg [`COMMIT_ID_WIDTH-1:0] saved_commit_id;
    reg saved_mem_op_lb, saved_mem_op_lh, saved_mem_op_lw;
    reg saved_mem_op_lbu, saved_mem_op_lhu;
    reg [2:0] saved_addr_offset;  // 扩展为3位以支持64位访问
    
    // ===================================================================
    // 数据扩展逻辑 - 32位到64位AXI
    // ===================================================================
    
    // 写数据扩展：将32位数据重复到64位总线的两个位置
    assign expanded_wdata = {mem_wdata_i, mem_wdata_i};
    
    // 写掩码扩展：根据地址低位选择掩码位置
    assign expanded_wstrb = addr_offset[2] ? {mem_wmask_i, 4'b0000} : {4'b0000, mem_wmask_i};
    
    // 读数据提取：从64位数据中提取32位
    wire [31:0] rdata_low = M_AXI_RDATA[31:0];
    wire [31:0] rdata_high = M_AXI_RDATA[63:32];
    wire [31:0] raw_rdata = saved_addr_offset[2] ? rdata_high : rdata_low;
    
    // ===================================================================
    // 读数据处理逻辑
    // ===================================================================
    
    // 字节读取数据处理
    wire [31:0] lb_data, lh_data, lw_data, lbu_data, lhu_data;
    
    // 有符号字节加载
    wire [31:0] lb_byte0 = {{24{raw_rdata[7]}}, raw_rdata[7:0]};
    wire [31:0] lb_byte1 = {{24{raw_rdata[15]}}, raw_rdata[15:8]};
    wire [31:0] lb_byte2 = {{24{raw_rdata[23]}}, raw_rdata[23:16]};
    wire [31:0] lb_byte3 = {{24{raw_rdata[31]}}, raw_rdata[31:24]};
    
    assign lb_data = ({32{saved_addr_offset[1:0] == 2'b00}} & lb_byte0) |
                     ({32{saved_addr_offset[1:0] == 2'b01}} & lb_byte1) |
                     ({32{saved_addr_offset[1:0] == 2'b10}} & lb_byte2) |
                     ({32{saved_addr_offset[1:0] == 2'b11}} & lb_byte3);
    
    // 无符号字节加载
    wire [31:0] lbu_byte0 = {24'h0, raw_rdata[7:0]};
    wire [31:0] lbu_byte1 = {24'h0, raw_rdata[15:8]};
    wire [31:0] lbu_byte2 = {24'h0, raw_rdata[23:16]};
    wire [31:0] lbu_byte3 = {24'h0, raw_rdata[31:24]};
    
    assign lbu_data = ({32{saved_addr_offset[1:0] == 2'b00}} & lbu_byte0) |
                      ({32{saved_addr_offset[1:0] == 2'b01}} & lbu_byte1) |
                      ({32{saved_addr_offset[1:0] == 2'b10}} & lbu_byte2) |
                      ({32{saved_addr_offset[1:0] == 2'b11}} & lbu_byte3);
    
    // 有符号半字加载
    wire [31:0] lh_low = {{16{raw_rdata[15]}}, raw_rdata[15:0]};
    wire [31:0] lh_high = {{16{raw_rdata[31]}}, raw_rdata[31:16]};
    
    assign lh_data = saved_addr_offset[1] ? lh_high : lh_low;
    
    // 无符号半字加载
    wire [31:0] lhu_low = {16'h0, raw_rdata[15:0]};
    wire [31:0] lhu_high = {16'h0, raw_rdata[31:16]};
    
    assign lhu_data = saved_addr_offset[1] ? lhu_high : lhu_low;
    
    // 字加载
    assign lw_data = raw_rdata;
    
    // 最终读数据选择
    assign extracted_rdata = ({32{saved_mem_op_lb}} & lb_data) |
                            ({32{saved_mem_op_lbu}} & lbu_data) |
                            ({32{saved_mem_op_lh}} & lh_data) |
                            ({32{saved_mem_op_lhu}} & lhu_data) |
                            ({32{saved_mem_op_lw}} & lw_data);
    
    // ===================================================================
    // 状态机控制
    // ===================================================================
    
    // 状态转换
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // 状态转换逻辑
    always @(*) begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE: begin
                if (req_mem_i && !int_assert_i) begin
                    if (mem_op_load_i) begin
                        next_state = STATE_READ_ADDR;
                    end else if (mem_op_store_i) begin
                        next_state = STATE_WRITE_ADDR;
                    end
                end
            end
            
            STATE_READ_ADDR: begin
                if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                    next_state = STATE_READ_DATA;
                end
            end
            
            STATE_READ_DATA: begin
                if (M_AXI_RVALID && M_AXI_RREADY) begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_WRITE_ADDR: begin
                if (M_AXI_AWVALID && M_AXI_AWREADY) begin
                    next_state = STATE_WRITE_DATA;
                end
            end
            
            STATE_WRITE_DATA: begin
                if (M_AXI_WVALID && M_AXI_WREADY) begin
                    next_state = STATE_WRITE_RESP;
                end
            end
            
            STATE_WRITE_RESP: begin
                if (M_AXI_BVALID && M_AXI_BREADY) begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end
    
    // ===================================================================
    // 寄存器更新
    // ===================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_rd_addr <= 5'b0;
            saved_commit_id <= {`COMMIT_ID_WIDTH{1'b0}};
            saved_mem_op_lb <= 1'b0;
            saved_mem_op_lh <= 1'b0;
            saved_mem_op_lw <= 1'b0;
            saved_mem_op_lbu <= 1'b0;
            saved_mem_op_lhu <= 1'b0;
            saved_addr_offset <= 3'b0;
        end else if (current_state == STATE_IDLE && req_mem_i && !int_assert_i) begin
            saved_rd_addr <= rd_addr_i;
            saved_commit_id <= commit_id_i;
            saved_mem_op_lb <= mem_op_lb_i;
            saved_mem_op_lh <= mem_op_lh_i;
            saved_mem_op_lw <= mem_op_lw_i;
            saved_mem_op_lbu <= mem_op_lbu_i;
            saved_mem_op_lhu <= mem_op_lhu_i;
            saved_addr_offset <= addr_offset;
        end
    end
    
    // ===================================================================
    // AXI接口信号
    // ===================================================================
    
    // 写地址通道
    assign M_AXI_AWID = {C_M_AXI_ID_WIDTH{1'b0}};
    assign M_AXI_AWADDR = aligned_addr;
    assign M_AXI_AWLEN = 8'b0;  // 单次传输
    assign M_AXI_AWSIZE = 3'b011;  // 8字节（64位）
    assign M_AXI_AWBURST = 2'b01;  // INCR
    assign M_AXI_AWLOCK = 1'b0;
    assign M_AXI_AWCACHE = 4'b0010;
    assign M_AXI_AWPROT = 3'h0;
    assign M_AXI_AWQOS = 4'h0;
    assign M_AXI_AWUSER = {C_M_AXI_AWUSER_WIDTH{1'b1}};
    assign M_AXI_AWVALID = (current_state == STATE_WRITE_ADDR);
    
    // 写数据通道
    assign M_AXI_WDATA = expanded_wdata;
    assign M_AXI_WSTRB = expanded_wstrb;
    assign M_AXI_WLAST = 1'b1;
    assign M_AXI_WUSER = {C_M_AXI_WUSER_WIDTH{1'b0}};
    assign M_AXI_WVALID = (current_state == STATE_WRITE_DATA);
    
    // 写响应通道
    assign M_AXI_BREADY = (current_state == STATE_WRITE_RESP);
    
    // 读地址通道
    assign M_AXI_ARID = {C_M_AXI_ID_WIDTH{1'b0}};
    assign M_AXI_ARADDR = aligned_addr;
    assign M_AXI_ARLEN = 8'b0;  // 单次传输
    assign M_AXI_ARSIZE = 3'b011;  // 8字节（64位）
    assign M_AXI_ARBURST = 2'b01;  // INCR
    assign M_AXI_ARLOCK = 1'b0;
    assign M_AXI_ARCACHE = 4'b0010;
    assign M_AXI_ARPROT = 3'h0;
    assign M_AXI_ARQOS = 4'h0;
    assign M_AXI_ARUSER = {C_M_AXI_ARUSER_WIDTH{1'b1}};
    assign M_AXI_ARVALID = (current_state == STATE_READ_ADDR);
    
    // 读数据通道
    assign M_AXI_RREADY = (current_state == STATE_READ_DATA);
    
    // ===================================================================
    // 输出信号
    // ===================================================================
    
    // 阻塞信号
    assign mem_stall_o = (current_state != STATE_IDLE);
    
    // 寄存器写回信号
    assign reg_wdata_o = extracted_rdata;
    assign reg_we_o = (current_state == STATE_READ_DATA) && M_AXI_RVALID && M_AXI_RREADY;
    assign reg_waddr_o = saved_rd_addr;
    assign commit_id_o = saved_commit_id;

endmodule
