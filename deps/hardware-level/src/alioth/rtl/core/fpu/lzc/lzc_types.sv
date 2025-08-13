package lzc_types;
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {logic [63:0] data_in;} lzc_64_in_type;

  typedef struct packed {
    logic [5:0] lzc;
    logic valid;
  } lzc_64_out_type;

  typedef struct packed {logic [255:0] data_in;} lzc_256_in_type;

  typedef struct packed {
    logic [7:0] lzc;
    logic valid;
  } lzc_256_out_type;

endpackage
