// 浮点舍入与结果打包模块
// 实现浮点数的舍入、异常标志生成和最终结果打包输出
//
// 端口说明：
//   fp_rnd_i : 输入结构体，包含待舍入数据及控制信号
//   fp_rnd_o : 输出结构体，包含最终结果和标志

import fp_types::*;

module fp_rnd (
    input                  clk,
    input                  rst_n,
    input  fp_rnd_in_type  fp_rnd_i,
    output fp_rnd_out_type fp_rnd_o
);
    timeunit 1ns; timeprecision 1ps;

    logic        sig_r;
    logic [13:0] expo_r;
    logic [53:0] mant_r;
    logic [ 1:0] rema_r;
    logic [ 1:0] fmt_r;
    logic [ 2:0] rm_r;
    logic [ 2:0] grs_r;
    logic        snan_r;
    logic        qnan_r;
    logic        dbz_r;
    logic        infs_r;
    logic        zero_r;
    logic        diff_r;
    logic        valid_r;

    // 输出组合信号
    logic [63:0] result;
    logic [ 4:0] flags;
    logic        ready;

    // 输入寄存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sig_r   <= 1'b0;
            expo_r  <= 14'h0;
            mant_r  <= 54'h0;
            rema_r  <= 2'h0;
            fmt_r   <= 2'h0;
            rm_r    <= 3'h0;
            grs_r   <= 3'h0;
            snan_r  <= 1'b0;
            qnan_r  <= 1'b0;
            dbz_r   <= 1'b0;
            infs_r  <= 1'b0;
            zero_r  <= 1'b0;
            diff_r  <= 1'b0;
            valid_r <= 1'b0;
        end else begin
            sig_r   <= fp_rnd_i.sig;
            expo_r  <= fp_rnd_i.expo;
            mant_r  <= fp_rnd_i.mant;
            rema_r  <= fp_rnd_i.rema;
            fmt_r   <= fp_rnd_i.fmt;
            rm_r    <= fp_rnd_i.rm;
            grs_r   <= fp_rnd_i.grs;
            snan_r  <= fp_rnd_i.snan;
            qnan_r  <= fp_rnd_i.qnan;
            dbz_r   <= fp_rnd_i.dbz;
            infs_r  <= fp_rnd_i.infs;
            zero_r  <= fp_rnd_i.zero;
            diff_r  <= fp_rnd_i.diff;
            valid_r <= fp_rnd_i.valid;
        end
    end

    logic        sig;
    logic [13:0] expo;
    logic [53:0] mant;
    logic [ 1:0] rema;
    logic [ 1:0] fmt;
    logic [ 2:0] rm;
    logic [ 2:0] grs;
    logic        snan;
    logic        qnan;
    logic        dbz;
    logic        infs;
    logic        zero;
    logic        diff;

    logic        odd;
    logic        rndup;
    logic        rnddn;
    logic        shift;

    // 舍入与打包组合逻辑
    always_comb begin
        // 默认输出
        result   = 64'h0;
        flags    = 5'h0;
        ready    = valid_r;
        sig      = sig_r;
        expo     = expo_r;
        mant     = mant_r;
        rema     = rema_r;
        fmt      = fmt_r;
        rm       = rm_r;
        grs      = grs_r;
        snan     = snan_r;
        qnan     = qnan_r;
        dbz      = dbz_r;
        infs     = infs_r;
        zero     = zero_r;
        diff     = diff_r;

        odd      = mant[0] | |grs[1:0] | (rema == 1);
        flags[0] = (rema != 0) | |grs;

        rndup    = 0;
        rnddn    = 0;
        if (rm == 0) begin  //rne
            if (grs[2] & odd) begin
                rndup = 1;
            end
        end else if (rm == 1) begin  //rtz
            rnddn = 1;
        end else if (rm == 2) begin  //rdn
            if (sig & flags[0]) begin
                rndup = 1;
            end else if (~sig & zero & diff) begin
                sig = ~sig;
            end else if (~sig) begin
                rnddn = 1;
            end
        end else if (rm == 3) begin  //rup
            if (~sig & flags[0]) begin
                rndup = 1;
            end else if (sig) begin
                rnddn = 1;
            end
        end else if (rm == 4) begin  //rmm
            if (grs[2] & flags[0]) begin
                rndup = 1;
            end
        end

        mant = mant + {53'h0, rndup};

        if (rndup == 1) begin
            if (fmt == 0) begin
                if (expo == 0) begin
                    if (mant[23]) begin
                        expo = 1;
                    end
                end
            end else if (fmt == 1) begin
                if (expo == 0) begin
                    if (mant[52]) begin
                        expo = 1;
                    end
                end
            end
        end

        if (rnddn == 1) begin
            if (fmt == 0) begin
                if (expo >= 255) begin
                    expo  = 254;
                    mant  = {31'b0, {23{1'b1}}};
                    flags = 5'b00101;
                end
            end else if (fmt == 1) begin
                if (expo >= 2047) begin
                    expo  = 2046;
                    mant  = {2'b0, {52{1'b1}}};
                    flags = 5'b00101;
                end
            end
        end

        shift = 0;
        if (fmt == 0) begin
            if (mant[24]) begin
                shift = 1;
            end
        end else if (fmt == 1) begin
            if (mant[53]) begin
                shift = 1;
            end
        end

        expo = expo + {13'h0, shift};
        mant = mant >> shift;

        if (expo == 0) begin
            flags[1] = flags[0];
        end

        if (rndup == 1) begin
            if (expo == 1) begin
                if (fmt == 0 && |mant[22:0] == 0) begin
                    flags[1] = rm == 2 || rm == 3 ? ((grs == 1) | (grs == 2) | (grs == 3) | (grs == 4)) : ((grs == 4) | (grs == 5));
                end else if (fmt == 1 && |mant[51:0] == 0) begin
                    flags[1] = rm == 2 || rm == 3 ? ((grs == 1) | (grs == 2) | (grs == 3) | (grs == 4)) : ((grs == 4) | (grs == 5));
                end
            end
        end

        if (snan) begin
            flags = 5'b10000;
        end else if (qnan) begin
            flags = 5'b00000;
        end else if (dbz) begin
            flags = 5'b01000;
        end else if (infs) begin
            flags = 5'b00000;
        end else if (zero) begin
            flags = 5'b00000;
        end

        if (fmt == 0) begin
            if (snan | qnan) begin
                result = {32'h00000000, 1'h0, 8'hFF, 23'h400000};
            end else if (dbz | infs) begin
                result = {32'h00000000, sig, 8'hFF, 23'h000000};
            end else if (zero) begin
                result = {32'h00000000, sig, 8'h00, 23'h000000};
            end else if (expo == 0) begin
                result = {32'h00000000, sig, 8'h00, mant[22:0]};
            end else if ($signed(expo) > 254) begin
                flags  = 5'b00101;
                result = {32'h00000000, sig, 8'hFF, 23'h000000};
            end else begin
                result = {32'h00000000, sig, expo[7:0], mant[22:0]};
            end
        end else if (fmt == 1) begin
            if (snan | qnan) begin
                result = {1'h0, 11'h7FF, 52'h8000000000000};
            end else if (dbz | infs) begin
                result = {sig, 11'h7FF, 52'h0000000000000};
            end else if (zero) begin
                result = {sig, 11'h000, 52'h0000000000000};
            end else if (expo == 0) begin
                result = {sig, 11'h000, mant[51:0]};
            end else if ($signed(expo) > 2046) begin
                flags  = 5'b00101;
                result = {sig, 11'h7FF, 52'h0000000000000};
            end else begin
                result = {sig, expo[10:0], mant[51:0]};
            end
        end
    end

    // 输出赋值
    assign fp_rnd_o.result = result;
    assign fp_rnd_o.flags  = flags;
    assign fp_rnd_o.ready  = ready;

endmodule
