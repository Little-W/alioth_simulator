// 浮点格式转换模块
// 支持浮点数不同格式间的转换、浮点转整型、整型转浮点等，支持异常处理
//
// 端口说明：
//   fpu_cvt_f2f_i/o : 浮点到浮点格式转换
//   fpu_cvt_f2i_i/o : 浮点到整型转换
//   fpu_cvt_i2f_i/o : 整型到浮点转换
//   lzc_o/lzc_i    : 前导零计数器接口（保留兼容性）

import fpu_types::*;

module fpu_cvt (
    input                      clk,
    input                      rst_n,
    input  fpu_cvt_f2f_in_type  fpu_cvt_f2f_i,
    output fpu_cvt_f2f_out_type fpu_cvt_f2f_o,
    input  fpu_cvt_f2i_in_type  fpu_cvt_f2i_i,
    output fpu_cvt_f2i_out_type fpu_cvt_f2i_o,
    input  fpu_cvt_i2f_in_type  fpu_cvt_i2f_i,
    output fpu_cvt_i2f_out_type fpu_cvt_i2f_o
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        PROCESS = 2'b01,
        COMPLETE = 2'b10
    } state_t;

    // State machines
    state_t f2f_state, f2i_state, i2f_state;
    state_t f2f_state_next, f2i_state_next, i2f_state_next;

    // Pipeline registers
    fpu_cvt_f2f_var_type v_f2f_r, v_f2f_next;
    fpu_cvt_f2i_var_type v_f2i_r, v_f2i_next;
    fpu_cvt_i2f_var_type v_i2f_r, v_i2f_next;

    // Output registers
    fpu_cvt_f2f_out_type fpu_cvt_f2f_o_r, fpu_cvt_f2f_o_next;
    fpu_cvt_f2i_out_type fpu_cvt_f2i_o_r, fpu_cvt_f2i_o_next;
    fpu_cvt_i2f_out_type fpu_cvt_i2f_o_r, fpu_cvt_i2f_o_next;

    // Assign outputs
    assign fpu_cvt_f2f_o = fpu_cvt_f2f_o_r;
    assign fpu_cvt_f2i_o = fpu_cvt_f2i_o_r;
    assign fpu_cvt_i2f_o = fpu_cvt_i2f_o_r;

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f2f_state      <= IDLE;
            f2i_state      <= IDLE;
            i2f_state      <= IDLE;
            v_f2f_r        <= '0;
            v_f2i_r        <= '0;
            v_i2f_r        <= '0;
            fpu_cvt_f2f_o_r <= '0;
            fpu_cvt_f2i_o_r <= '0;
            fpu_cvt_i2f_o_r <= '0;
        end else begin
            f2f_state      <= f2f_state_next;
            f2i_state      <= f2i_state_next;
            i2f_state      <= i2f_state_next;
            v_f2f_r        <= v_f2f_next;
            v_f2i_r        <= v_f2i_next;
            v_i2f_r        <= v_i2f_next;
            fpu_cvt_f2f_o_r <= fpu_cvt_f2f_o_next;
            fpu_cvt_f2i_o_r <= fpu_cvt_f2i_o_next;
            fpu_cvt_i2f_o_r <= fpu_cvt_i2f_o_next;
        end
    end

    // F2F State Machine
    always_comb begin
        f2f_state_next    = f2f_state;
        v_f2f_next        = v_f2f_r;
        fpu_cvt_f2f_o_next = '0;  // 默认清零

        case (f2f_state)
            IDLE: begin
                if (fpu_cvt_f2f_i.valid) begin
                    f2f_state_next = PROCESS;
                    v_f2f_next     = f2f_input_stage(fpu_cvt_f2f_i);
                end
            end
            PROCESS: begin
                f2f_state_next = COMPLETE;
                v_f2f_next     = f2f_process_stage(v_f2f_r);
            end
            COMPLETE: begin
                f2f_state_next    = IDLE;
                fpu_cvt_f2f_o_next = f2f_output_stage(v_f2f_r);
            end
            default: f2f_state_next = IDLE;
        endcase
    end

    // F2I State Machine
    always_comb begin
        f2i_state_next    = f2i_state;
        v_f2i_next        = v_f2i_r;
        fpu_cvt_f2i_o_next = '0;  // 默认清零

        case (f2i_state)
            IDLE: begin
                if (fpu_cvt_f2i_i.valid) begin
                    f2i_state_next = PROCESS;
                    v_f2i_next     = f2i_input_stage(fpu_cvt_f2i_i);
                end
            end
            PROCESS: begin
                f2i_state_next = COMPLETE;
                v_f2i_next     = f2i_process_stage(v_f2i_r);
            end
            COMPLETE: begin
                f2i_state_next    = IDLE;
                fpu_cvt_f2i_o_next = f2i_output_stage(v_f2i_r);
            end
            default: f2i_state_next = IDLE;
        endcase
    end

    // I2F State Machine
    always_comb begin
        i2f_state_next    = i2f_state;
        v_i2f_next        = v_i2f_r;
        fpu_cvt_i2f_o_next = '0;  // 默认清零

        case (i2f_state)
            IDLE: begin
                if (fpu_cvt_i2f_i.valid) begin
                    i2f_state_next = PROCESS;
                    v_i2f_next     = i2f_input_stage(fpu_cvt_i2f_i);
                end
            end
            PROCESS: begin
                i2f_state_next = COMPLETE;
                v_i2f_next     = i2f_process_stage(v_i2f_r, lzc_result);  // 直接传递lzc_result
            end
            COMPLETE: begin
                i2f_state_next    = IDLE;
                fpu_cvt_i2f_o_next = i2f_output_stage(v_i2f_r);
            end
            default: i2f_state_next = IDLE;
        endcase
    end

    // F2F Functions
    function automatic fpu_cvt_f2f_var_type f2f_input_stage(input fpu_cvt_f2f_in_type inp);
        fpu_cvt_f2f_var_type f2f_var;
        f2f_var.data           = inp.data;
        f2f_var.fmt            = inp.fmt;
        f2f_var.rm             = inp.rm;
        f2f_var.classification = inp.classification;
        f2f_var.snan           = f2f_var.classification[8];
        f2f_var.qnan           = f2f_var.classification[9];
        f2f_var.dbz            = 0;
        f2f_var.infs           = f2f_var.classification[0] | f2f_var.classification[7];
        f2f_var.zero           = f2f_var.classification[3] | f2f_var.classification[4];
        return f2f_var;
    endfunction

    function automatic fpu_cvt_f2f_var_type f2f_process_stage(input fpu_cvt_f2f_var_type f2f_var_in);
        fpu_cvt_f2f_var_type f2f_var_out;
        f2f_var_out               = f2f_var_in;
        f2f_var_out.exponent_cvt  = f2f_var_in.data[63:52];
        f2f_var_out.mantissa_cvt  = {2'h1, f2f_var_in.data[51:0], 26'h0};

        f2f_var_out.exponent_bias = 1920;
        if (f2f_var_in.fmt == 1) begin
            f2f_var_out.exponent_bias = 1024;
        end

        f2f_var_out.sign_rnd = f2f_var_in.data[64];
        f2f_var_out.exponent_rnd = {2'h0, f2f_var_out.exponent_cvt} - {3'h0, f2f_var_out.exponent_bias};

        f2f_var_out.counter_cvt = 0;
        if ($signed(f2f_var_out.exponent_rnd) <= 0) begin
            f2f_var_out.counter_cvt = 63;
            if ($signed(f2f_var_out.exponent_rnd) > -63) begin
                f2f_var_out.counter_cvt = 14'h1 - f2f_var_out.exponent_rnd;
            end
            f2f_var_out.exponent_rnd = 0;
        end

        f2f_var_out.mantissa_cvt = f2f_var_out.mantissa_cvt >> f2f_var_out.counter_cvt[5:0];

        f2f_var_out.mantissa_rnd = {29'h0, f2f_var_out.mantissa_cvt[79:55]};
        f2f_var_out.grs = {f2f_var_out.mantissa_cvt[54:53], |f2f_var_out.mantissa_cvt[52:0]};
        if (f2f_var_in.fmt == 1) begin
            f2f_var_out.mantissa_rnd = f2f_var_out.mantissa_cvt[79:26];
            f2f_var_out.grs = {f2f_var_out.mantissa_cvt[25:24], |f2f_var_out.mantissa_cvt[23:0]};
        end
        return f2f_var_out;
    endfunction

    function automatic fpu_cvt_f2f_out_type f2f_output_stage(input fpu_cvt_f2f_var_type f2f_var);
        fpu_cvt_f2f_out_type outp;
        outp.fpu_rnd.sig  = f2f_var.sign_rnd;
        outp.fpu_rnd.expo = f2f_var.exponent_rnd;
        outp.fpu_rnd.mant = f2f_var.mantissa_rnd;
        outp.fpu_rnd.rema = 2'h0;
        outp.fpu_rnd.fmt  = f2f_var.fmt;
        outp.fpu_rnd.rm   = f2f_var.rm;
        outp.fpu_rnd.grs  = f2f_var.grs;
        outp.fpu_rnd.snan = f2f_var.snan;
        outp.fpu_rnd.qnan = f2f_var.qnan;
        outp.fpu_rnd.dbz  = f2f_var.dbz;
        outp.fpu_rnd.infs = f2f_var.infs;
        outp.fpu_rnd.zero = f2f_var.zero;
        outp.fpu_rnd.diff = 1'h0;
        outp.ready       = 1'b1;
        return outp;
    endfunction

    // F2I Functions
    function automatic fpu_cvt_f2i_var_type f2i_input_stage(input fpu_cvt_f2i_in_type inp);
        fpu_cvt_f2i_var_type f2i_var;
        f2i_var.data           = inp.data;
        f2i_var.op             = inp.op.fcvt_op;
        f2i_var.rm             = inp.rm;
        f2i_var.classification = inp.classification;
        f2i_var.flags          = 0;
        f2i_var.result         = 0;
        f2i_var.snan           = f2i_var.classification[8];
        f2i_var.qnan           = f2i_var.classification[9];
        f2i_var.infs           = f2i_var.classification[0] | f2i_var.classification[7];
        f2i_var.zero           = 0;

        if (f2i_var.op == 0) begin
            f2i_var.exponent_bias = 34;
        end else if (f2i_var.op == 1) begin
            f2i_var.exponent_bias = 35;
        end else if (f2i_var.op == 2) begin
            f2i_var.exponent_bias = 66;
        end else begin
            f2i_var.exponent_bias = 67;
        end
        return f2i_var;
    endfunction

    function automatic fpu_cvt_f2i_var_type f2i_process_stage(input fpu_cvt_f2i_var_type f2i_var_in);
        fpu_cvt_f2i_var_type f2i_var_out;
        f2i_var_out              = f2i_var_in;

        f2i_var_out.sign_cvt     = f2i_var_in.data[64];
        f2i_var_out.exponent_cvt = f2i_var_in.data[63:52] - 13'd2044;
        f2i_var_out.mantissa_cvt = {68'h1, f2i_var_in.data[51:0]};

        if ((f2i_var_in.classification[3] | f2i_var_in.classification[4]) == 1) begin
            f2i_var_out.mantissa_cvt[52] = 0;
        end

        f2i_var_out.oor = 0;
        if ($signed(f2i_var_out.exponent_cvt) > $signed({5'h0, f2i_var_in.exponent_bias})) begin
            f2i_var_out.oor = 1;
        end else if ($signed(f2i_var_out.exponent_cvt) > 0) begin
            f2i_var_out.mantissa_cvt = f2i_var_out.mantissa_cvt << f2i_var_out.exponent_cvt;
        end

        f2i_var_out.mantissa_uint = f2i_var_out.mantissa_cvt[119:55];
        f2i_var_out.grs = {f2i_var_out.mantissa_cvt[54:53], |f2i_var_out.mantissa_cvt[52:0]};
        f2i_var_out.odd = f2i_var_out.mantissa_uint[0] | |f2i_var_out.grs[1:0];
        f2i_var_out.flags[0] = |f2i_var_out.grs;

        // Rounding logic
        f2i_var_out.rnded = 0;
        if (f2i_var_in.rm == 0) begin  //rne
            if (f2i_var_out.grs[2] & f2i_var_out.odd) begin
                f2i_var_out.rnded = 1;
            end
        end else if (f2i_var_in.rm == 2) begin  //rdn
            if (f2i_var_out.sign_cvt & f2i_var_out.flags[0]) begin
                f2i_var_out.rnded = 1;
            end
        end else if (f2i_var_in.rm == 3) begin  //rup
            if (~f2i_var_out.sign_cvt & f2i_var_out.flags[0]) begin
                f2i_var_out.rnded = 1;
            end
        end else if (f2i_var_in.rm == 4) begin  //rmm
            if (f2i_var_out.grs[2] & f2i_var_out.flags[0]) begin
                f2i_var_out.rnded = 1;
            end
        end

        f2i_var_out.mantissa_uint = f2i_var_out.mantissa_uint + {64'h0, f2i_var_out.rnded};
        return f2i_var_out;
    endfunction

    function automatic fpu_cvt_f2i_out_type f2i_output_stage(input fpu_cvt_f2i_var_type f2i_var);
        fpu_cvt_f2i_var_type f2i_var_temp;
        fpu_cvt_f2i_out_type outp;
        f2i_var_temp = f2i_var;

        // Out of range detection and result calculation
        f2i_var_temp.or_1 = f2i_var.mantissa_uint[64];
        f2i_var_temp.or_2 = f2i_var.mantissa_uint[63];
        f2i_var_temp.or_3 = |f2i_var.mantissa_uint[62:32];
        f2i_var_temp.or_4 = f2i_var.mantissa_uint[31];
        f2i_var_temp.or_5 = |f2i_var.mantissa_uint[30:0];

        f2i_var_temp.zero    = f2i_var_temp.or_1 | f2i_var_temp.or_2 | f2i_var_temp.or_3 | f2i_var_temp.or_4 | f2i_var_temp.or_5;

        f2i_var_temp.oor_64u = f2i_var_temp.or_1;
        f2i_var_temp.oor_64s = f2i_var_temp.or_1;
        f2i_var_temp.oor_32u = f2i_var_temp.or_1 | f2i_var_temp.or_2 | f2i_var_temp.or_3;
        f2i_var_temp.oor_32s = f2i_var_temp.or_1 | f2i_var_temp.or_2 | f2i_var_temp.or_3;

        // Apply sign-specific overflow checks
        if (f2i_var.sign_cvt) begin
            if (f2i_var.op == 0) begin
                f2i_var_temp.oor_32s = f2i_var_temp.oor_32s | (f2i_var_temp.or_4 & f2i_var_temp.or_5);
            end else if (f2i_var.op == 1) begin
                f2i_var_temp.oor = f2i_var_temp.oor | f2i_var_temp.zero;
            end else if (f2i_var.op == 2) begin
                f2i_var_temp.oor_64s = f2i_var_temp.oor_64s | (f2i_var_temp.or_2 & (f2i_var_temp.or_3 | f2i_var_temp.or_4 | f2i_var_temp.or_5));
            end else if (f2i_var.op == 3) begin
                f2i_var_temp.oor = f2i_var_temp.oor | f2i_var_temp.zero;
            end
        end else begin
            f2i_var_temp.oor_64s = f2i_var_temp.oor_64s | f2i_var_temp.or_2;
            f2i_var_temp.oor_32s = f2i_var_temp.oor_32s | f2i_var_temp.or_4;
        end

        f2i_var_temp.oor_64u = (f2i_var.op == 3) & (f2i_var_temp.oor_64u | f2i_var_temp.oor | f2i_var.infs | f2i_var.snan | f2i_var.qnan);
        f2i_var_temp.oor_64s = (f2i_var.op == 2) & (f2i_var_temp.oor_64s | f2i_var_temp.oor | f2i_var.infs | f2i_var.snan | f2i_var.qnan);
        f2i_var_temp.oor_32u = (f2i_var.op == 1) & (f2i_var_temp.oor_32u | f2i_var_temp.oor | f2i_var.infs | f2i_var.snan | f2i_var.qnan);
        f2i_var_temp.oor_32s = (f2i_var.op == 0) & (f2i_var_temp.oor_32s | f2i_var_temp.oor | f2i_var.infs | f2i_var.snan | f2i_var.qnan);

        if (f2i_var.sign_cvt) begin
            f2i_var_temp.mantissa_uint = -f2i_var.mantissa_uint;
        end

        // Generate final result based on operation type
        if (f2i_var.op == 0) begin
            f2i_var_temp.result = {32'h0, f2i_var_temp.mantissa_uint[31:0]};
            if (f2i_var_temp.oor_32s) begin
                f2i_var_temp.result = 64'h000000007FFFFFFF;
                f2i_var_temp.flags  = 5'b10000;
                if (f2i_var.sign_cvt) begin
                    if (~(f2i_var.snan | f2i_var.qnan)) begin
                        f2i_var_temp.result = 64'h0000000080000000;
                    end
                end
            end
        end else if (f2i_var.op == 1) begin
            f2i_var_temp.result = {32'h0, f2i_var_temp.mantissa_uint[31:0]};
            if (f2i_var_temp.oor_32u) begin
                f2i_var_temp.result = 64'h00000000FFFFFFFF;
                f2i_var_temp.flags  = 5'b10000;
                if (f2i_var.sign_cvt) begin
                    if (~(f2i_var.snan | f2i_var.qnan)) begin
                        f2i_var_temp.result = 64'h0000000000000000;
                    end
                end
            end
        end else if (f2i_var.op == 2) begin
            f2i_var_temp.result = f2i_var_temp.mantissa_uint[63:0];
            if (f2i_var_temp.oor_64s) begin
                f2i_var_temp.result = 64'h7FFFFFFFFFFFFFFF;
                f2i_var_temp.flags  = 5'b10000;
                if (f2i_var.sign_cvt) begin
                    if (~(f2i_var.snan | f2i_var.qnan)) begin
                        f2i_var_temp.result = 64'h8000000000000000;
                    end
                end
            end
        end else if (f2i_var.op == 3) begin
            f2i_var_temp.result = f2i_var_temp.mantissa_uint[63:0];
            if (f2i_var_temp.oor_64u) begin
                f2i_var_temp.result = 64'hFFFFFFFFFFFFFFFF;
                f2i_var_temp.flags  = 5'b10000;
                if (f2i_var.sign_cvt) begin
                    if (~(f2i_var.snan | f2i_var.qnan)) begin
                        f2i_var_temp.result = 64'h0000000000000000;
                    end
                end
            end
        end

        outp.result = f2i_var_temp.result;
        outp.flags  = f2i_var_temp.flags;
        outp.ready  = 1'b1;
        return outp;
    endfunction

    // I2F Functions
    function automatic fpu_cvt_i2f_var_type i2f_input_stage(input fpu_cvt_i2f_in_type inp);
        fpu_cvt_i2f_var_type i2f_var;
        i2f_var.data          = inp.data;
        i2f_var.op            = inp.op.fcvt_op;
        i2f_var.fmt           = inp.fmt;
        i2f_var.rm            = inp.rm;
        i2f_var.snan          = 0;
        i2f_var.qnan          = 0;
        i2f_var.dbz           = 0;
        i2f_var.infs          = 0;
        i2f_var.zero          = 0;

        i2f_var.exponent_bias = 127;
        if (i2f_var.fmt == 1) begin
            i2f_var.exponent_bias = 1023;
        end

        i2f_var.sign_uint = 0;
        if (i2f_var.op == 0) begin
            i2f_var.sign_uint = i2f_var.data[31];
        end else if (i2f_var.op == 2) begin
            i2f_var.sign_uint = i2f_var.data[63];
        end

        if (i2f_var.sign_uint) begin
            i2f_var.data = -i2f_var.data;
        end

        // 计算mantissa_uint，为下一个周期的LZC准备数据
        i2f_var.mantissa_uint = 64'hFFFFFFFFFFFFFFFF;
        i2f_var.exponent_uint = 0;
        if (!i2f_var.op[1]) begin
            i2f_var.mantissa_uint = {i2f_var.data[31:0], 32'h0};
            i2f_var.exponent_uint = 31;
        end else if (i2f_var.op[1]) begin
            i2f_var.mantissa_uint = i2f_var.data[63:0];
            i2f_var.exponent_uint = 63;
        end

        return i2f_var;
    endfunction

    function automatic fpu_cvt_i2f_var_type i2f_process_stage(
        input fpu_cvt_i2f_var_type i2f_var_in, input logic [5:0] lzc_result
    );  // 修改类型为logic [5:0]
        fpu_cvt_i2f_var_type i2f_var_out;
        i2f_var_out = i2f_var_in;

        i2f_var_out.zero = ~|i2f_var_out.mantissa_uint;
        i2f_var_out.counter_uint = ~lzc_result;
        i2f_var_out.mantissa_uint = i2f_var_out.mantissa_uint << i2f_var_out.counter_uint;

        i2f_var_out.sign_rnd = i2f_var_in.sign_uint;
        i2f_var_out.exponent_rnd = {8'h0,i2f_var_out.exponent_uint} + {4'h0,i2f_var_in.exponent_bias} - {8'h0,i2f_var_out.counter_uint};

        i2f_var_out.mantissa_rnd = {30'h0, i2f_var_out.mantissa_uint[63:40]};
        i2f_var_out.grs = {i2f_var_out.mantissa_uint[39:38], |i2f_var_out.mantissa_uint[37:0]};
        if (i2f_var_in.fmt == 1) begin
            i2f_var_out.mantissa_rnd = {1'h0, i2f_var_out.mantissa_uint[63:11]};
            i2f_var_out.grs = {i2f_var_out.mantissa_uint[10:9], |i2f_var_out.mantissa_uint[8:0]};
        end
        return i2f_var_out;
    endfunction

    function automatic fpu_cvt_i2f_out_type i2f_output_stage(input fpu_cvt_i2f_var_type i2f_var);
        fpu_cvt_i2f_out_type outp;
        outp.fpu_rnd.sig  = i2f_var.sign_rnd;
        outp.fpu_rnd.expo = i2f_var.exponent_rnd;
        outp.fpu_rnd.mant = i2f_var.mantissa_rnd;
        outp.fpu_rnd.rema = 2'h0;
        outp.fpu_rnd.fmt  = i2f_var.fmt;
        outp.fpu_rnd.rm   = i2f_var.rm;
        outp.fpu_rnd.grs  = i2f_var.grs;
        outp.fpu_rnd.snan = i2f_var.snan;
        outp.fpu_rnd.qnan = i2f_var.qnan;
        outp.fpu_rnd.dbz  = i2f_var.dbz;
        outp.fpu_rnd.infs = i2f_var.infs;
        outp.fpu_rnd.zero = i2f_var.zero;
        outp.fpu_rnd.diff = 1'h0;
        outp.ready       = 1'b1;
        return outp;
    endfunction

    // 内部LZC信号
    logic [63:0] lzc_data_in;
    logic [ 5:0] lzc_result;
    logic        lzc_valid;

    // LZC输入控制 - 在PROCESS状态时连接正确的数据
    always_comb begin
        lzc_data_in = 64'h0;
        if (i2f_state == PROCESS) begin
            lzc_data_in = v_i2f_r.mantissa_uint;
        end
    end

    // 实例化内部LZC模块
    lzc_64 u_lzc_64 (
        .data_in(lzc_data_in),
        .lzc    (lzc_result),
        .valid  (lzc_valid)
    );

endmodule
