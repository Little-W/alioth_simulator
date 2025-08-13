module lzc_4 (
    input  [3:0] data_in,
    output [1:0] lzc,
    output       valid
);
    timeunit 1ns; timeprecision 1ps;

    /*
     * LZC编码格式说明：
     * 输入data_in[3:0]对应位权重从高到低：bit3, bit2, bit1, bit0
     *
     * 编码逻辑：找到最高位的1所在位置，输出其位置编码
     * 编码表：
     * data_in[3:0] | 最高位1的位置 | lzc[1:0] | valid
     * 1xxx         | 位置3        | 11       | 1
     * 01xx         | 位置2        | 10       | 1
     * 001x         | 位置1        | 01       | 1
     * 0001         | 位置0        | 00       | 1
     * 0000         | 无1          | xx       | 0
     *
     * 注意：lzc[1:0]是位置的二进制编码，不是前导零的数量
     */

    // 输入位3
    logic bit3_input;
    // 输入位2
    logic bit2_input;
    // 输入位1
    logic bit1_input;
    // 输入位0
    logic bit0_input;
    // 高2位非零
    logic upper_half_nonzero;
    // 低2位非零
    logic lower_half_nonzero;
    // 任意一位非零
    logic overall_nonzero;
    // 计数第0位选择器
    logic bit0_selector;
    // 计数第0位最终值
    logic bit0_final;

    assign bit0_input         = data_in[0];
    assign bit1_input         = data_in[1];
    assign bit2_input         = data_in[2];
    assign bit3_input         = data_in[3];

    // 编码逻辑分解：
    // lzc[1]: 检测高2位(bit3,bit2)是否有1
    assign upper_half_nonzero = bit3_input | bit2_input;
    // lzc[0]: 当高2位无1时，检测bit1；当高2位有1时，检测bit3
    assign lower_half_nonzero = bit1_input | bit0_input;
    assign overall_nonzero    = lower_half_nonzero | upper_half_nonzero;
    assign bit0_selector      = (~upper_half_nonzero) & bit1_input;  // 低2位中的最高位
    assign bit0_final         = bit3_input | bit0_selector;  // 整体的奇数位选择

    assign valid              = overall_nonzero;
    // lzc输出为优先编码（binary encoding），不是直接的前导零数量。
    assign lzc[0]             = bit0_final;  // 位置编码的LSB
    assign lzc[1]             = upper_half_nonzero;  // 位置编码的MSB

endmodule
