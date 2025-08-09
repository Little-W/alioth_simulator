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

// AXI 64位到32位适配器模块
// 用于连接64位总线到32位外设，通过地址第2位进行高低位选择
module axi_64to32_adapter #(
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    // 64位AXI Slave接口 (连接到LSU)
    input  wire [                       3:0] S_AXI_AWID,
    input  wire [    C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [                       7:0] S_AXI_AWLEN,
    input  wire [                       2:0] S_AXI_AWSIZE,
    input  wire [                       1:0] S_AXI_AWBURST,
    input  wire                              S_AXI_AWLOCK,
    input  wire [                       3:0] S_AXI_AWCACHE,
    input  wire [                       2:0] S_AXI_AWPROT,
    input  wire [                       3:0] S_AXI_AWQOS,
    input  wire [                       3:0] S_AXI_AWUSER,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,

    input  wire [                      63:0] S_AXI_WDATA,
    input  wire [                       7:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WLAST,
    input  wire [                       3:0] S_AXI_WUSER,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,

    output wire [                       3:0] S_AXI_BID,
    output wire [                       1:0] S_AXI_BRESP,
    output wire [                       3:0] S_AXI_BUSER,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,

    input  wire [                       3:0] S_AXI_ARID,
    input  wire [    C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [                       7:0] S_AXI_ARLEN,
    input  wire [                       2:0] S_AXI_ARSIZE,
    input  wire [                       1:0] S_AXI_ARBURST,
    input  wire                              S_AXI_ARLOCK,
    input  wire [                       3:0] S_AXI_ARCACHE,
    input  wire [                       2:0] S_AXI_ARPROT,
    input  wire [                       3:0] S_AXI_ARQOS,
    input  wire [                       3:0] S_AXI_ARUSER,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,

    output wire [                       3:0] S_AXI_RID,
    output wire [                      63:0] S_AXI_RDATA,
    output wire [                       1:0] S_AXI_RRESP,
    output wire                              S_AXI_RLAST,
    output wire [                       3:0] S_AXI_RUSER,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,

    // 32位AXI Master接口 (连接到外设)
    output wire [                       3:0] M_AXI_AWID,
    output wire [    C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output wire [                       7:0] M_AXI_AWLEN,
    output wire [                       2:0] M_AXI_AWSIZE,
    output wire [                       1:0] M_AXI_AWBURST,
    output wire                              M_AXI_AWLOCK,
    output wire [                       3:0] M_AXI_AWCACHE,
    output wire [                       2:0] M_AXI_AWPROT,
    output wire [                       3:0] M_AXI_AWQOS,
    output wire [                       3:0] M_AXI_AWUSER,
    output wire                              M_AXI_AWVALID,
    input  wire                              M_AXI_AWREADY,

    output wire [                      31:0] M_AXI_WDATA,
    output wire [                       3:0] M_AXI_WSTRB,
    output wire                              M_AXI_WLAST,
    output wire [                       3:0] M_AXI_WUSER,
    output wire                              M_AXI_WVALID,
    input  wire                              M_AXI_WREADY,

    input  wire [                       3:0] M_AXI_BID,
    input  wire [                       1:0] M_AXI_BRESP,
    input  wire [                       3:0] M_AXI_BUSER,
    input  wire                              M_AXI_BVALID,
    output wire                              M_AXI_BREADY,

    output wire [                       3:0] M_AXI_ARID,
    output wire [    C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                       7:0] M_AXI_ARLEN,
    output wire [                       2:0] M_AXI_ARSIZE,
    output wire [                       1:0] M_AXI_ARBURST,
    output wire                              M_AXI_ARLOCK,
    output wire [                       3:0] M_AXI_ARCACHE,
    output wire [                       2:0] M_AXI_ARPROT,
    output wire [                       3:0] M_AXI_ARQOS,
    output wire [                       3:0] M_AXI_ARUSER,
    output wire                              M_AXI_ARVALID,
    input  wire                              M_AXI_ARREADY,

    input  wire [                       3:0] M_AXI_RID,
    input  wire [                      31:0] M_AXI_RDATA,
    input  wire [                       1:0] M_AXI_RRESP,
    input  wire                              M_AXI_RLAST,
    input  wire [                       3:0] M_AXI_RUSER,
    input  wire                              M_AXI_RVALID,
    output wire                              M_AXI_RREADY
);

    // 地址第2位用于高低位选择
    wire addr_bit2_aw = S_AXI_AWADDR[2];  // 写地址的第2位
    wire addr_bit2_ar = S_AXI_ARADDR[2];  // 读地址的第2位

    // AXI写地址通道 - 直接传递，但清除地址第2位
    assign M_AXI_AWID     = S_AXI_AWID;
    assign M_AXI_AWADDR   = {S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH-1:3], 1'b0, S_AXI_AWADDR[1:0]};  // 清除第2位
    assign M_AXI_AWLEN    = S_AXI_AWLEN;
    assign M_AXI_AWSIZE   = 3'b010;  // 强制为32位访问 (4字节)
    assign M_AXI_AWBURST  = S_AXI_AWBURST;
    assign M_AXI_AWLOCK   = S_AXI_AWLOCK;
    assign M_AXI_AWCACHE  = S_AXI_AWCACHE;
    assign M_AXI_AWPROT   = S_AXI_AWPROT;
    assign M_AXI_AWQOS    = S_AXI_AWQOS;
    assign M_AXI_AWUSER   = S_AXI_AWUSER;
    assign M_AXI_AWVALID  = S_AXI_AWVALID;
    assign S_AXI_AWREADY  = M_AXI_AWREADY;

    // AXI写数据通道 - 根据地址第2位选择高低32位数据
    assign M_AXI_WDATA = addr_bit2_aw ? S_AXI_WDATA[63:32] : S_AXI_WDATA[31:0];
    assign M_AXI_WSTRB = addr_bit2_aw ? S_AXI_WSTRB[7:4]   : S_AXI_WSTRB[3:0];
    assign M_AXI_WLAST = S_AXI_WLAST;
    assign M_AXI_WUSER = S_AXI_WUSER;
    assign M_AXI_WVALID = S_AXI_WVALID;
    assign S_AXI_WREADY = M_AXI_WREADY;

    // AXI写响应通道 - 直接传递
    assign S_AXI_BID    = M_AXI_BID;
    assign S_AXI_BRESP  = M_AXI_BRESP;
    assign S_AXI_BUSER  = M_AXI_BUSER;
    assign S_AXI_BVALID = M_AXI_BVALID;
    assign M_AXI_BREADY = S_AXI_BREADY;

    // AXI读地址通道 - 直接传递，但清除地址第2位
    assign M_AXI_ARID     = S_AXI_ARID;
    assign M_AXI_ARADDR   = {S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:3], 1'b0, S_AXI_ARADDR[1:0]};  // 清除第2位
    assign M_AXI_ARLEN    = S_AXI_ARLEN;
    assign M_AXI_ARSIZE   = 3'b010;  // 强制为32位访问 (4字节)
    assign M_AXI_ARBURST  = S_AXI_ARBURST;
    assign M_AXI_ARLOCK   = S_AXI_ARLOCK;
    assign M_AXI_ARCACHE  = S_AXI_ARCACHE;
    assign M_AXI_ARPROT   = S_AXI_ARPROT;
    assign M_AXI_ARQOS    = S_AXI_ARQOS;
    assign M_AXI_ARUSER   = S_AXI_ARUSER;
    assign M_AXI_ARVALID  = S_AXI_ARVALID;
    assign S_AXI_ARREADY  = M_AXI_ARREADY;

    // AXI读数据通道 - 根据地址第2位将32位数据放到64位数据的正确位置
    assign S_AXI_RID   = M_AXI_RID;
    assign S_AXI_RDATA = addr_bit2_ar ? {M_AXI_RDATA, 32'h0} : {32'h0, M_AXI_RDATA};
    assign S_AXI_RRESP = M_AXI_RRESP;
    assign S_AXI_RLAST = M_AXI_RLAST;
    assign S_AXI_RUSER = M_AXI_RUSER;
    assign S_AXI_RVALID = M_AXI_RVALID;
    assign M_AXI_RREADY = S_AXI_RREADY;

endmodule
