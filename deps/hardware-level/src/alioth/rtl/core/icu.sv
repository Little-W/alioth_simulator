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
    input wire [ 31:0] inst1_csr_waddr_i,
    input wire [ 31:0] inst1_csr_raddr_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst1_i,
    input wire                        inst1_illegal_inst_i,
    input wire                        inst1_valid_i,
    input wire                        inst1_jump_i,        // 新增：指令有效输入
    input wire                        inst1_branch_i,      // 新增：分支指令信号输入
    input wire                        inst1_csr_type_i,   // 新增：CSR指令类型输入

    // from idu - 第二路
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [ 31:0] inst2_csr_waddr_i,
    input wire [ 31:0] inst2_csr_raddr_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    input wire                        inst2_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst2_i,
    input wire                        inst2_illegal_inst_i,
    input wire                        inst2_valid_i,
    input wire                        inst2_csr_type_i,

    // 指令完成信号
    input wire                        commit_valid_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,
    input wire                        commit_valid2_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id2_i,
    
    // from control 控制信号
    input wire [`CU_BUS_WIDTH-1:0]   stall_flag_i,
    input wire                       jump_flag_i,  
    // 中断请求有效信号
    input wire clint_req_valid_i,  
    
    // 发射指令的完整decode信息- to dispatch
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,
    output wire                        inst1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_o,
    output wire [ 31:0] inst1_csr_waddr_o,
    output wire [ 31:0] inst1_csr_raddr_o,
    output wire                        inst1_csr_we_o,
    output wire [                31:0] inst1_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o,
    output wire                        inst1_is_pred_branch_o,
    output wire [`INST_DATA_WIDTH-1:0] inst1_o,
    output wire                        inst1_illegal_inst_o,
    output wire                        inst1_valid_o,
    
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,
    output wire                        inst2_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_o,
    output wire [ 31:0] inst2_csr_waddr_o,
    output wire [ 31:0] inst2_csr_raddr_o,
    output wire                        inst2_csr_we_o,
    output wire [                31:0] inst2_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o,
    output wire                        inst2_is_pred_branch_o,
    output wire [`INST_DATA_WIDTH-1:0] inst2_o,
    output wire                        inst2_illegal_inst_o,
    output wire                        inst2_valid_o,
    
    // HDU输出信号 - to control
    output wire [1:0]                  issue_inst_o,
,
    // HDU输出信号 - to dispatch
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,
    output wire                        long_inst_atom_lock_o
);


    // hdu与icu_issue之间的连线
    wire [1:0] issue_inst;
    wire [`COMMIT_ID_WIDTH-1:0] hdu_inst1_commit_id_o; 
    wire [`COMMIT_ID_WIDTH-1:0] hdu_inst2_commit_id_o;
    wire jump_inst1_valid_o;
    wire jump_inst2_valid_o;
    wire [`COMMIT_ID_WIDTH-1:0] jump_inst1_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] jump_inst2_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] pending_inst1_commit_id_o;
    wire idu_flush = |stall_flag_i;
    wire hdu_inst1_valid = inst1_valid_i && !stall_flag_i && !clint_req_valid_i;
    wire hdu_inst2_valid = inst2_valid_i && !stall_flag_i && !clint_req_valid_i;
    assign issue_inst_o  = issue_inst;

    // 实例化hdu模块
    hdu u_hdu (
        .clk                    (clk),
        .rst_n                  (rst_n),
        
        // 指令1输入信号
        .inst1_valid            (hdu_inst1_valid),
        .inst1_rd_addr          (inst1_reg_waddr_i),
        .inst1_rs1_addr         (inst1_reg1_raddr_i),
        .inst1_rs2_addr         (inst1_reg2_raddr_i),
        .inst1_rd_we            (inst1_reg_we_i),

        // 指令2输入信号
        .inst2_valid            (hdu_inst2_valid),
        .inst2_rd_addr          (inst2_reg_waddr_i),
        .inst2_rs1_addr         (inst2_reg1_raddr_i),
        .inst2_rs2_addr         (inst2_reg2_raddr_i),
        .inst2_rd_we            (inst2_reg_we_i),

        // 指令完成信号
        .commit_valid_i         (commit_valid_i),
        .commit_id_i            (commit_id_i),
        .commit_valid2_i        (commit_valid2_i),
        .commit_id2_i           (commit_id2_i),
        .jump_commit_valid_i    (jump_inst1_valid_o),
        .jump_commit_id_i       (jump_inst1_commit_id_o),
        .jump_commit_valid2_i   (jump_inst2_valid_o),
        .jump_commit_id2_i      (jump_inst2_commit_id_o),
        .pending_inst1_id_i      (pending_inst1_commit_id_o),

        //跳转控制
        .jump_flag_i            (jump_flag_i),
        .idu_flush_i            (idu_flush),
        .inst1_jump_i           (inst1_jump_i),
        .inst1_branch_i         (inst1_branch_i),

        .inst1_csr_type_i       (inst1_csr_type_i),
        .inst2_csr_type_i       (inst2_csr_type_i),
        .clint_req_valid        (clint_req_valid_i),

        // 输出信号
        //to ctrl & icu_issue
        .issue_inst_o           (issue_inst),

        //to irf
        .inst1_commit_id_o      (hdu_inst1_commit_id_o),
        .inst2_commit_id_o      (hdu_inst2_commit_id_o),
        .long_inst_atom_lock_o  (long_inst_atom_lock_o)
    );


    // 实例化icu_issue模块
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
        .inst1_i                (inst1_i),

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
        .inst2_i                (inst2_i),
        
        // from hdu
        .issue_inst_i           (issue_inst),
        .jump_flag_i            (jump_flag_i),  // 跳转标志

        // 流水线寄存器相关输入
        .hdu_inst1_commit_id_i  (hdu_inst1_commit_id_o),
        .hdu_inst2_commit_id_i  (hdu_inst2_commit_id_o),
        
        // from control
        .stall_flag_i           (stall_flag_i),

        .inst1_illegal_inst_i    (inst1_illegal_inst_i),
        .inst2_illegal_inst_i    (inst2_illegal_inst_i),
        .clint_req_valid_i       (clint_req_valid_i),

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
        .inst1_o                (inst1_o),
   
        
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
        .inst2_is_pred_branch_o (inst2_is_pred_branch_o),
        .inst2_o                (inst2_o),

        .jump_inst1_commit_id_o  (jump_inst1_commit_id_o),
        .jump_inst2_commit_id_o  (jump_inst2_commit_id_o),
        .jump_inst1_valid_o      (jump_inst1_valid_o),
        .jump_inst2_valid_o      (jump_inst2_valid_o),
        .pending_inst1_commit_id_o (pending_inst1_commit_id_o),

        // 流水线寄存器相关输出
        .inst1_commit_id_o      (inst1_commit_id_o),
        .inst2_commit_id_o      (inst2_commit_id_o),
        .inst1_illegal_inst_o   (inst1_illegal_inst_o),
        .inst2_illegal_inst_o   (inst2_illegal_inst_o),
        .inst1_valid_o          (inst1_valid_o),
        .inst2_valid_o          (inst2_valid_o)
    );

endmodule