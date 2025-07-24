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

`include "../core/defines.svh"

// alioth soc顶层模块
module alioth_soc_top (
    input wire clk,
    input wire rst_n,

    // UART0
    input  wire rx_i,
    output wire tx_o,
    // UART1
    input  wire rx1_i,
    output wire tx1_o,

    // SPI
    output wire spi_clk,
    output wire spi_csn0,
    output wire spi_csn1,
    output wire spi_csn2,
    output wire spi_csn3,
    output wire spi_sdo0,
    output wire spi_sdo1,
    output wire spi_sdo2,
    output wire spi_sdo3,
    output wire spi_oe0,
    output wire spi_oe1,
    output wire spi_oe2,
    output wire spi_oe3,
    input  wire spi_sdi0,
    input  wire spi_sdi1,
    input  wire spi_sdi2,
    input  wire spi_sdi3,

    // I2C0
    input  wire scl0_pad_i,
    output wire scl0_pad_o,
    output wire scl0_padoen_o,
    input  wire sda0_pad_i,
    output wire sda0_pad_o,
    output wire sda0_padoen_o,
    // I2C1
    input  wire scl1_pad_i,
    output wire scl1_pad_o,
    output wire scl1_padoen_o,
    input  wire sda1_pad_i,
    output wire sda1_pad_o,
    output wire sda1_padoen_o,

    // GPIO0
    input  wire [ 31:0] gpio0_in,
    output wire [ 31:0] gpio0_in_sync,
    output wire [ 31:0] gpio0_out,
    output wire [ 31:0] gpio0_dir,
    output wire [191:0] gpio0_padcfg,
    output wire [ 31:0] gpio0_iof,
    // GPIO1
    input  wire [ 31:0] gpio1_in,
    output wire [ 31:0] gpio1_in_sync,
    output wire [ 31:0] gpio1_out,
    output wire [ 31:0] gpio1_dir,
    output wire [191:0] gpio1_padcfg,
    output wire [ 31:0] gpio1_iof,

    // Timer
    input  wire        low_speed_clk_i,
    input  wire [31:0] ext_sig_i,
    output wire [ 3:0] ch_0_o,
    output wire [ 3:0] ch_1_o,
    output wire [ 3:0] ch_2_o,
    output wire [ 3:0] ch_3_o
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
    wire PCLK;
    wire PRESETn;

    // === 新增：中断信号内部连线 ===
    wire uart0_event, uart1_event;
    wire spi_event;
    wire i2c0_interrupt, i2c1_interrupt;
    wire gpio0_int, gpio1_int;
    wire [ 3:0] timer_events;

    // 拓展宽度为12位，优先级顺序：Timer[3:0], SPI, I2C0, I2C1, UART0, UART1, GPIO0, GPIO1
    wire [11:0] irq_vec;
    assign irq_vec = {
        gpio1_int,  // [11]
        gpio0_int,  // [10]
        uart1_event,  // [9]
        uart0_event,  // [8]
        i2c1_interrupt,  // [7]
        i2c0_interrupt,  // [6]
        spi_event,  // [5]
        timer_events  // [4:1]
    };

    // === 中断控制器输出信号 ===
    wire       irq_req;
    wire [7:0] irq_id;

    // === 中断控制器例化 ===
    irq_ctrl u_irq_ctrl (
        .clk    (clk),
        .rst_n  (rst_n),
        .irq_vec(irq_vec),
        .irq_req(irq_req),
        .irq_id (irq_id)
    );

    // alioth处理器核模块例化
    cpu_top u_cpu_top (
        .clk            (clk),
        .rst_n          (rst_n),
        .irq_req        (irq_req),        // 中断请求信号
        .irq_id         (irq_id),         // 新增：中断向量输入
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
        .HCLK            (PCLK),
        .HRESETn         (PRESETn),
        .PADDR           (PADDR),
        .PWDATA          (PWDATA),
        .PWRITE          (PWRITE),
        .PSEL            (PSEL),
        .PENABLE         (PENABLE),
        .PRDATA          (PRDATA),
        .PREADY          (PREADY),
        .PSLVERR         (PSLVERR),
        // UART0
        .rx0_i           (rx_i),
        .tx0_o           (tx_o),
        .uart0_event_o   (uart0_event),
        // UART1
        .rx1_i           (rx1_i),
        .tx1_o           (tx1_o),
        .uart1_event_o   (uart1_event),
        // SPI
        .spi_clk         (spi_clk),
        .spi_csn0        (spi_csn0),
        .spi_csn1        (spi_csn1),
        .spi_csn2        (spi_csn2),
        .spi_csn3        (spi_csn3),
        .spi_sdo0        (spi_sdo0),
        .spi_sdo1        (spi_sdo1),
        .spi_sdo2        (spi_sdo2),
        .spi_sdo3        (spi_sdo3),
        .spi_oe0         (spi_oe0),
        .spi_oe1         (spi_oe1),
        .spi_oe2         (spi_oe2),
        .spi_oe3         (spi_oe3),
        .spi_sdi0        (spi_sdi0),
        .spi_sdi1        (spi_sdi1),
        .spi_sdi2        (spi_sdi2),
        .spi_sdi3        (spi_sdi3),
        .spi_events_o    (spi_event),
        // I2C0
        .scl0_pad_i      (scl0_pad_i),
        .scl0_pad_o      (scl0_pad_o),
        .scl0_padoen_o   (scl0_padoen_o),
        .sda0_pad_i      (sda0_pad_i),
        .sda0_pad_o      (sda0_pad_o),
        .sda0_padoen_o   (sda0_padoen_o),
        .i2c0_interrupt_o(i2c0_interrupt),
        // I2C1
        .scl1_pad_i      (scl1_pad_i),
        .scl1_pad_o      (scl1_pad_o),
        .scl1_padoen_o   (scl1_padoen_o),
        .sda1_pad_i      (sda1_pad_i),
        .sda1_pad_o      (sda1_pad_o),
        .sda1_padoen_o   (sda1_padoen_o),
        .i2c1_interrupt_o(i2c1_interrupt),
        // GPIO0
        .gpio0_in        (gpio0_in),
        .gpio0_in_sync   (gpio0_in_sync),
        .gpio0_out       (gpio0_out),
        .gpio0_dir       (gpio0_dir),
        .gpio0_padcfg    (gpio0_padcfg),
        .gpio0_iof       (gpio0_iof),
        .gpio0_interrupt (gpio0_int),
        // GPIO1
        .gpio1_in        (gpio1_in),
        .gpio1_in_sync   (gpio1_in_sync),
        .gpio1_out       (gpio1_out),
        .gpio1_dir       (gpio1_dir),
        .gpio1_padcfg    (gpio1_padcfg),
        .gpio1_iof       (gpio1_iof),
        .gpio1_interrupt (gpio1_int),
        // Timer
        .dft_cg_enable_i (0),  // 忽略DFT时钟使能信号
        .low_speed_clk_i (low_speed_clk_i),
        .ext_sig_i       (ext_sig_i),
        .timer_events_o  (timer_events),
        .ch_0_o          (ch_0_o),
        .ch_1_o          (ch_1_o),
        .ch_2_o          (ch_2_o),
        .ch_3_o          (ch_3_o)
    );
endmodule
