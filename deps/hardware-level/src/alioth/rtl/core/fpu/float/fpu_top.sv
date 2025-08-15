
// 浮点运算单元顶层模块
// 负责各浮点子模块的实例化与互联，统一调度和数据流转发
//
// 端口说明：
//   rst_n, clk      : 时钟与复位
//   fpu_top_i/o     : 主输入输出结构体
//   clear           : 清除/暂停信号

import fpu_types::*;

module fpu_top (
    input                   clk,
    input                   rst_n,
    input  fpu_top_in_type  fpu_top_i,
    output fpu_top_out_type fpu_top_o,
    input                   clear
);

    fpu_ext_in_type      fpu_ext1_i;
    fpu_ext_out_type     fpu_ext1_o;
    fpu_ext_in_type      fpu_ext2_i;
    fpu_ext_out_type     fpu_ext2_o;
    fpu_ext_in_type      fpu_ext3_i;
    fpu_ext_out_type     fpu_ext3_o;

    fpu_cmp_in_type      fpu_cmp_i;
    fpu_cmp_out_type     fpu_cmp_o;
    fpu_max_in_type      fpu_max_i;
    fpu_max_out_type     fpu_max_o;
    fpu_sgnj_in_type     fpu_sgnj_i;
    fpu_sgnj_out_type    fpu_sgnj_o;
    fpu_fma_in_type      fpu_fma_i;
    fpu_fma_out_type     fpu_fma_o;
    fpu_rnd_in_type      fpu_rnd_i;
    fpu_rnd_out_type     fpu_rnd_o;

    fpu_cvt_f2f_in_type  fpu_cvt_f2f_i;
    fpu_cvt_f2f_out_type fpu_cvt_f2f_o;
    fpu_cvt_f2i_in_type  fpu_cvt_f2i_i;
    fpu_cvt_f2i_out_type fpu_cvt_f2i_o;
    fpu_cvt_i2f_in_type  fpu_cvt_i2f_i;
    fpu_cvt_i2f_out_type fpu_cvt_i2f_o;

    fpu_fdiv_in_type     fpu_fdiv_i;
    fpu_fdiv_out_type    fpu_fdiv_o;

    fpu_extract fpu_extract_1 (
        .fpu_ext_i(fpu_ext1_i),
        .fpu_ext_o(fpu_ext1_o)
    );

    fpu_extract fpu_extract_2 (
        .fpu_ext_i(fpu_ext2_i),
        .fpu_ext_o(fpu_ext2_o)
    );

    fpu_extract fpu_extract_3 (
        .fpu_ext_i(fpu_ext3_i),
        .fpu_ext_o(fpu_ext3_o)
    );

    fpu_cmp fpu_cmp (
        .fpu_cmp_i(fpu_cmp_i),
        .fpu_cmp_o(fpu_cmp_o)
    );

    fpu_max fpu_max (
        .fpu_max_i(fpu_max_i),
        .fpu_max_o(fpu_max_o)
    );

    fpu_sgnj fpu_sgnj (
        .fpu_sgnj_i(fpu_sgnj_i),
        .fpu_sgnj_o(fpu_sgnj_o)
    );

    fpu_cvt fpu_cvt (
        .clk         (clk),
        .rst_n       (rst_n),
        .fpu_cvt_f2f_i(fpu_cvt_f2f_i),
        .fpu_cvt_f2f_o(fpu_cvt_f2f_o),
        .fpu_cvt_f2i_i(fpu_cvt_f2i_i),
        .fpu_cvt_f2i_o(fpu_cvt_f2i_o),
        .fpu_cvt_i2f_i(fpu_cvt_i2f_i),
        .fpu_cvt_i2f_o(fpu_cvt_i2f_o)
    );

    fpu_fma fpu_fma (
        .clk     (clk),
        .rst_n   (rst_n),
        .fpu_fma_i(fpu_fma_i),
        .fpu_fma_o(fpu_fma_o),
        .clear   (clear)
    );

    fpu_fdiv fpu_fdiv (
        .clk      (clk),
        .rst_n    (rst_n),
        .fpu_fdiv_i(fpu_fdiv_i),
        .fpu_fdiv_o(fpu_fdiv_o),
        .clear    (clear)
    );

    fpu_rnd fpu_rnd (
        .clk     (clk),
        .rst_n   (rst_n),
        .fpu_rnd_i(fpu_rnd_i),
        .fpu_rnd_o(fpu_rnd_o)
    );

    fpu_hub fpu_hub (
        .fpu_hub_i    (fpu_top_i.fpu_hub_i),
        .fpu_hub_o    (fpu_top_o.fpu_hub_o),
        .fpu_ext1_o   (fpu_ext1_o),
        .fpu_ext1_i   (fpu_ext1_i),
        .fpu_ext2_o   (fpu_ext2_o),
        .fpu_ext2_i   (fpu_ext2_i),
        .fpu_ext3_o   (fpu_ext3_o),
        .fpu_ext3_i   (fpu_ext3_i),
        .fpu_cmp_o    (fpu_cmp_o),
        .fpu_cmp_i    (fpu_cmp_i),
        .fpu_max_o    (fpu_max_o),
        .fpu_max_i    (fpu_max_i),
        .fpu_sgnj_o   (fpu_sgnj_o),
        .fpu_sgnj_i   (fpu_sgnj_i),
        .fpu_cvt_f2f_i(fpu_cvt_f2f_i),
        .fpu_cvt_f2f_o(fpu_cvt_f2f_o),
        .fpu_cvt_f2i_i(fpu_cvt_f2i_i),
        .fpu_cvt_f2i_o(fpu_cvt_f2i_o),
        .fpu_cvt_i2f_i(fpu_cvt_i2f_i),
        .fpu_cvt_i2f_o(fpu_cvt_i2f_o),
        .fpu_fma_o    (fpu_fma_o),
        .fpu_fma_i    (fpu_fma_i),
        .fpu_fdiv_o   (fpu_fdiv_o),
        .fpu_fdiv_i   (fpu_fdiv_i),
        .fpu_rnd_o    (fpu_rnd_o),
        .fpu_rnd_i    (fpu_rnd_i),
        .clear       (clear)
    );

endmodule
