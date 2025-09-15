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

// alioth soc顶层模块
module alioth_soc_top (
    input wire clk,
    input wire rst_n,

    // UART0
    input  wire uart0_rxd_i,
    output wire uart0_txd_o,

    // GPIO0
    input  wire [31:0] gpio0_in_i,
    output wire [31:0] gpio0_out_o,
    output wire [31:0] gpio0_dir_o,
    // GPIO1
    input  wire [31:0] gpio1_in_i,
    output wire [31:0] gpio1_out_o,
    output wire [31:0] gpio1_dir_o,

    // Timer
    input wire low_speed_clk_i
);

    // AXI2APB桥模块信号
    wire                           S_AXI_ACLK;
    wire                           S_AXI_ARESETN;
    wire [     `APB_DEV_COUNT-1:0] PSEL;
    wire                           PENABLE;
    wire [    `APB_ADDR_WIDTH-1:0] PADDR;
    wire                           PWRITE;
    wire [    `BUS_DATA_WIDTH-1:0] PWDATA;
    wire [    `BUS_DATA_WIDTH-1:0] PRDATA        [`APB_DEV_COUNT];
    wire [     `APB_DEV_COUNT-1:0] PREADY;
    wire [     `APB_DEV_COUNT-1:0] PSLVERR;

    // AXI信号声明
    wire [    `BUS_ADDR_WIDTH-1:0] S_AXI_AWADDR;
    wire [                    2:0] S_AXI_AWPROT;
    wire                           S_AXI_AWVALID;
    wire                           S_AXI_AWREADY;
    wire [    `BUS_DATA_WIDTH-1:0] S_AXI_WDATA;
    wire [(`BUS_DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    wire                           S_AXI_WVALID;
    wire                           S_AXI_WREADY;
    wire [                    1:0] S_AXI_BRESP;
    wire                           S_AXI_BVALID;
    wire                           S_AXI_BREADY;
    wire [    `BUS_ADDR_WIDTH-1:0] S_AXI_ARADDR;
    wire [                    2:0] S_AXI_ARPROT;
    wire                           S_AXI_ARVALID;
    wire                           S_AXI_ARREADY;
    wire [    `BUS_DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [                    1:0] S_AXI_RRESP;
    wire                           S_AXI_RVALID;
    wire                           S_AXI_RREADY;

    // === APB时钟和复位信号定义 ===
    wire                           PCLK;
    wire                           PRESETn;

    // === 中断信号内部连线 ===
    wire uart0_event, uart1_event;
    wire spi_events;
    wire i2c0_interrupt, i2c1_interrupt;
    wire gpio0_interrupt, gpio1_interrupt;
    wire [ 3:0] timer_events;

    // 中断向量，优先级顺序：GPIO1, GPIO0, UART1, UART0, I2C1, I2C0, SPI, Timer[3:0]
    wire [10:0] irq_vec;
    assign irq_vec = {
        gpio1_interrupt,  // [10]
        gpio0_interrupt,  // [9]
        uart1_event,  // [8]
        uart0_event,  // [7]
        i2c1_interrupt,  // [6]
        i2c0_interrupt,  // [5]
        spi_events,  // [4]
        timer_events  // [3:0]
    };

    // M0/M1 AXI接口信号定义
    wire [   `BUS_ID_WIDTH-1:0] M0_AXI_ARID;
    wire [`INST_ADDR_WIDTH-1:0] M0_AXI_ARADDR;
    wire [                 7:0] M0_AXI_ARLEN;
    wire [                 2:0] M0_AXI_ARSIZE;
    wire [                 1:0] M0_AXI_ARBURST;
    wire                        M0_AXI_ARLOCK;
    wire [                 3:0] M0_AXI_ARCACHE;
    wire [                 2:0] M0_AXI_ARPROT;
    wire [                 3:0] M0_AXI_ARQOS;
    wire [                 3:0] M0_AXI_ARUSER;
    wire                        M0_AXI_ARVALID;
    wire                        M0_AXI_ARREADY;
    wire [   `BUS_ID_WIDTH-1:0] M0_AXI_RID;
    wire [`INST_DATA_WIDTH-1:0] M0_AXI_RDATA;
    wire [                 1:0] M0_AXI_RRESP;
    wire                        M0_AXI_RLAST;
    wire [                 3:0] M0_AXI_RUSER;
    wire                        M0_AXI_RVALID;
    wire                        M0_AXI_RREADY;

    wire [   `BUS_ID_WIDTH-1:0] M1_AXI_AWID;
    wire [                31:0] M1_AXI_AWADDR;
    wire [                 7:0] M1_AXI_AWLEN;
    wire [                 2:0] M1_AXI_AWSIZE;
    wire [                 1:0] M1_AXI_AWBURST;
    wire                        M1_AXI_AWLOCK;
    wire [                 3:0] M1_AXI_AWCACHE;
    wire [                 2:0] M1_AXI_AWPROT;
    wire [                 3:0] M1_AXI_AWQOS;
    wire                        M1_AXI_AWUSER;
    wire                        M1_AXI_AWVALID;
    wire                        M1_AXI_AWREADY;
    wire [                31:0] M1_AXI_WDATA;
    wire [                 3:0] M1_AXI_WSTRB;
    wire                        M1_AXI_WLAST;
    wire                        M1_AXI_WVALID;
    wire                        M1_AXI_WREADY;
    wire [   `BUS_ID_WIDTH-1:0] M1_AXI_BID;
    wire [                 1:0] M1_AXI_BRESP;
    wire                        M1_AXI_BVALID;
    wire                        M1_AXI_BREADY;
    wire [   `BUS_ID_WIDTH-1:0] M1_AXI_ARID;
    wire [                31:0] M1_AXI_ARADDR;
    wire [                 7:0] M1_AXI_ARLEN;
    wire [                 2:0] M1_AXI_ARSIZE;
    wire [                 1:0] M1_AXI_ARBURST;
    wire                        M1_AXI_ARLOCK;
    wire [                 3:0] M1_AXI_ARCACHE;
    wire [                 2:0] M1_AXI_ARPROT;
    wire [                 3:0] M1_AXI_ARQOS;
    wire                        M1_AXI_ARUSER;
    wire                        M1_AXI_ARVALID;
    wire                        M1_AXI_ARREADY;
    wire [   `BUS_ID_WIDTH-1:0] M1_AXI_RID;
    wire [                31:0] M1_AXI_RDATA;
    wire [                 1:0] M1_AXI_RRESP;
    wire                        M1_AXI_RLAST;
    wire                        M1_AXI_RUSER;
    wire                        M1_AXI_RVALID;
    wire                        M1_AXI_RREADY;

    // IMEM/DMEM AXI接口信号定义
    wire [   `BUS_ID_WIDTH-1:0] IMEM_AXI_AWID;
    wire [                31:0] IMEM_AXI_AWADDR;
    wire [                 7:0] IMEM_AXI_AWLEN;
    wire [                 2:0] IMEM_AXI_AWSIZE;
    wire [                 1:0] IMEM_AXI_AWBURST;
    wire                        IMEM_AXI_AWLOCK;
    wire [                 3:0] IMEM_AXI_AWCACHE;
    wire [                 2:0] IMEM_AXI_AWPROT;
    wire                        IMEM_AXI_AWVALID;
    wire                        IMEM_AXI_AWREADY;
    wire [                31:0] IMEM_AXI_WDATA;
    wire [                 3:0] IMEM_AXI_WSTRB;
    wire                        IMEM_AXI_WLAST;
    wire                        IMEM_AXI_WVALID;
    wire                        IMEM_AXI_WREADY;
    wire [   `BUS_ID_WIDTH-1:0] IMEM_AXI_BID;
    wire [                 1:0] IMEM_AXI_BRESP;
    wire                        IMEM_AXI_BVALID;
    wire                        IMEM_AXI_BREADY;
    wire [   `BUS_ID_WIDTH-1:0] IMEM_AXI_ARID;
    wire [                31:0] IMEM_AXI_ARADDR;
    wire [                 7:0] IMEM_AXI_ARLEN;
    wire [                 2:0] IMEM_AXI_ARSIZE;
    wire [                 1:0] IMEM_AXI_ARBURST;
    wire                        IMEM_AXI_ARLOCK;
    wire [                 3:0] IMEM_AXI_ARCACHE;
    wire [                 2:0] IMEM_AXI_ARPROT;
    wire                        IMEM_AXI_ARVALID;
    wire                        IMEM_AXI_ARREADY;
    wire [   `BUS_ID_WIDTH-1:0] IMEM_AXI_RID;
    wire [                31:0] IMEM_AXI_RDATA;
    wire [                 1:0] IMEM_AXI_RRESP;
    wire                        IMEM_AXI_RLAST;
    wire                        IMEM_AXI_RVALID;
    wire                        IMEM_AXI_RREADY;

    wire [   `BUS_ID_WIDTH-1:0] DMEM_AXI_AWID;
    wire [                31:0] DMEM_AXI_AWADDR;
    wire [                 7:0] DMEM_AXI_AWLEN;
    wire [                 2:0] DMEM_AXI_AWSIZE;
    wire [                 1:0] DMEM_AXI_AWBURST;
    wire                        DMEM_AXI_AWLOCK;
    wire [                 3:0] DMEM_AXI_AWCACHE;
    wire [                 2:0] DMEM_AXI_AWPROT;
    wire                        DMEM_AXI_AWVALID;
    wire                        DMEM_AXI_AWREADY;
    wire [                31:0] DMEM_AXI_WDATA;
    wire [                 3:0] DMEM_AXI_WSTRB;
    wire                        DMEM_AXI_WLAST;
    wire                        DMEM_AXI_WVALID;
    wire                        DMEM_AXI_WREADY;
    wire [   `BUS_ID_WIDTH-1:0] DMEM_AXI_BID;
    wire [                 1:0] DMEM_AXI_BRESP;
    wire                        DMEM_AXI_BVALID;
    wire                        DMEM_AXI_BREADY;
    wire [   `BUS_ID_WIDTH-1:0] DMEM_AXI_ARID;
    wire [                31:0] DMEM_AXI_ARADDR;
    wire [                 7:0] DMEM_AXI_ARLEN;
    wire [                 2:0] DMEM_AXI_ARSIZE;
    wire [                 1:0] DMEM_AXI_ARBURST;
    wire                        DMEM_AXI_ARLOCK;
    wire [                 3:0] DMEM_AXI_ARCACHE;
    wire [                 2:0] DMEM_AXI_ARPROT;
    wire                        DMEM_AXI_ARVALID;
    wire                        DMEM_AXI_ARREADY;
    wire [   `BUS_ID_WIDTH-1:0] DMEM_AXI_RID;
    wire [                31:0] DMEM_AXI_RDATA;
    wire [                 1:0] DMEM_AXI_RRESP;
    wire                        DMEM_AXI_RLAST;
    wire                        DMEM_AXI_RVALID;
    wire                        DMEM_AXI_RREADY;

    // alioth处理器核模块例化
    cpu_top u_cpu_top (
        .clk        (clk),
        .rst_n      (rst_n),
        .irq_sources(irq_vec), // 中断向量输入

        // M0 AXI接口 - IFU指令获取
        .M0_AXI_ARID   (M0_AXI_ARID),
        .M0_AXI_ARADDR (M0_AXI_ARADDR),
        .M0_AXI_ARLEN  (M0_AXI_ARLEN),
        .M0_AXI_ARSIZE (M0_AXI_ARSIZE),
        .M0_AXI_ARBURST(M0_AXI_ARBURST),
        .M0_AXI_ARLOCK (M0_AXI_ARLOCK),
        .M0_AXI_ARCACHE(M0_AXI_ARCACHE),
        .M0_AXI_ARPROT (M0_AXI_ARPROT),
        .M0_AXI_ARQOS  (M0_AXI_ARQOS),
        .M0_AXI_ARUSER (M0_AXI_ARUSER),
        .M0_AXI_ARVALID(M0_AXI_ARVALID),
        .M0_AXI_ARREADY(M0_AXI_ARREADY),
        .M0_AXI_RID    (M0_AXI_RID),
        .M0_AXI_RDATA  (M0_AXI_RDATA),
        .M0_AXI_RRESP  (M0_AXI_RRESP),
        .M0_AXI_RLAST  (M0_AXI_RLAST),
        .M0_AXI_RUSER  (M0_AXI_RUSER),
        .M0_AXI_RVALID (M0_AXI_RVALID),
        .M0_AXI_RREADY (M0_AXI_RREADY),

        // M1 AXI接口 - EXU数据访问
        .M1_AXI_AWID   (M1_AXI_AWID),
        .M1_AXI_AWADDR (M1_AXI_AWADDR),
        .M1_AXI_AWLEN  (M1_AXI_AWLEN),
        .M1_AXI_AWSIZE (M1_AXI_AWSIZE),
        .M1_AXI_AWBURST(M1_AXI_AWBURST),
        .M1_AXI_AWLOCK (M1_AXI_AWLOCK),
        .M1_AXI_AWCACHE(M1_AXI_AWCACHE),
        .M1_AXI_AWPROT (M1_AXI_AWPROT),
        .M1_AXI_AWQOS  (M1_AXI_AWQOS),
        .M1_AXI_AWUSER (M1_AXI_AWUSER),
        .M1_AXI_AWVALID(M1_AXI_AWVALID),
        .M1_AXI_AWREADY(M1_AXI_AWREADY),
        .M1_AXI_WDATA  (M1_AXI_WDATA),
        .M1_AXI_WSTRB  (M1_AXI_WSTRB),
        .M1_AXI_WLAST  (M1_AXI_WLAST),
        .M1_AXI_WUSER  (),
        .M1_AXI_WVALID (M1_AXI_WVALID),
        .M1_AXI_WREADY (M1_AXI_WREADY),
        .M1_AXI_BID    (M1_AXI_BID),
        .M1_AXI_BRESP  (M1_AXI_BRESP),
        .M1_AXI_BUSER  (),
        .M1_AXI_BVALID (M1_AXI_BVALID),
        .M1_AXI_BREADY (M1_AXI_BREADY),
        .M1_AXI_ARID   (M1_AXI_ARID),
        .M1_AXI_ARADDR (M1_AXI_ARADDR),
        .M1_AXI_ARLEN  (M1_AXI_ARLEN),
        .M1_AXI_ARSIZE (M1_AXI_ARSIZE),
        .M1_AXI_ARBURST(M1_AXI_ARBURST),
        .M1_AXI_ARLOCK (M1_AXI_ARLOCK),
        .M1_AXI_ARCACHE(M1_AXI_ARCACHE),
        .M1_AXI_ARPROT (M1_AXI_ARPROT),
        .M1_AXI_ARQOS  (M1_AXI_ARQOS),
        .M1_AXI_ARUSER (M1_AXI_ARUSER),
        .M1_AXI_ARVALID(M1_AXI_ARVALID),
        .M1_AXI_ARREADY(M1_AXI_ARREADY),
        .M1_AXI_RID    (M1_AXI_RID),
        .M1_AXI_RDATA  (M1_AXI_RDATA),
        .M1_AXI_RRESP  (M1_AXI_RRESP),
        .M1_AXI_RLAST  (M1_AXI_RLAST),
        .M1_AXI_RUSER  (M1_AXI_RUSER),
        .M1_AXI_RVALID (M1_AXI_RVALID),
        .M1_AXI_RREADY (M1_AXI_RREADY),
        // OM1 AXI-Lite
        .OM1_AXI_ACLK   (OM1_AXI_ACLK),
        .OM1_AXI_ARESETN(OM1_AXI_ARESETN),
        .OM1_AXI_AWADDR (OM1_AXI_AWADDR),
        .OM1_AXI_AWPROT (OM1_AXI_AWPROT),
        .OM1_AXI_AWVALID(OM1_AXI_AWVALID),
        .OM1_AXI_AWREADY(OM1_AXI_AWREADY),
        .OM1_AXI_WDATA  (OM1_AXI_WDATA),
        .OM1_AXI_WSTRB  (OM1_AXI_WSTRB),
        .OM1_AXI_WVALID (OM1_AXI_WVALID),
        .OM1_AXI_WREADY (OM1_AXI_WREADY),
        .OM1_AXI_BRESP  (OM1_AXI_BRESP),
        .OM1_AXI_BVALID (OM1_AXI_BVALID),
        .OM1_AXI_BREADY (OM1_AXI_BREADY),
        .OM1_AXI_ARADDR (OM1_AXI_ARADDR),
        .OM1_AXI_ARPROT (OM1_AXI_ARPROT),
        .OM1_AXI_ARVALID(OM1_AXI_ARVALID),
        .OM1_AXI_ARREADY(OM1_AXI_ARREADY),
        .OM1_AXI_RDATA  (OM1_AXI_RDATA),
        .OM1_AXI_RRESP  (OM1_AXI_RRESP),
        .OM1_AXI_RVALID (OM1_AXI_RVALID),
        .OM1_AXI_RREADY (OM1_AXI_RREADY),
        // OM2 AXI-Lite
        .OM2_AXI_ACLK   (OM2_AXI_ACLK),
        .OM2_AXI_ARESETN(OM2_AXI_ARESETN),
        .OM2_AXI_AWADDR (OM2_AXI_AWADDR),
        .OM2_AXI_AWPROT (OM2_AXI_AWPROT),
        .OM2_AXI_AWVALID(OM2_AXI_AWVALID),
        .OM2_AXI_AWREADY(OM2_AXI_AWREADY),
        .OM2_AXI_WDATA  (OM2_AXI_WDATA),
        .OM2_AXI_WSTRB  (OM2_AXI_WSTRB),
        .OM2_AXI_WVALID (OM2_AXI_WVALID),
        .OM2_AXI_WREADY (OM2_AXI_WREADY),
        .OM2_AXI_BRESP  (OM2_AXI_BRESP),
        .OM2_AXI_BVALID (OM2_AXI_BVALID),
        .OM2_AXI_BREADY (OM2_AXI_BREADY),
        .OM2_AXI_ARADDR (OM2_AXI_ARADDR),
        .OM2_AXI_ARPROT (OM2_AXI_ARPROT),
        .OM2_AXI_ARVALID(OM2_AXI_ARVALID),
        .OM2_AXI_ARREADY(OM2_AXI_ARREADY),
        .OM2_AXI_RDATA  (OM2_AXI_RDATA),
        .OM2_AXI_RRESP  (OM2_AXI_RRESP),
        .OM2_AXI_RVALID (OM2_AXI_RVALID),
        .OM2_AXI_RREADY (OM2_AXI_RREADY)
    );

    // AXI2APB桥模块例化
    axi2apb #(
        .C_S_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(`APB_ADDR_WIDTH),
        .C_APB_ADDR_WIDTH  (`APB_SLAVE_ADDR_WIDTH)
    ) u_axi2apb (
        .S_AXI_ACLK   (S_AXI_ACLK),     // AXI-Lite时钟信号
        .S_AXI_ARESETN(S_AXI_ARESETN),  // AXI-Lite复位信号
        .S_AXI_AWADDR (S_AXI_AWADDR),   // AXI写地址信号
        .S_AXI_AWPROT (S_AXI_AWPROT),   // AXI写保护信号
        .S_AXI_AWVALID(S_AXI_AWVALID),  // AXI写地址有效信号
        .S_AXI_AWREADY(S_AXI_AWREADY),  // AXI写地址准备信号
        .S_AXI_WDATA  (S_AXI_WDATA),    // AXI写数据信号
        .S_AXI_WSTRB  (S_AXI_WSTRB),    // AXI写数据字节选择信号
        .S_AXI_WVALID (S_AXI_WVALID),   // AXI写数据有效信号
        .S_AXI_WREADY (S_AXI_WREADY),   // AXI写数据准备信号
        .S_AXI_BRESP  (S_AXI_BRESP),    // AXI写响应信号
        .S_AXI_BVALID (S_AXI_BVALID),   // AXI写响应有效信号
        .S_AXI_BREADY (S_AXI_BREADY),   // AXI写响应准备信号
        .S_AXI_ARADDR (S_AXI_ARADDR),   // AXI读地址信号
        .S_AXI_ARPROT (S_AXI_ARPROT),   // AXI读保护信号
        .S_AXI_ARVALID(S_AXI_ARVALID),  // AXI读地址有效信号
        .S_AXI_ARREADY(S_AXI_ARREADY),  // AXI读地址准备信号
        .S_AXI_RDATA  (S_AXI_RDATA),    // AXI读数据信号
        .S_AXI_RRESP  (S_AXI_RRESP),    // AXI读响应信号
        .S_AXI_RVALID (S_AXI_RVALID),   // AXI读数据有效信号
        .S_AXI_RREADY (S_AXI_RREADY),   // AXI读数据准备信号
        .PSEL         (PSEL),
        .PENABLE      (PENABLE),
        .PADDR        (PADDR),
        .PWRITE       (PWRITE),
        .PWDATA       (PWDATA),
        .PRDATA       (PRDATA),
        .PREADY       (PREADY),
        .PSLVERR      (PSLVERR),
        .PCLK         (PCLK),           // APB时钟
        .PRESETn      (PRESETn)         // APB复位
    );

    // 外设顶层模块例化
    perip_top #(
        .APB_DEV_COUNT       (`APB_DEV_COUNT),
        .APB_SLAVE_ADDR_WIDTH(`APB_SLAVE_ADDR_WIDTH),
        .BUS_DATA_WIDTH      (`BUS_DATA_WIDTH)
    ) u_perip_top (
        .HCLK             (PCLK),
        .HRESETn          (PRESETn),
        .PADDR            (PADDR),
        .PWDATA           (PWDATA),
        .PWRITE           (PWRITE),
        .PSEL             (PSEL),
        .PENABLE          (PENABLE),
        .PRDATA           (PRDATA),
        .PREADY           (PREADY),
        .PSLVERR          (PSLVERR),
        // UART0
        .uart0_rxd_i      (uart0_rxd_i),
        .uart0_txd_o      (uart0_txd_o),
        .uart0_event_o    (uart0_event),
        // 保留事件信号到外部端口
        .uart1_event_o    (uart1_event),
        .spi_events_o     (spi_events),
        .i2c0_interrupt_o (i2c0_interrupt),
        .i2c1_interrupt_o (i2c1_interrupt),
        // GPIO0
        .gpio0_in_i       (gpio0_in_i),
        .gpio0_out_o      (gpio0_out_o),
        .gpio0_dir_o      (gpio0_dir),
        .gpio0_interrupt_o(gpio0_interrupt),
        // GPIO1
        .gpio1_in_i       (gpio1_in_i),
        .gpio1_out_o      (gpio1_out_o),
        .gpio1_dir_o      (gpio1_dir),
        .gpio1_interrupt_o(gpio1_interrupt),
        // Timer
        .dft_cg_enable_i  (0),
        .low_speed_clk_i  (low_speed_clk_i),
        .timer_events_o   (timer_events)
    );

    // === GPIO方向信号处理 ===
    wire [31:0] gpio0_dir;
    wire [31:0] gpio1_dir;
`ifdef FPGA_SOURCE
    assign gpio0_dir_o = ~gpio0_dir;
    assign gpio1_dir_o = ~gpio1_dir;
`else
    assign gpio0_dir_o = gpio0_dir;
    assign gpio1_dir_o = gpio1_dir;
`endif

    // CLINT/PLIC AXI-Lite接口信号
    wire                           OM1_AXI_ACLK;
    wire                           OM1_AXI_ARESETN;
    wire [    `BUS_ADDR_WIDTH-1:0] OM1_AXI_AWADDR;
    wire [                    2:0] OM1_AXI_AWPROT;
    wire                           OM1_AXI_AWVALID;
    wire                           OM1_AXI_AWREADY;
    wire [    `BUS_DATA_WIDTH-1:0] OM1_AXI_WDATA;
    wire [(`BUS_DATA_WIDTH/8)-1:0] OM1_AXI_WSTRB;
    wire                           OM1_AXI_WVALID;
    wire                           OM1_AXI_WREADY;
    wire [                    1:0] OM1_AXI_BRESP;
    wire                           OM1_AXI_BVALID;
    wire                           OM1_AXI_BREADY;
    wire [    `BUS_ADDR_WIDTH-1:0] OM1_AXI_ARADDR;
    wire [                    2:0] OM1_AXI_ARPROT;
    wire                           OM1_AXI_ARVALID;
    wire                           OM1_AXI_ARREADY;
    wire [    `BUS_DATA_WIDTH-1:0] OM1_AXI_RDATA;
    wire [                    1:0] OM1_AXI_RRESP;
    wire                           OM1_AXI_RVALID;
    wire                           OM1_AXI_RREADY;

    wire                           OM2_AXI_ACLK;
    wire                           OM2_AXI_ARESETN;
    wire [   `PLIC_ADDR_WIDTH-1:0] OM2_AXI_AWADDR;
    wire [                    2:0] OM2_AXI_AWPROT;
    wire                           OM2_AXI_AWVALID;
    wire                           OM2_AXI_AWREADY;
    wire [    `BUS_DATA_WIDTH-1:0] OM2_AXI_WDATA;
    wire [(`BUS_DATA_WIDTH/8)-1:0] OM2_AXI_WSTRB;
    wire                           OM2_AXI_WVALID;
    wire                           OM2_AXI_WREADY;
    wire [                    1:0] OM2_AXI_BRESP;
    wire                           OM2_AXI_BVALID;
    wire                           OM2_AXI_BREADY;
    wire [   `PLIC_ADDR_WIDTH-1:0] OM2_AXI_ARADDR;
    wire [                    2:0] OM2_AXI_ARPROT;
    wire                           OM2_AXI_ARVALID;
    wire                           OM2_AXI_ARREADY;
    wire [    `BUS_DATA_WIDTH-1:0] OM2_AXI_RDATA;
    wire [                    1:0] OM2_AXI_RRESP;
    wire                           OM2_AXI_RVALID;
    wire                           OM2_AXI_RREADY;

    // AXI 互连模块例化
    axi_interconnect #(
        .IMEM_ADDR_WIDTH(`ITCM_ADDR_WIDTH),
        .DMEM_ADDR_WIDTH(`DTCM_ADDR_WIDTH)
    ) u_axi_interconnect (
        .clk  (clk),
        .rst_n(rst_n),

        // M0 AXI接口 (IFU)
        .M0_AXI_ARID   (M0_AXI_ARID),
        .M0_AXI_ARADDR (M0_AXI_ARADDR),
        .M0_AXI_ARLEN  (M0_AXI_ARLEN),
        .M0_AXI_ARSIZE (M0_AXI_ARSIZE),
        .M0_AXI_ARBURST(M0_AXI_ARBURST),
        .M0_AXI_ARLOCK (M0_AXI_ARLOCK),
        .M0_AXI_ARCACHE(M0_AXI_ARCACHE),
        .M0_AXI_ARPROT (M0_AXI_ARPROT),
        .M0_AXI_ARQOS  (M0_AXI_ARQOS),
        .M0_AXI_ARUSER (M0_AXI_ARUSER),
        .M0_AXI_ARVALID(M0_AXI_ARVALID),
        .M0_AXI_ARREADY(M0_AXI_ARREADY),
        .M0_AXI_RID    (M0_AXI_RID),
        .M0_AXI_RDATA  (M0_AXI_RDATA),
        .M0_AXI_RRESP  (M0_AXI_RRESP),
        .M0_AXI_RLAST  (M0_AXI_RLAST),
        .M0_AXI_RUSER  (M0_AXI_RUSER),
        .M0_AXI_RVALID (M0_AXI_RVALID),
        .M0_AXI_RREADY (M0_AXI_RREADY),

        // M1 AXI接口 (EXU)
        .M1_AXI_AWID   (M1_AXI_AWID),
        .M1_AXI_AWADDR (M1_AXI_AWADDR),
        .M1_AXI_AWLEN  (M1_AXI_AWLEN),
        .M1_AXI_AWSIZE (M1_AXI_AWSIZE),
        .M1_AXI_AWBURST(M1_AXI_AWBURST),
        .M1_AXI_AWLOCK (M1_AXI_AWLOCK),
        .M1_AXI_AWCACHE(M1_AXI_AWCACHE),
        .M1_AXI_AWPROT (M1_AXI_AWPROT),
        .M1_AXI_AWQOS  (M1_AXI_AWQOS),
        .M1_AXI_AWUSER (M1_AXI_AWUSER),
        .M1_AXI_AWVALID(M1_AXI_AWVALID),
        .M1_AXI_AWREADY(M1_AXI_AWREADY),
        .M1_AXI_WDATA  (M1_AXI_WDATA),
        .M1_AXI_WSTRB  (M1_AXI_WSTRB),
        .M1_AXI_WLAST  (M1_AXI_WLAST),
        .M1_AXI_WVALID (M1_AXI_WVALID),
        .M1_AXI_WREADY (M1_AXI_WREADY),
        .M1_AXI_BID    (M1_AXI_BID),
        .M1_AXI_BRESP  (M1_AXI_BRESP),
        .M1_AXI_BVALID (M1_AXI_BVALID),
        .M1_AXI_BREADY (M1_AXI_BREADY),
        .M1_AXI_ARID   (M1_AXI_ARID),
        .M1_AXI_ARADDR (M1_AXI_ARADDR),
        .M1_AXI_ARLEN  (M1_AXI_ARLEN),
        .M1_AXI_ARSIZE (M1_AXI_ARSIZE),
        .M1_AXI_ARBURST(M1_AXI_ARBURST),
        .M1_AXI_ARLOCK (M1_AXI_ARLOCK),
        .M1_AXI_ARCACHE(M1_AXI_ARCACHE),
        .M1_AXI_ARPROT (M1_AXI_ARPROT),
        .M1_AXI_ARQOS  (M1_AXI_ARQOS),
        .M1_AXI_ARUSER (M1_AXI_ARUSER),
        .M1_AXI_ARVALID(M1_AXI_ARVALID),
        .M1_AXI_ARREADY(M1_AXI_ARREADY),
        .M1_AXI_RID    (M1_AXI_RID),
        .M1_AXI_RDATA  (M1_AXI_RDATA),
        .M1_AXI_RRESP  (M1_AXI_RRESP),
        .M1_AXI_RLAST  (M1_AXI_RLAST),
        .M1_AXI_RUSER  (M1_AXI_RUSER),
        .M1_AXI_RVALID (M1_AXI_RVALID),
        .M1_AXI_RREADY (M1_AXI_RREADY),

        // IMEM AXI接口
        .IMEM_AXI_AWID   (IMEM_AXI_AWID),
        .IMEM_AXI_AWADDR (IMEM_AXI_AWADDR),
        .IMEM_AXI_AWLEN  (IMEM_AXI_AWLEN),
        .IMEM_AXI_AWSIZE (IMEM_AXI_AWSIZE),
        .IMEM_AXI_AWBURST(IMEM_AXI_AWBURST),
        .IMEM_AXI_AWLOCK (IMEM_AXI_AWLOCK),
        .IMEM_AXI_AWCACHE(IMEM_AXI_AWCACHE),
        .IMEM_AXI_AWPROT (IMEM_AXI_AWPROT),
        .IMEM_AXI_AWVALID(IMEM_AXI_AWVALID),
        .IMEM_AXI_AWREADY(IMEM_AXI_AWREADY),
        .IMEM_AXI_WDATA  (IMEM_AXI_WDATA),
        .IMEM_AXI_WSTRB  (IMEM_AXI_WSTRB),
        .IMEM_AXI_WLAST  (IMEM_AXI_WLAST),
        .IMEM_AXI_WVALID (IMEM_AXI_WVALID),
        .IMEM_AXI_WREADY (IMEM_AXI_WREADY),
        .IMEM_AXI_BID    (IMEM_AXI_BID),
        .IMEM_AXI_BRESP  (IMEM_AXI_BRESP),
        .IMEM_AXI_BVALID (IMEM_AXI_BVALID),
        .IMEM_AXI_BREADY (IMEM_AXI_BREADY),
        .IMEM_AXI_ARID   (IMEM_AXI_ARID),
        .IMEM_AXI_ARADDR (IMEM_AXI_ARADDR),
        .IMEM_AXI_ARLEN  (IMEM_AXI_ARLEN),
        .IMEM_AXI_ARSIZE (IMEM_AXI_ARSIZE),
        .IMEM_AXI_ARBURST(IMEM_AXI_ARBURST),
        .IMEM_AXI_ARLOCK (IMEM_AXI_ARLOCK),
        .IMEM_AXI_ARCACHE(IMEM_AXI_ARCACHE),
        .IMEM_AXI_ARPROT (IMEM_AXI_ARPROT),
        .IMEM_AXI_ARVALID(IMEM_AXI_ARVALID),
        .IMEM_AXI_ARREADY(IMEM_AXI_ARREADY),
        .IMEM_AXI_RID    (IMEM_AXI_RID),
        .IMEM_AXI_RDATA  (IMEM_AXI_RDATA),
        .IMEM_AXI_RRESP  (IMEM_AXI_RRESP),
        .IMEM_AXI_RLAST  (IMEM_AXI_RLAST),
        .IMEM_AXI_RVALID (IMEM_AXI_RVALID),
        .IMEM_AXI_RREADY (IMEM_AXI_RREADY),

        // DMEM AXI接口
        .DMEM_AXI_AWID   (DMEM_AXI_AWID),
        .DMEM_AXI_AWADDR (DMEM_AXI_AWADDR),
        .DMEM_AXI_AWLEN  (DMEM_AXI_AWLEN),
        .DMEM_AXI_AWSIZE (DMEM_AXI_AWSIZE),
        .DMEM_AXI_AWBURST(DMEM_AXI_AWBURST),
        .DMEM_AXI_AWLOCK (DMEM_AXI_AWLOCK),
        .DMEM_AXI_AWCACHE(DMEM_AXI_AWCACHE),
        .DMEM_AXI_AWPROT (DMEM_AXI_AWPROT),
        .DMEM_AXI_AWVALID(DMEM_AXI_AWVALID),
        .DMEM_AXI_AWREADY(DMEM_AXI_AWREADY),
        .DMEM_AXI_WDATA  (DMEM_AXI_WDATA),
        .DMEM_AXI_WSTRB  (DMEM_AXI_WSTRB),
        .DMEM_AXI_WLAST  (DMEM_AXI_WLAST),
        .DMEM_AXI_WVALID (DMEM_AXI_WVALID),
        .DMEM_AXI_WREADY (DMEM_AXI_WREADY),
        .DMEM_AXI_BID    (DMEM_AXI_BID),
        .DMEM_AXI_BRESP  (DMEM_AXI_BRESP),
        .DMEM_AXI_BVALID (DMEM_AXI_BVALID),
        .DMEM_AXI_BREADY (DMEM_AXI_BREADY),
        .DMEM_AXI_ARID   (DMEM_AXI_ARID),
        .DMEM_AXI_ARADDR (DMEM_AXI_ARADDR),
        .DMEM_AXI_ARLEN  (DMEM_AXI_ARLEN),
        .DMEM_AXI_ARSIZE (DMEM_AXI_ARSIZE),
        .DMEM_AXI_ARBURST(DMEM_AXI_ARBURST),
        .DMEM_AXI_ARLOCK (DMEM_AXI_ARLOCK),
        .DMEM_AXI_ARCACHE(DMEM_AXI_ARCACHE),
        .DMEM_AXI_ARPROT (DMEM_AXI_ARPROT),
        .DMEM_AXI_ARVALID(DMEM_AXI_ARVALID),
        .DMEM_AXI_ARREADY(DMEM_AXI_ARREADY),
        .DMEM_AXI_RID    (DMEM_AXI_RID),
        .DMEM_AXI_RDATA  (DMEM_AXI_RDATA),
        .DMEM_AXI_RRESP  (DMEM_AXI_RRESP),
        .DMEM_AXI_RLAST  (DMEM_AXI_RLAST),
        .DMEM_AXI_RVALID (DMEM_AXI_RVALID),
        .DMEM_AXI_RREADY (DMEM_AXI_RREADY),

        // APB AXI-Lite 接口
        .OM0_AXI_ACLK   (S_AXI_ACLK),
        .OM0_AXI_ARESETN(S_AXI_ARESETN),
        .OM0_AXI_AWADDR (S_AXI_AWADDR),
        .OM0_AXI_AWPROT (S_AXI_AWPROT),
        .OM0_AXI_AWVALID(S_AXI_AWVALID),
        .OM0_AXI_AWREADY(S_AXI_AWREADY),
        .OM0_AXI_WDATA  (S_AXI_WDATA),
        .OM0_AXI_WSTRB  (S_AXI_WSTRB),
        .OM0_AXI_WVALID (S_AXI_WVALID),
        .OM0_AXI_WREADY (S_AXI_WREADY),
        .OM0_AXI_BRESP  (S_AXI_BRESP),
        .OM0_AXI_BVALID (S_AXI_BVALID),
        .OM0_AXI_BREADY (S_AXI_BREADY),
        .OM0_AXI_ARADDR (S_AXI_ARADDR),
        .OM0_AXI_ARPROT (S_AXI_ARPROT),
        .OM0_AXI_ARVALID(S_AXI_ARVALID),
        .OM0_AXI_ARREADY(S_AXI_ARREADY),
        .OM0_AXI_RDATA  (S_AXI_RDATA),
        .OM0_AXI_RRESP  (S_AXI_RRESP),
        .OM0_AXI_RVALID (S_AXI_RVALID),
        .OM0_AXI_RREADY (S_AXI_RREADY),

        // CLINT AXI-Lite 接口
        .OM1_AXI_ACLK   (OM1_AXI_ACLK),
        .OM1_AXI_ARESETN(OM1_AXI_ARESETN),
        .OM1_AXI_AWADDR (OM1_AXI_AWADDR),
        .OM1_AXI_AWPROT (OM1_AXI_AWPROT),
        .OM1_AXI_AWVALID(OM1_AXI_AWVALID),
        .OM1_AXI_AWREADY(OM1_AXI_AWREADY),
        .OM1_AXI_WDATA  (OM1_AXI_WDATA),
        .OM1_AXI_WSTRB  (OM1_AXI_WSTRB),
        .OM1_AXI_WVALID (OM1_AXI_WVALID),
        .OM1_AXI_WREADY (OM1_AXI_WREADY),
        .OM1_AXI_BRESP  (OM1_AXI_BRESP),
        .OM1_AXI_BVALID (OM1_AXI_BVALID),
        .OM1_AXI_BREADY (OM1_AXI_BREADY),
        .OM1_AXI_ARADDR (OM1_AXI_ARADDR),
        .OM1_AXI_ARPROT (OM1_AXI_ARPROT),
        .OM1_AXI_ARVALID(OM1_AXI_ARVALID),
        .OM1_AXI_ARREADY(OM1_AXI_ARREADY),
        .OM1_AXI_RDATA  (OM1_AXI_RDATA),
        .OM1_AXI_RRESP  (OM1_AXI_RRESP),
        .OM1_AXI_RVALID (OM1_AXI_RVALID),
        .OM1_AXI_RREADY (OM1_AXI_RREADY),

        // PLIC AXI-Lite 接口
        .OM2_AXI_ACLK   (OM2_AXI_ACLK),
        .OM2_AXI_ARESETN(OM2_AXI_ARESETN),
        .OM2_AXI_AWADDR (OM2_AXI_AWADDR),
        .OM2_AXI_AWPROT (OM2_AXI_AWPROT),
        .OM2_AXI_AWVALID(OM2_AXI_AWVALID),
        .OM2_AXI_AWREADY(OM2_AXI_AWREADY),
        .OM2_AXI_WDATA  (OM2_AXI_WDATA),
        .OM2_AXI_WSTRB  (OM2_AXI_WSTRB),
        .OM2_AXI_WVALID (OM2_AXI_WVALID),
        .OM2_AXI_WREADY (OM2_AXI_WREADY),
        .OM2_AXI_BRESP  (OM2_AXI_BRESP),
        .OM2_AXI_BVALID (OM2_AXI_BVALID),
        .OM2_AXI_BREADY (OM2_AXI_BREADY),
        .OM2_AXI_ARADDR (OM2_AXI_ARADDR),
        .OM2_AXI_ARPROT (OM2_AXI_ARPROT),
        .OM2_AXI_ARVALID(OM2_AXI_ARVALID),
        .OM2_AXI_ARREADY(OM2_AXI_ARREADY),
        .OM2_AXI_RDATA  (OM2_AXI_RDATA),
        .OM2_AXI_RRESP  (OM2_AXI_RRESP),
        .OM2_AXI_RVALID (OM2_AXI_RVALID),
        .OM2_AXI_RREADY (OM2_AXI_RREADY)
    );

    // IMEM (指令存储器) 实例化
    gnrl_ram_pseudo_dual_axi #(
        .ADDR_WIDTH        (`ITCM_ADDR_WIDTH),
        .DATA_WIDTH        (`BUS_DATA_WIDTH),
        .INIT_MEM          (`INIT_ITCM),
        .INIT_FILE         (`ITCM_INIT_FILE),
        .C_S_AXI_ID_WIDTH  (`BUS_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(`ITCM_ADDR_WIDTH)
    ) u_imem (
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(rst_n),
        .S_AXI_AWID   (IMEM_AXI_AWID),
        .S_AXI_AWADDR (IMEM_AXI_AWADDR[`ITCM_ADDR_WIDTH-1:0]),
        .S_AXI_AWLEN  (IMEM_AXI_AWLEN),
        .S_AXI_AWSIZE (IMEM_AXI_AWSIZE),
        .S_AXI_AWBURST(IMEM_AXI_AWBURST),
        .S_AXI_AWLOCK (IMEM_AXI_AWLOCK),
        .S_AXI_AWCACHE(IMEM_AXI_AWCACHE),
        .S_AXI_AWPROT (IMEM_AXI_AWPROT),
        .S_AXI_AWVALID(IMEM_AXI_AWVALID),
        .S_AXI_AWREADY(IMEM_AXI_AWREADY),
        .S_AXI_WDATA  (IMEM_AXI_WDATA),
        .S_AXI_WSTRB  (IMEM_AXI_WSTRB),
        .S_AXI_WLAST  (IMEM_AXI_WLAST),
        .S_AXI_WVALID (IMEM_AXI_WVALID),
        .S_AXI_WREADY (IMEM_AXI_WREADY),
        .S_AXI_BID    (IMEM_AXI_BID),
        .S_AXI_BRESP  (IMEM_AXI_BRESP),
        .S_AXI_BVALID (IMEM_AXI_BVALID),
        .S_AXI_BREADY (IMEM_AXI_BREADY),
        .S_AXI_ARID   (IMEM_AXI_ARID),
        .S_AXI_ARADDR (IMEM_AXI_ARADDR[`ITCM_ADDR_WIDTH-1:0]),
        .S_AXI_ARLEN  (IMEM_AXI_ARLEN),
        .S_AXI_ARSIZE (IMEM_AXI_ARSIZE),
        .S_AXI_ARBURST(IMEM_AXI_ARBURST),
        .S_AXI_ARLOCK (IMEM_AXI_ARLOCK),
        .S_AXI_ARCACHE(IMEM_AXI_ARCACHE),
        .S_AXI_ARPROT (IMEM_AXI_ARPROT),
        .S_AXI_ARVALID(IMEM_AXI_ARVALID),
        .S_AXI_ARREADY(IMEM_AXI_ARREADY),
        .S_AXI_RID    (IMEM_AXI_RID),
        .S_AXI_RDATA  (IMEM_AXI_RDATA),
        .S_AXI_RRESP  (IMEM_AXI_RRESP),
        .S_AXI_RLAST  (IMEM_AXI_RLAST),
        .S_AXI_RVALID (IMEM_AXI_RVALID),
        .S_AXI_RREADY (IMEM_AXI_RREADY)
    );

    // DMEM (数据存储器) 实例化
    gnrl_ram_pseudo_dual_axi #(
        .ADDR_WIDTH        (`DTCM_ADDR_WIDTH),
        .DATA_WIDTH        (`BUS_DATA_WIDTH),
        .INIT_MEM          (`INIT_DTCM),
        .INIT_FILE         (`DTCM_INIT_FILE),
        .C_S_AXI_ID_WIDTH  (`BUS_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(`DTCM_ADDR_WIDTH)
    ) u_dmem (
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(rst_n),
        .S_AXI_AWID   (DMEM_AXI_AWID),
        .S_AXI_AWADDR (DMEM_AXI_AWADDR[`DTCM_ADDR_WIDTH-1:0]),
        .S_AXI_AWLEN  (DMEM_AXI_AWLEN),
        .S_AXI_AWSIZE (DMEM_AXI_AWSIZE),
        .S_AXI_AWBURST(DMEM_AXI_AWBURST),
        .S_AXI_AWLOCK (DMEM_AXI_AWLOCK),
        .S_AXI_AWCACHE(DMEM_AXI_AWCACHE),
        .S_AXI_AWPROT (DMEM_AXI_AWPROT),
        .S_AXI_AWVALID(DMEM_AXI_AWVALID),
        .S_AXI_AWREADY(DMEM_AXI_AWREADY),
        .S_AXI_WDATA  (DMEM_AXI_WDATA),
        .S_AXI_WSTRB  (DMEM_AXI_WSTRB),
        .S_AXI_WLAST  (DMEM_AXI_WLAST),
        .S_AXI_WVALID (DMEM_AXI_WVALID),
        .S_AXI_WREADY (DMEM_AXI_WREADY),
        .S_AXI_BID    (DMEM_AXI_BID),
        .S_AXI_BRESP  (DMEM_AXI_BRESP),
        .S_AXI_BVALID (DMEM_AXI_BVALID),
        .S_AXI_BREADY (DMEM_AXI_BREADY),
        .S_AXI_ARID   (DMEM_AXI_ARID),
        .S_AXI_ARADDR (DMEM_AXI_ARADDR[`DTCM_ADDR_WIDTH-1:0]),
        .S_AXI_ARLEN  (DMEM_AXI_ARLEN),
        .S_AXI_ARSIZE (DMEM_AXI_ARSIZE),
        .S_AXI_ARBURST(DMEM_AXI_ARBURST),
        .S_AXI_ARLOCK (DMEM_AXI_ARLOCK),
        .S_AXI_ARCACHE(DMEM_AXI_ARCACHE),
        .S_AXI_ARPROT (DMEM_AXI_ARPROT),
        .S_AXI_ARVALID(DMEM_AXI_ARVALID),
        .S_AXI_ARREADY(DMEM_AXI_ARREADY),
        .S_AXI_RID    (DMEM_AXI_RID),
        .S_AXI_RDATA  (DMEM_AXI_RDATA),
        .S_AXI_RRESP  (DMEM_AXI_RRESP),
        .S_AXI_RLAST  (DMEM_AXI_RLAST),
        .S_AXI_RVALID (DMEM_AXI_RVALID),
        .S_AXI_RREADY (DMEM_AXI_RREADY)
    );

endmodule
