// MAC（乘累加）模块
// 实现定点数的乘法和加法/减法累加操作，支持有符号数运算。
//
// LATENCY_LEVEL 参数说明：
//   0：多周期结构，乘法器为4个mul_32并行，输出延迟为4个周期（乘法3周期+加法1周期）
//   1：32位乘法器用乘号，输入寄存一级，输出延迟为3个周期（乘法2周期+加法1周期）
//   2：直接用64位乘法器，输出延迟为2个周期(乘法1个周期，累加1个周期)
//   3：纯组合逻辑+一级输出寄存器，输出延迟为1个周期
//   4：纯组合逻辑，输出无时序延迟，ready恒为1
//
import fp_types::*;

module mac_56 #(
    parameter LATENCY_LEVEL = 0  // 0-3: 通过mul_64参数, 4: 纯组合
) (
    input                  clk,
    input                  rst_n,
    input  mac_56_in_type  mac_56_i,
    output mac_56_out_type mac_56_o
);
    timeunit 1ns; timeprecision 1ps;

    generate
        if (LATENCY_LEVEL == 4) begin : gen_mac_comb
            // 纯组合逻辑
            wire [ 55:0] a = mac_56_i.a;
            wire [ 55:0] b = mac_56_i.b;
            wire [ 55:0] c = mac_56_i.c;
            wire         op = mac_56_i.op;
            wire [111:0] mul_result = $signed(b) * $signed(c);
            wire [109:0] add = {a, 54'h0};
            wire [109:0] mac = (op == 0) ? mul_result[109:0] : -mul_result[109:0];
            wire [109:0] res = (a == 0) ? mac : (add + mac);

            assign mac_56_o.d     = res;
            assign mac_56_o.ready = 1'b1;
        end else if (LATENCY_LEVEL == 3) begin : gen_mac_comb_reg
            // 乘法后寄存，加法为组合逻辑
            wire [ 55:0] a = mac_56_i.a;
            wire [ 55:0] b = mac_56_i.b;
            wire [ 55:0] c = mac_56_i.c;
            wire         op = mac_56_i.op;
            wire         valid = mac_56_i.valid;

            wire [111:0] mul_result_wire = $signed(b) * $signed(c);

            logic [111:0] mul_result_reg;
            logic [55:0]  a_reg;
            logic         op_reg;
            logic         valid_reg;

            // 乘法结果寄存
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    mul_result_reg <= 0;
                    a_reg          <= 0;
                    op_reg         <= 0;
                    valid_reg      <= 0;
                end else if (valid & !valid_reg) begin
                    mul_result_reg <= mul_result_wire;
                    a_reg          <= a;
                    op_reg         <= op;
                    valid_reg      <= 1'b1;
                end else begin
                    valid_reg      <= 1'b0;
                end
            end

            // 加法为组合逻辑
            wire [109:0] add = {a_reg, 54'h0};
            wire [109:0] mac = (op_reg == 0) ? mul_result_reg[109:0] : -mul_result_reg[109:0];
            wire [109:0] res = (a_reg == 0) ? mac : (add + mac);

            assign mac_56_o.d     = res;
            assign mac_56_o.ready = valid_reg;
        end else begin : gen_mac_seq
            // 状态机定义
            typedef enum logic [1:0] {
                IDLE,
                MUL,
                ADD,
                OUT
            } state_t;
            state_t state, state_n;

            // 输入寄存器
            logic [55:0] a_reg;
            logic op_reg;
            logic valid_reg;

            // mul_64接口信号
            logic mul_start;
            logic [55:0] mul_a, mul_b;
            logic [128:0] mul_result_full;
            logic [111:0] mul_result;
            logic         mul_valid;

            // 加法相关
            logic [109:0] add;
            logic [109:0] mac;
            logic [109:0] res;
            logic [109:0] res_reg;

            // 输出ready信号
            logic         ready_reg;

            assign mul_result = mul_result_full[111:0];

            // 输入锁存
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    a_reg     <= 0;
                    op_reg    <= 0;
                    valid_reg <= 0;
                end else if (mac_56_i.valid && state == IDLE) begin
                    a_reg     <= mac_56_i.a;
                    op_reg    <= mac_56_i.op;
                    valid_reg <= mac_56_i.valid;
                end
            end

            // 状态转移
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) state <= IDLE;
                else state <= state_n;
            end

            always_comb begin
                state_n = state;
                case (state)
                    IDLE: if (mac_56_i.valid) state_n = MUL;
                    MUL:
                    if (mul_valid) begin
                        if (a_reg == 0) state_n = OUT;
                        else state_n = ADD;
                    end
                    ADD:  state_n = OUT;
                    OUT:  state_n = IDLE;
                endcase
            end

            // mul_64输入控制
            assign mul_a     = mac_56_i.b;
            assign mul_b     = mac_56_i.c;
            assign mul_start = (state == IDLE && mac_56_i.valid);

            // mul_64实例化
            mul_64 #(
                .SIGNED       (1),
                .WIDTH        (56),
                .LATENCY_LEVEL(LATENCY_LEVEL)
            ) u_mul_64 (
                .clk     (clk),
                .rst_n   (rst_n),
                .start_i (mul_start),
                .a_i     (mul_a),
                .b_i     (mul_b),
                .result_o(mul_result_full),
                .valid_o (mul_valid)
            );

            // 加法与累加
            assign add = {a_reg, 54'h0};
            assign mac = (op_reg == 0) ? mul_result[109:0] : -mul_result[109:0];
            assign res = add + mac;

            // 输出寄存器
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    res_reg   <= 0;
                    ready_reg <= 0;
                end else begin
                    if (state == MUL && mul_valid && a_reg == 0) begin
                        // a_reg为0时直接输出乘法结果
                        res_reg   <= mac;
                        ready_reg <= 1'b1;
                    end else if (state == ADD) begin
                        res_reg   <= res;
                        ready_reg <= 1'b1;
                    end else begin
                        ready_reg <= 1'b0;
                    end
                end
            end

            assign mac_56_o.d     = res_reg;
            assign mac_56_o.ready = ready_reg;
        end
    endgenerate

endmodule
