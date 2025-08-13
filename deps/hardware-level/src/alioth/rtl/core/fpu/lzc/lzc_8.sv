module lzc_8 (
    input [7:0] data_in,
    output [2:0] lzc,
    output valid
);
  timeunit 1ns; timeprecision 1ps;

  logic [1:0] lower_half_count;   // Count from lower 4 bits
  logic [1:0] upper_half_count;   // Count from upper 4 bits

  logic lower_half_valid;         // Valid bit from lower 4 bits
  logic upper_half_valid;         // Valid bit from upper 4 bits

  logic overall_valid;            // Overall valid flag
  logic bit0_mux_sel;             // Selector for bit 0 of final count
  logic bit0_final;               // Final bit 0 of count
  logic bit1_mux_sel;             // Selector for bit 1 of final count
  logic bit1_final;               // Final bit 1 of count

  lzc_4 lzc_4_0 (
      .data_in(data_in[3:0]),
      .lzc(lower_half_count),
      .valid(lower_half_valid)
  );

  lzc_4 lzc_4_1 (
      .data_in(data_in[7:4]),
      .lzc(upper_half_count),
      .valid(upper_half_valid)
  );

  assign overall_valid = upper_half_valid | lower_half_valid;
  assign bit0_mux_sel = (~upper_half_valid) & lower_half_count[0];
  assign bit0_final = upper_half_count[0] | bit0_mux_sel;
  assign bit1_mux_sel = (~upper_half_valid) & lower_half_count[1];
  assign bit1_final = upper_half_count[1] | bit1_mux_sel;

  assign valid = overall_valid;
  assign lzc[0] = bit0_final;
  assign lzc[1] = bit1_final;
  assign lzc[2] = upper_half_valid;

endmodule
