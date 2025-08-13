module lzc_256 (
    input [255:0] data_in,
    output [7:0] lzc,
    output valid
);
  timeunit 1ns; timeprecision 1ps;

  logic [6:0] lower_half_count;   // Count from lower 128 bits
  logic [6:0] upper_half_count;   // Count from upper 128 bits

  logic lower_half_valid;         // Valid bit from lower 128 bits
  logic upper_half_valid;         // Valid bit from upper 128 bits

  logic overall_valid;            // Overall valid flag
  logic bit0_mux_sel;             // Selector for bit 0 of final count
  logic bit0_final;               // Final bit 0 of count
  logic bit1_mux_sel;             // Selector for bit 1 of final count
  logic bit1_final;               // Final bit 1 of count
  logic bit2_mux_sel;             // Selector for bit 2 of final count
  logic bit2_final;               // Final bit 2 of count
  logic bit3_mux_sel;             // Selector for bit 3 of final count
  logic bit3_final;               // Final bit 3 of count
  logic bit4_mux_sel;             // Selector for bit 4 of final count
  logic bit4_final;               // Final bit 4 of count
  logic bit5_mux_sel;             // Selector for bit 5 of final count
  logic bit5_final;               // Final bit 5 of count
  logic bit6_mux_sel;             // Selector for bit 6 of final count
  logic bit6_final;               // Final bit 6 of count
  logic unused_sig1;              // Unused signal
  logic unused_sig2;              // Unused signal

  lzc_128 lzc_128_0 (
      .data_in(data_in[127:0]),
      .lzc(lower_half_count),
      .valid(lower_half_valid)
  );

  lzc_128 lzc_128_1 (
      .data_in(data_in[255:128]),
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
  assign bit4_mux_sel = (~upper_half_valid) & lower_half_count[4];
  assign bit4_final = upper_half_count[4] | bit4_mux_sel;
  assign bit5_mux_sel = (~upper_half_valid) & lower_half_count[5];
  assign bit5_final = upper_half_count[5] | bit5_mux_sel;
  assign bit6_mux_sel = (~upper_half_valid) & lower_half_count[6];
  assign bit6_final = upper_half_count[6] | bit6_mux_sel;

  assign valid = overall_valid;
  assign lzc[0] = bit0_final;
  assign lzc[1] = bit1_final;
  assign lzc[2] = bit2_final;
  assign lzc[3] = bit3_final;
  assign lzc[4] = bit4_final;
  assign lzc[5] = bit5_final;
  assign lzc[6] = bit6_final;
  assign lzc[7] = upper_half_valid;

endmodule
