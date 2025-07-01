`timescale 1ns / 1ps
`include "defines.svh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/22 10:25:24
// Design Name: 
// Module Name: perip_bridge
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

module perip_bridge (
    input logic clk,
    input logic cnt_clk,
    input logic rst,

    // 写端口
    input logic [31:0] perip_waddr,
    input logic [31:0] perip_wdata,
    input logic        perip_wen,
    input logic [ 3:0] perip_mask,

    // 读端口
    input  logic [31:0] perip_raddr,
    output logic [31:0] perip_rdata,

    input logic [63:0] virtual_sw_input,
    input logic [ 7:0] virtual_key_input,

    output logic [39:0] virtual_seg_output,
    output logic [31:0] virtual_led_output
);
    localparam DTCM_ADDR_START = `DTCM_BASE_ADDR;
    localparam DTCM_ADDR_END = `DTCM_BASE_ADDR + `DTCM_SIZE - 1;

    logic [31:0] LED;
    logic [31:0] seg_wdata, cnt_rdata, mmio_rdata, dram_rdata;
    logic [39:0] seg_output;
    logic [31:0] perip_rdata_reg;  // 添加寄存器

    // we don't care perip_mask in LED, SEG, SW & KEY, only care in DTCM
    // write process
    always_ff @(posedge clk) begin
        if (perip_wen) begin
            case (perip_waddr)
                `LED_ADDR: LED <= perip_wdata;
                `SEG_ADDR: seg_wdata <= perip_wdata;
            endcase
        end
    end

    // read process: in one cycle
    always_comb begin
        case (perip_raddr)
            `SW0_ADDR: mmio_rdata = virtual_sw_input[31:0];
            `SW1_ADDR: mmio_rdata = virtual_sw_input[63:32];
            `KEY_ADDR: mmio_rdata = {24'd0, virtual_key_input};
            `SEG_ADDR: mmio_rdata = seg_wdata;
            default:  mmio_rdata = 32'hDEAD_BEEF;
        endcase
    end

    // seg driver
    display_seg seg_driver (
        .clk (clk),
        .rst (rst),
        .s   (seg_wdata),
        .seg1(seg_output[6:0]),
        .seg2(seg_output[16:10]),
        .seg3(seg_output[26:20]),
        .seg4(seg_output[36:30]),
        .ans ({seg_output[39:38], seg_output[29:28], seg_output[19:18], seg_output[9:8]})
    );

    assign seg_output[7]  = 0;
    assign seg_output[17] = 0;
    assign seg_output[27] = 0;
    assign seg_output[37] = 0;

    // DTCM实例化
    gnrl_ram_pseudo_dual_async #(
        .ADDR_WIDTH(`DTCM_ADDR_WIDTH),
        .DATA_WIDTH(32),
        .INIT_MEM  (`INIT_DTCM),
        .INIT_FILE (`DTCM_INIT_FILE)
    ) ram_inst (
        .clk(clk),
        .rst_n(~rst),
        .we_i(perip_wen & (perip_waddr >= DTCM_ADDR_START && perip_waddr < DTCM_ADDR_END)),
        .we_mask_i(perip_mask),  // 直接使用4位掩码
        .waddr_i(perip_waddr[`DTCM_ADDR_WIDTH-1:0]),
        .data_i(perip_wdata),
        .raddr_i(perip_raddr[`DTCM_ADDR_WIDTH-1:0]),
        .data_o(dram_rdata)
    );

    // counter rw
    counter counter_inst (
        .clk        (cnt_clk),
        .rst        (rst),
        .perip_wdata(perip_wdata),
        .cnt_wen    (perip_wen & (perip_waddr == `CNT_ADDR)),
        .perip_rdata(cnt_rdata)
    );

    // 添加一级寄存器进行数据读取
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            perip_rdata_reg <= 32'h0;
        end else begin
            perip_rdata_reg <= {32{perip_raddr == `SW0_ADDR}} & mmio_rdata |
                              {32{perip_raddr == `SW1_ADDR}} & mmio_rdata |
                              {32{perip_raddr == `KEY_ADDR}} & mmio_rdata |
                              {32{perip_raddr == `SEG_ADDR}} & mmio_rdata |
                              {32{perip_raddr >= DTCM_ADDR_START && perip_raddr < DTCM_ADDR_END}} & dram_rdata |
                              {32{perip_raddr == `CNT_ADDR}} & cnt_rdata;
        end
    end

    assign perip_rdata        = perip_rdata_reg;

    assign virtual_led_output = LED;
    assign virtual_seg_output = seg_output;

endmodule
