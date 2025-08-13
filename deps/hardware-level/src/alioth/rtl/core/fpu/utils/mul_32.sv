/*
 32x32多周期无符号乘法器，分块实现
*/

module mul_32 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_i,
    input  wire [31:0] a_i,
    input  wire [31:0] b_i,
    output wire [63:0] result_o,
    output reg         valid_o
);

    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        CALC   = 2'b01
    } state_t;

    state_t state, next_state;

    reg [31:0] a_reg, b_reg;
    reg [31:0] mul_blk [0:3]; // 4个16x16分块乘法结果

    wire [15:0] a_low  = a_reg[15:0];
    wire [15:0] a_high = a_reg[31:16];
    wire [15:0] b_low  = b_reg[15:0];
    wire [15:0] b_high = b_reg[31:16];

    // 状态机
    always @(*) begin
        case (state)
            IDLE:   next_state = start_i ? CALC : IDLE;
            CALC:   next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            a_reg    <= 0;
            b_reg    <= 0;
            mul_blk[0] <= 0;
            mul_blk[1] <= 0;
            mul_blk[2] <= 0;
            mul_blk[3] <= 0;
            valid_o  <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid_o <= 1'b0;
                    if (start_i) begin
                        a_reg <= a_i;
                        b_reg <= b_i;
                    end
                end
                CALC: begin
                    valid_o <= 1'b1;
                    // 一次性计算4个分块乘法结果
                    mul_blk[0] <= a_low  * b_low;
                    mul_blk[1] <= a_high * b_low;
                    mul_blk[2] <= a_low  * b_high;
                    mul_blk[3] <= a_high * b_high;
                end
            endcase
        end
    end

    // 组合逻辑输出
    assign result_o = {32'b0, mul_blk[0]} +
                      ({16'b0, mul_blk[1], 16'b0}) +
                      ({16'b0, mul_blk[2], 16'b0}) +
                      ({mul_blk[3], 32'b0});

endmodule