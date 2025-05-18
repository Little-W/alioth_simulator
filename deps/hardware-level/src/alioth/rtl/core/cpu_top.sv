/*                                                                      
 Copyright 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "defines.svh"

// alioth处理器核顶层模块
module cpu_top (

    input wire clk,
    input wire rst_n

);

    // pc_reg模块输出信号
    wire [`INST_ADDR_WIDTH-1:0] pc_pc_o;

    // if_id模块输出信号
    wire [`INST_DATA_WIDTH-1:0] if_inst_o;
    wire [`INST_ADDR_WIDTH-1:0] if_inst_addr_o;
    wire [`INST_DATA_WIDTH-1:0] if_int_flag_o;  

    // idu模块输出信号
    wire [ `REG_ADDR_WIDTH-1:0] idu_reg1_raddr_o;
    wire [ `REG_ADDR_WIDTH-1:0] idu_reg2_raddr_o;
    wire [ `BUS_ADDR_WIDTH-1:0] idu_csr_raddr_o;
    wire [`INST_DATA_WIDTH-1:0] idu_inst_o;
    wire [`INST_ADDR_WIDTH-1:0] idu_inst_addr_o;
    wire                        idu_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] idu_reg_waddr_o;
    wire [ `REG_DATA_WIDTH-1:0] idu_reg1_rdata_o;
    wire [ `REG_DATA_WIDTH-1:0] idu_reg2_rdata_o;
    wire                        idu_csr_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] idu_csr_waddr_o;
    wire [ `REG_DATA_WIDTH-1:0] idu_csr_rdata_o;
    wire [                31:0] idu_dec_imm_o;
    wire [  `DECINFO_WIDTH-1:0] idu_dec_info_bus_o;
    wire                        idu_hdu_hold_flag_o; // 新增HDU相关信号

    // exu模块输出信号
    wire [ `BUS_DATA_WIDTH-1:0] exu_mem_wdata_o;
    wire [ `BUS_ADDR_WIDTH-1:0] exu_mem_raddr_o;
    wire [ `BUS_ADDR_WIDTH-1:0] exu_mem_waddr_o;
    wire                        exu_mem_we_o;
    wire                        exu_mem_req_o;
    wire [                 3:0] exu_mem_wmask_o;
    wire [ `REG_DATA_WIDTH-1:0] exu_reg_wdata_o;
    wire                        exu_reg_we_o;
    wire [ `REG_ADDR_WIDTH-1:0] exu_reg_waddr_o;
    wire                        exu_hold_flag_o;
    wire                        exu_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;
    wire [ `REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire                        exu_csr_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;
    wire                        exu_div_started_o;
    wire                        exu_inst_ecall_o;
    wire                        exu_inst_ebreak_o;
    wire                        exu_inst_mret_o;
    wire                        exu_inst_dret_o;
    wire                        exu_wb_done_o; // 新增写回完成信号

    // regs模块输出信号
    wire [ `REG_DATA_WIDTH-1:0] regs_rdata1_o;
    wire [ `REG_DATA_WIDTH-1:0] regs_rdata2_o;

    // csr_reg模块输出信号
    wire [ `REG_DATA_WIDTH-1:0] csr_data_o;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_data_o;
    wire                        csr_global_int_en_o;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_csr_mtvec;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_csr_mepc;
    wire [ `REG_DATA_WIDTH-1:0] csr_clint_csr_mstatus;

    // ctrl模块输出信号
    wire [      `Hold_Flag_Bus] ctrl_hold_flag_o;
    wire                        ctrl_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] ctrl_jump_addr_o;

    // clint模块输出信号
    wire                        clint_we_o;
    wire [ `BUS_ADDR_WIDTH-1:0] clint_waddr_o;
    wire [ `BUS_ADDR_WIDTH-1:0] clint_raddr_o;
    wire [ `REG_DATA_WIDTH-1:0] clint_data_o;
    wire [`INST_ADDR_WIDTH-1:0] clint_int_addr_o;
    wire                        clint_int_assert_o;
    wire                        clint_hold_flag_o;

    // mems模块接口信号
    wire                        hold_flag_i;
    wire [`INST_DATA_WIDTH-1:0] inst_data_i;
    wire [ `BUS_DATA_WIDTH-1:0] exu_mem_data_i;

    // IFU模块例化
    ifu u_ifu (
        .clk        (clk),
        .rst_n      (rst_n),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_i     (inst_data_i),
        .pc_o       (pc_pc_o),
        .inst_o     (if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // ctrl模块例化 - 更新接口加入HDU暂停信号
    ctrl u_ctrl (
        .rst_n            (rst_n),
        .jump_flag_i      (exu_jump_flag_o),
        .jump_addr_i      (exu_jump_addr_o),
        .hold_flag_ex_i   (exu_hold_flag_o),
        .hold_flag_mems_i (hold_flag_i),
        .hold_flag_o      (ctrl_hold_flag_o),
        .hold_flag_clint_i(clint_hold_flag_o),
        .hold_flag_hdu_i  (idu_hdu_hold_flag_o), // 新增：HDU暂停信号输入
        .jump_flag_o      (ctrl_jump_flag_o),
        .jump_addr_o      (ctrl_jump_addr_o)
    );

    // regs模块例化
    regs u_regs (
        .clk     (clk),
        .rst_n   (rst_n),
        .we_i    (exu_reg_we_o),
        .waddr_i (exu_reg_waddr_o),
        .wdata_i (exu_reg_wdata_o),
        .raddr1_i(idu_reg1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(idu_reg2_raddr_o),
        .rdata2_o(regs_rdata2_o)
    );

    // csr_reg模块例化
    csr_reg u_csr_reg (
        .clk              (clk),
        .rst_n            (rst_n),
        .we_i             (exu_csr_we_o),
        .raddr_i          (idu_csr_raddr_o),
        .waddr_i          (exu_csr_waddr_o),
        .data_i           (exu_csr_wdata_o),
        .data_o           (csr_data_o),
        .global_int_en_o  (csr_global_int_en_o),
        .clint_we_i       (clint_we_o),
        .clint_raddr_i    (clint_raddr_o),
        .clint_waddr_i    (clint_waddr_o),
        .clint_data_i     (clint_data_o),
        .clint_data_o     (csr_clint_data_o),
        .clint_csr_mtvec  (csr_clint_csr_mtvec),
        .clint_csr_mepc   (csr_clint_csr_mepc),
        .clint_csr_mstatus(csr_clint_csr_mstatus)
    );

    // idu模块例化 - 更新接口
    idu u_idu (
        .clk         (clk),
        .rst_n       (rst_n),
        .inst_i      (if_inst_o),
        .inst_addr_i (if_inst_addr_o),
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),
        .csr_rdata_i (csr_data_o),
        .hold_flag_i (ctrl_hold_flag_o),
        .wb_done_i   (exu_wb_done_o),       // 新增：连接写回完成信号
        .ex_reg_we_i (exu_reg_we_o),        // 新增：连接执行阶段写使能
        .ex_reg_waddr_i(exu_reg_waddr_o),   // 新增：连接执行阶段写地址
        .reg1_raddr_o(idu_reg1_raddr_o),
        .reg2_raddr_o(idu_reg2_raddr_o),
        .csr_raddr_o (idu_csr_raddr_o),
        .inst_o      (idu_inst_o),
        .inst_addr_o (idu_inst_addr_o),
        .reg_we_o    (idu_reg_we_o),
        .reg_waddr_o (idu_reg_waddr_o),
        .reg1_rdata_o(idu_reg1_rdata_o),
        .reg2_rdata_o(idu_reg2_rdata_o),
        .csr_we_o    (idu_csr_we_o),
        .csr_waddr_o (idu_csr_waddr_o),
        .csr_rdata_o (idu_csr_rdata_o),
        .dec_imm_o     (idu_dec_imm_o),
        .dec_info_bus_o(idu_dec_info_bus_o),
        .hdu_hold_flag_o(idu_hdu_hold_flag_o)  // 新增：HDU暂停信号输出
    );

    // exu模块例化 - 更新接口
    exu_top u_exu (
        .clk           (clk),
        .rst_n         (rst_n),
        .inst_i        (idu_inst_o),
        .inst_addr_i   (idu_inst_addr_o),
        .reg_we_i      (idu_reg_we_o),
        .reg_waddr_i   (idu_reg_waddr_o),
        .reg1_rdata_i  (idu_reg1_rdata_o),
        .reg2_rdata_i  (idu_reg2_rdata_o),
        .csr_we_i      (idu_csr_we_o),
        .csr_waddr_i   (idu_csr_waddr_o),
        .csr_rdata_i   (idu_csr_rdata_o),
        .dec_info_bus_i(idu_dec_info_bus_o),
        .dec_imm_i     (idu_dec_imm_o),
        .mem_rdata_i   (exu_mem_data_i),
        .int_assert_i  (clint_int_assert_o),
        .int_addr_i    (clint_int_addr_o),
        .mem_wdata_o   (exu_mem_wdata_o),
        .mem_raddr_o   (exu_mem_raddr_o),
        .mem_waddr_o   (exu_mem_waddr_o),
        .mem_we_o      (exu_mem_we_o),
        .mem_req_o     (exu_mem_req_o),
        .mem_wmask_o   (exu_mem_wmask_o),
        .reg_wdata_o   (exu_reg_wdata_o),
        .reg_we_o      (exu_reg_we_o),
        .reg_waddr_o   (exu_reg_waddr_o),
        .hold_flag_o   (exu_hold_flag_o),
        .jump_flag_o   (exu_jump_flag_o),
        .jump_addr_o   (exu_jump_addr_o),
        .csr_wdata_o   (exu_csr_wdata_o),
        .csr_we_o      (exu_csr_we_o),
        .csr_waddr_o   (exu_csr_waddr_o),
        .div_started_o (exu_div_started_o),
        .wb_done_o     (exu_wb_done_o)      // 新增：写回完成信号输出
    );

    // clint模块例化 - 修改连接到idu的信号
    clint u_clint (
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_i         (idu_inst_o),
        .inst_addr_i    (idu_inst_addr_o),
        .jump_flag_i    (exu_jump_flag_o),
        .jump_addr_i    (exu_jump_addr_o),
        .hold_flag_i    (ctrl_hold_flag_o),
        .div_started_i  (exu_div_started_o),
        .data_i         (csr_clint_data_o),
        .csr_mtvec      (csr_clint_csr_mtvec),
        .csr_mepc       (csr_clint_csr_mepc),
        .csr_mstatus    (csr_clint_csr_mstatus),
        .we_o           (clint_we_o),
        .waddr_o        (clint_waddr_o),
        .raddr_o        (clint_raddr_o),
        .data_o         (clint_data_o),
        .hold_flag_o    (clint_hold_flag_o),
        .global_int_en_i(csr_global_int_en_o),
        .int_addr_o     (clint_int_addr_o),
        .int_assert_o   (clint_int_assert_o)
    );

    // mems模块例化
    mems u_mems (
        .clk        (clk),
        .rst_n      (rst_n),
        // PC接口
        .pc_i       (pc_pc_o),
        .inst_o     (inst_data_i),
        // EX接口
        .ex_addr_i  (exu_mem_we_o ? exu_mem_waddr_o : exu_mem_raddr_o),
        .ex_data_i  (exu_mem_wdata_o),
        .ex_data_o  (exu_mem_data_i),
        .ex_we_i    (exu_mem_we_o),
        .ex_req_i   (exu_mem_req_o),
        .ex_wmask_i (exu_mem_wmask_o),
        // 暂停信号
        .hold_flag_o(hold_flag_i)
    );

endmodule
