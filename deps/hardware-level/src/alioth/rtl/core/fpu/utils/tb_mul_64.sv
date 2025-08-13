`timescale 1ns/1ps

module tb_mul_64;

    reg clk, rst_n, start_i;
    reg [63:0] a_i, b_i;
    wire [127:0] result_o_unsigned, result_o_signed;
    wire valid_o_unsigned, valid_o_signed;
    logic [127:0] expect_unsigned;
    logic signed [127:0] expect_signed;

    // 实例化无符号
    mul_64 #(.SIGNED(0)) u_mul_64_unsigned (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start_i),
        .a_i(a_i),
        .b_i(b_i),
        .result_o(result_o_unsigned),
        .valid_o(valid_o_unsigned)
    );

    // 实例化有符号
    mul_64 #(.SIGNED(1)) u_mul_64_signed (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start_i),
        .a_i(a_i),
        .b_i(b_i),
        .result_o(result_o_signed),
        .valid_o(valid_o_signed)
    );

    // 55位无符号实例
    wire [127:0] result_o_unsigned_55;
    wire valid_o_unsigned_55;
    reg [54:0] a_i_55, b_i_55;
    logic [127:0] expect_unsigned_55;

    mul_64 #(.SIGNED(0), .WIDTH(55)) u_mul_64_unsigned_55 (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start_i),
        .a_i(a_i_55),
        .b_i(b_i_55),
        .result_o(result_o_unsigned_55),
        .valid_o(valid_o_unsigned_55)
    );

    // 32位有符号实例
    wire [127:0] result_o_signed_32;
    wire valid_o_signed_32;
    reg [31:0] a_i_32, b_i_32;
    logic [127:0] expect_signed_32;

    mul_64 #(.SIGNED(1), .WIDTH(32)) u_mul_64_signed_32 (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start_i),
        .a_i(a_i_32),
        .b_i(b_i_32),
        .result_o(result_o_signed_32),
        .valid_o(valid_o_signed_32)
    );

    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        start_i = 0;
        a_i = 0;
        b_i = 0;
        #20;
        rst_n = 1;
        #20;

        // 无符号测试
        a_i = 64'h0000_0001_0000_0002;
        b_i = 64'h0000_0003_0000_0004;
        expect_unsigned = $unsigned(a_i) * $unsigned(b_i);
        start_i = 1;
        #10;
        start_i = 0;
        wait(valid_o_unsigned);
        $display("Unsigned: %h * %h = %h", a_i, b_i, result_o_unsigned);
        $display("Expect128: %h", expect_unsigned);
        #10;

        // 有符号测试
        a_i = -64'sd123456789;
        b_i =  64'sd987654321;
        expect_signed = $signed(a_i) * $signed(b_i);
        start_i = 1;
        #10;
        start_i = 0;
        wait(valid_o_signed);
        $display("Signed: %0d * %0d = %0d", $signed(a_i), $signed(b_i), $signed(result_o_signed));
        $display("Expect128: %0d", expect_signed);
        #10;

        a_i = -64'sd123456789;
        b_i = -64'sd987654321;
        expect_signed = $signed(a_i) * $signed(b_i);
        start_i = 1;
        #10;
        start_i = 0;
        wait(valid_o_signed);
        $display("Signed: %0d * %0d = %0d", $signed(a_i), $signed(b_i), $signed(result_o_signed));
        $display("Expect128: %0d", expect_signed);
        #10;

        // 特殊情况测试
        // 1. 全0
        a_i = 64'd0;
        b_i = 64'd0;
        expect_unsigned = $unsigned(a_i) * $unsigned(b_i);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_unsigned);
        $display("All zero: %h * %h = %h", a_i, b_i, result_o_unsigned);
        $display("Expect128: %h", expect_unsigned);
        #10;

        // 2. 全1
        a_i = 64'hFFFF_FFFF_FFFF_FFFF;
        b_i = 64'hFFFF_FFFF_FFFF_FFFF;
        expect_unsigned = $unsigned(a_i) * $unsigned(b_i);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_unsigned);
        $display("All one: %h * %h = %h", a_i, b_i, result_o_unsigned);
        $display("Expect128: %h", expect_unsigned);
        #10;

        // 3. 最大正数 * 最大正数（有符号）
        a_i = 64'sd9223372036854775807; // 2^63-1
        b_i = 64'sd9223372036854775807;
        expect_signed = $signed(a_i) * $signed(b_i);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_signed);
        $display("Max pos * Max pos: %0d * %0d = %0d", $signed(a_i), $signed(b_i), $signed(result_o_signed));
        $display("Expect128: %0d", expect_signed);
        #10;

        // 4. 最小负数 * 最小负数（有符号）
        a_i = -64'sd9223372036854775808; // -2^63
        b_i = -64'sd9223372036854775808;
        expect_signed = $signed(a_i) * $signed(b_i);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_signed);
        $display("Min neg * Min neg: %0d * %0d = %0d", $signed(a_i), $signed(b_i), $signed(result_o_signed));
        $display("Expect128: %0d", expect_signed);
        #10;

        // 5. 最大正数 * 最小负数（有符号）
        a_i = 64'sd9223372036854775807;
        b_i = -64'sd9223372036854775808;
        expect_signed = $signed(a_i) * $signed(b_i);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_signed);
        $display("Max pos * Min neg: %0d * %0d = %0d", $signed(a_i), $signed(b_i), $signed(result_o_signed));
        $display("Expect128: %0d", expect_signed);
        #10;

        // 6. 低位宽边界（如55位最大值）
        a_i = 55'h7FFFFFFFFFFFFF;
        b_i = 55'h7FFFFFFFFFFFFF;
        expect_unsigned = $unsigned(a_i) * $unsigned(b_i);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_unsigned);
        $display("55bit max * 55bit max: %h * %h = %h", a_i, b_i, result_o_unsigned);
        $display("Expect128: %h", expect_unsigned);
        #10;

        // 7. 55位无符号测试
        a_i_55 = 55'h123456789ABCD;
        b_i_55 = 55'h1FFFFF0000000;
        expect_unsigned_55 = $unsigned(a_i_55) * $unsigned(b_i_55);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_unsigned_55);
        $display("55bit unsigned: %h * %h = %h", a_i_55, b_i_55, result_o_unsigned_55);
        $display("Expect128: %h", expect_unsigned_55);
        #10;

        // 8. 32位有符号测试
        a_i_32 = -32'sd12345678;
        b_i_32 =  32'sd87654321;
        expect_signed_32 = $signed(a_i_32) * $signed(b_i_32);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_signed_32);
        $display("32bit signed: %0d * %0d = %0d", $signed(a_i_32), $signed(b_i_32), $signed(result_o_signed_32));
        $display("Expect128: %0d", expect_signed_32);
        #10;

        // 9. 32位有符号负数*负数
        a_i_32 = -32'sd12345678;
        b_i_32 = -32'sd87654321;
        expect_signed_32 = $signed(a_i_32) * $signed(b_i_32);
        start_i = 1;
        #10; start_i = 0;
        wait(valid_o_signed_32);
        $display("32bit signed neg*neg: %0d * %0d = %0d", $signed(a_i_32), $signed(b_i_32), $signed(result_o_signed_32));
        $display("Expect128: %0d", expect_signed_32);
        #10;

        $finish;
    end

endmodule
