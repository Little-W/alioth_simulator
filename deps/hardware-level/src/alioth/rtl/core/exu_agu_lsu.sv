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
module exu_agu_lsu #(
    // AXI接口参数
    parameter C_M_AXI_ID_WIDTH     = 2,
    parameter C_M_AXI_ADDR_WIDTH   = 32,
    parameter C_M_AXI_DATA_WIDTH   = 32,
    parameter C_M_AXI_AWUSER_WIDTH = 1,
    parameter C_M_AXI_ARUSER_WIDTH = 1,
    parameter C_M_AXI_WUSER_WIDTH  = 1,
    parameter C_M_AXI_RUSER_WIDTH  = 1,
    parameter C_M_AXI_BUSER_WIDTH  = 1
) (
    input wire clk,   // 时钟输入
    input wire rst_n,

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
    input wire        mem_op_load_i,
    input wire        mem_op_store_i,
    input wire [ 4:0] rd_addr_i,

    // 修改commit_id输入为4位
    input wire [3:0] commit_id_i,

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

    // 修改commit_id输出为4位
    output wire [3:0] commit_id_o,

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
    wire [31:0] mem_addr;
    wire valid_op;  // 有效操作信号（无中断且有内存请求）

    // 添加之前隐式声明的信号
    wire read_req_valid;
    wire write_req_valid;
    wire [3:0] mem_wmask;
    wire [31:0] mem_wdata;

    // 直接使用输入的load和store信号
    wire is_load_op = mem_op_load_i;
    wire is_store_op = mem_op_store_i;

    // 使用typedef定义读写状态机的状态
    typedef enum logic [1:0] {
        READ_IDLE = 2'b00,
        READ_ADDR = 2'b01,
        READ_DATA = 2'b10
    } read_state_t;

    typedef enum logic [1:0] {
        WRITE_IDLE = 2'b00,
        WRITE_ADDR = 2'b01,
        WRITE_DATA = 2'b10,
        WRITE_RESP = 2'b11
    } write_state_t;

    read_state_t state_axi_read;
    write_state_t state_axi_write;

    // AXI请求相关寄存器 - 移除独立读地址寄存器
    wire [`BUS_DATA_WIDTH-1:0] axi_read_data;

    // 寄存读取操作相关信号
    reg stored_mem_op_lb;
    reg stored_mem_op_lh;
    reg stored_mem_op_lw;
    reg stored_mem_op_lbu;
    reg stored_mem_op_lhu;
    reg [1:0] stored_mem_addr_index;
    reg [4:0] stored_rd_addr;

    // AXI控制信号
    reg axi_rready;
    reg axi_bready;

    // 新增等待信号声明
    reg wait_for_rdata;  // 等待读数据信号
    reg wait_for_bvalid;  // 等待写响应信号

    // 生成请求有效信号 - 简化逻辑，只检查是否有内存请求
    assign read_req_valid  = valid_op && is_load_op;
    assign write_req_valid = valid_op && is_store_op;

    // FIFO相关参数定义 - 读取请求FIFO
    localparam FIFO_DEPTH = 4;
    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);  // FIFO指针宽度

    // 读取请求FIFO结构 - 添加read_前缀
    reg [FIFO_PTR_WIDTH-1:0] read_fifo_wr_ptr;  // 读FIFO写指针
    reg [FIFO_PTR_WIDTH-1:0] read_fifo_rd_ptr;  // 读FIFO读指针
    reg [FIFO_DEPTH-1:0] read_fifo_valid;  // 读FIFO项有效标志

    // 添加FIFO数组定义 - 添加read_前缀
    reg read_fifo_mem_op_lb[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lh[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lw[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lbu[0:FIFO_DEPTH-1];
    reg read_fifo_mem_op_lhu[0:FIFO_DEPTH-1];
    reg [4:0] read_fifo_rd_addr[0:FIFO_DEPTH-1];
    reg [1:0] read_fifo_mem_addr_index[0:FIFO_DEPTH-1];
    // 修改FIFO中存储的commit_id为4位
    reg [3:0] read_fifo_commit_id[0:FIFO_DEPTH-1];

    // 读FIFO状态信号 - 添加read_前缀
    wire read_fifo_empty;
    wire read_fifo_full;

    // 读FIFO状态计算 - 更新使用read_前缀
    assign read_fifo_empty = (read_fifo_wr_ptr == read_fifo_rd_ptr) && (read_fifo_valid[read_fifo_rd_ptr] == 1'b0);
    assign read_fifo_full = (read_fifo_wr_ptr == read_fifo_rd_ptr) && (read_fifo_valid[read_fifo_wr_ptr] == 1'b1);

    // 判断数据是否在同一周期返回
    reg same_cycle_response;

    assign same_cycle_response = (~wait_for_rdata & M_AXI_ARVALID & M_AXI_ARREADY & M_AXI_RVALID & axi_rready);


    // 添加写请求的FIFO结构
    reg [FIFO_PTR_WIDTH-1:0] write_fifo_wr_ptr;  // 写FIFO写指针
    reg [FIFO_PTR_WIDTH-1:0] write_fifo_rd_ptr;  // 写FIFO读指针
    reg [FIFO_DEPTH-1:0] write_fifo_valid;  // 写FIFO项有效标志

    // 写FIFO数据结构
    reg [31:0] write_fifo_data[0:FIFO_DEPTH-1];  // 数据
    reg [3:0] write_fifo_strb[0:FIFO_DEPTH-1];  // 字节使能

    // 写FIFO状态信号
    wire write_fifo_empty;
    wire write_fifo_full;

    // 写FIFO状态计算
    assign write_fifo_empty = (write_fifo_wr_ptr == write_fifo_rd_ptr) && (write_fifo_valid[write_fifo_rd_ptr] == 1'b0);
    assign write_fifo_full = (write_fifo_wr_ptr == write_fifo_rd_ptr) && (write_fifo_valid[write_fifo_wr_ptr] == 1'b1);

    wire read_req_pending;
    wire write_req_pending;

    // 分离读写访存阻塞信号
    wire read_stall;
    wire write_stall;

    assign read_stall  = read_req_valid & (read_fifo_full | ~M_AXI_ARREADY);

    assign write_stall = write_req_valid & (write_fifo_full | ~M_AXI_AWREADY);

    // 总的访存阻塞信号 - 任一FIFO满且有相应请求时阻塞
    assign mem_stall_o = read_stall | write_stall;

    // 指示当前是否有未完成的传输事务 - 只追踪写FIFO状态，load指令的完成情况由HDU统一管理
    assign mem_busy_o  = !write_fifo_empty;

    // 从FIFO中获取当前处理的请求信息 - 更新使用read_前缀
    wire [1:0] curr_mem_addr_index = same_cycle_response ? mem_addr_index : read_fifo_mem_addr_index[read_fifo_rd_ptr];
    wire curr_mem_op_lb = same_cycle_response ? mem_op_lb_i : read_fifo_mem_op_lb[read_fifo_rd_ptr];
    wire curr_mem_op_lh = same_cycle_response ? mem_op_lh_i : read_fifo_mem_op_lh[read_fifo_rd_ptr];
    wire curr_mem_op_lw = same_cycle_response ? mem_op_lw_i : read_fifo_mem_op_lw[read_fifo_rd_ptr];
    wire curr_mem_op_lbu = same_cycle_response ? mem_op_lbu_i : read_fifo_mem_op_lbu[read_fifo_rd_ptr];
    wire curr_mem_op_lhu = same_cycle_response ? mem_op_lhu_i : read_fifo_mem_op_lhu[read_fifo_rd_ptr];
    wire [4:0] curr_rd_addr = same_cycle_response ? rd_addr_i : read_fifo_rd_addr[read_fifo_rd_ptr];
    wire [3:0] curr_commit_id = same_cycle_response ? commit_id_i : read_fifo_commit_id[read_fifo_rd_ptr];

    // 基本信号计算
    assign mem_addr       = mem_op1_i + mem_op2_i;
    assign mem_addr_index = mem_addr[1:0];
    assign valid_op       = req_mem_i & (int_assert_i != `INT_ASSERT);

    // 直接连接到 AXI 数据
    assign axi_read_data  = M_AXI_RDATA;

    // 字节加载数据 - 使用FIFO中的地址索引
    wire [31:0] lb_data, lh_data, lw_data, lbu_data, lhu_data;
    wire [31:0] lb_byte0, lb_byte1, lb_byte2, lb_byte3;
    wire [31:0] lbu_byte0, lbu_byte1, lbu_byte2, lbu_byte3;
    wire [31:0] lh_low, lh_high, lhu_low, lhu_high;

    // 有符号字节加载 - 并行准备所有可能的字节值（使用AXI读取的数据）
    assign lb_byte0 = {{24{axi_read_data[7]}}, axi_read_data[7:0]};
    assign lb_byte1 = {{24{axi_read_data[15]}}, axi_read_data[15:8]};
    assign lb_byte2 = {{24{axi_read_data[23]}}, axi_read_data[23:16]};
    assign lb_byte3 = {{24{axi_read_data[31]}}, axi_read_data[31:24]};

    // 无符号字节加载 - 并行准备所有可能的字节值
    assign lbu_byte0 = {24'h0, axi_read_data[7:0]};
    assign lbu_byte1 = {24'h0, axi_read_data[15:8]};
    assign lbu_byte2 = {24'h0, axi_read_data[23:16]};
    assign lbu_byte3 = {24'h0, axi_read_data[31:24]};

    // 有符号半字加载 - 并行准备所有可能的半字值
    assign lh_low = {{16{axi_read_data[15]}}, axi_read_data[15:0]};
    assign lh_high = {{16{axi_read_data[31]}}, axi_read_data[31:16]};

    // 无符号半字加载 - 并行准备所有可能的半字值
    assign lhu_low = {16'h0, axi_read_data[15:0]};
    assign lhu_high = {16'h0, axi_read_data[31:16]};

    // 使用FIFO中的信息选择正确的字节/半字/字
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

    assign lw_data = axi_read_data;  // 直接使用AXI读取的数据

    // 处理当前读取数据的寄存器写回信号 - 使用FIFO中的操作类型
    wire [`REG_DATA_WIDTH-1:0] current_reg_wdata =
           ({32{curr_mem_op_lb}} & lb_data) |
           ({32{curr_mem_op_lbu}} & lbu_data) |
           ({32{curr_mem_op_lh}} & lh_data) |
           ({32{curr_mem_op_lhu}} & lhu_data) |
           ({32{curr_mem_op_lw}} & lw_data);

    // 存储操作的掩码和数据 - 使用并行选择逻辑
    // 字节存储掩码和数据
    wire [3:0] sb_mask;
    wire [31:0] sb_data;

    assign sb_mask = ({4{mem_addr_index == 2'b00}} & 4'b0001) |
                     ({4{mem_addr_index == 2'b01}} & 4'b0010) |
                     ({4{mem_addr_index == 2'b10}} & 4'b0100) |
                     ({4{mem_addr_index == 2'b11}} & 4'b1000);

    assign sb_data = ({32{mem_addr_index == 2'b00}} & {24'b0, mem_rs2_data_i[7:0]}) |
                     ({32{mem_addr_index == 2'b01}} & {16'b0, mem_rs2_data_i[7:0], 8'b0}) |
                     ({32{mem_addr_index == 2'b10}} & {8'b0, mem_rs2_data_i[7:0], 16'b0}) |
                     ({32{mem_addr_index == 2'b11}} & {mem_rs2_data_i[7:0], 24'b0});

    // 半字存储掩码和数据
    wire [ 3:0] sh_mask;
    wire [31:0] sh_data;

    assign sh_mask = ({4{mem_addr_index[1] == 1'b0}} & 4'b0011) | ({4{mem_addr_index[1] == 1'b1}} & 4'b1100);

    assign sh_data = ({32{mem_addr_index[1] == 1'b0}} & {16'b0, mem_rs2_data_i[15:0]}) |
                     ({32{mem_addr_index[1] == 1'b1}} & {mem_rs2_data_i[15:0], 16'b0});

    // 字存储掩码和数据
    wire [ 3:0] sw_mask;
    wire [31:0] sw_data;

    assign sw_mask = 4'b1111;
    assign sw_data = mem_rs2_data_i;

    // 并行选择最终的存储掩码和数据
    assign mem_wmask = ({4{valid_op & mem_op_sb_i}} & sb_mask) |
                      ({4{valid_op & mem_op_sh_i}} & sh_mask) |
                      ({4{valid_op & mem_op_sw_i}} & sw_mask);

    assign mem_wdata = ({32{valid_op & mem_op_sb_i}} & sb_data) |
                      ({32{valid_op & mem_op_sh_i}} & sh_data) |
                      ({32{valid_op & mem_op_sw_i}} & sw_data);


    // 新增寄存器写回缓存寄存器
    reg [`REG_DATA_WIDTH-1:0] current_reg_wdata_r;
    reg                       reg_write_valid_r;
    reg [`REG_ADDR_WIDTH-1:0] reg_waddr_r;
    // 新增：寄存commit_id
    reg [                3:0] current_commit_id_r;

    // 流水线式读操作控制 - 修改为完全使用带前缀的FIFO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_rready          <= 1'b0;
            wait_for_rdata      <= 1'b0;
            read_fifo_wr_ptr    <= 'b0;
            read_fifo_rd_ptr    <= 'b0;
            read_fifo_valid     <= 'b0;
            // 新增寄存器初始化
            current_reg_wdata_r <= 32'b0;
            reg_write_valid_r   <= 1'b0;
            reg_waddr_r         <= 5'b0;
            // 新增：初始化commit_id寄存器
            current_commit_id_r <= 4'b0;
        end else begin
            // 默认在每个时钟周期清除寄存器写有效信号
            reg_write_valid_r <= 1'b0;
            axi_rready        <= 1'b1;  // 保持读数据通道的ready信号

            // 第一阶段：处理读地址握手
            if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                // 读地址握手成功，标记需要等待数据
                wait_for_rdata <= 1'b1;

                // 检查是否为同周期响应（地址和数据在同一周期都握手成功）
                if (M_AXI_RVALID) begin
                    // 同周期响应，无需使用FIFO，直接处理数据
                    wait_for_rdata      <= 1'b0;
                    current_reg_wdata_r <= current_reg_wdata;
                    reg_write_valid_r   <= 1'b1;
                    reg_waddr_r         <= rd_addr_i;
                    current_commit_id_r <= commit_id_i;
                end else begin
                    // 非同周期响应，将请求信息写入FIFO
                    if (!read_fifo_full) begin
                        read_fifo_mem_op_lb[read_fifo_wr_ptr] <= mem_op_lb_i;
                        read_fifo_mem_op_lh[read_fifo_wr_ptr] <= mem_op_lh_i;
                        read_fifo_mem_op_lw[read_fifo_wr_ptr] <= mem_op_lw_i;
                        read_fifo_mem_op_lbu[read_fifo_wr_ptr] <= mem_op_lbu_i;
                        read_fifo_mem_op_lhu[read_fifo_wr_ptr] <= mem_op_lhu_i;
                        read_fifo_rd_addr[read_fifo_wr_ptr] <= rd_addr_i;
                        read_fifo_mem_addr_index[read_fifo_wr_ptr]   <= mem_addr_index;
                        read_fifo_commit_id[read_fifo_wr_ptr] <= commit_id_i;
                        read_fifo_valid[read_fifo_wr_ptr] <= 1'b1;
                        read_fifo_wr_ptr <= (read_fifo_wr_ptr + 1) % FIFO_DEPTH;
                    end
                end
            end

            // 第二阶段：处理读数据握手（非同周期响应）
            if (wait_for_rdata && M_AXI_RVALID && axi_rready && !read_fifo_empty) begin
                // 读数据握手成功，从FIFO获取对应请求信息
                wait_for_rdata <= 1'b0;
                current_reg_wdata_r <= current_reg_wdata;
                reg_write_valid_r <= 1'b1;
                reg_waddr_r <= read_fifo_rd_addr[read_fifo_rd_ptr];
                current_commit_id_r <= read_fifo_commit_id[read_fifo_rd_ptr];

                // 弹出已处理的FIFO项
                read_fifo_valid[read_fifo_rd_ptr] <= 1'b0;
                read_fifo_rd_ptr <= (read_fifo_rd_ptr + 1) % FIFO_DEPTH;
            end
        end
    end

    // 流水线式写操作控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_bready        <= 1'b0;
            wait_for_bvalid   <= 1'b0;
            write_fifo_wr_ptr <= 'b0;
            write_fifo_rd_ptr <= 'b0;
            write_fifo_valid  <= 'b0;
        end else begin
            axi_bready <= 1'b1;  // 始终准备接收写响应

            // 第一阶段：处理写地址和数据握手
            if (write_req_valid && M_AXI_AWREADY) begin
                // 写地址握手成功
                if (M_AXI_WREADY) begin
                    // 同时写地址和写数据握手成功，无需使用FIFO
                    wait_for_bvalid <= 1'b1;  // 等待写响应
                end else begin
                    // 写地址握手成功但写数据握手失败，将数据压入FIFO
                    if (!write_fifo_full) begin
                        write_fifo_data[write_fifo_wr_ptr] <= mem_wdata;
                        write_fifo_strb[write_fifo_wr_ptr] <= mem_wmask;
                        write_fifo_valid[write_fifo_wr_ptr] <= 1'b1;
                        write_fifo_wr_ptr                   <= (write_fifo_wr_ptr + 1) % FIFO_DEPTH;
                    end
                end
            end

            // 第二阶段：处理写数据握手（从FIFO发送）
            if (!write_fifo_empty && M_AXI_WREADY) begin
                // 从FIFO发送的数据握手成功，弹出已处理的FIFO项
                write_fifo_valid[write_fifo_rd_ptr] <= 1'b0;
                write_fifo_rd_ptr <= (write_fifo_rd_ptr + 1) % FIFO_DEPTH;
            end

            // 第三阶段：处理写响应握手
            if (wait_for_bvalid && M_AXI_BVALID) begin
                // 写响应握手成功，完成一次写事务
                wait_for_bvalid <= 1'b0;
            end
        end
    end

    // 直接从FIFO获取读地址和写数据
    wire [31:0] mem_wdata_out = !write_fifo_empty ? write_fifo_data[write_fifo_rd_ptr] : mem_wdata;
    wire [3:0]  mem_wmask_out = !write_fifo_empty ? write_fifo_strb[write_fifo_rd_ptr] : mem_wmask;

    // AXI接口信号赋值
    // 写地址通道
    assign M_AXI_AWID    = 'b0;  // AWID固定为0,使用顺序Outstanding
    assign M_AXI_AWADDR  = mem_addr;
    assign M_AXI_AWLEN   = 8'b0;  // 单次传输
    assign M_AXI_AWSIZE  = 3'b010;  // 4字节
    assign M_AXI_AWBURST = 2'b01;  // INCR
    assign M_AXI_AWLOCK  = 1'b0;
    assign M_AXI_AWCACHE = 4'b0010;
    assign M_AXI_AWPROT  = 3'h0;
    assign M_AXI_AWQOS   = 4'h0;
    assign M_AXI_AWUSER  = 'b1;
    assign M_AXI_AWVALID = write_req_valid;  // 只在有写请求时有效

    // 写数据通道
    assign M_AXI_WDATA   = mem_wdata_out;
    assign M_AXI_WSTRB   = mem_wmask_out;
    assign M_AXI_WLAST   = 1'b1;  // 每次写入一组数据，Burst长度为1
    assign M_AXI_WUSER   = 'b0;
    assign M_AXI_WVALID  = write_req_valid || !write_fifo_empty;

    // 写响应通道
    assign M_AXI_BREADY  = axi_bready;

    // 读地址通道
    assign M_AXI_ARID    = 'b0;  // ARID固定为0,使用顺序Outstanding
    assign M_AXI_ARADDR  = mem_addr;
    assign M_AXI_ARLEN   = 8'b0;  // 单次传输
    assign M_AXI_ARSIZE  = 3'b010;  // 4字节
    assign M_AXI_ARBURST = 2'b01;  // INCR
    assign M_AXI_ARLOCK  = 1'b0;
    assign M_AXI_ARCACHE = 4'b0010;
    assign M_AXI_ARPROT  = 3'h0;
    assign M_AXI_ARQOS   = 4'h0;
    assign M_AXI_ARUSER  = 'b1;
    assign M_AXI_ARVALID = read_req_valid;
    // 读数据通道
    assign M_AXI_RREADY  = axi_rready;

    // 寄存器写回信号
    assign reg_we_o      = reg_write_valid_r;
    assign reg_wdata_o   = current_reg_wdata_r;
    assign reg_waddr_o   = reg_waddr_r;
    // 新增：输出commit_id
    assign commit_id_o   = current_commit_id_r;

endmodule
