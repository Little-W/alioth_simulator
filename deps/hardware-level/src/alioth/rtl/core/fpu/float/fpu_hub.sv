// 浮点主互联模块
// 负责调度和连接各类浮点子模块，完成浮点指令的整体执行流程
//
// 端口说明：
//   fpu_hub_i/o    : 主输入输出结构体
//   其余为各功能子模块的输入输出接口
//   clear         : 清除/暂停信号

import fpu_types::*;

module fpu_hub (
    input  fpu_hub_in_type      fpu_hub_i,
    output fpu_hub_out_type     fpu_hub_o,
    input  fpu_ext_out_type     fpu_ext1_o,
    output fpu_ext_in_type      fpu_ext1_i,
    input  fpu_ext_out_type     fpu_ext2_o,
    output fpu_ext_in_type      fpu_ext2_i,
    input  fpu_ext_out_type     fpu_ext3_o,
    output fpu_ext_in_type      fpu_ext3_i,
    input  fpu_cmp_out_type     fpu_cmp_o,
    output fpu_cmp_in_type      fpu_cmp_i,
    input  fpu_max_out_type     fpu_max_o,
    output fpu_max_in_type      fpu_max_i,
    input  fpu_sgnj_out_type    fpu_sgnj_o,
    output fpu_sgnj_in_type     fpu_sgnj_i,
    input  fpu_cvt_f2f_out_type fpu_cvt_f2f_o,
    output fpu_cvt_f2f_in_type  fpu_cvt_f2f_i,
    input  fpu_cvt_f2i_out_type fpu_cvt_f2i_o,
    output fpu_cvt_f2i_in_type  fpu_cvt_f2i_i,
    input  fpu_cvt_i2f_out_type fpu_cvt_i2f_o,
    output fpu_cvt_i2f_in_type  fpu_cvt_i2f_i,
    input  fpu_fma_out_type     fpu_fma_o,
    output fpu_fma_in_type      fpu_fma_i,
    input  fpu_fdiv_out_type    fpu_fdiv_o,
    output fpu_fdiv_in_type     fpu_fdiv_i,
    input  fpu_rnd_out_type     fpu_rnd_o,
    output fpu_rnd_in_type      fpu_rnd_i,
    input                      clear
);

    logic             [63:0] data1;
    logic             [63:0] data2;
    logic             [63:0] data3;
    fpu_operation_type        op;
    logic             [ 1:0] fmt;
    logic             [ 2:0] rm;

    logic             [63:0] result;
    logic             [ 4:0] flags;
    logic                    ready;

    logic             [ 1:0] fmt_ext;

    logic             [64:0] extend1;
    logic             [64:0] extend2;
    logic             [64:0] extend3;

    logic             [ 9:0] class1;
    logic             [ 9:0] class2;
    logic             [ 9:0] class3;

    fpu_rnd_in_type           fpu_rnd;
    logic                    fpu_rnd_valid;

    always_comb begin

        if (fpu_hub_i.enable) begin
            data1 = fpu_hub_i.data1;
            data2 = fpu_hub_i.data2;
            data3 = fpu_hub_i.data3;
            op    = fpu_hub_i.op;
            fmt   = fpu_hub_i.fmt;
            rm    = fpu_hub_i.rm;
        end else begin
            data1 = 0;
            data2 = 0;
            data3 = 0;
            op    = 0;
            fmt   = 0;
            rm    = 0;
        end

        result = 0;
        flags  = 0;
        ready  = fpu_hub_i.enable;

        if (op.fcvt_f2f) begin
            fmt_ext = fpu_hub_i.op.fcvt_op;
        end else begin
            fmt_ext = fpu_hub_i.fmt;
        end

        fpu_ext1_i.data              = data1;
        fpu_ext1_i.fmt               = fmt_ext;
        fpu_ext2_i.data              = data2;
        fpu_ext2_i.fmt               = fmt_ext;
        fpu_ext3_i.data              = data3;
        fpu_ext3_i.fmt               = fmt_ext;

        extend1                     = fpu_ext1_o.result;
        extend2                     = fpu_ext2_o.result;
        extend3                     = fpu_ext3_o.result;

        class2                      = fpu_ext2_o.classification;
        class1                      = fpu_ext1_o.classification;
        class3                      = fpu_ext3_o.classification;

        fpu_cmp_i.data1              = extend1;
        fpu_cmp_i.data2              = extend2;
        fpu_cmp_i.rm                 = rm;
        fpu_cmp_i.class1             = class1;
        fpu_cmp_i.class2             = class2;

        fpu_max_i.data1              = data1;
        fpu_max_i.data2              = data2;
        fpu_max_i.ext1               = extend1;
        fpu_max_i.ext2               = extend2;
        fpu_max_i.fmt                = fmt;
        fpu_max_i.rm                 = rm;
        fpu_max_i.class1             = class1;
        fpu_max_i.class2             = class2;

        fpu_sgnj_i.data1             = data1;
        fpu_sgnj_i.data2             = data2;
        fpu_sgnj_i.fmt               = fmt;
        fpu_sgnj_i.rm                = rm;

        fpu_fma_i.data1              = extend1;
        fpu_fma_i.data2              = extend2;
        fpu_fma_i.data3              = extend3;
        fpu_fma_i.fmt                = fmt;
        fpu_fma_i.rm                 = rm;
        fpu_fma_i.op                 = op;
        fpu_fma_i.class1             = class1;
        fpu_fma_i.class2             = class2;
        fpu_fma_i.class3             = class3;

        fpu_fdiv_i.data1             = extend1;
        fpu_fdiv_i.data2             = extend2;
        fpu_fdiv_i.fmt               = fmt;
        fpu_fdiv_i.rm                = rm;
        fpu_fdiv_i.op                = op;
        fpu_fdiv_i.class1            = class1;
        fpu_fdiv_i.class2            = class2;

        fpu_cvt_i2f_i.data           = data1;
        fpu_cvt_i2f_i.op             = op;
        fpu_cvt_i2f_i.fmt            = fmt;
        fpu_cvt_i2f_i.rm             = rm;
        fpu_cvt_i2f_i.valid          = fpu_hub_i.op.fcvt_i2f & fpu_hub_i.enable;

        fpu_cvt_f2f_i.data           = extend1;
        fpu_cvt_f2f_i.fmt            = fmt;
        fpu_cvt_f2f_i.rm             = rm;
        fpu_cvt_f2f_i.classification = class1;
        fpu_cvt_f2f_i.valid          = fpu_hub_i.op.fcvt_f2f & fpu_hub_i.enable;

        fpu_cvt_f2i_i.data           = extend1;
        fpu_cvt_f2i_i.op             = op;
        fpu_cvt_f2i_i.rm             = rm;
        fpu_cvt_f2i_i.classification = class1;
        fpu_cvt_f2i_i.valid          = fpu_hub_i.op.fcvt_f2i & fpu_hub_i.enable;

        fpu_rnd                      = init_fpu_rnd_in;
        fpu_rnd_valid                = 0;

        if (fpu_fma_o.ready) begin
            fpu_rnd = fpu_fma_o.fpu_rnd;
            fpu_rnd_valid = 1;
        end else if (fpu_fdiv_o.ready) begin
            fpu_rnd = fpu_fdiv_o.fpu_rnd;
            fpu_rnd_valid = 1;
        end else if (fpu_cvt_f2f_o.ready) begin
            fpu_rnd = fpu_cvt_f2f_o.fpu_rnd;
            fpu_rnd_valid = 1;
        end else if (fpu_cvt_i2f_o.ready) begin
            fpu_rnd = fpu_cvt_i2f_o.fpu_rnd;
            fpu_rnd_valid = 1;
        end

        fpu_rnd_i = fpu_rnd;
        fpu_rnd_i.valid = fpu_rnd_valid;


        if (fpu_rnd_o.ready) begin
            result = fpu_rnd_o.result;
            flags  = fpu_rnd_o.flags;
            ready  = 1;
        end else if (op.fmadd | op.fmsub | op.fnmadd | op.fnmsub | op.fadd | op.fadd | op.fsub | op.fmul) begin
            ready = 0;
        end else if (op.fcvt_f2i | op.fcvt_i2f | op.fcvt_f2f) begin
            ready = 0;
        end else if (op.fdiv | op.fsqrt) begin
            ready = 0;
        end else if (op.fcmp) begin
            result = fpu_cmp_o.result;
            flags  = fpu_cmp_o.flags;
        end else if (op.fsgnj) begin
            result = fpu_sgnj_o.result;
            flags  = 0;
        end else if (op.fmax) begin
            result = fpu_max_o.result;
            flags  = fpu_max_o.flags;
        end else if (op.fcmp) begin
            result = fpu_cmp_o.result;
            flags  = fpu_cmp_o.flags;
        end else if (op.fclass) begin
            result = {54'h0, class1};
            flags  = 0;
        end else if (op.fmv_f2i) begin
            result = data1;
            flags  = 0;
        end else if (op.fmv_i2f) begin
            result = data1;
            flags  = 0;
        end else if (fpu_cvt_f2i_o.ready) begin
            result = fpu_cvt_f2i_o.result;
            flags  = fpu_cvt_f2i_o.flags;
            ready  = 1;
        end

        if (clear == 1) begin
            result = 0;
            flags  = 0;
            ready  = 0;
        end

        fpu_hub_o.result = result;
        fpu_hub_o.flags  = flags;
        fpu_hub_o.ready  = ready;

    end
endmodule