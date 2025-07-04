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

// 执行单元顶层模块
module exu (
    input wire clk,
    input wire rst_n,

    // from id_ex
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire                        reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire                        csr_we_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] csr_rdata_i,
    input wire                        int_assert_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,
    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,
    input wire [                 1:0] inst_id_i,
    input wire [`INST_ADDR_WIDTH-1:0] old_pc_i, // 旧的PC地址;

    input wire alu_wb_ready_i,     // ALU写回握手信号
    input wire muldiv_wb_ready_i,  // MULDIV写回握手信号
    input wire csr_wb_ready_i,     // CSR写回握手信号

    // from mem
    input wire [`BUS_DATA_WIDTH-1:0] mem_rdata_i,

    // from regs
    input wire [`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [`REG_DATA_WIDTH-1:0] reg2_rdata_i,

    input wire                       hazard_stall_i,  // 来自HDU的冒险暂停信�?

    // 新增访存阻塞信号
    output wire                      mem_stall_o,

    // to regs
    output wire [`REG_DATA_WIDTH-1:0] alu_reg_wdata_o,
    output wire                       alu_reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] alu_reg_waddr_o,
    // 新增ALU commit_id输出
    output wire [                3:0] alu_commit_id_o,

    output wire [`REG_DATA_WIDTH-1:0] muldiv_reg_wdata_o,
    output wire                       muldiv_reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] muldiv_reg_waddr_o,
    output wire [                3:0] muldiv_commit_id_o,

    output wire [`REG_DATA_WIDTH-1:0] agu_reg_wdata_o,
    output wire                       agu_reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] agu_reg_waddr_o,
    // 新增AGU commit_id输出
    output wire [                3:0] agu_commit_id_o,

    // 更新CSR寄存器写数据输出端口
    output wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_o,
    output wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_o,

    // to csr reg
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,

    // to ctrl
    output wire                        stall_flag_o,
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,

    // 输出LSU未完成传输事务信�?
    output wire mem_store_busy_o,

    // to clint
    output wire muldiv_started_o,

    // 添加系统操作信号输出到顶�?
    output wire exu_op_ecall_o,
    output wire exu_op_ebreak_o,
    output wire exu_op_mret_o,

    // AXI接口 - 新增
    output wire [ 1:0] M_AXI_AWID,
    output wire [31:0] M_AXI_AWADDR,
    output wire [ 7:0] M_AXI_AWLEN,
    output wire [ 2:0] M_AXI_AWSIZE,
    output wire [ 1:0] M_AXI_AWBURST,
    output wire        M_AXI_AWLOCK,
    output wire [ 3:0] M_AXI_AWCACHE,
    output wire [ 2:0] M_AXI_AWPROT,
    output wire [ 3:0] M_AXI_AWQOS,
    output wire [ 0:0] M_AXI_AWUSER,
    output wire        M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,

    output wire [31:0] M_AXI_WDATA,
    output wire [ 3:0] M_AXI_WSTRB,
    output wire        M_AXI_WLAST,
    output wire [ 0:0] M_AXI_WUSER,
    output wire        M_AXI_WVALID,
    input  wire        M_AXI_WREADY,

    input  wire [1:0] M_AXI_BID,
    input  wire [1:0] M_AXI_BRESP,
    input  wire [0:0] M_AXI_BUSER,
    input  wire       M_AXI_BVALID,
    output wire       M_AXI_BREADY,

    output wire [ 1:0] M_AXI_ARID,
    output wire [31:0] M_AXI_ARADDR,
    output wire [ 7:0] M_AXI_ARLEN,
    output wire [ 2:0] M_AXI_ARSIZE,
    output wire [ 1:0] M_AXI_ARBURST,
    output wire        M_AXI_ARLOCK,
    output wire [ 3:0] M_AXI_ARCACHE,
    output wire [ 2:0] M_AXI_ARPROT,
    output wire [ 3:0] M_AXI_ARQOS,
    output wire [ 0:0] M_AXI_ARUSER,
    output wire        M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,

    input  wire [ 1:0] M_AXI_RID,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [ 1:0] M_AXI_RRESP,
    input  wire        M_AXI_RLAST,
    input  wire [ 0:0] M_AXI_RUSER,
    input  wire        M_AXI_RVALID,
    output wire        M_AXI_RREADY
);

    // 内部连线定义
    // 除法器信�?
    wire                        div_ready;
    wire [ `REG_DATA_WIDTH-1:0] div_result;
    wire                        div_busy;
    wire                        div_valid;  // 新增：除法结果有效信�?
    wire [ `REG_ADDR_WIDTH-1:0] div_reg_waddr;
    // 除法器信�?
    wire                        div_start;
    wire [ `REG_DATA_WIDTH-1:0] div_dividend;
    wire [ `REG_DATA_WIDTH-1:0] div_divisor;
    wire [                 3:0] div_op;
    wire [ `REG_ADDR_WIDTH-1:0] div_reg_waddr_o;

    // 乘法器信�?
    wire                        mul_ready;
    wire [ `REG_DATA_WIDTH-1:0] mul_result;
    wire                        mul_busy;
    wire                        mul_valid;  // 新增：乘法结果有效信�?
    wire [ `REG_ADDR_WIDTH-1:0] mul_reg_waddr;
    // 新增乘法器缺失信�?
    wire                        mul_start;
    wire [ `REG_DATA_WIDTH-1:0] mul_multiplicand;
    wire [ `REG_DATA_WIDTH-1:0] mul_multiplier;
    wire [                 3:0] mul_op;

    // 新增：commit_id相关信号 - 修改�?4�?
    wire [                 3:0] commit_id = {2'b0, inst_id_i};  // 将指令ID映射�?4位commit_id

    // 修改�?4位commit_id
    wire [                 3:0] mem_commit_id = {2'b0, mem_inst_id};

    // 新增：ALU握手相关信号
    wire                        alu_stall;

    // 新增：CSR握手相关信号
    wire                        csr_stall;
    wire                        csr_ready;  // CSR写回准备好信�?

    // 新增：�?�线控制信号
    wire [                 1:0] muldiv_inst_id;
    wire [                 1:0] mem_inst_id;

    wire [ `REG_DATA_WIDTH-1:0] alu_result;
    wire                        alu_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] alu_reg_waddr;

    wire [ `REG_DATA_WIDTH-1:0] agu_reg_wdata;
    wire                        agu_reg_we;
    wire [ `REG_ADDR_WIDTH-1:0] agu_reg_waddr;
    wire [                 3:0] agu_commit_id;  // 改为4�?

    wire                        bru_jump_flag;
    wire [`INST_ADDR_WIDTH-1:0] bru_jump_addr;

    wire [ `REG_DATA_WIDTH-1:0] csr_unit_wdata;
    wire [ `REG_DATA_WIDTH-1:0] csr_unit_reg_wdata;

    wire                        muldiv_stall_flag;
    wire [`INST_ADDR_WIDTH-1:0] muldiv_jump_addr;
    wire [ `REG_DATA_WIDTH-1:0] muldiv_wdata;

    wire                        muldiv_we;
    wire [ `REG_ADDR_WIDTH-1:0] muldiv_waddr;
    wire [                 3:0] muldiv_commit_id;  // 改为4�?

    // 来自ALU的分支比较结�?
    wire [                31:0] bjp_res;
    wire                        bjp_cmp_res;

    // dispatch to ALU
    wire [                31:0] alu_op1_o;
    wire [                31:0] alu_op2_o;
    wire                        req_alu_o;
    wire [   `ALU_OP_WIDTH-1:0] alu_op_info_o;

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
    wire                        muldiv_op_mul_all_o;
    wire                        muldiv_op_div_all_o;
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
    wire                        mem_op_load_o;
    wire                        mem_op_store_o;
    // dispatch to SYS
    wire                        sys_op_nop_o;
    wire                        sys_op_mret_o;
    wire                        sys_op_ecall_o;
    wire                        sys_op_ebreak_o;
    wire                        sys_op_fence_o;
    wire                        sys_op_dret_o;

    exu_dispatch u_exu_dispatch (
        // input
        .dec_info_bus_i     (dec_info_bus_i),
        .dec_imm_i          (dec_imm_i),
        .dec_pc_i           (inst_addr_i),
        .rs1_rdata_i        (reg1_rdata_i),
        .rs2_rdata_i        (reg2_rdata_i),
        .inst_id_i          (inst_id_i),            // 新增指令ID输入
        // dispatch to ALU
        .alu_op1_o          (alu_op1_o),
        .alu_op2_o          (alu_op2_o),
        .req_alu_o          (req_alu_o),
        .alu_op_info_o      (alu_op_info_o),
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
        .muldiv_op_mul_all_o(muldiv_op_mul_all_o),
        .muldiv_op_div_all_o(muldiv_op_div_all_o),
        .muldiv_inst_id_o   (muldiv_inst_id),       // 新增MULDIV指令ID输出
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
        .mem_op_load_o      (mem_op_load_o),
        .mem_op_store_o     (mem_op_store_o),
        .mem_inst_id_o      (mem_inst_id),          // 新增MEM指令ID输出
        // dispatch to SYS
        .sys_op_nop_o       (sys_op_nop_o),
        .sys_op_mret_o      (sys_op_mret_o),
        .sys_op_ecall_o     (sys_op_ecall_o),
        .sys_op_ebreak_o    (sys_op_ebreak_o),
        .sys_op_fence_o     (sys_op_fence_o),
        .sys_op_dret_o      (sys_op_dret_o)
    );

    // 除法器模块例�?
    exu_div u_div (
        .clk       (clk),
        .rst_n     (rst_n),
        .dividend_i(div_dividend),
        .divisor_i (div_divisor),
        .start_i   (div_start),
        .op_i      (div_op),
        .result_o  (div_result),
        .busy_o    (div_busy),
        .valid_o   (div_valid)
    );

    // 乘法器模块例�?
    exu_mul u_mul (
        .clk           (clk),
        .rst_n         (rst_n),
        .multiplicand_i(mul_multiplicand),
        .multiplier_i  (mul_multiplier),
        .start_i       (mul_start),
        .op_i          (mul_op),
        .result_o      (mul_result),
        .busy_o        (mul_busy),
        .valid_o       (mul_valid)
    );

    // 地址生成单元模块例化 - 更新commit_id宽度
    exu_agu_lsu u_agu (
        .clk           (clk),
        .rst_n         (rst_n),
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
        .mem_op_load_i (mem_op_load_o),
        .mem_op_store_i(mem_op_store_o),
        .rd_addr_i     (reg_waddr_i),
        .commit_id_i   (mem_commit_id),     // 使用4位commit_id
        .int_assert_i  (int_assert_i),
        .mem_stall_o   (mem_stall_o),
        .mem_busy_o    (mem_store_busy_o),
        .reg_wdata_o   (agu_reg_wdata),
        .reg_we_o      (agu_reg_we),
        .reg_waddr_o   (agu_reg_waddr),
        .commit_id_o   (agu_commit_id),     // 使用4位commit_id

        // AXI接口连接
        .M_AXI_AWID   (M_AXI_AWID),
        .M_AXI_AWADDR (M_AXI_AWADDR),
        .M_AXI_AWLEN  (M_AXI_AWLEN),
        .M_AXI_AWSIZE (M_AXI_AWSIZE),
        .M_AXI_AWBURST(M_AXI_AWBURST),
        .M_AXI_AWLOCK (M_AXI_AWLOCK),
        .M_AXI_AWCACHE(M_AXI_AWCACHE),
        .M_AXI_AWPROT (M_AXI_AWPROT),
        .M_AXI_AWQOS  (M_AXI_AWQOS),
        .M_AXI_AWUSER (M_AXI_AWUSER),
        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),
        .M_AXI_WSTRB  (M_AXI_WSTRB),
        .M_AXI_WLAST  (M_AXI_WLAST),
        .M_AXI_WUSER  (M_AXI_WUSER),
        .M_AXI_WVALID (M_AXI_WVALID),
        .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_BID    (M_AXI_BID),
        .M_AXI_BRESP  (M_AXI_BRESP),
        .M_AXI_BUSER  (M_AXI_BUSER),
        .M_AXI_BVALID (M_AXI_BVALID),
        .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_ARID   (M_AXI_ARID),
        .M_AXI_ARADDR (M_AXI_ARADDR),
        .M_AXI_ARLEN  (M_AXI_ARLEN),
        .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),
        .M_AXI_ARLOCK (M_AXI_ARLOCK),
        .M_AXI_ARCACHE(M_AXI_ARCACHE),
        .M_AXI_ARPROT (M_AXI_ARPROT),
        .M_AXI_ARQOS  (M_AXI_ARQOS),
        .M_AXI_ARUSER (M_AXI_ARUSER),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RID    (M_AXI_RID),
        .M_AXI_RDATA  (M_AXI_RDATA),
        .M_AXI_RRESP  (M_AXI_RRESP),
        .M_AXI_RLAST  (M_AXI_RLAST),
        .M_AXI_RUSER  (M_AXI_RUSER),
        .M_AXI_RVALID (M_AXI_RVALID),
        .M_AXI_RREADY (M_AXI_RREADY)
    );

    // 算术逻辑单元模块例化 - 使用专用握手信号
    exu_alu u_alu (
        .clk          (clk),
        .rst_n        (rst_n),
        .req_alu_i    (req_alu_o),
        .hazard_stall_i(hazard_stall_i),  // 来自HDU的冒险暂停信�?
        .alu_op1_i    (alu_op1_o),
        .alu_op2_i    (alu_op2_o),
        .alu_op_info_i(alu_op_info_o),
        .alu_rd_i     (reg_waddr_i),
        .wb_ready_i   (alu_wb_ready_i),  // 使用ALU专用写回准备信号
        .alu_stall_o  (alu_stall),
        .int_assert_i (int_assert_i),
        .result_o     (alu_result),
        .reg_we_o     (alu_reg_we),
        .reg_waddr_o  (alu_reg_waddr)
    );

    // 分支单元模块例化 - 保持不变
    exu_bru u_bru (
        .rst_n         (rst_n),
        .req_bjp_i     (req_bjp_o),
        .bjp_op1_i     (bjp_op1_o),
        .bjp_op2_i     (bjp_op2_o),
        .bjp_jump_op1_i(bjp_jump_op1_o),
        .bjp_jump_op2_i(bjp_jump_op2_o),
        .bjp_op_jump_i (bjp_op_jump_o),
        .bjp_op_beq_i  (bjp_op_beq_o),
        .bjp_op_bne_i  (bjp_op_bne_o),
        .bjp_op_blt_i  (bjp_op_blt_o),
        .bjp_op_bltu_i (bjp_op_bltu_o),
        .bjp_op_bge_i  (bjp_op_bge_o),
        .bjp_op_bgeu_i (bjp_op_bgeu_o),
        .bjp_op_jalr_i (bjp_op_jalr_o),
        .sys_op_fence_i(sys_op_fence_o),
        .int_assert_i  (int_assert_i),
        .int_addr_i    (int_addr_i),
        .jump_flag_o   (bru_jump_flag),
        .jump_addr_o   (bru_jump_addr)
    );

    // CSR处理单元模块例化 - 只连接必要的寄存器写地址和数�?
    exu_csr_unit u_csr_unit (
        .clk         (clk),
        .rst_n       (rst_n),
        .req_csr_i   (req_csr_o),
        .csr_op1_i   (csr_op1_o),
        .csr_addr_i  (csr_addr_o),
        .csr_csrrw_i (csr_csrrw_o),
        .csr_csrrs_i (csr_csrrs_o),
        .csr_csrrc_i (csr_csrrc_o),
        .csr_rdata_i (csr_rdata_i),
        .csr_we_i    (csr_we_i),
        .csr_waddr_i (csr_waddr_i),
        .reg_waddr_i (reg_waddr_i),      // 连接寄存器写地址输入
        .wb_ready_i  (csr_wb_ready_i),
        .csr_stall_o (csr_stall),
        .int_assert_i(int_assert_i),
        .csr_wdata_o (csr_wdata_o),
        .csr_we_o    (csr_we_o),
        .csr_waddr_o (csr_waddr_o),
        .reg_wdata_o (csr_reg_wdata_o),
        .reg_waddr_o (csr_reg_waddr_o)   // 连接寄存器写地址输出
    );

    // 乘除法控制�?�辑 - 使用专用握手信号
    exu_muldiv_ctrl u_muldiv_ctrl (
        .clk         (clk),
        .rst_n       (rst_n),
        .wb_ready    (muldiv_wb_ready_i),      // 使用MULDIV专用写回准备信号
        .hazard_stall_i(hazard_stall_i),      // 连接数据冒险暂停信号
        .reg_waddr_i (reg_waddr_i),
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),
        .commit_id_i ({2'b0, muldiv_inst_id}), // 修改�?4�?

        // 连接dispatch模块的译码信�?
        .req_muldiv_i       (req_muldiv_o),
        .muldiv_op_mul_i    (muldiv_op_mul_o),
        .muldiv_op_mulh_i   (muldiv_op_mulh_o),
        .muldiv_op_mulhsu_i (muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_i  (muldiv_op_mulhu_o),
        .muldiv_op_div_i    (muldiv_op_div_o),
        .muldiv_op_divu_i   (muldiv_op_divu_o),
        .muldiv_op_rem_i    (muldiv_op_rem_o),
        .muldiv_op_remu_i   (muldiv_op_remu_o),
        .muldiv_op_mul_all_i(muldiv_op_mul_all_o),
        .muldiv_op_div_all_i(muldiv_op_div_all_o),

        .div_result_i(div_result),
        .div_busy_i  (div_busy),
        .div_valid_i (div_valid),    // 新增：连接除法有效信�?
        .mul_result_i(mul_result),
        .mul_busy_i  (mul_busy),
        .mul_valid_i (mul_valid),    // 新增：连接乘法有效信�?
        .int_assert_i(int_assert_i),

        .div_start_o        (div_start),
        .div_dividend_o     (div_dividend),
        .div_divisor_o      (div_divisor),
        .div_op_o           (div_op),
        .mul_start_o        (mul_start),
        .mul_multiplicand_o (mul_multiplicand),
        .mul_multiplier_o   (mul_multiplier),
        .mul_op_o           (mul_op),
        .muldiv_stall_flag_o(muldiv_stall_flag),
        .reg_wdata_o        (muldiv_wdata),
        .reg_we_o           (muldiv_we),
        .reg_waddr_o        (muldiv_waddr),
        .commit_id_o        (muldiv_commit_id)    // 4位commit_id输出
    );

    //exu internior branch prediction(mis or right)
    wire branch_taken;
    if (`branchprediction_enable) begin 
            //jal
        assign branch_taken = ((~bjp_op_jalr_o) & bjp_op_jump_o) |
                            // bxx & imm[31]
                            (req_bjp_o & (~bjp_op_jump_o) & dec_imm_i[31]);
    end else begin
        assign branch_taken = 1'b0; // 不使用分支预测时，默认不预测分支
    end

    //预测失败
    wire   branch_mispredict;
    assign branch_mispredict = branch_taken & (~bjp_cmp_res_o) & req_bjp_o & (~bjp_op_jump_o);

    // 直接将执行单元的结果暴露给wbu - 修改commit_id宽度
    assign alu_reg_wdata_o = alu_result;
    assign alu_reg_we_o = alu_reg_we;
    assign alu_reg_waddr_o = alu_reg_waddr;
    assign alu_commit_id_o = {2'b0, inst_id_i};  // 修改�?4位commit_id

    assign muldiv_reg_wdata_o = muldiv_wdata;
    assign muldiv_reg_we_o = muldiv_we;
    assign muldiv_reg_waddr_o = muldiv_waddr;
    assign muldiv_commit_id_o = muldiv_commit_id;

    assign agu_reg_wdata_o = agu_reg_wdata;
    assign agu_reg_we_o = agu_reg_we;
    assign agu_reg_waddr_o = agu_reg_waddr;
    assign agu_commit_id_o = agu_commit_id;  // 修改：直接使�?8位commit_id

    // 输出选择逻辑 - 修改stall_flag输出，�?�虑�?有握手信�?
    assign stall_flag_o = muldiv_stall_flag | alu_stall | csr_stall | mem_stall_o;
    assign jump_flag_o = bru_jump_flag || ((int_assert_i == `INT_ASSERT) ? `JumpEnable : `JumpDisable);
    assign jump_addr_o = (int_assert_i == `INT_ASSERT) ? int_addr_i : bru_jump_addr;

    // 将乘除法�?始信号输出给clint
    assign muldiv_started_o = div_start | mul_start;

    // 将SYS操作信号连接到输�?
    assign exu_op_ecall_o = sys_op_ecall_o;
    assign exu_op_ebreak_o = sys_op_ebreak_o;
    assign exu_op_mret_o = sys_op_mret_o;

endmodule
