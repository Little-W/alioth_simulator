`include "defines.svh"

module perip_top #(
    parameter APB_DEV_COUNT      = 8,
    parameter APB_SLAVE_ADDR_WIDTH = 12,
    parameter BUS_DATA_WIDTH     = 32
) (
    input  wire                               HCLK,
    input  wire                               HRESETn,
    input  wire [APB_SLAVE_ADDR_WIDTH-1:0]    PADDR,
    input  wire [31:0]                        PWDATA,
    input  wire                               PWRITE,
    input  wire [APB_DEV_COUNT-1:0]           PSEL,
    input  wire                               PENABLE,
    output wire [BUS_DATA_WIDTH-1:0]          PRDATA [APB_DEV_COUNT],
    output wire [APB_DEV_COUNT-1:0]           PREADY,
    output wire [APB_DEV_COUNT-1:0]           PSLVERR,

    // UART0
    input  wire rx0_i,
    output wire tx0_o,
    output wire uart0_event_o,
    // UART1
    input  wire rx1_i,
    output wire tx1_o,
    output wire uart1_event_o,

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

    // I2C0
    input  wire scl0_pad_i,
    output wire scl0_pad_o,
    output wire scl0_padoen_o,
    input  wire sda0_pad_i,
    output wire sda0_pad_o,
    output wire sda0_padoen_o,
    output wire i2c0_interrupt_o,
    // I2C1
    input  wire scl1_pad_i,
    output wire scl1_pad_o,
    output wire scl1_padoen_o,
    input  wire sda1_pad_i,
    output wire sda1_pad_o,
    output wire sda1_padoen_o,
    output wire i2c1_interrupt_o,

    // GPIO0
    input  wire [ 31:0] gpio0_in,
    output wire [ 31:0] gpio0_in_sync,
    output wire [ 31:0] gpio0_out,
    output wire [ 31:0] gpio0_dir,
    output wire [191:0] gpio0_padcfg,
    output wire [ 31:0] gpio0_iof,
    output wire         gpio0_interrupt,
    // GPIO1
    input  wire [ 31:0] gpio1_in,
    output wire [ 31:0] gpio1_in_sync,
    output wire [ 31:0] gpio1_out,
    output wire [ 31:0] gpio1_dir,
    output wire [191:0] gpio1_padcfg,
    output wire [ 31:0] gpio1_iof,
    output wire         gpio1_interrupt,

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

    // Timer instance (PSEL[0])
    apb_adv_timer #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) timer_inst (
        .HCLK           (HCLK),
        .HRESETn        (HRESETn),
        .PADDR          (PADDR),
        .PWDATA         (PWDATA),
        .PWRITE         (PWRITE),
        .PSEL           (PSEL[0]),
        .PENABLE        (PENABLE),
        .PRDATA         (PRDATA[0]),
        .PREADY         (PREADY[0]),
        .PSLVERR        (PSLVERR[0]),
        .dft_cg_enable_i(dft_cg_enable_i),
        .low_speed_clk_i(low_speed_clk_i),
        .ext_sig_i      (ext_sig_i),
        .events_o       (timer_events_o),
        .ch_0_o         (ch_0_o),
        .ch_1_o         (ch_1_o),
        .ch_2_o         (ch_2_o),
        .ch_3_o         (ch_3_o)
    );

    // SPI instance (PSEL[1])
    apb_spi_master #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) spi_inst (
        .HCLK    (HCLK),
        .HRESETn (HRESETn),
        .PADDR   (PADDR),
        .PWDATA  (PWDATA),
        .PWRITE  (PWRITE),
        .PSEL    (PSEL[1]),
        .PENABLE (PENABLE),
        .PRDATA  (PRDATA[1]),
        .PREADY  (PREADY[1]),
        .PSLVERR (PSLVERR[1]),
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

    // I2C0 instance (PSEL[2])
    apb_i2c #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) i2c0_inst (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .PADDR       (PADDR),
        .PWDATA      (PWDATA),
        .PWRITE      (PWRITE),
        .PSEL        (PSEL[2]),
        .PENABLE     (PENABLE),
        .PRDATA      (PRDATA[2]),
        .PREADY      (PREADY[2]),
        .PSLVERR     (PSLVERR[2]),
        .interrupt_o (i2c0_interrupt_o),
        .scl_pad_i   (scl0_pad_i),
        .scl_pad_o   (scl0_pad_o),
        .scl_padoen_o(scl0_padoen_o),
        .sda_pad_i   (sda0_pad_i),
        .sda_pad_o   (sda0_pad_o),
        .sda_padoen_o(sda0_padoen_o)
    );

    // I2C1 instance (PSEL[3])
    apb_i2c #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) i2c1_inst (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .PADDR       (PADDR),
        .PWDATA      (PWDATA),
        .PWRITE      (PWRITE),
        .PSEL        (PSEL[3]),
        .PENABLE     (PENABLE),
        .PRDATA      (PRDATA[3]),
        .PREADY      (PREADY[3]),
        .PSLVERR     (PSLVERR[3]),
        .interrupt_o (i2c1_interrupt_o),
        .scl_pad_i   (scl1_pad_i),
        .scl_pad_o   (scl1_pad_o),
        .scl_padoen_o(scl1_padoen_o),
        .sda_pad_i   (sda1_pad_i),
        .sda_pad_o   (sda1_pad_o),
        .sda_padoen_o(sda1_padoen_o)
    );

    // UART0 instance (PSEL[4])
    apb_uart_sv #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) uart0_inst (
        .CLK    (HCLK),
        .RSTN   (HRESETn),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PWRITE (PWRITE),
        .PSEL   (PSEL[4]),
        .PENABLE(PENABLE),
        .PRDATA (PRDATA[4]),
        .PREADY (PREADY[4]),
        .PSLVERR(PSLVERR[4]),
        .rx_i   (rx0_i),
        .tx_o   (tx0_o),
        .event_o(uart0_event_o)
    );

    // UART1 instance (PSEL[5])
    apb_uart_sv #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) uart1_inst (
        .CLK    (HCLK),
        .RSTN   (HRESETn),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PWRITE (PWRITE),
        .PSEL   (PSEL[5]),
        .PENABLE(PENABLE),
        .PRDATA (PRDATA[5]),
        .PREADY (PREADY[5]),
        .PSLVERR(PSLVERR[5]),
        .rx_i   (rx1_i),
        .tx_o   (tx1_o),
        .event_o(uart1_event_o)
    );

    // GPIO0 instance (PSEL[6])
    apb_gpio #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) gpio0_inst (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .PADDR       (PADDR),
        .PWDATA      (PWDATA),
        .PWRITE      (PWRITE),
        .PSEL        (PSEL[6]),
        .PENABLE     (PENABLE),
        .PRDATA      (PRDATA[6]),
        .PREADY      (PREADY[6]),
        .PSLVERR     (PSLVERR[6]),
        .gpio_in     (gpio0_in),
        .gpio_in_sync(gpio0_in_sync),
        .gpio_out    (gpio0_out),
        .gpio_dir    (gpio0_dir),
        .gpio_padcfg (gpio0_padcfg),
        .gpio_iof    (gpio0_iof),
        .interrupt   (gpio0_interrupt)
    );

    // GPIO1 instance (PSEL[7])
    apb_gpio #(
        .APB_ADDR_WIDTH(APB_SLAVE_ADDR_WIDTH)
    ) gpio1_inst (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .PADDR       (PADDR),
        .PWDATA      (PWDATA),
        .PWRITE      (PWRITE),
        .PSEL        (PSEL[7]),
        .PENABLE     (PENABLE),
        .PRDATA      (PRDATA[7]),
        .PREADY      (PREADY[7]),
        .PSLVERR     (PSLVERR[7]),
        .gpio_in     (gpio1_in),
        .gpio_in_sync(gpio1_in_sync),
        .gpio_out    (gpio1_out),
        .gpio_dir    (gpio1_dir),
        .gpio_padcfg (gpio1_padcfg),
        .gpio_iof    (gpio1_iof),
        .interrupt   (gpio1_interrupt)
    );

endmodule
