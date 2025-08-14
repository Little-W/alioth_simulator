// 浮点最大/最小值选择模块
// 实现浮点数的max/min选择，支持异常（NaN等）处理
//
// 端口说明：
//   fp_max_i : 输入结构体，包含两个操作数及控制信号
//   fp_max_o : 输出结构体，包含结果和异常标志

import fp_types::*;

module fp_max (
    input                  clk,
    input                  rst_n,
    input  fp_max_in_type  fp_max_i,
    output fp_max_out_type fp_max_o
);

    logic [63:0] data1;
    logic [63:0] data2;
    logic [64:0] extend1;
    logic [64:0] extend2;
    logic [ 1:0] fmt;
    logic [ 2:0] rm;
    logic [ 9:0] class1;
    logic [ 9:0] class2;

    logic [63:0] nan;
    logic        comp;

    logic [63:0] result;
    logic [ 4:0] flags;
    logic        ready_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result    <= 64'b0;
            flags     <= 5'b0;
            ready_reg <= 1'b0;
        end else begin
            ready_reg <= fp_max_i.valid;

            if (fp_max_i.valid) begin
                data1   = fp_max_i.data1;
                data2   = fp_max_i.data2;
                extend1 = fp_max_i.ext1;
                extend2 = fp_max_i.ext2;
                fmt     = fp_max_i.fmt;
                rm      = fp_max_i.rm;
                class1  = fp_max_i.class1;
                class2  = fp_max_i.class2;

                nan     = 64'h7ff8000000000000;
                comp    = 0;

                if (fmt == 0) begin
                    nan = 64'h000000007fc00000;
                end

                if (extend1[63:0] > extend2[63:0]) begin
                    comp = 1;
                end

                // 设置默认值
                result <= 64'b0;
                flags  <= 5'b0;

                if (rm == 0) begin
                    if ((class1[8] & class2[8]) == 1) begin
                        result   <= nan;
                        flags[4] <= 1;
                    end else if (class1[8] == 1) begin
                        result   <= data2;
                        flags[4] <= 1;
                    end else if (class2[8] == 1) begin
                        result   <= data1;
                        flags[4] <= 1;
                    end else if ((class1[9] & class2[9]) == 1) begin
                        result <= nan;
                    end else if (class1[9] == 1) begin
                        result <= data2;
                    end else if (class2[9] == 1) begin
                        result <= data1;
                    end else if ((extend1[64] ^ extend2[64]) == 1) begin
                        if (extend1[64] == 1) begin
                            result <= data1;
                        end else begin
                            result <= data2;
                        end
                    end else begin
                        if (extend1[64] == 1) begin
                            if (comp == 1) begin
                                result <= data1;
                            end else begin
                                result <= data2;
                            end
                        end else begin
                            if (comp == 0) begin
                                result <= data1;
                            end else begin
                                result <= data2;
                            end
                        end
                    end
                end else if (rm == 1) begin
                    if ((class1[8] & class2[8]) == 1) begin
                        result   <= nan;
                        flags[4] <= 1;
                    end else if (class1[8] == 1) begin
                        result   <= data2;
                        flags[4] <= 1;
                    end else if (class2[8] == 1) begin
                        result   <= data1;
                        flags[4] <= 1;
                    end else if ((class1[9] & class2[9]) == 1) begin
                        result <= nan;
                    end else if (class1[9] == 1) begin
                        result <= data2;
                    end else if (class2[9] == 1) begin
                        result <= data1;
                    end else if ((extend1[64] ^ extend2[64]) == 1) begin
                        if (extend1[64] == 1) begin
                            result <= data2;
                        end else begin
                            result <= data1;
                        end
                    end else begin
                        if (extend1[64] == 1) begin
                            if (comp == 1) begin
                                result <= data2;
                            end else begin
                                result <= data1;
                            end
                        end else begin
                            if (comp == 0) begin
                                result <= data2;
                            end else begin
                                result <= data1;
                            end
                        end
                    end
                end else begin
                    flags <= 5'b0;
                end
            end
        end
    end

    assign fp_max_o.result = result;
    assign fp_max_o.flags  = flags;
    assign fp_max_o.ready  = ready_reg;

endmodule
