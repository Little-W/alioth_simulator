`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2025 06:21:44 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module twin_top #(
    parameter CLK_FREQ_MHZ = 100
)(
    input  wire i_clk,           // 新增时钟输入端口
    input  wire i_clk_50m,           // 新增时钟输入端口
    input  wire rst_n,           // 新增复位输入端口
    input  wire i_uart_rx,
    output wire o_uart_tx,
    output wire [31:0] virtual_led,
    output wire [39:0] virtual_seg
);

localparam CLK_FREQ = CLK_FREQ_MHZ * 1000000;
wire [7:0] virtual_key;
wire [63:0] virtual_sw;

wire [7:0] rx_data;
wire rx_ready;
wire tx_start;
wire [7:0] tx_data;
wire tx_busy;
reg [31:0] virtual_led_buf1, virtual_led_buf2, virtual_led_buf3;
reg [39:0] virtual_seg_buf1, virtual_seg_buf2, virtual_seg_buf3;
reg [63:0] virtual_sw_buf1, virtual_sw_buf2, virtual_sw_buf3;
reg [7:0] virtual_key_buf1, virtual_key_buf2, virtual_key_buf3;

always @(posedge i_clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        virtual_led_buf1 <= 32'b0;
        virtual_led_buf2 <= 32'b0;
        virtual_led_buf3 <= 32'b0;
        virtual_seg_buf1 <= 40'b0;
        virtual_seg_buf2 <= 40'b0;
        virtual_seg_buf3 <= 40'b0;
    end else begin
        virtual_led_buf1 <= virtual_led;
        virtual_led_buf2 <= virtual_led_buf1;
        virtual_led_buf3 <= virtual_led_buf2;
        virtual_seg_buf1 <= virtual_seg;
        virtual_seg_buf2 <= virtual_seg_buf1;
        virtual_seg_buf3 <= virtual_seg_buf2;
    end
end

always @(posedge i_clk or negedge rst_n) begin
    if (!rst_n) begin
        virtual_sw_buf1 <= 64'b0;
        virtual_sw_buf2 <= 64'b0;
        virtual_sw_buf3 <= 64'b0;
        virtual_key_buf1 <= 8'b0;
        virtual_key_buf2 <= 8'b0;
        virtual_key_buf3 <= 8'b0;
    end else begin
        virtual_sw_buf1 <= virtual_sw;
        virtual_sw_buf2 <= virtual_sw_buf1;
        virtual_sw_buf3 <= virtual_sw_buf2;
        virtual_key_buf1 <= virtual_key;
        virtual_key_buf2 <= virtual_key_buf1;
        virtual_key_buf3 <= virtual_key_buf2;
    end
end

uart #(
    .CLK_FREQ(50000000), // 使用参数
    .BAUD_RATE(9600)
) uart_inst(
    .clk(i_clk_50m),         // 使用新时钟端口
    .rst_n(rst_n),       // 使用新复位端口
    .rx(i_uart_rx),
    .rx_data(rx_data),
    .rx_ready(rx_ready),
    .tx(o_uart_tx),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx_busy(tx_busy)
);

twin_controller twin_controller_inst(
    .clk(i_clk_50m),         // 使用新时钟端口
    .rst_n(rst_n),       // 使用新复位端口
    .rx_ready(rx_ready),
    .rx_data(rx_data),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx_busy(tx_busy),
    .sw(virtual_sw),
    .key(virtual_key),
    .seg(virtual_seg_buf3), // 修改为第3级缓冲
    .led(virtual_led_buf3)  // 修改为第3级缓冲
);

cpu_top #(
    .CLK_FREQ(CLK_FREQ)
) alioth_inst(
    .clk(i_clk),
    .rst_n(rst_n),
    .virtual_sw_input(virtual_sw_buf3), // 修改为第3级缓冲
    .virtual_key_input(virtual_key_buf3), // 修改为第3级缓冲
    .virtual_seg_output(virtual_seg),
    .virtual_led_output(virtual_led)
);

endmodule
