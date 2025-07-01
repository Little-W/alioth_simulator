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
    parameter C_AXI_ID_WIDTH   = 1,   // AXI ID宽度
    parameter C_AXI_DATA_WIDTH = 32,  // AXI数据宽度
    parameter C_AXI_ADDR_WIDTH = 32   // AXI地址宽度
) (
    // 全局信号
    input wire clk,   // 时钟信号
    input wire rst_n, // 复位信号（低有效）

    // 外设相关引脚
    input  wire         cnt_clk,            // 计数器时钟
    input  wire [63:0]  virtual_sw_input,   // 虚拟开关输入
    input  wire [7:0]   virtual_key_input,  // 虚拟按键输入
    output wire [39:0]  virtual_seg_output, // 虚拟七段显示器输出
    output wire [31:0]  virtual_led_output, // 虚拟LED输出

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
    input  wire                        M1_AXI_RREADY
);

    // 地址解码逻辑
    wire is_m0_itcm_r = (M0_AXI_ARADDR >= `ITCM_BASE_ADDR) && (M0_AXI_ARADDR < (`ITCM_BASE_ADDR + `ITCM_SIZE));
    wire is_m1_itcm_r = (M1_AXI_ARADDR >= `ITCM_BASE_ADDR) && (M1_AXI_ARADDR < (`ITCM_BASE_ADDR + `ITCM_SIZE));
    wire is_m1_perip_r = (M1_AXI_ARADDR >= `PERIP_BRIDGE_BASE_ADDR) && (M1_AXI_ARADDR < `PERIP_BRIDGE_END_ADDR);

    wire is_m1_perip_w = (M1_AXI_AWADDR >= `PERIP_BRIDGE_BASE_ADDR) && (M1_AXI_AWADDR < `PERIP_BRIDGE_END_ADDR);
    wire is_m1_itcm_w = (M1_AXI_AWADDR >= `ITCM_BASE_ADDR) && (M1_AXI_AWADDR < (`ITCM_BASE_ADDR + `ITCM_SIZE));

    // Outstanding事务计数器 - 针对不同内存区域独立追踪
    wire [3:0] m0_itcm_r_outstanding_cnt;  // M0访问ITCM的读事务计数器
    wire [3:0] m1_itcm_r_outstanding_cnt;  // M1访问ITCM的读事务计数器
    wire [3:0] m1_perip_r_outstanding_cnt;  // M1访问外设的读事务计数器
    wire [3:0] m1_itcm_w_outstanding_cnt;  // M1访问ITCM的写事务计数器
    wire [3:0] m1_perip_w_outstanding_cnt;  // M1访问外设的写事务计数器

    // 事务跟踪信号
    wire m0_itcm_ar_trans = M0_AXI_ARVALID && M0_AXI_ARREADY && is_m0_itcm_r;
    wire m0_itcm_r_trans = M0_AXI_RVALID && M0_AXI_RREADY && M0_AXI_RLAST;

    wire m1_itcm_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_itcm_r;
    wire m1_perip_ar_trans = M1_AXI_ARVALID && M1_AXI_ARREADY && is_m1_perip_r;
    wire m1_itcm_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && M1_AXI_RLAST && m1_itcm_r_outstanding_cnt > 0;
    wire m1_perip_r_trans = M1_AXI_RVALID && M1_AXI_RREADY && M1_AXI_RLAST && m1_perip_r_outstanding_cnt > 0;

    // 写事务信号
    wire m1_itcm_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_itcm_w;
    wire m1_perip_aw_trans = M1_AXI_AWVALID && M1_AXI_AWREADY && is_m1_perip_w;
    wire m1_itcm_b_trans = M1_AXI_BVALID && M1_AXI_BREADY && m1_itcm_w_outstanding_cnt > 0;
    wire m1_perip_b_trans = M1_AXI_BVALID && M1_AXI_BREADY && m1_perip_w_outstanding_cnt > 0;

    // 计数器下一值计算 - 使用与或逻辑实现并行
    // M0 ITCM读outstanding计数器
    wire m0_itcm_inc = m0_itcm_ar_trans & ~m0_itcm_r_trans;  // 只增加不减少
    wire m0_itcm_dec = ~m0_itcm_ar_trans & m0_itcm_r_trans;  // 只减少不增加
    wire m0_itcm_keep = (m0_itcm_ar_trans & m0_itcm_r_trans) | (~m0_itcm_ar_trans & ~m0_itcm_r_trans); // 保持不变

    wire [3:0] m0_itcm_r_outstanding_cnt_nxt = 
        ({4{m0_itcm_inc}} & (m0_itcm_r_outstanding_cnt + 4'd1)) |
        ({4{m0_itcm_dec}} & (m0_itcm_r_outstanding_cnt - 4'd1)) |
        ({4{m0_itcm_keep}} & m0_itcm_r_outstanding_cnt);

    // M1 ITCM读outstanding计数器
    wire m1_itcm_inc = m1_itcm_ar_trans & ~m1_itcm_r_trans;
    wire m1_itcm_dec = ~m1_itcm_ar_trans & m1_itcm_r_trans;
    wire m1_itcm_keep = (m1_itcm_ar_trans & m1_itcm_r_trans) | (~m1_itcm_ar_trans & ~m1_itcm_r_trans);

    wire [3:0] m1_itcm_r_outstanding_cnt_nxt = 
        ({4{m1_itcm_inc}} & (m1_itcm_r_outstanding_cnt + 4'd1)) |
        ({4{m1_itcm_dec}} & (m1_itcm_r_outstanding_cnt - 4'd1)) |
        ({4{m1_itcm_keep}} & m1_itcm_r_outstanding_cnt);

    // M1 外设读outstanding计数器
    wire m1_perip_inc = m1_perip_ar_trans & ~m1_perip_r_trans;
    wire m1_perip_dec = ~m1_perip_ar_trans & m1_perip_r_trans;
    wire m1_perip_keep = (m1_perip_ar_trans & m1_perip_r_trans) | (~m1_perip_ar_trans & ~m1_perip_r_trans);

    wire [3:0] m1_perip_r_outstanding_cnt_nxt = 
        ({4{m1_perip_inc}} & (m1_perip_r_outstanding_cnt + 4'd1)) |
        ({4{m1_perip_dec}} & (m1_perip_r_outstanding_cnt - 4'd1)) |
        ({4{m1_perip_keep}} & m1_perip_r_outstanding_cnt);

    // M1 ITCM写outstanding计数器
    wire m1_itcm_w_inc = m1_itcm_aw_trans & ~m1_itcm_b_trans;
    wire m1_itcm_w_dec = ~m1_itcm_aw_trans & m1_itcm_b_trans;
    wire m1_itcm_w_keep = (m1_itcm_aw_trans & m1_itcm_b_trans) | (~m1_itcm_aw_trans & ~m1_itcm_b_trans);

    wire [3:0] m1_itcm_w_outstanding_cnt_nxt = 
        ({4{m1_itcm_w_inc}} & (m1_itcm_w_outstanding_cnt + 4'd1)) |
        ({4{m1_itcm_w_dec}} & (m1_itcm_w_outstanding_cnt - 4'd1)) |
        ({4{m1_itcm_w_keep}} & m1_itcm_w_outstanding_cnt);

    // M1 外设写outstanding计数器
    wire m1_perip_w_inc = m1_perip_aw_trans & ~m1_perip_b_trans;
    wire m1_perip_w_dec = ~m1_perip_aw_trans & m1_perip_b_trans;
    wire m1_perip_w_keep = (m1_perip_aw_trans & m1_perip_b_trans) | (~m1_perip_aw_trans & ~m1_perip_b_trans);

    wire [3:0] m1_perip_w_outstanding_cnt_nxt = 
        ({4{m1_perip_w_inc}} & (m1_perip_w_outstanding_cnt + 4'd1)) |
        ({4{m1_perip_w_dec}} & (m1_perip_w_outstanding_cnt - 4'd1)) |
        ({4{m1_perip_w_keep}} & m1_perip_w_outstanding_cnt);

    // 使用gnrl_dfflr实例化计数器寄存器
    gnrl_dfflr #(
        .DW(4)
    ) m0_itcm_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),                           // 始终使能
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
    ) m1_perip_r_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_perip_r_outstanding_cnt_nxt),
        .qout (m1_perip_r_outstanding_cnt)
    );

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
    ) m1_perip_w_cnt_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (1'b1),
        .dnxt (m1_perip_w_outstanding_cnt_nxt),
        .qout (m1_perip_w_outstanding_cnt)
    );


    // ITCM与外设的接口信号
    // ITCM读地址通道
    wire                        itcm_arready;
    wire [  C_AXI_ID_WIDTH-1:0] itcm_arid;
    wire [C_AXI_ADDR_WIDTH-1:0] itcm_araddr;
    wire [                 7:0] itcm_arlen;
    wire [                 2:0] itcm_arsize;
    wire [                 1:0] itcm_arburst;
    wire                        itcm_arlock;
    wire [                 3:0] itcm_arcache;
    wire [                 2:0] itcm_arprot;
    wire                        itcm_arvalid;

    // ITCM读数据通道
    wire [  C_AXI_ID_WIDTH-1:0] itcm_rid;
    wire [C_AXI_DATA_WIDTH-1:0] itcm_rdata;
    wire [                 1:0] itcm_rresp;
    wire                        itcm_rlast;
    wire                        itcm_rvalid;
    wire                        itcm_rready;

    // 外设读地址通道
    wire                        perip_arready;
    wire [  C_AXI_ID_WIDTH-1:0] perip_arid;
    wire [C_AXI_ADDR_WIDTH-1:0] perip_araddr;
    wire [                 7:0] perip_arlen;
    wire [                 2:0] perip_arsize;
    wire [                 1:0] perip_arburst;
    wire                        perip_arlock;
    wire [                 3:0] perip_arcache;
    wire [                 2:0] perip_arprot;
    wire                        perip_arvalid;

    // 外设读数据通道
    wire [  C_AXI_ID_WIDTH-1:0] perip_rid;
    wire [C_AXI_DATA_WIDTH-1:0] perip_rdata;
    wire [                 1:0] perip_rresp;
    wire                        perip_rlast;
    wire                        perip_rvalid;
    wire                        perip_rready;

    // 处理读通道ready信号的连接
    assign itcm_rready = m0_itcm_rready || m1_itcm_rready;
    assign perip_rready = m1_perip_rready;

    // 写响应通道连接
    wire [C_AXI_ID_WIDTH-1:0] itcm_bid;
    wire [1:0] itcm_bresp;
    wire itcm_bvalid;
    wire itcm_wready;
    wire itcm_awready;

    wire [C_AXI_ID_WIDTH-1:0] perip_bid;
    wire [1:0] perip_bresp;
    wire perip_bvalid;
    wire perip_wready;
    wire perip_awready;

    // ==================== 主机间仲裁逻辑（M0 vs M1 对 ITCM）====================
    // M0和M1同时访问ITCM时的仲裁标志
    wire m0_has_itcm_ar_req = M0_AXI_ARVALID && is_m0_itcm_r;  // M0有ITCM读请求
    wire m1_has_itcm_ar_req = M1_AXI_ARVALID && is_m1_itcm_r;  // M1有ITCM读请求
    wire m0_has_active_itcm_r = m0_itcm_r_outstanding_cnt > 0;  // M0有未完成的ITCM读事务
    wire m1_has_active_itcm_r = m1_itcm_r_outstanding_cnt > 0;  // M1有未完成的ITCM读事务

    // 主机间仲裁逻辑：
    // 1. 如果一方有未完成事务，优先保证其完成
    // 2. 如果都没有未完成事务或都有未完成事务，M1优先
    // 3. 地址通道可以立即切换，所以优先处理新请求
    wire m0_itcm_ar_grant = !m1_has_itcm_ar_req;

    wire m1_itcm_ar_grant = m1_has_itcm_ar_req;  // M1总是优先获得ITCM读地址通道

    // ==================== 从机选择逻辑（M1对ITCM vs 外设）====================
    wire m1_has_perip_ar_req = M1_AXI_ARVALID && is_m1_perip_r;  // M1有外设读请求
    wire m1_has_active_perip_r = m1_perip_r_outstanding_cnt > 0;  // M1有未完成的外设读事务

    // 地址通道可以立即切换
    wire m1_perip_ar_grant = m1_has_perip_ar_req;  // 地址通道授权可立即给外设
    wire m1_perip_grant = m1_perip_ar_grant;  // M1访问外设的授权

    // ==================== 读数据通道仲裁 ====================
    // 处理M0与M1对ITCM的读数据通道竞争
    wire m0_itcm_r_priority = m0_has_active_itcm_r;  // M0已有未完成事务时具有优先权
    wire m1_itcm_r_priority = m1_has_active_itcm_r || 
                             (!m0_has_active_itcm_r && m1_itcm_ar_grant); // M1已有未完成事务或M0无未完成事务且M1获得读地址授权时具有优先权

    // 处理M1对ITCM与外设的读数据通道选择
    // 优先级：1. 有未完成事务的存储区域 2. 无未完成事务时根据最近发出的地址请求
    wire m1_select_itcm_r = m1_has_active_itcm_r || (!m1_has_active_perip_r && m1_itcm_ar_grant);

    wire m1_select_perip_r = m1_has_active_perip_r || (!m1_has_active_itcm_r && m1_perip_ar_grant);

    // 读通道ready信号连接
    wire m0_itcm_rready = m0_itcm_r_priority && M0_AXI_RREADY;
    wire m1_itcm_rready = m1_itcm_r_priority && M1_AXI_RREADY;
    wire m1_perip_rready = m1_select_perip_r && M1_AXI_RREADY;

    // ==================== 写事务仲裁逻辑 ====================
    // 写事务活动状态跟踪
    wire m1_has_itcm_aw_req = M1_AXI_AWVALID && is_m1_itcm_w;  // M1有ITCM写请求
    wire m1_has_perip_aw_req = M1_AXI_AWVALID && is_m1_perip_w;  // M1有外设写请求
    wire m1_has_active_itcm_w = m1_itcm_w_outstanding_cnt > 0;  // M1有未完成的ITCM写事务
    wire m1_has_active_perip_w = m1_perip_w_outstanding_cnt > 0;  // M1有未完成的外设写事务

    // 写地址通道授权
    wire m1_itcm_aw_grant = m1_has_itcm_aw_req;  // M1的ITCM写地址通道授权
    wire m1_perip_aw_grant = m1_has_perip_aw_req;  // M1的外设写地址通道授权

    // 写数据通道授权 - 与写地址通道一致
    wire m1_itcm_w_grant = m1_itcm_aw_grant;  // M1的ITCM写数据通道授权
    wire m1_perip_w_grant = m1_perip_aw_grant;  // M1的外设写数据通道授权

    // ==================== 写响应通道仲裁（仅M1） ====================
    // 处理M1对ITCM与外设的写响应通道选择
    // 优先级：1. 有未完成事务的存储区域 2. 无未完成事务时根据最近发出的地址请求
    wire m1_select_itcm_b = m1_has_active_itcm_w || (!m1_has_active_perip_w && m1_itcm_aw_grant);

    wire m1_select_perip_b = m1_has_active_perip_w || (!m1_has_active_itcm_w && m1_perip_aw_grant);

    // 写响应通道ready信号连接
    wire itcm_bready = m1_select_itcm_b && M1_AXI_BREADY;
    wire perip_bready = m1_select_perip_b && M1_AXI_BREADY;

    // ==================== 端口连接信号 ====================

    // 根据仲裁结果选择ITCM的输入
    assign itcm_arid = m1_itcm_ar_grant ? M1_AXI_ARID : M0_AXI_ARID;
    assign itcm_araddr = m1_itcm_ar_grant ? M1_AXI_ARADDR : M0_AXI_ARADDR;
    assign itcm_arlen = m1_itcm_ar_grant ? M1_AXI_ARLEN : M0_AXI_ARLEN;
    assign itcm_arsize = m1_itcm_ar_grant ? M1_AXI_ARSIZE : M0_AXI_ARSIZE;
    assign itcm_arburst = m1_itcm_ar_grant ? M1_AXI_ARBURST : M0_AXI_ARBURST;
    assign itcm_arlock = m1_itcm_ar_grant ? M1_AXI_ARLOCK : M0_AXI_ARLOCK;
    assign itcm_arcache = m1_itcm_ar_grant ? M1_AXI_ARCACHE : M0_AXI_ARCACHE;
    assign itcm_arprot = m1_itcm_ar_grant ? M1_AXI_ARPROT : M0_AXI_ARPROT;
    assign itcm_arvalid = m1_itcm_ar_grant ? M1_AXI_ARVALID : (m0_itcm_ar_grant ? M0_AXI_ARVALID : 1'b0);

    // 外设只在被授权时连接到端口1
    assign perip_arid = M1_AXI_ARID;
    assign perip_araddr = M1_AXI_ARADDR;
    assign perip_arlen = M1_AXI_ARLEN;
    assign perip_arsize = M1_AXI_ARSIZE;
    assign perip_arburst = M1_AXI_ARBURST;
    assign perip_arlock = M1_AXI_ARLOCK;
    assign perip_arcache = M1_AXI_ARCACHE;
    assign perip_arprot = M1_AXI_ARPROT;
    assign perip_arvalid = m1_perip_grant ? M1_AXI_ARVALID : 1'b0;

    // 端口输出连接
    // 端口0连接
    assign M0_AXI_ARREADY = is_m0_itcm_r ? (itcm_arready && m0_itcm_ar_grant) : 1'b0;
    assign M0_AXI_RID = itcm_rid;
    assign M0_AXI_RDATA = itcm_rdata;
    assign M0_AXI_RRESP = itcm_rresp;
    assign M0_AXI_RLAST = itcm_rlast;
    assign M0_AXI_RUSER = 4'b0;
    assign M0_AXI_RVALID = itcm_rvalid && m0_itcm_r_outstanding_cnt > 0;

    // 端口1连接
    // 读地址通道
    assign M1_AXI_ARREADY = (is_m1_itcm_r && itcm_arready && m1_itcm_ar_grant) || 
                           (is_m1_perip_r && perip_arready && m1_perip_grant);

    // 读数据通道 - 根据活跃的事务选择源
    assign M1_AXI_RID = (m1_itcm_r_outstanding_cnt > 0) ? itcm_rid : perip_rid;
    assign M1_AXI_RDATA = (m1_itcm_r_outstanding_cnt > 0) ? itcm_rdata : perip_rdata;
    assign M1_AXI_RRESP = (m1_itcm_r_outstanding_cnt > 0) ? itcm_rresp : perip_rresp;
    assign M1_AXI_RLAST = (m1_itcm_r_outstanding_cnt > 0) ? itcm_rlast : perip_rlast;
    assign M1_AXI_RUSER = 4'b0;
    assign M1_AXI_RVALID = (m1_itcm_r_outstanding_cnt > 0 && itcm_rvalid) || 
                           (m1_perip_r_outstanding_cnt > 0 && perip_rvalid);

    // 输出连接 - M1写通道
    // 写地址通道可以立即切换
    assign M1_AXI_AWREADY = (m1_itcm_aw_grant && itcm_awready) || 
                           (m1_perip_aw_grant && perip_awready);

    // 写数据通道可以立即切换，跟随写地址通道
    assign M1_AXI_WREADY = (m1_itcm_w_grant && itcm_wready) || (m1_perip_w_grant && perip_wready);

    // 输出连接 - M1写响应通道
    assign M1_AXI_BVALID = (m1_select_itcm_b && itcm_bvalid) || (m1_select_perip_b && perip_bvalid);
    assign M1_AXI_BID = m1_select_itcm_b ? itcm_bid : perip_bid;
    assign M1_AXI_BRESP = m1_select_itcm_b ? itcm_bresp : perip_bresp;

    // ITCM实例化的写通道连接
    wire itcm_awvalid = m1_itcm_aw_grant && M1_AXI_AWVALID;
    wire itcm_wvalid = m1_itcm_w_grant && M1_AXI_WVALID;

    // 外设实例化的写通道连接
    wire perip_awvalid = m1_perip_aw_grant && M1_AXI_AWVALID;
    wire perip_wvalid = m1_perip_w_grant && M1_AXI_WVALID;

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
        .S_AXI_AWVALID(itcm_awvalid),
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

    // 外设桥接AXI接口模块
    perip_bridge_axi #(
        .ADDR_WIDTH        (DTCM_ADDR_WIDTH),
        .DATA_WIDTH        (DATA_WIDTH),
        .C_S_AXI_ID_WIDTH  (C_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
    ) perip_bridge_axi_inst (
        // 全局信号
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(rst_n),

        // 写地址通道
        .S_AXI_AWID   (M1_AXI_AWID),
        .S_AXI_AWADDR (M1_AXI_AWADDR),
        .S_AXI_AWLEN  (M1_AXI_AWLEN),
        .S_AXI_AWSIZE (M1_AXI_AWSIZE),
        .S_AXI_AWBURST(M1_AXI_AWBURST),
        .S_AXI_AWLOCK (M1_AXI_AWLOCK),
        .S_AXI_AWCACHE(M1_AXI_AWCACHE),
        .S_AXI_AWPROT (M1_AXI_AWPROT),
        .S_AXI_AWVALID(perip_awvalid),
        .S_AXI_AWREADY(perip_awready),

        // 写数据通道
        .S_AXI_WDATA (M1_AXI_WDATA),
        .S_AXI_WSTRB (M1_AXI_WSTRB),
        .S_AXI_WLAST (M1_AXI_WLAST),
        .S_AXI_WVALID(perip_wvalid),
        .S_AXI_WREADY(perip_wready),

        // 写响应通道
        .S_AXI_BID   (perip_bid),
        .S_AXI_BRESP (perip_bresp),
        .S_AXI_BVALID(perip_bvalid),
        .S_AXI_BREADY(perip_bready),

        // 读地址通道
        .S_AXI_ARID   (perip_arid),
        .S_AXI_ARADDR (perip_araddr),
        .S_AXI_ARLEN  (perip_arlen),
        .S_AXI_ARSIZE (perip_arsize),
        .S_AXI_ARBURST(perip_arburst),
        .S_AXI_ARLOCK (perip_arlock),
        .S_AXI_ARCACHE(perip_arcache),
        .S_AXI_ARPROT (perip_arprot),
        .S_AXI_ARVALID(perip_arvalid),
        .S_AXI_ARREADY(perip_arready),

        // 读数据通道
        .S_AXI_RID   (perip_rid),
        .S_AXI_RDATA (perip_rdata),
        .S_AXI_RRESP (perip_rresp),
        .S_AXI_RLAST (perip_rlast),
        .S_AXI_RVALID(perip_rvalid),
        .S_AXI_RREADY(perip_rready),

        // 外设相关引脚连接
        .cnt_clk            (cnt_clk),
        .virtual_sw_input   (virtual_sw_input),
        .virtual_key_input  (virtual_key_input),
        .virtual_seg_output (virtual_seg_output),
        .virtual_led_output (virtual_led_output)
    );

endmodule
