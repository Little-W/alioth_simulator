module lzc_32 (
    input [31:0] data_in,
    output [4:0] lzc,
    output valid
);
  timeunit 1ns; timeprecision 1ps;

  logic [3:0] lower_half_count;   // Count from lower 16 bits
  logic [3:0] upper_half_count;   // Count from upper 16 bits

  logic lower_half_valid;         // Valid bit from lower 16 bits
  logic upper_half_valid;         // Valid bit from upper 16 bits

  logic overall_valid;            // Overall valid flag
  logic bit0_mux_sel;             // Selector for bit 0 of final count
  logic bit0_final;               // Final bit 0 of count
  logic bit1_mux_sel;             // Selector for bit 1 of final count
  logic bit1_final;               // Final bit 1 of count
  logic bit2_mux_sel;             // Selector for bit 2 of final count
  logic bit2_final;               // Final bit 2 of count
  logic bit3_mux_sel;             // Selector for bit 3 of final count
  logic bit3_final;               // Final bit 3 of count

  lzc_16 lzc_16_0 (
      .data_in(data_in[15:0]),
      .lzc(lower_half_count),
      .valid(lower_half_valid)
  );

  lzc_16 lzc_16_1 (
      .data_in(data_in[31:16]),
      .lzc(upper_half_count),
      .valid(upper_half_valid)
  );

  assign overall_valid = upper_half_valid | lower_half_valid;
  assign bit0_mux_sel = (~upper_half_valid) & lower_half_count[0];
  assign bit0_final = upper_half_count[0] | bit0_mux_sel;
  assign bit1_mux_sel = (~upper_half_valid) & lower_half_count[1];
  assign bit1_final = upper_half_count[1] | bit1_mux_sel;
  assign bit2_mux_sel = (~upper_half_valid) & lower_half_count[2];
  assign bit2_final = upper_half_count[2] | bit2_mux_sel;
  assign bit3_mux_sel = (~upper_half_valid) & lower_half_count[3];
  assign bit3_final = upper_half_count[3] | bit3_mux_sel;

  assign valid = overall_valid;
  assign lzc[0] = bit0_final;
  assign lzc[1] = bit1_final;
  assign lzc[2] = bit2_final;
  assign lzc[3] = bit3_final;
  assign lzc[4] = upper_half_valid;

endmodule
