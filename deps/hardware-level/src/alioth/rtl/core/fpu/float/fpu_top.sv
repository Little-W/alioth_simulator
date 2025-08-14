
// 浮点运算单元顶层模块
// 负责各浮点子模块的实例化与互联，统一调度和数据流转发
//
// 端口说明：
//   rst_n, clk      : 时钟与复位
//   fpu_top_i/o     : 主输入输出结构体
//   clear           : 清除/暂停信号

import fp_types::*;

module fpu_top (
    input                   clk,
    input                   rst_n,
    input  fpu_top_in_type  fpu_top_i,
    output fpu_top_out_type fpu_top_o,
    input                   clear
);

    fp_ext_in_type      fp_ext1_i;
    fp_ext_out_type     fp_ext1_o;
    fp_ext_in_type      fp_ext2_i;
    fp_ext_out_type     fp_ext2_o;
    fp_ext_in_type      fp_ext3_i;
    fp_ext_out_type     fp_ext3_o;

    fp_cmp_in_type      fp_cmp_i;
    fp_cmp_out_type     fp_cmp_o;
    fp_max_in_type      fp_max_i;
    fp_max_out_type     fp_max_o;
    fp_sgnj_in_type     fp_sgnj_i;
    fp_sgnj_out_type    fp_sgnj_o;
    fp_fma_in_type      fp_fma_i;
    fp_fma_out_type     fp_fma_o;
    fp_rnd_in_type      fp_rnd_i;
    fp_rnd_out_type     fp_rnd_o;

    fp_cvt_f2f_in_type  fp_cvt_f2f_i;
    fp_cvt_f2f_out_type fp_cvt_f2f_o;
    fp_cvt_f2i_in_type  fp_cvt_f2i_i;
    fp_cvt_f2i_out_type fp_cvt_f2i_o;
    fp_cvt_i2f_in_type  fp_cvt_i2f_i;
    fp_cvt_i2f_out_type fp_cvt_i2f_o;

    fp_fdiv_in_type     fp_fdiv_i;
    fp_fdiv_out_type    fp_fdiv_o;

    fp_extract fp_extract_1 (
        .fp_ext_i(fp_ext1_i),
        .fp_ext_o(fp_ext1_o)
    );

    fp_extract fp_extract_2 (
        .fp_ext_i(fp_ext2_i),
        .fp_ext_o(fp_ext2_o)
    );

    fp_extract fp_extract_3 (
        .fp_ext_i(fp_ext3_i),
        .fp_ext_o(fp_ext3_o)
    );

    fp_cmp fp_cmp (
        .fp_cmp_i(fp_cmp_i),
        .fp_cmp_o(fp_cmp_o)
    );

    fp_max fp_max (
        .fp_max_i(fp_max_i),
        .fp_max_o(fp_max_o)
    );

    fp_sgnj fp_sgnj (
        .fp_sgnj_i(fp_sgnj_i),
        .fp_sgnj_o(fp_sgnj_o)
    );

    fp_cvt fp_cvt (
        .clk         (clk),
        .rst_n       (rst_n),
        .fp_cvt_f2f_i(fp_cvt_f2f_i),
        .fp_cvt_f2f_o(fp_cvt_f2f_o),
        .fp_cvt_f2i_i(fp_cvt_f2i_i),
        .fp_cvt_f2i_o(fp_cvt_f2i_o),
        .fp_cvt_i2f_i(fp_cvt_i2f_i),
        .fp_cvt_i2f_o(fp_cvt_i2f_o)
    );

    fp_fma fp_fma (
        .clk     (clk),
        .rst_n   (rst_n),
        .fp_fma_i(fp_fma_i),
        .fp_fma_o(fp_fma_o),
        .clear   (clear)
    );

    fp_fdiv fp_fdiv (
        .clk      (clk),
        .rst_n    (rst_n),
        .fp_fdiv_i(fp_fdiv_i),
        .fp_fdiv_o(fp_fdiv_o),
        .clear    (clear)
    );

    fp_rnd fp_rnd (
        .clk     (clk),
        .rst_n   (rst_n),
        .fp_rnd_i(fp_rnd_i),
        .fp_rnd_o(fp_rnd_o)
    );

    fp_hub fp_hub (
        .fp_hub_i    (fpu_top_i.fp_hub_i),
        .fp_hub_o    (fpu_top_o.fp_hub_o),
        .fp_ext1_o   (fp_ext1_o),
        .fp_ext1_i   (fp_ext1_i),
        .fp_ext2_o   (fp_ext2_o),
        .fp_ext2_i   (fp_ext2_i),
        .fp_ext3_o   (fp_ext3_o),
        .fp_ext3_i   (fp_ext3_i),
        .fp_cmp_o    (fp_cmp_o),
        .fp_cmp_i    (fp_cmp_i),
        .fp_max_o    (fp_max_o),
        .fp_max_i    (fp_max_i),
        .fp_sgnj_o   (fp_sgnj_o),
        .fp_sgnj_i   (fp_sgnj_i),
        .fp_cvt_f2f_i(fp_cvt_f2f_i),
        .fp_cvt_f2f_o(fp_cvt_f2f_o),
        .fp_cvt_f2i_i(fp_cvt_f2i_i),
        .fp_cvt_f2i_o(fp_cvt_f2i_o),
        .fp_cvt_i2f_i(fp_cvt_i2f_i),
        .fp_cvt_i2f_o(fp_cvt_i2f_o),
        .fp_fma_o    (fp_fma_o),
        .fp_fma_i    (fp_fma_i),
        .fp_fdiv_o   (fp_fdiv_o),
        .fp_fdiv_i   (fp_fdiv_i),
        .fp_rnd_o    (fp_rnd_o),
        .fp_rnd_i    (fp_rnd_i),
        .clear       (clear)
    );

endmodule
