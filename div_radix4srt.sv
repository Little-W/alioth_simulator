/*         
 The MIT License (MIT)

 Copyright © 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
                                                                         
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
                                                                         
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "defines.svh"

// -----------------------------------------------------------------------------
// Radix-4 SRT 除法模块（与原 div 模块端口/风格一致）
// - 支持 DIV/DIVU/REM/REMU
// - 采用冗余商位累积 + PLA 选商（q ∈ {-2,-1,0,+1,+2}）
// - 每次主循环生成 2 位商（N/2 次迭代；N 为 32 时为 16 次；若 N 为奇数，最后一次单移）
// -----------------------------------------------------------------------------
module div_radix4 (
    input  wire                        clk,
    input  wire                        rst_n,

    // from ex
    input  wire [`REG_DATA_WIDTH-1:0]  dividend_i,   // 被除数 x
    input  wire [`REG_DATA_WIDTH-1:0]  divisor_i,    // 除数   y
    input  wire                        start_i,      // 开始信号（沿用触发）
    input  wire                        ctrl_ready_i, // 控制器就绪
    input  wire [3:0]                  op_i,         // 操作类型：{remu, rem, divu, div}

    // to ex
    output reg  [`REG_DATA_WIDTH-1:0]  result_o,     // 结果（根据 op 输出商或余数）
    output reg                         busy_o,
    output reg                         valid_o
);

    // =========================
    // 状态机
    // =========================
    typedef enum logic [3:0] {
        STATE_IDLE  = 4'b0001,
        STATE_START = 4'b0010,
        STATE_CALC  = 4'b0100,
        STATE_END   = 4'b1000
    } state_t;

    state_t state;

    // =========================
    // 操作类型快捷信号
    reg  [3:0] op_r;
    wire op_div  = op_r[0];
    wire op_divu = op_r[1];
    wire op_rem  = op_r[2];
    wire op_remu = op_r[3];

    wire signed_mode = (op_div | op_rem); // 有符号模式

    // =========================
    // 数据寄存
    //x为被除数，y为除数
    // =========================
    localparam N = `REG_DATA_WIDTH;      // 32
    // 绝对值/符号
    reg  [N-1:0] x_r, y_r;               // 
    wire [N-1:0] x_abs = (signed_mode & x_r[N-1]) ? -x_r : x_r;
    wire [N-1:0] y_abs = (signed_mode & y_r[N-1]) ? -y_r : y_r;
    wire         opp_sign = signed_mode & (x_r[N-1] ^ y_r[N-1]); // 商是否为负

    // =========================
    // SRT 内部寄存/信号
    // =========================
    // 累积“部分余数 + 冗余商”拼接寄存器（carry-save 形式）
    // rxqReg[2N-1:N] 为部分余数窗口，rxqReg[N-1:0] 为冗余商
    reg  [2*N+2:0] rxqReg;     // 主寄存器（sum 用时与 cReg 同宽对齐）
    reg  [N+2:0]   cReg;       // carry-save 的进位寄存器
    reg  [N-1:0]   yShiftReg;  // 对齐后的 |y|（左移）
    reg  [N-1:0]   qnReg;      // q 的补码/冗余编码轨（用于“从旧低位接”）

    reg  [$clog2(N)-1:0] counter;
    wire [$clog2(N)-1:0] iter_target = (N/2) + (N%2); // N 为奇数时多一次“单移”
    // yAbs 的规格化移位（数最高位零的个数）
    wire [$clog2(N)-1:0] shiftY;
    zeroMSBCounter #(N) u_zmsb
    // 数最高位零的个数
    (   
        .x(y_abs), 
        .out(shiftY)
    );

    // “带符号移位”的 x 预装载（将 |x| 左移 shiftY 后送入 rxqReg 高侧）
    wire [2*N+2:0] rx_init = x_abs << shiftY; // 对齐到位：落在 [2N+2:N] 区间

    // 选商所需的加/减候选（carry-save） s是部分余数，c是进位
    wire [N+2:0] sa, ca, ss, cs, sa2, ca2, ss2, cs2;
    wire [N+2:0] sa1, ca1, ss1, cs1; // N 为奇数时用（单移）
    // 基于你提供的 csAddSubGen 模块生成
    // 主路径（每次移 2 位）
    csAddSubGen #(N+3) u_add  
        ( 
          .sub(1'b0), 
          .x(rxqReg[2*N   : N-2]), 
          .y({3'b000, yShiftReg}),       
          .cin({cReg[N:0],2'b00}), 
          .s(sa),  
          .c(ca)  
          );

    csAddSubGen #(N+3) u_sub  
        ( 
          .sub(1'b1), 
          .x(rxqReg[2*N   : N-2]), 
          .y({3'b000, yShiftReg}),      
          .cin({cReg[N:0],2'b00}), 
          .s(ss),  
          .c(cs)  
        );
        
    csAddSubGen #(N+3) u_add2  
        ( 
          .sub(1'b0), 
          .x(rxqReg[2*N   : N-2]), 
          .y({2'b0,  yShiftReg, 1'b0}),  
          .cin({cReg[N:0],2'b00}), 
          .s(sa2), 
          .c(ca2) 
        );
    csAddSubGen #(N+3) u_sub2  
        (
          .sub(1'b1), 
          .x(rxqReg[2*N   : N-2]), 
          .y({2'b0,  yShiftReg, 1'b0}),  
          .cin({cReg[N:0],2'b00}), 
          .s(ss2), 
          .c(cs2) 
        );
    // 奇数位宽时的“单移”候选
    csAddSubGen #(N+3) u_add1  
        ( 
          .sub(1'b0), 
          .x({rxqReg[2*N+1: N-1]}), 
          .y({3'b000, yShiftReg}),  
          .cin({cReg[N+1:0],1'b0}), 
          .s(sa1), 
          .c(ca1) 
        );
    csAddSubGen #(N+3) u_sub1  
        (
          .sub(1'b1), 
          .x({rxqReg[2*N+1: N-1]}), 
          .y({3'b000, yShiftReg}),  
          .cin({cReg[N+1:0],1'b0}), 
          .s(ss1), 
          .c(cs1) 
        );

    // 选商输入 r6：取（部分余数+carry）的高位窗口，先做 8 位“脉 carry”得到 6 位 r6
    wire [N+2:0] sum     = rxqReg[2*N+2:N] + {cReg[N+2:0]}; // 真值窗口（带符号）
    wire [7:0]   r8      = rxqReg[2*N:2*N-7] + cReg[N:N-7];
    wire [5:0]   r6      = r8[7:2];                         // r6[5] 为符号位
    // 选商 LUT：输入 r 的幅值（负号用一补近似）与 y 的最高 4 位
    wire [1:0] qcode; //商位combine编码
    qSelPLAPos u_qsel 
    (
        .r5( r6[5] ? ~r6[4:0] : r6[4:0] ),
        .y4( yShiftReg[N-1:N-4] ),
        .q2( qcode )                         // 00->0, 01->1, 10->2
    );
    wire q_sign = r6[5] & (qcode != 2'b00);  // 负区且非 0

    // 结束阶段需要的归一余数（非负），以及最终“多一步回退”选择
    wire [N-1:0] nonNegRemainder =
        sum[N+2] ? N'((sum + {3'b000, yShiftReg}) >> shiftY) : N'(sum >> shiftY);

    // =========================
    // 其它
    // =========================
    reg  busy_r;
    reg  valid_r;
    assign /* verilator lint_off UNUSED */ busy_o  = busy_r;
    assign /* verilator lint_off UNUSED */ valid_o = valid_r;

    // =========================
    // 时序逻辑
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            op_r      <= 4'h0;
            x_r       <= `ZeroWord;
            y_r       <= `ZeroWord;
            result_o  <= `ZeroWord;
            busy_r    <= 1'b0;
            valid_r   <= 1'b0;

            rxqReg    <= '0;
            cReg      <= '0;
            yShiftReg <= '0;
            qnReg     <= '0;
            counter   <= '0;
        end else begin
            case (state)
            // -----------------------
            STATE_IDLE: begin
                valid_r <= 1'b0;
                if (ctrl_ready_i) begin
                    if (start_i) begin
                        op_r   <= op_i;
                        x_r    <= dividend_i;
                        y_r    <= divisor_i;
                        busy_r <= 1'b1;
                        state  <= STATE_START;
                    end else begin
                        op_r     <= 4'h0;
                        x_r      <= `ZeroWord;
                        y_r      <= `ZeroWord;
                        result_o <= `ZeroWord;
                        busy_r   <= 1'b0;
                    end
                end
            end
            // -----------------------
            STATE_START: begin
                valid_r <= 1'b0;

                // 除数为 0
                if (y_r == `ZeroWord) begin
                    if (op_div | op_divu) result_o <= 32'hffff_ffff;
                    else                   result_o <= x_r;
                    busy_r  <= 1'b0;
                    valid_r <= 1'b1;
                    state   <= STATE_IDLE;
                end
                // |x| < |y| 直接返回
                else if ( (signed_mode ? (x_abs < y_abs) : (x_r < y_r)) ) begin
                    if (op_div | op_divu) result_o <= 32'b0;
                    else                   result_o <= x_r;
                    busy_r  <= 1'b0;
                    valid_r <= 1'b1;
                    state   <= STATE_IDLE;
                end
                // |y| == 1：商为 ±|x|，余数为 0/或符号修正
                else if (y_abs == {{(N-1){1'b0}},1'b1}) begin
                    if (op_div | op_divu) begin
                        result_o <= opp_sign ? -x_abs : x_abs;
                    end else begin
                        result_o <= 32'b0;
                    end
                    busy_r  <= 1'b0;
                    valid_r <= 1'b1;
                    state   <= STATE_IDLE;
                end
                else begin
                    // 初始化 SRT 寄存
                    yShiftReg <= (y_abs << shiftY);
                    rxqReg    <= rx_init;  // |x| 左移后放入高侧窗口
                    cReg      <= '0;
                    qnReg     <= '0;
                    counter   <= '0;
                    state     <= STATE_CALC;
                end
            end

            // -----------------------

            STATE_CALC: begin
                // 终止：完成所有迭代（N 偶：N/2 次；N 奇：N/2+1 次）
                if (counter == iter_target) begin
                    // 余数窗口归一化到 [0, |y|)（一步回退）
                    // 注意：此时 nonNegRemainder 为非负幅值
                    rxqReg[2*N-1:N] <= (nonNegRemainder >= y_abs) ? (nonNegRemainder - y_abs) : nonNegRemainder;

                    // 商修正：opp_sign 时取反（toward-zero 纠正），并加上回退“借位”影响
                    // sum[N+2] == 1 表示最终部分余数为负，需要 +1 做 toward-zero 修正
                    // 再加上一步回退产生的 +1（当 nonNegRemainder >= yAbs）
                    if (opp_sign)
                        rxqReg[N-1:0] <= sum[N+2] - rxqReg[N-1:0] + (nonNegRemainder >= y_abs);
                    else
                        rxqReg[N-1:0] <= rxqReg[N-1:0] - sum[N+2] + (nonNegRemainder >= y_abs);

                    // 转入 END 输出阶段
                    state   <= STATE_END;
                end
                
                // 奇数位宽的倒数第二次迭代（单移 1 位）
                else if ( (counter == (N/2)) && (N%2==1) ) begin
                    case ({q_sign, qcode})
                        3'b000: begin // +0
                            rxqReg <= {rxqReg[2*N+1:0], 1'b0};
                            cReg   <= {cReg[N+1:0],1'b0};
                            qnReg  <= {qnReg[N-2:0], 1'b1}; // “从旧低位接”
                        end
                        3'b001: begin
                            rxqReg <= {ss1, rxqReg[N-2:0], 1'b0};
                            cReg   <=  cs1;
                            qnReg  <= {rxqReg[N-2:0], 1'b1}; // “从旧低位接”
                        end// -1
                        3'b010: begin // +1（幅值相同，差号）
                            rxqReg <= {ss1, rxqReg[N-2:0], 1'b1};
                            cReg   <=  cs1;
                            qnReg  <= {rxqReg[N-2:0], 1'b0};
                        end
                        3'b101: begin// -2
                            rxqReg <= {sa1, qnReg[N-2:0], 1'b0};
                            cReg   <=  ca1;
                            qnReg  <= {qnReg[N-2:0], 1'b1};
                        end
                        3'b110: begin // +2
                            rxqReg <= {sa1, qnReg[N-2:0], 1'b1};
                            cReg   <=  ca1;
                            qnReg  <= {qnReg[N-2:0], 1'b0};
                        end
                
                    endcase
                    state <= STATE_CALC; // 继续迭代
                    counter <= counter + 1'b1;
                end
                // 常规每次移 2 位
                else begin
                    case ({q_sign, qcode})
                        3'b000: begin // +0
                            rxqReg <= {rxqReg[2*N:0], 2'b00};
                            cReg   <= {cReg[N:0],  2'b00};
                            qnReg  <= {qnReg[N-3:0], 2'b11}; // “从旧低位接”
                        end
                        3'b001: begin // -1
                            rxqReg <= {ss, rxqReg[N-3:0], 2'b01};
                            cReg   <=  cs;
                            qnReg  <= {rxqReg[N-3:0], 2'b00};
                        end
                        3'b010: begin // +1
                            rxqReg <= {ss2, rxqReg[N-3:0], 2'b10};
                            cReg   <=  cs2;
                            qnReg  <= {rxqReg[N-3:0], 2'b01};
                        end
                        3'b101: begin // -2
                            rxqReg <= {sa, qnReg[N-3:0], 2'b11};
                            cReg   <=  ca;
                            qnReg  <= {qnReg[N-3:0], 2'b10};
                        end
                        3'b110: begin // +2
                            rxqReg <= {sa2, qnReg[N-3:0], 2'b10};
                            cReg   <=  ca2;
                            qnReg  <= {qnReg[N-3:0], 2'b01};
                        end
                        
                    endcase
                    state <= STATE_CALC; // 继续迭代
                    counter <= counter + 1'b1;
                end
            end

            // -----------------------
            // END（根据 op 输出商或余数）
            // -----------------------
            STATE_END: begin
                // 取最终商/余数（此时 rxqReg[N-1:0] 为修正后的商）
                // 余数：对有符号运算，余数应与被除数符号一致
                // 这里我们已有 nonNegRemainder 的非负幅值；若 x 为负且为有符号，取相反数
                // 注意：上一步已经做了一步回退，保证 |r| < |y|
                // 重新计算便于清晰（组合等价）
                // sum[N+2] 仅用于商修正，这里不再参与
                begin : OUT_SEL
                    reg [N-1:0] q_final;
                    
                    reg [N-1:0] r_final; 

                    q_final = rxqReg[N-1:0];
                    
                    r_final = rxqReg[2*N-1:N];

                    if (op_div | op_divu)
                        result_o <= q_final;
                    else if (op_rem | op_remu) begin
                        if (signed_mode && x_r[N-1]) begin
                            // 有符号余数：若 x 为负，取相反数
                            result_o <= -r_final;
                        end else begin
                            // 无符号余数或有符号正余数
                            result_o <= r_final;
                        end
                end
                end
                busy_r  <= 1'b0;
                valid_r <= 1'b1;
                state   <= STATE_IDLE;
            end

            default: begin
                state <= STATE_IDLE;
            end
            endcase
        end
    end

endmodule




//-----// -----------------------------------------------------------------------------
//例化模块
module qSelPLAPos //q的商位combine编码
(
    input logic [4 : 0] r5,//余数高五位
    input logic [3 : 0] y4,//除数高四位
    // output logic [1 : 0] q2 // quotient digit, 2 bits
    // 00: 0, 01: 1, 10: 2
    output logic [1 : 0] q2 // magnitude of quotient digit 
);

always_comb
begin

    case ({y4, r5})
        // 8 0: 0
        {4'h8, 5'h0}: q2 = 2'b00;
        // 8 1: 0
        {4'h8, 5'h1}: q2 = 2'b00;
        // 8 2: 1
        {4'h8, 5'h2}: q2 = 2'b01;
        // 8 3: 1
        {4'h8, 5'h3}: q2 = 2'b01;
        // 8 4: 1
        {4'h8, 5'h4}: q2 = 2'b01;
        // 8 5: 1
        {4'h8, 5'h5}: q2 = 2'b01;
        // 8 6: 2
        {4'h8, 5'h6}: q2 = 2'b10;
        // 8 7: 2
        {4'h8, 5'h7}: q2 = 2'b10;
        // 8 8: 2
        {4'h8, 5'h8}: q2 = 2'b10;
        // 8 9: 2
        {4'h8, 5'h9}: q2 = 2'b10;
        // 8 10: 2
        {4'h8, 5'ha}: q2 = 2'b10;
        // 8 11: 2
        {4'h8, 5'hb}: q2 = 2'b10;
        // 9 0: 0
        {4'h9, 5'h0}: q2 = 2'b00;
        // 9 1: 0
        {4'h9, 5'h1}: q2 = 2'b00;
        // 9 2: 0
        {4'h9, 5'h2}: q2 = 2'b00;
        // 9 3: 1
        {4'h9, 5'h3}: q2 = 2'b01;
        // 9 4: 1
        {4'h9, 5'h4}: q2 = 2'b01;
        // 9 5: 1
        {4'h9, 5'h5}: q2 = 2'b01;
        // 9 6: 1
        {4'h9, 5'h6}: q2 = 2'b01;
        // 9 7: 2
        {4'h9, 5'h7}: q2 = 2'b10;
        // 9 8: 2
        {4'h9, 5'h8}: q2 = 2'b10;
        // 9 9: 2
        {4'h9, 5'h9}: q2 = 2'b10;
        // 9 10: 2
        {4'h9, 5'ha}: q2 = 2'b10;
        // 9 11: 2
        {4'h9, 5'hb}: q2 = 2'b10;
        // 9 12: 2
        {4'h9, 5'hc}: q2 = 2'b10;
        // 9 13: 2
        {4'h9, 5'hd}: q2 = 2'b10;
        // 10 0: 0
        {4'ha, 5'h0}: q2 = 2'b00;
        // 10 1: 0
        {4'ha, 5'h1}: q2 = 2'b00;
        // 10 2: 0
        {4'ha, 5'h2}: q2 = 2'b00;
        // 10 3: 1
        {4'ha, 5'h3}: q2 = 2'b01;
        // 10 4: 1
        {4'ha, 5'h4}: q2 = 2'b01;
        // 10 5: 1
        {4'ha, 5'h5}: q2 = 2'b01;
        // 10 6: 1
        {4'ha, 5'h6}: q2 = 2'b01;
        // 10 7: 1
        {4'ha, 5'h7}: q2 = 2'b01;
        // 10 8: 2
        {4'ha, 5'h8}: q2 = 2'b10;
        // 10 9: 2
        {4'ha, 5'h9}: q2 = 2'b10;
        // 10 10: 2
        {4'ha, 5'ha}: q2 = 2'b10;
        // 10 11: 2
        {4'ha, 5'hb}: q2 = 2'b10;
        // 10 12: 2
        {4'ha, 5'hc}: q2 = 2'b10;
        // 10 13: 2
        {4'ha, 5'hd}: q2 = 2'b10;
        // 10 14: 2
        {4'ha, 5'he}: q2 = 2'b10;
        // 11 0: 0
        {4'hb, 5'h0}: q2 = 2'b00;
        // 11 1: 0
        {4'hb, 5'h1}: q2 = 2'b00;
        // 11 2: 0
        {4'hb, 5'h2}: q2 = 2'b00;
        // 11 3: 1
        {4'hb, 5'h3}: q2 = 2'b01;
        // 11 4: 1
        {4'hb, 5'h4}: q2 = 2'b01;
        // 11 5: 1
        {4'hb, 5'h5}: q2 = 2'b01;
        // 11 6: 1
        {4'hb, 5'h6}: q2 = 2'b01;
        // 11 7: 1
        {4'hb, 5'h7}: q2 = 2'b01;
        // 11 8: 1
        {4'hb, 5'h8}: q2 = 2'b01;
        // 11 9: 2
        {4'hb, 5'h9}: q2 = 2'b10;
        // 11 10: 2
        {4'hb, 5'ha}: q2 = 2'b10;
        // 11 11: 2
        {4'hb, 5'hb}: q2 = 2'b10;
        // 11 12: 2
        {4'hb, 5'hc}: q2 = 2'b10;
        // 11 13: 2
        {4'hb, 5'hd}: q2 = 2'b10;
        // 11 14: 2
        {4'hb, 5'he}: q2 = 2'b10;
        // 11 15: 2
        {4'hb, 5'hf}: q2 = 2'b10;
        // 12 0: 0
        {4'hc, 5'h0}: q2 = 2'b00;
        // 12 1: 0
        {4'hc, 5'h1}: q2 = 2'b00;
        // 12 2: 0
        {4'hc, 5'h2}: q2 = 2'b00;
        // 12 3: 0
        {4'hc, 5'h3}: q2 = 2'b00;
        // 12 4: 1
        {4'hc, 5'h4}: q2 = 2'b01;
        // 12 5: 1
        {4'hc, 5'h5}: q2 = 2'b01;
        // 12 6: 1
        {4'hc, 5'h6}: q2 = 2'b01;
        // 12 7: 1
        {4'hc, 5'h7}: q2 = 2'b01;
        // 12 8: 1
        {4'hc, 5'h8}: q2 = 2'b01;
        // 12 9: 1
        {4'hc, 5'h9}: q2 = 2'b01;
        // 12 10: 2
        {4'hc, 5'ha}: q2 = 2'b10;
        // 12 11: 2
        {4'hc, 5'hb}: q2 = 2'b10;
        // 12 12: 2
        {4'hc, 5'hc}: q2 = 2'b10;
        // 12 13: 2
        {4'hc, 5'hd}: q2 = 2'b10;
        // 12 14: 2
        {4'hc, 5'he}: q2 = 2'b10;
        // 12 15: 2
        {4'hc, 5'hf}: q2 = 2'b10;
        // 12 16: 2
        {4'hc, 5'h10}: q2 = 2'b10;
        // 12 17: 2
        {4'hc, 5'h11}: q2 = 2'b10;
        // 13 0: 0
        {4'hd, 5'h0}: q2 = 2'b00;
        // 13 1: 0
        {4'hd, 5'h1}: q2 = 2'b00;
        // 13 2: 0
        {4'hd, 5'h2}: q2 = 2'b00;
        // 13 3: 0
        {4'hd, 5'h3}: q2 = 2'b00;
        // 13 4: 1
        {4'hd, 5'h4}: q2 = 2'b01;
        // 13 5: 1
        {4'hd, 5'h5}: q2 = 2'b01;
        // 13 6: 1
        {4'hd, 5'h6}: q2 = 2'b01;
        // 13 7: 1
        {4'hd, 5'h7}: q2 = 2'b01;
        // 13 8: 1
        {4'hd, 5'h8}: q2 = 2'b01;
        // 13 9: 1
        {4'hd, 5'h9}: q2 = 2'b01;
        // 13 10: 2
        {4'hd, 5'ha}: q2 = 2'b10;
        // 13 11: 2
        {4'hd, 5'hb}: q2 = 2'b10;
        // 13 12: 2
        {4'hd, 5'hc}: q2 = 2'b10;
        // 13 13: 2
        {4'hd, 5'hd}: q2 = 2'b10;
        // 13 14: 2
        {4'hd, 5'he}: q2 = 2'b10;
        // 13 15: 2
        {4'hd, 5'hf}: q2 = 2'b10;
        // 13 16: 2
        {4'hd, 5'h10}: q2 = 2'b10;
        // 13 17: 2
        {4'hd, 5'h11}: q2 = 2'b10;
        // 13 18: 2
        {4'hd, 5'h12}: q2 = 2'b10;
        // 14 0: 0
        {4'he, 5'h0}: q2 = 2'b00;
        // 14 1: 0
        {4'he, 5'h1}: q2 = 2'b00;
        // 14 2: 0
        {4'he, 5'h2}: q2 = 2'b00;
        // 14 3: 0
        {4'he, 5'h3}: q2 = 2'b00;
        // 14 4: 1
        {4'he, 5'h4}: q2 = 2'b01;
        // 14 5: 1
        {4'he, 5'h5}: q2 = 2'b01;
        // 14 6: 1
        {4'he, 5'h6}: q2 = 2'b01;
        // 14 7: 1
        {4'he, 5'h7}: q2 = 2'b01;
        // 14 8: 1
        {4'he, 5'h8}: q2 = 2'b01;
        // 14 9: 1
        {4'he, 5'h9}: q2 = 2'b01;
        // 14 10: 1
        {4'he, 5'ha}: q2 = 2'b01;
        // 14 11: 2
        {4'he, 5'hb}: q2 = 2'b10;
        // 14 12: 2
        {4'he, 5'hc}: q2 = 2'b10;
        // 14 13: 2
        {4'he, 5'hd}: q2 = 2'b10;
        // 14 14: 2
        {4'he, 5'he}: q2 = 2'b10;
        // 14 15: 2
        {4'he, 5'hf}: q2 = 2'b10;
        // 14 16: 2
        {4'he, 5'h10}: q2 = 2'b10;
        // 14 17: 2
        {4'he, 5'h11}: q2 = 2'b10;
        // 14 18: 2
        {4'he, 5'h12}: q2 = 2'b10;
        // 14 19: 2
        {4'he, 5'h13}: q2 = 2'b10;
        // 15 0: 0
        {4'hf, 5'h0}: q2 = 2'b00;
        // 15 1: 0
        {4'hf, 5'h1}: q2 = 2'b00;
        // 15 2: 0
        {4'hf, 5'h2}: q2 = 2'b00;
        // 15 3: 0
        {4'hf, 5'h3}: q2 = 2'b00;
        // 15 4: 0
        {4'hf, 5'h4}: q2 = 2'b00;
        // 15 5: 1
        {4'hf, 5'h5}: q2 = 2'b01;
        // 15 6: 1
        {4'hf, 5'h6}: q2 = 2'b01;
        // 15 7: 1
        {4'hf, 5'h7}: q2 = 2'b01;
        // 15 8: 1
        {4'hf, 5'h8}: q2 = 2'b01;
        // 15 9: 1
        {4'hf, 5'h9}: q2 = 2'b01;
        // 15 10: 1
        {4'hf, 5'ha}: q2 = 2'b01;
        // 15 11: 1
        {4'hf, 5'hb}: q2 = 2'b01;
        // 15 12: 2
        {4'hf, 5'hc}: q2 = 2'b10;
        // 15 13: 2
        {4'hf, 5'hd}: q2 = 2'b10;
        // 15 14: 2
        {4'hf, 5'he}: q2 = 2'b10;
        // 15 15: 2
        {4'hf, 5'hf}: q2 = 2'b10;
        // 15 16: 2
        {4'hf, 5'h10}: q2 = 2'b10;
        // 15 17: 2
        {4'hf, 5'h11}: q2 = 2'b10;
        // 15 18: 2
        {4'hf, 5'h12}: q2 = 2'b10;
        // 15 19: 2
        {4'hf, 5'h13}: q2 = 2'b10;
        // 15 20: 2
        {4'hf, 5'h14}: q2 = 2'b10;
        // 15 21: 2
        {4'hf, 5'h15}: q2 = 2'b10;
		  
		  default:       q2 = 2'b00;

    endcase
end
endmodule


//--------------------------------
// 进位与商计算：用于 SRT 算法的加减法器
module csAddSubGen  
#(parameter N = 32)

(
input logic sub,
input logic [N - 1 : 0] x,
input logic [N - 1 : 0] y,
input logic [N - 1 : 0] cin,
output logic [N - 1: 0] s,
output logic [N - 1 : 0] c
);

logic [N - 1 : 0] ys;

assign ys = y ^ {N{sub}};  // invert y if sub is set
assign c[0] = 1'b0;
assign s[0] = x[0] ^ ys[0] ^ sub;
assign c[1] = x[0] & ys[0] | x[0] & sub | ys[0] & sub;
assign s[N - 1 : 1] = x[N - 1 : 1] ^ ys[N - 1 : 1] ^ cin[N - 1 : 1];
assign c[N - 1 : 2] = x[N - 2 : 1] & ys[N - 2 : 1] | x[N - 2 : 1] & cin[N - 2 : 1] | ys[N - 2 : 1] & cin[N - 2 : 1];

// ignore last carry

endmodule


//--------------------------------
// 逆序计数器：输入 N 位宽的二进制数，输出其逆序的二进制编码

module zeroMSBCounter
#(parameter N = 32)
(  
    input logic [N - 1 : 0] x,
    output logic [$clog2(N) - 1 : 0] out
);
logic [N - 1 : 0] xi;
logic [N - 1 : 0] caOut;
genvar i;
generate
for(i = 0; i < N; i++)
begin: invertbits
   assign xi[i] = x[N - 1 - i];
end
endgenerate

combArbiter #(N) ca(.x(xi), .out(caOut));
encoder #(N) enc(.x(caOut), .out(out));
endmodule



//----------------------------------
// 编码器：将输入的 N 位二进制数转换为其对应的 $clog2(N) 位宽的编码输出（独热码转换器）
module encoder
#(parameter N = 32)
(
    input logic [N - 1 : 0] x,
    output logic [$clog2(N) - 1 : 0] out
);

always_comb
begin
    out = {$clog2(N){1'b0}};
    for (int unsigned i = 0; i < N; i++)
    begin
        if (x[i])
            out |= $clog2(N)'(i); // cast i to $clog2(N) width
    end
end
endmodule


//----------------------------------
//前导0检测器
module combArbiter
#(parameter N = 32)
(  
    input logic [N - 1 : 0] x,
    output logic [N - 1 : 0] out
);
logic [N - 1 : 0] notFoundYet;

genvar i;
assign notFoundYet[0] = 1'b1;

generate
for(i = 1; i < N; i++)
begin: arbiterFor
    assign notFoundYet[i] = (~x[i - 1]) & notFoundYet[i - 1];
end
endgenerate
assign out = x & notFoundYet;
endmodule


