/*         
 The MIT License (MIT)

 Copyright © 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
                                                                         
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
                                                                         
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "defines.svh"

//指令控制单元顶层模块
module icu (
    input wire clk,
    input wire rst_n,

    // from idu
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i,
    input wire                        inst1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_i,
    input wire                        inst1_csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_waddr_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_raddr_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,

    // from idu - 第二路
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_waddr_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_raddr_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    input wire                        inst2_is_pred_branch_i,
    
    // 指令有效信号
    input wire                        inst1_valid_i,
    input wire                        inst2_valid_i,
    
    // 指令完成信号
    input wire                        commit_valid_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,
    input wire                        commit_valid2_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id2_i,
    
    // from control 控制信号
    input wire [`CU_BUS_WIDTH-1:0]   stall_flag_i,
    
    // 发射指令的完整decode信息
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,
    output wire                        inst1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_waddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst1_csr_raddr_o,
    output wire                        inst1_csr_we_o,
    output wire [                31:0] inst1_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o,
    output wire                        inst1_is_pred_branch_o,
    
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,
    output wire                        inst2_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_waddr_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] inst2_csr_raddr_o,
    output wire                        inst2_csr_we_o,
    output wire [                31:0] inst2_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o,
    output wire                        inst2_is_pred_branch_o,
    
    // HDU输出信号
    output wire                        new_issue_stall_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,
    output wire                        long_inst_atom_lock_o,
    
    // 新增输出信号给WBU
    output wire [`REG_ADDR_WIDTH-1:0] inst1_rd_addr_o,
    output wire [`REG_ADDR_WIDTH-1:0] inst2_rd_addr_o,
    output wire [31:0] inst1_timestamp_o,
    output wire [31:0] inst2_timestamp_o
);

    // hdu与icu_issue之间的连线
    wire [1:0] issue_inst;
    wire [`COMMIT_ID_WIDTH-1:0] hdu_inst1_commit_id_o; 
    wire [`COMMIT_ID_WIDTH-1:0] hdu_inst2_commit_id_o;

    wire flush_en = stall_flag_i[`CU_FLUSH];
    wire other_stall_en = stall_flag_i[`CU_STALL_DISPATCH];
    wire update_id1 = issue_inst_i[0] & (~other_stall_en);
    wire update_id2 = issue_inst_i[1] & (~other_stall_en);



    // 实例化hdu模块
    hdu u_hdu (
        .clk                    (clk),
        .rst_n                  (rst_n),
        
        // 指令1输入信号
        .inst1_valid            (inst1_valid_i),
        .inst1_rd_addr          (inst1_reg_waddr_i),
        .inst1_rs1_addr         (inst1_reg1_raddr_i),
        .inst1_rs2_addr         (inst1_reg2_raddr_i),
        .inst1_rd_we            (inst1_reg_we_i),
        
        // 指令2输入信号
        .inst2_valid            (inst2_valid_i),
        .inst2_rd_addr          (inst2_reg_waddr_i),
        .inst2_rs1_addr         (inst2_reg1_raddr_i),
        .inst2_rs2_addr         (inst2_reg2_raddr_i),
        .inst2_rd_we            (inst2_reg_we_i),
        
        // 指令完成信号
        .commit_valid_i         (commit_valid_i),
        .commit_id_i            (commit_id_i),
        .commit_valid2_i        (commit_valid2_i),
        .commit_id2_i           (commit_id2_i),
        
        // 输出信号
        //to ctrl
        .new_issue_stall_o      (new_issue_stall_o),
        //to icu_issue
        .issue_inst_o           (issue_inst),
        //to irf
        .inst1_commit_id_o      (hdu_inst1_commit_id_o),
        .inst2_commit_id_o      (hdu_inst2_commit_id_o),
        .long_inst_atom_lock_o  (long_inst_atom_lock_o),
        
        // 新增输出信号给WBU
        .inst1_rd_addr_o        (inst1_rd_addr_o),
        .inst2_rd_addr_o        (inst2_rd_addr_o),
        .inst1_timestamp        (inst1_timestamp_o),
        .inst2_timestamp        (inst2_timestamp_o)
    );


    wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_nxt = flush_en ? 3'b0 : hdu_inst1_commit_id_o; 
    wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id;
    gnrl_dfflr #(`COMMIT_ID_WIDTH) inst1_commit_id_ff (
        clk,
        rst_n,
        update_id1,
        inst1_commit_id_nxt,
        inst1_commit_id
    );
    assign inst1_commit_id_o = inst1_commit_id;

    wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_nxt = flush_en ? 3'b0 : hdu_inst2_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id;
    gnrl_dfflr #(`COMMIT_ID_WIDTH) inst2_commit_id_ff (
        clk,
        rst_n,
        update_id2,
        inst2_commit_id_nxt,
        inst2_commit_id
    );
    assign inst2_commit_id_o = inst2_commit_id;


    // 实例化icu_issue模块模块
    icu_issue u_icu_issue (
        .clk                    (clk),
        .rst_n                  (rst_n),
        
        // from idu
        .inst1_addr_i           (inst1_addr_i),
        .inst1_reg_we_i         (inst1_reg_we_i),
        .inst1_reg_waddr_i      (inst1_reg_waddr_i),
        .inst1_reg1_raddr_i     (inst1_reg1_raddr_i),
        .inst1_reg2_raddr_i     (inst1_reg2_raddr_i),
        .inst1_csr_we_i         (inst1_csr_we_i),
        .inst1_csr_waddr_i      (inst1_csr_waddr_i),
        .inst1_csr_raddr_i      (inst1_csr_raddr_i),
        .inst1_dec_imm_i        (inst1_dec_imm_i),
        .inst1_dec_info_bus_i   (inst1_dec_info_bus_i),
        .inst1_is_pred_branch_i (inst1_is_pred_branch_i),
        
        .inst2_addr_i           (inst2_addr_i),
        .inst2_reg_we_i         (inst2_reg_we_i),
        .inst2_reg_waddr_i      (inst2_reg_waddr_i),
        .inst2_reg1_raddr_i     (inst2_reg1_raddr_i),
        .inst2_reg2_raddr_i     (inst2_reg2_raddr_i),
        .inst2_csr_we_i         (inst2_csr_we_i),
        .inst2_csr_waddr_i      (inst2_csr_waddr_i),
        .inst2_csr_raddr_i      (inst2_csr_raddr_i),
        .inst2_dec_imm_i        (inst2_dec_imm_i),
        .inst2_dec_info_bus_i   (inst2_dec_info_bus_i),
        .inst2_is_pred_branch_i (inst2_is_pred_branch_i),
        
        // from hdu
        .issue_inst_i           (issue_inst),
        
        // from control
        .stall_flag_i           (stall_flag_i),
        
        // outputs
        .inst1_addr_o           (inst1_addr_o),
        .inst1_reg_we_o         (inst1_reg_we_o),
        .inst1_reg_waddr_o      (inst1_reg_waddr_o),
        .inst1_reg1_raddr_o     (inst1_reg1_raddr_o),
        .inst1_reg2_raddr_o     (inst1_reg2_raddr_o),
        .inst1_csr_waddr_o      (inst1_csr_waddr_o),
        .inst1_csr_raddr_o      (inst1_csr_raddr_o),
        .inst1_csr_we_o         (inst1_csr_we_o),
        .inst1_dec_imm_o        (inst1_dec_imm_o),
        .inst1_dec_info_bus_o   (inst1_dec_info_bus_o),
        .inst1_is_pred_branch_o (inst1_is_pred_branch_o),
        
        .inst2_addr_o           (inst2_addr_o),
        .inst2_reg_we_o         (inst2_reg_we_o),
        .inst2_reg_waddr_o      (inst2_reg_waddr_o),
        .inst2_reg1_raddr_o     (inst2_reg1_raddr_o),
        .inst2_reg2_raddr_o     (inst2_reg2_raddr_o),
        .inst2_csr_waddr_o      (inst2_csr_waddr_o),
        .inst2_csr_raddr_o      (inst2_csr_raddr_o),
        .inst2_csr_we_o         (inst2_csr_we_o),
        .inst2_dec_imm_o        (inst2_dec_imm_o),
        .inst2_dec_info_bus_o   (inst2_dec_info_bus_o),
        .inst2_is_pred_branch_o (inst2_is_pred_branch_o)
    );

endmodule