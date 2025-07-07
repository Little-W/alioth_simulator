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
    wire [ 1:0] mem_addr_index;
    wire [31:0] mem_addr;
    wire        valid_op;  // 有效操作信号（无中断且有内存请求）

    // 添加之前隐式声明的信号
    wire        read_req_valid;
    wire        write_req_valid;
    wire [ 3:0] mem_wmask;
    wire [31:0] mem_wdata;

    // 直接使用输入的load和store信号
    wire        is_load_op = mem_op_load_i;
    wire        is_store_op = mem_op_store_i;

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

    read_state_t                        state_axi_read;
    write_state_t                       state_axi_write;

    // AXI请求相关寄存器
    wire          [`BUS_DATA_WIDTH-1:0] axi_read_data;

    // FIFO相关参数定义
    localparam FIFO_DEPTH = 4;
    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);

    // 寄存器信号定义 - 将wire改为reg类型
    reg  [FIFO_PTR_WIDTH-1:0] read_fifo_wr_ptr;
    reg  [FIFO_PTR_WIDTH-1:0] read_fifo_rd_ptr;
    reg  [    FIFO_DEPTH-1:0] read_fifo_valid;

    reg                       wait_for_bvalid;
    reg  [FIFO_PTR_WIDTH-1:0] write_fifo_wr_ptr;
    reg  [FIFO_PTR_WIDTH-1:0] write_fifo_rd_ptr;
    reg  [    FIFO_DEPTH-1:0] write_fifo_valid;

    wire                        axi_rready;
    wire                        axi_bready;

    // 读取请求FIFO数组 - 改为reg类型
    reg                       read_fifo_mem_op_lb     [0:FIFO_DEPTH-1];
    reg                       read_fifo_mem_op_lh     [0:FIFO_DEPTH-1];
    reg                       read_fifo_mem_op_lw     [0:FIFO_DEPTH-1];
    reg                       read_fifo_mem_op_lbu    [0:FIFO_DEPTH-1];
    reg                       read_fifo_mem_op_lhu    [0:FIFO_DEPTH-1];
    reg  [               4:0] read_fifo_rd_addr       [0:FIFO_DEPTH-1];
    reg  [               1:0] read_fifo_mem_addr_index[0:FIFO_DEPTH-1];
    reg  [`COMMIT_ID_WIDTH-1:0] read_fifo_commit_id     [0:FIFO_DEPTH-1];

    // 写请求FIFO数组 - 改为reg类型
    reg  [              31:0] write_fifo_data         [0:FIFO_DEPTH-1];
    reg  [               3:0] write_fifo_strb         [0:FIFO_DEPTH-1];

    // 输出寄存器 - 改为reg类型
    reg  [              31:0] current_reg_wdata_r;
    reg                       reg_write_valid_r;
    reg  [               4:0] reg_waddr_r;
    reg  [`COMMIT_ID_WIDTH-1:0] current_commit_id_r;

    // 读写FIFO状态信号
    wire                        read_fifo_empty;
    wire                        read_fifo_full;
    wire                        write_fifo_empty;
    wire                        write_fifo_full;

    // FIFO状态计算
    assign read_fifo_empty = (read_fifo_wr_ptr == read_fifo_rd_ptr) && (read_fifo_valid[read_fifo_rd_ptr] == 1'b0);
    assign read_fifo_full = (read_fifo_wr_ptr == read_fifo_rd_ptr) && (read_fifo_valid[read_fifo_wr_ptr] == 1'b1);
    assign write_fifo_empty = (write_fifo_wr_ptr == write_fifo_rd_ptr) && (write_fifo_valid[write_fifo_rd_ptr] == 1'b0);
    assign write_fifo_full = (write_fifo_wr_ptr == write_fifo_rd_ptr) && (write_fifo_valid[write_fifo_wr_ptr] == 1'b1);

    // 生成请求有效信号
    assign read_req_valid = valid_op && is_load_op;
    assign write_req_valid = valid_op && is_store_op;

    // 同周期响应判断
    wire same_cycle_response;
    assign same_cycle_response = (read_fifo_empty & M_AXI_ARVALID & M_AXI_ARREADY & M_AXI_RVALID & axi_rready);

    // 基本信号计算
    assign mem_addr = mem_op1_i + mem_op2_i;
    assign mem_addr_index = mem_addr[1:0];
    assign valid_op = req_mem_i & (int_assert_i != `INT_ASSERT);

    // 访存阻塞信号
    wire read_stall;
    wire write_stall;
    assign read_stall  = read_req_valid & (read_fifo_full | ~M_AXI_ARREADY);
    assign write_stall = write_req_valid & (write_fifo_full | ~M_AXI_AWREADY);
    assign mem_stall_o = read_stall | write_stall;
    assign mem_busy_o  = !write_fifo_empty;

    // FIFO控制信号
    // 读FIFO写控制信号
    wire                      read_fifo_wr_en;
    wire [FIFO_PTR_WIDTH-1:0] read_fifo_wr_ptr_nxt;
    // 读FIFO读控制信号
    wire                      read_fifo_rd_en;
    wire [FIFO_PTR_WIDTH-1:0] read_fifo_rd_ptr_nxt;

    // 写FIFO控制信号
    wire                      write_fifo_wr_en;
    wire [FIFO_PTR_WIDTH-1:0] write_fifo_wr_ptr_nxt;
    wire                      write_fifo_rd_en;
    wire [FIFO_PTR_WIDTH-1:0] write_fifo_rd_ptr_nxt;

    // 读控制信号逻辑
    assign axi_rready = 1'b1;  // 始终保持读数据通道ready

    // 读FIFO写入使能 - 当地址握手成功但数据未同时到达时
    assign read_fifo_wr_en = (M_AXI_ARVALID & M_AXI_ARREADY) & (~(M_AXI_RVALID | read_fifo_full) | ~read_fifo_empty);
    assign read_fifo_wr_ptr_nxt = (read_fifo_wr_ptr + 1'b1) % FIFO_DEPTH;

    // 读FIFO读取使能 - 当等待数据且数据到达时
    assign read_fifo_rd_en = M_AXI_RVALID & axi_rready & ~read_fifo_empty;
    assign read_fifo_rd_ptr_nxt = (read_fifo_rd_ptr + 1'b1) % FIFO_DEPTH;

    // 写控制信号逻辑
    assign axi_bready = 1'b1;  // 始终准备接收写响应

    // 写FIFO写入使能 - 当地址握手成功但数据握手失败时
    assign write_fifo_wr_en = write_req_valid & M_AXI_AWREADY & ~M_AXI_WREADY & ~write_fifo_full;
    assign write_fifo_wr_ptr_nxt = (write_fifo_wr_ptr + 1'b1) % FIFO_DEPTH;

    // 写FIFO读取使能 - 当FIFO非空且数据握手成功时
    assign write_fifo_rd_en = ~write_fifo_empty & M_AXI_WREADY;
    assign write_fifo_rd_ptr_nxt = (write_fifo_rd_ptr + 1'b1) % FIFO_DEPTH;

    // 等待写响应信号的下一状态逻辑
    wire wait_for_bvalid_set;
    wire wait_for_bvalid_clear;
    wire wait_for_bvalid_nxt;

    assign wait_for_bvalid_set = write_req_valid & M_AXI_AWREADY & M_AXI_WREADY;
    assign wait_for_bvalid_clear = wait_for_bvalid & M_AXI_BVALID;
    assign wait_for_bvalid_nxt = (wait_for_bvalid_set & ~wait_for_bvalid_clear) | (wait_for_bvalid & ~wait_for_bvalid_clear);

    // 寄存器写回逻辑
    wire reg_write_valid_set;
    wire reg_write_valid_nxt;

    assign reg_write_valid_set = (axi_rready & M_AXI_RVALID);
    assign reg_write_valid_nxt = reg_write_valid_set;

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

    // 字节加载数据的与或逻辑
    wire [31:0] lb_data, lh_data, lw_data, lbu_data, lhu_data;
    wire [31:0] lb_byte0, lb_byte1, lb_byte2, lb_byte3;
    wire [31:0] lbu_byte0, lbu_byte1, lbu_byte2, lbu_byte3;
    wire [31:0] lh_low, lh_high, lhu_low, lhu_high;

    // 有符号字节加载 - 并行准备所有可能的字节值
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

    assign lw_data = axi_read_data;

    // 与或逻辑并行选择当前读取数据的寄存器写回值
    wire [31:0] current_reg_wdata =
           ({32{curr_mem_op_lb}} & lb_data) |
           ({32{curr_mem_op_lbu}} & lbu_data) |
           ({32{curr_mem_op_lh}} & lh_data) |
           ({32{curr_mem_op_lhu}} & lhu_data) |
           ({32{curr_mem_op_lw}} & lw_data);

    // 存储操作的掩码和数据 - 使用并行与或逻辑
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

    assign sh_mask = ({4{mem_addr_index[1] == 1'b0}} & 4'b0011) | 
                     ({4{mem_addr_index[1] == 1'b1}} & 4'b1100);

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

    // 从FIFO获取或直接使用的写数据
    wire [31:0] mem_wdata_out = !write_fifo_empty ? write_fifo_data[write_fifo_rd_ptr] : mem_wdata;
    wire [ 3:0] mem_wmask_out = !write_fifo_empty ? write_fifo_strb[write_fifo_rd_ptr] : mem_wmask;


    // 使用always块替换gnrl_dfflr实例
    // read_fifo_wr_ptr寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_fifo_wr_ptr <= {FIFO_PTR_WIDTH{1'b0}};
        end else if (read_fifo_wr_en) begin
            read_fifo_wr_ptr <= read_fifo_wr_ptr_nxt;
        end
    end

    // read_fifo_rd_ptr寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_fifo_rd_ptr <= {FIFO_PTR_WIDTH{1'b0}};
        end else if (read_fifo_rd_en) begin
            read_fifo_rd_ptr <= read_fifo_rd_ptr_nxt;
        end
    end

    // 寄存器写回控制寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write_valid_r <= 1'b0;
        end else begin
            reg_write_valid_r <= reg_write_valid_nxt;
        end
    end

    // 当前寄存器写回数据
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_reg_wdata_r <= 32'b0;
        end else if (reg_write_valid_set) begin
            current_reg_wdata_r <= current_reg_wdata;
        end
    end

    // 目标寄存器地址
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_waddr_r <= 5'b0;
        end else if (reg_write_valid_set) begin
            reg_waddr_r <= curr_rd_addr;
        end
    end

    // 提交ID
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_commit_id_r <= {`COMMIT_ID_WIDTH{1'b0}};
        end else if (reg_write_valid_set) begin
            current_commit_id_r <= curr_commit_id;
        end
    end

    // wait_for_bvalid寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_for_bvalid <= 1'b0;
        end else begin
            wait_for_bvalid <= wait_for_bvalid_nxt;
        end
    end

    // write_fifo_wr_ptr寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_fifo_wr_ptr <= {FIFO_PTR_WIDTH{1'b0}};
        end else if (write_fifo_wr_en) begin
            write_fifo_wr_ptr <= write_fifo_wr_ptr_nxt;
        end
    end

    // write_fifo_rd_ptr寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_fifo_rd_ptr <= {FIFO_PTR_WIDTH{1'b0}};
        end else if (write_fifo_rd_en) begin
            write_fifo_rd_ptr <= write_fifo_rd_ptr_nxt;
        end
    end

    // 实现读FIFO的有效位数组和数据
    generate
        for (genvar i = 0; i < FIFO_DEPTH; i = i + 1) begin : read_fifo_valid_gen
            wire read_fifo_valid_set = read_fifo_wr_en & (read_fifo_wr_ptr == i);
            wire read_fifo_valid_clear = read_fifo_rd_en & (read_fifo_rd_ptr == i);
            wire read_fifo_valid_nxt = (read_fifo_valid_set | (read_fifo_valid[i] & ~read_fifo_valid_clear));

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_valid[i] <= 1'b0;
                end else if (read_fifo_valid_set | read_fifo_valid_clear) begin
                    read_fifo_valid[i] <= read_fifo_valid_nxt;
                end
            end

            // 读请求数据寄存器
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_mem_op_lb[i] <= 1'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_mem_op_lb[i] <= mem_op_lb_i;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_mem_op_lh[i] <= 1'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_mem_op_lh[i] <= mem_op_lh_i;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_mem_op_lw[i] <= 1'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_mem_op_lw[i] <= mem_op_lw_i;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_mem_op_lbu[i] <= 1'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_mem_op_lbu[i] <= mem_op_lbu_i;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_mem_op_lhu[i] <= 1'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_mem_op_lhu[i] <= mem_op_lhu_i;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_rd_addr[i] <= 5'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_rd_addr[i] <= rd_addr_i;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_mem_addr_index[i] <= 2'b0;
                end else if (read_fifo_valid_set) begin
                    read_fifo_mem_addr_index[i] <= mem_addr_index;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    read_fifo_commit_id[i] <= {`COMMIT_ID_WIDTH{1'b0}};
                end else if (read_fifo_valid_set) begin
                    read_fifo_commit_id[i] <= commit_id_i;
                end
            end
        end
    endgenerate

    // 实现写FIFO的有效位数组和数据
    generate
        for (genvar i = 0; i < FIFO_DEPTH; i = i + 1) begin : write_fifo_valid_gen
            wire write_fifo_valid_set = write_fifo_wr_en & (write_fifo_wr_ptr == i);
            wire write_fifo_valid_clear = write_fifo_rd_en & (write_fifo_rd_ptr == i);
            wire write_fifo_valid_nxt = (write_fifo_valid_set | (write_fifo_valid[i] & ~write_fifo_valid_clear));

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    write_fifo_valid[i] <= 1'b0;
                end else if (write_fifo_valid_set | write_fifo_valid_clear) begin
                    write_fifo_valid[i] <= write_fifo_valid_nxt;
                end
            end

            // 写数据和掩码
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    write_fifo_data[i] <= 32'b0;
                end else if (write_fifo_valid_set) begin
                    write_fifo_data[i] <= mem_wdata;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    write_fifo_strb[i] <= 4'b0;
                end else if (write_fifo_valid_set) begin
                    write_fifo_strb[i] <= mem_wmask;
                end
            end
        end
    endgenerate

    // AXI接口信号赋值 - 使用与之前相同的逻辑
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
    assign commit_id_o   = current_commit_id_r;

endmodule