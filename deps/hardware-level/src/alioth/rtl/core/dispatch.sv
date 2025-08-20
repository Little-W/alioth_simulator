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

// 指令分发模块 - 将译码结果分发到各功能单元
module dispatch (
    input wire                     clk,
    input wire                     rst_n,
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i, // 流水线暂停标志

    // 指令有效信号输入
    input wire inst_valid_i,
    // 新增：非法指令信号输入
    input wire illegal_inst_i,

    // 输入译码信息总线和立即数
    input wire [  `DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire [                31:0] dec_imm_i,
    input wire [`INST_ADDR_WIDTH-1:0] dec_pc_i,
    input wire [`INST_DATA_WIDTH-1:0] inst_i,
    input wire [ `REG_DATA_WIDTH-1:0] rs1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] rs2_rdata_i,
    input wire                        is_pred_branch_i,

    // 寄存器写入信息 - 用于HDU检测冒险
    input wire [   `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [   `REG_ADDR_WIDTH-1:0] reg1_raddr_i,
    input wire [   `REG_ADDR_WIDTH-1:0] reg2_raddr_i,
    input wire                          reg_we_i,
    // 新增：rs1和rs2寄存器是否需要访问
    input wire                          rs1_re_i,
    input wire                          rs2_re_i,
    // 从IDU接收额外的CSR信号
    input wire                          csr_we_i,
    input wire [   `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire [   `BUS_ADDR_WIDTH-1:0] csr_raddr_i,
    input wire [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus_i,

    // 长指令有效信号 - 用于HDU
    input wire clint_req_valid_i, // CLINT请求信号

    // 写回阶段提交信号 - 用于HDU
    input wire                        commit_valid_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // HDU输出信号
    output wire                        hazard_stall_o,
    output wire                        long_inst_atom_lock_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,
    // 新增：寄存器读取地址输出
    output wire [ `REG_ADDR_WIDTH-1:0] reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg2_raddr_o,
    output wire [`INST_ADDR_WIDTH-1:0] pipe_inst_addr_o,
    output wire [`INST_DATA_WIDTH-1:0] pipe_inst_o,
    // 指令有效信号输出
    output wire                        pipe_inst_valid_o,
    // 向其他模块输出的额外信号
    output wire                        pipe_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] pipe_reg_waddr_o,

    output wire                       pipe_csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] pipe_csr_waddr_o,
    output wire [`BUS_ADDR_WIDTH-1:0] pipe_csr_raddr_o,
    output wire [               31:0] pipe_dec_imm_o,
    output wire [ `DECINFO_WIDTH-1:0] pipe_dec_info_bus_o,
    // 寄存rs1/rs2数据
    output wire [               31:0] pipe_rs1_rdata_o,
    output wire [               31:0] pipe_rs2_rdata_o,

    // dispatch to ALU
    output wire                     req_alu_o,
    output wire [             31:0] alu_op1_o,
    output wire [             31:0] alu_op2_o,
    output wire [`ALU_OP_WIDTH-1:0] alu_op_info_o,

    // dispatch to Bru
    output wire        req_bjp_o,
    output wire        bjp_op_jal_o,
    output wire        bjp_op_beq_o,
    output wire        bjp_op_bne_o,
    output wire        bjp_op_blt_o,
    output wire        bjp_op_bltu_o,
    output wire        bjp_op_bge_o,
    output wire        bjp_op_bgeu_o,
    output wire        bjp_op_jalr_o,
    output wire [31:0] bjp_adder_result_o,
    output wire [31:0] bjp_next_pc_o,
    output wire        op1_eq_op2_o,
    output wire        op1_ge_op2_signed_o,
    output wire        op1_ge_op2_unsigned_o,

    // dispatch to MUL
    output wire                        req_mul_o,
    output wire                        mul_op_mul_o,
    output wire                        mul_op_mulh_o,
    output wire                        mul_op_mulhsu_o,
    output wire                        mul_op_mulhu_o,
    output wire [                31:0] mul_op1_o,
    output wire [                31:0] mul_op2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] mul_commit_id_o,
    output wire                        mul_pass_op1_o,
    output wire                        mul_pass_op2_o,

    // dispatch to DIV
    output wire                        req_div_o,
    output wire                        div_op_div_o,
    output wire                        div_op_divu_o,
    output wire                        div_op_rem_o,
    output wire                        div_op_remu_o,
    output wire [                31:0] div_op1_o,
    output wire [                31:0] div_op2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] div_commit_id_o,
    output wire                        div_pass_op1_o,
    output wire                        div_pass_op2_o,

    // dispatch to CSR
    output wire        req_csr_o,
    output wire [31:0] csr_op1_o,
    output wire [31:0] csr_addr_o,
    output wire        csr_csrrw_o,
    output wire        csr_csrrs_o,
    output wire        csr_csrrc_o,
    output wire        csr_pass_op1_o, // 新增：CSR旁路信号

    // dispatch to MEM
    output wire                        req_mem_o,
    output wire                        mem_op_lb_o,
    output wire                        mem_op_lh_o,
    output wire                        mem_op_lw_o,
    output wire                        mem_op_lbu_o,
    output wire                        mem_op_lhu_o,
    output wire                        mem_op_load_o,
    output wire                        mem_op_store_o,
    output wire [`COMMIT_ID_WIDTH-1:0] mem_commit_id_o,
    output wire [                31:0] mem_addr_o,
    output wire [                 3:0] mem_wmask_o,
    output wire [                31:0] mem_wdata_o,

    // dispatch to SYS
    output wire sys_op_nop_o,
    output wire sys_op_mret_o,
    output wire sys_op_ecall_o,
    output wire sys_op_ebreak_o,
    output wire sys_op_fence_o,
    output wire sys_op_dret_o,
    output wire is_pred_branch_o, // 预测分支信号输出

    output wire misaligned_load_o,   // 未对齐加载异常信号输出
    output wire misaligned_store_o,  // 未对齐存储异常信号输出
    // 新增：非法指令信号输出
    output wire illegal_inst_o,
    // 新增：ALU RAW冒险旁路前递信号输出
    output wire alu_pass_op1_o,
    output wire alu_pass_op2_o
);

    // 内部连线，用于连接dispatch_logic和dispatch_pipe

    wire [  `COMMIT_ID_WIDTH-1:0] hdu_long_inst_id;

    // 新增：hdu旁路信号连线
    wire                          alu_pass_op1;
    wire                          alu_pass_op2;
    // 新增：MUL/DIV/CSR旁路信号连线
    wire                          mul_pass_op1;
    wire                          mul_pass_op2;
    wire                          div_pass_op1;
    wire                          div_pass_op2;
    wire                          csr_pass_op1;

    // 新增：FIFO相关信号
    wire                          push_req;
    wire                          fifo_stall;
    wire                          fifo_full;

    // FIFO输出信号
    wire                          fifo_inst_valid;
    wire                          fifo_illegal_inst;
    wire [    `DECINFO_WIDTH-1:0] fifo_dec_info_bus;
    wire [                  31:0] fifo_dec_imm;
    wire [  `INST_ADDR_WIDTH-1:0] fifo_dec_pc;
    wire [  `INST_DATA_WIDTH-1:0] fifo_inst;
    wire                          fifo_is_pred_branch;
    wire [   `REG_ADDR_WIDTH-1:0] fifo_reg_waddr;
    wire [   `REG_ADDR_WIDTH-1:0] fifo_reg1_raddr;
    wire [   `REG_ADDR_WIDTH-1:0] fifo_reg2_raddr;
    wire                          fifo_reg_we;
    wire                          fifo_rs1_re;
    wire                          fifo_rs2_re;
    wire                          fifo_csr_we;
    wire [   `BUS_ADDR_WIDTH-1:0] fifo_csr_waddr;
    wire [   `BUS_ADDR_WIDTH-1:0] fifo_csr_raddr;
    wire [`EX_INFO_BUS_WIDTH-1:0] fifo_ex_info_bus;
    wire                          fifo_rd_we;

    // 用于连接dispatch_logic输出到dispatch_pipe输入的内部地址、掩码和数据信号
    wire [                  31:0] logic_mem_addr;
    wire [                   3:0] logic_mem_wmask;
    wire [                  31:0] logic_mem_wdata;

    // 用于连接dispatch_logic输出到dispatch_pipe输入的内部信号
    wire                          logic_req_alu;
    wire [                  31:0] logic_alu_op1;
    wire [                  31:0] logic_alu_op2;
    wire [     `ALU_OP_WIDTH-1:0] logic_alu_op_info;

    wire                          logic_req_bjp;
    wire                          logic_bjp_op_jal;
    wire                          logic_bjp_op_beq;
    wire                          logic_bjp_op_bne;
    wire                          logic_bjp_op_blt;
    wire                          logic_bjp_op_bltu;
    wire                          logic_bjp_op_bge;
    wire                          logic_bjp_op_bgeu;
    wire                          logic_bjp_op_jalr;
    wire [                  31:0] logic_bjp_adder_result;
    wire [                  31:0] logic_bjp_next_pc;
    wire                          logic_op1_eq_op2;
    wire                          logic_op1_ge_op2_signed;
    wire                          logic_op1_ge_op2_unsigned;

    wire [                  31:0] logic_mul_op1;
    wire [                  31:0] logic_mul_op2;
    wire                          logic_mul_op_mul;
    wire                          logic_mul_op_mulh;
    wire                          logic_mul_op_mulhsu;
    wire                          logic_mul_op_mulhu;

    wire                          logic_req_mul;
    wire [  `COMMIT_ID_WIDTH-1:0] logic_mul_commit_id;

    wire [                  31:0] logic_div_op1;
    wire [                  31:0] logic_div_op2;
    wire                          logic_div_op_div;
    wire                          logic_div_op_divu;
    wire                          logic_div_op_rem;
    wire                          logic_div_op_remu;

    wire                          logic_req_div;
    wire [  `COMMIT_ID_WIDTH-1:0] logic_div_commit_id;

    wire                          logic_req_csr;
    wire [                  31:0] logic_csr_op1;
    wire [                  31:0] logic_csr_addr;
    wire                          logic_csr_csrrw;
    wire                          logic_csr_csrrs;
    wire                          logic_csr_csrrc;

    wire                          logic_req_mem;
    wire [                  31:0] logic_mem_op1;
    wire [                  31:0] logic_mem_op2;
    wire [                  31:0] logic_mem_rs2_data;
    wire                          logic_mem_op_lb;
    wire                          logic_mem_op_lh;
    wire                          logic_mem_op_lw;
    wire                          logic_mem_op_lbu;
    wire                          logic_mem_op_lhu;
    wire                          logic_mem_op_sb;
    wire                          logic_mem_op_sh;
    wire                          logic_mem_op_sw;
    wire                          logic_mem_op_load;
    wire                          logic_mem_op_store;
    wire [  `COMMIT_ID_WIDTH-1:0] logic_mem_commit_id;

    wire                          logic_sys_op_nop;
    wire                          logic_sys_op_mret;
    wire                          logic_sys_op_ecall;
    wire                          logic_sys_op_ebreak;
    wire                          logic_sys_op_fence;
    wire                          logic_sys_op_dret;

    // 未对齐访存异常信号
    wire                          logic_misaligned_load;
    wire                          logic_misaligned_store;

    wire                          hdu_hazard_detect;
    wire                          dispatch_pipe_flush;

    // FIFO控制信号逻辑
    assign push_req            = hdu_hazard_detect;
    assign fifo_stall          = (stall_flag_i[`CU_STALL_DISPATCH]) | hdu_hazard_detect;
    assign dispatch_pipe_flush = stall_flag_i[`CU_FLUSH] | hdu_hazard_detect;
    // hazard_stall_o连接到FIFO满状态
    assign hazard_stall_o      = fifo_full;

    // 寄存器读地址输出连接到FIFO输出
    assign reg1_raddr_o        = fifo_reg1_raddr;
    assign reg2_raddr_o        = fifo_reg2_raddr;

    assign mem_commit_id_o     = commit_id_o;
    assign mul_commit_id_o     = commit_id_o;
    assign div_commit_id_o     = commit_id_o;

    // 实例化保留栈FIFO模块
    dispatch_reserve_stack #(
        .FIFO_DEPTH(4)
    ) u_dispatch_reserve_stack (
        .clk  (clk),
        .rst_n(rst_n),

        // FIFO控制信号
        .push_req_i  (push_req),
        .fifo_stall_i(fifo_stall),
        .fifo_full_o (fifo_full),
        .fifo_flush_i(stall_flag_i[`CU_FLUSH]),

        // 输入信号组
        .inst_valid_i    (inst_valid_i && !stall_flag_i),
        .illegal_inst_i  (illegal_inst_i),
        .dec_info_bus_i  (dec_info_bus_i),
        .dec_imm_i       (dec_imm_i),
        .dec_pc_i        (dec_pc_i),
        .inst_i          (inst_i),
        .is_pred_branch_i(is_pred_branch_i),
        .reg_waddr_i     (reg_waddr_i),
        .reg1_raddr_i    (reg1_raddr_i),
        .reg2_raddr_i    (reg2_raddr_i),
        .reg_we_i        (reg_we_i),
        .rs1_re_i        (rs1_re_i),
        .rs2_re_i        (rs2_re_i),
        .csr_we_i        (csr_we_i),
        .csr_waddr_i     (csr_waddr_i),
        .csr_raddr_i     (csr_raddr_i),
        .ex_info_bus_i   (ex_info_bus_i),

        // 输出信号组
        .inst_valid_o    (fifo_inst_valid),
        .illegal_inst_o  (fifo_illegal_inst),
        .dec_info_bus_o  (fifo_dec_info_bus),
        .dec_imm_o       (fifo_dec_imm),
        .dec_pc_o        (fifo_dec_pc),
        .inst_o          (fifo_inst),
        .is_pred_branch_o(fifo_is_pred_branch),
        .reg_waddr_o     (fifo_reg_waddr),
        .reg1_raddr_o    (fifo_reg1_raddr),
        .reg2_raddr_o    (fifo_reg2_raddr),
        .reg_we_o        (fifo_reg_we),
        .rs1_re_o        (fifo_rs1_re),
        .rs2_re_o        (fifo_rs2_re),
        .csr_we_o        (fifo_csr_we),
        .csr_waddr_o     (fifo_csr_waddr),
        .csr_raddr_o     (fifo_csr_raddr),
        .ex_info_bus_o   (fifo_ex_info_bus)
    );

    // 实例化HDU模块
    hdu u_hdu (
        .clk                  (clk),
        .rst_n                (rst_n),
        .rd_we_i              (fifo_reg_we && !clint_req_valid_i),
        .rd_addr              (fifo_reg_waddr),
        .rs1_addr             (fifo_reg1_raddr),
        .rs2_addr             (fifo_reg2_raddr),
        .rd_we                (fifo_reg_we),
        .rs1_re               (fifo_rs1_re),
        .rs2_re               (fifo_rs2_re),
        .ex_info_bus          (fifo_ex_info_bus),
        .commit_valid_i       (commit_valid_i),
        .commit_id_i          (commit_id_i),
        .hazard_stall_o       (hdu_hazard_detect),
        .commit_id_o          (hdu_long_inst_id),
        .long_inst_atom_lock_o(long_inst_atom_lock_o),
        // 新增旁路信号输出
        .alu_pass_op1_o       (alu_pass_op1),
        .alu_pass_op2_o       (alu_pass_op2),
        // 新增MUL/DIV/CSR旁路信号输出
        .mul_pass_op1_o       (mul_pass_op1),
        .mul_pass_op2_o       (mul_pass_op2),
        .div_pass_op1_o       (div_pass_op1),
        .div_pass_op2_o       (div_pass_op2),
        .csr_pass_op1_o       (csr_pass_op1)
    );

    // 实例化dispatch_logic模块
    dispatch_logic u_dispatch_logic (
        .dec_info_bus_i(fifo_dec_info_bus),
        .dec_imm_i     (fifo_dec_imm),
        .dec_pc_i      (fifo_dec_pc),
        .rs1_rdata_i   (rs1_rdata_i),
        .rs2_rdata_i   (rs2_rdata_i),

        // ALU信号
        .req_alu_o    (logic_req_alu),
        .alu_op1_o    (logic_alu_op1),
        .alu_op2_o    (logic_alu_op2),
        .alu_op_info_o(logic_alu_op_info),

        // BJP信号
        .req_bjp_o            (logic_req_bjp),
        .bjp_op_jal_o         (logic_bjp_op_jal),
        .bjp_op_beq_o         (logic_bjp_op_beq),
        .bjp_op_bne_o         (logic_bjp_op_bne),
        .bjp_op_blt_o         (logic_bjp_op_blt),
        .bjp_op_bltu_o        (logic_bjp_op_bltu),
        .bjp_op_bge_o         (logic_bjp_op_bge),
        .bjp_op_bgeu_o        (logic_bjp_op_bgeu),
        .bjp_op_jalr_o        (logic_bjp_op_jalr),
        .bjp_adder_result_o   (logic_bjp_adder_result),
        .bjp_next_pc_o        (logic_bjp_next_pc),
        .op1_eq_op2_o         (logic_op1_eq_op2),
        .op1_ge_op2_signed_o  (logic_op1_ge_op2_signed),
        .op1_ge_op2_unsigned_o(logic_op1_ge_op2_unsigned),

        // MUL信号
        .req_mul_o      (logic_req_mul),
        .mul_op1_o      (logic_mul_op1),
        .mul_op2_o      (logic_mul_op2),
        .mul_op_mul_o   (logic_mul_op_mul),
        .mul_op_mulh_o  (logic_mul_op_mulh),
        .mul_op_mulhsu_o(logic_mul_op_mulhsu),
        .mul_op_mulhu_o (logic_mul_op_mulhu),

        // DIV信号
        .req_div_o    (logic_req_div),
        .div_op1_o    (logic_div_op1),
        .div_op2_o    (logic_div_op2),
        .div_op_div_o (logic_div_op_div),
        .div_op_divu_o(logic_div_op_divu),
        .div_op_rem_o (logic_div_op_rem),
        .div_op_remu_o(logic_div_op_remu),

        // CSR信号
        .req_csr_o  (logic_req_csr),
        .csr_op1_o  (logic_csr_op1),
        .csr_addr_o (logic_csr_addr),
        .csr_csrrw_o(logic_csr_csrrw),
        .csr_csrrs_o(logic_csr_csrrs),
        .csr_csrrc_o(logic_csr_csrrc),

        // MEM信号
        .req_mem_o     (logic_req_mem),
        .mem_op_lb_o   (logic_mem_op_lb),
        .mem_op_lh_o   (logic_mem_op_lh),
        .mem_op_lw_o   (logic_mem_op_lw),
        .mem_op_lbu_o  (logic_mem_op_lbu),
        .mem_op_lhu_o  (logic_mem_op_lhu),
        .mem_op_load_o (logic_mem_op_load),
        .mem_op_store_o(logic_mem_op_store),
        // 直接计算的内存地址和掩码/数据
        .mem_addr_o    (logic_mem_addr),
        .mem_wmask_o   (logic_mem_wmask),
        .mem_wdata_o   (logic_mem_wdata),

        // SYS信号
        .sys_op_nop_o   (logic_sys_op_nop),
        .sys_op_mret_o  (logic_sys_op_mret),
        .sys_op_ecall_o (logic_sys_op_ecall),
        .sys_op_ebreak_o(logic_sys_op_ebreak),
        .sys_op_fence_o (logic_sys_op_fence),
        .sys_op_dret_o  (logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_o (logic_misaligned_load),
        .misaligned_store_o(logic_misaligned_store)
    );

    // 实例化dispatch_pipe模块
    dispatch_pipe u_dispatch_pipe (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_flag_i(stall_flag_i),
        .flush_i     (dispatch_pipe_flush),

        .inst_valid_i(fifo_inst_valid),
        .inst_addr_i (fifo_dec_pc),
        .inst_i      (fifo_inst),
        .commit_id_i (hdu_long_inst_id),

        // 额外的IDU信号输入
        .reg_we_i        (fifo_reg_we),
        .reg_waddr_i     (fifo_reg_waddr),
        .csr_we_i        (fifo_csr_we),
        .csr_waddr_i     (fifo_csr_waddr),
        .csr_raddr_i     (fifo_csr_raddr),
        .dec_imm_i       (fifo_dec_imm),
        .dec_info_bus_i  (fifo_dec_info_bus),
        // 寄存rs1/rs2数据
        .rs1_rdata_i     (rs1_rdata_i),
        .rs2_rdata_i     (rs2_rdata_i),
        .is_pred_branch_i(fifo_is_pred_branch),
        // 新增：非法指令信号输入
        .illegal_inst_i  (fifo_illegal_inst),

        // ALU信号输入
        .req_alu_i     (logic_req_alu),
        .alu_op1_i     (logic_alu_op1),
        .alu_op2_i     (logic_alu_op2),
        .alu_op_info_i (logic_alu_op_info),
        .alu_pass_op1_i(alu_pass_op1),       // 连接旁路信号输入
        .alu_pass_op2_i(alu_pass_op2),       // 连接旁路信号输入
        // 新增MUL/DIV/CSR旁路信号输入
        .mul_pass_op1_i(mul_pass_op1),
        .mul_pass_op2_i(mul_pass_op2),
        .div_pass_op1_i(div_pass_op1),
        .div_pass_op2_i(div_pass_op2),
        .csr_pass_op1_i(csr_pass_op1),

        // BJP信号输入
        .req_bjp_i            (logic_req_bjp),
        .bjp_op_jal_i         (logic_bjp_op_jal),
        .bjp_op_beq_i         (logic_bjp_op_beq),
        .bjp_op_bne_i         (logic_bjp_op_bne),
        .bjp_op_blt_i         (logic_bjp_op_blt),
        .bjp_op_bltu_i        (logic_bjp_op_bltu),
        .bjp_op_bge_i         (logic_bjp_op_bge),
        .bjp_op_bgeu_i        (logic_bjp_op_bgeu),
        .bjp_op_jalr_i        (logic_bjp_op_jalr),
        .bjp_adder_result_i   (logic_bjp_adder_result),
        .bjp_next_pc_i        (logic_bjp_next_pc),
        .op1_eq_op2_i         (logic_op1_eq_op2),
        .op1_ge_op2_signed_i  (logic_op1_ge_op2_signed),
        .op1_ge_op2_unsigned_i(logic_op1_ge_op2_unsigned),

        // MUL信号输入
        .req_mul_i      (logic_req_mul),
        .mul_op1_i      (logic_mul_op1),
        .mul_op2_i      (logic_mul_op2),
        .mul_op_mul_i   (logic_mul_op_mul),
        .mul_op_mulh_i  (logic_mul_op_mulh),
        .mul_op_mulhsu_i(logic_mul_op_mulhsu),
        .mul_op_mulhu_i (logic_mul_op_mulhu),

        // DIV信号输入
        .req_div_i    (logic_req_div),
        .div_op1_i    (logic_div_op1),
        .div_op2_i    (logic_div_op2),
        .div_op_div_i (logic_div_op_div),
        .div_op_divu_i(logic_div_op_divu),
        .div_op_rem_i (logic_div_op_rem),
        .div_op_remu_i(logic_div_op_remu),

        // CSR信号输入
        .req_csr_i  (logic_req_csr),
        .csr_op1_i  (logic_csr_op1),
        .csr_addr_i (logic_csr_addr),
        .csr_csrrw_i(logic_csr_csrrw),
        .csr_csrrs_i(logic_csr_csrrs),
        .csr_csrrc_i(logic_csr_csrrc),

        // MEM信号输入
        .req_mem_i     (logic_req_mem),
        .mem_op_lb_i   (logic_mem_op_lb),
        .mem_op_lh_i   (logic_mem_op_lh),
        .mem_op_lw_i   (logic_mem_op_lw),
        .mem_op_lbu_i  (logic_mem_op_lbu),
        .mem_op_lhu_i  (logic_mem_op_lhu),
        .mem_op_load_i (logic_mem_op_load),
        .mem_op_store_i(logic_mem_op_store),
        .mem_addr_i    (logic_mem_addr),
        .mem_wmask_i   (logic_mem_wmask),
        .mem_wdata_i   (logic_mem_wdata),

        // SYS信号输入
        .sys_op_nop_i   (logic_sys_op_nop),
        .sys_op_mret_i  (logic_sys_op_mret),
        .sys_op_ecall_i (logic_sys_op_ecall),
        .sys_op_ebreak_i(logic_sys_op_ebreak),
        .sys_op_fence_i (logic_sys_op_fence),
        .sys_op_dret_i  (logic_sys_op_dret),

        // 未对齐访存异常信号
        .misaligned_load_i (logic_misaligned_load),
        .misaligned_store_i(logic_misaligned_store),

        // 指令地址和ID输出
        .inst_addr_o   (pipe_inst_addr_o),
        .inst_o        (pipe_inst_o),
        .commit_id_o   (commit_id_o),
        .inst_valid_o  (pipe_inst_valid_o),
        // 额外的IDU信号输出
        .reg_we_o      (pipe_reg_we_o),
        .reg_waddr_o   (pipe_reg_waddr_o),
        .csr_we_o      (pipe_csr_we_o),
        .csr_waddr_o   (pipe_csr_waddr_o),
        .csr_raddr_o   (pipe_csr_raddr_o),
        .dec_imm_o     (pipe_dec_imm_o),
        .dec_info_bus_o(pipe_dec_info_bus_o),
        // 寄存rs1/rs2数据
        .rs1_rdata_o   (pipe_rs1_rdata_o),
        .rs2_rdata_o   (pipe_rs2_rdata_o),

        // ALU信号输出
        .req_alu_o     (req_alu_o),
        .alu_op1_o     (alu_op1_o),
        .alu_op2_o     (alu_op2_o),
        .alu_op_info_o (alu_op_info_o),
        .alu_pass_op1_o(alu_pass_op1_o),  // 连接旁路信号输出
        .alu_pass_op2_o(alu_pass_op2_o),  // 连接旁路
        // 新增MUL/DIV/CSR旁路信号输出
        .mul_pass_op1_o(mul_pass_op1_o),
        .mul_pass_op2_o(mul_pass_op2_o),
        .div_pass_op1_o(div_pass_op1_o),
        .div_pass_op2_o(div_pass_op2_o),
        .csr_pass_op1_o(csr_pass_op1_o),

        // BJP信号输出
        .req_bjp_o            (req_bjp_o),
        .bjp_op_jal_o         (bjp_op_jal_o),
        .bjp_op_beq_o         (bjp_op_beq_o),
        .bjp_op_bne_o         (bjp_op_bne_o),
        .bjp_op_blt_o         (bjp_op_blt_o),
        .bjp_op_bltu_o        (bjp_op_bltu_o),
        .bjp_op_bge_o         (bjp_op_bge_o),
        .bjp_op_bgeu_o        (bjp_op_bgeu_o),
        .bjp_op_jalr_o        (bjp_op_jalr_o),
        .bjp_adder_result_o   (bjp_adder_result_o),
        .bjp_next_pc_o        (bjp_next_pc_o),
        .op1_eq_op2_o         (op1_eq_op2_o),
        .op1_ge_op2_signed_o  (op1_ge_op2_signed_o),
        .op1_ge_op2_unsigned_o(op1_ge_op2_unsigned_o),

        // MUL信号输出
        .req_mul_o      (req_mul_o),
        .mul_op1_o      (mul_op1_o),
        .mul_op2_o      (mul_op2_o),
        .mul_op_mul_o   (mul_op_mul_o),
        .mul_op_mulh_o  (mul_op_mulh_o),
        .mul_op_mulhsu_o(mul_op_mulhsu_o),
        .mul_op_mulhu_o (mul_op_mulhu_o),

        // DIV信号输出
        .req_div_o    (req_div_o),
        .div_op1_o    (div_op1_o),
        .div_op2_o    (div_op2_o),
        .div_op_div_o (div_op_div_o),
        .div_op_divu_o(div_op_divu_o),
        .div_op_rem_o (div_op_rem_o),
        .div_op_remu_o(div_op_remu_o),

        // 删除原有的MULDIV信号输出

        // CSR信号输出
        .req_csr_o  (req_csr_o),
        .csr_op1_o  (csr_op1_o),
        .csr_addr_o (csr_addr_o),
        .csr_csrrw_o(csr_csrrw_o),
        .csr_csrrs_o(csr_csrrs_o),
        .csr_csrrc_o(csr_csrrc_o),

        // MEM信号输出
        .req_mem_o     (req_mem_o),
        .mem_op_lb_o   (mem_op_lb_o),
        .mem_op_lh_o   (mem_op_lh_o),
        .mem_op_lw_o   (mem_op_lw_o),
        .mem_op_lbu_o  (mem_op_lbu_o),
        .mem_op_lhu_o  (mem_op_lhu_o),
        .mem_op_load_o (mem_op_load_o),
        .mem_op_store_o(mem_op_store_o),
        .mem_addr_o    (mem_addr_o),
        .mem_wmask_o   (mem_wmask_o),
        .mem_wdata_o   (mem_wdata_o),

        // SYS信号输出
        .sys_op_nop_o      (sys_op_nop_o),
        .sys_op_mret_o     (sys_op_mret_o),
        .sys_op_ecall_o    (sys_op_ecall_o),
        .sys_op_ebreak_o   (sys_op_ebreak_o),
        .sys_op_fence_o    (sys_op_fence_o),
        .sys_op_dret_o     (sys_op_dret_o),
        .is_pred_branch_o  (is_pred_branch_o),    // 连接预测分支信号输出
        .misaligned_load_o (misaligned_load_o),
        .misaligned_store_o(misaligned_store_o),
        .illegal_inst_o    (illegal_inst_o)       // 新增：非法指令信号输出
    );

endmodule
