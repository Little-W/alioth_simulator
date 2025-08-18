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

// 地址生成单元 - 处理内存访问和相关寄存器操作
module exu_lsu #(
    // AXI接口参数
    parameter C_M_AXI_ID_WIDTH     = 3,
    parameter C_M_AXI_ADDR_WIDTH   = 32,
    parameter C_M_AXI_DATA_WIDTH   = 64,
    parameter C_M_AXI_AWUSER_WIDTH = 1,
    parameter C_M_AXI_ARUSER_WIDTH = 1,
    parameter C_M_AXI_WUSER_WIDTH  = 1,
    parameter C_M_AXI_RUSER_WIDTH  = 1,
    parameter C_M_AXI_BUSER_WIDTH  = 1
) (
    input wire clk,   // 时钟输入
    input wire rst_n,

    input wire req_mem_i,
    input wire mem_op_lb_i,
    input wire mem_op_lh_i,
    input wire mem_op_lw_i,
    input wire mem_op_lbu_i,
    input wire mem_op_lhu_i,

    input wire       mem_op_load_i,
    input wire       mem_op_store_i,
    input wire [4:0] rd_addr_i,

    // 新增的输入信号，直接提供写数据相关信号
    input wire [               31:0] mem_addr_i,
    input wire [`BUS_DATA_WIDTH-1:0] mem_wdata_i,

    input wire [7:0] mem_wmask_i,

    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 中断信号
    input wire int_assert_i,

    // 访存阻塞指示输出
    output wire mem_stall_o,

    // 新增：指示当前是否有未完成的传输事务
    output wire mem_busy_o,

    // 寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,

    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,

    // AXI Master接口
    // 写地址通道
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

    // 写数据通道
    output wire [  C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                            M_AXI_WLAST,
    output wire [ C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER,
    output wire                            M_AXI_WVALID,
    input  wire                            M_AXI_WREADY,

    // 写响应通道
    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [                    1:0] M_AXI_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                           M_AXI_BVALID,
    output wire                           M_AXI_BREADY,

    // 读地址通道
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

    // 读数据通道
    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [ C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                    1:0] M_AXI_RRESP,
    input  wire                           M_AXI_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                           M_AXI_RVALID,
    output wire                           M_AXI_RREADY
);
    // 内部信号定义
    wire [1:0] mem_addr_index;
    wire       valid_op;  // 有效操作信号（无中断且有内存请求）

    // 添加之前隐式声明的信号
    wire       read_req_valid;
    wire       write_req_valid;

    // 输入请求FIFO相关参数和信号
    localparam INPUT_FIFO_DEPTH = 4;
    localparam INPUT_FIFO_PTR_WIDTH = $clog2(INPUT_FIFO_DEPTH);
    localparam INPUT_FIFO_CNT_WIDTH = $clog2(INPUT_FIFO_DEPTH + 1);

    // 输入请求FIFO指针、计数器和状态
    reg [INPUT_FIFO_PTR_WIDTH-1:0] input_fifo_wr_ptr;
    reg [INPUT_FIFO_PTR_WIDTH-1:0] input_fifo_rd_ptr;
    reg [INPUT_FIFO_CNT_WIDTH-1:0] input_fifo_count;

    // 输入请求FIFO数组
    reg input_fifo_req_mem[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_lb[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_lh[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_lw[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_lbu[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_lhu[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_load[0:INPUT_FIFO_DEPTH-1];
    reg input_fifo_mem_op_store[0:INPUT_FIFO_DEPTH-1];
    reg [4:0] input_fifo_rd_addr[0:INPUT_FIFO_DEPTH-1];
    reg [31:0] input_fifo_mem_addr[0:INPUT_FIFO_DEPTH-1];
    reg [31:0] input_fifo_mem_wdata[0:INPUT_FIFO_DEPTH-1];
    reg [3:0] input_fifo_mem_wmask[0:INPUT_FIFO_DEPTH-1];
    reg [`COMMIT_ID_WIDTH-1:0] input_fifo_commit_id[0:INPUT_FIFO_DEPTH-1];

    // 输入FIFO状态信号
    wire input_fifo_empty;
    wire input_fifo_full;
    wire input_fifo_wr_en;
    wire input_fifo_rd_en;
    wire input_fifo_wr_allow;  // 允许写入
    wire input_fifo_rd_allow;  // 允许读取
    wire input_fifo_has_space_for_two;  // 新增：是否有空间容纳两个请求
    wire [                     1:0] input_fifo_op;        // FIFO操作码：00-无操作，01-只弹出，10-只推入，11-同时推入弹出

    // 输入FIFO状态计算 - 使用计数器
    assign input_fifo_empty = (input_fifo_count == {INPUT_FIFO_CNT_WIDTH{1'b0}});
    assign input_fifo_full = (input_fifo_count == INPUT_FIFO_DEPTH[INPUT_FIFO_CNT_WIDTH-1:0]);

    // 输入FIFO保护机制
    assign input_fifo_wr_allow = !input_fifo_full;
    assign input_fifo_rd_allow = !input_fifo_empty;
    assign input_fifo_has_space_for_two = (input_fifo_count <= INPUT_FIFO_DEPTH[INPUT_FIFO_CNT_WIDTH-1:0] - 2);

    // 输入源选择 - 如果FIFO非空则使用FIFO输出，否则使用直接输入
    wire effective_req_mem_i = input_fifo_empty ? req_mem_i : input_fifo_req_mem[input_fifo_rd_ptr];
    wire effective_mem_op_lb_i = input_fifo_empty ? mem_op_lb_i : input_fifo_mem_op_lb[input_fifo_rd_ptr];
    wire effective_mem_op_lh_i = input_fifo_empty ? mem_op_lh_i : input_fifo_mem_op_lh[input_fifo_rd_ptr];
    wire effective_mem_op_lw_i = input_fifo_empty ? mem_op_lw_i : input_fifo_mem_op_lw[input_fifo_rd_ptr];
    wire effective_mem_op_lbu_i = input_fifo_empty ? mem_op_lbu_i : input_fifo_mem_op_lbu[input_fifo_rd_ptr];
    wire effective_mem_op_lhu_i = input_fifo_empty ? mem_op_lhu_i : input_fifo_mem_op_lhu[input_fifo_rd_ptr];
    wire effective_mem_op_ldl_i = 1'b0;
    wire effective_mem_op_ldh_i = 1'b0;
    wire effective_mem_op_load_i = input_fifo_empty ? mem_op_load_i : input_fifo_mem_op_load[input_fifo_rd_ptr];
    wire effective_mem_op_store_i = input_fifo_empty ? mem_op_store_i : input_fifo_mem_op_store[input_fifo_rd_ptr];
    wire [4:0] effective_rd_addr_i = input_fifo_empty ? rd_addr_i : input_fifo_rd_addr[input_fifo_rd_ptr];
    wire [31:0] effective_mem_addr_i = input_fifo_empty ? mem_addr_i : input_fifo_mem_addr[input_fifo_rd_ptr];
    wire [31:0] effective_mem_wdata_i = input_fifo_empty ? mem_wdata_i : input_fifo_mem_wdata[input_fifo_rd_ptr];
    wire [3:0] effective_mem_wmask_i = input_fifo_empty ? mem_wmask_i : input_fifo_mem_wmask[input_fifo_rd_ptr];
    wire [`COMMIT_ID_WIDTH-1:0] effective_commit_id_i = input_fifo_empty ? commit_id_i : input_fifo_commit_id[input_fifo_rd_ptr];

    // 输入FIFO控制逻辑 - 简化为普通请求处理
    wire input_request_accepted = effective_req_mem_i && !int_assert_i &&
                                  ((effective_mem_op_load_i && M_AXI_ARVALID && M_AXI_ARREADY) ||
                                   (effective_mem_op_store_i && M_AXI_AWVALID && M_AXI_AWREADY));

    // 推入条件：所有指令都按32位指令处理
    wire should_push_input_fifo = req_mem_i && !int_assert_i && input_fifo_wr_allow && 
                                  (!input_request_accepted || !input_fifo_empty);

    // 输入FIFO写入使能
    assign input_fifo_wr_en = should_push_input_fifo;

    // 输入FIFO读取使能 - 当FIFO非空且能够处理请求时
    assign input_fifo_rd_en = input_fifo_rd_allow && input_request_accepted;

    // 输入FIFO操作码生成
    assign input_fifo_op    = {input_fifo_wr_en, input_fifo_rd_en};

    // 基本信号计算 - 使用effective信号
    assign mem_addr_index   = effective_mem_addr_i[1:0];
    assign valid_op         = effective_req_mem_i && !int_assert_i;

    // 直接使用输入的load和store信号 - 使用effective信号
    wire                       is_load_op = effective_mem_op_load_i;
    wire                       is_store_op = effective_mem_op_store_i;

    // AXI请求相关寄存器
    wire [C_M_AXI_DATA_WIDTH-1:0] axi_read_data;

    // FIFO相关参数定义
    localparam FIFO_DEPTH = 4;
    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);
    localparam FIFO_CNT_WIDTH = $clog2(FIFO_DEPTH + 1);

    // 读FIFO计数器和状态
    reg [FIFO_PTR_WIDTH-1:0] read_fifo_wr_ptr;
    reg [FIFO_PTR_WIDTH-1:0] read_fifo_rd_ptr;
    reg [FIFO_CNT_WIDTH-1:0] read_fifo_count;
    reg  [            1:0] read_fifo_op;    // FIFO操作码：00-无操作，01-只弹出，10-只推入，11-同时推入弹出

    // 写FIFO计数器和状态
    reg [FIFO_PTR_WIDTH-1:0] write_fifo_wr_ptr;
    reg [FIFO_PTR_WIDTH-1:0] write_fifo_rd_ptr;
    reg [FIFO_CNT_WIDTH-1:0] write_fifo_count;
    reg  [            1:0] write_fifo_op;   // FIFO操作码：00-无操作，01-只弹出，10-只推入，11-同时推入弹出

    // 读取请求FIFO数组 - 改为reg类型
    reg read_fifo_mem_op_lb[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lh[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lw[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lbu[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lhu[0:FIFO_DEPTH-1];
    reg [4:0] read_fifo_rd_addr[0:FIFO_DEPTH-1];
    reg [1:0] read_fifo_mem_addr_index[0:FIFO_DEPTH-1];
    reg [`COMMIT_ID_WIDTH-1:0] read_fifo_commit_id[0:FIFO_DEPTH-1];
    // 新增：高32位选择信号
    reg read_fifo_is_load_high[0:FIFO_DEPTH-1];

    // 写请求FIFO数组 - 改为reg类型
    reg [31:0] write_fifo_data[0:FIFO_DEPTH-1];
    reg [3:0] write_fifo_strb[0:FIFO_DEPTH-1];

    // 输出寄存器 - 改为reg类型
    reg [31:0] current_reg_wdata_r;
    reg reg_write_valid_r;
    reg [4:0] reg_waddr_r;
    reg [`COMMIT_ID_WIDTH-1:0] current_commit_id_r;

    // 读写FIFO状态信号
    wire read_fifo_empty;
    wire read_fifo_full;
    wire write_fifo_empty;
    wire write_fifo_full;
    wire read_fifo_wr_allow;  // 允许写入
    wire read_fifo_rd_allow;  // 允许读取
    wire write_fifo_wr_allow;  // 允许写入
    wire write_fifo_rd_allow;  // 允许读取

    // FIFO状态计算 - 使用计数器
    assign read_fifo_empty     = (read_fifo_count == {FIFO_CNT_WIDTH{1'b0}});
    assign read_fifo_full      = (read_fifo_count == FIFO_DEPTH[FIFO_CNT_WIDTH-1:0]);
    assign write_fifo_empty    = (write_fifo_count == {FIFO_CNT_WIDTH{1'b0}});
    assign write_fifo_full     = (write_fifo_count == FIFO_DEPTH[FIFO_CNT_WIDTH-1:0]);

    // FIFO保护机制
    assign read_fifo_wr_allow  = !read_fifo_full;
    assign read_fifo_rd_allow  = !read_fifo_empty;
    assign write_fifo_wr_allow = !write_fifo_full;
    assign write_fifo_rd_allow = !write_fifo_empty;

    // 生成请求有效信号
    assign read_req_valid      = valid_op && is_load_op;
    assign write_req_valid     = valid_op && is_store_op;

    // 同周期响应判断
    wire same_cycle_response;
    assign same_cycle_response = (read_fifo_empty & M_AXI_ARVALID & M_AXI_ARREADY & M_AXI_RVALID & axi_rready);

    // 访存阻塞信号 - 简化为32位指令处理
    assign mem_stall_o = req_mem_i && !int_assert_i && input_fifo_full;
    assign mem_busy_o = !write_fifo_empty || !input_fifo_empty;

    // 读请求FIFO操作
    wire read_fifo_wr_en;
    wire read_fifo_rd_en;

    // 写请求FIFO操作
    wire write_fifo_wr_en;
    wire write_fifo_rd_en;

    // AXI控制信号
    wire axi_rready;
    wire axi_bready;

    // 读控制信号逻辑
    assign axi_rready = 1'b1;  // 始终保持读数据通道ready

    // 读FIFO写入使能 - 当地址握手成功但数据未同时到达时，添加保护机制
    assign read_fifo_wr_en = (M_AXI_ARVALID & M_AXI_ARREADY) & (~(M_AXI_RVALID | read_fifo_full) | read_fifo_rd_allow) & read_fifo_wr_allow;

    // 读FIFO读取使能 - 当等待数据且数据到达时，添加保护机制
    assign read_fifo_rd_en = M_AXI_RVALID & axi_rready & read_fifo_rd_allow;

    // 写FIFO写入使能 - 当地址握手成功但数据握手失败时，添加保护机制
    assign write_fifo_wr_en = write_req_valid & M_AXI_AWREADY & ~M_AXI_WREADY & write_fifo_wr_allow;

    // 写FIFO读取使能 - 当FIFO非空且数据握手成功时，添加保护机制
    assign write_fifo_rd_en = write_fifo_rd_allow & M_AXI_WREADY;

    // FIFO操作码生成，使用位拼接整理
    assign read_fifo_op = {read_fifo_wr_en, read_fifo_rd_en};
    assign write_fifo_op = {write_fifo_wr_en, write_fifo_rd_en};

    // 寄存器写回逻辑 - 修改ldl判断条件
    wire reg_write_valid_set;
    wire reg_write_valid_nxt;

    assign reg_write_valid_set = (axi_rready & M_AXI_RVALID);
    assign reg_write_valid_nxt = reg_write_valid_set;

    // 直接从AXI读取数据
    assign axi_read_data       = M_AXI_RDATA;

    // 从FIFO中获取当前处理的请求信息 - 使用effective信号
    wire [1:0] curr_mem_addr_index = same_cycle_response ? mem_addr_index : read_fifo_mem_addr_index[read_fifo_rd_ptr];
    wire curr_mem_op_lb = same_cycle_response ? effective_mem_op_lb_i : read_fifo_mem_op_lb[read_fifo_rd_ptr];
    wire curr_mem_op_lh = same_cycle_response ? effective_mem_op_lh_i : read_fifo_mem_op_lh[read_fifo_rd_ptr];
    wire curr_mem_op_lw = same_cycle_response ? effective_mem_op_lw_i : read_fifo_mem_op_lw[read_fifo_rd_ptr];
    wire curr_mem_op_lbu = same_cycle_response ? effective_mem_op_lbu_i : read_fifo_mem_op_lbu[read_fifo_rd_ptr];
    wire curr_mem_op_lhu = same_cycle_response ? effective_mem_op_lhu_i : read_fifo_mem_op_lhu[read_fifo_rd_ptr];
    wire [`REG_ADDR_WIDTH-1:0] curr_rd_addr = same_cycle_response ? effective_rd_addr_i : read_fifo_rd_addr[read_fifo_rd_ptr];
    wire [`COMMIT_ID_WIDTH-1:0] curr_commit_id = same_cycle_response ? effective_commit_id_i : read_fifo_commit_id[read_fifo_rd_ptr];
    // 新增：高32位选择
    wire curr_is_load_high = same_cycle_response ? effective_mem_addr_i[2] : read_fifo_is_load_high[read_fifo_rd_ptr];

    // 新增：32位读数据选择
    wire [31:0] read_data_32b = curr_is_load_high ? axi_read_data[63:32] : axi_read_data[31:0];

    // 字节加载数据的与或逻辑
    wire [31:0] lb_data, lh_data, lw_data, lbu_data, lhu_data;
    wire [31:0] lb_byte0, lb_byte1, lb_byte2, lb_byte3;
    wire [31:0] lbu_byte0, lbu_byte1, lbu_byte2, lbu_byte3;
    wire [31:0] lh_low, lh_high, lhu_low, lhu_high;

    // 有符号字节加载 - 并行准备所有可能的字节值
    assign lb_byte0 = {{24{read_data_32b[7]}}, read_data_32b[7:0]};
    assign lb_byte1 = {{24{read_data_32b[15]}}, read_data_32b[15:8]};
    assign lb_byte2 = {{24{read_data_32b[23]}}, read_data_32b[23:16]};
    assign lb_byte3 = {{24{read_data_32b[31]}}, read_data_32b[31:24]};

    // 无符号字节加载 - 并行准备所有可能的字节值
    assign lbu_byte0 = {24'h0, read_data_32b[7:0]};
    assign lbu_byte1 = {24'h0, read_data_32b[15:8]};
    assign lbu_byte2 = {24'h0, read_data_32b[23:16]};
    assign lbu_byte3 = {24'h0, read_data_32b[31:24]};

    // 有符号半字加载 - 并行准备所有可能的半字值
    assign lh_low = {{16{read_data_32b[15]}}, read_data_32b[15:0]};
    assign lh_high = {{16{read_data_32b[31]}}, read_data_32b[31:16]};

    // 无符号半字加载 - 并行准备所有可能的半字值
    assign lhu_low = {16'h0, read_data_32b[15:0]};
    assign lhu_high = {16'h0, read_data_32b[31:16]};

    // 使用与或逻辑并行选择正确的字节/半字/字
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

    assign lw_data = read_data_32b;

    // 与或逻辑并行选择当前读取数据的寄存器写回值
    wire [`REG_DATA_WIDTH-1:0] current_reg_wdata =
           ({32{curr_mem_op_lb}} & lb_data) |
           ({32{curr_mem_op_lbu}} & lbu_data) |
           ({32{curr_mem_op_lh}} & lh_data) |
           ({32{curr_mem_op_lhu}} & lhu_data) |
           ({32{curr_mem_op_lw}} & lw_data);  // ldl直接使用读取数据

    // 从FIFO获取或直接使用的写数据 - 使用effective信号
    wire [31:0] mem_wdata_out = !write_fifo_empty ? write_fifo_data[write_fifo_rd_ptr] : effective_mem_wdata_i;
    wire [3:0] mem_wmask_out = !write_fifo_empty ? write_fifo_strb[write_fifo_rd_ptr] : effective_mem_wmask_i;

    // 输入请求FIFO更新逻辑 - 简化为普通32位指令处理
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_fifo_wr_ptr <= {INPUT_FIFO_PTR_WIDTH{1'b0}};
            input_fifo_rd_ptr <= {INPUT_FIFO_PTR_WIDTH{1'b0}};
            input_fifo_count  <= {INPUT_FIFO_CNT_WIDTH{1'b0}};
            // 重置所有输入FIFO条目
            for (int i = 0; i < INPUT_FIFO_DEPTH; i++) begin
                input_fifo_req_mem[i]      <= 1'b0;
                input_fifo_mem_op_lb[i]    <= 1'b0;
                input_fifo_mem_op_lh[i]    <= 1'b0;
                input_fifo_mem_op_lw[i]    <= 1'b0;
                input_fifo_mem_op_lbu[i]   <= 1'b0;
                input_fifo_mem_op_lhu[i]   <= 1'b0;
                input_fifo_mem_op_load[i]  <= 1'b0;
                input_fifo_mem_op_store[i] <= 1'b0;
                input_fifo_rd_addr[i]      <= 5'b0;
                input_fifo_mem_addr[i]     <= 32'b0;
                input_fifo_mem_wdata[i]    <= 32'b0;
                input_fifo_mem_wmask[i]    <= 4'b0;
                input_fifo_commit_id[i]    <= {`COMMIT_ID_WIDTH{1'b0}};
            end
        end else begin
            case (input_fifo_op)
                2'b10: begin  // 只推入
                    if (input_fifo_wr_allow) begin
                        // 所有指令，推入一个请求
                        input_fifo_wr_ptr <= (input_fifo_wr_ptr + 1'b1) % INPUT_FIFO_DEPTH;
                        input_fifo_count <= input_fifo_count + 1'b1;
                        // 更新当前写指针位置的数据
                        input_fifo_req_mem[input_fifo_wr_ptr] <= req_mem_i;
                        input_fifo_mem_op_lb[input_fifo_wr_ptr] <= mem_op_lb_i;
                        input_fifo_mem_op_lh[input_fifo_wr_ptr] <= mem_op_lh_i;
                        input_fifo_mem_op_lw[input_fifo_wr_ptr] <= mem_op_lw_i;
                        input_fifo_mem_op_lbu[input_fifo_wr_ptr] <= mem_op_lbu_i;
                        input_fifo_mem_op_lhu[input_fifo_wr_ptr] <= mem_op_lhu_i;
                        input_fifo_mem_op_load[input_fifo_wr_ptr] <= mem_op_load_i;
                        input_fifo_mem_op_store[input_fifo_wr_ptr] <= mem_op_store_i;
                        input_fifo_rd_addr[input_fifo_wr_ptr] <= rd_addr_i;
                        input_fifo_mem_addr[input_fifo_wr_ptr] <= mem_addr_i;
                        input_fifo_mem_wdata[input_fifo_wr_ptr] <= mem_wdata_i[31:0];
                        input_fifo_mem_wmask[input_fifo_wr_ptr] <= mem_wmask_i;
                        input_fifo_commit_id[input_fifo_wr_ptr] <= commit_id_i;
                    end
                end
                2'b01: begin  // 只弹出
                    if (input_fifo_rd_allow) begin
                        input_fifo_rd_ptr <= (input_fifo_rd_ptr + 1'b1) % INPUT_FIFO_DEPTH;
                        input_fifo_count  <= input_fifo_count - 1'b1;
                    end
                end
                2'b11: begin  // 同时推入弹出
                    // 单推入单弹出
                    input_fifo_wr_ptr <= (input_fifo_wr_ptr + 1'b1) % INPUT_FIFO_DEPTH;
                    input_fifo_rd_ptr <= (input_fifo_rd_ptr + 1'b1) % INPUT_FIFO_DEPTH;
                    // 计数器不变
                    // 更新当前写指针位置的数据
                    input_fifo_req_mem[input_fifo_wr_ptr] <= req_mem_i;
                    input_fifo_mem_op_lb[input_fifo_wr_ptr] <= mem_op_lb_i;
                    input_fifo_mem_op_lh[input_fifo_wr_ptr] <= mem_op_lh_i;
                    input_fifo_mem_op_lw[input_fifo_wr_ptr] <= mem_op_lw_i;
                    input_fifo_mem_op_lbu[input_fifo_wr_ptr] <= mem_op_lbu_i;
                    input_fifo_mem_op_lhu[input_fifo_wr_ptr] <= mem_op_lhu_i;
                    input_fifo_mem_op_load[input_fifo_wr_ptr] <= mem_op_load_i;
                    input_fifo_mem_op_store[input_fifo_wr_ptr] <= mem_op_store_i;
                    input_fifo_rd_addr[input_fifo_wr_ptr] <= rd_addr_i;
                    input_fifo_mem_addr[input_fifo_wr_ptr] <= mem_addr_i;
                    input_fifo_mem_wdata[input_fifo_wr_ptr] <= mem_wdata_i[31:0];
                    input_fifo_mem_wmask[input_fifo_wr_ptr] <= mem_wmask_i;
                    input_fifo_commit_id[input_fifo_wr_ptr] <= commit_id_i;
                end
                default: begin
                    // 保持当前状态
                end
            endcase
        end
    end

    // 合并读请求类型FIFO - 更新64位支持
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_fifo_wr_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            read_fifo_rd_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            read_fifo_count  <= {FIFO_CNT_WIDTH{1'b0}};
            // 重置所有读FIFO条目
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                read_fifo_mem_op_lb[i]      <= 1'b0;
                read_fifo_mem_op_lh[i]      <= 1'b0;
                read_fifo_mem_op_lw[i]      <= 1'b0;
                read_fifo_mem_op_lbu[i]     <= 1'b0;
                read_fifo_mem_op_lhu[i]     <= 1'b0;
                read_fifo_rd_addr[i]        <= 5'b0;
                read_fifo_mem_addr_index[i] <= 2'b0;
                read_fifo_commit_id[i]      <= {`COMMIT_ID_WIDTH{1'b0}};
                read_fifo_is_load_high[i]   <= 1'b0; // 新增
            end
        end else begin
            case (read_fifo_op)
                2'b10: begin  // 只推入
                    if (read_fifo_wr_allow) begin
                        read_fifo_wr_ptr <= (read_fifo_wr_ptr + 1'b1) % FIFO_DEPTH;
                        read_fifo_count <= read_fifo_count + 1'b1;

                        // 更新当前写指针位置的数据 - 使用effective信号
                        read_fifo_mem_op_lb[read_fifo_wr_ptr] <= effective_mem_op_lb_i;
                        read_fifo_mem_op_lh[read_fifo_wr_ptr] <= effective_mem_op_lh_i;
                        read_fifo_mem_op_lw[read_fifo_wr_ptr] <= effective_mem_op_lw_i;
                        read_fifo_mem_op_lbu[read_fifo_wr_ptr] <= effective_mem_op_lbu_i;
                        read_fifo_mem_op_lhu[read_fifo_wr_ptr] <= effective_mem_op_lhu_i;
                        read_fifo_rd_addr[read_fifo_wr_ptr] <= effective_rd_addr_i;
                        read_fifo_mem_addr_index[read_fifo_wr_ptr] <= mem_addr_index;
                        read_fifo_commit_id[read_fifo_wr_ptr] <= effective_commit_id_i;
                        read_fifo_is_load_high[read_fifo_wr_ptr] <= effective_mem_addr_i[2]; // 新增
                    end
                end
                2'b01: begin  // 只弹出
                    if (read_fifo_rd_allow) begin
                        read_fifo_rd_ptr <= (read_fifo_rd_ptr + 1'b1) % FIFO_DEPTH;
                        read_fifo_count  <= read_fifo_count - 1'b1;
                    end
                end
                2'b11: begin  // 同时推入弹出
                    read_fifo_wr_ptr <= (read_fifo_wr_ptr + 1'b1) % FIFO_DEPTH;
                    read_fifo_rd_ptr <= (read_fifo_rd_ptr + 1'b1) % FIFO_DEPTH;
                    // 计数器不变

                    // 更新当前写指针位置的数据 - 使用effective信号
                    read_fifo_mem_op_lb[read_fifo_wr_ptr] <= effective_mem_op_lb_i;
                    read_fifo_mem_op_lh[read_fifo_wr_ptr] <= effective_mem_op_lh_i;
                    read_fifo_mem_op_lw[read_fifo_wr_ptr] <= effective_mem_op_lw_i;
                    read_fifo_mem_op_lbu[read_fifo_wr_ptr] <= effective_mem_op_lbu_i;
                    read_fifo_mem_op_lhu[read_fifo_wr_ptr] <= effective_mem_op_lhu_i;
                    read_fifo_rd_addr[read_fifo_wr_ptr] <= effective_rd_addr_i;
                    read_fifo_mem_addr_index[read_fifo_wr_ptr] <= mem_addr_index;
                    read_fifo_commit_id[read_fifo_wr_ptr] <= effective_commit_id_i;
                    read_fifo_is_load_high[read_fifo_wr_ptr] <= effective_mem_addr_i[2]; // 新增
                end
                default: begin
                    // 保持当前状态
                end
            endcase
        end
    end

    // 合并写数据通道FIFO
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_fifo_wr_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            write_fifo_rd_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            write_fifo_count  <= {FIFO_CNT_WIDTH{1'b0}};
            // 重置所有写FIFO条目
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                write_fifo_data[i] <= 32'b0;
                write_fifo_strb[i] <= 4'b0;
            end
        end else begin
            case (write_fifo_op)
                2'b10: begin  // 只推入
                    if (write_fifo_wr_allow) begin
                        write_fifo_wr_ptr <= (write_fifo_wr_ptr + 1'b1) % FIFO_DEPTH;
                        write_fifo_count <= write_fifo_count + 1'b1;
                        write_fifo_data[write_fifo_wr_ptr] <= effective_mem_wdata_i;
                        write_fifo_strb[write_fifo_wr_ptr] <= effective_mem_wmask_i;
                    end
                end
                2'b01: begin  // 只弹出
                    if (write_fifo_rd_allow) begin
                        write_fifo_rd_ptr <= (write_fifo_rd_ptr + 1'b1) % FIFO_DEPTH;
                        write_fifo_count  <= write_fifo_count - 1'b1;
                    end
                end
                2'b11: begin  // 同时推入弹出
                    write_fifo_wr_ptr                  <= (write_fifo_wr_ptr + 1'b1) % FIFO_DEPTH;
                    write_fifo_rd_ptr                  <= (write_fifo_rd_ptr + 1'b1) % FIFO_DEPTH;
                    // 计数器不变
                    write_fifo_data[write_fifo_wr_ptr] <= effective_mem_wdata_i;
                    write_fifo_strb[write_fifo_wr_ptr] <= effective_mem_wmask_i;
                end
                default: begin
                    // 保持当前状态
                end
            endcase
        end
    end

    // AXI接口信号赋值
    // 写控制信号逻辑
    assign axi_bready    = 1'b1;  // 始终准备接收写响应

    // 写地址通道 - 使用effective信号，添加write_fifo_full阻塞
    assign M_AXI_AWID    = 'b0;
    assign M_AXI_AWADDR  = effective_mem_addr_i;
    assign M_AXI_AWLEN   = 8'b0;  // 单次传输
    assign M_AXI_AWSIZE  = 3'b010;  // 4字节
    assign M_AXI_AWBURST = 2'b01;  // INCR
    assign M_AXI_AWLOCK  = 1'b0;
    assign M_AXI_AWCACHE = 4'b0010;
    assign M_AXI_AWPROT  = 3'h0;
    assign M_AXI_AWQOS   = 4'h0;
    assign M_AXI_AWUSER  = 'b1;
    assign M_AXI_AWVALID = write_req_valid && !write_fifo_full;  // 写FIFO满时不发送写请求

    // 写数据通道
    assign M_AXI_WDATA   = mem_wdata_out;
    assign M_AXI_WSTRB   = mem_wmask_out;
    assign M_AXI_WLAST   = 1'b1;  // 每次写入一组数据，Burst长度为1
    assign M_AXI_WUSER   = 'b0;
    assign M_AXI_WVALID  = write_req_valid || !write_fifo_empty;

    // 写响应通道
    assign M_AXI_BREADY  = axi_bready;

    // 读地址通道 - 使用effective信号，添加read_fifo_full阻塞
    assign M_AXI_ARID    = 'b0;  // ARID固定为0,使用顺序Outstanding
    assign M_AXI_ARADDR  = effective_mem_addr_i;
    assign M_AXI_ARLEN   = 8'b0;  // 单次传输
    assign M_AXI_ARSIZE  = 3'b010;  // 4字节
    assign M_AXI_ARBURST = 2'b01;  // INCR
    assign M_AXI_ARLOCK  = 1'b0;
    assign M_AXI_ARCACHE = 4'b0010;
    assign M_AXI_ARPROT  = 3'h0;
    assign M_AXI_ARQOS   = 4'h0;
    assign M_AXI_ARUSER  = 'b1;
    assign M_AXI_ARVALID = read_req_valid && !read_fifo_full;  // 读FIFO满时不发送读请求

    // 读数据通道
    assign M_AXI_RREADY  = axi_rready;

    // 寄存器写回信号 - 直接使用组合逻辑连接，支持64位
    assign reg_we_o      = reg_write_valid_nxt;
    assign reg_wdata_o   = current_reg_wdata;
    assign reg_waddr_o   = curr_rd_addr;
    assign commit_id_o   = curr_commit_id;

endmodule
