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

// 加载存储单元 - 双发射版本，单独处理一条访存指令
module exu_lsu #(
    // AXI4总线参数 - 适配双发射架构
    parameter C_M_AXI_ID_WIDTH     = `BUS_ID_WIDTH,      // 使用全局配置的ID宽度
    parameter C_M_AXI_ADDR_WIDTH   = `BUS_ADDR_WIDTH,    // 使用全局配置的地址宽度
    parameter C_M_AXI_DATA_WIDTH   = 32,                 // LSU仍然使用32位数据宽度（单字节/半字/字访问）
    parameter C_M_AXI_AWUSER_WIDTH = 1,
    parameter C_M_AXI_ARUSER_WIDTH = 1,
    parameter C_M_AXI_WUSER_WIDTH  = 1,
    parameter C_M_AXI_RUSER_WIDTH  = 1,
    parameter C_M_AXI_BUSER_WIDTH  = 1,
    parameter UNIT_ID              = 0                   // LSU单元ID：0或1，用于区分两个LSU
)(
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire stall_i,
    input wire flush_i,
    input wire int_assert_i,

    // 访存请求信号
    input wire req_mem_i,
    input wire mem_op_lb_i,
    input wire mem_op_lh_i,
    input wire mem_op_lw_i,
    input wire mem_op_lbu_i,
    input wire mem_op_lhu_i,
    input wire mem_op_load_i,
    input wire mem_op_store_i,
    input wire [4:0] rd_addr_i,

    // 访存地址和数据
    input wire [31:0] mem_addr_i,
    input wire [31:0] mem_wdata_i,
    input wire [ 3:0] mem_wmask_i,

    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,
    input wire reg_we_i,
    input wire wb_ready_i,

    // 访存阻塞和忙信号输出
    output wire mem_stall_o,
    output wire mem_busy_o,

    // 寄存器写回接口 - 输出到WBU
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,

    // AXI Master接口
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

    // 内部信号定义 - 增强版本支持双发射优化
    wire [1:0] mem_addr_index;
    wire valid_op;
    wire read_req_valid;
    wire write_req_valid;
    wire is_load_op = mem_op_load_i;
    wire is_store_op = mem_op_store_i;
    wire [C_M_AXI_DATA_WIDTH-1:0] axi_read_data;

    // FIFO相关参数定义 - 增大深度支持更好的双发射性能
    localparam FIFO_DEPTH = 8;  // 增加到8以支持更多并发请求
    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);
    
    // ===================================================================
    // 增强功能：连续访存FIFO缓冲和RAW前递优化
    // ===================================================================
    
    // FIFO条目结构 - 增强版本
    typedef struct packed {
        logic                       valid;
        logic                       is_load;
        logic                       is_store;
        logic [31:0]               addr;
        logic [31:0]               wdata;        // store数据
        logic [3:0]                wmask;        // byte mask for store
        logic [4:0]                rd_addr;     // 目标寄存器地址
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
        logic                       reg_we;
        logic                       wb_ready;
        logic [2:0]                op_type;     // 操作类型：lb/lh/lw/lbu/lhu/sb/sh/sw
        logic                       mem_completed; // 内存操作是否完成
        logic                       forwarded;     // 是否通过前递获得数据
        logic [31:0]               result_data;   // load结果或前递数据
    } mem_fifo_entry_t;
    
    // FIFO存储
    mem_fifo_entry_t mem_fifo[0:FIFO_DEPTH-1];
    logic [FIFO_PTR_WIDTH-1:0] fifo_head, fifo_tail;
    logic [FIFO_PTR_WIDTH:0] fifo_count;
    logic fifo_full, fifo_empty;
    
    // 当前请求的操作类型编码
    wire [2:0] current_op_type;
    assign current_op_type = mem_op_lb_i  ? 3'b000 :
                            mem_op_lh_i  ? 3'b001 :
                            mem_op_lw_i  ? 3'b010 :
                            mem_op_lbu_i ? 3'b011 :
                            mem_op_lhu_i ? 3'b100 :
                            mem_op_store_i ? (mem_wmask_i == 4'b0001 || mem_wmask_i == 4'b0010 || 
                                             mem_wmask_i == 4'b0100 || mem_wmask_i == 4'b1000) ? 3'b101 :  // SB
                                            (mem_wmask_i == 4'b0011 || mem_wmask_i == 4'b1100) ? 3'b110 :  // SH
                                            3'b111 : 3'b000;  // SW
    
    // RAW相关性检测信号
    logic raw_detected;
    logic [31:0] forward_data;
    logic forward_available;
    
    // FIFO状态
    assign fifo_full = (fifo_count >= FIFO_DEPTH);
    assign fifo_empty = (fifo_count == 0);
    
    // ===================================================================
    // RAW相关性检测和前递逻辑
    // ===================================================================
    
    // 检查当前load请求是否与FIFO中的store操作存在RAW相关
    always_comb begin
        raw_detected = 1'b0;
        forward_data = 32'b0;
        forward_available = 1'b0;
        
        if (valid_op && is_load_op) begin
            // 检查FIFO中所有有效的store操作
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                if (mem_fifo[i].valid && mem_fifo[i].is_store && 
                    !mem_fifo[i].mem_completed) begin
                    
                    // 检查地址重叠
                    if (check_address_overlap(mem_addr_i, current_op_type, 
                                            mem_fifo[i].addr, mem_fifo[i].op_type, 
                                            mem_fifo[i].wmask)) begin
                        raw_detected = 1'b1;
                        forward_data = generate_forward_data(mem_addr_i, current_op_type,
                                                            mem_fifo[i].addr, mem_fifo[i].wdata,
                                                            mem_fifo[i].wmask);
                        forward_available = 1'b1;
                        break;  // 找到第一个匹配的store即可
                    end
                end
            end
        end
    end
    
    // ===================================================================
    // Load/Store并行处理逻辑
    // ===================================================================
    
    // 查找FIFO中下一个可以处理的操作
    logic [FIFO_PTR_WIDTH-1:0] next_load_idx, next_store_idx;
    logic load_ready, store_ready;
    
    always_comb begin
        load_ready = 1'b0;
        store_ready = 1'b0;
        next_load_idx = '0;
        next_store_idx = '0;
        
        // 按FIFO顺序查找可处理的操作
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            logic [FIFO_PTR_WIDTH-1:0] idx = (fifo_head + i) % FIFO_DEPTH;
            
            if (mem_fifo[idx].valid && !mem_fifo[idx].mem_completed && !mem_fifo[idx].forwarded) begin
                if (mem_fifo[idx].is_load && !load_ready) begin
                    load_ready = 1'b1;
                    next_load_idx = idx;
                end else if (mem_fifo[idx].is_store && !store_ready) begin
                    store_ready = 1'b1;
                    next_store_idx = idx;
                end
            end
        end
    end

    // 寄存器信号定义
    reg [FIFO_PTR_WIDTH-1:0] read_fifo_wr_ptr;
    reg [FIFO_PTR_WIDTH-1:0] read_fifo_rd_ptr;
    reg [FIFO_DEPTH-1:0] read_fifo_valid;
    reg [1:0] read_fifo_op;
    reg [1:0] write_fifo_op;

    reg [FIFO_PTR_WIDTH-1:0] write_fifo_wr_ptr;
    reg [FIFO_PTR_WIDTH-1:0] write_fifo_rd_ptr;
    reg [FIFO_DEPTH-1:0] write_fifo_valid;

    wire axi_rready;
    wire axi_bready;

    // 读取请求FIFO数组
    reg read_fifo_mem_op_lb[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lh[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lw[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lbu[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lhu[0:FIFO_DEPTH-1];
    reg [4:0] read_fifo_rd_addr[0:FIFO_DEPTH-1];
    reg [1:0] read_fifo_mem_addr_index[0:FIFO_DEPTH-1];
    reg [`COMMIT_ID_WIDTH-1:0] read_fifo_commit_id[0:FIFO_DEPTH-1];

    // 写请求FIFO数组
    reg [31:0] write_fifo_data[0:FIFO_DEPTH-1];
    reg [3:0] write_fifo_strb[0:FIFO_DEPTH-1];

    // 输出寄存器
    reg [31:0] current_reg_wdata_r;
    reg reg_write_valid_r;
    reg [4:0] reg_waddr_r;
    reg [`COMMIT_ID_WIDTH-1:0] current_commit_id_r;

    // 读写FIFO状态信号
    wire read_fifo_empty;
    wire read_fifo_full;
    wire write_fifo_empty;
    wire write_fifo_full;

    // FIFO状态计算
    assign read_fifo_empty = (read_fifo_wr_ptr == read_fifo_rd_ptr) && (read_fifo_valid[read_fifo_rd_ptr] == 1'b0);
    assign read_fifo_full = (read_fifo_wr_ptr == read_fifo_rd_ptr) && (read_fifo_valid[read_fifo_wr_ptr] == 1'b1);
    assign write_fifo_empty = (write_fifo_wr_ptr == write_fifo_rd_ptr) && (write_fifo_valid[write_fifo_rd_ptr] == 1'b0);
    assign write_fifo_full = (write_fifo_wr_ptr == write_fifo_rd_ptr) && (write_fifo_valid[write_fifo_wr_ptr] == 1'b1);

    // 生成请求有效信号
    assign mem_addr_index = mem_addr_i[1:0];
    assign valid_op = req_mem_i && !int_assert_i && !flush_i;
    assign read_req_valid = valid_op && is_load_op && !stall_i;
    assign write_req_valid = valid_op && is_store_op && !stall_i;

    // 同周期响应判断
    wire same_cycle_response;
    assign same_cycle_response = (read_fifo_empty & M_AXI_ARVALID & M_AXI_ARREADY & M_AXI_RVALID & axi_rready);

    // 访存阻塞信号
    wire read_stall;
    wire write_stall;
    assign read_stall = read_req_valid & (read_fifo_full | ~M_AXI_ARREADY);
    assign write_stall = write_req_valid & (write_fifo_full | ~M_AXI_AWREADY);
    assign mem_stall_o = read_stall | write_stall;
    assign mem_busy_o = !write_fifo_empty;

    // 读请求FIFO操作
    wire read_fifo_wr_en;
    wire read_fifo_rd_en;

    // 写请求FIFO操作
    wire write_fifo_wr_en;
    wire write_fifo_rd_en;

    // 读控制信号逻辑
    assign axi_rready = 1'b1;
    assign axi_bready = 1'b1;

    // 读FIFO写入使能
    assign read_fifo_wr_en = (M_AXI_ARVALID & M_AXI_ARREADY) & (~(M_AXI_RVALID | read_fifo_full) | ~read_fifo_empty);

    // 读FIFO读取使能
    assign read_fifo_rd_en = M_AXI_RVALID & axi_rready & ~read_fifo_empty;

    // 写FIFO写入使能 - 修正逻辑
    assign write_fifo_wr_en = write_req_valid & M_AXI_AWREADY & ~write_fifo_full;

    // 写FIFO读取使能 - 修正逻辑  
    assign write_fifo_rd_en = ~write_fifo_empty & M_AXI_WREADY;

    // FIFO操作码生成
    assign read_fifo_op = {read_fifo_wr_en, read_fifo_rd_en};
    assign write_fifo_op = {write_fifo_wr_en, write_fifo_rd_en};

    // 直接从AXI读取数据
    assign axi_read_data = M_AXI_RDATA;

    // 从FIFO中获取当前处理的请求信息
    wire [1:0] curr_mem_addr_index = same_cycle_response ? mem_addr_index : read_fifo_mem_addr_index[read_fifo_rd_ptr];
    wire curr_mem_op_lb = same_cycle_response ? mem_op_lb_i : read_fifo_mem_op_lb[read_fifo_rd_ptr];
    wire curr_mem_op_lh = same_cycle_response ? mem_op_lh_i : read_fifo_mem_op_lh[read_fifo_rd_ptr];
    wire curr_mem_op_lw = same_cycle_response ? mem_op_lw_i : read_fifo_mem_op_lw[read_fifo_rd_ptr];
    wire curr_mem_op_lbu = same_cycle_response ? mem_op_lbu_i : read_fifo_mem_op_lbu[read_fifo_rd_ptr];
    wire curr_mem_op_lhu = same_cycle_response ? mem_op_lhu_i : read_fifo_mem_op_lhu[read_fifo_rd_ptr];
    wire [4:0] curr_rd_addr = same_cycle_response ? rd_addr_i : read_fifo_rd_addr[read_fifo_rd_ptr];
    wire [`COMMIT_ID_WIDTH-1:0] curr_commit_id = same_cycle_response ? commit_id_i : read_fifo_commit_id[read_fifo_rd_ptr];

    // 字节加载数据的选择逻辑
    wire [31:0] lb_data, lh_data, lw_data, lbu_data, lhu_data;
    wire [31:0] lb_byte0, lb_byte1, lb_byte2, lb_byte3;
    wire [31:0] lbu_byte0, lbu_byte1, lbu_byte2, lbu_byte3;
    wire [31:0] lh_low, lh_high, lhu_low, lhu_high;

    // 有符号字节加载
    assign lb_byte0 = {{24{axi_read_data[7]}}, axi_read_data[7:0]};
    assign lb_byte1 = {{24{axi_read_data[15]}}, axi_read_data[15:8]};
    assign lb_byte2 = {{24{axi_read_data[23]}}, axi_read_data[23:16]};
    assign lb_byte3 = {{24{axi_read_data[31]}}, axi_read_data[31:24]};

    // 无符号字节加载
    assign lbu_byte0 = {24'h0, axi_read_data[7:0]};
    assign lbu_byte1 = {24'h0, axi_read_data[15:8]};
    assign lbu_byte2 = {24'h0, axi_read_data[23:16]};
    assign lbu_byte3 = {24'h0, axi_read_data[31:24]};

    // 有符号半字加载
    assign lh_low = {{16{axi_read_data[15]}}, axi_read_data[15:0]};
    assign lh_high = {{16{axi_read_data[31]}}, axi_read_data[31:16]};

    // 无符号半字加载
    assign lhu_low = {16'h0, axi_read_data[15:0]};
    assign lhu_high = {16'h0, axi_read_data[31:16]};

    // 使用并行选择正确的字节/半字/字
    assign lb_data = ({32{curr_mem_addr_index == 2'b00}} & lb_byte0) |
                     ({32{curr_mem_addr_index == 2'b01}} & lb_byte1) |
                     ({32{curr_mem_addr_index == 2'b10}} & lb_byte2) |
                     ({32{curr_mem_addr_index == 2'b11}} & lb_byte3);

    assign lbu_data = ({32{curr_mem_addr_index == 2'b00}} & lbu_byte0) |
                      ({32{curr_mem_addr_index == 2'b01}} & lbu_byte1) |
                      ({32{curr_mem_addr_index == 2'b10}} & lbu_byte2) |
                      ({32{curr_mem_addr_index == 2'b11}} & lbu_byte3);

    assign lh_data = ({32{curr_mem_addr_index[1] == 1'b0}} & lh_low) |
                     ({32{curr_mem_addr_index[1] == 1'b1}} & lh_high);

    assign lhu_data = ({32{curr_mem_addr_index[1] == 1'b0}} & lhu_low) |
                      ({32{curr_mem_addr_index[1] == 1'b1}} & lhu_high);

    assign lw_data = axi_read_data;

    // 最终加载数据选择
    wire [31:0] load_data = ({32{curr_mem_op_lb}} & lb_data) |
                           ({32{curr_mem_op_lh}} & lh_data) |
                           ({32{curr_mem_op_lw}} & lw_data) |
                           ({32{curr_mem_op_lbu}} & lbu_data) |
                           ({32{curr_mem_op_lhu}} & lhu_data);

    // AXI ID生成 - 基于LSU单元ID
    wire [C_M_AXI_ID_WIDTH-1:0] base_axi_id = {{(C_M_AXI_ID_WIDTH-1){1'b0}}, UNIT_ID[0]};
    
    // AXI接口连接
    assign M_AXI_AWID = base_axi_id;
    assign M_AXI_AWADDR = mem_addr_i;
    assign M_AXI_AWLEN = 8'b0;
    assign M_AXI_AWSIZE = 3'b010;
    assign M_AXI_AWBURST = 2'b01;
    assign M_AXI_AWLOCK = 1'b0;
    assign M_AXI_AWCACHE = 4'b0;
    assign M_AXI_AWPROT = 3'b0;
    assign M_AXI_AWQOS = 4'b0;
    assign M_AXI_AWUSER = {C_M_AXI_AWUSER_WIDTH{1'b0}};
    assign M_AXI_AWVALID = write_req_valid;

    // AXI写数据通道改进
    assign M_AXI_WDATA = write_fifo_empty ? mem_wdata_i : write_fifo_data[write_fifo_rd_ptr];
    assign M_AXI_WSTRB = write_fifo_empty ? mem_wmask_i : write_fifo_strb[write_fifo_rd_ptr];
    assign M_AXI_WLAST = 1'b1;
    assign M_AXI_WUSER = {C_M_AXI_WUSER_WIDTH{1'b0}};
    assign M_AXI_WVALID = write_req_valid | ~write_fifo_empty;

    assign M_AXI_BREADY = axi_bready;

    assign M_AXI_ARID = base_axi_id;
    assign M_AXI_ARADDR = mem_addr_i;
    assign M_AXI_ARLEN = 8'b0;
    assign M_AXI_ARSIZE = 3'b010;
    assign M_AXI_ARBURST = 2'b01;
    assign M_AXI_ARLOCK = 1'b0;
    assign M_AXI_ARCACHE = 4'b0;
    assign M_AXI_ARPROT = 3'b0;
    assign M_AXI_ARQOS = 4'b0;
    assign M_AXI_ARUSER = {C_M_AXI_ARUSER_WIDTH{1'b0}};
    assign M_AXI_ARVALID = read_req_valid;

    assign M_AXI_RREADY = axi_rready;

    // 写回逻辑
    assign reg_wdata_o = load_data;
    assign reg_we_o = valid_op && is_load_op && M_AXI_RVALID && reg_we_i;
    assign reg_waddr_o = curr_rd_addr;
    assign commit_id_o = curr_commit_id;

    // 读FIFO状态更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_fifo_wr_ptr <= '0;
            read_fifo_rd_ptr <= '0;
            read_fifo_valid <= '0;
        end else if (flush_i) begin
            read_fifo_wr_ptr <= '0;
            read_fifo_rd_ptr <= '0;
            read_fifo_valid <= '0;
        end else begin
            case (read_fifo_op)
                2'b01: begin // 只读
                    read_fifo_rd_ptr <= (read_fifo_rd_ptr + 1) % FIFO_DEPTH;
                    read_fifo_valid[read_fifo_rd_ptr] <= 1'b0;
                end
                2'b10: begin // 只写
                    read_fifo_wr_ptr <= (read_fifo_wr_ptr + 1) % FIFO_DEPTH;
                    read_fifo_valid[read_fifo_wr_ptr] <= 1'b1;
                    // 保存请求信息到FIFO
                    read_fifo_mem_op_lb[read_fifo_wr_ptr] <= mem_op_lb_i;
                    read_fifo_mem_op_lh[read_fifo_wr_ptr] <= mem_op_lh_i;
                    read_fifo_mem_op_lw[read_fifo_wr_ptr] <= mem_op_lw_i;
                    read_fifo_mem_op_lbu[read_fifo_wr_ptr] <= mem_op_lbu_i;
                    read_fifo_mem_op_lhu[read_fifo_wr_ptr] <= mem_op_lhu_i;
                    read_fifo_rd_addr[read_fifo_wr_ptr] <= rd_addr_i;
                    read_fifo_mem_addr_index[read_fifo_wr_ptr] <= mem_addr_index;
                    read_fifo_commit_id[read_fifo_wr_ptr] <= commit_id_i;
                end
                2'b11: begin // 同时读写
                    read_fifo_wr_ptr <= (read_fifo_wr_ptr + 1) % FIFO_DEPTH;
                    read_fifo_rd_ptr <= (read_fifo_rd_ptr + 1) % FIFO_DEPTH;
                    read_fifo_valid[read_fifo_wr_ptr] <= 1'b1;
                    read_fifo_valid[read_fifo_rd_ptr] <= 1'b0;
                    // 保存新请求信息到FIFO
                    read_fifo_mem_op_lb[read_fifo_wr_ptr] <= mem_op_lb_i;
                    read_fifo_mem_op_lh[read_fifo_wr_ptr] <= mem_op_lh_i;
                    read_fifo_mem_op_lw[read_fifo_wr_ptr] <= mem_op_lw_i;
                    read_fifo_mem_op_lbu[read_fifo_wr_ptr] <= mem_op_lbu_i;
                    read_fifo_mem_op_lhu[read_fifo_wr_ptr] <= mem_op_lhu_i;
                    read_fifo_rd_addr[read_fifo_wr_ptr] <= rd_addr_i;
                    read_fifo_mem_addr_index[read_fifo_wr_ptr] <= mem_addr_index;
                    read_fifo_commit_id[read_fifo_wr_ptr] <= commit_id_i;
                end
                default: begin // 2'b00 - 无操作
                    // 保持当前状态
                end
            endcase
        end
    end

    // 写FIFO状态更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_fifo_wr_ptr <= '0;
            write_fifo_rd_ptr <= '0;
            write_fifo_valid <= '0;
        end else if (flush_i) begin
            write_fifo_wr_ptr <= '0;
            write_fifo_rd_ptr <= '0;
            write_fifo_valid <= '0;
        end else begin
            case (write_fifo_op)
                2'b01: begin // 只读
                    write_fifo_rd_ptr <= (write_fifo_rd_ptr + 1) % FIFO_DEPTH;
                    write_fifo_valid[write_fifo_rd_ptr] <= 1'b0;
                end
                2'b10: begin // 只写
                    write_fifo_wr_ptr <= (write_fifo_wr_ptr + 1) % FIFO_DEPTH;
                    write_fifo_valid[write_fifo_wr_ptr] <= 1'b1;
                    // 保存写数据到FIFO
                    write_fifo_data[write_fifo_wr_ptr] <= mem_wdata_i;
                    write_fifo_strb[write_fifo_wr_ptr] <= mem_wmask_i;
                end
                2'b11: begin // 同时读写
                    write_fifo_wr_ptr <= (write_fifo_wr_ptr + 1) % FIFO_DEPTH;
                    write_fifo_rd_ptr <= (write_fifo_rd_ptr + 1) % FIFO_DEPTH;
                    write_fifo_valid[write_fifo_wr_ptr] <= 1'b1;
                    write_fifo_valid[write_fifo_rd_ptr] <= 1'b0;
                    // 保存新写数据到FIFO
                    write_fifo_data[write_fifo_wr_ptr] <= mem_wdata_i;
                    write_fifo_strb[write_fifo_wr_ptr] <= mem_wmask_i;
                end
                default: begin // 2'b00 - 无操作
                    // 保持当前状态
                end
    // ===================================================================
    // 主FIFO管理和优化逻辑
    // ===================================================================
    
    // FIFO插入逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位FIFO
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                mem_fifo[i] <= '0;
            end
            fifo_head <= '0;
            fifo_tail <= '0;
            fifo_count <= '0;
        end else if (flush_i) begin
            // 冲刷FIFO
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                mem_fifo[i] <= '0;
            end
            fifo_head <= '0;
            fifo_tail <= '0;
            fifo_count <= '0;
        end else begin
            // 插入新请求
            if (valid_op && !fifo_full) begin
                mem_fifo[fifo_tail].valid <= 1'b1;
                mem_fifo[fifo_tail].is_load <= is_load_op;
                mem_fifo[fifo_tail].is_store <= is_store_op;
                mem_fifo[fifo_tail].addr <= mem_addr_i;
                mem_fifo[fifo_tail].wdata <= mem_wdata_i;
                mem_fifo[fifo_tail].wmask <= mem_wmask_i;
                mem_fifo[fifo_tail].rd_addr <= rd_addr_i;
                mem_fifo[fifo_tail].commit_id <= commit_id_i;
                mem_fifo[fifo_tail].reg_we <= reg_we_i;
                mem_fifo[fifo_tail].wb_ready <= wb_ready_i;
                mem_fifo[fifo_tail].op_type <= current_op_type;
                mem_fifo[fifo_tail].mem_completed <= 1'b0;
                
                // 检查RAW前递
                if (is_load_op && raw_detected && forward_available) begin
                    mem_fifo[fifo_tail].forwarded <= 1'b1;
                    mem_fifo[fifo_tail].result_data <= forward_data;
                    mem_fifo[fifo_tail].mem_completed <= 1'b1;
                end else begin
                    mem_fifo[fifo_tail].forwarded <= 1'b0;
                    mem_fifo[fifo_tail].result_data <= 32'b0;
                end
                
                fifo_tail <= (fifo_tail + 1) % FIFO_DEPTH;
                fifo_count <= fifo_count + 1;
            end
            
            // 移除已完成的条目
            if (!fifo_empty && mem_fifo[fifo_head].valid && 
                mem_fifo[fifo_head].mem_completed && mem_fifo[fifo_head].wb_ready) begin
                mem_fifo[fifo_head].valid <= 1'b0;
                fifo_head <= (fifo_head + 1) % FIFO_DEPTH;
                fifo_count <= fifo_count - 1;
            end
        end
    end
    
    // Stall条件：FIFO满时阻塞新请求
    assign mem_stall_o = valid_op && fifo_full;
    
    // Busy条件：有未完成的store操作
    logic has_pending_store;
    always_comb begin
        has_pending_store = 1'b0;
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            if (mem_fifo[i].valid && mem_fifo[i].is_store && !mem_fifo[i].mem_completed) begin
                has_pending_store = 1'b1;
                break;
            end
        end
    end
    assign mem_busy_o = has_pending_store;
    
    // 写回接口：输出FIFO头部已完成的load操作结果
    assign reg_wdata_o = (!fifo_empty && mem_fifo[fifo_head].valid && 
                         mem_fifo[fifo_head].mem_completed && mem_fifo[fifo_head].is_load) ?
                         mem_fifo[fifo_head].result_data : 32'b0;
    assign reg_we_o = (!fifo_empty && mem_fifo[fifo_head].valid && 
                      mem_fifo[fifo_head].mem_completed && mem_fifo[fifo_head].is_load &&
                      mem_fifo[fifo_head].reg_we);
    assign reg_waddr_o = mem_fifo[fifo_head].rd_addr;
    assign commit_id_o = mem_fifo[fifo_head].commit_id;

    // ===================================================================
    // 辅助函数定义
    // ===================================================================
    
    // 检查地址重叠
    function automatic logic check_address_overlap(
        input [31:0] addr1,
        input [2:0] op1_type,
        input [31:0] addr2,
        input [2:0] op2_type,
        input [3:0] mask2
    );
        logic [31:0] base1, base2;
        logic [2:0] size1, size2;
        
        // 计算访问范围
        case (op1_type)
            3'b000, 3'b011, 3'b101: begin // LB, LBU, SB
                base1 = addr1;
                size1 = 1;
            end
            3'b001, 3'b100, 3'b110: begin // LH, LHU, SH
                base1 = addr1 & ~32'h1;
                size1 = 2;
            end
            default: begin // LW, SW
                base1 = addr1 & ~32'h3;
                size1 = 4;
            end
        endcase
        
        case (op2_type)
            3'b000, 3'b011, 3'b101: begin // LB, LBU, SB
                base2 = addr2;
                size2 = 1;
            end
            3'b001, 3'b100, 3'b110: begin // LH, LHU, SH
                base2 = addr2 & ~32'h1;
                size2 = 2;
            end
            default: begin // LW, SW
                base2 = addr2 & ~32'h3;
                size2 = 4;
            end
        endcase
        
        // 检查重叠
        return (base1 < base2 + size2) && (base2 < base1 + size1);
    endfunction
    
    // 生成前递数据
    function automatic [31:0] generate_forward_data(
        input [31:0] load_addr,
        input [2:0] load_op_type,
        input [31:0] store_addr,
        input [31:0] store_data,
        input [3:0] store_mask
    );
        logic [31:0] result;
        logic [1:0] byte_offset;
        
        byte_offset = load_addr[1:0];
        
        case (load_op_type)
            3'b000: begin // LB
                case (byte_offset)
                    2'b00: result = {{24{store_data[7]}}, store_data[7:0]};
                    2'b01: result = {{24{store_data[15]}}, store_data[15:8]};
                    2'b10: result = {{24{store_data[23]}}, store_data[23:16]};
                    2'b11: result = {{24{store_data[31]}}, store_data[31:24]};
                endcase
            end
            3'b011: begin // LBU
                case (byte_offset)
                    2'b00: result = {24'b0, store_data[7:0]};
                    2'b01: result = {24'b0, store_data[15:8]};
                    2'b10: result = {24'b0, store_data[23:16]};
                    2'b11: result = {24'b0, store_data[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (byte_offset[1])
                    1'b0: result = {{16{store_data[15]}}, store_data[15:0]};
                    1'b1: result = {{16{store_data[31]}}, store_data[31:16]};
                endcase
            end
            3'b100: begin // LHU
                case (byte_offset[1])
                    1'b0: result = {16'b0, store_data[15:0]};
                    1'b1: result = {16'b0, store_data[31:16]};
                endcase
            end
            default: result = store_data; // LW
        endcase
        
        return result;
    endfunction

endmodule
