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

// AXI Master多合一复用器
// 将多个AXI Master接口复用到一个输出接口
module axi_master_mux #(
    // AXI接口参数
    parameter int C_AXI_ID_WIDTH   = 2,   // AXI ID宽度
    parameter int C_AXI_DATA_WIDTH = 32,  // AXI数据宽度
    parameter int C_AXI_ADDR_WIDTH = 32   // AXI地址宽度
) (
    // 全局信号
    input wire clk,   // 时钟信号
    input wire rst_n, // 复位信号（低有效）

    // Master 0 接口 - 只读（指令获取）
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

    // Master 1 接口 - 完整读写通道（数据访问）
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

    // 输出AXI接口（复用后的单一接口）
    // AXI写地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] S_AXI_AWID,
    output wire [C_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    output wire [                 7:0] S_AXI_AWLEN,
    output wire [                 2:0] S_AXI_AWSIZE,
    output wire [                 1:0] S_AXI_AWBURST,
    output wire                        S_AXI_AWLOCK,
    output wire [                 3:0] S_AXI_AWCACHE,
    output wire [                 2:0] S_AXI_AWPROT,
    output wire [                 3:0] S_AXI_AWQOS,
    output wire [                 3:0] S_AXI_AWUSER,
    output wire                        S_AXI_AWVALID,
    input  wire                        S_AXI_AWREADY,

    // AXI写数据通道
    output wire [    C_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    output wire                            S_AXI_WLAST,
    output wire                            S_AXI_WVALID,
    input  wire                            S_AXI_WREADY,

    // AXI写响应通道
    input  wire [C_AXI_ID_WIDTH-1:0] S_AXI_BID,
    input  wire [               1:0] S_AXI_BRESP,
    input  wire                      S_AXI_BVALID,
    output wire                      S_AXI_BREADY,

    // AXI读地址通道
    output wire [  C_AXI_ID_WIDTH-1:0] S_AXI_ARID,
    output wire [C_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    output wire [                 7:0] S_AXI_ARLEN,
    output wire [                 2:0] S_AXI_ARSIZE,
    output wire [                 1:0] S_AXI_ARBURST,
    output wire                        S_AXI_ARLOCK,
    output wire [                 3:0] S_AXI_ARCACHE,
    output wire [                 2:0] S_AXI_ARPROT,
    output wire [                 3:0] S_AXI_ARQOS,
    output wire [                 3:0] S_AXI_ARUSER,
    output wire                        S_AXI_ARVALID,
    input  wire                        S_AXI_ARREADY,

    // AXI读数据通道
    input  wire [  C_AXI_ID_WIDTH-1:0] S_AXI_RID,
    input  wire [C_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    input  wire [                 1:0] S_AXI_RRESP,
    input  wire                        S_AXI_RLAST,
    input  wire [                 3:0] S_AXI_RUSER,
    input  wire                        S_AXI_RVALID,
    output wire                        S_AXI_RREADY
);

    // ==================== 仲裁逻辑 ====================
    // Outstanding计数器
    wire [3:0] m0_r_outstanding_cnt;
    wire [3:0] m1_r_outstanding_cnt;
    wire [3:0] m1_w_outstanding_cnt;
    wire [3:0] m1_b_outstanding_cnt;

    wire m0_has_active_r;
    wire m1_has_active_r;
    wire m1_has_active_w;
    wire m1_has_active_b;

    // 仲裁信号
    wire m0_ar_grant;
    wire m1_ar_grant;
    wire m1_aw_grant;

    // 选择信号
    wire m0_select_r;
    wire m1_select_r;
    wire m1_select_w;
    wire m1_select_b;

    // 事务信号
    wire m0_ar_trans = M0_AXI_ARVALID && M0_AXI_ARREADY;
    wire m0_r_trans = M0_AXI_RVALID && M0_AXI_RREADY && M0_AXI_RLAST && m0_select_r;
    wire m1_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY;
    wire m1_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && M1_AXI_RLAST && m1_select_r;
    wire m1_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY;
    wire m1_w_trans = M1_AXI_WVALID && M1_AXI_WREADY && M1_AXI_WLAST && m1_select_w;
    wire m1_b_trans = M1_AXI_BVALID && M1_AXI_BREADY && m1_select_b;

    // Outstanding计数器实例化
    bus_trans_cnt m0_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m0_ar_trans),
        .transaction_end          (m0_r_trans),
        .outstanding_count        (m0_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m0_has_active_r),
        .has_active_transaction_nxt ()  // M0不需要预测信号
    );

    bus_trans_cnt m1_r_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_ar_trans),
        .transaction_end          (m1_r_trans),
        .outstanding_count        (m1_r_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_r),
        .has_active_transaction_nxt ()  // M1不需要预测信号
    );

    bus_trans_cnt m1_w_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_aw_trans),
        .transaction_end          (m1_w_trans),
        .outstanding_count        (m1_w_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_w),
        .has_active_transaction_nxt ()  // M1不需要预测信号
    );

    bus_trans_cnt m1_b_counter (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .transaction_start        (m1_aw_trans),
        .transaction_end          (m1_b_trans),
        .outstanding_count        (m1_b_outstanding_cnt),
        .outstanding_count_nxt    (),  // 未使用
        .has_active_transaction   (m1_has_active_b),
        .has_active_transaction_nxt ()  // M1不需要预测信号
    );

    // ==================== 仲裁逻辑 ====================
    // 请求信号定义
    wire m0_has_ar_req = M0_AXI_ARVALID;  // M0有读地址请求
    wire m1_has_ar_req = M1_AXI_ARVALID;  // M1有读地址请求
    wire m1_has_aw_req = M1_AXI_AWVALID;  // M1有写地址请求

    // 主机间仲裁逻辑（参考axi_interconnect_bak.sv）：
    // 1. 如果一方有未完成事务，优先保证其完成
    // 2. 如果都没有未完成事务或都有未完成事务，M1优先
    // 3. 地址通道可以立即切换，所以优先处理新请求
    assign m0_ar_grant = m0_has_ar_req && !m1_has_ar_req && !m1_has_active_r;
    assign m1_ar_grant = m1_has_ar_req;  // M1总是优先获得读地址通道
    assign m1_aw_grant = m1_has_aw_req;  // M1独享写地址通道

    // 数据通道选择逻辑
    // 处理M0与M1对读数据通道的竞争
    // 如果M0没有未完成的读请求，那么才能转交读响应通道给M1
    assign m0_select_r = m0_has_active_r;
    assign m1_select_r = m1_has_active_r && !m0_has_active_r;
    // M1独享写通道，不需要仲裁
    assign m1_select_w = 1'b1;  // M1独享写数据通道
    assign m1_select_b = 1'b1;  // M1独享写响应通道

    // ==================== 地址通道复用 ====================
    // 读地址通道
    assign S_AXI_ARID    = m1_ar_grant ? M1_AXI_ARID    : (m0_ar_grant ? M0_AXI_ARID    : '0);
    assign S_AXI_ARADDR  = m1_ar_grant ? M1_AXI_ARADDR  : (m0_ar_grant ? M0_AXI_ARADDR  : '0);
    assign S_AXI_ARLEN   = m1_ar_grant ? M1_AXI_ARLEN   : (m0_ar_grant ? M0_AXI_ARLEN   : '0);
    assign S_AXI_ARSIZE  = m1_ar_grant ? M1_AXI_ARSIZE  : (m0_ar_grant ? M0_AXI_ARSIZE  : '0);
    assign S_AXI_ARBURST = m1_ar_grant ? M1_AXI_ARBURST : (m0_ar_grant ? M0_AXI_ARBURST : '0);
    assign S_AXI_ARLOCK  = m1_ar_grant ? M1_AXI_ARLOCK  : (m0_ar_grant ? M0_AXI_ARLOCK  : '0);
    assign S_AXI_ARCACHE = m1_ar_grant ? M1_AXI_ARCACHE : (m0_ar_grant ? M0_AXI_ARCACHE : '0);
    assign S_AXI_ARPROT  = m1_ar_grant ? M1_AXI_ARPROT  : (m0_ar_grant ? M0_AXI_ARPROT  : '0);
    assign S_AXI_ARQOS   = m1_ar_grant ? M1_AXI_ARQOS   : (m0_ar_grant ? M0_AXI_ARQOS   : '0);
    assign S_AXI_ARUSER  = m1_ar_grant ? M1_AXI_ARUSER  : (m0_ar_grant ? M0_AXI_ARUSER  : '0);
    assign S_AXI_ARVALID = m1_ar_grant ? M1_AXI_ARVALID : (m0_ar_grant ? M0_AXI_ARVALID : 1'b0);

    // 写地址通道（只有M1有写操作）
    assign S_AXI_AWID    = M1_AXI_AWID;
    assign S_AXI_AWADDR  = M1_AXI_AWADDR;
    assign S_AXI_AWLEN   = M1_AXI_AWLEN;
    assign S_AXI_AWSIZE  = M1_AXI_AWSIZE;
    assign S_AXI_AWBURST = M1_AXI_AWBURST;
    assign S_AXI_AWLOCK  = M1_AXI_AWLOCK;
    assign S_AXI_AWCACHE = M1_AXI_AWCACHE;
    assign S_AXI_AWPROT  = M1_AXI_AWPROT;
    assign S_AXI_AWQOS   = M1_AXI_AWQOS;
    assign S_AXI_AWUSER  = M1_AXI_AWUSER;
    assign S_AXI_AWVALID = m1_aw_grant ? M1_AXI_AWVALID : 1'b0;

    // ==================== 数据通道复用 ====================
    // 写数据通道（只有M1有写操作）
    assign S_AXI_WDATA  = M1_AXI_WDATA;
    assign S_AXI_WSTRB  = M1_AXI_WSTRB;
    assign S_AXI_WLAST  = M1_AXI_WLAST;
    assign S_AXI_WVALID = m1_select_w ? M1_AXI_WVALID : 1'b0;

    // 读数据通道ready信号
    assign S_AXI_RREADY = (m0_select_r && M0_AXI_RREADY) || (m1_select_r && M1_AXI_RREADY);

    // 写响应通道ready信号
    assign S_AXI_BREADY = m1_select_b ? M1_AXI_BREADY : 1'b0;

    // ==================== 响应通道分发 ====================
    // Master 0 读响应
    assign M0_AXI_RID    = m0_select_r ? S_AXI_RID    : '0;
    assign M0_AXI_RDATA  = m0_select_r ? S_AXI_RDATA  : '0;
    assign M0_AXI_RRESP  = m0_select_r ? S_AXI_RRESP  : '0;
    assign M0_AXI_RLAST  = m0_select_r ? S_AXI_RLAST  : '0;
    assign M0_AXI_RUSER  = m0_select_r ? S_AXI_RUSER  : '0;
    assign M0_AXI_RVALID = m0_select_r ? S_AXI_RVALID : 1'b0;

    // Master 1 读响应
    assign M1_AXI_RID    = m1_select_r ? S_AXI_RID    : '0;
    assign M1_AXI_RDATA  = m1_select_r ? S_AXI_RDATA  : '0;
    assign M1_AXI_RRESP  = m1_select_r ? S_AXI_RRESP  : '0;
    assign M1_AXI_RLAST  = m1_select_r ? S_AXI_RLAST  : '0;
    assign M1_AXI_RUSER  = m1_select_r ? S_AXI_RUSER  : '0;
    assign M1_AXI_RVALID = m1_select_r ? S_AXI_RVALID : 1'b0;

    // Master 1 写响应
    assign M1_AXI_BID    = m1_select_b ? S_AXI_BID    : '0;
    assign M1_AXI_BRESP  = m1_select_b ? S_AXI_BRESP  : '0;
    assign M1_AXI_BVALID = m1_select_b ? S_AXI_BVALID : 1'b0;

    // ==================== Ready信号反向连接 ====================
    assign M0_AXI_ARREADY = m0_ar_grant ? S_AXI_ARREADY : 1'b0;
    assign M1_AXI_ARREADY = m1_ar_grant ? S_AXI_ARREADY : 1'b0;
    assign M1_AXI_AWREADY = m1_aw_grant ? S_AXI_AWREADY : 1'b0;
    assign M1_AXI_WREADY  = m1_select_w ? S_AXI_WREADY  : 1'b0;

endmodule