// 浮点乘加（FMA）模块
// 实现浮点数的乘加、加法、减法、乘法等操作，支持多种IEEE 754格式
// 支持异常处理（NaN、无穷、零、无效操作等），并进行规格化、对齐、舍入等处理
//
// 端口说明：
//   rst_n, clk      : 时钟与复位
//   fp_fma_i        : 输入操作数及控制信号
//   fp_fma_o        : 输出结果及标志
//   clear           : 清除/暂停信号

import fp_types::*;

module fp_fma (
    input                  clk,
    input                  rst_n,
    input  fp_fma_in_type  fp_fma_i,
    output fp_fma_out_type fp_fma_o,
    input                  clear
);
    timeunit 1ns; timeprecision 1ps;

    // 状态机状态定义
    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        MUL_START = 3'b001,
        MUL_WAIT  = 3'b010,
        ADD       = 3'b011,
        LZC_READ  = 3'b100,
        LZC_CALC  = 3'b101,
        OUTPUT    = 3'b110
    } state_t;

    state_t current_state, next_state;

    // 输入参数寄存器
    fp_fma_in_type    input_reg;

    // 中间计算结果寄存器
    fp_fma_var_type_1 stage1_reg;
    fp_fma_var_type_2 stage2_reg;

    // 乘法器相关信号
    logic             mul_start;
    logic [52:0] mul_a, mul_b;
    logic [127:0] mul_result_full;
    logic [105:0] mul_result;
    logic         mul_valid;

    // LZC相关信号
    logic [255:0] lzc_data_in;
    logic [  7:0] lzc_count;
    logic         lzc_valid;
    logic [  7:0] lzc_count_reg;

    // 操作有效信号
    logic         op_valid;
    logic         is_add_sub_only, is_add_sub_only_reg;
    assign op_valid = fp_fma_i.op.fmadd | fp_fma_i.op.fmsub | fp_fma_i.op.fnmsub |
                      fp_fma_i.op.fnmadd | fp_fma_i.op.fadd | fp_fma_i.op.fsub | fp_fma_i.op.fmul;
    assign is_add_sub_only = fp_fma_i.op.fadd | fp_fma_i.op.fsub;

    assign mul_result = mul_result_full[105:0];  // 取乘法器结果的低106位
    assign lzc_data_in = {stage2_reg.mantissa_mac[162:0], {93{1'b1}}};
    // 实例化LZC模块
    lzc_256 lzc_256 (
        .data_in(lzc_data_in),
        .lzc    (lzc_count),
        .valid  (lzc_valid)
    );

    // 实例化53位乘法器
    mul_64 #(
        .LATENCY_LEVEL(0),
        .SIGNED       (0),
        .WIDTH        (53)
    ) u_mul_64 (
        .clk     (clk),
        .rst_n   (rst_n),
        .start_i (mul_start),
        .a_i     (mul_a),
        .b_i     (mul_b),
        .result_o(mul_result_full),
        .valid_o (mul_valid)
    );

    // 状态机时序逻辑
    always_ff @(posedge clk) begin
        if (rst_n == 0) begin
            current_state <= IDLE;
            input_reg     <= '0;
            stage1_reg    <= '0;
            stage2_reg    <= '0;
            mul_start     <= 1'b0;
            lzc_count_reg <= '0;
            is_add_sub_only_reg <= 1'b0;
        end else if (clear) begin
            current_state <= IDLE;
            input_reg     <= '0;
            stage1_reg    <= '0;
            stage2_reg    <= '0;
            mul_start     <= 1'b0;
            lzc_count_reg <= '0;
            is_add_sub_only_reg <= 1'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    mul_start <= 1'b0;
                    if (op_valid) begin
                        input_reg <= fp_fma_i;
                        is_add_sub_only_reg <= is_add_sub_only;
                    end
                end

                MUL_START: begin
                    stage1_reg <= stage1_prep(input_reg);
                    // 只有非纯加减法操作才启动乘法器
                    if (!is_add_sub_only_reg) begin
                        mul_start <= 1'b1;
                    end
                end

                MUL_WAIT: begin
                    mul_start <= 1'b0;
                    if (mul_valid) begin
                        stage1_reg <= stage1_calc(stage1_reg, mul_result);
                    end
                end

                ADD: begin
                    mul_start  <= 1'b0;
                    stage2_reg <= stage2_calc_part1(stage1_reg);
                end

                LZC_READ: begin
                    lzc_count_reg <= lzc_count;
                end

                LZC_CALC: begin
                    stage2_reg <= stage2_calc_part2(stage2_reg, lzc_count_reg, clear);
                end

                OUTPUT: begin
                    // 保持输出一个周期
                end

                default: ;
            endcase
        end
    end

    // 状态机组合逻辑
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (op_valid) begin
                    next_state = MUL_START;
                end
            end

            MUL_START: begin
                // 纯加减法直接跳转到ADD状态
                if (is_add_sub_only_reg) begin
                    next_state = ADD;
                end else begin
                    next_state = MUL_WAIT;
                end
            end

            MUL_WAIT: begin
                if (mul_valid) begin
                    next_state = ADD;
                end
            end

            ADD: begin
                next_state = LZC_READ;
            end

            LZC_READ: begin
                next_state = LZC_CALC;
            end

            LZC_CALC: begin
                next_state = OUTPUT;
            end

            OUTPUT: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase

        if (clear) begin
            next_state = IDLE;
        end
    end

    // 乘法器输入连接 - 使用预处理后的mantissa
    assign mul_a = stage1_reg.mantissa_a;
    assign mul_b = stage1_reg.mantissa_b;

    // 第一阶段预处理函数 - 准备乘法器输入
    function fp_fma_var_type_1 stage1_prep(input fp_fma_in_type input_reg_i);
        fp_fma_var_type_1         tmp;
        logic             [105:0] simulated_mul_result;

        // 输入解包
        tmp.a       = input_reg_i.data1;
        tmp.b       = input_reg_i.data2;
        tmp.c       = input_reg_i.data3;
        tmp.class_a = input_reg_i.class1;
        tmp.class_b = input_reg_i.class2;
        tmp.class_c = input_reg_i.class3;
        tmp.fmt     = input_reg_i.fmt;
        tmp.rm      = input_reg_i.rm;
        tmp.snan    = 0;
        tmp.qnan    = 0;
        tmp.dbz     = 0;
        tmp.infs    = 0;
        tmp.zero    = 0;
        tmp.ready   = 1;

        // 加法/减法特殊处理
        if (input_reg_i.op.fadd | input_reg_i.op.fsub) begin
            tmp.c       = tmp.b;
            tmp.class_c = tmp.class_b;
            tmp.b       = 65'h07FF0000000000000;
            tmp.class_b = 10'h040;
        end

        // 乘法特殊处理
        if (input_reg_i.op.fmul) begin
            tmp.c       = {tmp.a[64] ^ tmp.b[64], 64'h0000000000000000};
            tmp.class_c = 0;
        end

        // 拆解符号、指数、尾数，准备乘法器输入
        tmp.sign_a = tmp.a[64];
        tmp.exponent_a = tmp.a[63:52];
        tmp.mantissa_a = {|tmp.exponent_a, tmp.a[51:0]};  // 浮点隐含位处理

        tmp.sign_b = tmp.b[64];
        tmp.exponent_b = tmp.b[63:52];
        tmp.mantissa_b = {|tmp.exponent_b, tmp.b[51:0]};

        tmp.sign_c = tmp.c[64];
        tmp.exponent_c = tmp.c[63:52];
        tmp.mantissa_c = {|tmp.exponent_c, tmp.c[51:0]};

        // 计算符号
        tmp.sign_add = tmp.sign_c ^ (input_reg_i.op.fmsub | input_reg_i.op.fnmadd | input_reg_i.op.fsub);
        tmp.sign_mul = (tmp.sign_a ^ tmp.sign_b) ^ (input_reg_i.op.fnmsub | input_reg_i.op.fnmadd);

        // 异常判断
        if (tmp.class_a[8] | tmp.class_b[8] | tmp.class_c[8]) begin
            tmp.snan = 1;
        end else if (((tmp.class_a[3] | tmp.class_a[4]) & (tmp.class_b[0] | tmp.class_b[7])) | 
                     ((tmp.class_b[3] | tmp.class_b[4]) & (tmp.class_a[0] | tmp.class_a[7]))) begin
            tmp.snan = 1;
        end else if (tmp.class_a[9] | tmp.class_b[9] | tmp.class_c[9]) begin
            tmp.qnan = 1;
        end else if (((tmp.class_a[0] | tmp.class_a[7]) | (tmp.class_b[0] | tmp.class_b[7])) & 
                     ((tmp.class_c[0] | tmp.class_c[7]) & (tmp.sign_add != tmp.sign_mul))) begin
            tmp.snan = 1;
        end else if ((tmp.class_a[0] | tmp.class_a[7]) | (tmp.class_b[0] | tmp.class_b[7]) | 
                     (tmp.class_c[0] | tmp.class_c[7])) begin
            tmp.infs = 1;
        end

        // 指数计算
        tmp.exponent_add = $signed({2'h0, tmp.exponent_c});
        tmp.exponent_mul = $signed({2'h0, tmp.exponent_a}) + $signed({2'h0, tmp.exponent_b}) -
            14'd2047;

        if (&tmp.exponent_c) tmp.exponent_add = 14'h0FFF;
        if (&tmp.exponent_a | &tmp.exponent_b) tmp.exponent_mul = 14'h0FFF;

        // 准备mantissa_add
        tmp.mantissa_add[163:161] = 0;
        tmp.mantissa_add[160:108] = tmp.mantissa_c;
        tmp.mantissa_add[107:0]   = 0;

        // 对于纯加减法，直接模拟乘法结果并调用stage1_calc
        if (input_reg_i.op.fadd | input_reg_i.op.fsub) begin
            // 设置模拟的乘法结果为扩展后的a的尾数
            simulated_mul_result = {tmp.mantissa_a, 52'h0};
            tmp                  = stage1_calc(tmp, simulated_mul_result);
        end

        return tmp;
    endfunction

    // 第一阶段计算函数 - 使用乘法器结果
    function fp_fma_var_type_1 stage1_calc(input fp_fma_var_type_1 stage1_reg_i,
                                           input logic [105:0] mul_result_i);
        fp_fma_var_type_1 tmp;

        // 复制预处理结果
        tmp                       = stage1_reg_i;

        // 使用乘法器结果计算mantissa_mul
        tmp.mantissa_mul[163:162] = 0;
        tmp.mantissa_mul[161:56]  = mul_result_i;
        tmp.mantissa_mul[55:0]    = 0;

        // 对齐计算
        tmp.exponent_dif          = $signed(tmp.exponent_mul) - $signed(tmp.exponent_add);
        tmp.exponent_neg          = tmp.exponent_dif[13];

        // 尾数对齐，左/右对齐
        if (tmp.exponent_neg) begin
            tmp.counter_dif = 56;
            if ($signed(tmp.exponent_dif) > -56) begin
                tmp.counter_dif = -tmp.exponent_dif[6:0];
            end
            tmp.mantissa_l = tmp.mantissa_add;
            tmp.mantissa_r = tmp.mantissa_mul;
        end else begin
            tmp.counter_dif = 108;
            if ($signed(tmp.exponent_dif) < 108) begin
                tmp.counter_dif = tmp.exponent_dif[6:0];
            end
            tmp.mantissa_l = tmp.mantissa_mul;
            tmp.mantissa_r = tmp.mantissa_add;
        end

        // 右侧尾数移位对齐
        tmp.mantissa_r = tmp.mantissa_r >> tmp.counter_dif;

        // 重新分配尾数，便于后续加法
        if (tmp.exponent_neg) begin
            tmp.mantissa_add = tmp.mantissa_l;
            tmp.mantissa_mul = tmp.mantissa_r;
        end else begin
            tmp.mantissa_add = tmp.mantissa_r;
            tmp.mantissa_mul = tmp.mantissa_l;
        end

        return tmp;
    endfunction

    // 第二阶段计算函数 - 第一部分（计算mantissa_mac）
    function fp_fma_var_type_2 stage2_calc_part1(input fp_fma_var_type_1 stage1_reg_i);
        fp_fma_var_type_2 tmp;

        // 从第一阶段结果复制数据
        tmp.fmt          = stage1_reg_i.fmt;
        tmp.rm           = stage1_reg_i.rm;
        tmp.snan         = stage1_reg_i.snan;
        tmp.qnan         = stage1_reg_i.qnan;
        tmp.dbz          = stage1_reg_i.dbz;
        tmp.infs         = stage1_reg_i.infs;
        tmp.zero         = stage1_reg_i.zero;
        tmp.sign_mul     = stage1_reg_i.sign_mul;
        tmp.exponent_mul = stage1_reg_i.exponent_mul;
        tmp.mantissa_mul = stage1_reg_i.mantissa_mul;
        tmp.sign_add     = stage1_reg_i.sign_add;
        tmp.exponent_add = stage1_reg_i.exponent_add;
        tmp.mantissa_add = stage1_reg_i.mantissa_add;
        tmp.exponent_neg = stage1_reg_i.exponent_neg;
        tmp.ready        = stage1_reg_i.ready;

        if (tmp.exponent_neg) begin
            tmp.exponent_mac = tmp.exponent_add;
        end else begin
            tmp.exponent_mac = tmp.exponent_mul;
        end

        if (tmp.sign_add) begin
            tmp.mantissa_add = ~tmp.mantissa_add;
        end
        if (tmp.sign_mul) begin
            tmp.mantissa_mul = ~tmp.mantissa_mul;
        end

        tmp.mantissa_mac = tmp.mantissa_add + tmp.mantissa_mul + {163'h0,tmp.sign_add} + {163'h0,tmp.sign_mul};
        tmp.sign_mac = tmp.mantissa_mac[163];

        tmp.zero = ~|tmp.mantissa_mac;

        if (tmp.zero) begin
            tmp.sign_mac = tmp.sign_add & tmp.sign_mul;
        end else if (tmp.sign_mac) begin
            tmp.mantissa_mac = -tmp.mantissa_mac;
        end

        tmp.diff = tmp.sign_add ^ tmp.sign_mul;

        return tmp;
    endfunction

    // 第二阶段计算函数 - 第二部分（使用LZC结果）
    function fp_fma_var_type_2 stage2_calc_part2(
        input fp_fma_var_type_2 stage2_reg_i, input logic [7:0] lzc_count_i, input logic clear_i);
        fp_fma_var_type_2 tmp;

        // 复制第一部分结果
        tmp      = stage2_reg_i;

        tmp.bias = 1918;
        if (tmp.fmt == 1) begin
            tmp.bias = 1022;
        end

        tmp.counter_mac  = ~lzc_count_i;  // 计算前导零个数
        tmp.mantissa_mac = tmp.mantissa_mac << tmp.counter_mac;

        tmp.sign_rnd     = tmp.sign_mac;
        tmp.exponent_rnd = tmp.exponent_mac - {3'h0, tmp.bias} - {6'h0, tmp.counter_mac};

        tmp.counter_sub  = 0;
        if ($signed(tmp.exponent_rnd) <= 0) begin
            tmp.counter_sub = 63;
            if ($signed(tmp.exponent_rnd) > -63) begin
                tmp.counter_sub = 14'h1 - tmp.exponent_rnd;
            end
            tmp.exponent_rnd = 0;
        end

        tmp.mantissa_mac = tmp.mantissa_mac >> tmp.counter_sub[5:0];

        tmp.mantissa_rnd = {30'h0, tmp.mantissa_mac[162:139]};
        tmp.grs          = {tmp.mantissa_mac[138:137], |tmp.mantissa_mac[136:0]};
        if (tmp.fmt == 1) begin
            tmp.mantissa_rnd = {1'h0, tmp.mantissa_mac[162:110]};
            tmp.grs          = {tmp.mantissa_mac[109:108], |tmp.mantissa_mac[107:0]};
        end

        if (clear_i == 1) begin
            tmp.ready = 0;
        end

        return tmp;
    endfunction

    // 输出逻辑
    always_comb begin
        fp_fma_o = '0;

        if (current_state == OUTPUT) begin
            fp_fma_o.fp_rnd.sig  = stage2_reg.sign_rnd;
            fp_fma_o.fp_rnd.expo = stage2_reg.exponent_rnd;
            fp_fma_o.fp_rnd.mant = stage2_reg.mantissa_rnd;
            fp_fma_o.fp_rnd.rema = 2'h0;
            fp_fma_o.fp_rnd.fmt  = stage2_reg.fmt;
            fp_fma_o.fp_rnd.rm   = stage2_reg.rm;
            fp_fma_o.fp_rnd.grs  = stage2_reg.grs;
            fp_fma_o.fp_rnd.snan = stage2_reg.snan;
            fp_fma_o.fp_rnd.qnan = stage2_reg.qnan;
            fp_fma_o.fp_rnd.dbz  = stage2_reg.dbz;
            fp_fma_o.fp_rnd.infs = stage2_reg.infs;
            fp_fma_o.fp_rnd.zero = stage2_reg.zero;
            fp_fma_o.fp_rnd.diff = stage2_reg.diff;
            fp_fma_o.ready       = stage2_reg.ready;
        end
    end

endmodule
