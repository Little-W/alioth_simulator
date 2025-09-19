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

// AXI 1对多 Crossbar
module axi_crossbar #(
    parameter int IMEM_ADDR_WIDTH = 16,  // IMEM地址宽度
    parameter int DMEM_ADDR_WIDTH = 16,  // DMEM地址宽度
    parameter int DATA_WIDTH      = 32,  // RAM数据宽度

    // AXI接口参数
    parameter int C_AXI_ID_WIDTH   = 2,   // AXI ID宽度
    parameter int C_AXI_DATA_WIDTH = 32,  // AXI数据宽度
    parameter int C_AXI_ADDR_WIDTH = 32,  // AXI地址宽度

    // APB AXI-Lite接口参数
    parameter int C_OM0_AXI_ADDR_WIDTH = 32,  // APB AXI-Lite 地址宽度
    parameter int C_OM0_AXI_DATA_WIDTH = 32,  // APB AXI-Lite 数据宽度
    // CLINT AXI-Lite接口参数
    parameter int C_OM1_AXI_ADDR_WIDTH = 32,  // CLINT AXI-Lite 地址宽度
    parameter int C_OM1_AXI_DATA_WIDTH = 32,  // CLINT AXI-Lite 数据宽度
    // PLIC AXI-Lite接口参数
    parameter int C_OM2_AXI_ADDR_WIDTH = 32,  // PLIC AXI-Lite 地址宽度
    parameter int C_OM2_AXI_DATA_WIDTH = 32   // PLIC AXI-Lite 数据宽度
) (
    // 全局信号
    input wire clk,   // 时钟信号
    input wire rst_n, // 复位信号（低有效）

    // 单一AXI Master输入接口 (Slave side of the crossbar)
    // AXI写地址通道
    input  wire [  C_AXI_ID_WIDTH-1:0] S_AXI_AWID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [                 7:0] S_AXI_AWLEN,
    input  wire [                 2:0] S_AXI_AWSIZE,
    input  wire [                 1:0] S_AXI_AWBURST,
    input  wire                        S_AXI_AWLOCK,
    input  wire [                 3:0] S_AXI_AWCACHE,
    input  wire [                 2:0] S_AXI_AWPROT,
    input  wire [                 3:0] S_AXI_AWQOS,
    input  wire [                 3:0] S_AXI_AWUSER,
    input  wire                        S_AXI_AWVALID,
    output wire                        S_AXI_AWREADY,

    // AXI写数据通道
    input  wire [    C_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                            S_AXI_WLAST,
    input  wire                            S_AXI_WVALID,
    output wire                            S_AXI_WREADY,

    // AXI写响应通道
    output wire [C_AXI_ID_WIDTH-1:0] S_AXI_BID,
    output wire [               1:0] S_AXI_BRESP,
    output wire                      S_AXI_BVALID,
    input  wire                      S_AXI_BREADY,

    // AXI读地址通道
    input  wire [  C_AXI_ID_WIDTH-1:0] S_AXI_ARID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [                 7:0] S_AXI_ARLEN,
    input  wire [                 2:0] S_AXI_ARSIZE,
    input  wire [                 1:0] S_AXI_ARBURST,
    input  wire                        S_AXI_ARLOCK,
    input  wire [                 3:0] S_AXI_ARCACHE,
    input  wire [                 2:0] S_AXI_ARPROT,
    input  wire [                 3:0] S_AXI_ARQOS,
    input  wire [                 3:0] S_AXI_ARUSER,
    input  wire                        S_AXI_ARVALID,
    output wire                        S_AXI_ARREADY,

    // AXI读数据通道
    output wire [  C_AXI_ID_WIDTH-1:0] S_AXI_RID,
    output wire [C_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [                 1:0] S_AXI_RRESP,
    output wire                        S_AXI_RLAST,
    output wire [                 3:0] S_AXI_RUSER,
    output wire                        S_AXI_RVALID,
    input  wire                        S_AXI_RREADY,

    // APB AXI-lite 接口
    output wire                                  OM0_AXI_ACLK,
    output wire                                  OM0_AXI_ARESETN,
    output wire [    C_OM0_AXI_ADDR_WIDTH-1 : 0] OM0_AXI_AWADDR,
    output wire [                         2 : 0] OM0_AXI_AWPROT,
    output wire                                  OM0_AXI_AWVALID,
    input  wire                                  OM0_AXI_AWREADY,
    output wire [    C_OM0_AXI_DATA_WIDTH-1 : 0] OM0_AXI_WDATA,
    output wire [(C_OM0_AXI_DATA_WIDTH/8)-1 : 0] OM0_AXI_WSTRB,
    output wire                                  OM0_AXI_WVALID,
    input  wire                                  OM0_AXI_WREADY,
    input  wire [                         1 : 0] OM0_AXI_BRESP,
    input  wire                                  OM0_AXI_BVALID,
    output wire                                  OM0_AXI_BREADY,
    output wire [    C_OM0_AXI_ADDR_WIDTH-1 : 0] OM0_AXI_ARADDR,
    output wire [                         2 : 0] OM0_AXI_ARPROT,
    output wire                                  OM0_AXI_ARVALID,
    input  wire                                  OM0_AXI_ARREADY,
    input  wire [    C_OM0_AXI_DATA_WIDTH-1 : 0] OM0_AXI_RDATA,
    input  wire [                         1 : 0] OM0_AXI_RRESP,
    input  wire                                  OM0_AXI_RVALID,
    output wire                                  OM0_AXI_RREADY,
    // CLINT AXI-lite 接口
    output wire                                  OM1_AXI_ACLK,
    output wire                                  OM1_AXI_ARESETN,
    output wire [    C_OM1_AXI_ADDR_WIDTH-1 : 0] OM1_AXI_AWADDR,
    output wire [                         2 : 0] OM1_AXI_AWPROT,
    output wire                                  OM1_AXI_AWVALID,
    input  wire                                  OM1_AXI_AWREADY,
    output wire [    C_OM1_AXI_DATA_WIDTH-1 : 0] OM1_AXI_WDATA,
    output wire [(C_OM1_AXI_DATA_WIDTH/8)-1 : 0] OM1_AXI_WSTRB,
    output wire                                  OM1_AXI_WVALID,
    input  wire                                  OM1_AXI_WREADY,
    input  wire [                         1 : 0] OM1_AXI_BRESP,
    input  wire                                  OM1_AXI_BVALID,
    output wire                                  OM1_AXI_BREADY,
    output wire [    C_OM1_AXI_ADDR_WIDTH-1 : 0] OM1_AXI_ARADDR,
    output wire [                         2 : 0] OM1_AXI_ARPROT,
    output wire                                  OM1_AXI_ARVALID,
    input  wire                                  OM1_AXI_ARREADY,
    input  wire [    C_OM1_AXI_DATA_WIDTH-1 : 0] OM1_AXI_RDATA,
    input  wire [                         1 : 0] OM1_AXI_RRESP,
    input  wire                                  OM1_AXI_RVALID,
    output wire                                  OM1_AXI_RREADY,

    // PLIC AXI-lite 接口
    output wire                                  OM2_AXI_ACLK,
    output wire                                  OM2_AXI_ARESETN,
    output wire [    C_OM2_AXI_ADDR_WIDTH-1 : 0] OM2_AXI_AWADDR,
    output wire [                         2 : 0] OM2_AXI_AWPROT,
    output wire                                  OM2_AXI_AWVALID,
    input  wire                                  OM2_AXI_AWREADY,
    output wire [    C_OM2_AXI_DATA_WIDTH-1 : 0] OM2_AXI_WDATA,
    output wire [(C_OM2_AXI_DATA_WIDTH/8)-1 : 0] OM2_AXI_WSTRB,
    output wire                                  OM2_AXI_WVALID,
    input  wire                                  OM2_AXI_WREADY,
    input  wire [                         1 : 0] OM2_AXI_BRESP,
    input  wire                                  OM2_AXI_BVALID,
    output wire                                  OM2_AXI_BREADY,
    output wire [    C_OM2_AXI_ADDR_WIDTH-1 : 0] OM2_AXI_ARADDR,
    output wire [                         2 : 0] OM2_AXI_ARPROT,
    output wire                                  OM2_AXI_ARVALID,
    input  wire                                  OM2_AXI_ARREADY,
    input  wire [    C_OM2_AXI_DATA_WIDTH-1 : 0] OM2_AXI_RDATA,
    input  wire [                         1 : 0] OM2_AXI_RRESP,
    input  wire                                  OM2_AXI_RVALID,
    output wire                                  OM2_AXI_RREADY,

    // IMEM AXI接口 (指令存储器)
    // 写地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] IMEM_AXI_AWID,
    output wire [C_AXI_ADDR_WIDTH-1:0] IMEM_AXI_AWADDR,
    output wire [                 7:0] IMEM_AXI_AWLEN,
    output wire [                 2:0] IMEM_AXI_AWSIZE,
    output wire [                 1:0] IMEM_AXI_AWBURST,
    output wire                        IMEM_AXI_AWLOCK,
    output wire [                 3:0] IMEM_AXI_AWCACHE,
    output wire [                 2:0] IMEM_AXI_AWPROT,
    output wire                        IMEM_AXI_AWVALID,
    input  wire                        IMEM_AXI_AWREADY,

    // 写数据通道
    output wire [    C_AXI_DATA_WIDTH-1:0] IMEM_AXI_WDATA,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0] IMEM_AXI_WSTRB,
    output wire                            IMEM_AXI_WLAST,
    output wire                            IMEM_AXI_WVALID,
    input  wire                            IMEM_AXI_WREADY,

    // 写响应通道
    input  wire [C_AXI_ID_WIDTH-1:0] IMEM_AXI_BID,
    input  wire [               1:0] IMEM_AXI_BRESP,
    input  wire                      IMEM_AXI_BVALID,
    output wire                      IMEM_AXI_BREADY,

    // 读地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] IMEM_AXI_ARID,
    output wire [C_AXI_ADDR_WIDTH-1:0] IMEM_AXI_ARADDR,
    output wire [                 7:0] IMEM_AXI_ARLEN,
    output wire [                 2:0] IMEM_AXI_ARSIZE,
    output wire [                 1:0] IMEM_AXI_ARBURST,
    output wire                        IMEM_AXI_ARLOCK,
    output wire [                 3:0] IMEM_AXI_ARCACHE,
    output wire [                 2:0] IMEM_AXI_ARPROT,
    output wire                        IMEM_AXI_ARVALID,
    input  wire                        IMEM_AXI_ARREADY,

    // 读数据通道
    input  wire [  C_AXI_ID_WIDTH-1:0] IMEM_AXI_RID,
    input  wire [C_AXI_DATA_WIDTH-1:0] IMEM_AXI_RDATA,
    input  wire [                 1:0] IMEM_AXI_RRESP,
    input  wire                        IMEM_AXI_RLAST,
    input  wire                        IMEM_AXI_RVALID,
    output wire                        IMEM_AXI_RREADY,

    // DMEM AXI接口 (数据存储器)
    // 写地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] DMEM_AXI_AWID,
    output wire [C_AXI_ADDR_WIDTH-1:0] DMEM_AXI_AWADDR,
    output wire [                 7:0] DMEM_AXI_AWLEN,
    output wire [                 2:0] DMEM_AXI_AWSIZE,
    output wire [                 1:0] DMEM_AXI_AWBURST,
    output wire                        DMEM_AXI_AWLOCK,
    output wire [                 3:0] DMEM_AXI_AWCACHE,
    output wire [                 2:0] DMEM_AXI_AWPROT,
    output wire                        DMEM_AXI_AWVALID,
    input  wire                        DMEM_AXI_AWREADY,

    // 写数据通道
    output wire [    C_AXI_DATA_WIDTH-1:0] DMEM_AXI_WDATA,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0] DMEM_AXI_WSTRB,
    output wire                            DMEM_AXI_WLAST,
    output wire                            DMEM_AXI_WVALID,
    input  wire                            DMEM_AXI_WREADY,

    // 写响应通道
    input  wire [C_AXI_ID_WIDTH-1:0] DMEM_AXI_BID,
    input  wire [               1:0] DMEM_AXI_BRESP,
    input  wire                      DMEM_AXI_BVALID,
    output wire                      DMEM_AXI_BREADY,

    // 读地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] DMEM_AXI_ARID,
    output wire [C_AXI_ADDR_WIDTH-1:0] DMEM_AXI_ARADDR,
    output wire [                 7:0] DMEM_AXI_ARLEN,
    output wire [                 2:0] DMEM_AXI_ARSIZE,
    output wire [                 1:0] DMEM_AXI_ARBURST,
    output wire                        DMEM_AXI_ARLOCK,
    output wire [                 3:0] DMEM_AXI_ARCACHE,
    output wire [                 2:0] DMEM_AXI_ARPROT,
    output wire                        DMEM_AXI_ARVALID,
    input  wire                        DMEM_AXI_ARREADY,

    // 读数据通道
    input  wire [  C_AXI_ID_WIDTH-1:0] DMEM_AXI_RID,
    input  wire [C_AXI_DATA_WIDTH-1:0] DMEM_AXI_RDATA,
    input  wire [                 1:0] DMEM_AXI_RRESP,
    input  wire                        DMEM_AXI_RLAST,
    input  wire                        DMEM_AXI_RVALID,
    output wire                        DMEM_AXI_RREADY,

    // DM AXI接口 (Debug Module)
    // 写地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] DM_AXI_AWID,
    output wire [C_AXI_ADDR_WIDTH-1:0] DM_AXI_AWADDR,
    output wire [                 7:0] DM_AXI_AWLEN,
    output wire [                 2:0] DM_AXI_AWSIZE,
    output wire [                 1:0] DM_AXI_AWBURST,
    output wire                        DM_AXI_AWLOCK,
    output wire [                 3:0] DM_AXI_AWCACHE,
    output wire [                 2:0] DM_AXI_AWPROT,
    output wire                        DM_AXI_AWVALID,
    input  wire                        DM_AXI_AWREADY,

    // 写数据通道
    output wire [    C_AXI_DATA_WIDTH-1:0] DM_AXI_WDATA,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0] DM_AXI_WSTRB,
    output wire                            DM_AXI_WLAST,
    output wire                            DM_AXI_WVALID,
    input  wire                            DM_AXI_WREADY,

    // 写响应通道
    input  wire [C_AXI_ID_WIDTH-1:0] DM_AXI_BID,
    input  wire [               1:0] DM_AXI_BRESP,
    input  wire                      DM_AXI_BVALID,
    output wire                      DM_AXI_BREADY,

    // 读地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] DM_AXI_ARID,
    output wire [C_AXI_ADDR_WIDTH-1:0] DM_AXI_ARADDR,
    output wire [                 7:0] DM_AXI_ARLEN,
    output wire [                 2:0] DM_AXI_ARSIZE,
    output wire [                 1:0] DM_AXI_ARBURST,
    output wire                        DM_AXI_ARLOCK,
    output wire [                 3:0] DM_AXI_ARCACHE,
    output wire [                 2:0] DM_AXI_ARPROT,
    output wire                        DM_AXI_ARVALID,
    input  wire                        DM_AXI_ARREADY,

    // 读数据通道
    input  wire [  C_AXI_ID_WIDTH-1:0] DM_AXI_RID,
    input  wire [C_AXI_DATA_WIDTH-1:0] DM_AXI_RDATA,
    input  wire [                 1:0] DM_AXI_RRESP,
    input  wire                        DM_AXI_RLAST,
    input  wire                        DM_AXI_RVALID,
    output wire                        DM_AXI_RREADY
);

    // ==================== 参数定义和数组索引映射 ====================
    localparam int NumSlaves = 6;

    // 从机索引定义 - 用于数组索引
    localparam int ItcmIdx = 0;  // 指令存储器
    localparam int DtcmIdx = 1;  // 数据存储器
    localparam int ApbIdx = 2;  // APB桥
    localparam int ClintIdx = 3;  // 核心级中断控制器
    localparam int PlicIdx = 4;  // 平台级中断控制器
    localparam int DmIdx = 5;  // 调试模块

    // 基地址数组 - 按索引顺序对应各外设
    localparam logic [C_AXI_ADDR_WIDTH-1:0] BaseAddr[NumSlaves] = '{
        `ITCM_BASE_ADDR,  // [0] ITCM
        `DTCM_BASE_ADDR,  // [1] DTCM
        `APB_BASE_ADDR,  // [2] APB
        `CLINT_BASE_ADDR,  // [3] CLINT
        `PLIC_BASE_ADDR,  // [4] PLIC
        `DM_BASE_ADDR  // [5] DM
    };

    // ==================== 地址解码逻辑 ====================
    // 读地址解码数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] addr_decode_r;
    assign addr_decode_r[ItcmIdx]  = (S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH] ==
                                      BaseAddr[ItcmIdx][C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH]);
    assign addr_decode_r[DtcmIdx]  = (S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH] ==
                                      BaseAddr[DtcmIdx][C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH]);
    assign addr_decode_r[ApbIdx]   = (S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH] ==
                                      BaseAddr[ApbIdx][C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH]);
    assign addr_decode_r[ClintIdx] = (S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH] ==
                                      BaseAddr[ClintIdx][C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH]);
    assign addr_decode_r[PlicIdx]  = (S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH] ==
                                      BaseAddr[PlicIdx][C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH]);
    assign addr_decode_r[DmIdx]    = (S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`DM_ADDR_WIDTH] ==
                                      BaseAddr[DmIdx][C_AXI_ADDR_WIDTH-1:`DM_ADDR_WIDTH]);

    // 写地址解码数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] addr_decode_w;
    assign addr_decode_w[ItcmIdx]  = (S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH] ==
                                      BaseAddr[ItcmIdx][C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH]);
    assign addr_decode_w[DtcmIdx]  = (S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH] ==
                                      BaseAddr[DtcmIdx][C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH]);
    assign addr_decode_w[ApbIdx]   = (S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH] ==
                                      BaseAddr[ApbIdx][C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH]);
    assign addr_decode_w[ClintIdx] = (S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH] ==
                                      BaseAddr[ClintIdx][C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH]);
    assign addr_decode_w[PlicIdx]  = (S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH] ==
                                      BaseAddr[PlicIdx][C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH]);
    assign addr_decode_w[DmIdx]    = (S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`DM_ADDR_WIDTH] ==
                                      BaseAddr[DmIdx][C_AXI_ADDR_WIDTH-1:`DM_ADDR_WIDTH]);

    // ==================== 仲裁和选择信号数组 ====================
    // AR通道授权信号数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] ar_grant;

    // AW通道授权信号数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] aw_grant;

    // 各通道选择信号数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] select_r;  // 读数据通道选择
    wire [NumSlaves-1:0] select_w;  // 写数据通道选择
    wire [NumSlaves-1:0] select_b;  // 写响应通道选择

    // ==================== outstanding计数器和事务信号数组 ====================
    // Outstanding计数器输出数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [3:0] r_outstanding_cnt[NumSlaves];  // R通道outstanding计数器
    wire [3:0] w_outstanding_cnt[NumSlaves];  // W通道outstanding计数器
    wire [3:0] b_outstanding_cnt[NumSlaves];  // B通道outstanding计数器

    // 激活状态信号数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] has_active_r;  // R通道激活状态
    wire [NumSlaves-1:0] has_active_w;  // W通道激活状态
    wire [NumSlaves-1:0] has_active_b;  // B通道激活状态
    wire [NumSlaves-1:0] has_active_r_nxt;  // R通道下一周期激活状态
    wire [NumSlaves-1:0] has_active_w_nxt;  // W通道下一周期激活状态
    wire [NumSlaves-1:0] has_active_b_nxt;  // B通道下一周期激活状态

    // 事务信号数组 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    wire [NumSlaves-1:0] ar_trans;  // AR通道事务
    wire [NumSlaves-1:0] r_trans;  // R通道事务
    wire [NumSlaves-1:0] aw_trans;  // AW通道事务
    wire [NumSlaves-1:0] w_trans;  // W通道事务
    wire [NumSlaves-1:0] b_trans;  // B通道事务

    // AR通道事务信号赋值 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign ar_trans[ItcmIdx] = S_AXI_ARVALID && S_AXI_ARREADY && addr_decode_r[ItcmIdx];
    assign ar_trans[DtcmIdx] = S_AXI_ARVALID && S_AXI_ARREADY && addr_decode_r[DtcmIdx];
    assign ar_trans[ApbIdx] = S_AXI_ARVALID && S_AXI_ARREADY && addr_decode_r[ApbIdx];
    assign ar_trans[ClintIdx] = S_AXI_ARVALID && S_AXI_ARREADY && addr_decode_r[ClintIdx];
    assign ar_trans[PlicIdx] = S_AXI_ARVALID && S_AXI_ARREADY && addr_decode_r[PlicIdx];
    assign ar_trans[DmIdx] = S_AXI_ARVALID && S_AXI_ARREADY && addr_decode_r[DmIdx];

    // R通道事务信号赋值 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign r_trans[ItcmIdx] = S_AXI_RVALID && S_AXI_RREADY && S_AXI_RLAST && select_r[ItcmIdx];
    assign r_trans[DtcmIdx] = S_AXI_RVALID && S_AXI_RREADY && S_AXI_RLAST && select_r[DtcmIdx];
    assign r_trans[ApbIdx] = S_AXI_RVALID && S_AXI_RREADY && select_r[ApbIdx];  // AXI-Lite无RLAST
    assign r_trans[ClintIdx] = S_AXI_RVALID && S_AXI_RREADY && select_r[ClintIdx]; // AXI-Lite无RLAST
    assign r_trans[PlicIdx]  = S_AXI_RVALID && S_AXI_RREADY && select_r[PlicIdx]; // AXI-Lite无RLAST
    assign r_trans[DmIdx] = S_AXI_RVALID && S_AXI_RREADY && S_AXI_RLAST && select_r[DmIdx];

    // AW通道事务信号赋值 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign aw_trans[ItcmIdx] = S_AXI_AWVALID && S_AXI_AWREADY && addr_decode_w[ItcmIdx];
    assign aw_trans[DtcmIdx] = S_AXI_AWVALID && S_AXI_AWREADY && addr_decode_w[DtcmIdx];
    assign aw_trans[ApbIdx] = S_AXI_AWVALID && S_AXI_AWREADY && addr_decode_w[ApbIdx];
    assign aw_trans[ClintIdx] = S_AXI_AWVALID && S_AXI_AWREADY && addr_decode_w[ClintIdx];
    assign aw_trans[PlicIdx] = S_AXI_AWVALID && S_AXI_AWREADY && addr_decode_w[PlicIdx];
    assign aw_trans[DmIdx] = S_AXI_AWVALID && S_AXI_AWREADY && addr_decode_w[DmIdx];

    // W通道事务信号赋值 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign w_trans[ItcmIdx] = S_AXI_WVALID && IMEM_AXI_WREADY && select_w[ItcmIdx];
    assign w_trans[DtcmIdx] = S_AXI_WVALID && DMEM_AXI_WREADY && select_w[DtcmIdx];
    assign w_trans[ApbIdx] = S_AXI_WVALID && OM0_AXI_WREADY && select_w[ApbIdx];
    assign w_trans[ClintIdx] = S_AXI_WVALID && OM1_AXI_WREADY && select_w[ClintIdx];
    assign w_trans[PlicIdx] = S_AXI_WVALID && OM2_AXI_WREADY && select_w[PlicIdx];
    assign w_trans[DmIdx] = S_AXI_WVALID && DM_AXI_WREADY && select_w[DmIdx];

    // B通道事务信号赋值 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign b_trans[ItcmIdx] = IMEM_AXI_BVALID && S_AXI_BREADY && select_b[ItcmIdx];
    assign b_trans[DtcmIdx] = DMEM_AXI_BVALID && S_AXI_BREADY && select_b[DtcmIdx];
    assign b_trans[ApbIdx] = OM0_AXI_BVALID && S_AXI_BREADY && select_b[ApbIdx];
    assign b_trans[ClintIdx] = OM1_AXI_BVALID && S_AXI_BREADY && select_b[ClintIdx];
    assign b_trans[PlicIdx] = OM2_AXI_BVALID && S_AXI_BREADY && select_b[PlicIdx];
    assign b_trans[DmIdx] = DM_AXI_BVALID && S_AXI_BREADY && select_b[DmIdx];

    // ==================== 优先级跟踪寄存器 ====================
    // bit 0: ITCM, bit 1: DTCM, bit 2: APB, bit 3: CLINT, bit 4: PLIC, bit 5: DM
    reg  [5:0] slave_sel_r;  // 读通道优先级
    reg  [5:0] slave_sel_w;  // 写数据通道优先级
    reg  [5:0] slave_sel_b;  // 写响应通道优先级

    // 拼接变量用于case判断 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    // 当前周期激活状态
    wire [5:0] active_r = has_active_r;  // 读通道激活状态
    wire [5:0] active_w = has_active_w;  // 写通道激活状态
    wire [5:0] active_b = has_active_b;  // 写响应通道激活状态

    // 下一周期激活状态
    wire [5:0] active_r_nxt = has_active_r_nxt;  // 读通道下一周期激活状态
    wire [5:0] active_w_nxt = has_active_w_nxt;  // 写通道下一周期激活状态
    wire [5:0] active_b_nxt = has_active_b_nxt;  // 写响应通道下一周期激活状态

    // 读通道优先权切换逻辑 - case实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_sel_r <= 6'b000001;
        end else begin
            case (active_r_nxt)
                6'b000000: slave_sel_r <= 6'b000000;
                6'b000001: slave_sel_r <= 6'b000001;
                6'b000010: slave_sel_r <= 6'b000010;
                6'b000100: slave_sel_r <= 6'b000100;
                6'b001000: slave_sel_r <= 6'b001000;
                6'b010000: slave_sel_r <= 6'b010000;
                6'b100000: slave_sel_r <= 6'b100000;
                default:   slave_sel_r <= slave_sel_r;  // 多个同时有效时保持
            endcase
        end
    end

    // 写响应通道优先权切换逻辑 - 使用b通道nxt信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_sel_b <= 6'b000001;
        end else begin
            case (active_b_nxt)
                6'b000000: slave_sel_b <= 6'b000000;
                6'b000001: slave_sel_b <= 6'b000001;
                6'b000010: slave_sel_b <= 6'b000010;
                6'b000100: slave_sel_b <= 6'b000100;
                6'b001000: slave_sel_b <= 6'b001000;
                6'b010000: slave_sel_b <= 6'b010000;
                6'b100000: slave_sel_b <= 6'b100000;
                default:   slave_sel_b <= slave_sel_b;
            endcase
        end
    end

    // 写数据通道优先权切换逻辑 - 使用w通道nxt信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_sel_w <= 6'b000001;
        end else begin
            case (active_w_nxt)
                6'b000000: slave_sel_w <= 6'b000000;
                6'b000001: slave_sel_w <= 6'b000001;
                6'b000010: slave_sel_w <= 6'b000010;
                6'b000100: slave_sel_w <= 6'b000100;
                6'b001000: slave_sel_w <= 6'b001000;
                6'b010000: slave_sel_w <= 6'b010000;
                6'b100000: slave_sel_w <= 6'b100000;
                default:   slave_sel_w <= slave_sel_w;
            endcase
        end
    end

    // ==================== 事务计数器模块实例化 ====================
    // 使用generate生成所有bus_trans_cnt实例 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM

    // R通道计数器generate
    genvar i;
    generate
        for (i = 0; i < NumSlaves; i = i + 1) begin : gen_r_counters
            bus_trans_cnt r_counter (
                .clk                       (clk),
                .rst_n                     (rst_n),
                .transaction_start         (ar_trans[i]),
                .transaction_end           (r_trans[i]),
                .outstanding_count         (r_outstanding_cnt[i]),
                .outstanding_count_nxt     (),                      // 未使用
                .has_active_transaction    (has_active_r[i]),
                .has_active_transaction_nxt(has_active_r_nxt[i])
            );
        end
    endgenerate

    // W通道计数器generate
    generate
        for (i = 0; i < NumSlaves; i = i + 1) begin : gen_w_counters
            bus_trans_cnt w_counter (
                .clk                       (clk),
                .rst_n                     (rst_n),
                .transaction_start         (aw_trans[i]),
                .transaction_end           (w_trans[i]),
                .outstanding_count         (w_outstanding_cnt[i]),
                .outstanding_count_nxt     (),                      // 未使用
                .has_active_transaction    (has_active_w[i]),
                .has_active_transaction_nxt(has_active_w_nxt[i])
            );
        end
    endgenerate

    // B通道计数器generate
    generate
        for (i = 0; i < NumSlaves; i = i + 1) begin : gen_b_counters
            bus_trans_cnt b_counter (
                .clk                       (clk),
                .rst_n                     (rst_n),
                .transaction_start         (aw_trans[i]),
                .transaction_end           (b_trans[i]),
                .outstanding_count         (b_outstanding_cnt[i]),
                .outstanding_count_nxt     (),                      // 未使用
                .has_active_transaction    (has_active_b[i]),
                .has_active_transaction_nxt(has_active_b_nxt[i])
            );
        end
    endgenerate

    // ==================== 仲裁和选择逻辑 ====================
    // 使用generate生成仲裁逻辑 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM

    // AR通道授权逻辑 - 固定优先级仲裁
    generate
        for (i = 0; i < NumSlaves; i = i + 1) begin : gen_ar_grant
            assign ar_grant[i] = S_AXI_ARVALID && addr_decode_r[i];
        end
    endgenerate

    // AW通道授权逻辑 - 固定优先级仲裁
    generate
        for (i = 0; i < NumSlaves; i = i + 1) begin : gen_aw_grant
            assign aw_grant[i] = S_AXI_AWVALID && addr_decode_w[i];
        end
    endgenerate

    // 通道选择逻辑 - 支持立即授权机制
    generate
        for (i = 0; i < NumSlaves; i = i + 1) begin : gen_channel_select
            // 读数据通道选择
            assign select_r[i] = (slave_sel_r[i] && has_active_r[i]) || (!active_r && ar_grant[i]);
            // 写数据通道选择
            assign select_w[i] = (slave_sel_w[i] && has_active_w[i]) || (!active_w && aw_grant[i]);
            // 写响应通道选择
            assign select_b[i] = (slave_sel_b[i] && has_active_b[i]) || (!active_b && aw_grant[i]);
        end
    endgenerate

    // ==================== 输出端口连接 ====================
    // IMEM
    assign IMEM_AXI_ARID = S_AXI_ARID;
    assign IMEM_AXI_ARADDR = S_AXI_ARADDR;
    assign IMEM_AXI_ARLEN = S_AXI_ARLEN;
    assign IMEM_AXI_ARSIZE = S_AXI_ARSIZE;
    assign IMEM_AXI_ARBURST = S_AXI_ARBURST;
    assign IMEM_AXI_ARLOCK = S_AXI_ARLOCK;
    assign IMEM_AXI_ARCACHE = S_AXI_ARCACHE;
    assign IMEM_AXI_ARPROT = S_AXI_ARPROT;
    assign IMEM_AXI_ARVALID = ar_grant[ItcmIdx];
    assign IMEM_AXI_AWID = S_AXI_AWID;
    assign IMEM_AXI_AWADDR = S_AXI_AWADDR;
    assign IMEM_AXI_AWLEN = S_AXI_AWLEN;
    assign IMEM_AXI_AWSIZE = S_AXI_AWSIZE;
    assign IMEM_AXI_AWBURST = S_AXI_AWBURST;
    assign IMEM_AXI_AWLOCK = S_AXI_AWLOCK;
    assign IMEM_AXI_AWCACHE = S_AXI_AWCACHE;
    assign IMEM_AXI_AWPROT = S_AXI_AWPROT;
    assign IMEM_AXI_AWVALID = aw_grant[ItcmIdx];
    assign IMEM_AXI_WDATA = S_AXI_WDATA;
    assign IMEM_AXI_WSTRB = S_AXI_WSTRB;
    assign IMEM_AXI_WLAST = S_AXI_WLAST;
    assign IMEM_AXI_WVALID = S_AXI_WVALID && select_w[ItcmIdx];
    assign IMEM_AXI_BREADY = S_AXI_BREADY && select_b[ItcmIdx];
    assign IMEM_AXI_RREADY = S_AXI_RREADY && select_r[ItcmIdx];

    // DMEM
    assign DMEM_AXI_ARID = S_AXI_ARID;
    assign DMEM_AXI_ARADDR = S_AXI_ARADDR;
    assign DMEM_AXI_ARLEN = S_AXI_ARLEN;
    assign DMEM_AXI_ARSIZE = S_AXI_ARSIZE;
    assign DMEM_AXI_ARBURST = S_AXI_ARBURST;
    assign DMEM_AXI_ARLOCK = S_AXI_ARLOCK;
    assign DMEM_AXI_ARCACHE = S_AXI_ARCACHE;
    assign DMEM_AXI_ARPROT = S_AXI_ARPROT;
    assign DMEM_AXI_ARVALID = ar_grant[DtcmIdx];
    assign DMEM_AXI_AWID = S_AXI_AWID;
    assign DMEM_AXI_AWADDR = S_AXI_AWADDR;
    assign DMEM_AXI_AWLEN = S_AXI_AWLEN;
    assign DMEM_AXI_AWSIZE = S_AXI_AWSIZE;
    assign DMEM_AXI_AWBURST = S_AXI_AWBURST;
    assign DMEM_AXI_AWLOCK = S_AXI_AWLOCK;
    assign DMEM_AXI_AWCACHE = S_AXI_AWCACHE;
    assign DMEM_AXI_AWPROT = S_AXI_AWPROT;
    assign DMEM_AXI_AWVALID = aw_grant[DtcmIdx];
    assign DMEM_AXI_WDATA = S_AXI_WDATA;
    assign DMEM_AXI_WSTRB = S_AXI_WSTRB;
    assign DMEM_AXI_WLAST = S_AXI_WLAST;
    assign DMEM_AXI_WVALID = S_AXI_WVALID && select_w[DtcmIdx];
    assign DMEM_AXI_BREADY = S_AXI_BREADY && select_b[DtcmIdx];
    assign DMEM_AXI_RREADY = S_AXI_RREADY && select_r[DtcmIdx];

    // DM
    assign DM_AXI_ARID = S_AXI_ARID;
    assign DM_AXI_ARADDR = S_AXI_ARADDR;
    assign DM_AXI_ARLEN = S_AXI_ARLEN;
    assign DM_AXI_ARSIZE = S_AXI_ARSIZE;
    assign DM_AXI_ARBURST = S_AXI_ARBURST;
    assign DM_AXI_ARLOCK = S_AXI_ARLOCK;
    assign DM_AXI_ARCACHE = S_AXI_ARCACHE;
    assign DM_AXI_ARPROT = S_AXI_ARPROT;
    assign DM_AXI_ARVALID = ar_grant[DmIdx];
    assign DM_AXI_AWID = S_AXI_AWID;
    assign DM_AXI_AWADDR = S_AXI_AWADDR;
    assign DM_AXI_AWLEN = S_AXI_AWLEN;
    assign DM_AXI_AWSIZE = S_AXI_AWSIZE;
    assign DM_AXI_AWBURST = S_AXI_AWBURST;
    assign DM_AXI_AWLOCK = S_AXI_AWLOCK;
    assign DM_AXI_AWCACHE = S_AXI_AWCACHE;
    assign DM_AXI_AWPROT = S_AXI_AWPROT;
    assign DM_AXI_AWVALID = aw_grant[DmIdx];
    assign DM_AXI_WDATA = S_AXI_WDATA;
    assign DM_AXI_WSTRB = S_AXI_WSTRB;
    assign DM_AXI_WLAST = S_AXI_WLAST;
    assign DM_AXI_WVALID = S_AXI_WVALID && select_w[DmIdx];
    assign DM_AXI_BREADY = S_AXI_BREADY && select_b[DmIdx];
    assign DM_AXI_RREADY = S_AXI_RREADY && select_r[DmIdx];

    // APB/CLINT/PLIC (AXI-Lite)
    assign OM0_AXI_ACLK = clk;
    assign OM0_AXI_ARESETN = rst_n;
    assign OM1_AXI_ACLK = clk;
    assign OM1_AXI_ARESETN = rst_n;
    assign OM2_AXI_ACLK = clk;
    assign OM2_AXI_ARESETN = rst_n;

    assign OM0_AXI_ARADDR = S_AXI_ARADDR;
    assign OM0_AXI_ARPROT = S_AXI_ARPROT;
    assign OM0_AXI_ARVALID = ar_grant[ApbIdx];
    assign OM1_AXI_ARADDR = S_AXI_ARADDR;
    assign OM1_AXI_ARPROT = S_AXI_ARPROT;
    assign OM1_AXI_ARVALID = ar_grant[ClintIdx];
    assign OM2_AXI_ARADDR = S_AXI_ARADDR;
    assign OM2_AXI_ARPROT = S_AXI_ARPROT;
    assign OM2_AXI_ARVALID = ar_grant[PlicIdx];

    assign OM0_AXI_AWADDR = S_AXI_AWADDR;
    assign OM0_AXI_AWPROT = S_AXI_AWPROT;
    assign OM0_AXI_AWVALID = aw_grant[ApbIdx];
    assign OM1_AXI_AWADDR = S_AXI_AWADDR;
    assign OM1_AXI_AWPROT = S_AXI_AWPROT;
    assign OM1_AXI_AWVALID = aw_grant[ClintIdx];
    assign OM2_AXI_AWADDR = S_AXI_AWADDR;
    assign OM2_AXI_AWPROT = S_AXI_AWPROT;
    assign OM2_AXI_AWVALID = aw_grant[PlicIdx];

    assign OM0_AXI_WDATA = S_AXI_WDATA;
    assign OM0_AXI_WSTRB = S_AXI_WSTRB;
    assign OM0_AXI_WVALID = S_AXI_WVALID && select_w[ApbIdx];
    assign OM1_AXI_WDATA = S_AXI_WDATA;
    assign OM1_AXI_WSTRB = S_AXI_WSTRB;
    assign OM1_AXI_WVALID = S_AXI_WVALID && select_w[ClintIdx];
    assign OM2_AXI_WDATA = S_AXI_WDATA;
    assign OM2_AXI_WSTRB = S_AXI_WSTRB;
    assign OM2_AXI_WVALID = S_AXI_WVALID && select_w[PlicIdx];

    assign OM0_AXI_BREADY = S_AXI_BREADY && select_b[ApbIdx];
    assign OM1_AXI_BREADY = S_AXI_BREADY && select_b[ClintIdx];
    assign OM2_AXI_BREADY = S_AXI_BREADY && select_b[PlicIdx];
    assign OM0_AXI_RREADY = S_AXI_RREADY && select_r[ApbIdx];
    assign OM1_AXI_RREADY = S_AXI_RREADY && select_r[ClintIdx];
    assign OM2_AXI_RREADY = S_AXI_RREADY && select_r[PlicIdx];

    // ==================== 输入端口连接 ====================
    // Ready信号 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign S_AXI_ARREADY = (addr_decode_r[ItcmIdx] && IMEM_AXI_ARREADY) ||
                           (addr_decode_r[DtcmIdx] && DMEM_AXI_ARREADY) ||
                           (addr_decode_r[ApbIdx] && OM0_AXI_ARREADY) ||
                           (addr_decode_r[ClintIdx] && OM1_AXI_ARREADY) ||
                           (addr_decode_r[PlicIdx] && OM2_AXI_ARREADY) ||
                           (addr_decode_r[DmIdx] && DM_AXI_ARREADY);

    assign S_AXI_AWREADY = (addr_decode_w[ItcmIdx] && IMEM_AXI_AWREADY) ||
                           (addr_decode_w[DtcmIdx] && DMEM_AXI_AWREADY) ||
                           (addr_decode_w[ApbIdx] && OM0_AXI_AWREADY) ||
                           (addr_decode_w[ClintIdx] && OM1_AXI_AWREADY) ||
                           (addr_decode_w[PlicIdx] && OM2_AXI_AWREADY) ||
                           (addr_decode_w[DmIdx] && DM_AXI_AWREADY);

    assign S_AXI_WREADY = (select_w[ItcmIdx] && IMEM_AXI_WREADY) ||
                          (select_w[DtcmIdx] && DMEM_AXI_WREADY) ||
                          (select_w[ApbIdx] && OM0_AXI_WREADY) ||
                          (select_w[ClintIdx] && OM1_AXI_WREADY) ||
                          (select_w[PlicIdx] && OM2_AXI_WREADY) ||
                          (select_w[DmIdx] && DM_AXI_WREADY);

    // 读数据通道 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign S_AXI_RID = select_r[ItcmIdx] ? IMEM_AXI_RID :
                       select_r[DtcmIdx] ? DMEM_AXI_RID :
                       select_r[DmIdx]   ? DM_AXI_RID : '0; // AXI-Lite no ID
    assign S_AXI_RDATA = select_r[ItcmIdx] ? IMEM_AXI_RDATA :
                         select_r[DtcmIdx] ? DMEM_AXI_RDATA :
                         select_r[ApbIdx]  ? OM0_AXI_RDATA :
                         select_r[ClintIdx]? OM1_AXI_RDATA :
                         select_r[PlicIdx] ? OM2_AXI_RDATA :
                         select_r[DmIdx]   ? DM_AXI_RDATA : '0;
    assign S_AXI_RRESP = select_r[ItcmIdx] ? IMEM_AXI_RRESP :
                         select_r[DtcmIdx] ? DMEM_AXI_RRESP :
                         select_r[ApbIdx]  ? OM0_AXI_RRESP :
                         select_r[ClintIdx]? OM1_AXI_RRESP :
                         select_r[PlicIdx] ? OM2_AXI_RRESP :
                         select_r[DmIdx]   ? DM_AXI_RRESP : '0;
    assign S_AXI_RLAST = select_r[ItcmIdx] ? IMEM_AXI_RLAST :
                         select_r[DtcmIdx] ? DMEM_AXI_RLAST :
                         select_r[DmIdx]   ? DM_AXI_RLAST :
                         (select_r[ApbIdx] || select_r[ClintIdx] ||
                          select_r[PlicIdx]); // AXI-Lite is always last
    assign S_AXI_RUSER = 4'b0;  // AXI-Lite不使用RUSER信号，设为0
    assign S_AXI_RVALID = (select_r[ItcmIdx] && IMEM_AXI_RVALID) ||
                          (select_r[DtcmIdx] && DMEM_AXI_RVALID) ||
                          (select_r[ApbIdx] && OM0_AXI_RVALID) ||
                          (select_r[ClintIdx] && OM1_AXI_RVALID) ||
                          (select_r[PlicIdx] && OM2_AXI_RVALID) ||
                          (select_r[DmIdx] && DM_AXI_RVALID);

    // 写响应通道 - [0]:ITCM [1]:DTCM [2]:APB [3]:CLINT [4]:PLIC [5]:DM
    assign S_AXI_BID = select_b[ItcmIdx] ? IMEM_AXI_BID :
                       select_b[DtcmIdx] ? DMEM_AXI_BID :
                       select_b[DmIdx]   ? DM_AXI_BID : '0; // AXI-Lite no ID
    assign S_AXI_BRESP = select_b[ItcmIdx] ? IMEM_AXI_BRESP :
                         select_b[DtcmIdx] ? DMEM_AXI_BRESP :
                         select_b[ApbIdx]  ? OM0_AXI_BRESP :
                         select_b[ClintIdx]? OM1_AXI_BRESP :
                         select_b[PlicIdx] ? OM2_AXI_BRESP :
                         select_b[DmIdx]   ? DM_AXI_BRESP : '0;
    assign S_AXI_BVALID = (select_b[ItcmIdx] && IMEM_AXI_BVALID) ||
                          (select_b[DtcmIdx] && DMEM_AXI_BVALID) ||
                          (select_b[ApbIdx] && OM0_AXI_BVALID) ||
                          (select_b[ClintIdx] && OM1_AXI_BVALID) ||
                          (select_b[PlicIdx] && OM2_AXI_BVALID) ||
                          (select_b[DmIdx] && DM_AXI_BVALID);
endmodule
