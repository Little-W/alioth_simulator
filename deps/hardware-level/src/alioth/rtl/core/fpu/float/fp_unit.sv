
// 浮点运算单元顶层模块
// 负责各浮点子模块的实例化与互联，统一调度和数据流转发
//
// 端口说明：
//   rst_n, clk      : 时钟与复位
//   fp_unit_i/o     : 主输入输出结构体
//   clear           : 清除/暂停信号

import lzc_types::*;
import fp_types::*;

module fp_unit (
    input clk,
    input rst_n,
    input fp_unit_in_type fp_unit_i,
    output fp_unit_out_type fp_unit_o,
    input clear
);
  timeunit 1ns; timeprecision 1ps;

  lzc_64_in_type lzc1_64_i;
  lzc_64_out_type lzc1_64_o;
  lzc_64_in_type lzc2_64_i;
  lzc_64_out_type lzc2_64_o;
  lzc_64_in_type lzc3_64_i;
  lzc_64_out_type lzc3_64_o;
  lzc_64_in_type lzc4_64_i;
  lzc_64_out_type lzc4_64_o;

  fp_ext_in_type fp_ext1_i;
  fp_ext_out_type fp_ext1_o;
  fp_ext_in_type fp_ext2_i;
  fp_ext_out_type fp_ext2_o;
  fp_ext_in_type fp_ext3_i;
  fp_ext_out_type fp_ext3_o;

  fp_cmp_in_type fp_cmp_i;
  fp_cmp_out_type fp_cmp_o;
  fp_max_in_type fp_max_i;
  fp_max_out_type fp_max_o;
  fp_sgnj_in_type fp_sgnj_i;
  fp_sgnj_out_type fp_sgnj_o;
  fp_fma_in_type fp_fma_i;
  fp_fma_out_type fp_fma_o;
  fp_rnd_in_type fp_rnd_i;
  fp_rnd_out_type fp_rnd_o;

  fp_cvt_f2f_in_type fp_cvt_f2f_i;
  fp_cvt_f2f_out_type fp_cvt_f2f_o;
  fp_cvt_f2i_in_type fp_cvt_f2i_i;
  fp_cvt_f2i_out_type fp_cvt_f2i_o;
  fp_cvt_i2f_in_type fp_cvt_i2f_i;
  fp_cvt_i2f_out_type fp_cvt_i2f_o;

  fp_fdiv_in_type fp_fdiv_i;
  fp_fdiv_out_type fp_fdiv_o;

  lzc_64 lzc_64_1 (
      .data_in(lzc1_64_i.data_in),
      .lzc(lzc1_64_o.lzc),
      .valid(lzc1_64_o.valid)
  );

  lzc_64 lzc_64_2 (
      .data_in(lzc2_64_i.data_in),
      .lzc(lzc2_64_o.lzc),
      .valid(lzc2_64_o.valid)
  );

  lzc_64 lzc_64_3 (
      .data_in(lzc3_64_i.data_in),
      .lzc(lzc3_64_o.lzc),
      .valid(lzc3_64_o.valid)
  );

  lzc_64 lzc_64_4 (
      .data_in(lzc4_64_i.data_in),
      .lzc(lzc4_64_o.lzc),
      .valid(lzc4_64_o.valid)
  );

  fp_ext fp_ext_1 (
      .fp_ext_i(fp_ext1_i),
      .fp_ext_o(fp_ext1_o),
      .lzc_o(lzc1_64_o),
      .lzc_i(lzc1_64_i)
  );

  fp_ext fp_ext_2 (
      .fp_ext_i(fp_ext2_i),
      .fp_ext_o(fp_ext2_o),
      .lzc_o(lzc2_64_o),
      .lzc_i(lzc2_64_i)
  );

  fp_ext fp_ext_3 (
      .fp_ext_i(fp_ext3_i),
      .fp_ext_o(fp_ext3_o),
      .lzc_o(lzc3_64_o),
      .lzc_i(lzc3_64_i)
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
      .fp_cvt_f2f_i(fp_cvt_f2f_i),
      .fp_cvt_f2f_o(fp_cvt_f2f_o),
      .fp_cvt_f2i_i(fp_cvt_f2i_i),
      .fp_cvt_f2i_o(fp_cvt_f2i_o),
      .fp_cvt_i2f_i(fp_cvt_i2f_i),
      .fp_cvt_i2f_o(fp_cvt_i2f_o),
      .lzc_o(lzc4_64_o),
      .lzc_i(lzc4_64_i)
  );

  fp_fma fp_fma (
      .rst_n(rst_n),
      .clk(clk),
      .fp_fma_i(fp_fma_i),
      .fp_fma_o(fp_fma_o),
      .clear(clear)
  );

  fp_fdiv fp_fdiv (
      .rst_n(rst_n),
      .clk(clk),
      .fp_fdiv_i(fp_fdiv_i),
      .fp_fdiv_o(fp_fdiv_o),
      .clear(clear)
  );

  fp_rnd fp_rnd (
      .fp_rnd_i(fp_rnd_i),
      .fp_rnd_o(fp_rnd_o)
  );

  fp_exe fp_exe (
      .fp_exe_i(fp_unit_i.fp_exe_i),
      .fp_exe_o(fp_unit_o.fp_exe_o),
      .fp_ext1_o(fp_ext1_o),
      .fp_ext1_i(fp_ext1_i),
      .fp_ext2_o(fp_ext2_o),
      .fp_ext2_i(fp_ext2_i),
      .fp_ext3_o(fp_ext3_o),
      .fp_ext3_i(fp_ext3_i),
      .fp_cmp_o(fp_cmp_o),
      .fp_cmp_i(fp_cmp_i),
      .fp_max_o(fp_max_o),
      .fp_max_i(fp_max_i),
      .fp_sgnj_o(fp_sgnj_o),
      .fp_sgnj_i(fp_sgnj_i),
      .fp_cvt_f2f_i(fp_cvt_f2f_i),
      .fp_cvt_f2f_o(fp_cvt_f2f_o),
      .fp_cvt_f2i_i(fp_cvt_f2i_i),
      .fp_cvt_f2i_o(fp_cvt_f2i_o),
      .fp_cvt_i2f_i(fp_cvt_i2f_i),
      .fp_cvt_i2f_o(fp_cvt_i2f_o),
      .fp_fma_o(fp_fma_o),
      .fp_fma_i(fp_fma_i),
      .fp_fdiv_o(fp_fdiv_o),
      .fp_fdiv_i(fp_fdiv_i),
      .fp_rnd_o(fp_rnd_o),
      .fp_rnd_i(fp_rnd_i),
      .clear(clear)
  );

endmodule
