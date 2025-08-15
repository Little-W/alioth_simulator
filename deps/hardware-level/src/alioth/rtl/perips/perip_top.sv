`include "defines.svh"

module perip_top #(
    parameter APB_DEV_COUNT        = 8,
    parameter APB_SLAVE_ADDR_WIDTH = 12,
    parameter BUS_DATA_WIDTH       = 32
) (
    input  wire                            HCLK,
    input  wire                            HRESETn,
    input  wire [APB_SLAVE_ADDR_WIDTH-1:0] PADDR,
    input  wire [                    31:0] PWDATA,
    input  wire                            PWRITE,
    input  wire [       APB_DEV_COUNT-1:0] PSEL,
    input  wire                            PENABLE,
    output wire [      BUS_DATA_WIDTH-1:0] PRDATA [APB_DEV_COUNT],
    output wire [       APB_DEV_COUNT-1:0] PREADY,
    output wire [       APB_DEV_COUNT-1:0] PSLVERR,

    // UART0 - 保留独立引脚
    input  wire uart0_rxd_i,
    output wire uart0_txd_o,
    output wire uart0_event_o,

    // 保留事件信号到外部端口
    output wire uart1_event_o,
    output wire spi_events_o,
    output wire i2c0_interrupt_o,
    output wire i2c1_interrupt_o,

    // GPIO0 - 与其他外设复用
    input  wire [31:0] gpio0_in_i,
    output wire [31:0] gpio0_out_o,
    output wire [31:0] gpio0_dir_o,

    output wire        gpio0_interrupt_o,
    // GPIO1
    input  wire [31:0] gpio1_in_i,
    output wire [31:0] gpio1_out_o,
    output wire [31:0] gpio1_dir_o,

    output wire gpio1_interrupt_o,

    // Timer
    input  wire       dft_cg_enable_i,
    input  wire       low_speed_clk_i,
    output wire [3:0] timer_events_o
);
    // 内部信号定义
    wire [31:0] gpio0_in_sync;
    wire [31:0] gpio1_in_sync;
    wire [31:0] gpio0_iof;
    wire [31:0] gpio1_iof;
    wire [31:0] gpio0_out;
    wire [31:0] gpio0_dir;
    wire [31:0] gpio1_out;
    wire [31:0] gpio1_dir;
    wire [ 3:0] pwm_ch0;
    wire [ 3:0] pwm_ch1;
    wire [ 3:0] pwm_ch2;
    wire [ 3:0] pwm_ch3;
    wire        spi_clk;
    wire        spi_csn0;
    wire        spi_csn1;
    wire        spi_csn2;
    wire        spi_csn3;
    wire        spi_sdo0;
    wire        spi_sdo1;
    wire        spi_sdo2;
    wire        spi_sdo3;
    wire        spi_oe0;
    wire        spi_oe1;
    wire        spi_oe2;
    wire        spi_oe3;
    wire        spi_sdi0;
    wire        spi_sdi1;
    wire        spi_sdi2;
    wire        spi_sdi3;

    wire        scl0_pad_o;
    wire        scl0_padoen_o;
    wire        sda0_pad_o;
    wire        sda0_padoen_o;
    wire        scl1_pad_o;
    wire        scl1_padoen_o;
    wire        sda1_pad_o;
    wire        sda1_padoen_o;

    wire        uart1_rxd;
    wire        uart1_txd;

    wire        i2c0_scl;
    wire        i2c0_sda;
    wire        i2c1_scl;
    wire        i2c1_sda;

    // Timer instance (PSEL[0])
`ifdef ENABLE_TIMER
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
        .ext_sig_i      (gpio0_in_sync),
        .events_o       (timer_events_o),
        .pwm_ch0        (pwm_ch0),
        .pwm_ch1        (pwm_ch1),
        .pwm_ch2        (pwm_ch2),
        .pwm_ch3        (pwm_ch3)
    );
`endif

    // SPI instance (PSEL[1])
`ifdef ENABLE_SPI
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
`endif

    // I2C0 instance (PSEL[2])
`ifdef ENABLE_I2C0
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
        .scl_pad_i   (i2c0_scl),
        .scl_pad_o   (scl0_pad_o),
        .scl_padoen_o(scl0_padoen_o),
        .sda_pad_i   (i2c0_sda),
        .sda_pad_o   (sda0_pad_o),
        .sda_padoen_o(sda0_padoen_o)
    );
`endif

    // I2C1 instance (PSEL[3])
`ifdef ENABLE_I2C1
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
        .scl_pad_i   (i2c1_scl),
        .scl_pad_o   (scl1_pad_o),
        .scl_padoen_o(scl1_padoen_o),
        .sda_pad_i   (i2c1_sda),
        .sda_pad_o   (sda1_pad_o),
        .sda_padoen_o(sda1_padoen_o)
    );
`endif

    // UART0 instance (PSEL[4])
`ifdef ENABLE_UART0
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
        .rx_i   (uart0_rxd_i),
        .tx_o   (uart0_txd_o),
        .event_o(uart0_event_o)
    );
`endif

    // UART1 instance (PSEL[5])
`ifdef ENABLE_UART1
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
        .rx_i   (uart1_rxd),
        .tx_o   (uart1_txd),
        .event_o(uart1_event_o)
    );
`endif

    // GPIO0 instance (PSEL[6])
`ifdef ENABLE_GPIO0
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
        .gpio_in     (gpio0_in_i),
        .gpio_in_sync(gpio0_in_sync),
        .gpio_out    (gpio0_out),
        .gpio_dir    (gpio0_dir),
        .gpio_padcfg (),
        .gpio_iof    (gpio0_iof),
        .interrupt   (gpio0_interrupt_o)
    );
`endif

    // GPIO1 instance (PSEL[7])
`ifdef ENABLE_GPIO1
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
        .gpio_in     (gpio1_in_i),
        .gpio_in_sync(gpio1_in_sync),
        .gpio_out    (gpio1_out),
        .gpio_dir    (gpio1_dir),
        .gpio_padcfg (),
        .gpio_iof    (gpio1_iof),
        .interrupt   (gpio1_interrupt_o)
    );
`endif

    // 引脚复用逻辑
    // GPIO0引脚复用
    // GPIO0[0-3]: Timer CH0-3 (PWM输出)
    assign gpio0_out_o[0]  = gpio0_iof[0] ? pwm_ch0[0] : gpio0_out[0];
    assign gpio0_out_o[1]  = gpio0_iof[1] ? pwm_ch0[1] : gpio0_out[1];
    assign gpio0_out_o[2]  = gpio0_iof[2] ? pwm_ch0[2] : gpio0_out[2];
    assign gpio0_out_o[3]  = gpio0_iof[3] ? pwm_ch0[3] : gpio0_out[3];

    // GPIO0[4-7]: Timer CH1
    assign gpio0_out_o[4]  = gpio0_iof[4] ? pwm_ch1[0] : gpio0_out[4];
    assign gpio0_out_o[5]  = gpio0_iof[5] ? pwm_ch1[1] : gpio0_out[5];
    assign gpio0_out_o[6]  = gpio0_iof[6] ? pwm_ch1[2] : gpio0_out[6];
    assign gpio0_out_o[7]  = gpio0_iof[7] ? pwm_ch1[3] : gpio0_out[7];

    // GPIO0[8-11]: Timer CH2
    assign gpio0_out_o[8]  = gpio0_iof[8] ? pwm_ch2[0] : gpio0_out[8];
    assign gpio0_out_o[9]  = gpio0_iof[9] ? pwm_ch2[1] : gpio0_out[9];
    assign gpio0_out_o[10] = gpio0_iof[10] ? pwm_ch2[2] : gpio0_out[10];
    assign gpio0_out_o[11] = gpio0_iof[11] ? pwm_ch2[3] : gpio0_out[11];

    // GPIO0[12-15]: Timer CH3
    assign gpio0_out_o[12] = gpio0_iof[12] ? pwm_ch3[0] : gpio0_out[12];
    assign gpio0_out_o[13] = gpio0_iof[13] ? pwm_ch3[1] : gpio0_out[13];
    assign gpio0_out_o[14] = gpio0_iof[14] ? pwm_ch3[2] : gpio0_out[14];
    assign gpio0_out_o[15] = gpio0_iof[15] ? pwm_ch3[3] : gpio0_out[15];

    // GPIO0[16]: UART1 RX (输入)
    assign gpio0_out_o[16] = gpio0_iof[16] ? 1'b0 : gpio0_out[16];
    // GPIO0[17]: UART1 TX (输出)
    assign gpio0_out_o[17] = gpio0_iof[17] ? uart1_txd : gpio0_out[17];

    // GPIO0[18-19]: I2C0 (SCL, SDA)
    assign gpio0_out_o[18] = gpio0_iof[18] ? scl0_pad_o : gpio0_out[18];
    assign gpio0_out_o[19] = gpio0_iof[19] ? sda0_pad_o : gpio0_out[19];

    // GPIO0[20-21]: I2C1 (SCL, SDA)
    assign gpio0_out_o[20] = gpio0_iof[20] ? scl1_pad_o : gpio0_out[20];
    assign gpio0_out_o[21] = gpio0_iof[21] ? sda1_pad_o : gpio0_out[21];

    // GPIO0[22-31]: SPI信号
    assign gpio0_out_o[22] = gpio0_iof[22] ? spi_clk : gpio0_out[22];
    assign gpio0_out_o[23] = gpio0_iof[23] ? spi_csn0 : gpio0_out[23];
    assign gpio0_out_o[24] = gpio0_iof[24] ? spi_csn1 : gpio0_out[24];
    assign gpio0_out_o[25] = gpio0_iof[25] ? spi_csn2 : gpio0_out[25];
    assign gpio0_out_o[26] = gpio0_iof[26] ? spi_csn3 : gpio0_out[26];
    assign gpio0_out_o[27] = gpio0_iof[27] ? spi_sdo0 : gpio0_out[27];
    assign gpio0_out_o[28] = gpio0_iof[28] ? spi_sdo1 : gpio0_out[28];
    assign gpio0_out_o[29] = gpio0_iof[29] ? spi_sdo2 : gpio0_out[29];
    assign gpio0_out_o[30] = gpio0_iof[30] ? spi_sdo3 : gpio0_out[30];
    assign gpio0_out_o[31] = gpio0_out[31];  // 保持原有值

    // GPIO0 IOF复用输出使能
    assign gpio0_dir_o[0]  = gpio0_iof[0] ? 1'b1 : gpio0_dir[0];  // pwm_ch0
    assign gpio0_dir_o[1]  = gpio0_iof[1] ? 1'b1 : gpio0_dir[1];
    assign gpio0_dir_o[2]  = gpio0_iof[2] ? 1'b1 : gpio0_dir[2];
    assign gpio0_dir_o[3]  = gpio0_iof[3] ? 1'b1 : gpio0_dir[3];
    assign gpio0_dir_o[4]  = gpio0_iof[4] ? 1'b1 : gpio0_dir[4];  // pwm_ch1
    assign gpio0_dir_o[5]  = gpio0_iof[5] ? 1'b1 : gpio0_dir[5];
    assign gpio0_dir_o[6]  = gpio0_iof[6] ? 1'b1 : gpio0_dir[6];
    assign gpio0_dir_o[7]  = gpio0_iof[7] ? 1'b1 : gpio0_dir[7];
    assign gpio0_dir_o[8]  = gpio0_iof[8] ? 1'b1 : gpio0_dir[8];  // pwm_ch2
    assign gpio0_dir_o[9]  = gpio0_iof[9] ? 1'b1 : gpio0_dir[9];
    assign gpio0_dir_o[10] = gpio0_iof[10] ? 1'b1 : gpio0_dir[10];
    assign gpio0_dir_o[11] = gpio0_iof[11] ? 1'b1 : gpio0_dir[11];
    assign gpio0_dir_o[12] = gpio0_iof[12] ? 1'b1 : gpio0_dir[12];  // pwm_ch3
    assign gpio0_dir_o[13] = gpio0_iof[13] ? 1'b1 : gpio0_dir[13];
    assign gpio0_dir_o[14] = gpio0_iof[14] ? 1'b1 : gpio0_dir[14];
    assign gpio0_dir_o[15] = gpio0_iof[15] ? 1'b1 : gpio0_dir[15];
    assign gpio0_dir_o[16] = gpio0_iof[16] ? 1'b0 : gpio0_dir[16];  // UART1 RX
    assign gpio0_dir_o[17] = gpio0_iof[17] ? 1'b1 : gpio0_dir[17];  // UART1 TX
    assign gpio0_dir_o[18] = gpio0_iof[18] ? ~scl0_padoen_o : gpio0_dir[18];  // I2C0 SCL
    assign gpio0_dir_o[19] = gpio0_iof[19] ? ~sda0_padoen_o : gpio0_dir[19];  // I2C0 SDA
    assign gpio0_dir_o[20] = gpio0_iof[20] ? ~scl1_padoen_o : gpio0_dir[20];  // I2C1 SCL
    assign gpio0_dir_o[21] = gpio0_iof[21] ? ~sda1_padoen_o : gpio0_dir[21];  // I2C1 SDA
    assign gpio0_dir_o[22] = gpio0_iof[22] ? 1'b1 : gpio0_dir[22];  // SPI
    assign gpio0_dir_o[23] = gpio0_iof[23] ? 1'b1 : gpio0_dir[23];
    assign gpio0_dir_o[24] = gpio0_iof[24] ? 1'b1 : gpio0_dir[24];
    assign gpio0_dir_o[25] = gpio0_iof[25] ? 1'b1 : gpio0_dir[25];
    assign gpio0_dir_o[26] = gpio0_iof[26] ? 1'b1 : gpio0_dir[26];
    assign gpio0_dir_o[27] = gpio0_iof[27] ? spi_oe0 : gpio0_dir[27];
    assign gpio0_dir_o[28] = gpio0_iof[28] ? spi_oe1 : gpio0_dir[28];
    assign gpio0_dir_o[29] = gpio0_iof[29] ? spi_oe2 : gpio0_dir[29];
    assign gpio0_dir_o[30] = gpio0_iof[30] ? spi_oe3 : gpio0_dir[30];
    assign gpio0_dir_o[31] = gpio0_dir[31];

    // 输入信号连接
    assign uart1_rxd       = gpio0_in_sync[16];
    assign i2c0_scl        = gpio0_in_sync[18];
    assign i2c0_sda        = gpio0_in_sync[19];
    assign i2c1_scl        = gpio0_in_sync[20];
    assign i2c1_sda        = gpio0_in_sync[21];
    assign spi_sdi0        = gpio0_in_sync[27];
    assign spi_sdi1        = gpio0_in_sync[28];
    assign spi_sdi2        = gpio0_in_sync[29];
    assign spi_sdi3        = gpio0_in_sync[30];

    assign gpio1_out_o     = gpio1_out;
    assign gpio1_dir_o     = gpio1_dir;

endmodule
