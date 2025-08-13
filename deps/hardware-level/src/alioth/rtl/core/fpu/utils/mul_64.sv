/*
 64x64多周期乘法器，分块实例化4个mul_32
 输出级带一级寄存器
*/

module mul_64 #(
    parameter SIGNED = 0,  // 0:无符号乘法, 1:有符号乘法
    parameter WIDTH  = 64  // 输入数据实际位宽
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start_i,
    input  wire [WIDTH-1:0] a_i,
    input  wire [WIDTH-1:0] b_i,
    output wire [    127:0] result_o,
    output wire             valid_o
);

    // 输入符号扩展或零扩展到64位
    wire [63:0] a_ext = SIGNED ? {{(64-WIDTH){a_i[WIDTH-1]}}, a_i} : {{(64-WIDTH){1'b0}}, a_i};
    wire [63:0] b_ext = SIGNED ? {{(64-WIDTH){b_i[WIDTH-1]}}, b_i} : {{(64-WIDTH){1'b0}}, b_i};

    // 保留正确的符号位提取
    wire a_neg = SIGNED ? a_i[WIDTH-1] : 1'b0;  // 使用WIDTH-1而不是固定的63
    wire b_neg = SIGNED ? b_i[WIDTH-1] : 1'b0;  // 使用WIDTH-1而不是固定的63

    // 输入绝对值处理
    wire [63:0] a_abs = SIGNED ? (a_neg ? (~a_ext + 1'b1) : a_ext) : a_ext;
    wire [63:0] b_abs = SIGNED ? (b_neg ? (~b_ext + 1'b1) : b_ext) : b_ext;

    // 拆分输入
    wire [31:0] a_lo = a_abs[31:0];
    wire [31:0] a_hi = a_abs[63:32];
    wire [31:0] b_lo = b_abs[31:0];
    wire [31:0] b_hi = b_abs[63:32];

    // 4个32x32乘法器输出
    wire [63:0] p_ll, p_lh, p_hl, p_hh;
    wire v_ll, v_lh, v_hl, v_hh;

    // 4个mul_32实例（只支持无符号）
    mul_32 u_mul_ll (
        .clk     (clk),
        .rst_n   (rst_n),
        .start_i (start_i),
        .a_i     (a_lo),
        .b_i     (b_lo),
        .result_o(p_ll),
        .valid_o (v_ll)
    );
    mul_32 u_mul_lh (
        .clk     (clk),
        .rst_n   (rst_n),
        .start_i (start_i),
        .a_i     (a_lo),
        .b_i     (b_hi),
        .result_o(p_lh),
        .valid_o (v_lh)
    );
    mul_32 u_mul_hl (
        .clk     (clk),
        .rst_n   (rst_n),
        .start_i (start_i),
        .a_i     (a_hi),
        .b_i     (b_lo),
        .result_o(p_hl),
        .valid_o (v_hl)
    );
    mul_32 u_mul_hh (
        .clk     (clk),
        .rst_n   (rst_n),
        .start_i (start_i),
        .a_i     (a_hi),
        .b_i     (b_hi),
        .result_o(p_hh),
        .valid_o (v_hh)
    );

    // 有效信号同步
    wire valid_all = v_ll & v_lh & v_hl & v_hh;

    // 结果组合
    wire [127:0] unsigned_result =
        {p_hh, 64'b0} +
        ({32'b0, p_lh} << 32) +
        ({32'b0, p_hl} << 32) +
        {64'b0, p_ll};

    // 输出寄存器
    reg [127:0] result_r;
    reg valid_r;

    // 符号还原相关信号
    reg result_neg_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            result_r     <= 0;
            valid_r      <= 1'b0;
            result_neg_r <= 1'b0;
        end else begin
            if (start_i) begin
                result_neg_r <= SIGNED ? (a_neg ^ b_neg) : 1'b0;
            end
            if (valid_all) begin
                result_r <= result_neg_r ? (~unsigned_result + 1'b1) : unsigned_result;
                valid_r  <= 1'b1;
            end else begin
                valid_r <= 1'b0;
            end
        end
    end

    assign result_o = result_r;
    assign valid_o  = valid_r;

endmodule
