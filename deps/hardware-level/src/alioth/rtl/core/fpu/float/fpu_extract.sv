// 浮点扩展与分类模块
// 负责浮点数的规格化、分类（如零、无穷、NaN等），并与前导零计数器协作
//
// 端口说明：
//   fpu_ext_i/o : 输入输出结构体

import fpu_types::*;

module fpu_extract (
    input                  clk,
    input                  rst_n,
    input  fpu_ext_in_type  fpu_ext_i,
    output fpu_ext_out_type fpu_ext_o
);

    logic [63:0] data;
    logic [ 1:0] fmt;

    logic [63:0] mantissa;
    logic [64:0] result;
    logic [ 9:0] classification;
    logic [ 5:0] counter;
    logic        mantissa_zero;
    logic        exponent_zero;
    logic        exponent_ones;

    logic [63:0] lzc_data_in;
    logic [ 5:0] lzc_lzc;
    logic        lzc_valid;

    // 实例化 lzc_64
    lzc_64 u_lzc_64 (
        .data_in(lzc_data_in),
        .lzc    (lzc_lzc),
        .valid  (lzc_valid)
    );

    always_comb begin

        data           = fpu_ext_i.data;
        fmt            = fpu_ext_i.fmt;

        mantissa       = 64'hFFFFFFFFFFFFFFFF;
        counter        = 0;

        result         = 0;
        classification = 0;

        mantissa_zero  = 0;
        exponent_zero  = 0;
        exponent_ones  = 0;

        if (fmt == 0) begin
            mantissa      = {1'h0, data[22:0], 40'hFFFFFFFFFF};
            exponent_zero = ~|data[30:23];
            exponent_ones = &data[30:23];
            mantissa_zero = ~|data[22:0];
        end else begin
            mantissa      = {1'h0, data[51:0], 11'h7FF};
            exponent_zero = ~|data[62:52];
            exponent_ones = &data[62:52];
            mantissa_zero = ~|data[51:0];
        end

        lzc_data_in = mantissa;
        counter     = ~lzc_lzc;

        if (fmt == 0) begin
            result[64] = data[31];
            if (&data[30:23]) begin
                result[63:52] = 12'hFFF;
                result[51:29] = data[22:0];
            end else if (|data[30:23]) begin
                result[63:52] = {4'h0, data[30:23]} + 12'h780;
                result[51:29] = data[22:0];
            end else if (counter < 24) begin
                result[63:52] = 12'h781 - {6'h0, counter};
                result[51:29] = (data[22:0] << counter);
            end
            result[28:0] = 0;
        end else if (fmt == 1) begin
            result[64] = data[63];
            if (&data[62:52]) begin
                result[63:52] = 12'hFFF;
                result[51:0]  = data[51:0];
            end else if (|data[62:52]) begin
                result[63:52] = {1'h0, data[62:52]} + 12'h400;
                result[51:0]  = data[51:0];
            end else if (counter < 53) begin
                result[63:52] = 12'h401 - {6'h0, counter};
                result[51:0]  = (data[51:0] << counter);
            end
        end

        if (result[64]) begin
            if (exponent_ones) begin
                if (mantissa_zero) begin
                    classification[0] = 1;
                end else if (result[51] == 0) begin
                    classification[8] = 1;
                end else begin
                    classification[9] = 1;
                end
            end else if (exponent_zero) begin
                if (mantissa_zero == 1) begin
                    classification[3] = 1;
                end else begin
                    classification[2] = 1;
                end
            end else begin
                classification[1] = 1;
            end
        end else begin
            if (exponent_ones) begin
                if (mantissa_zero) begin
                    classification[7] = 1;
                end else if (result[51] == 0) begin
                    classification[8] = 1;
                end else begin
                    classification[9] = 1;
                end
            end else if (exponent_zero) begin
                if (mantissa_zero == 1) begin
                    classification[4] = 1;
                end else begin
                    classification[5] = 1;
                end
            end else begin
                classification[6] = 1;
            end
        end

        fpu_ext_o.result         = result;
        fpu_ext_o.classification = classification;

    end

endmodule
