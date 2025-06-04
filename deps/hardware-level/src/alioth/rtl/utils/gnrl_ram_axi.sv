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

// 带AXI接口的通用RAM模块
module gnrl_ram_axi #(
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
    output reg  [C_S_AXI_ID_WIDTH-1:0] S_AXI_BID,
    output reg  [                 1:0] S_AXI_BRESP,
    output reg                         S_AXI_BVALID,
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

    // AXI读写地址准备信号始终为1
    assign S_AXI_ARREADY = 1'b1;
    assign S_AXI_AWREADY = 1'b1;
    assign S_AXI_WREADY  = 1'b1;

    // 读地址通道处理
    reg  [  C_S_AXI_ID_WIDTH-1:0] axi_arid_r;
    reg  [                   7:0] axi_arlen;
    reg  [                   7:0] axi_arlen_cntr;
    reg  [                   1:0] axi_arburst;
    reg  [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg                           axi_ar_flag;

    // 写地址通道处理
    reg  [  C_S_AXI_ID_WIDTH-1:0] axi_awid_r;
    reg  [                   7:0] axi_awlen;
    reg  [                   1:0] axi_awburst;
    reg  [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg                           axi_aw_flag;

    // 写数据通道处理
    reg                           axi_w_flag;

    // 读数据通道处理
    reg                           axi_rvalid_ff;
    reg  [  C_S_AXI_ID_WIDTH-1:0] axi_rid_ff;
    reg  [                   7:0] axi_rlen_cntr;
    reg                           axi_rlast_ff;

    // RAM接口信号
    wire [        ADDR_WIDTH-1:0] ram_addr;
    wire [        DATA_WIDTH-1:0] ram_wdata;
    wire [                   3:0] ram_we_mask;
    wire                          ram_we;
    wire [        DATA_WIDTH-1:0] ram_rdata;

    // 读地址寄存器
    reg  [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_r;
    reg  [  C_S_AXI_ID_WIDTH-1:0] axi_arid_r;
    reg                           axi_arvalid_r;
    reg  [                   7:0] axi_arlen_r;
    reg                           axi_arlast_r;

    // 读响应控制信号 - 用于生成连续读请求的last信号
    reg  [                   7:0] axi_rlen_cntr;
    wire                          axi_rlast_signal;

    // AXI读地址通道处理 - 简化版本
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_ar_flag    <= 1'b0;
            axi_arid_r     <= 'b0;
            axi_araddr     <= 'b0;
            axi_arlen      <= 8'b0;
            axi_arburst    <= 2'b0;
            axi_arlen_cntr <= 8'b0;

            // 读请求寄存器复位
            axi_araddr_r   <= 'b0;
            axi_arid_r     <= 'b0;
            axi_arvalid_r  <= 1'b0;
            axi_arlen_r    <= 8'b0;
            axi_arlast_r   <= 1'b0;
        end else begin
            // 存储读请求信息 - 直接保存，不再使用流水线
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                axi_araddr_r <= S_AXI_ARADDR;
                axi_arid_r <= S_AXI_ARID;
                axi_arvalid_r <= 1'b1;
                axi_arlen_r <= S_AXI_ARLEN;
                axi_arlast_r   <= (S_AXI_ARLEN == 8'b0); // 如果长度为0，则是最后一笔

                // 保存burst信息用于后续访问
                axi_ar_flag <= 1'b1;
                axi_araddr <= S_AXI_ARADDR;
                axi_arlen <= S_AXI_ARLEN;
                axi_arburst <= S_AXI_ARBURST;
                axi_arlen_cntr <= 8'b0;
            end else begin
                axi_arvalid_r <= 1'b0;
            end

            // 处理读传输计数
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                if (axi_arlen_cntr < axi_arlen) begin
                    axi_arlen_cntr <= axi_arlen_cntr + 1;

                    // 更新下一个读地址，基于burst类型
                    if (axi_arburst == 2'b01) begin  // INCR burst
                        axi_araddr <= axi_araddr + (1 << ADDR_LSB);
                    end
                end else begin
                    axi_ar_flag <= 1'b0;
                end
            end
        end
    end

    // AXI读数据通道处理 - 简化版本，改为仅更新控制信号
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rlen_cntr <= 8'b0;
        end else begin
            // 处理burst传输的计数器
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                if (axi_rlen_cntr < axi_arlen) begin
                    axi_rlen_cntr <= axi_rlen_cntr + 1;
                end else begin
                    axi_rlen_cntr <= 8'b0;
                end
            end
        end
    end

    // 生成RLAST信号的逻辑
    assign axi_rlast_signal = (axi_arlen == 0) ? axi_arvalid_r : 
                              (axi_rlen_cntr == axi_arlen) && axi_arvalid_r;

    // 直接将RAM读取数据和响应信号通过连线连接到AXI读通道，保证同步
    assign S_AXI_RDATA = ram_rdata;
    assign S_AXI_RVALID = axi_arvalid_r;
    assign S_AXI_RID = axi_arid_r;
    assign S_AXI_RRESP = 2'b00;  // OKAY
    assign S_AXI_RLAST = axi_rlast_signal;

    // AXI写地址通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_aw_flag <= 1'b0;
            axi_awid_r  <= 'b0;
            axi_awaddr  <= 'b0;
            axi_awlen   <= 8'b0;
            axi_awburst <= 2'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY && !axi_aw_flag) begin
                axi_aw_flag <= 1'b1;
                axi_awid_r  <= S_AXI_AWID;
                axi_awaddr  <= S_AXI_AWADDR;
                axi_awlen   <= S_AXI_AWLEN;
                axi_awburst <= S_AXI_AWBURST;
            end else if (S_AXI_WLAST && S_AXI_WVALID && S_AXI_WREADY && axi_aw_flag) begin
                axi_aw_flag <= 1'b0;
            end
        end
    end

    // AXI写数据通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_w_flag     <= 1'b0;
            wlast_received <= 1'b0;
        end else begin
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
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BID    <= 'b0;
            S_AXI_BRESP  <= 2'b0;
        end else begin
            if (wlast_received && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BID    <= axi_awid_r;
                S_AXI_BRESP  <= 2'b00;  // OKAY
            end else if (S_AXI_BREADY && S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // RAM地址和数据映射
    // 将AXI地址映射到RAM地址
    assign ram_addr = (S_AXI_WVALID && S_AXI_WREADY) ? S_AXI_AWADDR[ADDR_WIDTH-1:0] : axi_araddr_r[ADDR_WIDTH-1:0];
    assign ram_wdata = S_AXI_WDATA;
    assign ram_we_mask = S_AXI_WSTRB;
    assign ram_we = (S_AXI_WVALID && S_AXI_WREADY) ? 1'b1 : 1'b0;

    // 实例化RAM
    gnrl_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INIT_MEM  (INIT_MEM),
        .INIT_FILE (INIT_FILE)
    ) ram_inst (
        .clk      (S_AXI_ACLK),
        .rst_n    (S_AXI_ARESETN),
        .we_i     (ram_we),
        .we_mask_i(ram_we_mask),
        .addr_i   (ram_addr),
        .data_i   (ram_wdata),
        .data_o   (ram_rdata)
    );

endmodule
