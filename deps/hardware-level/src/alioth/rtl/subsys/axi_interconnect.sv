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

// AXI互连模块
module axi_interconnect #(
    parameter IMEM_ADDR_WIDTH = 16,  // IMEM地址宽度
    parameter DMEM_ADDR_WIDTH = 16,  // DMEM地址宽度
    parameter DATA_WIDTH      = 32,  // RAM数据宽度

    // AXI接口参数
    parameter C_AXI_ID_WIDTH   = 2,   // AXI ID宽度
    parameter C_AXI_DATA_WIDTH = 32,  // AXI数据宽度
    parameter C_AXI_ADDR_WIDTH = 32,  // AXI地址宽度

    // APB AXI-Lite接口参数
    parameter C_OM0_AXI_ADDR_WIDTH = 32,  // APB AXI-Lite 地址宽度
    parameter C_OM0_AXI_DATA_WIDTH = 32,  // APB AXI-Lite 数据宽度
    // CLINT AXI-Lite接口参数
    parameter C_OM1_AXI_ADDR_WIDTH = 32,  // CLINT AXI-Lite 地址宽度
    parameter C_OM1_AXI_DATA_WIDTH = 32,  // CLINT AXI-Lite 数据宽度
    // PLIC AXI-Lite接口参数
    parameter C_OM2_AXI_ADDR_WIDTH = 32,  // PLIC AXI-Lite 地址宽度
    parameter C_OM2_AXI_DATA_WIDTH = 32   // PLIC AXI-Lite 数据宽度
) (
    // 全局信号
    input wire clk,   // 时钟信号
    input wire rst_n, // 复位信号（低有效）

    // 端口0 - 只有读通道（指令获取）
    // AXI读地址通道
    input  wire [  C_AXI_ID_WIDTH-1:0] M0_AXI_ARID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] M0_AXI_ARADDR,
    input  wire [                 7:0] M0_AXI_ARLEN,
    input  wire [                 2:0] M0_AXI_ARSIZE,
    input  wire [                 1:0] M0_AXI_ARBURST,
    input  wire                        M0_AXI_ARLOCK,
    input  wire [                 3:0] M0_AXI_ARCACHE,
    input  wire [                 2:0] M0_AXI_ARPROT,
    input  wire [                 3:0] M0_AXI_ARQOS,
    input  wire [                 3:0] M0_AXI_ARUSER,
    input  wire                        M0_AXI_ARVALID,
    output wire                        M0_AXI_ARREADY,

    // AXI读数据通道
    output wire [  C_AXI_ID_WIDTH-1:0] M0_AXI_RID,
    output wire [C_AXI_DATA_WIDTH-1:0] M0_AXI_RDATA,
    output wire [                 1:0] M0_AXI_RRESP,
    output wire                        M0_AXI_RLAST,
    output wire [                 3:0] M0_AXI_RUSER,
    output wire                        M0_AXI_RVALID,
    input  wire                        M0_AXI_RREADY,

    // 端口1 - 完整读写通道（数据访问）
    // AXI写地址通道
    input  wire [  C_AXI_ID_WIDTH-1:0] M1_AXI_AWID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] M1_AXI_AWADDR,
    input  wire [                 7:0] M1_AXI_AWLEN,
    input  wire [                 2:0] M1_AXI_AWSIZE,
    input  wire [                 1:0] M1_AXI_AWBURST,
    input  wire                        M1_AXI_AWLOCK,
    input  wire [                 3:0] M1_AXI_AWCACHE,
    input  wire [                 2:0] M1_AXI_AWPROT,
    input  wire [                 3:0] M1_AXI_AWQOS,
    input  wire [                 3:0] M1_AXI_AWUSER,
    input  wire                        M1_AXI_AWVALID,
    output wire                        M1_AXI_AWREADY,

    // AXI写数据通道
    input  wire [    C_AXI_DATA_WIDTH-1:0] M1_AXI_WDATA,
    input  wire [(C_AXI_DATA_WIDTH/8)-1:0] M1_AXI_WSTRB,
    input  wire                            M1_AXI_WLAST,
    input  wire                            M1_AXI_WVALID,
    output wire                            M1_AXI_WREADY,

    // AXI写响应通道
    output wire [C_AXI_ID_WIDTH-1:0] M1_AXI_BID,
    output wire [               1:0] M1_AXI_BRESP,
    output wire                      M1_AXI_BVALID,
    input  wire                      M1_AXI_BREADY,

    // AXI读地址通道
    input  wire [  C_AXI_ID_WIDTH-1:0] M1_AXI_ARID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] M1_AXI_ARADDR,
    input  wire [                 7:0] M1_AXI_ARLEN,
    input  wire [                 2:0] M1_AXI_ARSIZE,
    input  wire [                 1:0] M1_AXI_ARBURST,
    input  wire                        M1_AXI_ARLOCK,
    input  wire [                 3:0] M1_AXI_ARCACHE,
    input  wire [                 2:0] M1_AXI_ARPROT,
    input  wire [                 3:0] M1_AXI_ARQOS,
    input  wire [                 3:0] M1_AXI_ARUSER,
    input  wire                        M1_AXI_ARVALID,
    output wire                        M1_AXI_ARREADY,

    // AXI读数据通道
    output wire [  C_AXI_ID_WIDTH-1:0] M1_AXI_RID,
    output wire [C_AXI_DATA_WIDTH-1:0] M1_AXI_RDATA,
    output wire [                 1:0] M1_AXI_RRESP,
    output wire                        M1_AXI_RLAST,
    output wire [                 3:0] M1_AXI_RUSER,
    output wire                        M1_AXI_RVALID,
    input  wire                        M1_AXI_RREADY,

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

    // CLINT AXI-lite 接口
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
    output wire                        DMEM_AXI_RREADY
);



    localparam ITCM_BASE_ADDR = `ITCM_BASE_ADDR;
    localparam DTCM_BASE_ADDR = `DTCM_BASE_ADDR;
    localparam APB_BASE_ADDR = `APB_BASE_ADDR;
    localparam CLINT_BASE_ADDR = `CLINT_BASE_ADDR;
    localparam PLIC_BASE_ADDR = `PLIC_BASE_ADDR;

    // 地址解码逻辑
    wire is_m0_itcm_r = (M0_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH] == ITCM_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH]);
    wire is_m1_itcm_r = (M1_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH] == ITCM_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH]);
    wire is_m1_dtcm_r = (M1_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH] == DTCM_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH]);
    wire is_m1_apb_r  = (M1_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH] == APB_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH]);
    wire is_m1_clint_r = (M1_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH] == CLINT_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH]);
    wire is_m1_plic_r  = (M1_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH] == PLIC_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH]);

    wire is_m1_dtcm_w = (M1_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH] == DTCM_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`DTCM_ADDR_WIDTH]);
    wire is_m1_itcm_w = (M1_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH] == ITCM_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`ITCM_ADDR_WIDTH]);
    wire is_m1_apb_w  = (M1_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH] == APB_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`APB_ADDR_WIDTH]);
    wire is_m1_clint_w = (M1_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH] == CLINT_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`CLINT_AXI_ADDR_WIDTH]);
    wire is_m1_plic_w  = (M1_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH] == PLIC_BASE_ADDR[C_AXI_ADDR_WIDTH-1:`PLIC_AXI_ADDR_WIDTH]);

    // ==================== 主机间仲裁逻辑（M0 vs M1 对 ITCM）====================
    // 定义仲裁相关信号
    wire m0_has_itcm_ar_req;
    wire m1_has_itcm_ar_req;
    wire m0_itcm_ar_grant;
    wire m1_itcm_ar_grant;

    // ==================== 从机选择逻辑（M1对ITCM vs 外设）====================
    wire m1_has_dtcm_ar_req;
    wire m1_has_apb_ar_req;
    wire m1_has_clint_ar_req;
    wire m1_has_plic_ar_req;
    wire m1_dtcm_ar_grant;
    wire m1_apb_ar_grant;
    wire m1_clint_ar_grant;
    wire m1_plic_ar_grant;

    // ==================== 读数据通道仲裁 ====================
    wire m0_select_itcm_r;
    wire m1_select_itcm_r;
    wire m1_select_dtcm_r;
    wire m1_select_apb_r;
    wire m1_select_clint_r;
    wire m1_select_plic_r;
    wire m0_itcm_rready;
    wire m1_itcm_rready;
    wire m1_dtcm_rready;

    // ==================== 写事务仲裁逻辑 ====================
    wire m1_has_itcm_aw_req;
    wire m1_has_dtcm_aw_req;
    wire m1_has_apb_aw_req;
    wire m1_has_clint_aw_req;
    wire m1_has_plic_aw_req;
    wire m1_itcm_aw_grant;
    wire m1_dtcm_aw_grant;
    wire m1_apb_aw_grant;
    wire m1_clint_aw_grant;
    wire m1_plic_aw_grant;
    wire m1_select_itcm_w;
    wire m1_select_dtcm_w;
    wire m1_select_apb_w;
    wire m1_select_clint_w;
    wire m1_select_plic_w;
    wire m1_select_itcm_b;
    wire m1_select_dtcm_b;
    wire m1_select_apb_b;
    wire m1_select_clint_b;
    wire m1_select_plic_b;
    wire itcm_bready;
    wire dtcm_bready;
    wire itcm_wvalid;
    wire dtcm_wvalid;

    // ==================== outstanding计数器和事务信号分组 ====================
    // ----------- R通道（读）相关 -----------
    wire [3:0] m0_itcm_r_outstanding_cnt;  // M0访问ITCM的读事务计数器
    wire [3:0] m1_itcm_r_outstanding_cnt;  // M1访问ITCM的读事务计数器
    wire [3:0] m1_dtcm_r_outstanding_cnt;  // M1访问DTCM的读事务计数器
    wire [3:0] m1_apb_r_outstanding_cnt;  // M1访问APB的读事务计数器
    wire [3:0] m1_clint_r_outstanding_cnt;  // M1访问CLINT的读事务计数器
    wire [3:0] m1_plic_r_outstanding_cnt;  // M1访问PLIC的读事务计数器

    wire m0_has_active_itcm_r;
    wire m1_has_active_itcm_r;
    wire m1_has_active_dtcm_r;
    wire m1_has_active_apb_r;
    wire m1_has_active_clint_r;
    wire m1_has_active_plic_r;

    // R通道事务信号
    wire m0_itcm_ar_trans = M0_AXI_ARVALID && M0_AXI_ARREADY && is_m0_itcm_r;
    wire m0_itcm_r_trans = M0_AXI_RVALID && M0_AXI_RREADY && M0_AXI_RLAST;

    wire m1_itcm_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_itcm_r;
    wire m1_dtcm_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_dtcm_r;
    wire m1_apb_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_apb_r;
    wire m1_clint_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_clint_r;
    wire m1_plic_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_plic_r;

    // 读事务完成条件
    wire m1_itcm_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && M1_AXI_RLAST && m1_select_itcm_r;
    wire m1_dtcm_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && M1_AXI_RLAST && m1_select_dtcm_r;
    wire m1_apb_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && m1_select_apb_r;
    wire m1_clint_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && m1_select_clint_r;
    wire m1_plic_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && m1_select_plic_r;

    // ----------- W通道（写数据）相关 -----------
    wire [3:0] m1_itcm_w_outstanding_cnt;  // M1访问ITCM的写数据outstanding
    wire [3:0] m1_dtcm_w_outstanding_cnt;  // M1访问DTCM的写数据outstanding
    wire [3:0] m1_apb_w_outstanding_cnt;  // M1访问APB的写数据outstanding
    wire [3:0] m1_clint_w_outstanding_cnt;  // M1访问CLINT的写数据outstanding
    wire [3:0] m1_plic_w_outstanding_cnt;  // M1访问PLIC的写数据outstanding

    wire m1_has_active_itcm_w;
    wire m1_has_active_dtcm_w;
    wire m1_has_active_apb_w;
    wire m1_has_active_clint_w;
    wire m1_has_active_plic_w;

    // AW通道事务信号
    wire m1_itcm_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_itcm_w;
    wire m1_dtcm_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_dtcm_w;
    wire m1_apb_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_apb_w;
    wire m1_clint_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_clint_w;
    wire m1_plic_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_plic_w;

    // W通道事务信号
    wire m1_itcm_w_trans = M1_AXI_WVALID && IMEM_AXI_WREADY && m1_select_itcm_w;
    wire m1_dtcm_w_trans = M1_AXI_WVALID && DMEM_AXI_WREADY && m1_select_dtcm_w;
    wire m1_apb_w_trans = M1_AXI_WVALID && OM0_AXI_WREADY && m1_select_apb_w;
    wire m1_clint_w_trans = M1_AXI_WVALID && OM1_AXI_WREADY && m1_select_clint_w;
    wire m1_plic_w_trans = M1_AXI_WVALID && OM2_AXI_WREADY && m1_select_plic_w;

    // ----------- B通道（写响应）相关 -----------
    wire [3:0] m1_itcm_b_outstanding_cnt;  // M1访问ITCM的写响应outstanding
    wire [3:0] m1_dtcm_b_outstanding_cnt;  // M1访问DTCM的写响应outstanding
    wire [3:0] m1_apb_b_outstanding_cnt;  // M1访问APB的写响应outstanding
    wire [3:0] m1_clint_b_outstanding_cnt;  // M1访问CLINT的写响应outstanding
    wire [3:0] m1_plic_b_outstanding_cnt;  // M1访问PLIC的写响应outstanding

    wire m1_has_active_itcm_b;
    wire m1_has_active_dtcm_b;
    wire m1_has_active_apb_b;
    wire m1_has_active_clint_b;
    wire m1_has_active_plic_b;

    // B通道事务信号
    wire m1_itcm_b_trans = IMEM_AXI_BVALID && M1_AXI_BREADY && m1_select_itcm_b;
    wire m1_dtcm_b_trans = DMEM_AXI_BVALID && M1_AXI_BREADY && m1_select_dtcm_b;
    wire m1_apb_b_trans = OM0_AXI_BVALID && M1_AXI_BREADY && m1_select_apb_b;
    wire m1_clint_b_trans = OM1_AXI_BVALID && M1_AXI_BREADY && m1_select_clint_b;
    wire m1_plic_b_trans = OM2_AXI_BVALID && M1_AXI_BREADY && m1_select_plic_b;

    // ==================== 下一周期预测信号 ====================
    wire m1_has_active_itcm_r_nxt;
    wire m1_has_active_dtcm_r_nxt;
    wire m1_has_active_apb_r_nxt;
    wire m1_has_active_clint_r_nxt;
    wire m1_has_active_plic_r_nxt;
    wire m1_has_active_itcm_w_nxt;
    wire m1_has_active_dtcm_w_nxt;
    wire m1_has_active_apb_w_nxt;
    wire m1_has_active_clint_w_nxt;
    wire m1_has_active_plic_w_nxt;
    wire m1_has_active_itcm_b_nxt;
    wire m1_has_active_dtcm_b_nxt;
    wire m1_has_active_apb_b_nxt;
    wire m1_has_active_clint_b_nxt;
    wire m1_has_active_plic_b_nxt;

    // ==================== 优先级跟踪寄存器 ====================
    // bit 0: ITCM, bit 1: DTCM, bit 2: APB, bit 3: CLINT, bit 4: PLIC
    reg [4:0] m1_slave_sel_r;  // 读通道优先级
    reg [4:0] m1_slave_sel_b;  // 写响应通道优先级
    reg [4:0] m1_slave_sel_w;  // 写数据通道优先级

    // 拼接变量用于case判断（当前周期）
    wire [4:0] m1_active_r = {
        m1_has_active_plic_r,
        m1_has_active_clint_r,
        m1_has_active_apb_r,
        m1_has_active_dtcm_r,
        m1_has_active_itcm_r
    };
    wire [4:0] m1_active_w = {
        m1_has_active_plic_w,
        m1_has_active_clint_w,
        m1_has_active_apb_w,
        m1_has_active_dtcm_w,
        m1_has_active_itcm_w
    };
    wire [4:0] m1_active_b = {
        m1_has_active_plic_b,
        m1_has_active_clint_b,
        m1_has_active_apb_b,
        m1_has_active_dtcm_b,
        m1_has_active_itcm_b
    };

    // 拼接变量用于case判断（下一个周期）
    wire [4:0] m1_active_r_nxt = {
        m1_has_active_plic_r_nxt,
        m1_has_active_clint_r_nxt,
        m1_has_active_apb_r_nxt,
        m1_has_active_dtcm_r_nxt,
        m1_has_active_itcm_r_nxt
    };
    wire [4:0] m1_active_w_nxt = {
        m1_has_active_plic_w_nxt,
        m1_has_active_clint_w_nxt,
        m1_has_active_apb_w_nxt,
        m1_has_active_dtcm_w_nxt,
        m1_has_active_itcm_w_nxt
    };
    wire [4:0] m1_active_b_nxt = {
        m1_has_active_plic_b_nxt,
        m1_has_active_clint_b_nxt,
        m1_has_active_apb_b_nxt,
        m1_has_active_dtcm_b_nxt,
        m1_has_active_itcm_b_nxt
    };

    // 读通道优先权切换逻辑 - case实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m1_slave_sel_r <= 5'b00001;
        end else begin
            case (m1_active_r_nxt)
                5'b00000: m1_slave_sel_r <= 5'b00000;
                5'b00001: m1_slave_sel_r <= 5'b00001;
                5'b00010: m1_slave_sel_r <= 5'b00010;
                5'b00100: m1_slave_sel_r <= 5'b00100;
                5'b01000: m1_slave_sel_r <= 5'b01000;
                5'b10000: m1_slave_sel_r <= 5'b10000;
                default:  m1_slave_sel_r <= m1_slave_sel_r;  // 多个同时有效时保持
            endcase
        end
    end

    // 写响应通道优先权切换逻辑 - 使用b通道nxt信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m1_slave_sel_b <= 5'b00001;
        end else begin
            case (m1_active_b_nxt)
                5'b00000: m1_slave_sel_b <= 5'b00000;
                5'b00001: m1_slave_sel_b <= 5'b00001;
                5'b00010: m1_slave_sel_b <= 5'b00010;
                5'b00100: m1_slave_sel_b <= 5'b00100;
                5'b01000: m1_slave_sel_b <= 5'b01000;
                5'b10000: m1_slave_sel_b <= 5'b10000;
                default:  m1_slave_sel_b <= m1_slave_sel_b;
            endcase
        end
    end

    // 写数据通道优先权切换逻辑 - 使用w通道nxt信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m1_slave_sel_w <= 5'b00001;
        end else begin
            case (m1_active_w_nxt)
                5'b00000: m1_slave_sel_w <= 5'b00000;
                5'b00001: m1_slave_sel_w <= 5'b00001;
                5'b00010: m1_slave_sel_w <= 5'b00010;
                5'b00100: m1_slave_sel_w <= 5'b00100;
                5'b01000: m1_slave_sel_w <= 5'b01000;
                5'b10000: m1_slave_sel_w <= 5'b10000;
                default:  m1_slave_sel_w <= m1_slave_sel_w;
            endcase
        end
    end

    // ==================== 事务计数器模块实例化 ====================
    // R通道计数器
    bus_trans_cnt m0_itcm_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m0_itcm_ar_trans),
        .transaction_end          (m0_itcm_r_trans),
        .outstanding_count        (m0_itcm_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m0_has_active_itcm_r),
        .has_active_transaction_nxt ()  // 未使用
    );

    bus_trans_cnt m1_itcm_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_itcm_ar_trans),
        .transaction_end          (m1_itcm_r_trans),
        .outstanding_count        (m1_itcm_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_itcm_r),
        .has_active_transaction_nxt (m1_has_active_itcm_r_nxt)
    );

    bus_trans_cnt m1_dtcm_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_dtcm_ar_trans),
        .transaction_end          (m1_dtcm_r_trans),
        .outstanding_count        (m1_dtcm_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_dtcm_r),
        .has_active_transaction_nxt (m1_has_active_dtcm_r_nxt)
    );

    bus_trans_cnt m1_apb_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_apb_ar_trans),
        .transaction_end          (m1_apb_r_trans),
        .outstanding_count        (m1_apb_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_apb_r),
        .has_active_transaction_nxt (m1_has_active_apb_r_nxt)
    );

    bus_trans_cnt m1_clint_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_clint_ar_trans),
        .transaction_end          (m1_clint_r_trans),
        .outstanding_count        (m1_clint_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_clint_r),
        .has_active_transaction_nxt (m1_has_active_clint_r_nxt)
    );

    bus_trans_cnt m1_plic_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_plic_ar_trans),
        .transaction_end          (m1_plic_r_trans),
        .outstanding_count        (m1_plic_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_plic_r),
        .has_active_transaction_nxt (m1_has_active_plic_r_nxt)
    );

    // W通道计数器
    bus_trans_cnt m1_itcm_w_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_itcm_aw_trans),
        .transaction_end          (m1_itcm_w_trans),
        .outstanding_count        (m1_itcm_w_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_itcm_w),
        .has_active_transaction_nxt (m1_has_active_itcm_w_nxt)
    );

    bus_trans_cnt m1_dtcm_w_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_dtcm_aw_trans),
        .transaction_end          (m1_dtcm_w_trans),
        .outstanding_count        (m1_dtcm_w_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_dtcm_w),
        .has_active_transaction_nxt (m1_has_active_dtcm_w_nxt)
    );

    bus_trans_cnt m1_apb_w_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_apb_aw_trans),
        .transaction_end          (m1_apb_w_trans),
        .outstanding_count        (m1_apb_w_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_apb_w),
        .has_active_transaction_nxt (m1_has_active_apb_w_nxt)
    );

    bus_trans_cnt m1_clint_w_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_clint_aw_trans),
        .transaction_end          (m1_clint_w_trans),
        .outstanding_count        (m1_clint_w_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_clint_w),
        .has_active_transaction_nxt (m1_has_active_clint_w_nxt)
    );

    bus_trans_cnt m1_plic_w_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_plic_aw_trans),
        .transaction_end          (m1_plic_w_trans),
        .outstanding_count        (m1_plic_w_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_plic_w),
        .has_active_transaction_nxt (m1_has_active_plic_w_nxt)
    );

    // B通道计数器
    bus_trans_cnt m1_itcm_b_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_itcm_aw_trans),
        .transaction_end          (m1_itcm_b_trans),
        .outstanding_count        (m1_itcm_b_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_itcm_b),
        .has_active_transaction_nxt (m1_has_active_itcm_b_nxt)
    );

    bus_trans_cnt m1_dtcm_b_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_dtcm_aw_trans),
        .transaction_end          (m1_dtcm_b_trans),
        .outstanding_count        (m1_dtcm_b_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_dtcm_b),
        .has_active_transaction_nxt (m1_has_active_dtcm_b_nxt)
    );

    bus_trans_cnt m1_apb_b_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_apb_aw_trans),
        .transaction_end          (m1_apb_b_trans),
        .outstanding_count        (m1_apb_b_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_apb_b),
        .has_active_transaction_nxt (m1_has_active_apb_b_nxt)
    );

    bus_trans_cnt m1_clint_b_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_clint_aw_trans),
        .transaction_end          (m1_clint_b_trans),
        .outstanding_count        (m1_clint_b_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_clint_b),
        .has_active_transaction_nxt (m1_has_active_clint_b_nxt)
    );

    bus_trans_cnt m1_plic_b_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_plic_aw_trans),
        .transaction_end          (m1_plic_b_trans),
        .outstanding_count        (m1_plic_b_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_plic_b),
        .has_active_transaction_nxt (m1_has_active_plic_b_nxt)
    );

    // ==================== 主机间仲裁逻辑（M0 vs M1 对 ITCM）====================
    assign m0_has_itcm_ar_req = M0_AXI_ARVALID && is_m0_itcm_r;  // M0有ITCM读请求
    assign m1_has_itcm_ar_req = M1_AXI_ARVALID && is_m1_itcm_r;  // M1有ITCM读请求且没有未完成事务

    // 主机间仲裁逻辑：
    // 1. 如果一方有未完成事务，优先保证其完成
    // 2. 如果都没有未完成事务或都有未完成事务，M1优先
    // 3. 地址通道可以立即切换，所以优先处理新请求
    assign m0_itcm_ar_grant = m0_has_itcm_ar_req && !m1_has_itcm_ar_req && !m1_has_active_itcm_r;
    assign m1_itcm_ar_grant = m1_has_itcm_ar_req;  // M1总是优先获得ITCM读地址通道

    // ==================== 从机选择逻辑（M1对ITCM vs 外设）====================
    assign m1_has_dtcm_ar_req = M1_AXI_ARVALID && is_m1_dtcm_r;  // M1有DTCM读请求
    assign m1_has_apb_ar_req = M1_AXI_ARVALID && is_m1_apb_r;  // M1有APB读请求
    assign m1_has_clint_ar_req = M1_AXI_ARVALID && is_m1_clint_r;  // M1有CLINT读请求
    assign m1_has_plic_ar_req = M1_AXI_ARVALID && is_m1_plic_r;  // M1有PLIC读请求
    // 地址通道可以立即切换
    assign m1_dtcm_ar_grant = m1_has_dtcm_ar_req;  // 地址通道授权可立即给DTCM
    assign m1_apb_ar_grant = m1_has_apb_ar_req;  // 地址通道授权可立即给APB
    assign m1_clint_ar_grant = m1_has_clint_ar_req;  // 地址通道授权可立即给CLINT
    assign m1_plic_ar_grant = m1_has_plic_ar_req;  // 地址通道授权可立即给PLIC

    // ==================== 读数据通道仲裁 ====================
    // 处理M0与M1对ITCM的读数据通道竞争
    // 如果m0没有未完成的itcm读请求,那么才能转交读读响应通道给m1.
    assign m0_select_itcm_r = m0_has_active_itcm_r;
    assign m1_select_itcm_r = m1_slave_sel_r[0] && m1_has_active_itcm_r && !m0_has_active_itcm_r;
    assign m1_select_dtcm_r = m1_slave_sel_r[1] && m1_has_active_dtcm_r;
    assign m1_select_apb_r = m1_slave_sel_r[2] && m1_has_active_apb_r;
    assign m1_select_clint_r = m1_slave_sel_r[3] && m1_has_active_clint_r;
    assign m1_select_plic_r = m1_slave_sel_r[4] && m1_has_active_plic_r;

    // 读通道ready信号连接 - 确保信号只连接到当前优先级对应的设备
    assign m0_itcm_rready = m0_select_itcm_r && M0_AXI_RREADY;
    assign m1_itcm_rready = m1_select_itcm_r && M1_AXI_RREADY;
    assign m1_dtcm_rready = m1_select_dtcm_r && M1_AXI_RREADY;

    // ==================== 写事务仲裁逻辑 ====================
    // 写地址通道请求信号
    assign m1_has_itcm_aw_req = M1_AXI_AWVALID && is_m1_itcm_w;  // M1有ITCM写请求
    assign m1_has_dtcm_aw_req = M1_AXI_AWVALID && is_m1_dtcm_w;  // M1有DTCM写请求
    assign m1_has_apb_aw_req = M1_AXI_AWVALID && is_m1_apb_w;  // M1有APB写请求
    assign m1_has_clint_aw_req = M1_AXI_AWVALID && is_m1_clint_w;  // M1有CLINT写请求
    assign m1_has_plic_aw_req = M1_AXI_AWVALID && is_m1_plic_w;  // M1有PLIC写请求

    // 写地址通道授权
    assign m1_itcm_aw_grant = m1_has_itcm_aw_req;
    assign m1_dtcm_aw_grant = m1_has_dtcm_aw_req;
    assign m1_apb_aw_grant = m1_has_apb_aw_req;
    assign m1_clint_aw_grant = m1_has_clint_aw_req;
    assign m1_plic_aw_grant = m1_has_plic_aw_req;

    // 写数据通道授权
    assign m1_select_itcm_w = (m1_slave_sel_w[0] && m1_has_active_itcm_w) || (!m1_active_w && m1_itcm_aw_grant);
    assign m1_select_dtcm_w = (m1_slave_sel_w[1] && m1_has_active_dtcm_w) || (!m1_active_w && m1_dtcm_aw_grant);
    assign m1_select_apb_w  = (m1_slave_sel_w[2] && m1_has_active_apb_w)  || (!m1_active_w && m1_apb_aw_grant);
    assign m1_select_clint_w= (m1_slave_sel_w[3] && m1_has_active_clint_w) || (!m1_active_w && m1_clint_aw_grant);
    assign m1_select_plic_w = (m1_slave_sel_w[4] && m1_has_active_plic_w) || (!m1_active_w && m1_plic_aw_grant);
    // 写响应通道授权
    assign m1_select_itcm_b = (m1_slave_sel_b[0] && m1_has_active_itcm_b) || (!m1_active_b && m1_itcm_aw_grant);
    assign m1_select_dtcm_b = (m1_slave_sel_b[1] && m1_has_active_dtcm_b) || (!m1_active_b && m1_dtcm_aw_grant);
    assign m1_select_apb_b  = (m1_slave_sel_b[2] && m1_has_active_apb_b)  || (!m1_active_b && m1_apb_aw_grant);
    assign m1_select_clint_b= (m1_slave_sel_b[3] && m1_has_active_clint_b) || (!m1_active_b && m1_clint_aw_grant);
    assign m1_select_plic_b = (m1_slave_sel_b[4] && m1_has_active_plic_b) || (!m1_active_b && m1_plic_aw_grant);

    // 写响应通道ready信号
    assign itcm_bready = m1_select_itcm_b && M1_AXI_BREADY;
    assign dtcm_bready = m1_select_dtcm_b && M1_AXI_BREADY;

    assign itcm_wvalid = m1_select_itcm_w && M1_AXI_WVALID;
    assign dtcm_wvalid = m1_select_dtcm_w && M1_AXI_WVALID;

    // IMEM写地址通道连接
    assign IMEM_AXI_AWID = M1_AXI_AWID;
    assign IMEM_AXI_AWADDR = M1_AXI_AWADDR;
    assign IMEM_AXI_AWLEN = M1_AXI_AWLEN;
    assign IMEM_AXI_AWSIZE = M1_AXI_AWSIZE;
    assign IMEM_AXI_AWBURST = M1_AXI_AWBURST;
    assign IMEM_AXI_AWLOCK = M1_AXI_AWLOCK;
    assign IMEM_AXI_AWCACHE = M1_AXI_AWCACHE;
    assign IMEM_AXI_AWPROT = M1_AXI_AWPROT;
    assign IMEM_AXI_AWVALID = itcm_wvalid;

    // IMEM写数据通道连接
    assign IMEM_AXI_WDATA = M1_AXI_WDATA;
    assign IMEM_AXI_WSTRB = M1_AXI_WSTRB;
    assign IMEM_AXI_WLAST = M1_AXI_WLAST;
    assign IMEM_AXI_WVALID = itcm_wvalid;

    // IMEM写响应通道连接
    assign IMEM_AXI_BREADY = itcm_bready;

    // DMEM写地址通道连接
    assign DMEM_AXI_AWID = M1_AXI_AWID;
    assign DMEM_AXI_AWADDR = M1_AXI_AWADDR;
    assign DMEM_AXI_AWLEN = M1_AXI_AWLEN;
    assign DMEM_AXI_AWSIZE = M1_AXI_AWSIZE;
    assign DMEM_AXI_AWBURST = M1_AXI_AWBURST;
    assign DMEM_AXI_AWLOCK = M1_AXI_AWLOCK;
    assign DMEM_AXI_AWCACHE = M1_AXI_AWCACHE;
    assign DMEM_AXI_AWPROT = M1_AXI_AWPROT;
    assign DMEM_AXI_AWVALID = dtcm_wvalid;

    // DMEM写数据通道连接
    assign DMEM_AXI_WDATA = M1_AXI_WDATA;
    assign DMEM_AXI_WSTRB = M1_AXI_WSTRB;
    assign DMEM_AXI_WLAST = M1_AXI_WLAST;
    assign DMEM_AXI_WVALID = dtcm_wvalid;

    // DMEM写响应通道连接
    assign DMEM_AXI_BREADY = dtcm_bready;

    // ==================== 端口连接信号 ====================

    // 根据仲裁结果选择IMEM的输入
    assign IMEM_AXI_ARID = m1_itcm_ar_grant ? M1_AXI_ARID : (m0_itcm_ar_grant ? M0_AXI_ARID : '0);
    assign IMEM_AXI_ARADDR = m1_itcm_ar_grant ? M1_AXI_ARADDR : (m0_itcm_ar_grant ? M0_AXI_ARADDR : '0);
    assign IMEM_AXI_ARLEN = m1_itcm_ar_grant ? M1_AXI_ARLEN : (m0_itcm_ar_grant ? M0_AXI_ARLEN : '0);
    assign IMEM_AXI_ARSIZE = m1_itcm_ar_grant ? M1_AXI_ARSIZE : (m0_itcm_ar_grant ? M0_AXI_ARSIZE : '0);
    assign IMEM_AXI_ARBURST = m1_itcm_ar_grant ? M1_AXI_ARBURST : (m0_itcm_ar_grant ? M0_AXI_ARBURST : '0);
    assign IMEM_AXI_ARLOCK = m1_itcm_ar_grant ? M1_AXI_ARLOCK : (m0_itcm_ar_grant ? M0_AXI_ARLOCK : '0);
    assign IMEM_AXI_ARCACHE = m1_itcm_ar_grant ? M1_AXI_ARCACHE : (m0_itcm_ar_grant ? M0_AXI_ARCACHE : '0);
    assign IMEM_AXI_ARPROT = m1_itcm_ar_grant ? M1_AXI_ARPROT : (m0_itcm_ar_grant ? M0_AXI_ARPROT : '0);
    assign IMEM_AXI_ARVALID = m1_itcm_ar_grant ? M1_AXI_ARVALID : (m0_itcm_ar_grant ? M0_AXI_ARVALID : 1'b0);

    // DMEM只在被授权时连接到端口1
    assign DMEM_AXI_ARID = M1_AXI_ARID;
    assign DMEM_AXI_ARADDR = M1_AXI_ARADDR;
    assign DMEM_AXI_ARLEN = M1_AXI_ARLEN;
    assign DMEM_AXI_ARSIZE = M1_AXI_ARSIZE;
    assign DMEM_AXI_ARBURST = M1_AXI_ARBURST;
    assign DMEM_AXI_ARLOCK = M1_AXI_ARLOCK;
    assign DMEM_AXI_ARCACHE = M1_AXI_ARCACHE;
    assign DMEM_AXI_ARPROT = M1_AXI_ARPROT;
    assign DMEM_AXI_ARVALID = m1_dtcm_ar_grant ? M1_AXI_ARVALID : 1'b0;

    // 端口输出连接
    // 端口0连接
    assign M0_AXI_ARREADY = is_m0_itcm_r ? (IMEM_AXI_ARREADY && m0_itcm_ar_grant) : 1'b0;
    assign M0_AXI_RID = IMEM_AXI_RID;
    assign M0_AXI_RDATA = IMEM_AXI_RDATA;
    assign M0_AXI_RRESP = IMEM_AXI_RRESP;
    assign M0_AXI_RLAST = IMEM_AXI_RLAST;
    assign M0_AXI_RUSER = 4'b0;

    // RVALID信号也需要考虑FIFO中的数据
    assign M0_AXI_RVALID = IMEM_AXI_RVALID && m0_select_itcm_r;

    // APB接口连接到外部
    assign OM0_AXI_ACLK = clk;
    assign OM0_AXI_ARESETN = rst_n;
    // CLINT接口连接到外部
    assign OM1_AXI_ACLK = clk;
    assign OM1_AXI_ARESETN = rst_n;
    // PLIC接口连接到外部
    assign OM2_AXI_ACLK = clk;
    assign OM2_AXI_ARESETN = rst_n;
    // 读地址通道
    assign OM0_AXI_ARADDR = M1_AXI_ARADDR;
    assign OM0_AXI_ARPROT = M1_AXI_ARPROT;
    assign OM0_AXI_ARVALID = m1_apb_ar_grant;
    assign OM1_AXI_ARADDR = M1_AXI_ARADDR;
    assign OM1_AXI_ARPROT = M1_AXI_ARPROT;
    assign OM1_AXI_ARVALID = m1_clint_ar_grant;
    assign OM2_AXI_ARADDR = M1_AXI_ARADDR;
    assign OM2_AXI_ARPROT = M1_AXI_ARPROT;
    assign OM2_AXI_ARVALID = m1_plic_ar_grant;
    // 写地址通道
    assign OM0_AXI_AWADDR = M1_AXI_AWADDR;
    assign OM0_AXI_AWPROT = M1_AXI_AWPROT;
    assign OM0_AXI_AWVALID = m1_apb_aw_grant;
    assign OM1_AXI_AWADDR = M1_AXI_AWADDR;
    assign OM1_AXI_AWPROT = M1_AXI_AWPROT;
    assign OM1_AXI_AWVALID = m1_clint_aw_grant;
    assign OM2_AXI_AWADDR = M1_AXI_AWADDR;
    assign OM2_AXI_AWPROT = M1_AXI_AWPROT;
    assign OM2_AXI_AWVALID = m1_plic_aw_grant;
    // 写数据通道
    assign OM0_AXI_WDATA = M1_AXI_WDATA;
    assign OM0_AXI_WSTRB = M1_AXI_WSTRB;
    assign OM0_AXI_WVALID = M1_AXI_WVALID && is_m1_apb_w;
    assign OM1_AXI_WDATA = M1_AXI_WDATA;
    assign OM1_AXI_WSTRB = M1_AXI_WSTRB;
    assign OM1_AXI_WVALID = M1_AXI_WVALID && is_m1_clint_w;
    assign OM2_AXI_WDATA = M1_AXI_WDATA;
    assign OM2_AXI_WSTRB = M1_AXI_WSTRB;
    assign OM2_AXI_WVALID = M1_AXI_WVALID && is_m1_plic_w;
    // 响应通道
    assign OM0_AXI_BREADY = M1_AXI_BREADY && m1_select_apb_b;
    assign OM1_AXI_BREADY = M1_AXI_BREADY && m1_select_clint_b;
    assign OM2_AXI_BREADY = M1_AXI_BREADY && m1_select_plic_b;
    assign OM0_AXI_RREADY = M1_AXI_RREADY && m1_select_apb_r;
    assign OM1_AXI_RREADY = M1_AXI_RREADY && m1_select_clint_r;
    assign OM2_AXI_RREADY = M1_AXI_RREADY && m1_select_plic_r;

    // 处理读通道ready信号的连接
    assign IMEM_AXI_RREADY = m0_itcm_rready || m1_itcm_rready;
    assign DMEM_AXI_RREADY = m1_dtcm_rready;

    // 端口1读数据通道的选择逻辑
    assign M1_AXI_RID = m1_select_itcm_r ? IMEM_AXI_RID :
                        m1_select_dtcm_r ? DMEM_AXI_RID : 0; // APB/CLINT/PLIC是AXI-Lite，无ID
    assign M1_AXI_RDATA = m1_select_itcm_r ? IMEM_AXI_RDATA :
                          m1_select_dtcm_r ? DMEM_AXI_RDATA :
                          m1_select_apb_r ? OM0_AXI_RDATA :
                          m1_select_clint_r ? OM1_AXI_RDATA :
                          m1_select_plic_r ? OM2_AXI_RDATA : 0;
    assign M1_AXI_RRESP = m1_select_itcm_r ? IMEM_AXI_RRESP :
                          m1_select_dtcm_r ? DMEM_AXI_RRESP :
                          m1_select_apb_r ? OM0_AXI_RRESP :
                          m1_select_clint_r ? OM1_AXI_RRESP :
                          m1_select_plic_r ? OM2_AXI_RRESP : 0;
    assign M1_AXI_RLAST = m1_select_itcm_r ? IMEM_AXI_RLAST :
                          m1_select_dtcm_r ? DMEM_AXI_RLAST :
                          (m1_select_apb_r || m1_select_clint_r || m1_select_plic_r) ? 1'b1 : 0; // AXI-Lite每次传输都是LAST
    assign M1_AXI_RVALID = m1_select_itcm_r ? IMEM_AXI_RVALID :
                           m1_select_dtcm_r ? DMEM_AXI_RVALID :
                           m1_select_apb_r ? OM0_AXI_RVALID :
                           m1_select_clint_r ? OM1_AXI_RVALID :
                           m1_select_plic_r ? OM2_AXI_RVALID : 0;
    // 端口1写响应通道的选择逻辑
    assign M1_AXI_BID = m1_select_itcm_b ? IMEM_AXI_BID :
                        m1_select_dtcm_b ? DMEM_AXI_BID : 0; // APB/CLINT/PLIC是AXI-Lite，无ID
    assign M1_AXI_BRESP = m1_select_itcm_b ? IMEM_AXI_BRESP :
                          m1_select_dtcm_b ? DMEM_AXI_BRESP :
                          m1_select_apb_b ? OM0_AXI_BRESP :
                          m1_select_clint_b ? OM1_AXI_BRESP :
                          m1_select_plic_b ? OM2_AXI_BRESP : 0;
    assign M1_AXI_BVALID = m1_select_itcm_b ? IMEM_AXI_BVALID :
                           m1_select_dtcm_b ? DMEM_AXI_BVALID :
                           m1_select_apb_b ? OM0_AXI_BVALID :
                           m1_select_clint_b ? OM1_AXI_BVALID :
                           m1_select_plic_b ? OM2_AXI_BVALID : 0;

    // 更新Ready信号连接
    assign M1_AXI_ARREADY = (is_m1_itcm_r && IMEM_AXI_ARREADY) ||
                            (is_m1_dtcm_r && DMEM_AXI_ARREADY) ||
                            (is_m1_apb_r && OM0_AXI_ARREADY) ||
                            (is_m1_clint_r && OM1_AXI_ARREADY) ||
                            (is_m1_plic_r && OM2_AXI_ARREADY);
    assign M1_AXI_AWREADY = (is_m1_itcm_w && IMEM_AXI_AWREADY) ||
                            (is_m1_dtcm_w && DMEM_AXI_AWREADY) ||
                            (is_m1_apb_w && OM0_AXI_AWREADY) ||
                            (is_m1_clint_w && OM1_AXI_AWREADY) ||
                            (is_m1_plic_w && OM2_AXI_AWREADY);
    assign M1_AXI_WREADY = (m1_select_itcm_w && IMEM_AXI_WREADY) ||
                           (m1_select_dtcm_w && DMEM_AXI_WREADY) ||
                           (m1_select_apb_w && OM0_AXI_WREADY) ||
                           (m1_select_clint_w && OM1_AXI_WREADY) ||
                           (m1_select_plic_w && OM2_AXI_WREADY);



endmodule

