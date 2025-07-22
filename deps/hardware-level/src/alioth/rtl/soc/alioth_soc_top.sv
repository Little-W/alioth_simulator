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

    // UART
    input  wire rx_i,
    output wire tx_o,

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

    // I2C
    input  wire scl_pad_i,
    output wire scl_pad_o,
    output wire scl_padoen_o,
    input  wire sda_pad_i,
    output wire sda_pad_o,
    output wire sda_padoen_o,

    // GPIO
    input  wire [ 31:0] gpio_in,
    output wire [ 31:0] gpio_in_sync,
    output wire [ 31:0] gpio_out,
    output wire [ 31:0] gpio_dir,
    output wire [191:0] gpio_padcfg,
    output wire [ 31:0] gpio_iof,

    // Timer
    input  wire        dft_cg_enable_i,
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

    // === 新增：中断信号内部连线 ===
    wire                           uart_event;
    wire                           spi_event;
    wire                           i2c_interrupt;
    wire                           gpio_int;
    wire [                    3:0] timer_events;

    wire                           PCLK;
    wire                           PRESETn;

    // 汇总中断向量（假设顺序：uart, spi, i2c, gpio, timer[3:0]，共8位，可根据实际外设数量调整）
    wire [                    7:0] irq_vec;
    assign irq_vec = {timer_events, gpio_int, i2c_interrupt, spi_event, uart_event};

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
    perip_top u_perip_top (
        .HCLK           (PCLK),             // 使用顶层时钟信号
        .HRESETn        (PRESETn),          // 使用顶层复位信号
        .PADDR          (PADDR),
        .PWDATA         (PWDATA),
        .PWRITE         (PWRITE),
        .PSEL           (PSEL),
        .PENABLE        (PENABLE),
        .PRDATA         (PRDATA),
        .PREADY         (PREADY),
        .PSLVERR        (PSLVERR),
        .rx_i           (rx_i),             // UART接收信号
        .tx_o           (tx_o),             // UART发送信号
        .uart_event_o   (uart_event),       // 改为内部信号
        .spi_clk        (spi_clk),          // SPI时钟信号
        .spi_csn0       (spi_csn0),         // SPI片选信号0
        .spi_csn1       (spi_csn1),         // SPI片选信号1
        .spi_csn2       (spi_csn2),         // SPI片选信号2
        .spi_csn3       (spi_csn3),         // SPI片选信号3
        .spi_sdo0       (spi_sdo0),         // SPI数据输出信号0
        .spi_sdo1       (spi_sdo1),         // SPI数据输出信号1
        .spi_sdo2       (spi_sdo2),         // SPI数据输出信号2
        .spi_sdo3       (spi_sdo3),         // SPI数据输出信号3
        .spi_oe0        (spi_oe0),          // SPI输出使能信号0
        .spi_oe1        (spi_oe1),          // SPI输出使能信号1
        .spi_oe2        (spi_oe2),          // SPI输出使能信号2
        .spi_oe3        (spi_oe3),          // SPI输出使能信号3
        .spi_sdi0       (spi_sdi0),         // SPI数据输入信号0
        .spi_sdi1       (spi_sdi1),         // SPI数据输入信号1
        .spi_sdi2       (spi_sdi2),         // SPI数据输入信号2
        .spi_sdi3       (spi_sdi3),         // SPI数据输入信号3
        .spi_events_o   (spi_event),        // 改为内部信号
        .scl_pad_i      (scl_pad_i),        // I2C时钟输入信号
        .scl_pad_o      (scl_pad_o),        // I2C时钟输出信号
        .scl_padoen_o   (scl_padoen_o),     // I2C时钟输出使能信号
        .sda_pad_i      (sda_pad_i),        // I2C数据输入信号
        .sda_pad_o      (sda_pad_o),        // I2C数据输出信号
        .sda_padoen_o   (sda_padoen_o),     // I2C数据输出使能信号
        .i2c_interrupt_o(i2c_interrupt),    // 改为内部信号
        .gpio_in        (gpio_in),          // GPIO输入信号
        .gpio_in_sync   (gpio_in_sync),     // GPIO输入同步信号
        .gpio_out       (gpio_out),         // GPIO输出信号
        .gpio_dir       (gpio_dir),         // GPIO方向信号
        .gpio_padcfg    (gpio_padcfg),      // GPIO配置信号
        .gpio_iof       (gpio_iof),         // GPIO功能选择信号
        .gpio_interrupt (gpio_int),         // 改为内部信号
        .dft_cg_enable_i(dft_cg_enable_i),  // 时钟门控使能信号
        .low_speed_clk_i(low_speed_clk_i),  // 低速时钟信号
        .ext_sig_i      (ext_sig_i),        // 外部信号输入
        .timer_events_o (timer_events),     // 改为内部信号
        .ch_0_o         (ch_0_o),           // 定时器通道0输出
        .ch_1_o         (ch_1_o),           // 定时器通道1输出
        .ch_2_o         (ch_2_o),           // 定时器通道2输出
        .ch_3_o         (ch_3_o)            // 定时器通道3输出
    );
endmodule
