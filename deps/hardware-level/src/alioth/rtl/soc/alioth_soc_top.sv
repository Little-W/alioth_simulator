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
    input  wire       low_speed_clk_i
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
    wire        uart0_event, uart1_event;
    wire        spi_events;
    wire        i2c0_interrupt, i2c1_interrupt;
    wire        gpio0_interrupt, gpio1_interrupt;
    wire [3:0]  timer_events;

    // 中断向量，优先级顺序：GPIO1, GPIO0, UART1, UART0, I2C1, I2C0, SPI, Timer[3:0]
    wire [10:0] irq_vec;
    assign irq_vec = {
        gpio1_interrupt,   // [10]
        gpio0_interrupt,   // [9]
        uart1_event,       // [8]
        uart0_event,       // [7]
        i2c1_interrupt,    // [6]
        i2c0_interrupt,    // [5]
        spi_events,        // [4]
        timer_events       // [3:0]
    };

    // alioth处理器核模块例化
    cpu_top u_cpu_top (
        .clk            (clk),
        .rst_n          (rst_n),
        .irq_sources    (irq_vec),        // 中断向量输入
        .OM0_AXI_ACLK   (S_AXI_ACLK),     // AXI-Lite时钟信号
        .OM0_AXI_ARESETN(S_AXI_ARESETN),  // AXI-Lite复位信号
        .OM0_AXI_AWADDR (S_AXI_AWADDR),   // AXI写地址信号
        .OM0_AXI_AWPROT (S_AXI_AWPROT),   // AXI写保护信号
        .OM0_AXI_AWVALID(S_AXI_AWVALID),  // AXI写地址有效信号
        .OM0_AXI_AWREADY(S_AXI_AWREADY),  // AXI写地址准备信号
        .OM0_AXI_WDATA  (S_AXI_WDATA),    // AXI写数据信号
        .OM0_AXI_WSTRB  (S_AXI_WSTRB),    // AXI写数据字节选择信号
        .OM0_AXI_WVALID (S_AXI_WVALID),   // AXI写数据有效信号
        .OM0_AXI_WREADY (S_AXI_WREADY),   // AXI写数据准备信号
        .OM0_AXI_BRESP  (S_AXI_BRESP),    // AXI写响应信号
        .OM0_AXI_BVALID (S_AXI_BVALID),   // AXI写响应有效信号
        .OM0_AXI_BREADY (S_AXI_BREADY),   // AXI写响应准备信号
        .OM0_AXI_ARADDR (S_AXI_ARADDR),   // AXI读地址信号
        .OM0_AXI_ARPROT (S_AXI_ARPROT),   // AXI读保护信号
        .OM0_AXI_ARVALID(S_AXI_ARVALID),  // AXI读地址有效信号
        .OM0_AXI_ARREADY(S_AXI_ARREADY),  // AXI读地址准备信号
        .OM0_AXI_RDATA  (S_AXI_RDATA),    // AXI读数据信号
        .OM0_AXI_RRESP  (S_AXI_RRESP),    // AXI读响应信号
        .OM0_AXI_RVALID (S_AXI_RVALID),   // AXI读数据有效信号
        .OM0_AXI_RREADY (S_AXI_RREADY)    // AXI读数据准备信号
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
endmodule
