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

// 内存模块，包含ITCM和DTCM
module mems #(
    parameter ITCM_ADDR_WIDTH = 16,  // ITCM地址宽度
    parameter DTCM_ADDR_WIDTH = 16,  // DTCM地址宽度
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
    output wire                                  OM2_AXI_RREADY
);


    // ITCM与DTCM的接口信号
    // ITCM读地址通道
    wire itcm_arready;
    wire [C_AXI_ID_WIDTH-1:0] itcm_arid;
    wire [C_AXI_ADDR_WIDTH-1:0] itcm_araddr;
    wire [7:0] itcm_arlen;
    wire [2:0] itcm_arsize;
    wire [1:0] itcm_arburst;
    wire itcm_arlock;
    wire [3:0] itcm_arcache;
    wire [2:0] itcm_arprot;
    wire itcm_arvalid;

    // ITCM读数据通道
    wire [C_AXI_ID_WIDTH-1:0] itcm_rid;
    wire [C_AXI_DATA_WIDTH-1:0] itcm_rdata;
    wire [1:0] itcm_rresp;
    wire itcm_rlast;
    wire itcm_rvalid;
    wire itcm_rready;

    // DTCM读地址通道
    wire dtcm_arready;
    wire [C_AXI_ID_WIDTH-1:0] dtcm_arid;
    wire [C_AXI_ADDR_WIDTH-1:0] dtcm_araddr;
    wire [7:0] dtcm_arlen;
    wire [2:0] dtcm_arsize;
    wire [1:0] dtcm_arburst;
    wire dtcm_arlock;
    wire [3:0] dtcm_arcache;
    wire [2:0] dtcm_arprot;
    wire dtcm_arvalid;

    // DTCM读数据通道
    wire [C_AXI_ID_WIDTH-1:0] dtcm_rid;
    wire [C_AXI_DATA_WIDTH-1:0] dtcm_rdata;
    wire [1:0] dtcm_rresp;
    wire dtcm_rlast;
    wire dtcm_rvalid;
    wire dtcm_rready;

    // 写响应通道连接
    wire [C_AXI_ID_WIDTH-1:0] itcm_bid;
    wire [1:0] itcm_bresp;
    wire itcm_bvalid;
    wire itcm_wready;
    wire itcm_awready;

    wire [C_AXI_ID_WIDTH-1:0] dtcm_bid;
    wire [1:0] dtcm_bresp;
    wire dtcm_bvalid;
    wire dtcm_wready;
    wire dtcm_awready;

    // 地址解码逻辑
    wire is_m0_itcm_r = (M0_AXI_ARADDR >= `ITCM_BASE_ADDR) && (M0_AXI_ARADDR < (`ITCM_BASE_ADDR + `ITCM_SIZE));
    wire is_m1_itcm_r = (M1_AXI_ARADDR >= `ITCM_BASE_ADDR) && (M1_AXI_ARADDR < (`ITCM_BASE_ADDR + `ITCM_SIZE));
    wire is_m1_dtcm_r = (M1_AXI_ARADDR >= `DTCM_BASE_ADDR) && (M1_AXI_ARADDR < (`DTCM_BASE_ADDR + `DTCM_SIZE));
    wire is_m1_apb_r = (M1_AXI_ARADDR >= `APB_BASE_ADDR) && (M1_AXI_ARADDR < (`APB_BASE_ADDR + `APB_SIZE));
    // CLINT区域地址解码
    wire is_m1_clint_r = (M1_AXI_ARADDR >= `CLINT_BASE_ADDR) && (M1_AXI_ARADDR < (`CLINT_BASE_ADDR + `CLINT_SIZE));
    // PLIC区域地址解码
    wire is_m1_plic_r = (M1_AXI_ARADDR >= `PLIC_BASE_ADDR) && (M1_AXI_ARADDR < (`PLIC_BASE_ADDR + `PLIC_SIZE));

    wire is_m1_dtcm_w = (M1_AXI_AWADDR >= `DTCM_BASE_ADDR) && (M1_AXI_AWADDR < (`DTCM_BASE_ADDR + `DTCM_SIZE));
    wire is_m1_itcm_w = (M1_AXI_AWADDR >= `ITCM_BASE_ADDR) && (M1_AXI_AWADDR < (`ITCM_BASE_ADDR + `ITCM_SIZE));
    wire is_m1_apb_w = (M1_AXI_AWADDR >= `APB_BASE_ADDR) && (M1_AXI_AWADDR < (`APB_BASE_ADDR + `APB_SIZE));
    // CLINT区域写地址解码
    wire is_m1_clint_w = (M1_AXI_AWADDR >= `CLINT_BASE_ADDR) && (M1_AXI_AWADDR < (`CLINT_BASE_ADDR + `CLINT_SIZE));
    // PLIC区域写地址解码
    wire is_m1_plic_w = (M1_AXI_AWADDR >= `PLIC_BASE_ADDR) && (M1_AXI_AWADDR < (`PLIC_BASE_ADDR + `PLIC_SIZE));

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

    wire m0_has_active_itcm_r = m0_itcm_r_outstanding_cnt > 0;
    wire m1_has_active_itcm_r = m1_itcm_r_outstanding_cnt > 0;
    wire m1_has_active_dtcm_r = m1_dtcm_r_outstanding_cnt > 0;
    wire m1_has_active_apb_r = m1_apb_r_outstanding_cnt > 0;
    wire m1_has_active_clint_r = m1_clint_r_outstanding_cnt > 0;
    wire m1_has_active_plic_r = m1_plic_r_outstanding_cnt > 0;

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

    wire m1_has_active_itcm_w = m1_itcm_w_outstanding_cnt > 0;
    wire m1_has_active_dtcm_w = m1_dtcm_w_outstanding_cnt > 0;
    wire m1_has_active_apb_w = m1_apb_w_outstanding_cnt > 0;
    wire m1_has_active_clint_w = m1_clint_w_outstanding_cnt > 0;
    wire m1_has_active_plic_w = m1_plic_w_outstanding_cnt > 0;

    // AW通道事务信号
    wire m1_itcm_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_itcm_w;
    wire m1_dtcm_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_dtcm_w;
    wire m1_apb_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_apb_w;
    wire m1_clint_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_clint_w;
    wire m1_plic_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_plic_w;

    // W通道事务信号
    wire m1_itcm_w_trans = M1_AXI_WVALID && itcm_wready && m1_select_itcm_w;
    wire m1_dtcm_w_trans = M1_AXI_WVALID && dtcm_wready && m1_select_dtcm_w;
    wire m1_apb_w_trans = M1_AXI_WVALID && OM0_AXI_WREADY && m1_select_apb_w;
    wire m1_clint_w_trans = M1_AXI_WVALID && OM1_AXI_WREADY && m1_select_clint_w;
    wire m1_plic_w_trans = M1_AXI_WVALID && OM2_AXI_WREADY && m1_select_plic_w;

    // ----------- B通道（写响应）相关 -----------
    wire [3:0] m1_itcm_b_outstanding_cnt;  // M1访问ITCM的写响应outstanding
    wire [3:0] m1_dtcm_b_outstanding_cnt;  // M1访问DTCM的写响应outstanding
    wire [3:0] m1_apb_b_outstanding_cnt;  // M1访问APB的写响应outstanding
    wire [3:0] m1_clint_b_outstanding_cnt;  // M1访问CLINT的写响应outstanding
    wire [3:0] m1_plic_b_outstanding_cnt;  // M1访问PLIC的写响应outstanding

    wire m1_has_active_itcm_b = m1_itcm_b_outstanding_cnt > 0;
    wire m1_has_active_dtcm_b = m1_dtcm_b_outstanding_cnt > 0;
    wire m1_has_active_apb_b = m1_apb_b_outstanding_cnt > 0;
    wire m1_has_active_clint_b = m1_clint_b_outstanding_cnt > 0;
    wire m1_has_active_plic_b = m1_plic_b_outstanding_cnt > 0;

    // B通道事务信号
    wire m1_itcm_b_trans = itcm_bvalid && M1_AXI_BREADY && m1_select_itcm_b;
    wire m1_dtcm_b_trans = dtcm_bvalid && M1_AXI_BREADY && m1_select_dtcm_b;
    wire m1_apb_b_trans = OM0_AXI_BVALID && M1_AXI_BREADY && m1_select_apb_b;
    wire m1_clint_b_trans = OM1_AXI_BVALID && M1_AXI_BREADY && m1_select_clint_b;
    wire m1_plic_b_trans = OM2_AXI_BVALID && M1_AXI_BREADY && m1_select_plic_b;

    // ==================== outstanding计数器更新逻辑 ====================
    // 读通道计数器信号定义（下一个周期是否有未完成事务）
    wire [3:0] m0_itcm_r_outstanding_cnt_nxt;
    wire [3:0] m1_itcm_r_outstanding_cnt_nxt;
    wire [3:0] m1_dtcm_r_outstanding_cnt_nxt;
    wire [3:0] m1_apb_r_outstanding_cnt_nxt;
    wire [3:0] m1_clint_r_outstanding_cnt_nxt;
    wire [3:0] m1_itcm_w_outstanding_cnt_nxt;
    wire [3:0] m1_dtcm_w_outstanding_cnt_nxt;
    wire [3:0] m1_apb_w_outstanding_cnt_nxt;
    wire [3:0] m1_clint_w_outstanding_cnt_nxt;
    wire [3:0] m1_itcm_b_outstanding_cnt_nxt;
    wire [3:0] m1_dtcm_b_outstanding_cnt_nxt;
    wire [3:0] m1_apb_b_outstanding_cnt_nxt;
    wire [3:0] m1_clint_b_outstanding_cnt_nxt;
    wire [3:0] m1_plic_r_outstanding_cnt_nxt;
    wire [3:0] m1_plic_w_outstanding_cnt_nxt;
    wire [3:0] m1_plic_b_outstanding_cnt_nxt;

    wire m1_has_active_itcm_r_nxt = (m1_itcm_r_outstanding_cnt_nxt > 0);
    wire m1_has_active_dtcm_r_nxt = (m1_dtcm_r_outstanding_cnt_nxt > 0);
    wire m1_has_active_apb_r_nxt = (m1_apb_r_outstanding_cnt_nxt > 0);
    wire m1_has_active_clint_r_nxt = (m1_clint_r_outstanding_cnt_nxt > 0);
    wire m1_has_active_plic_r_nxt = (m1_plic_r_outstanding_cnt_nxt > 0);

    wire m1_has_active_itcm_w_nxt = (m1_itcm_w_outstanding_cnt_nxt > 0);
    wire m1_has_active_dtcm_w_nxt = (m1_dtcm_w_outstanding_cnt_nxt > 0);
    wire m1_has_active_apb_w_nxt = (m1_apb_w_outstanding_cnt_nxt > 0);
    wire m1_has_active_clint_w_nxt = (m1_clint_w_outstanding_cnt_nxt > 0);
    wire m1_has_active_plic_w_nxt = (m1_plic_w_outstanding_cnt_nxt > 0);

    wire m1_has_active_itcm_b_nxt = (m1_itcm_b_outstanding_cnt_nxt > 0);
    wire m1_has_active_dtcm_b_nxt = (m1_dtcm_b_outstanding_cnt_nxt > 0);
    wire m1_has_active_apb_b_nxt = (m1_apb_b_outstanding_cnt_nxt > 0);
    wire m1_has_active_clint_b_nxt = (m1_clint_b_outstanding_cnt_nxt > 0);
    wire m1_has_active_plic_b_nxt = (m1_plic_b_outstanding_cnt_nxt > 0);

    // R通道
    wire m0_itcm_inc = m0_itcm_ar_trans & ~m0_itcm_r_trans;
    wire m0_itcm_dec = ~m0_itcm_ar_trans & m0_itcm_r_trans;
    wire m0_itcm_keep = (m0_itcm_ar_trans & m0_itcm_r_trans) | (~m0_itcm_ar_trans & ~m0_itcm_r_trans);
    assign m0_itcm_r_outstanding_cnt_nxt =
            ({4{m0_itcm_inc}} & (m0_itcm_r_outstanding_cnt + 4'd1)) |
            ({4{m0_itcm_dec}} & (m0_itcm_r_outstanding_cnt - 4'd1)) |
            ({4{m0_itcm_keep}} & m0_itcm_r_outstanding_cnt);

    wire m1_itcm_inc = m1_itcm_ar_trans & ~m1_itcm_r_trans;
    wire m1_itcm_dec = ~m1_itcm_ar_trans & m1_itcm_r_trans;
    wire m1_itcm_keep = (m1_itcm_ar_trans & m1_itcm_r_trans) | (~m1_itcm_ar_trans & ~m1_itcm_r_trans);
    assign m1_itcm_r_outstanding_cnt_nxt =
            ({4{m1_itcm_inc}} & (m1_itcm_r_outstanding_cnt + 4'd1)) |
            ({4{m1_itcm_dec}} & (m1_itcm_r_outstanding_cnt - 4'd1)) |
            ({4{m1_itcm_keep}} & m1_itcm_r_outstanding_cnt);

    wire m1_dtcm_inc = m1_dtcm_ar_trans & ~m1_dtcm_r_trans;
    wire m1_dtcm_dec = ~m1_dtcm_ar_trans & m1_dtcm_r_trans;
    wire m1_dtcm_keep = (m1_dtcm_ar_trans & m1_dtcm_r_trans) | (~m1_dtcm_ar_trans & ~m1_dtcm_r_trans);
    assign m1_dtcm_r_outstanding_cnt_nxt =
            ({4{m1_dtcm_inc}} & (m1_dtcm_r_outstanding_cnt + 4'd1)) |
            ({4{m1_dtcm_dec}} & (m1_dtcm_r_outstanding_cnt - 4'd1)) |
            ({4{m1_dtcm_keep}} & m1_dtcm_r_outstanding_cnt);

    wire m1_apb_r_inc = m1_apb_ar_trans & ~m1_apb_r_trans;
    wire m1_apb_r_dec = ~m1_apb_ar_trans & m1_apb_r_trans;
    wire m1_apb_r_keep = (m1_apb_ar_trans & m1_apb_r_trans) | (~m1_apb_ar_trans & ~m1_apb_r_trans);
    assign m1_apb_r_outstanding_cnt_nxt =
            ({4{m1_apb_r_inc}} & (m1_apb_r_outstanding_cnt + 4'd1)) |
            ({4{m1_apb_r_dec}} & (m1_apb_r_outstanding_cnt - 4'd1)) |
            ({4{m1_apb_r_keep}} & m1_apb_r_outstanding_cnt);

    wire m1_clint_r_inc = m1_clint_ar_trans & ~m1_clint_r_trans;
    wire m1_clint_r_dec = ~m1_clint_ar_trans & m1_clint_r_trans;
    wire m1_clint_r_keep = (m1_clint_ar_trans & m1_clint_r_trans) | (~m1_clint_ar_trans & ~m1_clint_r_trans);
    assign m1_clint_r_outstanding_cnt_nxt =
            ({4{m1_clint_r_inc}} & (m1_clint_r_outstanding_cnt + 4'd1)) |
            ({4{m1_clint_r_dec}} & (m1_clint_r_outstanding_cnt - 4'd1)) |
            ({4{m1_clint_r_keep}} & m1_clint_r_outstanding_cnt);

    // PLIC R通道
    wire m1_plic_r_inc = m1_plic_ar_trans & ~m1_plic_r_trans;
    wire m1_plic_r_dec = ~m1_plic_ar_trans & m1_plic_r_trans;
    wire m1_plic_r_keep = (m1_plic_ar_trans & m1_plic_r_trans) | (~m1_plic_ar_trans & ~m1_plic_r_trans);
    assign m1_plic_r_outstanding_cnt_nxt =
            ({4{m1_plic_r_inc}} & (m1_plic_r_outstanding_cnt + 4'd1)) |
            ({4{m1_plic_r_dec}} & (m1_plic_r_outstanding_cnt - 4'd1)) |
            ({4{m1_plic_r_keep}} & m1_plic_r_outstanding_cnt);
    // W通道
    wire m1_itcm_w_inc = m1_itcm_aw_trans & ~m1_itcm_w_trans;
    wire m1_itcm_w_dec = ~m1_itcm_aw_trans & m1_itcm_w_trans;
    wire m1_itcm_w_keep = (m1_itcm_aw_trans & m1_itcm_w_trans) | (~m1_itcm_aw_trans & ~m1_itcm_w_trans);
    assign m1_itcm_w_outstanding_cnt_nxt =
            ({4{m1_itcm_w_inc}} & (m1_itcm_w_outstanding_cnt + 4'd1)) |
            ({4{m1_itcm_w_dec}} & (m1_itcm_w_outstanding_cnt - 4'd1)) |
            ({4{m1_itcm_w_keep}} & m1_itcm_w_outstanding_cnt);

    wire m1_dtcm_w_inc = m1_dtcm_aw_trans & ~m1_dtcm_w_trans;
    wire m1_dtcm_w_dec = ~m1_dtcm_aw_trans & m1_dtcm_w_trans;
    wire m1_dtcm_w_keep = (m1_dtcm_aw_trans & m1_dtcm_w_trans) | (~m1_dtcm_aw_trans & ~m1_dtcm_w_trans);
    assign m1_dtcm_w_outstanding_cnt_nxt =
            ({4{m1_dtcm_w_inc}} & (m1_dtcm_w_outstanding_cnt + 4'd1)) |
            ({4{m1_dtcm_w_dec}} & (m1_dtcm_w_outstanding_cnt - 4'd1)) |
            ({4{m1_dtcm_w_keep}} & m1_dtcm_w_outstanding_cnt);

    wire m1_apb_w_inc = m1_apb_aw_trans & ~m1_apb_w_trans;
    wire m1_apb_w_dec = ~m1_apb_aw_trans & m1_apb_w_trans;
    wire m1_apb_w_keep = (m1_apb_aw_trans & m1_apb_w_trans) | (~m1_apb_aw_trans & ~m1_apb_w_trans);
    assign m1_apb_w_outstanding_cnt_nxt =
            ({4{m1_apb_w_inc}} & (m1_apb_w_outstanding_cnt + 4'd1)) |
            ({4{m1_apb_w_dec}} & (m1_apb_w_outstanding_cnt - 4'd1)) |
            ({4{m1_apb_w_keep}} & m1_apb_w_outstanding_cnt);

    wire m1_clint_w_inc = m1_clint_aw_trans & ~m1_clint_w_trans;
    wire m1_clint_w_dec = ~m1_clint_aw_trans & m1_clint_w_trans;
    wire m1_clint_w_keep = (m1_clint_aw_trans & m1_clint_w_trans) | (~m1_clint_aw_trans & ~m1_clint_w_trans);
    assign m1_clint_w_outstanding_cnt_nxt =
            ({4{m1_clint_w_inc}} & (m1_clint_w_outstanding_cnt + 4'd1)) |
            ({4{m1_clint_w_dec}} & (m1_clint_w_outstanding_cnt - 4'd1)) |
            ({4{m1_clint_w_keep}} & m1_clint_w_outstanding_cnt);

    // PLIC W通道
    wire m1_plic_w_inc = m1_plic_aw_trans & ~m1_plic_w_trans;
    wire m1_plic_w_dec = ~m1_plic_aw_trans & m1_plic_w_trans;
    wire m1_plic_w_keep = (m1_plic_aw_trans & m1_plic_w_trans) | (~m1_plic_aw_trans & ~m1_plic_w_trans);
    assign m1_plic_w_outstanding_cnt_nxt =
            ({4{m1_plic_w_inc}} & (m1_plic_w_outstanding_cnt + 4'd1)) |
            ({4{m1_plic_w_dec}} & (m1_plic_w_outstanding_cnt - 4'd1)) |
            ({4{m1_plic_w_keep}} & m1_plic_w_outstanding_cnt);
    // B通道
    wire m1_itcm_b_inc = m1_itcm_aw_trans & ~m1_itcm_b_trans;
    wire m1_itcm_b_dec = ~m1_itcm_aw_trans & m1_itcm_b_trans;
    wire m1_itcm_b_keep = (m1_itcm_aw_trans & m1_itcm_b_trans) | (~m1_itcm_aw_trans & ~m1_itcm_b_trans);
    assign m1_itcm_b_outstanding_cnt_nxt =
            ({4{m1_itcm_b_inc}} & (m1_itcm_b_outstanding_cnt + 4'd1)) |
            ({4{m1_itcm_b_dec}} & (m1_itcm_b_outstanding_cnt - 4'd1)) |
            ({4{m1_itcm_b_keep}} & m1_itcm_b_outstanding_cnt);

    wire m1_dtcm_b_inc = m1_dtcm_aw_trans & ~m1_dtcm_b_trans;
    wire m1_dtcm_b_dec = ~m1_dtcm_aw_trans & m1_dtcm_b_trans;
    wire m1_dtcm_b_keep = (m1_dtcm_aw_trans & m1_dtcm_b_trans) | (~m1_dtcm_aw_trans & ~m1_dtcm_b_trans);
    assign m1_dtcm_b_outstanding_cnt_nxt =
            ({4{m1_dtcm_b_inc}} & (m1_dtcm_b_outstanding_cnt + 4'd1)) |
            ({4{m1_dtcm_b_dec}} & (m1_dtcm_b_outstanding_cnt - 4'd1)) |
            ({4{m1_dtcm_b_keep}} & m1_dtcm_b_outstanding_cnt);

    wire m1_apb_b_inc = m1_apb_aw_trans & ~m1_apb_b_trans;
    wire m1_apb_b_dec = ~m1_apb_aw_trans & m1_apb_b_trans;
    wire m1_apb_b_keep = (m1_apb_aw_trans & m1_apb_b_trans) | (~m1_apb_aw_trans & ~m1_apb_b_trans);
    assign m1_apb_b_outstanding_cnt_nxt =
            ({4{m1_apb_b_inc}} & (m1_apb_b_outstanding_cnt + 4'd1)) |
            ({4{m1_apb_b_dec}} & (m1_apb_b_outstanding_cnt - 4'd1)) |
            ({4{m1_apb_b_keep}} & m1_apb_b_outstanding_cnt);

    wire m1_clint_b_inc = m1_clint_aw_trans & ~m1_clint_b_trans;
    wire m1_clint_b_dec = ~m1_clint_aw_trans & m1_clint_b_trans;
    wire m1_clint_b_keep = (m1_clint_aw_trans & m1_clint_b_trans) | (~m1_clint_aw_trans & ~m1_clint_b_trans);
    assign m1_clint_b_outstanding_cnt_nxt =
            ({4{m1_clint_b_inc}} & (m1_clint_b_outstanding_cnt + 4'd1)) |
            ({4{m1_clint_b_dec}} & (m1_clint_b_outstanding_cnt - 4'd1)) |
            ({4{m1_clint_b_keep}} & m1_clint_b_outstanding_cnt);

    // PLIC B通道
    wire m1_plic_b_inc = m1_plic_aw_trans & ~m1_plic_b_trans;
    wire m1_plic_b_dec = ~m1_plic_aw_trans & m1_plic_b_trans;
    wire m1_plic_b_keep = (m1_plic_aw_trans & m1_plic_b_trans) | (~m1_plic_aw_trans & ~m1_plic_b_trans);
    assign m1_plic_b_outstanding_cnt_nxt =
            ({4{m1_plic_b_inc}} & (m1_plic_b_outstanding_cnt + 4'd1)) |
            ({4{m1_plic_b_dec}} & (m1_plic_b_outstanding_cnt - 4'd1)) |
            ({4{m1_plic_b_keep}} & m1_plic_b_outstanding_cnt);

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

    // ==================== outstanding计数器寄存器实例化 ====================
    // R通道
    gnrl_dfflr #(
        .DW(4)
    ) m0_itcm_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m0_itcm_r_outstanding_cnt_nxt),
        .qout (m0_itcm_r_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_itcm_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_itcm_r_outstanding_cnt_nxt),
        .qout (m1_itcm_r_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_dtcm_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_dtcm_r_outstanding_cnt_nxt),
        .qout (m1_dtcm_r_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_apb_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_apb_r_outstanding_cnt_nxt),
        .qout (m1_apb_r_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_clint_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_clint_r_outstanding_cnt_nxt),
        .qout (m1_clint_r_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_plic_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_plic_r_outstanding_cnt_nxt),
        .qout (m1_plic_r_outstanding_cnt)
    );

    // W通道
    gnrl_dfflr #(
        .DW(4)
    ) m1_itcm_w_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_itcm_w_outstanding_cnt_nxt),
        .qout (m1_itcm_w_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_dtcm_w_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_dtcm_w_outstanding_cnt_nxt),
        .qout (m1_dtcm_w_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_apb_w_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_apb_w_outstanding_cnt_nxt),
        .qout (m1_apb_w_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_clint_w_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_clint_w_outstanding_cnt_nxt),
        .qout (m1_clint_w_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_plic_w_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_plic_w_outstanding_cnt_nxt),
        .qout (m1_plic_w_outstanding_cnt)
    );

    // B通道
    gnrl_dfflr #(
        .DW(4)
    ) m1_itcm_b_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_itcm_b_outstanding_cnt_nxt),
        .qout (m1_itcm_b_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_dtcm_b_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_dtcm_b_outstanding_cnt_nxt),
        .qout (m1_dtcm_b_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_apb_b_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_apb_b_outstanding_cnt_nxt),
        .qout (m1_apb_b_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_clint_b_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_clint_b_outstanding_cnt_nxt),
        .qout (m1_clint_b_outstanding_cnt)
    );

    gnrl_dfflr #(
        .DW(4)
    ) m1_plic_b_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_plic_b_outstanding_cnt_nxt),
        .qout (m1_plic_b_outstanding_cnt)
    );

    // 为M0添加读响应FIFO - 用于缓存ITCM的读响应
    // FIFO深度设置为4，足够缓存一般的突发传输
    localparam RDATA_FIFO_DEPTH = 4;
    localparam RDATA_FIFO_ADDR_WIDTH = $clog2(RDATA_FIFO_DEPTH);

    // 读响应FIFO寄存器
    reg [C_AXI_ID_WIDTH-1:0] m0_rdata_rid[RDATA_FIFO_DEPTH-1:0];
    reg [C_AXI_DATA_WIDTH-1:0] m0_rdata_rdata[RDATA_FIFO_DEPTH-1:0];
    reg [1:0] m0_rdata_rresp[RDATA_FIFO_DEPTH-1:0];
    reg m0_rdata_rlast[RDATA_FIFO_DEPTH-1:0];

    // FIFO指针和控制信号
    reg [RDATA_FIFO_ADDR_WIDTH-1:0] m0_rdata_wr_ptr;
    reg [RDATA_FIFO_ADDR_WIDTH-1:0] m0_rdata_rd_ptr;
    reg [RDATA_FIFO_ADDR_WIDTH:0] m0_rdata_count;

    wire m0_rdata_empty = (m0_rdata_count == 0);
    wire m0_rdata_full = (m0_rdata_count == RDATA_FIFO_DEPTH);
    wire m0_rdata_all_cached = (m0_rdata_count == m0_itcm_r_outstanding_cnt);

    // FIFO操作控制
    wire m0_rdata_push = itcm_rvalid && m0_select_itcm_r &&
                        ((!M0_AXI_RREADY) || m0_rdata_count > 0);
    wire m0_rdata_pop = !m0_rdata_empty && M0_AXI_RREADY;

    // FIFO控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m0_rdata_wr_ptr <= 0;
            m0_rdata_rd_ptr <= 0;
            m0_rdata_count  <= 0;
            for (integer i = 0; i < RDATA_FIFO_DEPTH; i = i + 1) begin
                m0_rdata_rid[i]   <= 0;
                m0_rdata_rdata[i] <= 0;
                m0_rdata_rresp[i] <= 0;
                m0_rdata_rlast[i] <= 0;
            end
        end else begin
            // 同时推入和弹出
            if (m0_rdata_push && m0_rdata_pop) begin
                // 同时推入和弹出时，推入数据并移动指针
                m0_rdata_rid[m0_rdata_wr_ptr] <= itcm_rid;
                m0_rdata_rdata[m0_rdata_wr_ptr] <= itcm_rdata;
                m0_rdata_rresp[m0_rdata_wr_ptr] <= itcm_rresp;
                m0_rdata_rlast[m0_rdata_wr_ptr] <= itcm_rlast;
                m0_rdata_wr_ptr <= (m0_rdata_wr_ptr == RDATA_FIFO_DEPTH - 1) ? 0 : m0_rdata_wr_ptr + 1;
                m0_rdata_rd_ptr <= (m0_rdata_rd_ptr == RDATA_FIFO_DEPTH - 1) ? 0 : m0_rdata_rd_ptr + 1;
                // m0_rdata_count保持不变
            end  // 只推入
            else if (m0_rdata_push && !m0_rdata_full) begin
                m0_rdata_rid[m0_rdata_wr_ptr] <= itcm_rid;
                m0_rdata_rdata[m0_rdata_wr_ptr] <= itcm_rdata;
                m0_rdata_rresp[m0_rdata_wr_ptr] <= itcm_rresp;
                m0_rdata_rlast[m0_rdata_wr_ptr] <= itcm_rlast;
                m0_rdata_wr_ptr <= (m0_rdata_wr_ptr == RDATA_FIFO_DEPTH - 1) ? 0 : m0_rdata_wr_ptr + 1;
                m0_rdata_count <= m0_rdata_count + 1;
            end  // 只弹出
            else if (m0_rdata_pop) begin
                m0_rdata_rd_ptr <= (m0_rdata_rd_ptr == RDATA_FIFO_DEPTH - 1) ? 0 : m0_rdata_rd_ptr + 1;
                m0_rdata_count <= m0_rdata_count - 1;
            end
        end
    end


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
    assign m0_select_itcm_r = m0_has_active_itcm_r && !m1_select_itcm_r;
    // 处理M1对ITCM与外设的读数据通道选择 - 基于优先权寄存器决定
    // 谁有优先权，谁就获得读数据通道
    assign m1_select_itcm_r = m1_slave_sel_r[0] && m1_has_active_itcm_r && m0_rdata_all_cached;
    assign m1_select_dtcm_r = m1_slave_sel_r[1] && m1_has_active_dtcm_r;
    assign m1_select_apb_r = m1_slave_sel_r[2] && m1_has_active_apb_r;
    assign m1_select_clint_r = m1_slave_sel_r[3] && m1_has_active_clint_r;
    assign m1_select_plic_r = m1_slave_sel_r[4] && m1_has_active_plic_r;

    // 读通道ready信号连接 - 确保信号只连接到当前优先级对应的设备
    assign m0_itcm_rready = ((m0_select_itcm_r && M0_AXI_RREADY) || m0_rdata_push) && !(m0_rdata_full && !M0_AXI_RREADY);
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

    // ==================== 端口连接信号 ====================

    // 根据仲裁结果选择ITCM的输入
    assign itcm_arid = m1_itcm_ar_grant ? M1_AXI_ARID : (m0_itcm_ar_grant ? M0_AXI_ARID : '0);
    assign itcm_araddr = m1_itcm_ar_grant ? M1_AXI_ARADDR : (m0_itcm_ar_grant ? M0_AXI_ARADDR : '0);
    assign itcm_arlen = m1_itcm_ar_grant ? M1_AXI_ARLEN : (m0_itcm_ar_grant ? M0_AXI_ARLEN : '0);
    assign itcm_arsize = m1_itcm_ar_grant ? M1_AXI_ARSIZE : (m0_itcm_ar_grant ? M0_AXI_ARSIZE : '0);
    assign itcm_arburst = m1_itcm_ar_grant ? M1_AXI_ARBURST : (m0_itcm_ar_grant ? M0_AXI_ARBURST : '0);
    assign itcm_arlock = m1_itcm_ar_grant ? M1_AXI_ARLOCK : (m0_itcm_ar_grant ? M0_AXI_ARLOCK : '0);
    assign itcm_arcache = m1_itcm_ar_grant ? M1_AXI_ARCACHE : (m0_itcm_ar_grant ? M0_AXI_ARCACHE : '0);
    assign itcm_arprot = m1_itcm_ar_grant ? M1_AXI_ARPROT : (m0_itcm_ar_grant ? M0_AXI_ARPROT : '0);
    assign itcm_arvalid = m1_itcm_ar_grant ? M1_AXI_ARVALID : (m0_itcm_ar_grant ? M0_AXI_ARVALID : 1'b0);

    // DTCM只在被授权时连接到端口1
    assign dtcm_arid = M1_AXI_ARID;
    assign dtcm_araddr = M1_AXI_ARADDR;
    assign dtcm_arlen = M1_AXI_ARLEN;
    assign dtcm_arsize = M1_AXI_ARSIZE;
    assign dtcm_arburst = M1_AXI_ARBURST;
    assign dtcm_arlock = M1_AXI_ARLOCK;
    assign dtcm_arcache = M1_AXI_ARCACHE;
    assign dtcm_arprot = M1_AXI_ARPROT;
    assign dtcm_arvalid = m1_dtcm_ar_grant ? M1_AXI_ARVALID : 1'b0;

    // 端口输出连接
    // 端口0连接
    assign M0_AXI_ARREADY = is_m0_itcm_r ? (itcm_arready && m0_itcm_ar_grant) : 1'b0;
    assign M0_AXI_RID = !m0_rdata_empty ? m0_rdata_rid[m0_rdata_rd_ptr] : itcm_rid;
    assign M0_AXI_RDATA = !m0_rdata_empty ? m0_rdata_rdata[m0_rdata_rd_ptr] : itcm_rdata;
    assign M0_AXI_RRESP = !m0_rdata_empty ? m0_rdata_rresp[m0_rdata_rd_ptr] : itcm_rresp;
    assign M0_AXI_RLAST = !m0_rdata_empty ? m0_rdata_rlast[m0_rdata_rd_ptr] : itcm_rlast;
    assign M0_AXI_RUSER = 4'b0;

    // RVALID信号也需要考虑FIFO中的数据
    assign M0_AXI_RVALID = !m0_rdata_empty || (itcm_rvalid && m0_select_itcm_r);

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
    assign itcm_rready = m0_itcm_rready || m1_itcm_rready;
    assign dtcm_rready = m1_dtcm_rready;

    // 端口1读数据通道的选择逻辑
    assign M1_AXI_RID = m1_select_itcm_r ? itcm_rid :
                        m1_select_dtcm_r ? dtcm_rid : 0; // APB/CLINT/PLIC是AXI-Lite，无ID
    assign M1_AXI_RDATA = m1_select_itcm_r ? itcm_rdata :
                          m1_select_dtcm_r ? dtcm_rdata :
                          m1_select_apb_r ? OM0_AXI_RDATA :
                          m1_select_clint_r ? OM1_AXI_RDATA :
                          m1_select_plic_r ? OM2_AXI_RDATA : 0;
    assign M1_AXI_RRESP = m1_select_itcm_r ? itcm_rresp :
                          m1_select_dtcm_r ? dtcm_rresp :
                          m1_select_apb_r ? OM0_AXI_RRESP :
                          m1_select_clint_r ? OM1_AXI_RRESP :
                          m1_select_plic_r ? OM2_AXI_RRESP : 0;
    assign M1_AXI_RLAST = m1_select_itcm_r ? itcm_rlast :
                          m1_select_dtcm_r ? dtcm_rlast :
                          (m1_select_apb_r || m1_select_clint_r || m1_select_plic_r) ? 1'b1 : 0; // AXI-Lite每次传输都是LAST
    assign M1_AXI_RVALID = m1_select_itcm_r ? itcm_rvalid :
                           m1_select_dtcm_r ? dtcm_rvalid :
                           m1_select_apb_r ? OM0_AXI_RVALID :
                           m1_select_clint_r ? OM1_AXI_RVALID :
                           m1_select_plic_r ? OM2_AXI_RVALID : 0;
    // 端口1写响应通道的选择逻辑
    assign M1_AXI_BID = m1_select_itcm_b ? itcm_bid :
                        m1_select_dtcm_b ? dtcm_bid : 0; // APB/CLINT/PLIC是AXI-Lite，无ID
    assign M1_AXI_BRESP = m1_select_itcm_b ? itcm_bresp :
                          m1_select_dtcm_b ? dtcm_bresp :
                          m1_select_apb_b ? OM0_AXI_BRESP :
                          m1_select_clint_b ? OM1_AXI_BRESP :
                          m1_select_plic_b ? OM2_AXI_BRESP : 0;
    assign M1_AXI_BVALID = m1_select_itcm_b ? itcm_bvalid :
                           m1_select_dtcm_b ? dtcm_bvalid :
                           m1_select_apb_b ? OM0_AXI_BVALID :
                           m1_select_clint_b ? OM1_AXI_BVALID :
                           m1_select_plic_b ? OM2_AXI_BVALID : 0;

    // 更新Ready信号连接
    assign M1_AXI_ARREADY = (is_m1_itcm_r && itcm_arready) || 
                            (is_m1_dtcm_r && dtcm_arready) ||
                            (is_m1_apb_r && OM0_AXI_ARREADY) ||
                            (is_m1_clint_r && OM1_AXI_ARREADY) ||
                            (is_m1_plic_r && OM2_AXI_ARREADY);
    assign M1_AXI_AWREADY = (is_m1_itcm_w && itcm_awready) || 
                            (is_m1_dtcm_w && dtcm_awready) ||
                            (is_m1_apb_w && OM0_AXI_AWREADY) ||
                            (is_m1_clint_w && OM1_AXI_AWREADY) ||
                            (is_m1_plic_w && OM2_AXI_AWREADY);
    assign M1_AXI_WREADY = (m1_select_itcm_w && itcm_wready) ||
                           (m1_select_dtcm_w && dtcm_wready) ||
                           (m1_select_apb_w && OM0_AXI_WREADY) ||
                           (m1_select_clint_w && OM1_AXI_WREADY) ||
                           (m1_select_plic_w && OM2_AXI_WREADY);

    // ITCM实例连接
    gnrl_ram_pseudo_dual_axi #(
        .ADDR_WIDTH        (ITCM_ADDR_WIDTH),
        .DATA_WIDTH        (DATA_WIDTH),
        .INIT_MEM          (`INIT_ITCM),
        .INIT_FILE         (`ITCM_INIT_FILE),
        .C_S_AXI_ID_WIDTH  (C_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ITCM_ADDR_WIDTH)
    ) itcm_inst (
        // 全局信号
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(rst_n),

        // 写地址通道
        .S_AXI_AWID   (M1_AXI_AWID),
        .S_AXI_AWADDR (M1_AXI_AWADDR[ITCM_ADDR_WIDTH-1:0]),
        .S_AXI_AWLEN  (M1_AXI_AWLEN),
        .S_AXI_AWSIZE (M1_AXI_AWSIZE),
        .S_AXI_AWBURST(M1_AXI_AWBURST),
        .S_AXI_AWLOCK (M1_AXI_AWLOCK),
        .S_AXI_AWCACHE(M1_AXI_AWCACHE),
        .S_AXI_AWPROT (M1_AXI_AWPROT),
        .S_AXI_AWVALID(itcm_wvalid),
        .S_AXI_AWREADY(itcm_awready),

        // 写数据通道
        .S_AXI_WDATA (M1_AXI_WDATA),
        .S_AXI_WSTRB (M1_AXI_WSTRB),
        .S_AXI_WLAST (M1_AXI_WLAST),
        .S_AXI_WVALID(itcm_wvalid),
        .S_AXI_WREADY(itcm_wready),

        // 写响应通道
        .S_AXI_BID   (itcm_bid),
        .S_AXI_BRESP (itcm_bresp),
        .S_AXI_BVALID(itcm_bvalid),
        .S_AXI_BREADY(itcm_bready),

        // 读地址通道
        .S_AXI_ARID   (itcm_arid),
        .S_AXI_ARADDR (itcm_araddr[ITCM_ADDR_WIDTH-1:0]),
        .S_AXI_ARLEN  (itcm_arlen),
        .S_AXI_ARSIZE (itcm_arsize),
        .S_AXI_ARBURST(itcm_arburst),
        .S_AXI_ARLOCK (itcm_arlock),
        .S_AXI_ARCACHE(itcm_arcache),
        .S_AXI_ARPROT (itcm_arprot),
        .S_AXI_ARVALID(itcm_arvalid),
        .S_AXI_ARREADY(itcm_arready),

        // 读数据通道
        .S_AXI_RID   (itcm_rid),
        .S_AXI_RDATA (itcm_rdata),
        .S_AXI_RRESP (itcm_rresp),
        .S_AXI_RLAST (itcm_rlast),
        .S_AXI_RVALID(itcm_rvalid),
        .S_AXI_RREADY(itcm_rready)
    );

    // DTCM实例连接
    gnrl_ram_pseudo_dual_axi #(
        .ADDR_WIDTH        (DTCM_ADDR_WIDTH),
        .DATA_WIDTH        (DATA_WIDTH),
        .INIT_MEM          (0),
        .C_S_AXI_ID_WIDTH  (C_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(DTCM_ADDR_WIDTH)
    ) dtcm_inst (
        // 全局信号
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(rst_n),

        // 写地址通道
        .S_AXI_AWID   (M1_AXI_AWID),
        .S_AXI_AWADDR (M1_AXI_AWADDR[DTCM_ADDR_WIDTH-1:0]),
        .S_AXI_AWLEN  (M1_AXI_AWLEN),
        .S_AXI_AWSIZE (M1_AXI_AWSIZE),
        .S_AXI_AWBURST(M1_AXI_AWBURST),
        .S_AXI_AWLOCK (M1_AXI_AWLOCK),
        .S_AXI_AWCACHE(M1_AXI_AWCACHE),
        .S_AXI_AWPROT (M1_AXI_AWPROT),
        .S_AXI_AWVALID(dtcm_wvalid),
        .S_AXI_AWREADY(dtcm_awready),

        // 写数据通道
        .S_AXI_WDATA (M1_AXI_WDATA),
        .S_AXI_WSTRB (M1_AXI_WSTRB),
        .S_AXI_WLAST (M1_AXI_WLAST),
        .S_AXI_WVALID(dtcm_wvalid),
        .S_AXI_WREADY(dtcm_wready),

        // 写响应通道
        .S_AXI_BID   (dtcm_bid),
        .S_AXI_BRESP (dtcm_bresp),
        .S_AXI_BVALID(dtcm_bvalid),
        .S_AXI_BREADY(dtcm_bready),

        // 读地址通道
        .S_AXI_ARID   (dtcm_arid),
        .S_AXI_ARADDR (dtcm_araddr[DTCM_ADDR_WIDTH-1:0]),
        .S_AXI_ARLEN  (dtcm_arlen),
        .S_AXI_ARSIZE (dtcm_arsize),
        .S_AXI_ARBURST(dtcm_arburst),
        .S_AXI_ARLOCK (dtcm_arlock),
        .S_AXI_ARCACHE(dtcm_arcache),
        .S_AXI_ARPROT (dtcm_arprot),
        .S_AXI_ARVALID(dtcm_arvalid),
        .S_AXI_ARREADY(dtcm_arready),

        // 读数据通道
        .S_AXI_RID   (dtcm_rid),
        .S_AXI_RDATA (dtcm_rdata),
        .S_AXI_RRESP (dtcm_rresp),
        .S_AXI_RLAST (dtcm_rlast),
        .S_AXI_RVALID(dtcm_rvalid),
        .S_AXI_RREADY(dtcm_rready)
    );

endmodule
