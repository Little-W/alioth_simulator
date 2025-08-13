// 浮点除法与开方模块
// 实现浮点数的除法和开方操作，支持多种精度和性能参数
//
// 设计思路：
// 本模块采用迭代法实现浮点除法和开方运算，主要流程包括：
// 1. 输入数据及操作类型的判别和特殊情况处理（如NaN、无穷、零等）。
// 2. 通过查找表（LUT）获得初始倒数或倒数根的近似值，作为迭代起点。
// 3. 利用多步迭代（如牛顿-拉夫森法）和内部MAC单元进行高精度求解。
// 4. 结果规格化、舍入及异常标志处理，输出最终结果。
// 该模块支持单精度和双精度浮点格式，结构清晰，便于扩展和维护。
//
// 端口说明：
//   rst_n, clk      : 时钟与复位
//   fp_fdiv_i/o     : 输入输出结构体
//   fp_mac_i/o      : MAC单元接口
//   clear           : 清除/暂停信号

import fp_types::*;

module fp_fdiv (
    input                   rst_n,
    input                   clk,
    input  fp_fdiv_in_type  fp_fdiv_i,
    output fp_fdiv_out_type fp_fdiv_o,
    input                   clear
);
    timeunit 1ns; timeprecision 1ps;

    fp_fdiv_reg_functional_type r;
    fp_fdiv_reg_functional_type rin;

    fp_fdiv_reg_functional_type v;

    localparam logic [7:0] reciprocal_lut[0:127] = '{
        8'b00000000,
        8'b11111110,
        8'b11111100,
        8'b11111010,
        8'b11111000,
        8'b11110110,
        8'b11110100,
        8'b11110010,
        8'b11110000,
        8'b11101111,
        8'b11101101,
        8'b11101011,
        8'b11101010,
        8'b11101000,
        8'b11100110,
        8'b11100101,
        8'b11100011,
        8'b11100001,
        8'b11100000,
        8'b11011110,
        8'b11011101,
        8'b11011011,
        8'b11011010,
        8'b11011001,
        8'b11010111,
        8'b11010110,
        8'b11010100,
        8'b11010011,
        8'b11010010,
        8'b11010000,
        8'b11001111,
        8'b11001110,
        8'b11001100,
        8'b11001011,
        8'b11001010,
        8'b11001001,
        8'b11000111,
        8'b11000110,
        8'b11000101,
        8'b11000100,
        8'b11000011,
        8'b11000001,
        8'b11000000,
        8'b10111111,
        8'b10111110,
        8'b10111101,
        8'b10111100,
        8'b10111011,
        8'b10111010,
        8'b10111001,
        8'b10111000,
        8'b10110111,
        8'b10110110,
        8'b10110101,
        8'b10110100,
        8'b10110011,
        8'b10110010,
        8'b10110001,
        8'b10110000,
        8'b10101111,
        8'b10101110,
        8'b10101101,
        8'b10101100,
        8'b10101011,
        8'b10101010,
        8'b10101001,
        8'b10101000,
        8'b10101000,
        8'b10100111,
        8'b10100110,
        8'b10100101,
        8'b10100100,
        8'b10100011,
        8'b10100011,
        8'b10100010,
        8'b10100001,
        8'b10100000,
        8'b10011111,
        8'b10011111,
        8'b10011110,
        8'b10011101,
        8'b10011100,
        8'b10011100,
        8'b10011011,
        8'b10011010,
        8'b10011001,
        8'b10011001,
        8'b10011000,
        8'b10010111,
        8'b10010111,
        8'b10010110,
        8'b10010101,
        8'b10010100,
        8'b10010100,
        8'b10010011,
        8'b10010010,
        8'b10010010,
        8'b10010001,
        8'b10010000,
        8'b10010000,
        8'b10001111,
        8'b10001111,
        8'b10001110,
        8'b10001101,
        8'b10001101,
        8'b10001100,
        8'b10001100,
        8'b10001011,
        8'b10001010,
        8'b10001010,
        8'b10001001,
        8'b10001001,
        8'b10001000,
        8'b10000111,
        8'b10000111,
        8'b10000110,
        8'b10000110,
        8'b10000101,
        8'b10000101,
        8'b10000100,
        8'b10000100,
        8'b10000011,
        8'b10000011,
        8'b10000010,
        8'b10000010,
        8'b10000001,
        8'b10000001,
        8'b10000000
    };

    localparam logic [7:0] reciprocal_root_lut[0:95] = '{
        8'b10110101,
        8'b10110010,
        8'b10101111,
        8'b10101101,
        8'b10101010,
        8'b10101000,
        8'b10100110,
        8'b10100011,
        8'b10100001,
        8'b10011111,
        8'b10011110,
        8'b10011100,
        8'b10011010,
        8'b10011000,
        8'b10010110,
        8'b10010101,
        8'b10010011,
        8'b10010010,
        8'b10010000,
        8'b10001111,
        8'b10001110,
        8'b10001100,
        8'b10001011,
        8'b10001010,
        8'b10001000,
        8'b10000111,
        8'b10000110,
        8'b10000101,
        8'b10000100,
        8'b10000011,
        8'b10000010,
        8'b10000001,
        8'b10000000,
        8'b01111111,
        8'b01111110,
        8'b01111101,
        8'b01111100,
        8'b01111011,
        8'b01111010,
        8'b01111001,
        8'b01111000,
        8'b01110111,
        8'b01110111,
        8'b01110110,
        8'b01110101,
        8'b01110100,
        8'b01110011,
        8'b01110011,
        8'b01110010,
        8'b01110001,
        8'b01110001,
        8'b01110000,
        8'b01101111,
        8'b01101111,
        8'b01101110,
        8'b01101101,
        8'b01101101,
        8'b01101100,
        8'b01101011,
        8'b01101011,
        8'b01101010,
        8'b01101010,
        8'b01101001,
        8'b01101001,
        8'b01101000,
        8'b01100111,
        8'b01100111,
        8'b01100110,
        8'b01100110,
        8'b01100101,
        8'b01100101,
        8'b01100100,
        8'b01100100,
        8'b01100011,
        8'b01100011,
        8'b01100010,
        8'b01100010,
        8'b01100010,
        8'b01100001,
        8'b01100001,
        8'b01100000,
        8'b01100000,
        8'b01011111,
        8'b01011111,
        8'b01011111,
        8'b01011110,
        8'b01011110,
        8'b01011101,
        8'b01011101,
        8'b01011101,
        8'b01011100,
        8'b01011100,
        8'b01011011,
        8'b01011011,
        8'b01011011,
        8'b01011010
    };

    // 声明内部MAC信号
    fp_mac_in_type  fp_mac_i_int;
    fp_mac_out_type fp_mac_o_int;

    always_comb begin

        v = r;

        // 默认MAC valid为0
        fp_mac_i_int.valid = 0;

        if (r.state == 0) begin
            if (fp_fdiv_i.op.fdiv) begin
                v.state = 1;
            end
            if (fp_fdiv_i.op.fsqrt) begin
                v.state = 2;
            end
            v.istate = 0;
            v.ready  = 0;
        end else if (r.state == 1) begin
            // 浮点除法状态，只有当MAC ready时才能进入下一个istate
            if (v.istate == 10 && fp_mac_o_int.ready) begin
                v.state = 3;
            end else if (fp_mac_o_int.ready) begin
                v.istate = v.istate + 6'd1;
            end
            v.ready  = 0;
        end else if (r.state == 2) begin
            // 浮点开方状态，只有当MAC ready时才能进入下一个istate
            if (v.istate == 13 && fp_mac_o_int.ready) begin
                v.state = 3;
            end else if (fp_mac_o_int.ready) begin
                v.istate = v.istate + 6'd1;
            end
            v.ready  = 0;
        end else if (r.state == 3) begin
            v.state = 4;
            v.ready = 0;
        end else begin
            v.state = 0;
            v.ready = 1;
        end

        if (r.state == 0) begin
            v.a       = fp_fdiv_i.data1;
            v.b       = fp_fdiv_i.data2;
            v.class_a = fp_fdiv_i.class1;
            v.class_b = fp_fdiv_i.class2;
            v.fmt     = fp_fdiv_i.fmt;
            v.rm      = fp_fdiv_i.rm;
            v.snan    = 0;
            v.qnan    = 0;
            v.dbz     = 0;
            v.infs    = 0;
            v.zero    = 0;

            if (fp_fdiv_i.op.fsqrt) begin
                v.b       = 65'h07FF0000000000000;
                v.class_b = 0;
            end

            if (v.class_a[8] | v.class_b[8]) begin
                v.snan = 1;
            end else if ((v.class_a[3] | v.class_a[4]) & (v.class_b[3] | v.class_b[4])) begin
                v.snan = 1;
            end else if ((v.class_a[0] | v.class_a[7]) & (v.class_b[0] | v.class_b[7])) begin
                v.snan = 1;
            end else if (v.class_a[9] | v.class_b[9]) begin
                v.qnan = 1;
            end

            if ((v.class_a[0] | v.class_a[7]) & (v.class_b[1] | v.class_b[2] | v.class_b[3] | v.class_b[4] | v.class_b[5] | v.class_b[6])) begin
                v.infs = 1;
            end else if ((v.class_b[3] | v.class_b[4]) & (v.class_a[1] | v.class_a[2] | v.class_a[5] | v.class_a[6])) begin
                v.dbz = 1;
            end

            if ((v.class_a[3] | v.class_a[4]) | (v.class_b[0] | v.class_b[7])) begin
                v.zero = 1;
            end

            if (fp_fdiv_i.op.fsqrt) begin
                if (v.class_a[7]) begin
                    v.infs = 1;
                end
                if (v.class_a[0] | v.class_a[1] | v.class_a[2]) begin
                    v.snan = 1;
                end
            end

            v.qa            = {2'h1, v.a[51:0], 2'h0};
            v.qb            = {2'h1, v.b[51:0], 2'h0};

            v.sign_fdiv     = v.a[64] ^ v.b[64];
            v.exponent_fdiv = {2'h0, v.a[63:52]} - {2'h0, v.b[63:52]};
            v.y             = {1'h0, ~|v.b[51:45], reciprocal_lut[$unsigned(v.b[51:45])], 46'h0};
            v.op            = 0;

            if (fp_fdiv_i.op.fsqrt) begin
                v.qa = {2'h1, v.a[51:0], 2'h0};
                if (!v.a[52]) begin
                    v.qa = v.qa >> 1;
                end
                v.index         = $unsigned(v.qa[54:48]) - 7'd32;
                v.exponent_fdiv = ($signed({2'h0, v.a[63:52]}) + $signed(-14'd2045)) >>> 1;
                v.y             = {1'h0, reciprocal_root_lut[v.index], 47'h0};
                v.op            = 1;
            end

            fp_mac_i_int.a  = 0;
            fp_mac_i_int.b  = 0;
            fp_mac_i_int.c  = 0;
            fp_mac_i_int.op = 0;
        end else if (r.state == 1) begin
            // 浮点除法迭代过程
            if (r.istate == 0) begin
                // 1. 计算初始误差 e0 = 1 - B * y
                fp_mac_i_int.a  = 56'h40000000000000;
                fp_mac_i_int.b  = v.qb;
                fp_mac_i_int.c  = v.y;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1; // 启动MAC运算
                v.e0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 1) begin
                // 2. 计算 y0 = y + y * e0，牛顿法第一次修正倒数近似
                fp_mac_i_int.a  = v.y;
                fp_mac_i_int.b  = v.y;
                fp_mac_i_int.c  = v.e0;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 2) begin
                // 3. 计算 e1 = e0 * e0，误差平方
                fp_mac_i_int.a  = 56'h0;
                fp_mac_i_int.b  = v.e0;
                fp_mac_i_int.c  = v.e0;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.e1        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 3) begin
                // 4. 计算 y1 = y0 + y0 * e1，牛顿法第二次修正倒数近似
                fp_mac_i_int.a  = v.y0;
                fp_mac_i_int.b  = v.y0;
                fp_mac_i_int.c  = v.e1;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y1        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 4) begin
                // 5. 计算 e2 = e1 * e1，误差再平方
                fp_mac_i_int.a  = 56'h0;
                fp_mac_i_int.b  = v.e1;
                fp_mac_i_int.c  = v.e1;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.e2        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 5) begin
                // 6. 计算 y2 = y1 + y1 * e2，牛顿法第三次修正倒数近似
                fp_mac_i_int.a  = v.y1;
                fp_mac_i_int.b  = v.y1;
                fp_mac_i_int.c  = v.e2;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y2        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 6) begin
                // 7. 计算 q0 = A * y2，得到初步的商
                fp_mac_i_int.a  = 56'h0;
                fp_mac_i_int.b  = v.qa;
                fp_mac_i_int.c  = v.y2;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.q0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 7) begin
                // 8. 计算 r0 = A - q0 * B，计算余数
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.qb;
                fp_mac_i_int.c  = v.q0;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r0        = fp_mac_o_int.d;
            end else if (r.istate == 8) begin
                // 9. 计算 q0 = q0 + r0 * y2，修正商
                fp_mac_i_int.a  = v.q0;
                fp_mac_i_int.b  = v.r0[109:54];
                fp_mac_i_int.c  = v.y2;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.q0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 9) begin
                // 10. 计算 r1 = A - q0 * B，计算最终余数
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.qb;
                fp_mac_i_int.c  = v.q0;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r1        = fp_mac_o_int.d;
                v.q1        = v.q0;
                // 余数正则商加1
                if ($signed(v.r1[109:54]) > 0) begin
                    v.q1 = v.q1 + 1;
                end
            end else if (r.istate == 10) begin
                // 11. 再次计算 r0 = A - q1 * B，若余数为0则q0=q1
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.qb;
                fp_mac_i_int.c  = v.q1;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r0        = fp_mac_o_int.d;
                if (v.r0[109:54] == 0) begin
                    v.q0 = v.q1;
                    v.r1 = v.r0;
                end
            end else begin
                fp_mac_i_int.a  = 0;
                fp_mac_i_int.b  = 0;
                fp_mac_i_int.c  = 0;
                fp_mac_i_int.op = 0;
            end
        end else if (r.state == 2) begin
            // 浮点开方迭代过程
            if (r.istate == 0) begin
                // 1. 计算 y0 = y * A，初始近似
                fp_mac_i_int.a  = 56'h0;
                fp_mac_i_int.b  = v.qa;
                fp_mac_i_int.c  = v.y;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 1) begin
                // 2. 计算 h0 = y * 0.5，y的一半
                fp_mac_i_int.a  = 56'h0;
                fp_mac_i_int.b  = 56'h20000000000000;
                fp_mac_i_int.c  = v.y;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.h0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 2) begin
                // 3. 计算 e0 = 0.5 * h0 + y0，牛顿法第一次修正
                fp_mac_i_int.a  = 56'h20000000000000;
                fp_mac_i_int.b  = v.h0;
                fp_mac_i_int.c  = v.y0;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.e0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 3) begin
                // 4. 计算 y1 = y0 + y0 * e0，牛顿法第二次修正
                fp_mac_i_int.a  = v.y0;
                fp_mac_i_int.b  = v.y0;
                fp_mac_i_int.c  = v.e0;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y1        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 4) begin
                // 5. 计算 h1 = h0 * h0 + e0，误差平方修正
                fp_mac_i_int.a  = v.h0;
                fp_mac_i_int.b  = v.h0;
                fp_mac_i_int.c  = v.e0;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.h1        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 5) begin
                // 6. 计算 e1 = 0.5 * h1 + y1，牛顿法第三次修正
                fp_mac_i_int.a  = 56'h20000000000000;
                fp_mac_i_int.b  = v.h1;
                fp_mac_i_int.c  = v.y1;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.e1        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 6) begin
                // 7. 计算 y2 = y1 + y1 * e1，牛顿法第四次修正
                fp_mac_i_int.a  = v.y1;
                fp_mac_i_int.b  = v.y1;
                fp_mac_i_int.c  = v.e1;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y2        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 7) begin
                // 8. 计算 h2 = h1 * h1 + e1，误差平方修正
                fp_mac_i_int.a  = v.h1;
                fp_mac_i_int.b  = v.h1;
                fp_mac_i_int.c  = v.e1;
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.h2        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 8) begin
                // 9. 计算 r0 = A * y2 + y2，初步根
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.y2;
                fp_mac_i_int.c  = v.y2;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r0        = fp_mac_o_int.d;
            end else if (r.istate == 9) begin
                // 10. 计算 y3 = y2 * h2 + r0，高阶修正
                fp_mac_i_int.a  = v.y2;
                fp_mac_i_int.b  = v.h2;
                fp_mac_i_int.c  = v.r0[109:54];
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.y3        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 10) begin
                // 11. 计算 r0 = A * y3 + y3，进一步修正根
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.y3;
                fp_mac_i_int.c  = v.y3;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r0        = fp_mac_o_int.d;
            end else if (r.istate == 11) begin
                // 12. 计算 q0 = y3 * h2 + r0，最终根近似
                fp_mac_i_int.a  = v.y3;
                fp_mac_i_int.b  = v.h2;
                fp_mac_i_int.c  = v.r0[109:54];
                fp_mac_i_int.op = 0;
                fp_mac_i_int.valid = 1;
                v.q0        = fp_mac_o_int.d[109:54];
            end else if (r.istate == 12) begin
                // 13. 计算 r1 = A * q0 + q0，最终余数
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.q0;
                fp_mac_i_int.c  = v.q0;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r1        = fp_mac_o_int.d;
                v.q1        = v.q0;
                // 余数正则根加1
                if ($signed(v.r1[109:54]) > 0) begin
                    v.q1 = v.q1 + 1;
                end
            end else if (r.istate == 13) begin
                // 14. 再次计算 r0 = A * q1 + q1，若余数为0则q0=q1
                fp_mac_i_int.a  = v.qa;
                fp_mac_i_int.b  = v.q1;
                fp_mac_i_int.c  = v.q1;
                fp_mac_i_int.op = 1;
                fp_mac_i_int.valid = 1;
                v.r0        = fp_mac_o_int.d;
                if (v.r0[109:54] == 0) begin
                    v.q0 = v.q1;
                    v.r1 = v.r0;
                end
            end else begin
                fp_mac_i_int.a  = 0;
                fp_mac_i_int.b  = 0;
                fp_mac_i_int.c  = 0;
                fp_mac_i_int.op = 0;
            end
        end else if (r.state == 3) begin
            fp_mac_i_int.a      = 0;
            fp_mac_i_int.b      = 0;
            fp_mac_i_int.c      = 0;
            fp_mac_i_int.op     = 0;

            // 规格化结果尾数
            v.mantissa_fdiv = {v.q0[54:0], 59'h0};

            // 计算余数舍入信息
            v.remainder_rnd = 2;
            if ($signed(v.r1) > 0) begin
                v.remainder_rnd = 1;
            end else if (v.r1 == 0) begin
                v.remainder_rnd = 0;
            end

            // 规格化尾数最高位，若未对齐则左移并调整计数
            v.counter_fdiv = 0;
            if (v.mantissa_fdiv[113] == 0) begin
                v.mantissa_fdiv = {v.mantissa_fdiv[112:0], 1'h0};
                v.counter_fdiv  = 1;
            end
            // 开方特殊规格化处理
            if (v.op == 1) begin
                v.counter_fdiv = 1;
                if (v.mantissa_fdiv[113] == 0) begin
                    v.mantissa_fdiv = {v.mantissa_fdiv[112:0], 1'h0};
                    v.counter_fdiv  = 0;
                end
            end

            // 设置偏置值（单精度127，双精度1023）
            v.exponent_bias = 127;
            if (v.fmt == 1) begin
                v.exponent_bias = 1023;
            end

            // 计算最终符号和阶码
            v.sign_rnd     = v.sign_fdiv;
            v.exponent_rnd = v.exponent_fdiv + {3'h0, v.exponent_bias} - {12'h0, v.counter_fdiv};

            // 阶码下溢处理，尾数右移补零
            v.counter_rnd  = 0;
            if ($signed(v.exponent_rnd) <= 0) begin
                v.counter_rnd = 54;
                if ($signed(v.exponent_rnd) > -54) begin
                    v.counter_rnd = 14'h1 - v.exponent_rnd;
                end
                v.exponent_rnd = 0;
            end

            // 尾数右移，准备舍入
            v.mantissa_fdiv = v.mantissa_fdiv >> v.counter_rnd[5:0];

            // 单精度/双精度尾数与GRS位提取
            v.mantissa_rnd  = {30'h0, v.mantissa_fdiv[113:90]};
            v.grs           = {v.mantissa_fdiv[89:88], |v.mantissa_fdiv[87:0]};
            if (v.fmt == 1) begin
                v.mantissa_rnd = {1'h0, v.mantissa_fdiv[113:61]};
                v.grs          = {v.mantissa_fdiv[60:59], |v.mantissa_fdiv[58:0]};
            end

        end else begin
            // 其它状态，MAC输入清零
            fp_mac_i_int.a  = 0;
            fp_mac_i_int.b  = 0;
            fp_mac_i_int.c  = 0;
            fp_mac_i_int.op = 0;
        end

        // clear信号处理，输出ready清零
        if (clear == 1) begin
            v.ready = 0;
        end

        // 输出结构体赋值
        fp_fdiv_o.fp_rnd.sig  = v.sign_rnd;
        fp_fdiv_o.fp_rnd.expo = v.exponent_rnd;
        fp_fdiv_o.fp_rnd.mant = v.mantissa_rnd;
        fp_fdiv_o.fp_rnd.rema = v.remainder_rnd;
        fp_fdiv_o.fp_rnd.fmt  = v.fmt;
        fp_fdiv_o.fp_rnd.rm   = v.rm;
        fp_fdiv_o.fp_rnd.grs  = v.grs;
        fp_fdiv_o.fp_rnd.snan = v.snan;
        fp_fdiv_o.fp_rnd.qnan = v.qnan;
        fp_fdiv_o.fp_rnd.dbz  = v.dbz;
        fp_fdiv_o.fp_rnd.infs = v.infs;
        fp_fdiv_o.fp_rnd.zero = v.zero;
        fp_fdiv_o.fp_rnd.diff = 1'h0;
        fp_fdiv_o.ready       = v.ready;

        rin                   = v;

    end

    always_ff @(posedge clk) begin
        if (rst_n == 0) begin
            r <= init_fp_fdiv_reg_functional;
        end else begin
            r <= rin;
        end
    end

    // 实例化MAC模块
    fp_mac u_fp_mac (
        .clk   (clk),
        .rst_n (rst_n),
        .fp_mac_i (fp_mac_i_int),
        .fp_mac_o (fp_mac_o_int)
    );

endmodule
