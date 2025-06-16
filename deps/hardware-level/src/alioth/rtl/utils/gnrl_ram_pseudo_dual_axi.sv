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

// 带AXI接口的伪双端口RAM模块
module gnrl_ram_pseudo_dual_axi #(
    parameter ADDR_WIDTH = 16,  // 地址宽度参数
    parameter DATA_WIDTH = 32,  // 数据宽度参数
    parameter INIT_MEM = 1,           // 是否初始化内存，1表示初始化，0表示不初始化
    parameter INIT_FILE = "prog.mem",  // 初始化文件路径

    // AXI接口参数
    parameter integer C_S_AXI_ID_WIDTH   = 4,   // AXI ID宽度
    parameter integer C_S_AXI_DATA_WIDTH = 32,  // AXI数据宽度
    parameter integer C_S_AXI_ADDR_WIDTH = 16   // AXI地址宽度
) (
    // 全局时钟和复位信号
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,

    // AXI写地址通道
    input  wire [  C_S_AXI_ID_WIDTH-1:0] S_AXI_AWID,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [                   7:0] S_AXI_AWLEN,
    input  wire [                   2:0] S_AXI_AWSIZE,
    input  wire [                   1:0] S_AXI_AWBURST,
    input  wire                          S_AXI_AWLOCK,
    input  wire [                   3:0] S_AXI_AWCACHE,
    input  wire [                   2:0] S_AXI_AWPROT,
    input  wire                          S_AXI_AWVALID,
    output wire                          S_AXI_AWREADY,

    // AXI写数据通道
    input  wire [    C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WLAST,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,

    // AXI写响应通道
    output wire [C_S_AXI_ID_WIDTH-1:0] S_AXI_BID,
    output wire [                 1:0] S_AXI_BRESP,
    output wire                        S_AXI_BVALID,
    input  wire                        S_AXI_BREADY,

    // AXI读地址通道
    input  wire [  C_S_AXI_ID_WIDTH-1:0] S_AXI_ARID,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [                   7:0] S_AXI_ARLEN,
    input  wire [                   2:0] S_AXI_ARSIZE,
    input  wire [                   1:0] S_AXI_ARBURST,
    input  wire                          S_AXI_ARLOCK,
    input  wire [                   3:0] S_AXI_ARCACHE,
    input  wire [                   2:0] S_AXI_ARPROT,
    input  wire                          S_AXI_ARVALID,
    output wire                          S_AXI_ARREADY,

    // AXI读数据通道
    output wire [  C_S_AXI_ID_WIDTH-1:0] S_AXI_RID,
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [                   1:0] S_AXI_RRESP,
    output wire                          S_AXI_RLAST,
    output wire                          S_AXI_RVALID,
    input  wire                          S_AXI_RREADY
);

    // ADDR_LSB用于字节寻址转换为字寻址
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;

    // 定义FIFO深度和指针位宽
    localparam integer FIFO_DEPTH = 4;
    localparam integer PTR_WIDTH = $clog2(FIFO_DEPTH);

    // 读FIFO相关信号定义
    reg [PTR_WIDTH-1:0] rfifo_rd_ptr;
    reg [PTR_WIDTH-1:0] rfifo_wr_ptr;
    reg [PTR_WIDTH:0] fifo_count;
    reg [C_S_AXI_ADDR_WIDTH-1:0] fifo_addr[0:FIFO_DEPTH-1];
    reg [C_S_AXI_ID_WIDTH-1:0] fifo_id[0:FIFO_DEPTH-1];  // 添加FIFO ID存储
    wire [1:0] rd_fifo_op;

    // 写FIFO相关信号定义
    reg [PTR_WIDTH-1:0] wfifo_rd_ptr;
    reg [PTR_WIDTH-1:0] wfifo_wr_ptr;
    reg [PTR_WIDTH:0] wr_fifo_count;
    reg [C_S_AXI_ADDR_WIDTH-1:0] wr_fifo_addr[0:FIFO_DEPTH-1];
    reg  [  C_S_AXI_ID_WIDTH-1:0] wr_fifo_id       [0:FIFO_DEPTH-1]; // 添加写FIFO ID存储
    wire [1:0] wr_fifo_op;

    // 读通道相关信号
    reg [C_S_AXI_ID_WIDTH-1:0] axi_arid_r;
    reg [7:0] axi_arlen;
    reg [7:0] axi_arlen_cntr;
    reg [1:0] axi_arburst;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_ar_flag;
    wire axi_rlast_signal;

    // 写通道相关信号
    reg [C_S_AXI_ID_WIDTH-1:0] axi_awid_r;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_next;
    reg [7:0] axi_awlen;
    reg [7:0] axi_awlen_cntr;
    reg [1:0] axi_awburst;
    reg axi_aw_flag;
    reg axi_w_flag;
    reg wlast_received;
    reg wvalid_r;  // 增加一个寄存器保存上一个周期的WVALID

    // 添加burst相关的辅助函数和信号
    wire [C_S_AXI_ADDR_WIDTH-1:0] wrap_boundary;
    wire [C_S_AXI_ADDR_WIDTH-1:0] next_addr;
    wire [C_S_AXI_ADDR_WIDTH-1:0] addr_increment;

    // 读操作的wrap相关信号
    wire [C_S_AXI_ADDR_WIDTH-1:0] ar_wrap_size;
    wire ar_wrap_en;

    // 写操作的wrap相关信号  
    wire [C_S_AXI_ADDR_WIDTH-1:0] aw_wrap_size;
    wire aw_wrap_en;

    // 计算地址增量（基于传输大小）
    assign addr_increment = (1 << ADDR_LSB);

    // 读操作wrap边界计算
    assign ar_wrap_size = ((axi_arlen + 1) * addr_increment);
    assign ar_wrap_en = ((axi_araddr & ar_wrap_size) == ar_wrap_size);

    // 写操作wrap边界计算
    assign aw_wrap_size = ((axi_awlen + 1) * addr_increment);
    assign aw_wrap_en = ((axi_awaddr_next & aw_wrap_size) == aw_wrap_size);

    // FIFO操作控制：{push, pop}
    assign rd_fifo_op = {
        S_AXI_ARVALID && S_AXI_ARREADY,  // 推入操作条件 [1]
        S_AXI_RVALID && S_AXI_RREADY && S_AXI_RLAST  // 弹出操作条件 [0]
    };

    // 写FIFO操作控制: {push, pop}
    assign wr_fifo_op = {
        S_AXI_AWVALID && S_AXI_AWREADY,  // 写地址有效并握手完成 - 推入操作条件 [1]
        S_AXI_WVALID && S_AXI_WREADY     // 写数据输入有效且握手完成 - 弹出操作条件 [0]
    };

    // 读地址通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rfifo_rd_ptr <= 0;
            rfifo_wr_ptr <= 0;
            fifo_count   <= 0;
        end else begin
            // 处理FIFO推入和弹出
            case (rd_fifo_op)
                2'b10: begin  // 只推入
                    fifo_addr[rfifo_wr_ptr] <= S_AXI_ARADDR;  // 保存读请求地址
                    fifo_id[rfifo_wr_ptr] <= S_AXI_ARID;  // 保存读请求ID
                    rfifo_wr_ptr <= rfifo_wr_ptr + 1'd1;  // 循环指针
                    fifo_count <= fifo_count + 1'd1;
                end
                2'b01: begin  // 只弹出
                    rfifo_rd_ptr <= rfifo_rd_ptr + 1'd1;  // 循环指针
                    fifo_count   <= fifo_count - 1'd1;
                end
                2'b11: begin  // 同时推入和弹出
                    fifo_addr[rfifo_wr_ptr] <= S_AXI_ARADDR;  // 保存读请求地址
                    fifo_id[rfifo_wr_ptr] <= S_AXI_ARID;  // 保存读请求ID
                    rfifo_wr_ptr <= rfifo_wr_ptr + 1'd1;
                    rfifo_rd_ptr <= rfifo_rd_ptr + 1'd1;
                    // fifo_count保持不变
                end
                default: begin  // 2'b00: 无操作
                    // 保持当前状态
                end
            endcase

            // 处理读传输计数
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                if (axi_arlen_cntr < axi_arlen) begin
                    // 同步更新FIFO中读指针位置的地址，确保burst传输中地址同步更新
                    fifo_addr[rfifo_rd_ptr] <= axi_araddr;
                    // ID在burst传输中保持不变，不需要更新
                end
            end
        end
    end

    // 读地址通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_ar_flag    <= 1'b0;
            axi_arid_r     <= 'b0;
            axi_araddr     <= 'b0;
            axi_arlen      <= 8'b0;
            axi_arburst    <= 2'b0;
            axi_arlen_cntr <= 8'b0;
            // 删除 axi_arvalid_r 的复位
        end else begin
            // 存储读请求信息
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                // 删除 axi_arvalid_r 的赋值
                
                // 保存burst信息用于后续访问
                axi_ar_flag    <= 1'b1;
                axi_arid_r     <= S_AXI_ARID;
                axi_araddr     <= S_AXI_ARADDR + addr_increment;
                axi_arlen      <= S_AXI_ARLEN;
                axi_arburst    <= S_AXI_ARBURST;
                axi_arlen_cntr <= 8'b0;
            end else begin
                // 删除 axi_arvalid_r 的赋值
            end

            // 处理读传输计数和地址更新
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                if (axi_arlen_cntr < axi_arlen) begin
                    axi_arlen_cntr <= axi_arlen_cntr + 1;

                    // 基于burst类型更新下一个读地址
                    case (axi_arburst)
                        2'b00: begin  // FIXED burst - 地址保持不变
                            // axi_araddr保持不变
                        end
                        2'b01: begin  // INCR burst - 地址递增
                            axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                            axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                        end
                        2'b10: begin  // Wrapping burst
                            // The read address wraps when the address reaches wrap boundary
                            if (ar_wrap_en) begin
                                axi_araddr <= (axi_araddr - ar_wrap_size);
                            end else begin
                                axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                                //araddr aligned to 4 byte boundary
                                axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                            end
                        end
                        default: begin  // 保留类型，按INCR处理
                            axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                            axi_araddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                        end
                    endcase

                end else begin
                    axi_ar_flag    <= 1'b0;
                    axi_arlen_cntr <= 8'b0;
                end
            end
        end
    end

    // 生成RLAST信号的逻辑，如果当前传输计数等于总长度，则表示这是最后一个数据
    assign axi_rlast_signal = (axi_arlen_cntr == axi_arlen) ? 1'b1 : 1'b0;

    // AXI读数据通道信号 - 修改为FIFO不为空时始终有效
    assign S_AXI_RVALID = (fifo_count > 0);
    assign S_AXI_RID = fifo_id[rfifo_rd_ptr];  // 使用FIFO中保存的ID
    assign S_AXI_RRESP = 2'b00;  // OKAY
    assign S_AXI_RLAST = axi_rlast_signal;

    // 添加S_AXI_ARREADY的赋值逻辑
    // 当FIFO未满且当前没有正在进行的BURST传输时才接受新的读请求
    assign S_AXI_ARREADY = (fifo_count < FIFO_DEPTH) && S_AXI_RLAST;

    // 修改S_AXI_AWREADY的赋值逻辑，支持outstanding写入
    // 当写地址FIFO未满时才接受新的写请求
    assign S_AXI_AWREADY = (wr_fifo_count < FIFO_DEPTH);

    // 修改S_AXI_WREADY的赋值逻辑，通过寄存器延迟一个周期
    assign S_AXI_WREADY = wvalid_r;

    // AXI写地址通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_aw_flag     <= 1'b0;
            axi_awid_r      <= 'b0;
            axi_awaddr      <= 'b0;
            axi_awaddr_next <= 'b0;
            axi_awlen       <= 8'b0;
            axi_awlen_cntr  <= 8'b0;
            axi_awburst     <= 2'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY && !axi_aw_flag) begin
                axi_aw_flag     <= 1'b1;
                axi_awid_r      <= S_AXI_AWID;
                axi_awaddr      <= S_AXI_AWADDR;
                axi_awaddr_next <= S_AXI_AWADDR;
                axi_awlen       <= S_AXI_AWLEN;
                axi_awlen_cntr  <= 8'b0;
                axi_awburst     <= S_AXI_AWBURST;
            end else if (S_AXI_WVALID && S_AXI_WREADY && axi_aw_flag) begin
                if (axi_awlen_cntr < axi_awlen) begin
                    axi_awlen_cntr <= axi_awlen_cntr + 1;

                    // 基于burst类型更新写地址
                    case (axi_awburst)
                        2'b00: begin  // FIXED burst - 地址保持不变
                            // axi_awaddr_next保持不变
                        end
                        2'b01: begin  // INCR burst - 地址递增
                            axi_awaddr_next[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr_next[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                            axi_awaddr_next[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                        end
                        2'b10: begin  // Wrapping burst
                            // The write address wraps when the address reaches wrap boundary
                            if (aw_wrap_en) begin
                                axi_awaddr_next <= (axi_awaddr_next - aw_wrap_size);
                            end else begin
                                axi_awaddr_next[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr_next[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                                //awaddr aligned to 4 byte boundary
                                axi_awaddr_next[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                            end
                        end
                        default: begin
                            axi_awaddr_next[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr_next[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                            axi_awaddr_next[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
                        end
                    endcase
                end

                if (S_AXI_WLAST) begin
                    axi_aw_flag    <= 1'b0;
                    axi_awlen_cntr <= 8'b0;
                end
            end
        end
    end

    // 写FIFO处理逻辑
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            wfifo_rd_ptr  <= 0;
            wfifo_wr_ptr  <= 0;
            wr_fifo_count <= 0;
        end else begin
            // 处理写FIFO推入和弹出
            case (wr_fifo_op)
                2'b10: begin  // 只推入
                    wr_fifo_addr[wfifo_wr_ptr] <= S_AXI_AWADDR;  // 保存写请求地址
                    wr_fifo_id[wfifo_wr_ptr] <= S_AXI_AWID;  // 保存写请求ID
                    wfifo_wr_ptr <= wfifo_wr_ptr + 1'd1;  // 循环指针
                    wr_fifo_count <= wr_fifo_count + 1'd1;
                end
                2'b01: begin  // 只弹出
                    wfifo_rd_ptr  <= wfifo_rd_ptr + 1'd1;  // 循环指针
                    wr_fifo_count <= wr_fifo_count - 1'd1;
                end
                2'b11: begin  // 同时推入和弹出
                    wr_fifo_addr[wfifo_wr_ptr] <= S_AXI_AWADDR;  // 保存写请求地址
                    wr_fifo_id[wfifo_wr_ptr] <= S_AXI_AWID;  // 保存写请求ID
                    wfifo_wr_ptr <= wfifo_wr_ptr + 1'd1;
                    wfifo_rd_ptr <= wfifo_rd_ptr + 1'd1;
                    // wr_fifo_count保持不变
                end
                default: begin  // 2'b00: 无操作
                    // 保持当前状态
                end
            endcase
        end
    end

    // AXI写数据通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_w_flag     <= 1'b0;
            wlast_received <= 1'b0;
            wvalid_r       <= 1'b0;  // 初始化寄存器
        end else begin
            // 寄存S_AXI_WVALID信号延迟一拍作为S_AXI_WREADY
            wvalid_r <= S_AXI_WVALID;

            if (S_AXI_WVALID && S_AXI_WREADY && !axi_w_flag) begin
                axi_w_flag <= 1'b1;
            end

            if (S_AXI_WLAST && S_AXI_WVALID && S_AXI_WREADY) begin
                wlast_received <= 1'b1;
                axi_w_flag     <= 1'b0;
            end else if (S_AXI_BREADY && S_AXI_BVALID) begin
                wlast_received <= 1'b0;
            end
        end
    end

    // AXI写响应通道处理
    reg [C_S_AXI_ID_WIDTH-1:0] bvalid_id;
    reg                        bvalid;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            bvalid    <= 1'b0;
            bvalid_id <= 'b0;
        end else begin
            if (wlast_received && !bvalid) begin
                bvalid    <= 1'b1;
                bvalid_id <= axi_awid_r;
            end else if (S_AXI_BREADY && bvalid) begin
                bvalid <= 1'b0;
            end
        end
    end

    assign S_AXI_BVALID = bvalid;
    assign S_AXI_BID    = bvalid_id;
    assign S_AXI_BRESP  = 2'b00;  // OKAY

    // RAM接口信号
    wire [ADDR_WIDTH-1:0] ram_waddr;
    wire [ADDR_WIDTH-1:0] ram_raddr;
    wire [DATA_WIDTH-1:0] ram_wdata;
    wire [           3:0] ram_we_mask;
    wire                  ram_we;
    wire [DATA_WIDTH-1:0] ram_rdata;

    // 写逻辑连接
    assign ram_waddr = (wr_fifo_count > 0) ? 
                       wr_fifo_addr[wfifo_rd_ptr][ADDR_WIDTH-1:0] : 
                       S_AXI_AWADDR[ADDR_WIDTH-1:0];
    assign ram_wdata = S_AXI_WDATA;
    assign ram_we_mask = S_AXI_WSTRB;
    assign ram_we = (S_AXI_WVALID && S_AXI_WREADY) ? 1'b1 : 1'b0;

    // 读逻辑连接 - 修改为直接使用输入地址、burst地址或FIFO中的地址
    // 当有新的地址有效时，直接使用输入地址；
    // 当处于burst传输中时，使用axi_araddr；
    // 其他情况使用FIFO中的地址
    assign ram_raddr = (S_AXI_ARVALID && S_AXI_ARREADY) ? 
                       S_AXI_ARADDR[ADDR_WIDTH-1:0] : 
                       (axi_arlen > 0 && axi_arlen_cntr > 0) ? 
                       axi_araddr[ADDR_WIDTH-1:0] : 
                       fifo_addr[rfifo_rd_ptr][ADDR_WIDTH-1:0];

    // 直接将RAM读取数据连接到AXI读数据通道
    assign S_AXI_RDATA = ram_rdata;

    // 实例化伪双端口RAM
    gnrl_ram_pseudo_dual #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INIT_MEM  (INIT_MEM),
        .INIT_FILE (INIT_FILE)
    ) ram_inst (
        .clk      (S_AXI_ACLK),
        .rst_n    (S_AXI_ARESETN),
        .we_i     (ram_we),
        .we_mask_i(ram_we_mask),
        .waddr_i  (ram_waddr),
        .data_i   (ram_wdata),
        .raddr_i  (ram_raddr),
        .data_o   (ram_rdata)
    );

endmodule

