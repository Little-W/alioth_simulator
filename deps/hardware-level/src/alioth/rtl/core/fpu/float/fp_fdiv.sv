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
//   mac_56_i/o      : MAC单元接口
//   clear           : 清除/暂停信号

import fp_types::*;

module fp_fdiv (
    input                   rst_n,
    input                   clk,
    input  fp_fdiv_in_type  fp_fdiv_i,
    output fp_fdiv_out_type fp_fdiv_o,
    input                   clear
);

    // 状态机状态定义
    typedef enum logic [4:0] {
        ST_IDLE       = 5'b00001,
        ST_FDIV_ITER  = 5'b00010,
        ST_FSQRT_ITER = 5'b00100,
        ST_NORMALIZE  = 5'b01000,
        ST_COMPLETE   = 5'b10000
    } state_t;

    // 除法迭代子状态定义
    typedef enum logic [10:0] {
        FDIV_CALC_E0     = 11'b00000000001,
        FDIV_CALC_Y0     = 11'b00000000010,
        FDIV_CALC_E1     = 11'b00000000100,
        FDIV_CALC_Y1     = 11'b00000001000,
        FDIV_CALC_E2     = 11'b00000010000,
        FDIV_CALC_Y2     = 11'b00000100000,
        FDIV_CALC_Q0     = 11'b00001000000,
        FDIV_CALC_R0     = 11'b00010000000,
        FDIV_REFINE_Q0   = 11'b00100000000,
        FDIV_CALC_R1     = 11'b01000000000,
        FDIV_FINAL_CHECK = 11'b10000000000
    } fdiv_sub_state_t;

    // 开方迭代子状态定义
    typedef enum logic [13:0] {
        FSQRT_CALC_Y0     = 14'b00000000000001,
        FSQRT_CALC_H0     = 14'b00000000000010,
        FSQRT_CALC_E0     = 14'b00000000000100,
        FSQRT_CALC_Y1     = 14'b00000000001000,
        FSQRT_CALC_H1     = 14'b00000000010000,
        FSQRT_CALC_E1     = 14'b00000000100000,
        FSQRT_CALC_Y2     = 14'b00000001000000,
        FSQRT_CALC_H2     = 14'b00000010000000,
        FSQRT_CALC_R0     = 14'b00000100000000,
        FSQRT_CALC_Y3     = 14'b00001000000000,
        FSQRT_REFINE_R0   = 14'b00010000000000,
        FSQRT_CALC_Q0     = 14'b00100000000000,
        FSQRT_CALC_R1     = 14'b01000000000000,
        FSQRT_FINAL_CHECK = 14'b10000000000000
    } fsqrt_sub_state_t;

    // 寄存器结构体
    fp_fdiv_reg_functional_type current_state_reg, next_state_reg;

    // 状态机状态寄存器
    state_t current_main_state, next_main_state;
    fdiv_sub_state_t current_fdiv_sub_state, next_fdiv_sub_state;
    fsqrt_sub_state_t current_fsqrt_sub_state, next_fsqrt_sub_state;

    // MAC接口信号
    mac_56_in_type  mac_input_signals;
    mac_56_out_type mac_output_signals;

    // 查找表定义
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

    // 主状态机状态转换逻辑（）
    always_comb begin
        next_main_state      = current_main_state;
        next_fdiv_sub_state  = current_fdiv_sub_state;
        next_fsqrt_sub_state = current_fsqrt_sub_state;

        case (current_main_state)
            ST_IDLE: begin
                if (fp_fdiv_i.op.fdiv) begin
                    next_main_state     = ST_FDIV_ITER;
                    next_fdiv_sub_state = FDIV_CALC_E0;
                end else if (fp_fdiv_i.op.fsqrt) begin
                    next_main_state      = ST_FSQRT_ITER;
                    next_fsqrt_sub_state = FSQRT_CALC_Y0;
                end
            end

            ST_FDIV_ITER: begin
                if (mac_output_signals.ready) begin
                    case (current_fdiv_sub_state)
                        FDIV_CALC_E0:   next_fdiv_sub_state = FDIV_CALC_Y0;
                        FDIV_CALC_Y0:   next_fdiv_sub_state = FDIV_CALC_E1;
                        FDIV_CALC_E1:   next_fdiv_sub_state = FDIV_CALC_Y1;
                        FDIV_CALC_Y1:   next_fdiv_sub_state = FDIV_CALC_E2;
                        FDIV_CALC_E2:   next_fdiv_sub_state = FDIV_CALC_Y2;
                        FDIV_CALC_Y2:   next_fdiv_sub_state = FDIV_CALC_Q0;
                        FDIV_CALC_Q0:   next_fdiv_sub_state = FDIV_CALC_R0;
                        FDIV_CALC_R0:   next_fdiv_sub_state = FDIV_REFINE_Q0;
                        FDIV_REFINE_Q0: next_fdiv_sub_state = FDIV_CALC_R1;
                        FDIV_CALC_R1:   next_fdiv_sub_state = FDIV_FINAL_CHECK;
                        FDIV_FINAL_CHECK: begin
                            next_main_state     = ST_NORMALIZE;
                            next_fdiv_sub_state = FDIV_CALC_E0;
                        end
                        default:        next_fdiv_sub_state = FDIV_CALC_E0;
                    endcase
                end
            end

            ST_FSQRT_ITER: begin
                if (mac_output_signals.ready) begin
                    case (current_fsqrt_sub_state)
                        FSQRT_CALC_Y0:   next_fsqrt_sub_state = FSQRT_CALC_H0;
                        FSQRT_CALC_H0:   next_fsqrt_sub_state = FSQRT_CALC_E0;
                        FSQRT_CALC_E0:   next_fsqrt_sub_state = FSQRT_CALC_Y1;
                        FSQRT_CALC_Y1:   next_fsqrt_sub_state = FSQRT_CALC_H1;
                        FSQRT_CALC_H1:   next_fsqrt_sub_state = FSQRT_CALC_E1;
                        FSQRT_CALC_E1:   next_fsqrt_sub_state = FSQRT_CALC_Y2;
                        FSQRT_CALC_Y2:   next_fsqrt_sub_state = FSQRT_CALC_H2;
                        FSQRT_CALC_H2:   next_fsqrt_sub_state = FSQRT_CALC_R0;
                        FSQRT_CALC_R0:   next_fsqrt_sub_state = FSQRT_CALC_Y3;
                        FSQRT_CALC_Y3:   next_fsqrt_sub_state = FSQRT_REFINE_R0;
                        FSQRT_REFINE_R0: next_fsqrt_sub_state = FSQRT_CALC_Q0;
                        FSQRT_CALC_Q0:   next_fsqrt_sub_state = FSQRT_CALC_R1;
                        FSQRT_CALC_R1:   next_fsqrt_sub_state = FSQRT_FINAL_CHECK;
                        FSQRT_FINAL_CHECK: begin
                            next_main_state      = ST_NORMALIZE;
                            next_fsqrt_sub_state = FSQRT_CALC_Y0;
                        end
                        default:         next_fsqrt_sub_state = FSQRT_CALC_Y0;
                    endcase
                end
            end

            ST_NORMALIZE: begin
                next_main_state = ST_COMPLETE;
            end

            ST_COMPLETE: begin
                next_main_state = ST_IDLE;
            end

            default: begin
                next_main_state = ST_IDLE;
            end
        endcase

        // clear信号处理
        if (clear) begin
            next_main_state      = ST_IDLE;
            next_fdiv_sub_state  = FDIV_CALC_E0;
            next_fsqrt_sub_state = FSQRT_CALC_Y0;
        end
    end

    // 组合逻辑：数据处理和MAC控制
    always_comb begin
        next_state_reg          = current_state_reg;

        // 默认MAC控制信号
        mac_input_signals.valid = 1'b0;
        mac_input_signals.a     = 56'h0;
        mac_input_signals.b     = 56'h0;
        mac_input_signals.c     = 56'h0;
        mac_input_signals.op    = 1'b0;

        case (current_main_state)
            ST_IDLE: begin
                // 初始化输入数据
                next_state_reg.a       = fp_fdiv_i.data1;
                next_state_reg.b       = fp_fdiv_i.data2;
                next_state_reg.class_a = fp_fdiv_i.class1;
                next_state_reg.class_b = fp_fdiv_i.class2;
                next_state_reg.fmt     = fp_fdiv_i.fmt;
                next_state_reg.rm      = fp_fdiv_i.rm;
                next_state_reg.ready   = 1'b0;

                // 清除异常标志
                next_state_reg.snan    = 1'b0;
                next_state_reg.qnan    = 1'b0;
                next_state_reg.dbz     = 1'b0;
                next_state_reg.infs    = 1'b0;
                next_state_reg.zero    = 1'b0;

                // 开方操作的特殊处理
                if (fp_fdiv_i.op.fsqrt) begin
                    next_state_reg.b       = 65'h07FF0000000000000;
                    next_state_reg.class_b = 10'h0;
                end

                // 异常检测逻辑
                if (next_state_reg.class_a[8] | next_state_reg.class_b[8]) begin
                    next_state_reg.snan = 1'b1;
                end else if ((next_state_reg.class_a[3] | next_state_reg.class_a[4]) & 
                           (next_state_reg.class_b[3] | next_state_reg.class_b[4])) begin
                    next_state_reg.snan = 1'b1;
                end else if ((next_state_reg.class_a[0] | next_state_reg.class_a[7]) & 
                           (next_state_reg.class_b[0] | next_state_reg.class_b[7])) begin
                    next_state_reg.snan = 1'b1;
                end else if (next_state_reg.class_a[9] | next_state_reg.class_b[9]) begin
                    next_state_reg.qnan = 1'b1;
                end

                // 无穷大和除零检测
                if ((next_state_reg.class_a[0] | next_state_reg.class_a[7]) & 
                    (next_state_reg.class_b[1] | next_state_reg.class_b[2] | next_state_reg.class_b[3] | 
                     next_state_reg.class_b[4] | next_state_reg.class_b[5] | next_state_reg.class_b[6])) begin
                    next_state_reg.infs = 1'b1;
                end else if ((next_state_reg.class_b[3] | next_state_reg.class_b[4]) & 
                           (next_state_reg.class_a[1] | next_state_reg.class_a[2] | 
                            next_state_reg.class_a[5] | next_state_reg.class_a[6])) begin
                    next_state_reg.dbz = 1'b1;
                end

                // 零结果检测
                if ((next_state_reg.class_a[3] | next_state_reg.class_a[4]) | 
                    (next_state_reg.class_b[0] | next_state_reg.class_b[7])) begin
                    next_state_reg.zero = 1'b1;
                end

                // 开方特殊异常检测
                if (fp_fdiv_i.op.fsqrt) begin
                    if (next_state_reg.class_a[7]) begin
                        next_state_reg.infs = 1'b1;
                    end
                    if (next_state_reg.class_a[0] | next_state_reg.class_a[1] | next_state_reg.class_a[2]) begin
                        next_state_reg.snan = 1'b1;
                    end
                end

                // 准备尾数计算
                next_state_reg.qa = {2'h1, next_state_reg.a[51:0], 2'h0};
                next_state_reg.qb = {2'h1, next_state_reg.b[51:0], 2'h0};

                // 符号和指数计算
                next_state_reg.sign_fdiv = next_state_reg.a[64] ^ next_state_reg.b[64];
                next_state_reg.exponent_fdiv = {2'h0, next_state_reg.a[63:52]} - {2'h0, next_state_reg.b[63:52]};

                // 初始倒数近似
                next_state_reg.y = {
                    1'h0,
                    ~|next_state_reg.b[51:45],
                    reciprocal_lut[$unsigned(next_state_reg.b[51:45])],
                    46'h0
                };
                next_state_reg.op = 1'b0;

                // 开方的特殊初始化
                if (fp_fdiv_i.op.fsqrt) begin
                    next_state_reg.qa = {2'h1, next_state_reg.a[51:0], 2'h0};
                    if (!next_state_reg.a[52]) begin
                        next_state_reg.qa = next_state_reg.qa >> 1;
                    end
                    next_state_reg.index = $unsigned(next_state_reg.qa[54:48]) - 7'd32;
                    next_state_reg.exponent_fdiv = ($signed({2'h0, next_state_reg.a[63:52]}) +
                                                    $signed(-14'd2045)) >>> 1;
                    next_state_reg.y = {1'h0, reciprocal_root_lut[next_state_reg.index], 47'h0};
                    next_state_reg.op = 1'b1;
                end
            end

            ST_FDIV_ITER: begin
                mac_input_signals.valid = 1'b1;
                case (current_fdiv_sub_state)
                    FDIV_CALC_E0: begin
                        // 计算 e0 = 1 - B * y
                        mac_input_signals.a  = 56'h40000000000000;
                        mac_input_signals.b  = current_state_reg.qb;
                        mac_input_signals.c  = current_state_reg.y;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.e0    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_Y0: begin
                        // 计算 y0 = y + y * e0
                        mac_input_signals.a  = current_state_reg.y;
                        mac_input_signals.b  = current_state_reg.y;
                        mac_input_signals.c  = current_state_reg.e0;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y0    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_E1: begin
                        // 计算 e1 = e0 * e0
                        mac_input_signals.a  = 56'h0;
                        mac_input_signals.b  = current_state_reg.e0;
                        mac_input_signals.c  = current_state_reg.e0;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.e1    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_Y1: begin
                        // 计算 y1 = y0 + y0 * e1
                        mac_input_signals.a  = current_state_reg.y0;
                        mac_input_signals.b  = current_state_reg.y0;
                        mac_input_signals.c  = current_state_reg.e1;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y1    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_E2: begin
                        // 计算 e2 = e1 * e1
                        mac_input_signals.a  = 56'h0;
                        mac_input_signals.b  = current_state_reg.e1;
                        mac_input_signals.c  = current_state_reg.e1;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.e2    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_Y2: begin
                        // 计算 y2 = y1 + y1 * e2
                        mac_input_signals.a  = current_state_reg.y1;
                        mac_input_signals.b  = current_state_reg.y1;
                        mac_input_signals.c  = current_state_reg.e2;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y2    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_Q0: begin
                        // 计算 q0 = A * y2
                        mac_input_signals.a  = 56'h0;
                        mac_input_signals.b  = current_state_reg.qa;
                        mac_input_signals.c  = current_state_reg.y2;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.q0    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_R0: begin
                        // 计算 r0 = A - q0 * B
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.qb;
                        mac_input_signals.c  = current_state_reg.q0;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r0    = mac_output_signals.d;
                    end
                    FDIV_REFINE_Q0: begin
                        // 修正 q0 = q0 + r0 * y2
                        mac_input_signals.a  = current_state_reg.q0;
                        mac_input_signals.b  = current_state_reg.r0[109:54];
                        mac_input_signals.c  = current_state_reg.y2;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.q0    = mac_output_signals.d[109:54];
                    end
                    FDIV_CALC_R1: begin
                        // 计算 r1 = A - q0 * B
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.qb;
                        mac_input_signals.c  = current_state_reg.q0;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r1    = mac_output_signals.d;
                        next_state_reg.q1    = current_state_reg.q0;
                        if ($signed(mac_output_signals.d[109:54]) > 0) begin
                            next_state_reg.q1 = current_state_reg.q0 + 1;
                        end
                    end
                    FDIV_FINAL_CHECK: begin
                        // 最终检查 r0 = A - q1 * B
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.qb;
                        mac_input_signals.c  = current_state_reg.q1;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r0    = mac_output_signals.d;
                        if (mac_output_signals.d[109:54] == 0) begin
                            next_state_reg.q0 = current_state_reg.q1;
                            next_state_reg.r1 = mac_output_signals.d;
                        end
                    end

                    default: begin
                        mac_input_signals.valid = 1'b0;
                    end
                endcase
            end

            ST_FSQRT_ITER: begin
                mac_input_signals.valid = 1'b1;
                case (current_fsqrt_sub_state)
                    FSQRT_CALC_Y0: begin
                        // 计算 y0 = y * A
                        mac_input_signals.a  = 56'h0;
                        mac_input_signals.b  = current_state_reg.qa;
                        mac_input_signals.c  = current_state_reg.y;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y0    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_H0: begin
                        // 计算 h0 = y * 0.5
                        mac_input_signals.a  = 56'h0;
                        mac_input_signals.b  = 56'h20000000000000;
                        mac_input_signals.c  = current_state_reg.y;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.h0    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_E0: begin
                        // 计算 e0 = 0.5 * h0 + y0
                        mac_input_signals.a  = 56'h20000000000000;
                        mac_input_signals.b  = current_state_reg.h0;
                        mac_input_signals.c  = current_state_reg.y0;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.e0    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_Y1: begin
                        // 计算 y1 = y0 + y0 * e0
                        mac_input_signals.a  = current_state_reg.y0;
                        mac_input_signals.b  = current_state_reg.y0;
                        mac_input_signals.c  = current_state_reg.e0;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y1    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_H1: begin
                        // 计算 h1 = h0 * h0 + e0
                        mac_input_signals.a  = current_state_reg.h0;
                        mac_input_signals.b  = current_state_reg.h0;
                        mac_input_signals.c  = current_state_reg.e0;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.h1    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_E1: begin
                        // 计算 e1 = 0.5 * h1 + y1
                        mac_input_signals.a  = 56'h20000000000000;
                        mac_input_signals.b  = current_state_reg.h1;
                        mac_input_signals.c  = current_state_reg.y1;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.e1    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_Y2: begin
                        // 计算 y2 = y1 + y1 * e1
                        mac_input_signals.a  = current_state_reg.y1;
                        mac_input_signals.b  = current_state_reg.y1;
                        mac_input_signals.c  = current_state_reg.e1;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y2    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_H2: begin
                        // 计算 h2 = h1 * h1 + e1
                        mac_input_signals.a  = current_state_reg.h1;
                        mac_input_signals.b  = current_state_reg.h1;
                        mac_input_signals.c  = current_state_reg.e1;
                        mac_input_signals.op = 1'b0;
                        next_state_reg.h2    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_R0: begin
                        // 计算 r0 = A * y2 + y2
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.y2;
                        mac_input_signals.c  = current_state_reg.y2;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r0    = mac_output_signals.d;
                    end
                    FSQRT_CALC_Y3: begin
                        // 计算 y3 = y2 * h2 + r0
                        mac_input_signals.a  = current_state_reg.y2;
                        mac_input_signals.b  = current_state_reg.h2;
                        mac_input_signals.c  = current_state_reg.r0[109:54];
                        mac_input_signals.op = 1'b0;
                        next_state_reg.y3    = mac_output_signals.d[109:54];
                    end
                    FSQRT_REFINE_R0: begin
                        // 修正 r0 = A * y3 + y3
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.y3;
                        mac_input_signals.c  = current_state_reg.y3;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r0    = mac_output_signals.d;
                    end
                    FSQRT_CALC_Q0: begin
                        // 计算 q0 = y3 * h2 + r0
                        mac_input_signals.a  = current_state_reg.y3;
                        mac_input_signals.b  = current_state_reg.h2;
                        mac_input_signals.c  = current_state_reg.r0[109:54];
                        mac_input_signals.op = 1'b0;
                        next_state_reg.q0    = mac_output_signals.d[109:54];
                    end
                    FSQRT_CALC_R1: begin
                        // 计算 r1 = A * q0 + q0
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.q0;
                        mac_input_signals.c  = current_state_reg.q0;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r1    = mac_output_signals.d;
                        next_state_reg.q1    = current_state_reg.q0;
                        if ($signed(mac_output_signals.d[109:54]) > 0) begin
                            next_state_reg.q1 = current_state_reg.q0 + 1;
                        end
                    end
                    FSQRT_FINAL_CHECK: begin
                        // 最终检查 r0 = A * q1 + q1
                        mac_input_signals.a  = current_state_reg.qa;
                        mac_input_signals.b  = current_state_reg.q1;
                        mac_input_signals.c  = current_state_reg.q1;
                        mac_input_signals.op = 1'b1;
                        next_state_reg.r0    = mac_output_signals.d;
                        if (mac_output_signals.d[109:54] == 0) begin
                            next_state_reg.q0 = current_state_reg.q1;
                            next_state_reg.r1 = mac_output_signals.d;
                        end
                    end

                    default: begin
                        mac_input_signals.valid = 1'b0;
                    end
                endcase
            end

            ST_NORMALIZE: begin
                // 规格化结果尾数
                next_state_reg.mantissa_fdiv = {current_state_reg.q0[54:0], 59'h0};

                // 计算余数舍入信息
                next_state_reg.remainder_rnd = 2;
                if ($signed(current_state_reg.r1) > 0) begin
                    next_state_reg.remainder_rnd = 1;
                end else if (current_state_reg.r1 == 0) begin
                    next_state_reg.remainder_rnd = 0;
                end

                // 规格化尾数最高位
                next_state_reg.counter_fdiv = 0;
                if (next_state_reg.mantissa_fdiv[113] == 0) begin
                    next_state_reg.mantissa_fdiv = {next_state_reg.mantissa_fdiv[112:0], 1'h0};
                    next_state_reg.counter_fdiv  = 1;
                end

                // 开方特殊规格化处理
                if (current_state_reg.op == 1) begin
                    next_state_reg.counter_fdiv = 1;
                    if (next_state_reg.mantissa_fdiv[113] == 0) begin
                        next_state_reg.mantissa_fdiv = {next_state_reg.mantissa_fdiv[112:0], 1'h0};
                        next_state_reg.counter_fdiv  = 0;
                    end
                end

                // 设置指数偏置值
                next_state_reg.exponent_bias = (current_state_reg.fmt == 1) ? 1023 : 127;

                // 计算最终符号和指数
                next_state_reg.sign_rnd = current_state_reg.sign_fdiv;
                next_state_reg.exponent_rnd = current_state_reg.exponent_fdiv + {3'h0, next_state_reg.exponent_bias} - {12'h0, next_state_reg.counter_fdiv};

                // 指数下溢处理
                next_state_reg.counter_rnd = 0;
                if ($signed(next_state_reg.exponent_rnd) <= 0) begin
                    next_state_reg.counter_rnd = 54;
                    if ($signed(next_state_reg.exponent_rnd) > -54) begin
                        next_state_reg.counter_rnd = 14'h1 - next_state_reg.exponent_rnd;
                    end
                    next_state_reg.exponent_rnd = 0;
                end

                // 尾数右移准备舍入
                next_state_reg.mantissa_fdiv = next_state_reg.mantissa_fdiv >> next_state_reg.counter_rnd[5:0];

                // 提取尾数和GRS位
                if (current_state_reg.fmt == 1) begin
                    // 双精度
                    next_state_reg.mantissa_rnd = {1'h0, next_state_reg.mantissa_fdiv[113:61]};
                    next_state_reg.grs = {
                        next_state_reg.mantissa_fdiv[60:59], |next_state_reg.mantissa_fdiv[58:0]
                    };
                end else begin
                    // 单精度
                    next_state_reg.mantissa_rnd = {30'h0, next_state_reg.mantissa_fdiv[113:90]};
                    next_state_reg.grs = {
                        next_state_reg.mantissa_fdiv[89:88], |next_state_reg.mantissa_fdiv[87:0]
                    };
                end
            end

            ST_COMPLETE: begin
                next_state_reg.ready = 1'b1;
            end

            default: begin
                // 默认状态处理
            end
        endcase
    end

    // 输出信号赋值
    always_comb begin
        fp_fdiv_o.fp_rnd.sig  = current_state_reg.sign_rnd;
        fp_fdiv_o.fp_rnd.expo = current_state_reg.exponent_rnd;
        fp_fdiv_o.fp_rnd.mant = current_state_reg.mantissa_rnd;
        fp_fdiv_o.fp_rnd.rema = current_state_reg.remainder_rnd;
        fp_fdiv_o.fp_rnd.fmt  = current_state_reg.fmt;
        fp_fdiv_o.fp_rnd.rm   = current_state_reg.rm;
        fp_fdiv_o.fp_rnd.grs  = current_state_reg.grs;
        fp_fdiv_o.fp_rnd.snan = current_state_reg.snan;
        fp_fdiv_o.fp_rnd.qnan = current_state_reg.qnan;
        fp_fdiv_o.fp_rnd.dbz  = current_state_reg.dbz;
        fp_fdiv_o.fp_rnd.infs = current_state_reg.infs;
        fp_fdiv_o.fp_rnd.zero = current_state_reg.zero;
        fp_fdiv_o.fp_rnd.diff = 1'h0;
        fp_fdiv_o.ready       = current_state_reg.ready;
    end

    // 时序逻辑：寄存器更新
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            current_state_reg       <= init_fp_fdiv_reg_functional;
            current_main_state      <= ST_IDLE;
            current_fdiv_sub_state  <= FDIV_CALC_E0;
            current_fsqrt_sub_state <= FSQRT_CALC_Y0;
        end else begin
            current_state_reg       <= next_state_reg;
            current_main_state      <= next_main_state;
            current_fdiv_sub_state  <= next_fdiv_sub_state;
            current_fsqrt_sub_state <= next_fsqrt_sub_state;
        end
    end

    // MAC模块实例化
    mac_56 #(
        .LATENCY_LEVEL(3)
    ) u_mac_56 (
        .clk     (clk),
        .rst_n   (rst_n),
        .mac_56_i(mac_input_signals),
        .mac_56_o(mac_output_signals)
    );

endmodule
