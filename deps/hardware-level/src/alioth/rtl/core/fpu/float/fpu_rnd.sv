// 浮点舍入与结果打包模块
// 实现浮点数的舍入、异常标志生成和最终结果打包输出
//
// 端口说明：
//   fpu_rnd_i : 输入结构体，包含待舍入数据及控制信号
//   fpu_rnd_o : 输出结构体，包含最终结果和标志

import fpu_types::*;

module fpu_rnd (
    input                  clk,           // 时钟信号
    input                  rst_n,         // 复位信号，低有效
    input  fpu_rnd_in_type  fpu_rnd_i,      // 输入结构体
    output fpu_rnd_out_type fpu_rnd_o       // 输出结构体
);

    // 输入信号寄存器，用于时序同步
    logic        sig_r;    // 符号位
    logic [13:0] expo_r;   // 指数部分
    logic [53:0] mant_r;   // 尾数部分
    logic [ 1:0] rema_r;   // 余数
    logic [ 1:0] fmt_r;    // 浮点格式（0:单精度，1:双精度）
    logic [ 2:0] rm_r;     // 舍入模式
    logic [ 2:0] grs_r;    // GRS位（Guard, Round, Sticky）
    logic        snan_r;   // 信号NaN
    logic        qnan_r;   // 安静NaN
    logic        dbz_r;    // 除零异常
    logic        infs_r;   // 无穷大
    logic        zero_r;   // 零
    logic        diff_r;   // 差值标志
    logic        valid_r;  // 输入有效标志

    // 输出组合信号
    logic [63:0] result;   // 最终浮点结果
    logic [ 4:0] flags;    // 异常标志
    logic        ready;    // 输出有效标志

    // 输入寄存
    // 时钟上升沿或复位时更新输入寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位时清零所有寄存器
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
            // 正常工作时采样输入信号
            sig_r   <= fpu_rnd_i.sig;
            expo_r  <= fpu_rnd_i.expo;
            mant_r  <= fpu_rnd_i.mant;
            rema_r  <= fpu_rnd_i.rema;
            fmt_r   <= fpu_rnd_i.fmt;
            rm_r    <= fpu_rnd_i.rm;
            grs_r   <= fpu_rnd_i.grs;
            snan_r  <= fpu_rnd_i.snan;
            qnan_r  <= fpu_rnd_i.qnan;
            dbz_r   <= fpu_rnd_i.dbz;
            infs_r  <= fpu_rnd_i.infs;
            zero_r  <= fpu_rnd_i.zero;
            diff_r  <= fpu_rnd_i.diff;
            valid_r <= fpu_rnd_i.valid;
        end
    end

    // 组合逻辑临时变量
    logic        sig;      // 符号位
    logic [13:0] expo;     // 指数
    logic [53:0] mant;     // 尾数
    logic [ 1:0] rema;     // 余数
    logic [ 1:0] fmt;      // 格式
    logic [ 2:0] rm;       // 舍入模式
    logic [ 2:0] grs;      // GRS位
    logic        snan;     // 信号NaN
    logic        qnan;     // 安静NaN
    logic        dbz;      // 除零
    logic        infs;     // 无穷
    logic        zero;     // 零
    logic        diff;     // 差值

    logic        odd;      // 奇数判断，用于舍入
    logic        rndup;    // 是否需要进位
    logic        rnddn;    // 是否需要舍去
    logic        shift;    // 是否需要尾数右移

    // 舍入与打包组合逻辑
    always_comb begin
        // 默认输出初始化
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

        // 判断是否为奇数（用于舍入最近偶数）
        odd      = mant[0] | |grs[1:0] | (rema == 1);
        // flags[0]：是否发生舍入
        flags[0] = (rema != 0) | |grs;

        // 舍入控制信号初始化
        rndup    = 0;
        rnddn    = 0;
        // 根据舍入模式决定是否进位或舍去
        if (rm == 0) begin  // rne: 最近偶数舍入
            if (grs[2] & odd) begin
                rndup = 1;
            end
        end else if (rm == 1) begin  // rtz: 向零舍入
            rnddn = 1;
        end else if (rm == 2) begin  // rdn: 向负无穷舍入
            if (sig & flags[0]) begin
                rndup = 1;
            end else if (~sig & zero & diff) begin
                sig = ~sig;
            end else if (~sig) begin
                rnddn = 1;
            end
        end else if (rm == 3) begin  // rup: 向正无穷舍入
            if (~sig & flags[0]) begin
                rndup = 1;
            end else if (sig) begin
                rnddn = 1;
            end
        end else if (rm == 4) begin  // rmm: 最近最大幅度
            if (grs[2] & flags[0]) begin
                rndup = 1;
            end
        end

        // 尾数加进位
        mant = mant + {53'h0, rndup};

        // 进位后特殊处理
        if (rndup == 1) begin
            if (fmt == 0) begin // 单精度
                if (expo == 0) begin
                    if (mant[23]) begin
                        expo = 1;
                    end
                end
            end else if (fmt == 1) begin // 双精度
                if (expo == 0) begin
                    if (mant[52]) begin
                        expo = 1;
                    end
                end
            end
        end

        // 舍去时的特殊处理
        if (rnddn == 1) begin
            if (fmt == 0) begin // 单精度
                if (expo >= 255) begin
                    expo  = 254;
                    mant  = {31'b0, {23{1'b1}}};
                    flags = 5'b00101; // 溢出和舍入
                end
            end else if (fmt == 1) begin // 双精度
                if (expo >= 2047) begin
                    expo  = 2046;
                    mant  = {2'b0, {52{1'b1}}};
                    flags = 5'b00101;
                end
            end
        end

        // 判断是否需要尾数右移（规格化）
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

        // 尾数右移，指数加一
        expo = expo + {13'h0, shift};
        mant = mant >> shift;

        // 非规格化数的舍入标志
        if (expo == 0) begin
            flags[1] = flags[0];
        end

        // 进位后对最小规格化数的特殊处理
        if (rndup == 1) begin
            if (expo == 1) begin
                if (fmt == 0 && |mant[22:0] == 0) begin
                    flags[1] = rm == 2 || rm == 3 ? ((grs == 1) | (grs == 2) | (grs == 3) | (grs == 4)) : ((grs == 4) | (grs == 5));
                end else if (fmt == 1 && |mant[51:0] == 0) begin
                    flags[1] = rm == 2 || rm == 3 ? ((grs == 1) | (grs == 2) | (grs == 3) | (grs == 4)) : ((grs == 4) | (grs == 5));
                end
            end
        end

        // 异常情况处理
        if (snan) begin
            flags = 5'b10000; // 信号NaN
        end else if (qnan) begin
            flags = 5'b00000; // 安静NaN
        end else if (dbz) begin
            flags = 5'b01000; // 除零
        end else if (infs) begin
            flags = 5'b00000; // 无穷
        end else if (zero) begin
            flags = 5'b00000; // 零
        end

        // 根据格式打包最终结果
        if (fmt == 0) begin // 单精度
            if (snan | qnan) begin
                // NaN编码
                result = {32'h00000000, 1'h0, 8'hFF, 23'h400000};
            end else if (dbz | infs) begin
                // 无穷大编码
                result = {32'h00000000, sig, 8'hFF, 23'h000000};
            end else if (zero) begin
                // 零编码
                result = {32'h00000000, sig, 8'h00, 23'h000000};
            end else if (expo == 0) begin
                // 非规格化数
                result = {32'h00000000, sig, 8'h00, mant[22:0]};
            end else if ($signed(expo) > 254) begin
                // 溢出
                flags  = 5'b00101;
                result = {32'h00000000, sig, 8'hFF, 23'h000000};
            end else begin
                // 规格化数
                result = {32'h00000000, sig, expo[7:0], mant[22:0]};
            end
        end else if (fmt == 1) begin // 双精度
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
    assign fpu_rnd_o.result = result;
    assign fpu_rnd_o.flags  = flags;
    assign fpu_rnd_o.ready  = ready;

endmodule
