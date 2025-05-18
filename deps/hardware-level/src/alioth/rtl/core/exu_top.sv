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

// 执行单元顶层模块
module exu_top (
    input wire clk,
    input wire rst_n,

    // from id_ex
    input wire [`INST_DATA_WIDTH-1:0] inst_i,
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire                        reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire                        csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] csr_rdata_i,
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,
    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,
    // from mem
    input wire [ `BUS_DATA_WIDTH-1:0] mem_rdata_i,

    // to mem
    output wire [`BUS_DATA_WIDTH-1:0] mem_wdata_o,
    output wire [`BUS_ADDR_WIDTH-1:0] mem_raddr_o,
    output wire [`BUS_ADDR_WIDTH-1:0] mem_waddr_o,
    output wire                       mem_we_o,
    output wire                       mem_req_o,
    output wire [                3:0] mem_wmask_o,

    // to regs
    output wire [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o,

    // to csr reg
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,

    // to ctrl
    output wire                        hold_flag_o,
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,
    
    // to clint
    output wire                        div_started_o,
    
    // to IDU HDU - 新增写回完成信号
    output wire                        wb_done_o
);

    // 内部连线定义
    // 除法器信号
    wire                        div_ready;
    wire [ `REG_DATA_WIDTH-1:0] div_result;
    wire                        div_busy;
    wire [ `REG_ADDR_WIDTH-1:0] div_reg_waddr;
    // 除法器信号
    wire                        div_start;
    wire [ `REG_DATA_WIDTH-1:0] div_dividend;
    wire [ `REG_DATA_WIDTH-1:0] div_divisor;
    wire [                 3:0] div_op;
    wire [ `REG_ADDR_WIDTH-1:0] div_reg_waddr_o;

    // 乘法器信号
    wire                        mul_ready;
    wire [ `REG_DATA_WIDTH-1:0] mul_result;
    wire                        mul_busy;
    wire [ `REG_ADDR_WIDTH-1:0] mul_reg_waddr;

    wire                        mul_start;
    wire [ `REG_DATA_WIDTH-1:0] mul_multiplicand;
    wire [ `REG_DATA_WIDTH-1:0] mul_multiplier;
    wire [                 3:0] mul_op;
    wire [ `REG_ADDR_WIDTH-1:0] mul_reg_waddr_o;

    wire [ `REG_DATA_WIDTH-1:0] alu_result;
    wire                        alu_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] alu_reg_waddr;

    wire [ `REG_DATA_WIDTH-1:0] agu_reg_wdata;
    wire                        agu_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] agu_reg_waddr;

    wire                        bru_jump_flag;
    wire [`INST_ADDR_WIDTH-1:0] bru_jump_addr;

    wire [ `REG_DATA_WIDTH-1:0] csr_unit_wdata;
    wire [ `REG_DATA_WIDTH-1:0] csr_unit_reg_wdata;


    wire                        muldiv_hold_flag;
    wire                        muldiv_jump_flag;
    wire [`INST_ADDR_WIDTH-1:0] muldiv_jump_addr;
    wire [ `REG_DATA_WIDTH-1:0] muldiv_wdata;

    wire                        muldiv_we;
    wire [ `REG_ADDR_WIDTH-1:0] muldiv_waddr;

    // 来自ALU的分支比较结果
    wire [                31:0] bjp_res;
    wire                        bjp_cmp_res;

    // dispatch to ALU 

    // wire [ 4:0] rd_addr_o;
    wire [                31:0] alu_op1_o;
    wire [                31:0] alu_op2_o;
    wire                        req_alu_o;
    wire                        alu_op_lui_o;
    wire                        alu_op_auipc_o;
    wire                        alu_op_add_o;
    wire                        alu_op_sub_o;
    wire                        alu_op_sll_o;
    wire                        alu_op_slt_o;
    wire                        alu_op_sltu_o;
    wire                        alu_op_xor_o;
    wire                        alu_op_srl_o;
    wire                        alu_op_sra_o;
    wire                        alu_op_or_o;
    wire                        alu_op_and_o;
    // dispatch to BJP
    wire [                31:0] bjp_op1_o;
    wire [                31:0] bjp_op2_o;
    wire [                31:0] bjp_jump_op1_o;
    wire [                31:0] bjp_jump_op2_o;
    wire                        req_bjp_o;
    wire                        bjp_op_jump_o;
    wire                        bjp_op_beq_o;
    wire                        bjp_op_bne_o;
    wire                        bjp_op_blt_o;
    wire                        bjp_op_bltu_o;
    wire                        bjp_op_bge_o;
    wire                        bjp_op_bgeu_o;
    wire                        bjp_op_jalr_o;
    // dispatch to MULDIV
    wire                        req_muldiv_o;
    wire [                31:0] muldiv_op1_o;
    wire [                31:0] muldiv_op2_o;
    wire                        muldiv_op_mul_o;
    wire                        muldiv_op_mulh_o;
    wire                        muldiv_op_mulhsu_o;
    wire                        muldiv_op_mulhu_o;
    wire                        muldiv_op_div_o;
    wire                        muldiv_op_divu_o;
    wire                        muldiv_op_rem_o;
    wire                        muldiv_op_remu_o;
    wire                        muldiv_op_mul_all_o;  // 新增：总乘法操作标志
    wire                        muldiv_op_div_all_o;  // 新增：总除法操作标志
    // dispatch to CSR
    wire                        req_csr_o;
    wire [                31:0] csr_op1_o;
    wire [                31:0] csr_addr_o;
    wire                        csr_csrrw_o;
    wire                        csr_csrrs_o;
    wire                        csr_csrrc_o;
    // dispatch to MEM
    wire                        req_mem_o;
    wire [                31:0] mem_op1_o;
    wire [                31:0] mem_op2_o;
    wire [                31:0] mem_rs2_data_o;
    wire                        mem_op_lb_o;
    wire                        mem_op_lh_o;
    wire                        mem_op_lw_o;
    wire                        mem_op_lbu_o;
    wire                        mem_op_lhu_o;
    wire                        mem_op_sb_o;
    wire                        mem_op_sh_o;
    wire                        mem_op_sw_o;
    wire                        mem_op_load_o;  // 新增：总load操作标志
    wire                        mem_op_store_o;  // 新增：总store操作标志
    // dispatch to SYS
    wire                        sys_op_nop_o;
    wire                        sys_op_mret_o;
    wire                        sys_op_ecall_o;
    wire                        sys_op_ebreak_o;
    wire                        sys_op_fence_o;
    wire                        sys_op_dret_o;

    // 新增：用于结果延迟一个周期的信号
    wire [`REG_DATA_WIDTH-1:0] alu_result_delay;
    wire                       alu_reg_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] alu_reg_waddr_delay;
    
    wire [`REG_DATA_WIDTH-1:0] muldiv_wdata_delay;
    wire                       muldiv_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] muldiv_waddr_delay;
    
    wire [`REG_DATA_WIDTH-1:0] csr_unit_reg_wdata_delay;
    wire                       csr_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_delay;

    // 新增：用于AGU结果延迟一个周期的信号
    wire [`REG_DATA_WIDTH-1:0] agu_reg_wdata_delay;
    wire                       agu_reg_we_delay;
    wire [`REG_ADDR_WIDTH-1:0] agu_reg_waddr_delay;

    exu_dispatch u_exu_dispatch (
        // input
        .clk                (clk),
        .rst_n              (rst_n),
        .inst_i             (inst_i),
        .dec_info_bus_i     (dec_info_bus_i),
        .dec_imm_i          (dec_imm_i),
        .dec_pc_i           (inst_addr_i),
        .rs1_rdata_i        (reg1_rdata_i),
        .rs2_rdata_i        (reg2_rdata_i),
        // dispatch to ALU
        .alu_op1_o          (alu_op1_o),
        .alu_op2_o          (alu_op2_o),
        .req_alu_o          (req_alu_o),
        .alu_op_lui_o       (alu_op_lui_o),
        .alu_op_auipc_o     (alu_op_auipc_o),
        .alu_op_add_o       (alu_op_add_o),
        .alu_op_sub_o       (alu_op_sub_o),
        .alu_op_sll_o       (alu_op_sll_o),
        .alu_op_slt_o       (alu_op_slt_o),
        .alu_op_sltu_o      (alu_op_sltu_o),
        .alu_op_xor_o       (alu_op_xor_o),
        .alu_op_srl_o       (alu_op_srl_o),
        .alu_op_sra_o       (alu_op_sra_o),
        .alu_op_or_o        (alu_op_or_o),
        .alu_op_and_o       (alu_op_and_o),
        // dispatch to BJP
        .bjp_op1_o          (bjp_op1_o),
        .bjp_op2_o          (bjp_op2_o),
        .bjp_jump_op1_o     (bjp_jump_op1_o),
        .bjp_jump_op2_o     (bjp_jump_op2_o),
        .req_bjp_o          (req_bjp_o),
        .bjp_op_jump_o      (bjp_op_jump_o),
        .bjp_op_beq_o       (bjp_op_beq_o),
        .bjp_op_bne_o       (bjp_op_bne_o),
        .bjp_op_blt_o       (bjp_op_blt_o),
        .bjp_op_bltu_o      (bjp_op_bltu_o),
        .bjp_op_bge_o       (bjp_op_bge_o),
        .bjp_op_bgeu_o      (bjp_op_bgeu_o),
        .bjp_op_jalr_o      (bjp_op_jalr_o),
        // dispatch to MULDIV
        .req_muldiv_o       (req_muldiv_o),
        .muldiv_op1_o       (muldiv_op1_o),
        .muldiv_op2_o       (muldiv_op2_o),
        .muldiv_op_mul_o    (muldiv_op_mul_o),
        .muldiv_op_mulh_o   (muldiv_op_mulh_o),
        .muldiv_op_mulhsu_o (muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_o  (muldiv_op_mulhu_o),
        .muldiv_op_div_o    (muldiv_op_div_o),
        .muldiv_op_divu_o   (muldiv_op_divu_o),
        .muldiv_op_rem_o    (muldiv_op_rem_o),
        .muldiv_op_remu_o   (muldiv_op_remu_o),
        .muldiv_op_mul_all_o(muldiv_op_mul_all_o),  // 新增连接
        .muldiv_op_div_all_o(muldiv_op_div_all_o),  // 新增连接
        // dispatch to CSR
        .req_csr_o          (req_csr_o),
        .csr_op1_o          (csr_op1_o),
        .csr_addr_o         (csr_addr_o),
        .csr_csrrw_o        (csr_csrrw_o),
        .csr_csrrs_o        (csr_csrrs_o),
        .csr_csrrc_o        (csr_csrrc_o),
        // dispatch to MEM
        .req_mem_o          (req_mem_o),
        .mem_op1_o          (mem_op1_o),
        .mem_op2_o          (mem_op2_o),
        .mem_rs2_data_o     (mem_rs2_data_o),
        .mem_op_lb_o        (mem_op_lb_o),
        .mem_op_lh_o        (mem_op_lh_o),
        .mem_op_lw_o        (mem_op_lw_o),
        .mem_op_lbu_o       (mem_op_lbu_o),
        .mem_op_lhu_o       (mem_op_lhu_o),
        .mem_op_sb_o        (mem_op_sb_o),
        .mem_op_sh_o        (mem_op_sh_o),
        .mem_op_sw_o        (mem_op_sw_o),
        .mem_op_load_o      (mem_op_load_o),        // 新增连接
        .mem_op_store_o     (mem_op_store_o),       // 新增连接
        // dispatch to SYS
        .sys_op_nop_o       (sys_op_nop_o),
        .sys_op_mret_o      (sys_op_mret_o),
        .sys_op_ecall_o     (sys_op_ecall_o),
        .sys_op_ebreak_o    (sys_op_ebreak_o),
        .sys_op_fence_o     (sys_op_fence_o),
        .sys_op_dret_o      (sys_op_dret_o)
    );

    // 除法器模块例化
    exu_div u_div (
        .clk        (clk),
        .rst_n      (rst_n),
        .dividend_i (div_dividend),
        .divisor_i  (div_divisor),
        .start_i    ((int_assert_i == `INT_ASSERT) ? `DivStop : div_start),
        .op_i       (div_op),
        .reg_waddr_i(div_reg_waddr_o),
        .result_o   (div_result),
        .ready_o    (div_ready),
        .busy_o     (div_busy),
        .reg_waddr_o(div_reg_waddr)
    );

    // 乘法器模块例化
    exu_mul u_mul (
        .clk           (clk),
        .rst_n         (rst_n),
        .multiplicand_i(mul_multiplicand),
        .multiplier_i  (mul_multiplier),
        .start_i       ((int_assert_i == `INT_ASSERT) ? 1'b0 : mul_start),
        .op_i          (mul_op),
        .reg_waddr_i   (mul_reg_waddr_o),
        .result_o      (mul_result),
        .ready_o       (mul_ready),
        .busy_o        (mul_busy),
        .reg_waddr_o   (mul_reg_waddr)
    );

    // 地址生成单元模块例化 - 移除时钟信号，纯组合逻辑实现
    exu_agu_lsu u_agu (
        .rst_n        (rst_n),
        .req_mem_i     (req_mem_o),
        .mem_op1_i     (mem_op1_o),
        .mem_op2_i     (mem_op2_o),
        .mem_rs2_data_i(mem_rs2_data_o),
        .mem_op_lb_i   (mem_op_lb_o),
        .mem_op_lh_i   (mem_op_lh_o),
        .mem_op_lw_i   (mem_op_lw_o),
        .mem_op_lbu_i  (mem_op_lbu_o),
        .mem_op_lhu_i  (mem_op_lhu_o),
        .mem_op_sb_i   (mem_op_sb_o),
        .mem_op_sh_i   (mem_op_sh_o),
        .mem_op_sw_i   (mem_op_sw_o),
        .mem_op_load_i (mem_op_load_o),   // 新增连接
        .mem_op_store_i(mem_op_store_o),  // 新增连接
        .rd_addr_i     (reg_waddr_i),
        .mem_rdata_i   (mem_rdata_i),
        .int_assert_i  (int_assert_i),
        .mem_wdata_o   (mem_wdata_o),
        .mem_raddr_o   (mem_raddr_o),
        .mem_waddr_o   (mem_waddr_o),
        .mem_we_o      (mem_we_o),
        .mem_req_o     (mem_req_o),
        .mem_wmask_o   (mem_wmask_o),
        .reg_wdata_o   (agu_reg_wdata),
        .reg_we_o      (agu_reg_we),
        .reg_waddr_o   (agu_reg_waddr)
    );

    // 新增：使用D触发器延迟AGU控制信号一个周期
    gnrl_dff #(.DW(`REG_DATA_WIDTH)) u_agu_wdata_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(agu_reg_wdata),
        .qout(agu_reg_wdata_delay)
    );
    
    gnrl_dff #(.DW(1)) u_agu_we_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(agu_reg_we),
        .qout(agu_reg_we_delay)
    );
    
    gnrl_dff #(.DW(`REG_ADDR_WIDTH)) u_agu_waddr_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(agu_reg_waddr),
        .qout(agu_reg_waddr_delay)
    );

    // 算术逻辑单元模块例化
    exu_alu u_alu (
        .rst_n         (rst_n),
        .req_alu_i     (req_alu_o),
        .alu_op1_i     (alu_op1_o),
        .alu_op2_i     (alu_op2_o),
        .alu_op_lui_i  (alu_op_lui_o),
        .alu_op_auipc_i(alu_op_auipc_o),
        .alu_op_add_i  (alu_op_add_o),
        .alu_op_sub_i  (alu_op_sub_o),
        .alu_op_sll_i  (alu_op_sll_o),
        .alu_op_slt_i  (alu_op_slt_o),
        .alu_op_sltu_i (alu_op_sltu_o),
        .alu_op_xor_i  (alu_op_xor_o),
        .alu_op_srl_i  (alu_op_srl_o),
        .alu_op_sra_i  (alu_op_sra_o),
        .alu_op_or_i   (alu_op_or_o),
        .alu_op_and_i  (alu_op_and_o),
        .alu_op_jump_i (bjp_op_jump_o),
        .alu_rd_i      (reg_waddr_i),
        .int_assert_i  (int_assert_i),
        .result_o      (alu_result),
        .reg_we_o      (alu_reg_we),
        .reg_waddr_o   (alu_reg_waddr)
    );

    // 分支单元模块例化
    exu_bru u_bru (
        .rst_n             (rst_n),
        .req_bjp_i         (req_bjp_o),
        .bjp_op1_i         (bjp_op1_o),
        .bjp_op2_i         (bjp_op2_o),
        .bjp_jump_op1_i    (bjp_jump_op1_o),
        .bjp_jump_op2_i    (bjp_jump_op2_o),
        .bjp_op_jump_i     (bjp_op_jump_o),
        .bjp_op_beq_i      (bjp_op_beq_o),
        .bjp_op_bne_i      (bjp_op_bne_o),
        .bjp_op_blt_i      (bjp_op_blt_o),
        .bjp_op_bltu_i     (bjp_op_bltu_o),
        .bjp_op_bge_i      (bjp_op_bge_o),
        .bjp_op_bgeu_i     (bjp_op_bgeu_o),
        .bjp_op_jalr_i     (bjp_op_jalr_o),
        .sys_op_fence_i    (sys_op_fence_o),
        .muldiv_jump_flag_i(muldiv_jump_flag),
        .int_assert_i      (int_assert_i),
        .int_addr_i        (int_addr_i),
        .jump_flag_o       (bru_jump_flag),
        .jump_addr_o       (bru_jump_addr)
    );

    // CSR处理单元模块例化    
    exu_csr_unit u_csr_unit (
        .rst_n(rst_n),

        .req_csr_i   (req_csr_o),
        .csr_op1_i   (csr_op1_o),
        .csr_addr_i  (csr_addr_o),
        .csr_csrrw_i (csr_csrrw_o),
        .csr_csrrs_i (csr_csrrs_o),
        .csr_csrrc_i (csr_csrrc_o),
        .csr_rdata_i (csr_rdata_i),
        .int_assert_i(int_assert_i),

        .csr_wdata_o(csr_unit_wdata),
        .reg_wdata_o(csr_unit_reg_wdata)
    );

    // 乘除法控制逻辑
    exu_muldiv_ctrl u_muldiv_ctrl (
        .rst_n       (rst_n),
        .reg_waddr_i (reg_waddr_i),
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),
        .op1_jump_i  (bjp_jump_op1_o),
        .op2_jump_i  (bjp_jump_op2_o),

        // 连接dispatch模块的译码信号
        .req_muldiv_i       (req_muldiv_o),
        .muldiv_op_mul_i    (muldiv_op_mul_o),
        .muldiv_op_mulh_i   (muldiv_op_mulh_o),
        .muldiv_op_mulhsu_i (muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_i  (muldiv_op_mulhu_o),
        .muldiv_op_div_i    (muldiv_op_div_o),
        .muldiv_op_divu_i   (muldiv_op_divu_o),
        .muldiv_op_rem_i    (muldiv_op_rem_o),
        .muldiv_op_remu_i   (muldiv_op_remu_o),
        .muldiv_op_mul_all_i(muldiv_op_mul_all_o),  // 新增连接
        .muldiv_op_div_all_i(muldiv_op_div_all_o),  // 新增连接

        .div_ready_i    (div_ready),
        .div_result_i   (div_result),
        .div_busy_i     (div_busy),
        .div_reg_waddr_i(div_reg_waddr),
        .mul_ready_i    (mul_ready),
        .mul_result_i   (mul_result),
        .mul_busy_i     (mul_busy),
        .mul_reg_waddr_i(mul_reg_waddr),
        .int_assert_i   (int_assert_i),

        .div_start_o       (div_start),
        .div_dividend_o    (div_dividend),
        .div_divisor_o     (div_divisor),
        .div_op_o          (div_op),
        .div_reg_waddr_o   (div_reg_waddr_o),
        .mul_start_o       (mul_start),
        .mul_multiplicand_o(mul_multiplicand),
        .mul_multiplier_o  (mul_multiplier),
        .mul_op_o          (mul_op),
        .mul_reg_waddr_o   (mul_reg_waddr_o),
        .muldiv_hold_flag_o(muldiv_hold_flag),
        .muldiv_jump_flag_o(muldiv_jump_flag),
        .reg_wdata_o       (muldiv_wdata),
        .reg_we_o          (muldiv_we),
        .reg_waddr_o       (muldiv_waddr)
    );

    // 新增：使用D触发器延迟ALU结果一个周期
    gnrl_dff #(.DW(`REG_DATA_WIDTH)) u_alu_result_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(alu_result),
        .qout(alu_result_delay)
    );
    
    gnrl_dff #(.DW(1)) u_alu_we_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(alu_reg_we),
        .qout(alu_reg_we_delay)
    );
    
    gnrl_dff #(.DW(`REG_ADDR_WIDTH)) u_alu_waddr_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(alu_reg_waddr),
        .qout(alu_reg_waddr_delay)
    );
    
    // 新增：使用D触发器延迟MULDIV结果一个周期
    gnrl_dff #(.DW(`REG_DATA_WIDTH)) u_muldiv_data_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(muldiv_wdata),
        .qout(muldiv_wdata_delay)
    );
    
    gnrl_dff #(.DW(1)) u_muldiv_we_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(muldiv_we),
        .qout(muldiv_we_delay)
    );
    
    gnrl_dff #(.DW(`REG_ADDR_WIDTH)) u_muldiv_waddr_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(muldiv_waddr),
        .qout(muldiv_waddr_delay)
    );
    
    // 新增：使用D触发器延迟CSR结果一个周期
    gnrl_dff #(.DW(`REG_DATA_WIDTH)) u_csr_data_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(csr_unit_reg_wdata),
        .qout(csr_unit_reg_wdata_delay)
    );
    
    gnrl_dff #(.DW(1)) u_csr_we_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(csr_we_i && inst_i[6:0] == `INST_CSR),
        .qout(csr_we_delay)
    );
    
    gnrl_dff #(.DW(`REG_ADDR_WIDTH)) u_csr_waddr_dff (
        .clk(clk),
        .rst_n(rst_n),
        .dnxt(reg_waddr_i),
        .qout(csr_reg_waddr_delay)
    );
    
    // 新增：实例化写回模块
    exu_writeback u_exu_writeback (
        .clk(clk),
        .rst_n(rst_n),
        
        // 来自AGU模块的load数据 - 更新为延迟后的信号
        .agu_reg_wdata_i(agu_reg_wdata_delay),
        .agu_reg_we_i(agu_reg_we_delay),
        .agu_reg_waddr_i(agu_reg_waddr_delay),
        
        // 来自ALU模块的数据（经过D触发器延迟后）
        .alu_reg_wdata_i(alu_result_delay),
        .alu_reg_we_i(alu_reg_we_delay),
        .alu_reg_waddr_i(alu_reg_waddr_delay),
        
        // 来自MULDIV模块的数据（经过D触发器延迟后）
        .muldiv_reg_wdata_i(muldiv_wdata_delay),
        .muldiv_reg_we_i(muldiv_we_delay),
        .muldiv_reg_waddr_i(muldiv_waddr_delay),
        
        // 来自CSR模块的数据（经过D触发器延迟后）
        .csr_reg_wdata_i(csr_unit_reg_wdata_delay),
        .csr_reg_we_i(csr_we_delay),
        .csr_reg_waddr_i(csr_reg_waddr_delay),
        
        // 中断信号
        .int_assert_i(int_assert_i),
        
        // 寄存器写回接口
        .reg_wdata_o(reg_wdata_o),
        .reg_we_o(reg_we_o),
        .reg_waddr_o(reg_waddr_o),
        
        // 写回完成信号 - 用于HDU
        .wb_done_o(wb_done_o)
    );

    // 输出选择逻辑
    assign hold_flag_o = muldiv_hold_flag;  // 使用muldiv控制模块的hold信号
    assign jump_flag_o = bru_jump_flag || ((int_assert_i == `INT_ASSERT) ? `JumpEnable : `JumpDisable);
    assign jump_addr_o = (int_assert_i == `INT_ASSERT) ? int_addr_i : bru_jump_addr;

    // CSR写数据选择
    assign csr_we_o = (int_assert_i == `INT_ASSERT) ? `WriteDisable : (csr_we_i && inst_i[6:0] == `INST_CSR);
    assign csr_waddr_o = csr_waddr_i;
    assign csr_wdata_o = csr_unit_wdata;

    // 将除法开始信号输出给clint
    assign div_started_o = div_start | mul_start;

endmodule
