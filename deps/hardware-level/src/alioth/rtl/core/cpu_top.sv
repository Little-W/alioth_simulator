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

// alioth处理器核顶层模块
module cpu_top (

<<<<<<< Updated upstream
    input wire clk,
    input wire rst_n
=======
        input wire clk,
        input wire rst_n,
        // interrupt input
        input wire int_req_i,
        input wire[7:0] int_id_i,

>>>>>>> Stashed changes

        //内部信号外接
        //ex内部接线
        input  wire inst_dret_i,

<<<<<<< Updated upstream
=======
        //csr触发器匹配信号
        input wire trigger_match_i,

    );

>>>>>>> Stashed changes
    // pc_reg模块输出信号
    wire [`INST_ADDR_WIDTH-1:0] pc_pc_o;

    // if_id模块输出信号
    wire [`INST_DATA_WIDTH-1:0] if_inst_o;
    wire [`INST_ADDR_WIDTH-1:0] if_inst_addr_o;
    wire [`INST_DATA_WIDTH-1:0] if_int_flag_o;
    wire if_is_pred_branch_o;  // 添加预测分支信号线

    // id模块输出信号
    wire [`INST_ADDR_WIDTH-1:0] idu_inst_addr_o;
    wire idu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_reg_waddr_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_reg1_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_reg2_raddr_o;
    wire idu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] idu_csr_waddr_o;
    wire [`REG_DATA_WIDTH-1:0] idu_csr_rdata_o;
    wire [31:0] idu_dec_imm_o;
    wire [`DECINFO_WIDTH-1:0] idu_dec_info_bus_o;
    wire idu_is_pred_branch_o;  // 添加预测分支指令标志输出

    // exu模块输出信号
    wire exu_stall_flag_o;
    wire exu_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;
    wire [`REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire exu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;
    wire exu_muldiv_started_o;

    // 系统操作信号
    wire exu_ecall_o;
    wire exu_ebreak_o;
    wire exu_mret_o;
    wire ex_clint_inst_executed_o; // 新增指令执行完成信号

    // CSR寄存器写数据信号
    wire [`REG_DATA_WIDTH-1:0] exu_csr_reg_wdata_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_csr_reg_waddr_o;
    wire exu_csr_reg_we_o;  // 新增：csr_reg_we信号线

    // 新增csr_clint模块输出信号
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mie; // 新增：连接CSR中断使能寄存器

    // EXU的Commit ID信号
    wire [`COMMIT_ID_WIDTH-1:0] exu_csr_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_alu_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_muldiv_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_agu_commit_id_o;

    // CSR寄存器写数据信号
    wire [`REG_DATA_WIDTH-1:0] exu_csr_reg_wdata_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_csr_reg_waddr_o;
    wire exu_csr_reg_we_o;  // 新增：csr_reg_we信号线

    // EXU的Commit ID信号
    wire [`COMMIT_ID_WIDTH-1:0] exu_csr_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_alu_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_muldiv_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_agu_commit_id_o;

    // EXU到WBU的数据通路信号
    wire [`REG_DATA_WIDTH-1:0] exu_alu_reg_wdata_o;
    wire exu_alu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_alu_reg_waddr_o;

    wire [`REG_DATA_WIDTH-1:0] exu_muldiv_reg_wdata_o;
    wire exu_muldiv_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_muldiv_reg_waddr_o;

    wire [`REG_DATA_WIDTH-1:0] exu_agu_reg_wdata_o;
    wire exu_agu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_agu_reg_waddr_o;

    // wbu输出信号
    wire [`REG_DATA_WIDTH-1:0] wbu_reg_wdata_o;
    wire wbu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] wbu_reg_waddr_o;

    // WBU CSR输出信号
    wire [`REG_DATA_WIDTH-1:0] wbu_csr_wdata_o;
    wire wbu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] wbu_csr_waddr_o;

    // regs模块输出信号
    wire [`REG_DATA_WIDTH-1:0] regs_rdata1_o;
    wire [`REG_DATA_WIDTH-1:0] regs_rdata2_o;

    // csr_reg模块输出信号
    wire [`REG_DATA_WIDTH-1:0] csr_data_o;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_data_o;
    wire csr_global_int_en_o;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mtvec;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mepc;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mstatus;

    // ctrl模块输出信号
    wire [`CU_BUS_WIDTH-1:0] ctrl_stall_flag_o;
    wire ctrl_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] ctrl_jump_addr_o;

    // clint模块输出信号
    wire clint_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] clint_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] clint_raddr_o;
    wire [`REG_DATA_WIDTH-1:0] clint_data_o;
    wire [`INST_ADDR_WIDTH-1:0] clint_int_addr_o;
    wire clint_int_assert_o;
    wire clint_flush_flag_o;  // 添加中断刷新信号
    wire clint_stall_flag_o;

    wire [`BUS_DATA_WIDTH-1:0] exu_mem_data_i;

    // 新增信号定义
    wire ifu_read_resp_error_o;
    wire exu_mem_stall_o;
    wire exu_mem_store_busy_o;
    wire dispatch_stall_flag_o;
    wire dispatch_long_inst_atom_lock_o;
    wire [`COMMIT_ID_WIDTH-1:0] hdu_long_inst_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] wbu_commit_id_o;
    wire wbu_alu_ready_o;
    wire wbu_muldiv_ready_o;
    wire wbu_csr_ready_o;
    // 显式声明原子操作忙信号，避免隐式定义
    wire atom_opt_busy;
    // 添加缺少的信号声明
    wire wbu_commit_valid_o;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_commit_id_o;

    // 给dispatch和HDU的译码信息
    wire inst_valid = (ctrl_stall_flag_o == 0);
    wire                        inst_exu_valid = (ctrl_stall_flag_o == 0) && (idu_dec_info_bus_o[`DECINFO_GRP_BUS] != `DECINFO_GRP_NONE);
    // wire is_muldiv_long_inst = (idu_dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_MULDIV);
    // wire is_mem_long_inst = ((idu_dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM) && idu_dec_info_bus_o[`DECINFO_MEM_OP_LOAD]);
    // wire is_long_inst = is_muldiv_long_inst | is_mem_long_inst;
    wire rd_access_inst_valid = idu_reg_we_o && !ctrl_stall_flag_o;
    wire dis_is_pred_branch_o;
    // AXI接口信号 - IFU
    wire [`BUS_ID_WIDTH-1:0] ifu_axi_arid;  // 使用BUS_ID_WIDTH定义位宽
    wire [`INST_ADDR_WIDTH-1:0] ifu_axi_araddr;
    wire [7:0] ifu_axi_arlen;
    wire [2:0] ifu_axi_arsize;
    wire [1:0] ifu_axi_arburst;
    wire ifu_axi_arlock;
    wire [3:0] ifu_axi_arcache;
    wire [2:0] ifu_axi_arprot;
    wire [3:0] ifu_axi_arqos;
    wire [3:0] ifu_axi_aruser;
    wire ifu_axi_arvalid;
    wire ifu_axi_arready;
    wire [`BUS_ID_WIDTH-1:0] ifu_axi_rid;  // 使用BUS_ID_WIDTH定义位宽
    wire [`INST_DATA_WIDTH-1:0] ifu_axi_rdata;
    wire [1:0] ifu_axi_rresp;
    wire ifu_axi_rlast;
    wire [3:0] ifu_axi_ruser;
    wire ifu_axi_rvalid;
    wire ifu_axi_rready;

    // dispatch to ALU
    wire [31:0] dispatch_alu_op1;
    wire [31:0] dispatch_alu_op2;
    wire dispatch_req_alu;
    wire [`ALU_OP_WIDTH-1:0] dispatch_alu_op_info;

    // dispatch to Bru
    wire dispatch_req_bjp;
    wire [31:0] dispatch_bjp_op1;
    wire [31:0] dispatch_bjp_op2;
    wire [31:0] dispatch_bjp_jump_op1;
    wire [31:0] dispatch_bjp_jump_op2;
    wire dispatch_bjp_op_jump;
    wire dispatch_bjp_op_beq;
    wire dispatch_bjp_op_bne;
    wire dispatch_bjp_op_blt;
    wire dispatch_bjp_op_bltu;
    wire dispatch_bjp_op_bge;
    wire dispatch_bjp_op_bgeu;
    wire dispatch_bjp_op_jalr;

    // dispatch to MULDIV
    wire dispatch_req_muldiv;
    wire [31:0] dispatch_muldiv_op1;
    wire [31:0] dispatch_muldiv_op2;
    wire dispatch_muldiv_op_mul;
    wire dispatch_muldiv_op_mulh;
    wire dispatch_muldiv_op_mulhsu;
    wire dispatch_muldiv_op_mulhu;
    wire dispatch_muldiv_op_div;
    wire dispatch_muldiv_op_divu;
    wire dispatch_muldiv_op_rem;
    wire dispatch_muldiv_op_remu;
    wire dispatch_muldiv_op_mul_all;
    wire dispatch_muldiv_op_div_all;
    wire [1:0] dispatch_muldiv_commit_id;

    // dispatch to CSR
    wire dispatch_req_csr;
    wire [31:0] dispatch_csr_op1;
    wire [31:0] dispatch_csr_addr;
    wire dispatch_csr_csrrw;
    wire dispatch_csr_csrrs;
    wire dispatch_csr_csrrc;

    wire [`BUS_ADDR_WIDTH-1:0] idu_csr_raddr_o;
    wire dispatch_pipe_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] dispatch_pipe_reg_waddr_o;
    wire dispatch_pipe_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_pipe_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_pipe_csr_raddr_o;
    wire [31:0] dispatch_pipe_dec_imm_o;
    wire [`DECINFO_WIDTH-1:0] dispatch_pipe_dec_info_bus_o;
    wire [`INST_ADDR_WIDTH-1:0] pipe_inst_addr;

    // dispatch to MEM
    wire dispatch_req_mem;
    wire dispatch_mem_op_lb;
    wire dispatch_mem_op_lh;
    wire dispatch_mem_op_lw;
    wire dispatch_mem_op_lbu;
    wire dispatch_mem_op_lhu;
    wire dispatch_mem_op_load;
    wire dispatch_mem_op_store;
    wire [1:0] dispatch_mem_commit_id;
    wire [31:0] dispatch_mem_addr;
    wire [31:0] dispatch_mem_wdata;
    wire [3:0] dispatch_mem_wmask;

    // dispatch to SYS
    wire dispatch_sys_op_nop;
    wire dispatch_sys_op_mret;
    wire dispatch_sys_op_ecall;
    wire dispatch_sys_op_ebreak;
    wire dispatch_sys_op_fence;
    wire dispatch_sys_op_dret;

    wire [31:0] dispatch_rs1_rdata;
    wire [31:0] dispatch_rs2_rdata;

    // AXI接口信号 - EXU
    wire [`BUS_ID_WIDTH-1:0] exu_axi_awid;  // 使用BUS_ID_WIDTH定义位宽
    wire [31:0] exu_axi_awaddr;
    wire [7:0] exu_axi_awlen;
    wire [2:0] exu_axi_awsize;
    wire [1:0] exu_axi_awburst;
    wire exu_axi_awlock;
    wire [3:0] exu_axi_awcache;
    wire [2:0] exu_axi_awprot;
    wire [3:0] exu_axi_awqos;
    wire exu_axi_awuser;
    wire exu_axi_awvalid;
    wire exu_axi_awready;
    wire [31:0] exu_axi_wdata;
    wire [3:0] exu_axi_wstrb;
    wire exu_axi_wlast;
    wire exu_axi_wuser;
    wire exu_axi_wvalid;
    wire exu_axi_wready;
    wire [`BUS_ID_WIDTH-1:0] exu_axi_bid;  // 使用BUS_ID_WIDTH定义位宽
    wire [1:0] exu_axi_bresp;
    wire exu_axi_buser;
    wire exu_axi_bvalid;
    wire exu_axi_bready;
    wire [`BUS_ID_WIDTH-1:0] exu_axi_arid;  // 使用BUS_ID_WIDTH定义位宽
    wire [31:0] exu_axi_araddr;
    wire [7:0] exu_axi_arlen;
    wire [2:0] exu_axi_arsize;
    wire [1:0] exu_axi_arburst;
    wire exu_axi_arlock;
    wire [3:0] exu_axi_arcache;
    wire [2:0] exu_axi_arprot;
    wire [3:0] exu_axi_arqos;
    wire exu_axi_aruser;
    wire exu_axi_arvalid;
    wire exu_axi_arready;
    wire [`BUS_ID_WIDTH-1:0] exu_axi_rid;  // 使用BUS_ID_WIDTH定义位宽
    wire [31:0] exu_axi_rdata;
    wire [1:0] exu_axi_rresp;
    wire exu_axi_rlast;
    wire exu_axi_ruser;
    wire exu_axi_rvalid;
    wire exu_axi_rready;

    // IFU模块例化
    ifu u_ifu (
<<<<<<< Updated upstream
        .clk              (clk),
        .rst_n            (rst_n),
        .jump_flag_i      (ctrl_jump_flag_o),
        .jump_addr_i      (ctrl_jump_addr_o),
        .stall_flag_i     (ctrl_stall_flag_o),
        .inst_o           (if_inst_o),
        .inst_addr_o      (if_inst_addr_o),
        .read_resp_error_o(ifu_read_resp_error_o),
        .is_pred_branch_o (if_is_pred_branch_o),    // 连接预测分支信号输出
=======
            .clk              (clk),
            .rst_n            (rst_n),
            .jump_flag_i      (ctrl_jump_flag_o),
            .jump_addr_i      (ctrl_jump_addr_o),
            .stall_flag_i     (ctrl_stall_flag_o),
            .inst_o           (if_inst_o),
            .inst_addr_o      (if_inst_addr_o),
            .read_resp_error_o(ifu_read_resp_error_o),
            .is_pred_branch_o (if_is_pred_branch_o),    // 连接预测分支信号输出
>>>>>>> Stashed changes

            // AXI接口
            .M_AXI_ARID   (ifu_axi_arid),
            .M_AXI_ARADDR (ifu_axi_araddr),
            .M_AXI_ARLEN  (ifu_axi_arlen),
            .M_AXI_ARSIZE (ifu_axi_arsize),
            .M_AXI_ARBURST(ifu_axi_arburst),
            .M_AXI_ARLOCK (ifu_axi_arlock),
            .M_AXI_ARCACHE(ifu_axi_arcache),
            .M_AXI_ARPROT (ifu_axi_arprot),
            .M_AXI_ARQOS  (ifu_axi_arqos),
            .M_AXI_ARUSER (ifu_axi_aruser),
            .M_AXI_ARVALID(ifu_axi_arvalid),
            .M_AXI_ARREADY(ifu_axi_arready),
            .M_AXI_RID    (ifu_axi_rid),
            .M_AXI_RDATA  (ifu_axi_rdata),
            .M_AXI_RRESP  (ifu_axi_rresp),
            .M_AXI_RLAST  (ifu_axi_rlast),
            .M_AXI_RUSER  (ifu_axi_ruser),
            .M_AXI_RVALID (ifu_axi_rvalid),
            .M_AXI_RREADY (ifu_axi_rready)
        );

    // ctrl模块例化 - 修改使用来自dispatch的HDU暂停信号
    ctrl u_ctrl (
<<<<<<< Updated upstream
        .clk               (clk),
        .rst_n             (rst_n),
        .jump_flag_i       (exu_jump_flag_o),
        .jump_addr_i       (exu_jump_addr_o),
        .atom_opt_busy_i   (atom_opt_busy),
        .stall_flag_ex_i   (exu_stall_flag_o),
        .flush_flag_clint_i(clint_flush_flag_o),     // 添加连接到clint的flush信号
        .stall_flag_clint_i(clint_stall_flag_o),
        .stall_flag_hdu_i  (dispatch_stall_flag_o),  // 修改为从dispatch获取HDU暂停信号
        .stall_flag_o      (ctrl_stall_flag_o),
        .jump_flag_o       (ctrl_jump_flag_o),
        .jump_addr_o       (ctrl_jump_addr_o)
    );
=======
             .clk               (clk),
             .rst_n             (rst_n),
             .jump_flag_i       (exu_jump_flag_o),
             .jump_addr_i       (exu_jump_addr_o),
             .atom_opt_busy_i   (atom_opt_busy),
             .stall_flag_ex_i   (exu_stall_flag_o),
             .flush_flag_clint_i(clint_flush_flag_o),     // 添加连接到clint的flush信号
             .stall_flag_clint_i(clint_stall_flag_o),
             .stall_flag_hdu_i  (dispatch_stall_flag_o),  // 修改为从dispatch获取HDU暂停信号
             .stall_flag_o      (ctrl_stall_flag_o),
             .jump_flag_o       (ctrl_jump_flag_o),
             .jump_addr_o       (ctrl_jump_addr_o)
         );
>>>>>>> Stashed changes

    // gpr模块例化 - 注意：从dispatch pipe获取写地址
    gpr u_gpr (
            .clk     (clk),
            .rst_n   (rst_n),
            .we_i    (wbu_reg_we_o),
            .waddr_i (wbu_reg_waddr_o),
            .wdata_i (wbu_reg_wdata_o),
            .raddr1_i(idu_reg1_raddr_o),
            .rdata1_o(regs_rdata1_o),
            .raddr2_i(idu_reg2_raddr_o),
            .rdata2_o(regs_rdata2_o)
        );

    // csr模块例化 - 修改为从dispatch pipe获取CSR地址
    csr u_csr (
<<<<<<< Updated upstream
        .clk              (clk),
        .rst_n            (rst_n),
        .we_i             (wbu_csr_we_o),
        .raddr_i          (dispatch_pipe_csr_raddr_o),
        .waddr_i          (wbu_csr_waddr_o),
        .data_i           (wbu_csr_wdata_o),
        .inst_valid_i     (inst_exu_valid),
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

    // idu模块例化 - 更新接口，移除长指令ID相关接口
    idu u_idu (
        .clk             (clk),
        .rst_n           (rst_n),
        .inst_i          (if_inst_o),
        .inst_addr_i     (if_inst_addr_o),
        .stall_flag_i    (ctrl_stall_flag_o),
        .is_pred_branch_i(if_is_pred_branch_o), // 连接预测分支信号输入

        .csr_raddr_o     (idu_csr_raddr_o),
        .inst_addr_o     (idu_inst_addr_o),
        .reg_we_o        (idu_reg_we_o),
        .reg_waddr_o     (idu_reg_waddr_o),
        .reg1_raddr_o    (idu_reg1_raddr_o),
        .reg2_raddr_o    (idu_reg2_raddr_o),
        .csr_we_o        (idu_csr_we_o),
        .csr_waddr_o     (idu_csr_waddr_o),
        .dec_imm_o       (idu_dec_imm_o),
        .dec_info_bus_o  (idu_dec_info_bus_o),
        .is_pred_branch_o(idu_is_pred_branch_o)  // 连接预测分支信号输出
    );

    // 添加dispatch模块例化 - 修改增加新的接口
    dispatch u_dispatch (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall_flag_i(ctrl_stall_flag_o),

        // 输入译码信息
        .dec_info_bus_i  (idu_dec_info_bus_o),
        .dec_imm_i       (idu_dec_imm_o),
        .dec_pc_i        (idu_inst_addr_o),
        .rs1_rdata_i     (regs_rdata1_o),
        .rs2_rdata_i     (regs_rdata2_o),
        .is_pred_branch_i(idu_is_pred_branch_o), // 连接预测分支信号输入

        // 寄存器访问信息 - 用于HDU冒险检测
        .reg_waddr_i (idu_reg_waddr_o),
        .reg1_raddr_i(idu_reg1_raddr_o),
        .reg2_raddr_i(idu_reg2_raddr_o),
        .reg_we_i    (idu_reg_we_o),

        // 从IDU接收CSR信号
        .csr_we_i   (idu_csr_we_o),
        .csr_waddr_i(idu_csr_waddr_o),
        .csr_raddr_i(idu_csr_raddr_o),

        // 长指令有效信号 - 用于HDU
        .new_long_inst_valid_i(rd_access_inst_valid),

        // 写回阶段提交信号
        .commit_valid_i(wbu_commit_valid_o),
        .commit_id_i   (wbu_commit_id_o),

        // HDU输出信号
        .hazard_stall_o       (dispatch_stall_flag_o),
        .long_inst_atom_lock_o(dispatch_long_inst_atom_lock_o),
        .commit_id_o          (dispatch_commit_id_o),

        // 新增：额外的流水线寄存输出信号
        .pipe_reg_we_o      (dispatch_pipe_reg_we_o),
        .pipe_reg_waddr_o   (dispatch_pipe_reg_waddr_o),
        .pipe_csr_we_o      (dispatch_pipe_csr_we_o),
        .pipe_csr_waddr_o   (dispatch_pipe_csr_waddr_o),
        .pipe_csr_raddr_o   (dispatch_pipe_csr_raddr_o),
        .pipe_dec_imm_o     (dispatch_pipe_dec_imm_o),
        .pipe_dec_info_bus_o(dispatch_pipe_dec_info_bus_o),
        .pipe_inst_addr_o   (pipe_inst_addr),
        .pipe_rs1_rdata_o   (dispatch_rs1_rdata),
        .pipe_rs2_rdata_o   (dispatch_rs2_rdata),

        // 分发到各功能单元的信号
        .req_alu_o    (dispatch_req_alu),
        .alu_op1_o    (dispatch_alu_op1),
        .alu_op2_o    (dispatch_alu_op2),
        .alu_op_info_o(dispatch_alu_op_info),

        .req_bjp_o     (dispatch_req_bjp),
        .bjp_op1_o     (dispatch_bjp_op1),
        .bjp_op2_o     (dispatch_bjp_op2),
        .bjp_jump_op1_o(dispatch_bjp_jump_op1),
        .bjp_jump_op2_o(dispatch_bjp_jump_op2),
        .bjp_op_jump_o (dispatch_bjp_op_jump),
        .bjp_op_beq_o  (dispatch_bjp_op_beq),
        .bjp_op_bne_o  (dispatch_bjp_op_bne),
        .bjp_op_blt_o  (dispatch_bjp_op_blt),
        .bjp_op_bltu_o (dispatch_bjp_op_bltu),
        .bjp_op_bge_o  (dispatch_bjp_op_bge),
        .bjp_op_bgeu_o (dispatch_bjp_op_bgeu),
        .bjp_op_jalr_o (dispatch_bjp_op_jalr),

        .req_muldiv_o       (dispatch_req_muldiv),
        .muldiv_op1_o       (dispatch_muldiv_op1),
        .muldiv_op2_o       (dispatch_muldiv_op2),
        .muldiv_op_mul_o    (dispatch_muldiv_op_mul),
        .muldiv_op_mulh_o   (dispatch_muldiv_op_mulh),
        .muldiv_op_mulhsu_o (dispatch_muldiv_op_mulhsu),
        .muldiv_op_mulhu_o  (dispatch_muldiv_op_mulhu),
        .muldiv_op_div_o    (dispatch_muldiv_op_div),
        .muldiv_op_divu_o   (dispatch_muldiv_op_divu),
        .muldiv_op_rem_o    (dispatch_muldiv_op_rem),
        .muldiv_op_remu_o   (dispatch_muldiv_op_remu),
        .muldiv_op_mul_all_o(dispatch_muldiv_op_mul_all),
        .muldiv_op_div_all_o(dispatch_muldiv_op_div_all),
        .muldiv_commit_id_o (dispatch_muldiv_commit_id),

        .req_csr_o  (dispatch_req_csr),
        .csr_op1_o  (dispatch_csr_op1),
        .csr_addr_o (dispatch_csr_addr),
        .csr_csrrw_o(dispatch_csr_csrrw),
        .csr_csrrs_o(dispatch_csr_csrrs),
        .csr_csrrc_o(dispatch_csr_csrrc),

        .req_mem_o       (dispatch_req_mem),
        .mem_op_lb_o     (dispatch_mem_op_lb),
        .mem_op_lh_o     (dispatch_mem_op_lh),
        .mem_op_lw_o     (dispatch_mem_op_lw),
        .mem_op_lbu_o    (dispatch_mem_op_lbu),
        .mem_op_lhu_o    (dispatch_mem_op_lhu),
        .mem_op_load_o   (dispatch_mem_op_load),
        .mem_op_store_o  (dispatch_mem_op_store),
        .mem_commit_id_o (dispatch_mem_commit_id),
        .mem_addr_o      (dispatch_mem_addr),
        .mem_wmask_o     (dispatch_mem_wmask),
        .mem_wdata_o     (dispatch_mem_wdata),
        .sys_op_nop_o    (dispatch_sys_op_nop),
        .sys_op_mret_o   (dispatch_sys_op_mret),
        .sys_op_ecall_o  (dispatch_sys_op_ecall),
        .sys_op_ebreak_o (dispatch_sys_op_ebreak),
        .sys_op_fence_o  (dispatch_sys_op_fence),
        .sys_op_dret_o   (dispatch_sys_op_dret),
        .is_pred_branch_o(dis_is_pred_branch_o)     // 连接预测分支信号输出
    );

    // exu模块例化 - 修改commit_id相关连接
    exu u_exu (
        .clk(clk),
        .rst_n(rst_n),
        .inst_addr_i(pipe_inst_addr),  // 从dispatch pipe获取指令地址
        .reg_we_i(dispatch_pipe_reg_we_o),  // 修改为从dispatch pipe获取寄存器写使能
        .reg_waddr_i   (dispatch_pipe_reg_waddr_o),        // 修改为从dispatch pipe获取寄存器写地址
        .csr_we_i(dispatch_pipe_csr_we_o),  // 修改为从dispatch pipe获取CSR写使能
        .csr_waddr_i(dispatch_pipe_csr_waddr_o),  // 修改为从dispatch pipe获取CSR写地址
        .csr_rdata_i(csr_data_o),
        .dec_info_bus_i(dispatch_pipe_dec_info_bus_o),     // 修改为从dispatch pipe获取译码信息总线
        .dec_imm_i(dispatch_pipe_dec_imm_o),  // 修改为从dispatch pipe获取立即数
        .mem_rdata_i(exu_mem_data_i),
        .int_assert_i(clint_int_assert_o),
        .int_addr_i(clint_int_addr_o),
        .is_pred_branch_i(dis_is_pred_branch_o),  // 连接预测分支信号输入

        // 修改：从dispatch获取长指令ID
        .commit_id_i(dispatch_commit_id_o),
=======
            .clk              (clk),
            .rst_n            (rst_n),
            .we_i             (wbu_csr_we_o),
            .raddr_i          (dispatch_pipe_csr_raddr_o),
            .waddr_i          (wbu_csr_waddr_o),
            .data_i           (wbu_csr_wdata_o),
            .inst_valid_i     (inst_exu_valid),
            .data_o           (csr_data_o),
            .global_int_en_o  (csr_global_int_en_o),
            .clint_we_i       (clint_we_o),
            .clint_raddr_i    (clint_raddr_o),
            .clint_waddr_i    (clint_waddr_o),
            .clint_data_i     (clint_data_o),
            .clint_data_o     (csr_clint_data_o),
            .clint_csr_mtvec  (csr_clint_csr_mtvec),
            .clint_csr_mepc   (csr_clint_csr_mepc),
            .clint_csr_mstatus(csr_clint_csr_mstatus),
            // 新增：连接clint
            .clint_csr_mie    (csr_clint_csr_mie)
        );

    // idu模块例化 - 更新接口，移除长指令ID相关接口
    idu u_idu (
            .clk             (clk),
            .rst_n           (rst_n),
            .inst_i          (if_inst_o),
            .inst_addr_i     (if_inst_addr_o),
            .stall_flag_i    (ctrl_stall_flag_o),
            .is_pred_branch_i(if_is_pred_branch_o), // 连接预测分支信号输入

            .csr_raddr_o     (idu_csr_raddr_o),
            .inst_addr_o     (idu_inst_addr_o),
            .reg_we_o        (idu_reg_we_o),
            .reg_waddr_o     (idu_reg_waddr_o),
            .reg1_raddr_o    (idu_reg1_raddr_o),
            .reg2_raddr_o    (idu_reg2_raddr_o),
            .csr_we_o        (idu_csr_we_o),
            .csr_waddr_o     (idu_csr_waddr_o),
            .dec_imm_o       (idu_dec_imm_o),
            .dec_info_bus_o  (idu_dec_info_bus_o),
            .is_pred_branch_o(idu_is_pred_branch_o)  // 连接预测分支信号输出
        );

    // 添加dispatch模块例化 - 修改增加新的接口
    dispatch u_dispatch (
                 .clk         (clk),
                 .rst_n       (rst_n),
                 .stall_flag_i(ctrl_stall_flag_o),

                 // 输入译码信息
                 .dec_info_bus_i  (idu_dec_info_bus_o),
                 .dec_imm_i       (idu_dec_imm_o),
                 .dec_pc_i        (idu_inst_addr_o),
                 .rs1_rdata_i     (regs_rdata1_o),
                 .rs2_rdata_i     (regs_rdata2_o),
                 .is_pred_branch_i(idu_is_pred_branch_o), // 连接预测分支信号输入

                 // 寄存器访问信息 - 用于HDU冒险检测
                 .reg_waddr_i (idu_reg_waddr_o),
                 .reg1_raddr_i(idu_reg1_raddr_o),
                 .reg2_raddr_i(idu_reg2_raddr_o),
                 .reg_we_i    (idu_reg_we_o),

                 // 从IDU接收CSR信号
                 .csr_we_i   (idu_csr_we_o),
                 .csr_waddr_i(idu_csr_waddr_o),
                 .csr_raddr_i(idu_csr_raddr_o),

                 // 长指令有效信号 - 用于HDU
                 .new_long_inst_valid_i(rd_access_inst_valid),

                 // 写回阶段提交信号
                 .commit_valid_i(wbu_commit_valid_o),
                 .commit_id_i   (wbu_commit_id_o),

                 // HDU输出信号
                 .hazard_stall_o       (dispatch_stall_flag_o),
                 .long_inst_atom_lock_o(dispatch_long_inst_atom_lock_o),
                 .commit_id_o          (dispatch_commit_id_o),

                 // 新增：额外的流水线寄存输出信号
                 .pipe_reg_we_o      (dispatch_pipe_reg_we_o),
                 .pipe_reg_waddr_o   (dispatch_pipe_reg_waddr_o),
                 .pipe_csr_we_o      (dispatch_pipe_csr_we_o),
                 .pipe_csr_waddr_o   (dispatch_pipe_csr_waddr_o),
                 .pipe_csr_raddr_o   (dispatch_pipe_csr_raddr_o),
                 .pipe_dec_imm_o     (dispatch_pipe_dec_imm_o),
                 .pipe_dec_info_bus_o(dispatch_pipe_dec_info_bus_o),
                 .pipe_inst_addr_o   (pipe_inst_addr),
                 .pipe_rs1_rdata_o   (dispatch_rs1_rdata),
                 .pipe_rs2_rdata_o   (dispatch_rs2_rdata),

                 // 分发到各功能单元的信号
                 .req_alu_o    (dispatch_req_alu),
                 .alu_op1_o    (dispatch_alu_op1),
                 .alu_op2_o    (dispatch_alu_op2),
                 .alu_op_info_o(dispatch_alu_op_info),

                 .req_bjp_o     (dispatch_req_bjp),
                 .bjp_op1_o     (dispatch_bjp_op1),
                 .bjp_op2_o     (dispatch_bjp_op2),
                 .bjp_jump_op1_o(dispatch_bjp_jump_op1),
                 .bjp_jump_op2_o(dispatch_bjp_jump_op2),
                 .bjp_op_jump_o (dispatch_bjp_op_jump),
                 .bjp_op_beq_o  (dispatch_bjp_op_beq),
                 .bjp_op_bne_o  (dispatch_bjp_op_bne),
                 .bjp_op_blt_o  (dispatch_bjp_op_blt),
                 .bjp_op_bltu_o (dispatch_bjp_op_bltu),
                 .bjp_op_bge_o  (dispatch_bjp_op_bge),
                 .bjp_op_bgeu_o (dispatch_bjp_op_bgeu),
                 .bjp_op_jalr_o (dispatch_bjp_op_jalr),

                 .req_muldiv_o       (dispatch_req_muldiv),
                 .muldiv_op1_o       (dispatch_muldiv_op1),
                 .muldiv_op2_o       (dispatch_muldiv_op2),
                 .muldiv_op_mul_o    (dispatch_muldiv_op_mul),
                 .muldiv_op_mulh_o   (dispatch_muldiv_op_mulh),
                 .muldiv_op_mulhsu_o (dispatch_muldiv_op_mulhsu),
                 .muldiv_op_mulhu_o  (dispatch_muldiv_op_mulhu),
                 .muldiv_op_div_o    (dispatch_muldiv_op_div),
                 .muldiv_op_divu_o   (dispatch_muldiv_op_divu),
                 .muldiv_op_rem_o    (dispatch_muldiv_op_rem),
                 .muldiv_op_remu_o   (dispatch_muldiv_op_remu),
                 .muldiv_op_mul_all_o(dispatch_muldiv_op_mul_all),
                 .muldiv_op_div_all_o(dispatch_muldiv_op_div_all),
                 .muldiv_commit_id_o (dispatch_muldiv_commit_id),

                 .req_csr_o  (dispatch_req_csr),
                 .csr_op1_o  (dispatch_csr_op1),
                 .csr_addr_o (dispatch_csr_addr),
                 .csr_csrrw_o(dispatch_csr_csrrw),
                 .csr_csrrs_o(dispatch_csr_csrrs),
                 .csr_csrrc_o(dispatch_csr_csrrc),

                 .req_mem_o       (dispatch_req_mem),
                 .mem_op_lb_o     (dispatch_mem_op_lb),
                 .mem_op_lh_o     (dispatch_mem_op_lh),
                 .mem_op_lw_o     (dispatch_mem_op_lw),
                 .mem_op_lbu_o    (dispatch_mem_op_lbu),
                 .mem_op_lhu_o    (dispatch_mem_op_lhu),
                 .mem_op_load_o   (dispatch_mem_op_load),
                 .mem_op_store_o  (dispatch_mem_op_store),
                 .mem_commit_id_o (dispatch_mem_commit_id),
                 .mem_addr_o      (dispatch_mem_addr),
                 .mem_wmask_o     (dispatch_mem_wmask),
                 .mem_wdata_o     (dispatch_mem_wdata),
                 .sys_op_nop_o    (dispatch_sys_op_nop),
                 .sys_op_mret_o   (dispatch_sys_op_mret),
                 .sys_op_ecall_o  (dispatch_sys_op_ecall),
                 .sys_op_ebreak_o (dispatch_sys_op_ebreak),
                 .sys_op_fence_o  (dispatch_sys_op_fence),
                 .sys_op_dret_o   (dispatch_sys_op_dret),
                 .is_pred_branch_o(dis_is_pred_branch_o)     // 连接预测分支信号输出
             );

    // exu模块例化 - 直接从HDU接收长指令ID
    exu u_exu (
            .clk(clk),
            .rst_n(rst_n),
            .inst_addr_i(pipe_inst_addr),  // 从dispatch pipe获取指令地址
            .reg_we_i(dispatch_pipe_reg_we_o),  // 修改为从dispatch pipe获取寄存器写使能
            .reg_waddr_i   (dispatch_pipe_reg_waddr_o),        // 修改为从dispatch pipe获取寄存器写地址
            .csr_we_i(dispatch_pipe_csr_we_o),  // 修改为从dispatch pipe获取CSR写使能
            .csr_waddr_i(dispatch_pipe_csr_waddr_o),  // 修改为从dispatch pipe获取CSR写地址
            .csr_rdata_i(csr_data_o),
            .dec_info_bus_i(dispatch_pipe_dec_info_bus_o),     // 修改为从dispatch pipe获取译码信息总线
            .dec_imm_i(dispatch_pipe_dec_imm_o),  // 修改为从dispatch pipe获取立即数
            .mem_rdata_i(exu_mem_data_i),
            .int_assert_i(clint_int_assert_o),
            .int_addr_i(clint_int_addr_o),
            .is_pred_branch_i(dis_is_pred_branch_o),  // 连接预测分支信号输入

            // 修改：从dispatch获取长指令ID
            .commit_id_i(dispatch_commit_id_o),
>>>>>>> Stashed changes

            // 写回握手信号
            .alu_wb_ready_i   (wbu_alu_ready_o),
            .muldiv_wb_ready_i(wbu_muldiv_ready_o),
            .csr_wb_ready_i   (wbu_csr_ready_o),

<<<<<<< Updated upstream
        .reg1_rdata_i(dispatch_rs1_rdata),
        .reg2_rdata_i(dispatch_rs2_rdata),

        .hazard_stall_i(dispatch_stall_flag_o),

        // 从dispatch获取的信号
        .req_alu_i    (dispatch_req_alu),
        .alu_op1_i    (dispatch_alu_op1),
        .alu_op2_i    (dispatch_alu_op2),
        .alu_op_info_i(dispatch_alu_op_info),

        .req_bjp_i     (dispatch_req_bjp),
        .bjp_op1_i     (dispatch_bjp_op1),
        .bjp_op2_i     (dispatch_bjp_op2),
        .bjp_jump_op1_i(dispatch_bjp_jump_op1),
        .bjp_jump_op2_i(dispatch_bjp_jump_op2),
        .bjp_op_jump_i (dispatch_bjp_op_jump),
        .bjp_op_beq_i  (dispatch_bjp_op_beq),
        .bjp_op_bne_i  (dispatch_bjp_op_bne),
        .bjp_op_blt_i  (dispatch_bjp_op_blt),
        .bjp_op_bltu_i (dispatch_bjp_op_bltu),
        .bjp_op_bge_i  (dispatch_bjp_op_bge),
        .bjp_op_bgeu_i (dispatch_bjp_op_bgeu),
        .bjp_op_jalr_i (dispatch_bjp_op_jalr),

        .req_muldiv_i       (dispatch_req_muldiv),
        .muldiv_op1_i       (dispatch_muldiv_op1),
        .muldiv_op2_i       (dispatch_muldiv_op2),
        .muldiv_op_mul_i    (dispatch_muldiv_op_mul),
        .muldiv_op_mulh_i   (dispatch_muldiv_op_mulh),
        .muldiv_op_mulhsu_i (dispatch_muldiv_op_mulhsu),
        .muldiv_op_mulhu_i  (dispatch_muldiv_op_mulhu),
        .muldiv_op_div_i    (dispatch_muldiv_op_div),
        .muldiv_op_divu_i   (dispatch_muldiv_op_divu),
        .muldiv_op_rem_i    (dispatch_muldiv_op_rem),
        .muldiv_op_remu_i   (dispatch_muldiv_op_remu),
        .muldiv_op_mul_all_i(dispatch_muldiv_op_mul_all),
        .muldiv_op_div_all_i(dispatch_muldiv_op_div_all),
        .muldiv_commit_id_i (dispatch_muldiv_commit_id),

        .req_csr_i  (dispatch_req_csr),
        .csr_op1_i  (dispatch_csr_op1),
        .csr_addr_i (dispatch_csr_addr),
        .csr_csrrw_i(dispatch_csr_csrrw),
        .csr_csrrs_i(dispatch_csr_csrrs),
        .csr_csrrc_i(dispatch_csr_csrrc),

        .req_mem_i      (dispatch_req_mem),
        .mem_op_lb_i    (dispatch_mem_op_lb),
        .mem_op_lh_i    (dispatch_mem_op_lh),
        .mem_op_lw_i    (dispatch_mem_op_lw),
        .mem_op_lbu_i   (dispatch_mem_op_lbu),
        .mem_op_lhu_i   (dispatch_mem_op_lhu),
        .mem_op_load_i  (dispatch_mem_op_load),
        .mem_op_store_i (dispatch_mem_op_store),
        .mem_commit_id_i(dispatch_mem_commit_id),
        .mem_addr_i     (dispatch_mem_addr),
        .mem_wdata_i    (dispatch_mem_wdata),
        .mem_wmask_i    (dispatch_mem_wmask),

        .sys_op_nop_i   (dispatch_sys_op_nop),
        .sys_op_mret_i  (dispatch_sys_op_mret),
        .sys_op_ecall_i (dispatch_sys_op_ecall),
        .sys_op_ebreak_i(dispatch_sys_op_ebreak),
        .sys_op_fence_i (dispatch_sys_op_fence),
        .sys_op_dret_i  (dispatch_sys_op_dret),
=======
            .reg1_rdata_i(dispatch_rs1_rdata),
            .reg2_rdata_i(dispatch_rs2_rdata),
>>>>>>> Stashed changes

            .hazard_stall_i(dispatch_stall_flag_o),

<<<<<<< Updated upstream
        .alu_reg_wdata_o(exu_alu_reg_wdata_o),
        .alu_reg_we_o   (exu_alu_reg_we_o),
        .alu_reg_waddr_o(exu_alu_reg_waddr_o),
        .alu_commit_id_o(exu_alu_commit_id_o),

        .muldiv_reg_wdata_o(exu_muldiv_reg_wdata_o),
        .muldiv_reg_we_o   (exu_muldiv_reg_we_o),
        .muldiv_reg_waddr_o(exu_muldiv_reg_waddr_o),
        .muldiv_commit_id_o(exu_muldiv_commit_id_o),

        .agu_reg_wdata_o(exu_agu_reg_wdata_o),
        .agu_reg_we_o   (exu_agu_reg_we_o),
        .agu_reg_waddr_o(exu_agu_reg_waddr_o),
        .agu_commit_id_o(exu_agu_commit_id_o),

        // 连接CSR寄存器写数据信号
        .csr_reg_wdata_o(exu_csr_reg_wdata_o),
        .csr_reg_waddr_o(exu_csr_reg_waddr_o),
        .csr_commit_id_o(exu_csr_commit_id_o),  // 添加缺失的CSR commit_id输出连接
        .csr_reg_we_o   (exu_csr_reg_we_o),     // 新增：连接csr_reg_we_o
=======
            // 从dispatch获取的信号
            .req_alu_i    (dispatch_req_alu),
            .alu_op1_i    (dispatch_alu_op1),
            .alu_op2_i    (dispatch_alu_op2),
            .alu_op_info_i(dispatch_alu_op_info),

            .req_bjp_i     (dispatch_req_bjp),
            .bjp_op1_i     (dispatch_bjp_op1),
            .bjp_op2_i     (dispatch_bjp_op2),
            .bjp_jump_op1_i(dispatch_bjp_jump_op1),
            .bjp_jump_op2_i(dispatch_bjp_jump_op2),
            .bjp_op_jump_i (dispatch_bjp_op_jump),
            .bjp_op_beq_i  (dispatch_bjp_op_beq),
            .bjp_op_bne_i  (dispatch_bjp_op_bne),
            .bjp_op_blt_i  (dispatch_bjp_op_blt),
            .bjp_op_bltu_i (dispatch_bjp_op_bltu),
            .bjp_op_bge_i  (dispatch_bjp_op_bge),
            .bjp_op_bgeu_i (dispatch_bjp_op_bgeu),
            .bjp_op_jalr_i (dispatch_bjp_op_jalr),

            .req_muldiv_i       (dispatch_req_muldiv),
            .muldiv_op1_i       (dispatch_muldiv_op1),
            .muldiv_op2_i       (dispatch_muldiv_op2),
            .muldiv_op_mul_i    (dispatch_muldiv_op_mul),
            .muldiv_op_mulh_i   (dispatch_muldiv_op_mulh),
            .muldiv_op_mulhsu_i (dispatch_muldiv_op_mulhsu),
            .muldiv_op_mulhu_i  (dispatch_muldiv_op_mulhu),
            .muldiv_op_div_i    (dispatch_muldiv_op_div),
            .muldiv_op_divu_i   (dispatch_muldiv_op_divu),
            .muldiv_op_rem_i    (dispatch_muldiv_op_rem),
            .muldiv_op_remu_i   (dispatch_muldiv_op_remu),
            .muldiv_op_mul_all_i(dispatch_muldiv_op_mul_all),
            .muldiv_op_div_all_i(dispatch_muldiv_op_div_all),
            .muldiv_commit_id_i (dispatch_muldiv_commit_id),

            .req_csr_i  (dispatch_req_csr),
            .csr_op1_i  (dispatch_csr_op1),
            .csr_addr_i (dispatch_csr_addr),
            .csr_csrrw_i(dispatch_csr_csrrw),
            .csr_csrrs_i(dispatch_csr_csrrs),
            .csr_csrrc_i(dispatch_csr_csrrc),
>>>>>>> Stashed changes

            .req_mem_i      (dispatch_req_mem),
            .mem_op_lb_i    (dispatch_mem_op_lb),
            .mem_op_lh_i    (dispatch_mem_op_lh),
            .mem_op_lw_i    (dispatch_mem_op_lw),
            .mem_op_lbu_i   (dispatch_mem_op_lbu),
            .mem_op_lhu_i   (dispatch_mem_op_lhu),
            .mem_op_load_i  (dispatch_mem_op_load),
            .mem_op_store_i (dispatch_mem_op_store),
            .mem_commit_id_i(dispatch_mem_commit_id),
            .mem_addr_i     (dispatch_mem_addr),
            .mem_wdata_i    (dispatch_mem_wdata),
            .mem_wmask_i    (dispatch_mem_wmask),

            .sys_op_nop_i   (dispatch_sys_op_nop),
            .sys_op_mret_i  (dispatch_sys_op_mret),
            .sys_op_ecall_i (dispatch_sys_op_ecall),
            .sys_op_ebreak_i(dispatch_sys_op_ebreak),
            .sys_op_fence_i (dispatch_sys_op_fence),
            .sys_op_dret_i  (dispatch_sys_op_dret),

            .mem_stall_o     (exu_mem_stall_o),
            .mem_store_busy_o(exu_mem_store_busy_o),

<<<<<<< Updated upstream
        // 添加AXI接口连接 - 保持不变
        .M_AXI_AWID   (exu_axi_awid),
        .M_AXI_AWADDR (exu_axi_awaddr),
        .M_AXI_AWLEN  (exu_axi_awlen),
        .M_AXI_AWSIZE (exu_axi_awsize),
        .M_AXI_AWBURST(exu_axi_awburst),
        .M_AXI_AWLOCK (exu_axi_awlock),
        .M_AXI_AWCACHE(exu_axi_awcache),
        .M_AXI_AWPROT (exu_axi_awprot),
        .M_AXI_AWQOS  (exu_axi_awqos),
        .M_AXI_AWUSER (exu_axi_awuser),
        .M_AXI_AWVALID(exu_axi_awvalid),
        .M_AXI_AWREADY(exu_axi_awready),
        .M_AXI_WDATA  (exu_axi_wdata),
        .M_AXI_WSTRB  (exu_axi_wstrb),
        .M_AXI_WLAST  (exu_axi_wlast),
        .M_AXI_WUSER  (exu_axi_wuser),
        .M_AXI_WVALID (exu_axi_wvalid),
        .M_AXI_WREADY (exu_axi_wready),
        .M_AXI_BID    (exu_axi_bid),
        .M_AXI_BRESP  (exu_axi_bresp),
        .M_AXI_BUSER  (exu_axi_buser),
        .M_AXI_BVALID (exu_axi_bvalid),
        .M_AXI_BREADY (exu_axi_bready),
        .M_AXI_ARID   (exu_axi_arid),
        .M_AXI_ARADDR (exu_axi_araddr),
        .M_AXI_ARLEN  (exu_axi_arlen),
        .M_AXI_ARSIZE (exu_axi_arsize),
        .M_AXI_ARBURST(exu_axi_arburst),
        .M_AXI_ARLOCK (exu_axi_arlock),
        .M_AXI_ARCACHE(exu_axi_arcache),
        .M_AXI_ARPROT (exu_axi_arprot),
        .M_AXI_ARQOS  (exu_axi_arqos),
        .M_AXI_ARUSER (exu_axi_aruser),
        .M_AXI_ARVALID(exu_axi_arvalid),
        .M_AXI_ARREADY(exu_axi_arready),
        .M_AXI_RID    (exu_axi_rid),
        .M_AXI_RDATA  (exu_axi_rdata),
        .M_AXI_RRESP  (exu_axi_rresp),
        .M_AXI_RLAST  (exu_axi_rlast),
        .M_AXI_RUSER  (exu_axi_ruser),
        .M_AXI_RVALID (exu_axi_rvalid),
        .M_AXI_RREADY (exu_axi_rready)
    );
=======
            .alu_reg_wdata_o(exu_alu_reg_wdata_o),
            .alu_reg_we_o   (exu_alu_reg_we_o),
            .alu_reg_waddr_o(exu_alu_reg_waddr_o),
            .alu_commit_id_o(exu_alu_commit_id_o),

            .muldiv_reg_wdata_o(exu_muldiv_reg_wdata_o),
            .muldiv_reg_we_o   (exu_muldiv_reg_we_o),
            .muldiv_reg_waddr_o(exu_muldiv_reg_waddr_o),
            .muldiv_commit_id_o(exu_muldiv_commit_id_o),

            .agu_reg_wdata_o(exu_agu_reg_wdata_o),
            .agu_reg_we_o   (exu_agu_reg_we_o),
            .agu_reg_waddr_o(exu_agu_reg_waddr_o),
            .agu_commit_id_o(exu_agu_commit_id_o),

            // 连接CSR寄存器写数据信号
            .csr_reg_wdata_o(exu_csr_reg_wdata_o),
            .csr_reg_waddr_o(exu_csr_reg_waddr_o),
            .csr_commit_id_o(exu_csr_commit_id_o),  // 添加缺失的CSR commit_id输出连接
            .csr_reg_we_o   (exu_csr_reg_we_o),     // 新增：连接csr_reg_we_o

            .csr_wdata_o(exu_csr_wdata_o),
            .csr_we_o   (exu_csr_we_o),
            .csr_waddr_o(exu_csr_waddr_o),

            .stall_flag_o    (exu_stall_flag_o),
            .jump_flag_o     (exu_jump_flag_o),
            .jump_addr_o     (exu_jump_addr_o),
            .muldiv_started_o(exu_muldiv_started_o),

            // 系统操作信号输出
            .exu_op_ecall_o (exu_ecall_o),
            .exu_op_ebreak_o(exu_ebreak_o),
            .exu_op_mret_o  (exu_mret_o),

            // 新增指令执行完成信号to clint
            .inst_executed_o (ex_clint_inst_executed_o),

            // 添加AXI接口连接 - 保持不变
            .M_AXI_AWID   (exu_axi_awid),
            .M_AXI_AWADDR (exu_axi_awaddr),
            .M_AXI_AWLEN  (exu_axi_awlen),
            .M_AXI_AWSIZE (exu_axi_awsize),
            .M_AXI_AWBURST(exu_axi_awburst),
            .M_AXI_AWLOCK (exu_axi_awlock),
            .M_AXI_AWCACHE(exu_axi_awcache),
            .M_AXI_AWPROT (exu_axi_awprot),
            .M_AXI_AWQOS  (exu_axi_awqos),
            .M_AXI_AWUSER (exu_axi_awuser),
            .M_AXI_AWVALID(exu_axi_awvalid),
            .M_AXI_AWREADY(exu_axi_awready),
            .M_AXI_WDATA  (exu_axi_wdata),
            .M_AXI_WSTRB  (exu_axi_wstrb),
            .M_AXI_WLAST  (exu_axi_wlast),
            .M_AXI_WUSER  (exu_axi_wuser),
            .M_AXI_WVALID (exu_axi_wvalid),
            .M_AXI_WREADY (exu_axi_wready),
            .M_AXI_BID    (exu_axi_bid),
            .M_AXI_BRESP  (exu_axi_bresp),
            .M_AXI_BUSER  (exu_axi_buser),
            .M_AXI_BVALID (exu_axi_bvalid),
            .M_AXI_BREADY (exu_axi_bready),
            .M_AXI_ARID   (exu_axi_arid),
            .M_AXI_ARADDR (exu_axi_araddr),
            .M_AXI_ARLEN  (exu_axi_arlen),
            .M_AXI_ARSIZE (exu_axi_arsize),
            .M_AXI_ARBURST(exu_axi_arburst),
            .M_AXI_ARLOCK (exu_axi_arlock),
            .M_AXI_ARCACHE(exu_axi_arcache),
            .M_AXI_ARPROT (exu_axi_arprot),
            .M_AXI_ARQOS  (exu_axi_arqos),
            .M_AXI_ARUSER (exu_axi_aruser),
            .M_AXI_ARVALID(exu_axi_arvalid),
            .M_AXI_ARREADY(exu_axi_arready),
            .M_AXI_RID    (exu_axi_rid),
            .M_AXI_RDATA  (exu_axi_rdata),
            .M_AXI_RRESP  (exu_axi_rresp),
            .M_AXI_RLAST  (exu_axi_rlast),
            .M_AXI_RUSER  (exu_axi_ruser),
            .M_AXI_RVALID (exu_axi_rvalid),
            .M_AXI_RREADY (exu_axi_rready)
        );
>>>>>>> Stashed changes

    // wbu模块例化 - 更新commit_id相关连接
    wbu u_wbu (
            .clk  (clk),
            .rst_n(rst_n),

<<<<<<< Updated upstream
        .alu_reg_wdata_i(exu_alu_reg_wdata_o),
        .alu_reg_we_i   (exu_alu_reg_we_o),
        .alu_reg_waddr_i(exu_alu_reg_waddr_o),
        .alu_commit_id_i(exu_alu_commit_id_o),  // 连接ALU commit_id
        .alu_ready_o    (wbu_alu_ready_o),

        .muldiv_reg_wdata_i(exu_muldiv_reg_wdata_o),
        .muldiv_reg_we_i   (exu_muldiv_reg_we_o),
        .muldiv_reg_waddr_i(exu_muldiv_reg_waddr_o),
        .muldiv_commit_id_i(exu_muldiv_commit_id_o),  // 直接使用全宽度
        .muldiv_ready_o    (wbu_muldiv_ready_o),

        .csr_wdata_i    (exu_csr_wdata_o),
        .csr_we_i       (exu_csr_we_o),
        .csr_waddr_i    (exu_csr_waddr_o),
        .csr_commit_id_i(exu_csr_commit_id_o),  // 连接CSR commit_id
        .csr_ready_o    (wbu_csr_ready_o),

        // CSR对通用寄存器的写数据输入
        .csr_reg_wdata_i(exu_csr_reg_wdata_o),
        .csr_reg_waddr_i(exu_csr_reg_waddr_o),
        .csr_reg_we_i   (exu_csr_reg_we_o),     // 新增：csr_reg_we输入端口

        .agu_reg_wdata_i(exu_agu_reg_wdata_o),
        .agu_reg_we_i   (exu_agu_reg_we_o),
        .agu_reg_waddr_i(exu_agu_reg_waddr_o),
        .agu_commit_id_i(exu_agu_commit_id_o),  // 直接使用全宽度

        .idu_reg_waddr_i(dispatch_pipe_reg_waddr_o), // 修改为从dispatch pipe获取IDU寄存器写地址
=======
            .alu_reg_wdata_i(exu_alu_reg_wdata_o),
            .alu_reg_we_i   (exu_alu_reg_we_o),
            .alu_reg_waddr_i(exu_alu_reg_waddr_o),
            .alu_commit_id_i(exu_alu_commit_id_o),  // 连接ALU commit_id
            .alu_ready_o    (wbu_alu_ready_o),

            .muldiv_reg_wdata_i(exu_muldiv_reg_wdata_o),
            .muldiv_reg_we_i   (exu_muldiv_reg_we_o),
            .muldiv_reg_waddr_i(exu_muldiv_reg_waddr_o),
            .muldiv_commit_id_i(exu_muldiv_commit_id_o),  // 直接使用全宽度
            .muldiv_ready_o    (wbu_muldiv_ready_o),

            .csr_wdata_i    (exu_csr_wdata_o),
            .csr_we_i       (exu_csr_we_o),
            .csr_waddr_i    (exu_csr_waddr_o),
            .csr_commit_id_i(exu_csr_commit_id_o),  // 连接CSR commit_id
            .csr_ready_o    (wbu_csr_ready_o),

            // CSR对通用寄存器的写数据输入
            .csr_reg_wdata_i(exu_csr_reg_wdata_o),
            .csr_reg_waddr_i(exu_csr_reg_waddr_o),
            .csr_reg_we_i   (exu_csr_reg_we_o),     // 新增：csr_reg_we输入端口

            .agu_reg_wdata_i(exu_agu_reg_wdata_o),
            .agu_reg_we_i   (exu_agu_reg_we_o),
            .agu_reg_waddr_i(exu_agu_reg_waddr_o),
            .agu_commit_id_i(exu_agu_commit_id_o),  // 直接使用全宽度

            .idu_reg_waddr_i(dispatch_pipe_reg_waddr_o), // 修改为从dispatch pipe获取IDU寄存器写地址
>>>>>>> Stashed changes

            .int_assert_i(clint_int_assert_o),

            // 新增长指令完成输出
            .commit_valid_o(wbu_commit_valid_o),
            .commit_id_o   (wbu_commit_id_o),

            .reg_wdata_o(wbu_reg_wdata_o),
            .reg_we_o   (wbu_reg_we_o),
            .reg_waddr_o(wbu_reg_waddr_o),

            .csr_wdata_o(wbu_csr_wdata_o),
            .csr_we_o   (wbu_csr_we_o),
            .csr_waddr_o(wbu_csr_waddr_o)
        );

    // clint模块例化 - 修改为从dispatch pipe获取指令地址
    clint u_clint (
<<<<<<< Updated upstream
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_addr_i    (pipe_inst_addr),     // 修改为从dispatch pipe获取指令地址
        .jump_flag_i    (exu_jump_flag_o),
        .jump_addr_i    (exu_jump_addr_o),
        .stall_flag_i   (ctrl_stall_flag_o),
        .atom_opt_busy_i(atom_opt_busy),
=======
              .inst_dret_i    (inst_dret_i),//**************后期更改

              .inst_addr_i    (dispatch_pipe_inst_addr),     // 修改为从dispatch pipe获取指令地址
              .rst_n          (rst_n),
              .int_req_i      (int_req_i),
              .int_id_i       (int_id_i),
              .inst_addr_i    (pipe_inst_addr),     // 修改为从dispatch pipe获取指令地址
              .jump_flag_i    (exu_jump_flag_o),
              .jump_addr_i    (exu_jump_addr_o),
              .stall_flag_i   (ctrl_stall_flag_o),
              .atom_opt_busy_i(atom_opt_busy),
>>>>>>> Stashed changes

              // 连接系统操作信号
              .sys_op_ecall_i (exu_ecall_o),
              .sys_op_ebreak_i(exu_ebreak_o),
              .sys_op_mret_i  (exu_mret_o),
              .sys_op_executed_i(ex_clint_inst_executed_o),
              .sys_op_mie_i   (csr_clint_csr_mie),  // 新增：连接CSR中断使能寄存器
              .trigger_match_i(trigger_match_i),//新增 csr触发器匹配信号

<<<<<<< Updated upstream
        .data_i         (csr_clint_data_o),
        .csr_mtvec      (csr_clint_csr_mtvec),
        .csr_mepc       (csr_clint_csr_mepc),
        .csr_mstatus    (csr_clint_csr_mstatus),
        .we_o           (clint_we_o),
        .waddr_o        (clint_waddr_o),
        .raddr_o        (clint_raddr_o),
        .data_o         (clint_data_o),
        .flush_flag_o   (clint_flush_flag_o),     // 连接flush信号
        .stall_flag_o   (clint_stall_flag_o),
        .global_int_en_i(csr_global_int_en_o),
        .int_addr_o     (clint_int_addr_o),
        .int_assert_o   (clint_int_assert_o)
    );

    // mems模块例化
    mems #(
        .ITCM_ADDR_WIDTH (`ITCM_ADDR_WIDTH),
        .DTCM_ADDR_WIDTH (`DTCM_ADDR_WIDTH),
        .DATA_WIDTH      (`BUS_DATA_WIDTH),
        .C_AXI_ID_WIDTH  (`BUS_ID_WIDTH),
        .C_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
        .C_AXI_ADDR_WIDTH(`BUS_ADDR_WIDTH)
    ) u_mems (
        .clk  (clk),
        .rst_n(rst_n),
=======
              .data_i         (csr_clint_data_o),
              .csr_mtvec      (csr_clint_csr_mtvec),
              .csr_mepc       (csr_clint_csr_mepc),
              .csr_mstatus    (csr_clint_csr_mstatus),
              .we_o           (clint_we_o),
              .waddr_o        (clint_waddr_o),
              .raddr_o        (clint_raddr_o),

              .data_o         (clint_data_o),
              .flush_flag_o   (clint_flush_flag_o),     // 连接flush信号
              .stall_flag_o   (clint_stall_flag_o),
              .global_int_en_i(csr_global_int_en_o),
              .int_addr_o     (clint_int_addr_o),
              .int_assert_o   (clint_int_assert_o)
          );

    // mems模块例化
    mems #(
             .ITCM_ADDR_WIDTH (`ITCM_ADDR_WIDTH),
             .DTCM_ADDR_WIDTH (`DTCM_ADDR_WIDTH),
             .DATA_WIDTH      (`BUS_DATA_WIDTH),
             .C_AXI_ID_WIDTH  (`BUS_ID_WIDTH),
             .C_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
             .C_AXI_ADDR_WIDTH(`BUS_ADDR_WIDTH)
         ) u_mems (
             .clk  (clk),
             .rst_n(rst_n),
>>>>>>> Stashed changes

             // 端口0 - IFU指令获取接口 (M0)
             .M0_AXI_ARID   (ifu_axi_arid),
             .M0_AXI_ARADDR (ifu_axi_araddr),
             .M0_AXI_ARLEN  (ifu_axi_arlen),
             .M0_AXI_ARSIZE (ifu_axi_arsize),
             .M0_AXI_ARBURST(ifu_axi_arburst),
             .M0_AXI_ARLOCK (ifu_axi_arlock),
             .M0_AXI_ARCACHE(ifu_axi_arcache),
             .M0_AXI_ARPROT (ifu_axi_arprot),
             .M0_AXI_ARQOS  (ifu_axi_arqos),
             .M0_AXI_ARUSER (ifu_axi_aruser),
             .M0_AXI_ARVALID(ifu_axi_arvalid),
             .M0_AXI_ARREADY(ifu_axi_arready),
             .M0_AXI_RID    (ifu_axi_rid),
             .M0_AXI_RDATA  (ifu_axi_rdata),
             .M0_AXI_RRESP  (ifu_axi_rresp),
             .M0_AXI_RLAST  (ifu_axi_rlast),
             .M0_AXI_RUSER  (ifu_axi_ruser),
             .M0_AXI_RVALID (ifu_axi_rvalid),
             .M0_AXI_RREADY (ifu_axi_rready),

             // 端口1 - EXU数据访问接口 (M1)
             .M1_AXI_AWID   (exu_axi_awid),
             .M1_AXI_AWADDR (exu_axi_awaddr),
             .M1_AXI_AWLEN  (exu_axi_awlen),
             .M1_AXI_AWSIZE (exu_axi_awsize),
             .M1_AXI_AWBURST(exu_axi_awburst),
             .M1_AXI_AWLOCK (exu_axi_awlock),
             .M1_AXI_AWCACHE(exu_axi_awcache),
             .M1_AXI_AWPROT (exu_axi_awprot),
             .M1_AXI_AWQOS  (exu_axi_awqos),
             .M1_AXI_AWUSER (exu_axi_awuser),
             .M1_AXI_AWVALID(exu_axi_awvalid),
             .M1_AXI_AWREADY(exu_axi_awready),
             .M1_AXI_WDATA  (exu_axi_wdata),
             .M1_AXI_WSTRB  (exu_axi_wstrb),
             .M1_AXI_WLAST  (exu_axi_wlast),
             .M1_AXI_WVALID (exu_axi_wvalid),
             .M1_AXI_WREADY (exu_axi_wready),
             .M1_AXI_BID    (exu_axi_bid),
             .M1_AXI_BRESP  (exu_axi_bresp),
             .M1_AXI_BVALID (exu_axi_bvalid),
             .M1_AXI_BREADY (exu_axi_bready),
             .M1_AXI_ARID   (exu_axi_arid),
             .M1_AXI_ARADDR (exu_axi_araddr),
             .M1_AXI_ARLEN  (exu_axi_arlen),
             .M1_AXI_ARSIZE (exu_axi_arsize),
             .M1_AXI_ARBURST(exu_axi_arburst),
             .M1_AXI_ARLOCK (exu_axi_arlock),
             .M1_AXI_ARCACHE(exu_axi_arcache),
             .M1_AXI_ARPROT (exu_axi_arprot),
             .M1_AXI_ARQOS  (exu_axi_arqos),
             .M1_AXI_ARUSER (exu_axi_aruser),
             .M1_AXI_ARVALID(exu_axi_arvalid),
             .M1_AXI_ARREADY(exu_axi_arready),
             .M1_AXI_RID    (exu_axi_rid),
             .M1_AXI_RDATA  (exu_axi_rdata),
             .M1_AXI_RRESP  (exu_axi_rresp),
             .M1_AXI_RLAST  (exu_axi_rlast),
             .M1_AXI_RUSER  (exu_axi_ruser),
             .M1_AXI_RVALID (exu_axi_rvalid),
             .M1_AXI_RREADY (exu_axi_rready)
         );

    // 定义原子操作忙信号 - 使用dispatch提供的HDU原子锁信号
    assign atom_opt_busy = dispatch_long_inst_atom_lock_o | exu_mem_store_busy_o;
endmodule
