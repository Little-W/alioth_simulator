// 浮点比较模块
// 实现浮点数的大小、等于等关系比较，支持异常（NaN等）处理
//
// 端口说明：
//   fp_cmp_i : 输入结构体，包含两个操作数及控制信号
//   fp_cmp_o : 输出结构体，包含比较结果和异常标志

import fp_types::*;

module fp_cmp (
    input                  clk,
    input                  rst_n,
    input  fp_cmp_in_type  fp_cmp_i,  // 输入：包含两个浮点操作数及控制信号
    output fp_cmp_out_type fp_cmp_o   // 输出：比较结果和异常标志
);
    timeunit 1ns; timeprecision 1ps;

    // 定义内部变量
    logic [64:0] data1;  // 扩展的第一个操作数（含符号位）
    logic [64:0] data2;  // 扩展的第二个操作数（含符号位）
    logic [ 2:0] rm;  // 比较操作类型（0: fle, 1: flt, 2: feq）
    logic [ 9:0] class1;  // 第一个操作数的类别（如NaN、无穷等）
    logic [ 9:0] class2;  // 第二个操作数的类别

    logic        comp_lt;  // 小于比较结果
    logic        comp_le;  // 小于等于比较结果
    logic [63:0] result;  // 比较结果输出
    logic [ 4:0] flags;  // 异常标志输出

    always_comb begin

        // 输入信号赋值到内部变量
        data1   = fp_cmp_i.data1;
        data2   = fp_cmp_i.data2;
        rm      = fp_cmp_i.rm;
        class1  = fp_cmp_i.class1;
        class2  = fp_cmp_i.class2;

        // 初始化比较结果和异常标志
        comp_lt = 0;
        comp_le = 0;
        result  = 0;
        flags   = 0;

        // 仅在rm为0/1/2时进行比较
        if ((rm == 0) || (rm == 1) || (rm == 2)) begin
            // 直接对64位数据进行无符号比较
            comp_lt = (data1[63:0] < data2[63:0]) ? 1'b1 : 1'b0;
            comp_le = (data1[63:0] <= data2[63:0]) ? 1'b1 : 1'b0;
        end

        // feq: 浮点等于比较
        if (rm == 2) begin
            // 若任一操作数为信号NaN，设置invalid flag
            if ((class1[8] | class2[8]) == 1) begin
                flags[4] = 1;
                // 若任一操作数为quiet NaN，结果为0
            end else if ((class1[9] | class2[9]) == 1) begin
                flags[0] = 0;
                // 若均为无穷大且符号相同，结果为1
            end else if (((class1[3] | class1[4]) & (class2[3] | class2[4])) == 1) begin
                result[0] = 1;
                // 其余情况下，数据完全相等则结果为1
            end else if (data1 == data2) begin
                result[0] = 1;
            end
        end  // flt: 浮点小于比较
        else if (rm == 1) begin
            // 若有NaN，设置invalid flag
            if ((class1[8] | class2[8] | class1[9] | class2[9]) == 1) begin
                flags[4] = 1;
                // 均为无穷大，结果为0
            end else if (((class1[3] | class1[4]) & (class2[3] | class2[4])) == 1) begin
                result[0] = 0;
                // 符号不同，结果为data1的符号位
            end else if ((data1[64] ^ data2[64]) == 1) begin
                result[0] = data1[64];
            end else begin
                // 同号时，负数取反小于等于，正数直接用小于
                if (data1[64] == 1) begin
                    result[0] = ~comp_le;
                end else begin
                    result[0] = comp_lt;
                end
            end
        end  // fle: 浮点小于等于比较
        else if (rm == 0) begin
            // 若有NaN，设置invalid flag
            if ((class1[8] | class2[8] | class1[9] | class2[9]) == 1) begin
                flags[4] = 1;
                // 均为无穷大，结果为1
            end else if (((class1[3] | class1[4]) & (class2[3] | class2[4])) == 1) begin
                result[0] = 1;
                // 符号不同，结果为data1的符号位
            end else if ((data1[64] ^ data2[64]) == 1) begin
                result[0] = data1[64];
            end else begin
                // 正数直接用小于等于，负数取反小于
                if (data1[64] == 0) begin
                    result[0] = comp_le;
                end else begin
                    result[0] = ~comp_lt;
                end
            end
        end

        // 输出赋值
        fp_cmp_o.result = result;
        fp_cmp_o.flags  = flags;

    end

endmodule
