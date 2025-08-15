// 浮点符号操作模块
// 实现浮点数的符号赋值、取反、异或等操作
//
// 端口说明：
//   fpu_sgnj_i : 输入结构体，包含操作数和控制信号
//   fpu_sgnj_o : 输出结构体，包含结果

import fpu_types::*;

module fpu_sgnj (
    input                   clk,
    input                   rst_n,
    input  fpu_sgnj_in_type  fpu_sgnj_i,
    output fpu_sgnj_out_type fpu_sgnj_o
);

    logic [63:0] data1;
    logic [63:0] data2;
    logic [ 1:0] fmt;
    logic [ 2:0] rm;
    logic [63:0] result;

    always_comb begin

        data1  = fpu_sgnj_i.data1;
        data2  = fpu_sgnj_i.data2;
        fmt    = fpu_sgnj_i.fmt;
        rm     = fpu_sgnj_i.rm;

        result = 0;

        if (fmt == 0) begin
            result[30:0] = data1[30:0];
            if (rm == 0) begin
                result[31] = data2[31];
            end else if (rm == 1) begin
                result[31] = ~data2[31];
            end else if (rm == 2) begin
                result[31] = data1[31] ^ data2[31];
            end
        end else if (fmt == 1) begin
            result[62:0] = data1[62:0];
            if (rm == 0) begin
                result[63] = data2[63];
            end else if (rm == 1) begin
                result[63] = ~data2[63];
            end else if (rm == 2) begin
                result[63] = data1[63] ^ data2[63];
            end
        end

        fpu_sgnj_o.result = result;

    end

endmodule
