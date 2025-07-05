`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 03:04:25 PM
// Design Name: 
// Module Name: counter
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


module counter(
    input  logic         clk,
    input  logic         clk_fast, // 新增高速时钟
    input  logic         rst,

    input  logic [31:0]  perip_wdata,
    input  logic         cnt_wen,
    output logic [31:0]  perip_rdata
);

    // 高速时钟域下的寄存器
    logic [31:0] perip_wdata_fast_d[3:0];
    logic        cnt_wen_fast_d[3:0];
    logic        rst_fast_d[3:0];

    // 高速时钟域下输入信号寄存与延迟4拍
    always_ff @(posedge clk_fast) begin
        perip_wdata_fast_d[0] <= perip_wdata;
        cnt_wen_fast_d[0]     <= cnt_wen;
        rst_fast_d[0]         <= rst;
        for (int i = 1; i < 4; i++) begin
            perip_wdata_fast_d[i] <= perip_wdata_fast_d[i-1];
            cnt_wen_fast_d[i]     <= cnt_wen_fast_d[i-1];
            rst_fast_d[i]         <= rst_fast_d[i-1];
        end
    end

    // 低速时钟域下采样延迟4拍后的信号，并多打一拍，避免亚稳态
    logic [31:0] perip_wdata_sync_ff1, perip_wdata_sync_ff2;
    logic        cnt_wen_sync_ff1, cnt_wen_sync_ff2;
    logic        rst_sync_ff1, rst_sync_ff2;

    always_ff @(posedge clk) begin
        perip_wdata_sync_ff1 <= perip_wdata_fast_d[3];
        perip_wdata_sync_ff2 <= perip_wdata_sync_ff1;
        cnt_wen_sync_ff1     <= cnt_wen_fast_d[3];
        cnt_wen_sync_ff2     <= cnt_wen_sync_ff1;
        rst_sync_ff1         <= rst_fast_d[3];
        rst_sync_ff2         <= rst_sync_ff1;
    end

    wire [31:0] perip_wdata_sync = perip_wdata_sync_ff2;
    wire        cnt_wen_sync     = cnt_wen_sync_ff2;
    wire        rst_sync         = rst_sync_ff2;

    // 高速时钟域下采样写启动和写停止条件
    logic start_set_fast, start_clr_fast;
    always_ff @(posedge clk_fast) begin
        start_set_fast <= cnt_wen & (perip_wdata == 32'h8000_0000);
        start_clr_fast <= cnt_wen & (perip_wdata == 32'hFFFF_FFFF);
    end

    // 多拍同步到低速时钟域，避免亚稳态
    logic start_set_sync_ff1, start_set_sync_ff2;
    logic start_clr_sync_ff1, start_clr_sync_ff2;
    always_ff @(posedge clk) begin
        start_set_sync_ff1 <= start_set_fast;
        start_set_sync_ff2 <= start_set_sync_ff1;
        start_clr_sync_ff1 <= start_clr_fast;
        start_clr_sync_ff2 <= start_clr_sync_ff1;
    end

    wire start_set = start_set_sync_ff2;
    wire start_clr = start_clr_sync_ff2;

    // 采样写启动和写停止条件
    logic start;

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            start <= 0;
        end else if (start_set) begin
            start <= 1;
        end else if (start_clr) begin
            start <= 0;
        end
    end

    logic [15:0] cnt_1ms;
    logic [31:0] cnt_ms;

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            cnt_1ms <= 0;
        end else if (start) begin
            if (cnt_1ms == 49999) begin
                cnt_1ms <= 0;
            end else begin
                cnt_1ms <= cnt_1ms + 1;
            end
        end else begin
            cnt_1ms <= 0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            cnt_ms <= 0;
        end else if (start && cnt_1ms == 49999) begin
            cnt_ms <= cnt_ms + 1;
        end
    end

    assign perip_rdata = cnt_ms;

endmodule
