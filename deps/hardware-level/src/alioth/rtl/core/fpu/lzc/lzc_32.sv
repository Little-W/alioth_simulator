module lzc_32 (
    input  [31:0] data_in,
    output [ 4:0] lzc,
    output        valid
);
    timeunit 1ns; timeprecision 1ps;

    // 低16位计数
    logic [3:0] lower_half_count;
    // 高16位计数
    logic [3:0] upper_half_count;
    // 低16位有效标志
    logic       lower_half_valid;
    // 高16位有效标志
    logic       upper_half_valid;
    // 总体有效标志
    logic       overall_valid;
    // 计数第0位选择器
    logic       bit0_mux_sel;
    // 计数第0位最终值
    logic       bit0_final;
    // 计数第1位选择器
    logic       bit1_mux_sel;
    // 计数第1位最终值
    logic       bit1_final;
    // 计数第2位选择器
    logic       bit2_mux_sel;
    // 计数第2位最终值
    logic       bit2_final;
    // 计数第3位选择器
    logic       bit3_mux_sel;
    // 计数第3位最终值
    logic       bit3_final;

    lzc_16 lzc_16_0 (
        .data_in(data_in[15:0]),
        .lzc    (lower_half_count),
        .valid  (lower_half_valid)
    );

    lzc_16 lzc_16_1 (
        .data_in(data_in[31:16]),
        .lzc    (upper_half_count),
        .valid  (upper_half_valid)
    );

    assign overall_valid = upper_half_valid | lower_half_valid;
    assign bit0_mux_sel  = (~upper_half_valid) & lower_half_count[0];
    assign bit0_final    = upper_half_count[0] | bit0_mux_sel;
    assign bit1_mux_sel  = (~upper_half_valid) & lower_half_count[1];
    assign bit1_final    = upper_half_count[1] | bit1_mux_sel;
    assign bit2_mux_sel  = (~upper_half_valid) & lower_half_count[2];
    assign bit2_final    = upper_half_count[2] | bit2_mux_sel;
    assign bit3_mux_sel  = (~upper_half_valid) & lower_half_count[3];
    assign bit3_final    = upper_half_count[3] | bit3_mux_sel;

    assign valid         = overall_valid;
    assign lzc[0]        = bit0_final;
    assign lzc[1]        = bit1_final;
    assign lzc[2]        = bit2_final;
    assign lzc[3]        = bit3_final;
    assign lzc[4]        = upper_half_valid;

endmodule
