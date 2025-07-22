`include "defines.svh"

module perip_top (
    input wire HCLK,
    input wire HRESETn,
    input wire [`APB_SLAVE_ADDR_WIDTH - 1:0] PADDR,
    input wire [31:0] PWDATA,
    input wire PWRITE,
    input wire [`APB_DEV_COUNT-1:0] PSEL,  // 修改为多设备选择信号
    input wire PENABLE,
    output wire [`BUS_DATA_WIDTH-1:0] PRDATA[`APB_DEV_COUNT],  // 修改为多设备数据输出
    output wire [`APB_DEV_COUNT-1:0] PREADY,  // 修改为多设备准备信号
    output wire [`APB_DEV_COUNT-1:0] PSLVERR,  // 修改为多设备错误信号

    // UART
    input  wire rx_i,
    output wire tx_o,
    output wire uart_event_o,

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
    output wire spi_events_o,

    // I2C
    input  wire scl_pad_i,
    output wire scl_pad_o,
    output wire scl_padoen_o,
    input  wire sda_pad_i,
    output wire sda_pad_o,
    output wire sda_padoen_o,
    output wire i2c_interrupt_o,

    // GPIO
    input  wire [ 31:0] gpio_in,
    output wire [ 31:0] gpio_in_sync,
    output wire [ 31:0] gpio_out,
    output wire [ 31:0] gpio_dir,
    output wire [191:0] gpio_padcfg,
    output wire [ 31:0] gpio_iof,
    output wire         gpio_interrupt,

    // Timer
    input  wire        dft_cg_enable_i,
    input  wire        low_speed_clk_i,
    input  wire [31:0] ext_sig_i,
    output wire [ 3:0] timer_events_o,
    output wire [ 3:0] ch_0_o,
    output wire [ 3:0] ch_1_o,
    output wire [ 3:0] ch_2_o,
    output wire [ 3:0] ch_3_o
);

    // UART instance
    apb_uart_sv #(
        .APB_ADDR_WIDTH(`APB_SLAVE_ADDR_WIDTH)
    ) uart_inst (
        .CLK    (HCLK),
        .RSTN   (HRESETn),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PWRITE (PWRITE),
        .PSEL   (PSEL[0]),      // 独立的 PSEL 信号
        .PENABLE(PENABLE),
        .PRDATA (PRDATA[0]),    // 独立的 PRDATA 信号
        .PREADY (PREADY[0]),    // 独立的 PREADY 信号
        .PSLVERR(PSLVERR[0]),   // 独立的 PSLVERR 信号
        .rx_i   (rx_i),
        .tx_o   (tx_o),
        .event_o(uart_event_o)
    );

    // SPI instance
    apb_spi_master #(
        .APB_ADDR_WIDTH(`APB_SLAVE_ADDR_WIDTH)
    ) spi_inst (
        .HCLK    (HCLK),
        .HRESETn (HRESETn),
        .PADDR   (PADDR),
        .PWDATA  (PWDATA),
        .PWRITE  (PWRITE),
        .PSEL    (PSEL[1]),       // 独立的 PSEL 信号
        .PENABLE (PENABLE),
        .PRDATA  (PRDATA[1]),     // 独立的 PRDATA 信号
        .PREADY  (PREADY[1]),     // 独立的 PREADY 信号
        .PSLVERR (PSLVERR[1]),    // 独立的 PSLVERR 信号
        .events_o(spi_events_o),
        .spi_clk (spi_clk),
        .spi_csn0(spi_csn0),
        .spi_csn1(spi_csn1),
        .spi_csn2(spi_csn2),
        .spi_csn3(spi_csn3),
        .spi_sdo0(spi_sdo0),
        .spi_sdo1(spi_sdo1),
        .spi_sdo2(spi_sdo2),
        .spi_sdo3(spi_sdo3),
        .spi_oe0 (spi_oe0),
        .spi_oe1 (spi_oe1),
        .spi_oe2 (spi_oe2),
        .spi_oe3 (spi_oe3),
        .spi_sdi0(spi_sdi0),
        .spi_sdi1(spi_sdi1),
        .spi_sdi2(spi_sdi2),
        .spi_sdi3(spi_sdi3)
    );

    // I2C instance
    apb_i2c #(
        .APB_ADDR_WIDTH(`APB_SLAVE_ADDR_WIDTH)
    ) i2c_inst (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .PADDR       (PADDR),
        .PWDATA      (PWDATA),
        .PWRITE      (PWRITE),
        .PSEL        (PSEL[2]),          // 独立的 PSEL 信号
        .PENABLE     (PENABLE),
        .PRDATA      (PRDATA[2]),        // 独立的 PRDATA 信号
        .PREADY      (PREADY[2]),        // 独立的 PREADY 信号
        .PSLVERR     (PSLVERR[2]),       // 独立的 PSLVERR 信号
        .interrupt_o (i2c_interrupt_o),
        .scl_pad_i   (scl_pad_i),
        .scl_pad_o   (scl_pad_o),
        .scl_padoen_o(scl_padoen_o),
        .sda_pad_i   (sda_pad_i),
        .sda_pad_o   (sda_pad_o),
        .sda_padoen_o(sda_padoen_o)
    );

    // GPIO instance
    apb_gpio #(
        .APB_ADDR_WIDTH(`APB_SLAVE_ADDR_WIDTH)
    ) gpio_inst (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .PADDR       (PADDR),
        .PWDATA      (PWDATA),
        .PWRITE      (PWRITE),
        .PSEL        (PSEL[3]),        // 独立的 PSEL 信号
        .PENABLE     (PENABLE),
        .PRDATA      (PRDATA[3]),      // 独立的 PRDATA 信号
        .PREADY      (PREADY[3]),      // 独立的 PREADY 信号
        .PSLVERR     (PSLVERR[3]),     // 独立的 PSLVERR 信号
        .gpio_in     (gpio_in),
        .gpio_in_sync(gpio_in_sync),
        .gpio_out    (gpio_out),
        .gpio_dir    (gpio_dir),
        .gpio_padcfg (gpio_padcfg),
        .gpio_iof    (gpio_iof),
        .interrupt   (gpio_interrupt)
    );

    // Timer instance
    apb_adv_timer #(
        .APB_ADDR_WIDTH(`APB_SLAVE_ADDR_WIDTH)
    ) timer_inst (
        .HCLK           (HCLK),
        .HRESETn        (HRESETn),
        .PADDR          (PADDR),
        .PWDATA         (PWDATA),
        .PWRITE         (PWRITE),
        .PSEL           (PSEL[4]),          // 独立的 PSEL 信号
        .PENABLE        (PENABLE),
        .PRDATA         (PRDATA[4]),        // 独立的 PRDATA 信号
        .PREADY         (PREADY[4]),        // 独立的 PREADY 信号
        .PSLVERR        (PSLVERR[4]),       // 独立的 PSLVERR 信号
        .dft_cg_enable_i(dft_cg_enable_i),
        .low_speed_clk_i(low_speed_clk_i),
        .ext_sig_i      (ext_sig_i),
        .events_o       (timer_events_o),
        .ch_0_o         (ch_0_o),
        .ch_1_o         (ch_1_o),
        .ch_2_o         (ch_2_o),
        .ch_3_o         (ch_3_o)
    );

endmodule
