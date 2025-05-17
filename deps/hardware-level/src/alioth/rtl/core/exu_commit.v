// `include "defines.v"


// module exu_commit(

//     input wire clk,
//     input wire rst,

//     input wire req_muldiv_i,
//     input wire muldiv_reg_we_i,
//     input wire[4:0] muldiv_reg_waddr_i,
//     input wire[31:0] muldiv_reg_wdata_i,

//     input wire req_mem_i,
//     input wire mem_reg_we_i,
//     input wire[4:0] mem_reg_waddr_i,
//     input wire[31:0] mem_reg_wdata_i,

//     input wire req_csr_i,
//     input wire csr_reg_we_i,
//     input wire[4:0] csr_reg_waddr_i,
//     input wire[31:0] csr_reg_wdata_i,

//     input wire req_bjp_i,
//     input wire bjp_reg_we_i,
//     input wire[31:0] bjp_reg_wdata_i,
//     input wire[4:0] bjp_reg_waddr_i,

//     input wire rd_we_i,
//     input wire[4:0] rd_waddr_i,
//     input wire[31:0] alu_reg_wdata_i,

//     output wire reg_we_o,
//     output wire[4:0] reg_waddr_o,
//     output wire[31:0] reg_wdata_o

//     );

//     wire use_alu_res = (~req_muldiv_i) &
//                        (~req_mem_i) &
//                        (~req_csr_i) &
//                        (~req_bjp_i);

//     assign reg_we_o = muldiv_reg_we_i | mem_reg_we_i | csr_reg_we_i | use_alu_res | bjp_reg_we_i;

//     reg[4:0] reg_waddr;

//     always @ (*) begin
//         reg_waddr = 5'h0;
//         case (1'b1)
//             muldiv_reg_we_i: reg_waddr = muldiv_reg_waddr_i;
//             mem_reg_we_i:    reg_waddr = mem_reg_waddr_i;
//             csr_reg_we_i:    reg_waddr = csr_reg_waddr_i;
//             bjp_reg_we_i:    reg_waddr = bjp_reg_waddr_i;
//             rd_we_i:         reg_waddr = rd_waddr_i;
//         endcase
//     end

//     assign reg_waddr_o = reg_waddr;

//     reg[31:0] reg_wdata;

//     always @ (*) begin
//         reg_wdata = 32'h0;
//         case (1'b1)
//             muldiv_reg_we_i: reg_wdata = muldiv_reg_wdata_i;
//             mem_reg_we_i:    reg_wdata = mem_reg_wdata_i;
//             csr_reg_we_i:    reg_wdata = csr_reg_wdata_i;
//             bjp_reg_we_i:    reg_wdata = bjp_reg_wdata_i;
//             use_alu_res:     reg_wdata = alu_reg_wdata_i;
//         endcase
//     end

//     assign reg_wdata_o = reg_wdata;

// endmodule
