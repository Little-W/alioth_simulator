module lzc_4 (
    input [3:0] data_in,
    output [1:0] lzc,
    output valid
);
  timeunit 1ns; timeprecision 1ps;

  logic bit3_input;               // Input bit 3
  logic bit2_input;               // Input bit 2
  logic bit1_input;               // Input bit 1
  logic bit0_input;               // Input bit 0

  logic upper_half_nonzero;       // Upper 2 bits have non-zero
  logic lower_half_nonzero;       // Lower 2 bits have non-zero
  logic overall_nonzero;          // Any bit is non-zero
  logic bit0_selector;            // Selector for bit 0 of count
  logic bit0_final;               // Final bit 0 of count

  assign bit0_input = data_in[0];
  assign bit1_input = data_in[1];
  assign bit2_input = data_in[2];
  assign bit3_input = data_in[3];

  assign upper_half_nonzero = bit3_input | bit2_input;
  assign lower_half_nonzero = bit1_input | bit0_input;
  assign overall_nonzero = lower_half_nonzero | upper_half_nonzero;
  assign bit0_selector = (~upper_half_nonzero) & bit1_input;
  assign bit0_final = bit3_input | bit0_selector;

  assign valid = overall_nonzero;
  assign lzc[0] = bit0_final;
  assign lzc[1] = upper_half_nonzero;

endmodule
