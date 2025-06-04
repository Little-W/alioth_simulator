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

    // 读响应控制信号
    reg  [                   7:0] axi_rlen_cntr;
    wire                          axi_rlast_signal;
    reg                           axi_arvalid_r;
    reg  [  C_S_AXI_ID_WIDTH-1:0] axi_arid_pipe;

    // 写入完成指示
    reg                           wlast_received;

    // AXI读地址通道处理
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_ar_flag    <= 1'b0;
            axi_arid_r     <= 'b0;
            axi_araddr     <= 'b0;
            axi_arlen      <= 8'b0;
            axi_arburst    <= 2'b0;
            axi_arlen_cntr <= 8'b0;
            axi_arvalid_r  <= 1'b0;
            axi_arid_pipe  <= 'b0;
        end else begin
            // 存储读请求信息
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                axi_arvalid_r  <= 1'b1;
                axi_arid_pipe  <= S_AXI_ARID;

                // 保存burst信息用于后续访问
                axi_ar_flag    <= 1'b1;
                axi_arid_r     <= S_AXI_ARID;
                axi_araddr     <= S_AXI_ARADDR;
                axi_arlen      <= S_AXI_ARLEN;
                axi_arburst    <= S_AXI_ARBURST;
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
                    axi_ar_flag    <= 1'b0;
                    axi_arlen_cntr <= 8'b0;
                end
            end
        end
    end

    // 生成RLAST信号的逻辑
    assign axi_rlast_signal = (axi_arlen == 0) ? axi_arvalid_r : 
                             (axi_arlen_cntr == axi_arlen) && axi_arvalid_r;

    // AXI读数据通道信号
    assign S_AXI_RVALID = axi_arvalid_r;
    assign S_AXI_RID = axi_arid_pipe;
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
    assign ram_waddr   = S_AXI_AWADDR[ADDR_WIDTH-1:0];
    assign ram_wdata   = S_AXI_WDATA;
    assign ram_we_mask = S_AXI_WSTRB;
    assign ram_we      = (S_AXI_WVALID && S_AXI_WREADY) ? 1'b1 : 1'b0;

    // 读逻辑连接
    assign ram_raddr   = axi_araddr[ADDR_WIDTH-1:0];

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
