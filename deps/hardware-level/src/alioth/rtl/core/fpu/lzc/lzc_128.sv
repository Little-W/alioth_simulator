module lzc_128 (
    input  [127:0] data_in,
    output [  6:0] lzc,
    output         valid
);

    // 低64位计数
    logic [5:0] lower_half_count;
    // 高64位计数
    logic [5:0] upper_half_count;
    // 低64位有效标志
    logic       lower_half_valid;
    // 高64位有效标志
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
    // 计数第4位选择器
    logic       bit4_mux_sel;
    // 计数第4位最终值
    logic       bit4_final;
    // 计数第5位选择器
    logic       bit5_mux_sel;
    // 计数第5位最终值
    logic       bit5_final;

    lzc_64 lzc_64_0 (
        .data_in(data_in[63:0]),
        .lzc    (lower_half_count),
        .valid  (lower_half_valid)
    );

    lzc_64 lzc_64_1 (
        .data_in(data_in[127:64]),
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
    assign bit4_mux_sel  = (~upper_half_valid) & lower_half_count[4];
    assign bit4_final    = upper_half_count[4] | bit4_mux_sel;
    assign bit5_mux_sel  = (~upper_half_valid) & lower_half_count[5];
    assign bit5_final    = upper_half_count[5] | bit5_mux_sel;

    assign valid         = overall_valid;
    assign lzc[0]        = bit0_final;
    assign lzc[1]        = bit1_final;
    assign lzc[2]        = bit2_final;
    assign lzc[3]        = bit3_final;
    assign lzc[4]        = bit4_final;
    assign lzc[5]        = bit5_final;
    assign lzc[6]        = upper_half_valid;

endmodule
