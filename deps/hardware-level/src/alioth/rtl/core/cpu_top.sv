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

    input  wire                             clk,
    input  wire                             rst_n,
    input  wire [                      7:0] irq_sources,      // 中断ID

    // M0 AXI接口 - IFU指令获取
    output wire [`BUS_ID_WIDTH-1:0]         M0_AXI_ARID,
    output wire [`INST_ADDR_WIDTH-1:0]      M0_AXI_ARADDR,
    output wire [7:0]                       M0_AXI_ARLEN,
    output wire [2:0]                       M0_AXI_ARSIZE,
    output wire [1:0]                       M0_AXI_ARBURST,
    output wire                             M0_AXI_ARLOCK,
    output wire [3:0]                       M0_AXI_ARCACHE,
    output wire [2:0]                       M0_AXI_ARPROT,
    output wire [3:0]                       M0_AXI_ARQOS,
    output wire [3:0]                       M0_AXI_ARUSER,
    output wire                             M0_AXI_ARVALID,
    input  wire                             M0_AXI_ARREADY,
    input  wire [`BUS_ID_WIDTH-1:0]         M0_AXI_RID,
    input  wire [`INST_DATA_WIDTH-1:0]      M0_AXI_RDATA,
    input  wire [1:0]                       M0_AXI_RRESP,
    input  wire                             M0_AXI_RLAST,
    input  wire [3:0]                       M0_AXI_RUSER,
    input  wire                             M0_AXI_RVALID,
    output wire                             M0_AXI_RREADY,

    // M1 AXI接口 - EXU数据访问
    output wire [`BUS_ID_WIDTH-1:0]         M1_AXI_AWID,
    output wire [31:0]                      M1_AXI_AWADDR,
    output wire [7:0]                       M1_AXI_AWLEN,
    output wire [2:0]                       M1_AXI_AWSIZE,
    output wire [1:0]                       M1_AXI_AWBURST,
    output wire                             M1_AXI_AWLOCK,
    output wire [3:0]                       M1_AXI_AWCACHE,
    output wire [2:0]                       M1_AXI_AWPROT,
    output wire [3:0]                       M1_AXI_AWQOS,
    output wire                             M1_AXI_AWUSER,
    output wire                             M1_AXI_AWVALID,
    input  wire                             M1_AXI_AWREADY,
    output wire [31:0]                      M1_AXI_WDATA,
    output wire [3:0]                       M1_AXI_WSTRB,
    output wire                             M1_AXI_WLAST,
    output wire                             M1_AXI_WUSER,
    output wire                             M1_AXI_WVALID,
    input  wire                             M1_AXI_WREADY,
    input  wire [`BUS_ID_WIDTH-1:0]         M1_AXI_BID,
    input  wire [1:0]                       M1_AXI_BRESP,
    input  wire                             M1_AXI_BUSER,
    input  wire                             M1_AXI_BVALID,
    output wire                             M1_AXI_BREADY,
    output wire [`BUS_ID_WIDTH-1:0]         M1_AXI_ARID,
    output wire [31:0]                      M1_AXI_ARADDR,
    output wire [7:0]                       M1_AXI_ARLEN,
    output wire [2:0]                       M1_AXI_ARSIZE,
    output wire [1:0]                       M1_AXI_ARBURST,
    output wire                             M1_AXI_ARLOCK,
    output wire [3:0]                       M1_AXI_ARCACHE,
    output wire [2:0]                       M1_AXI_ARPROT,
    output wire [3:0]                       M1_AXI_ARQOS,
    output wire                             M1_AXI_ARUSER,
    output wire                             M1_AXI_ARVALID,
    input  wire                             M1_AXI_ARREADY,
    input  wire [`BUS_ID_WIDTH-1:0]         M1_AXI_RID,
    input  wire [31:0]                      M1_AXI_RDATA,
    input  wire [1:0]                       M1_AXI_RRESP,
    input  wire                             M1_AXI_RLAST,
    input  wire                             M1_AXI_RUSER,
    input  wire                             M1_AXI_RVALID,
    output wire                             M1_AXI_RREADY,

    // OM1 AXI-Lite接口 - CLINT
    input  wire                             OM1_AXI_ACLK,
    input  wire                             OM1_AXI_ARESETN,
    input  wire [`BUS_ADDR_WIDTH-1 : 0]     OM1_AXI_AWADDR,
    input  wire [2:0]                       OM1_AXI_AWPROT,
    input  wire                             OM1_AXI_AWVALID,
    output wire                             OM1_AXI_AWREADY,
    input  wire [`BUS_DATA_WIDTH-1 : 0]     OM1_AXI_WDATA,
    input  wire [(`BUS_DATA_WIDTH/8)-1 : 0] OM1_AXI_WSTRB,
    input  wire                             OM1_AXI_WVALID,
    output wire                             OM1_AXI_WREADY,
    output wire [1:0]                       OM1_AXI_BRESP,
    output wire                             OM1_AXI_BVALID,
    input  wire                             OM1_AXI_BREADY,
    input  wire [`BUS_ADDR_WIDTH-1 : 0]     OM1_AXI_ARADDR,
    input  wire [2:0]                       OM1_AXI_ARPROT,
    input  wire                             OM1_AXI_ARVALID,
    output wire                             OM1_AXI_ARREADY,
    output wire [`BUS_DATA_WIDTH-1 : 0]     OM1_AXI_RDATA,
    output wire [1:0]                       OM1_AXI_RRESP,
    output wire                             OM1_AXI_RVALID,
    input  wire                             OM1_AXI_RREADY,

    // OM2 AXI-Lite接口 - PLIC
    input  wire                             OM2_AXI_ACLK,
    input  wire                             OM2_AXI_ARESETN,
    input  wire [`PLIC_ADDR_WIDTH-1 : 0]    OM2_AXI_AWADDR,
    input  wire [2:0]                       OM2_AXI_AWPROT,
    input  wire                             OM2_AXI_AWVALID,
    output wire                             OM2_AXI_AWREADY,
    input  wire [`BUS_DATA_WIDTH-1 : 0]     OM2_AXI_WDATA,
    input  wire [(`BUS_DATA_WIDTH/8)-1 : 0] OM2_AXI_WSTRB,
    input  wire                             OM2_AXI_WVALID,
    output wire                             OM2_AXI_WREADY,
    output wire [1:0]                       OM2_AXI_BRESP,
    output wire                             OM2_AXI_BVALID,
    input  wire                             OM2_AXI_BREADY,
    input  wire [`PLIC_ADDR_WIDTH-1 : 0]    OM2_AXI_ARADDR,
    input  wire [2:0]                       OM2_AXI_ARPROT,
    input  wire                             OM2_AXI_ARVALID,
    output wire                             OM2_AXI_ARREADY,
    output wire [`BUS_DATA_WIDTH-1 : 0]     OM2_AXI_RDATA,
    output wire [1:0]                       OM2_AXI_RRESP,
    output wire                             OM2_AXI_RVALID,
    input  wire                             OM2_AXI_RREADY
);

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
    // 新增rs1/rs2读使能信号
    wire idu_rs1_re_o;
    wire idu_rs2_re_o;
    wire [`EX_INFO_BUS_WIDTH-1:0] idu_ex_info_bus_o;  // 新增：IDU ex_info_bus信号
    wire idu_irs_stall_flag_o;
    // exu模块输出信号
    wire exu_stall_flag_o;
    wire exu_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;
    wire [`REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire exu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;

    // 系统操作信号
    wire exu_ecall_o;
    wire exu_ebreak_o;
    wire exu_mret_o;

    // CSR寄存器写数据信号
    wire [`REG_DATA_WIDTH-1:0] exu_csr_reg_wdata_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_csr_reg_waddr_o;
    wire exu_csr_reg_we_o;  // 新增：csr_reg_we信号线

    // EXU的Commit ID信号
    wire [`COMMIT_ID_WIDTH-1:0] exu_csr_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_alu_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_mul_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_div_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_lsu_commit_id_o;

    // EXU到WBU的数据通路信号
    wire [`REG_DATA_WIDTH-1:0] exu_alu_reg_wdata_o;
    wire exu_alu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_alu_reg_waddr_o;

    wire [`REG_DATA_WIDTH-1:0] exu_mul_reg_wdata_o;
    wire exu_mul_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_mul_reg_waddr_o;

    wire [`REG_DATA_WIDTH-1:0] exu_div_reg_wdata_o;
    wire exu_div_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_div_reg_waddr_o;

    wire [`REG_DATA_WIDTH-1:0] exu_lsu_reg_wdata_o;
    wire exu_lsu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_lsu_reg_waddr_o;

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
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mtvec;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mepc;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mstatus;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mie;

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
    wire clint_int_jump_o;  // 添加中断跳转信号
    wire clint_req_valid_o;  // 添加中断请求有效信号

    // 新增信号定义
    wire ifu_read_resp_error_o;
    wire exu_mem_stall_o;
    wire exu_mem_store_busy_o;
    wire dispatch_stall_flag_o;
    wire dispatch_long_inst_atom_lock_o;
    wire [`COMMIT_ID_WIDTH-1:0] hdu_long_inst_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] wbu_commit_id_o;
    wire wbu_alu_ready_o;
    wire wbu_mul_ready_o;
    wire wbu_div_ready_o;
    wire wbu_csr_ready_o;
    // 显式声明原子操作忙信号，避免隐式定义
    wire atom_opt_busy;
    // 添加缺少的信号声明
    wire wbu_commit_valid_o;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_commit_id_o;

    // inst_valid相关信号定义
    wire if_inst_valid_o;  // IFU输出指令有效信号
    wire idu_inst_valid_o;  // IDU输出指令有效信号
    wire dispatch_inst_valid_o;  // dispatch输出流水线指令有效信号
    wire idu_illegal_inst_o;  // IDU输出非法指令信号
    wire [`INST_DATA_WIDTH-1:0] idu_inst_o;  // IDU输出非法指令内容
    wire dispatch_misaligned_load_o;  // dispatch输出misaligned load信号
    wire dispatch_misaligned_store_o;  // dispatch输出misaligned store信号
    wire dispatch_illegal_inst_o;  // dispatch输出非法指令信号
    wire misaligned_fetch_o;  // EXU输出misaligned fetch信号

    // dispatch to ALU
    wire [31:0] dispatch_alu_op1;
    wire [31:0] dispatch_alu_op2;
    wire dispatch_req_alu;
    wire [`ALU_OP_WIDTH-1:0] dispatch_alu_op_info;
    wire dispatch_alu_pass_op1;  // 新增：ALU旁路信号
    wire dispatch_alu_pass_op2;  // 新增：ALU旁路信号

    // dispatch to Bru
    wire dispatch_req_bjp;
    wire dispatch_bjp_op_jal;
    wire dispatch_bjp_op_beq;
    wire dispatch_bjp_op_bne;
    wire dispatch_bjp_op_blt;
    wire dispatch_bjp_op_bltu;
    wire dispatch_bjp_op_bge;
    wire dispatch_bjp_op_bgeu;
    wire dispatch_bjp_op_jalr;
    wire [31:0] dispatch_bjp_adder_result;
    wire [31:0] dispatch_bjp_next_pc;
    wire dispatch_op1_eq_op2;
    wire dispatch_op1_ge_op2_signed;
    wire dispatch_op1_ge_op2_unsigned;

    // dispatch to MUL
    wire dispatch_req_mul;
    wire [31:0] dispatch_mul_op1;
    wire [31:0] dispatch_mul_op2;
    wire dispatch_mul_op_mul;
    wire dispatch_mul_op_mulh;
    wire dispatch_mul_op_mulhsu;
    wire dispatch_mul_op_mulhu;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_mul_commit_id;
    wire dispatch_mul_pass_op1;  // 新增：MUL旁路信号
    wire dispatch_mul_pass_op2;  // 新增：MUL旁路信号

    // dispatch to DIV
    wire dispatch_req_div;
    wire [31:0] dispatch_div_op1;
    wire [31:0] dispatch_div_op2;
    wire dispatch_div_op_div;
    wire dispatch_div_op_divu;
    wire dispatch_div_op_rem;
    wire dispatch_div_op_remu;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_div_commit_id;
    wire dispatch_div_pass_op1;  // 新增：DIV旁路信号
    wire dispatch_div_pass_op2;  // 新增：DIV旁路信号

    // dispatch to CSR
    wire dispatch_req_csr;
    wire [31:0] dispatch_csr_op1;
    wire [31:0] dispatch_csr_addr;
    wire dispatch_csr_csrrw;
    wire dispatch_csr_csrrs;
    wire dispatch_csr_csrrc;
    wire dispatch_csr_pass_op;  // 新增：CSR旁路信号

    wire [`BUS_ADDR_WIDTH-1:0] idu_csr_raddr_o;
    wire dispatch_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] dispatch_reg_waddr_o;
    wire dispatch_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_csr_raddr_o;
    wire [31:0] dispatch_dec_imm_o;
    wire [`DECINFO_WIDTH-1:0] dispatch_dec_info_bus_o;
    wire [`INST_ADDR_WIDTH-1:0] dispatch_inst_addr_o;
    wire [`INST_DATA_WIDTH-1:0] dispatch_inst_o;  // 新增：指令内容输出

    // dispatch to MEM
    wire dispatch_req_mem;
    wire dispatch_mem_op_lb;
    wire dispatch_mem_op_lh;
    wire dispatch_mem_op_lw;
    wire dispatch_mem_op_lbu;
    wire dispatch_mem_op_lhu;
    wire dispatch_mem_op_load;
    wire dispatch_mem_op_store;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_mem_commit_id;
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

    // 给dispatch和HDU的译码信息
    wire dis_is_pred_branch_o;
    wire ext_int_req;
    wire inst_valid = (ctrl_stall_flag_o == 0);
    wire inst_exu_valid = (ctrl_stall_flag_o[`CU_STALL_DISPATCH] == 0) && 
                        (idu_dec_info_bus_o[`DECINFO_GRP_BUS] != `DECINFO_GRP_NONE);
    wire inst_clint_valid = !dis_is_pred_branch_o && (dispatch_inst_valid_o);
    // wire is_muldiv_long_inst = (idu_dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_MULDIV);
    // wire is_mem_long_inst = ((idu_dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM) && idu_dec_info_bus_o[`DECINFO_MEM_OP_LOAD]);
    // wire is_long_inst = is_muldiv_long_inst | is_mem_long_inst;
    wire jump_addr_valid = dispatch_bjp_op_jal || exu_jump_flag_o;

    // IFU模块例化
    ifu u_ifu (
        .clk              (clk),
        .rst_n            (rst_n),
        .jump_flag_i      (ctrl_jump_flag_o),
        .jump_addr_i      (ctrl_jump_addr_o),
        .stall_flag_i     (ctrl_stall_flag_o),
        .inst_o           (if_inst_o),
        .inst_addr_o      (if_inst_addr_o),
        .read_resp_error_o(ifu_read_resp_error_o),
        .is_pred_branch_o (if_is_pred_branch_o),    // 连接预测分支信号输出
        .inst_valid_o     (if_inst_valid_o),        // 添加指令有效信号输出

        // AXI接口
        .M_AXI_ARID   (M0_AXI_ARID),
        .M_AXI_ARADDR (M0_AXI_ARADDR),
        .M_AXI_ARLEN  (M0_AXI_ARLEN),
        .M_AXI_ARSIZE (M0_AXI_ARSIZE),
        .M_AXI_ARBURST(M0_AXI_ARBURST),
        .M_AXI_ARLOCK (M0_AXI_ARLOCK),
        .M_AXI_ARCACHE(M0_AXI_ARCACHE),
        .M_AXI_ARPROT (M0_AXI_ARPROT),
        .M_AXI_ARQOS  (M0_AXI_ARQOS),
        .M_AXI_ARUSER (M0_AXI_ARUSER),
        .M_AXI_ARVALID(M0_AXI_ARVALID),
        .M_AXI_ARREADY(M0_AXI_ARREADY),
        .M_AXI_RID    (M0_AXI_RID),
        .M_AXI_RDATA  (M0_AXI_RDATA),
        .M_AXI_RRESP  (M0_AXI_RRESP),
        .M_AXI_RLAST  (M0_AXI_RLAST),
        .M_AXI_RUSER  (M0_AXI_RUSER),
        .M_AXI_RVALID (M0_AXI_RVALID),
        .M_AXI_RREADY (M0_AXI_RREADY)
    );

    // ctrl模块例化 - 修改使用来自dispatch的HDU暂停信号
    ctrl u_ctrl (
        .clk               (clk),
        .rst_n             (rst_n),
        .jump_flag_i       (exu_jump_flag_o),
        .jump_addr_i       (exu_jump_addr_o),
        .atom_opt_busy_i   (atom_opt_busy),
        .stall_flag_ex_i   (exu_stall_flag_o),
        .flush_flag_clint_i(clint_int_assert_o),     // 添加连接到clint的flush信号
        .stall_flag_hdu_i  (dispatch_stall_flag_o),  // 修改为从dispatch获取HDU暂停信号
        .stall_flag_irs_i  (idu_irs_stall_flag_o),   // 添加连接到IDU的IRS暂停信号
        .stall_flag_o      (ctrl_stall_flag_o),
        .jump_flag_o       (ctrl_jump_flag_o),
        .jump_addr_o       (ctrl_jump_addr_o)
    );

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
        .clk              (clk),
        .rst_n            (rst_n),
        .we_i             (wbu_csr_we_o),
        .raddr_i          (dispatch_csr_raddr_o),
        .waddr_i          (wbu_csr_waddr_o),
        .data_i           (wbu_csr_wdata_o),
        .inst_valid_i     (inst_exu_valid),
        .data_o           (csr_data_o),
        .clint_we_i       (clint_we_o),
        .clint_raddr_i    (clint_raddr_o),
        .clint_waddr_i    (clint_waddr_o),
        .clint_data_i     (clint_data_o),
        .clint_data_o     (csr_clint_data_o),
        .clint_csr_mtvec  (csr_clint_csr_mtvec),
        .clint_csr_mepc   (csr_clint_csr_mepc),
        .clint_csr_mstatus(csr_clint_csr_mstatus),
        .clint_csr_mie    (csr_clint_csr_mie)
    );

    // idu模块例化 - 更新接口，移除长指令ID相关接口
    idu u_idu (
        .clk             (clk),
        .rst_n           (rst_n),
        .inst_i          (if_inst_o),
        .inst_addr_i     (if_inst_addr_o),
        .stall_flag_i    (ctrl_stall_flag_o),
        .is_pred_branch_i(if_is_pred_branch_o),  // 连接预测分支信号输入
        .inst_valid_i    (if_inst_valid_o),      // 添加指令有效信号输入

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
        .is_pred_branch_o(idu_is_pred_branch_o),  // 连接预测分支信号输出
        .inst_valid_o    (idu_inst_valid_o),      // 添加指令有效信号输出
        .illegal_inst_o  (idu_illegal_inst_o),
        .inst_o          (idu_inst_o),            // 添加非法指令值输出
        // 新增rs1/rs2读使能信号输出
        .rs1_re_o        (idu_rs1_re_o),
        .rs2_re_o        (idu_rs2_re_o),
        .ex_info_bus_o   (idu_ex_info_bus_o),     // 新增
        .irs_stall_flag_o(idu_irs_stall_flag_o)
    );

    // 添加dispatch模块例化 - 修改增加新的接口
    dispatch u_dispatch (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall_flag_i  (ctrl_stall_flag_o),
        .inst_valid_i  (idu_inst_valid_o),
        .illegal_inst_i(idu_illegal_inst_o),

        // 输入译码信息
        .dec_info_bus_i  (idu_dec_info_bus_o),
        .dec_imm_i       (idu_dec_imm_o),
        .dec_pc_i        (idu_inst_addr_o),
        .inst_i          (idu_inst_o),
        .rs1_rdata_i     (regs_rdata1_o),
        .rs2_rdata_i     (regs_rdata2_o),
        .is_pred_branch_i(idu_is_pred_branch_o), // 连接预测分支信号输入

        // 寄存器访问信息 - 用于HDU冒险检测
        .reg_waddr_i (idu_reg_waddr_o),
        .reg1_raddr_i(idu_reg1_raddr_o),
        .reg2_raddr_i(idu_reg2_raddr_o),
        .reg_we_i    (idu_reg_we_o),
        // 新增rs1/rs2读使能信号输入
        .rs1_re_i    (idu_rs1_re_o),
        .rs2_re_i    (idu_rs2_re_o),

        // 从IDU接收CSR信号
        .csr_we_i   (idu_csr_we_o),
        .csr_waddr_i(idu_csr_waddr_o),
        .csr_raddr_i(idu_csr_raddr_o),

        .ex_info_bus_i(idu_ex_info_bus_o),  // 新增：连接IDU ex_info_bus到dispatch

        // 长指令有效信号 - 用于HDU
        .clint_req_valid_i(clint_req_valid_o),

        // 写回阶段提交信号
        .commit_valid_i(wbu_commit_valid_o),
        .commit_id_i   (wbu_commit_id_o),

        // HDU输出信号
        .hazard_stall_o       (dispatch_stall_flag_o),
        .long_inst_atom_lock_o(dispatch_long_inst_atom_lock_o),
        .commit_id_o          (dispatch_commit_id_o),

        .pipe_inst_valid_o(dispatch_inst_valid_o),

        // 新增：额外的流水线寄存输出信号
        .pipe_reg_we_o      (dispatch_reg_we_o),
        .pipe_reg_waddr_o   (dispatch_reg_waddr_o),
        .pipe_csr_we_o      (dispatch_csr_we_o),
        .pipe_csr_waddr_o   (dispatch_csr_waddr_o),
        .pipe_csr_raddr_o   (dispatch_csr_raddr_o),
        .pipe_dec_imm_o     (dispatch_dec_imm_o),
        .pipe_dec_info_bus_o(dispatch_dec_info_bus_o),
        .pipe_inst_addr_o   (dispatch_inst_addr_o),
        .pipe_inst_o        (dispatch_inst_o),
        .pipe_rs1_rdata_o   (dispatch_rs1_rdata),
        .pipe_rs2_rdata_o   (dispatch_rs2_rdata),

        // 分发到各功能单元的信号
        .req_alu_o     (dispatch_req_alu),
        .alu_op1_o     (dispatch_alu_op1),
        .alu_op2_o     (dispatch_alu_op2),
        .alu_op_info_o (dispatch_alu_op_info),
        .alu_pass_op1_o(dispatch_alu_pass_op1),  // 新增：ALU旁路信号
        .alu_pass_op2_o(dispatch_alu_pass_op2),  // 新增：ALU旁路信号

        .req_bjp_o            (dispatch_req_bjp),
        .bjp_op_jal_o         (dispatch_bjp_op_jal),
        .bjp_op_beq_o         (dispatch_bjp_op_beq),
        .bjp_op_bne_o         (dispatch_bjp_op_bne),
        .bjp_op_blt_o         (dispatch_bjp_op_blt),
        .bjp_op_bltu_o        (dispatch_bjp_op_bltu),
        .bjp_op_bge_o         (dispatch_bjp_op_bge),
        .bjp_op_bgeu_o        (dispatch_bjp_op_bgeu),
        .bjp_op_jalr_o        (dispatch_bjp_op_jalr),
        .bjp_adder_result_o   (dispatch_bjp_adder_result),
        .bjp_next_pc_o        (dispatch_bjp_next_pc),
        .op1_eq_op2_o         (dispatch_op1_eq_op2),
        .op1_ge_op2_signed_o  (dispatch_op1_ge_op2_signed),
        .op1_ge_op2_unsigned_o(dispatch_op1_ge_op2_unsigned),

        .req_mul_o      (dispatch_req_mul),
        .mul_op1_o      (dispatch_mul_op1),
        .mul_op2_o      (dispatch_mul_op2),
        .mul_op_mul_o   (dispatch_mul_op_mul),
        .mul_op_mulh_o  (dispatch_mul_op_mulh),
        .mul_op_mulhsu_o(dispatch_mul_op_mulhsu),
        .mul_op_mulhu_o (dispatch_mul_op_mulhu),
        .mul_pass_op1_o (dispatch_mul_pass_op1),   // 新增：MUL旁路信号
        .mul_pass_op2_o (dispatch_mul_pass_op2),   // 新增：MUL旁路信号
        .req_div_o      (dispatch_req_div),
        .div_op1_o      (dispatch_div_op1),
        .div_op2_o      (dispatch_div_op2),
        .div_op_div_o   (dispatch_div_op_div),
        .div_op_divu_o  (dispatch_div_op_divu),
        .div_op_rem_o   (dispatch_div_op_rem),
        .div_op_remu_o  (dispatch_div_op_remu),
        .div_pass_op1_o (dispatch_div_pass_op1),   // 新增：DIV旁路信号
        .div_pass_op2_o (dispatch_div_pass_op2),   // 新增：DIV旁路信号
        .mul_commit_id_o(dispatch_mul_commit_id),
        .div_commit_id_o(dispatch_div_commit_id),

        .req_csr_o     (dispatch_req_csr),
        .csr_op1_o     (dispatch_csr_op1),
        .csr_addr_o    (dispatch_csr_addr),
        .csr_csrrw_o   (dispatch_csr_csrrw),
        .csr_csrrs_o   (dispatch_csr_csrrs),
        .csr_csrrc_o   (dispatch_csr_csrrc),
        .csr_pass_op1_o(dispatch_csr_pass_op), // 新增：CSR旁路信号

        .req_mem_o         (dispatch_req_mem),
        .mem_op_lb_o       (dispatch_mem_op_lb),
        .mem_op_lh_o       (dispatch_mem_op_lh),
        .mem_op_lw_o       (dispatch_mem_op_lw),
        .mem_op_lbu_o      (dispatch_mem_op_lbu),
        .mem_op_lhu_o      (dispatch_mem_op_lhu),
        .mem_op_load_o     (dispatch_mem_op_load),
        .mem_op_store_o    (dispatch_mem_op_store),
        .mem_commit_id_o   (dispatch_mem_commit_id),
        .mem_addr_o        (dispatch_mem_addr),
        .mem_wmask_o       (dispatch_mem_wmask),
        .mem_wdata_o       (dispatch_mem_wdata),
        .sys_op_nop_o      (dispatch_sys_op_nop),
        .sys_op_mret_o     (dispatch_sys_op_mret),
        .sys_op_ecall_o    (dispatch_sys_op_ecall),
        .sys_op_ebreak_o   (dispatch_sys_op_ebreak),
        .sys_op_fence_o    (dispatch_sys_op_fence),
        .sys_op_dret_o     (dispatch_sys_op_dret),
        .is_pred_branch_o  (dis_is_pred_branch_o),         // 连接预测分支信号输出
        .misaligned_load_o (dispatch_misaligned_load_o),
        .misaligned_store_o(dispatch_misaligned_store_o),
        .illegal_inst_o    (dispatch_illegal_inst_o)       // 连接IDU的非法指令输出

    );

    // exu模块例化 - 修改commit_id相关连接
    exu u_exu (
        .clk(clk),
        .rst_n(rst_n),
        .inst_addr_i(dispatch_inst_addr_o),  // 从dispatch pipe获取指令地址
        .reg_we_i(dispatch_reg_we_o),  // 修改为从dispatch pipe获取寄存器写使能
        .reg_waddr_i(dispatch_reg_waddr_o),  // 修改为从dispatch pipe获取寄存器写地址
        .csr_we_i(dispatch_csr_we_o),  // 修改为从dispatch pipe获取CSR写使能
        .csr_waddr_i(dispatch_csr_waddr_o),  // 修改为从dispatch pipe获取CSR写地址
        .csr_rdata_i(csr_data_o),
        .dec_info_bus_i(dispatch_dec_info_bus_o),     // 修改为从dispatch pipe获取译码信息总线
        .dec_imm_i(dispatch_dec_imm_o),  // 修改为从dispatch pipe获取立即数
        .int_assert_i(clint_int_assert_o),
        .int_jump_i(clint_int_jump_o),  // 添加中断跳转信号输入
        .int_addr_i(clint_int_addr_o),
        .is_pred_branch_i(dis_is_pred_branch_o),  // 连接预测分支信号输入

        // 从dispatch获取长指令ID
        .commit_id_i(dispatch_commit_id_o),

        // 写回握手信号
        .alu_wb_ready_i(wbu_alu_ready_o),
        .mul_wb_ready_i(wbu_mul_ready_o),
        .div_wb_ready_i(wbu_div_ready_o),
        .csr_wb_ready_i(wbu_csr_ready_o),

        .reg1_rdata_i(dispatch_rs1_rdata),
        .reg2_rdata_i(dispatch_rs2_rdata),

        .hazard_stall_i(dispatch_stall_flag_o),

        // 从dispatch获取的信号
        .req_alu_i     (dispatch_req_alu),
        .alu_op1_i     (dispatch_alu_op1),
        .alu_op2_i     (dispatch_alu_op2),
        .alu_op_info_i (dispatch_alu_op_info),
        .alu_pass_op1_i(dispatch_alu_pass_op1),  // 新增：ALU旁路信号
        .alu_pass_op2_i(dispatch_alu_pass_op2),  // 新增：ALU旁路信号

        .req_bjp_i            (dispatch_req_bjp),
        .bjp_op_jal_i         (dispatch_bjp_op_jal),
        .bjp_op_beq_i         (dispatch_bjp_op_beq),
        .bjp_op_bne_i         (dispatch_bjp_op_bne),
        .bjp_op_blt_i         (dispatch_bjp_op_blt),
        .bjp_op_bltu_i        (dispatch_bjp_op_bltu),
        .bjp_op_bge_i         (dispatch_bjp_op_bge),
        .bjp_op_bgeu_i        (dispatch_bjp_op_bgeu),
        .bjp_op_jalr_i        (dispatch_bjp_op_jalr),
        .bjp_adder_result_i   (dispatch_bjp_adder_result),
        .bjp_next_pc_i        (dispatch_bjp_next_pc),
        .op1_eq_op2_i         (dispatch_op1_eq_op2),
        .op1_ge_op2_signed_i  (dispatch_op1_ge_op2_signed),
        .op1_ge_op2_unsigned_i(dispatch_op1_ge_op2_unsigned),

        .req_mul_i      (dispatch_req_mul),
        .mul_op1_i      (dispatch_mul_op1),
        .mul_op2_i      (dispatch_mul_op2),
        .mul_op_mul_i   (dispatch_mul_op_mul),
        .mul_op_mulh_i  (dispatch_mul_op_mulh),
        .mul_op_mulhsu_i(dispatch_mul_op_mulhsu),
        .mul_op_mulhu_i (dispatch_mul_op_mulhu),
        .req_div_i      (dispatch_req_div),
        .div_op1_i      (dispatch_div_op1),
        .div_op2_i      (dispatch_div_op2),
        .div_op_div_i   (dispatch_div_op_div),
        .div_op_divu_i  (dispatch_div_op_divu),
        .div_op_rem_i   (dispatch_div_op_rem),
        .div_op_remu_i  (dispatch_div_op_remu),
        .mul_pass_op1_i (dispatch_mul_pass_op1),   // 新增：MUL旁路信号
        .mul_pass_op2_i (dispatch_mul_pass_op2),   // 新增：MUL旁路信号
        .div_pass_op1_i (dispatch_div_pass_op1),   // 新增：DIV旁路信号
        .div_pass_op2_i (dispatch_div_pass_op2),   // 新增：DIV旁路信号
        .mul_commit_id_i(dispatch_mul_commit_id),
        .div_commit_id_i(dispatch_div_commit_id),

        .req_csr_i     (dispatch_req_csr),
        .csr_op1_i     (dispatch_csr_op1),
        .csr_addr_i    (dispatch_csr_addr),
        .csr_csrrw_i   (dispatch_csr_csrrw),
        .csr_csrrs_i   (dispatch_csr_csrrs),
        .csr_csrrc_i   (dispatch_csr_csrrc),
        .csr_pass_op1_i(dispatch_csr_pass_op), // 新增：CSR旁路信号

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

        .alu_reg_wdata_o(exu_alu_reg_wdata_o),
        .alu_reg_we_o   (exu_alu_reg_we_o),
        .alu_reg_waddr_o(exu_alu_reg_waddr_o),
        .alu_commit_id_o(exu_alu_commit_id_o),

        // MUL/DIV结果输出
        .mul_reg_wdata_o(exu_mul_reg_wdata_o),
        .mul_reg_we_o   (exu_mul_reg_we_o),
        .mul_reg_waddr_o(exu_mul_reg_waddr_o),
        .mul_commit_id_o(exu_mul_commit_id_o),

        .div_reg_wdata_o(exu_div_reg_wdata_o),
        .div_reg_we_o   (exu_div_reg_we_o),
        .div_reg_waddr_o(exu_div_reg_waddr_o),
        .div_commit_id_o(exu_div_commit_id_o),

        .lsu_reg_wdata_o(exu_lsu_reg_wdata_o),
        .lsu_reg_we_o   (exu_lsu_reg_we_o),
        .lsu_reg_waddr_o(exu_lsu_reg_waddr_o),
        .lsu_commit_id_o(exu_lsu_commit_id_o),

        // 连接CSR寄存器写数据信号
        .csr_reg_wdata_o(exu_csr_reg_wdata_o),
        .csr_reg_waddr_o(exu_csr_reg_waddr_o),
        .csr_commit_id_o(exu_csr_commit_id_o),  // 添加缺失的CSR commit_id输出连接
        .csr_reg_we_o   (exu_csr_reg_we_o),     // 新增：连接csr_reg_we_o

        .csr_wdata_o(exu_csr_wdata_o),
        .csr_we_o   (exu_csr_we_o),
        .csr_waddr_o(exu_csr_waddr_o),

        .stall_flag_o(exu_stall_flag_o),
        .jump_flag_o (exu_jump_flag_o),
        .jump_addr_o (exu_jump_addr_o),

        // 系统操作信号输出
        .exu_op_ecall_o (exu_ecall_o),
        .exu_op_ebreak_o(exu_ebreak_o),
        .exu_op_mret_o  (exu_mret_o),

        .misaligned_fetch_o(misaligned_fetch_o),  // 新增misaligned fetch信号输出
        // 添加AXI接口连接 - 保持不变
        .M_AXI_AWID        (M1_AXI_AWID),
        .M_AXI_AWADDR      (M1_AXI_AWADDR),
        .M_AXI_AWLEN       (M1_AXI_AWLEN),
        .M_AXI_AWSIZE      (M1_AXI_AWSIZE),
        .M_AXI_AWBURST     (M1_AXI_AWBURST),
        .M_AXI_AWLOCK      (M1_AXI_AWLOCK),
        .M_AXI_AWCACHE     (M1_AXI_AWCACHE),
        .M_AXI_AWPROT      (M1_AXI_AWPROT),
        .M_AXI_AWQOS       (M1_AXI_AWQOS),
        .M_AXI_AWUSER      (M1_AXI_AWUSER),
        .M_AXI_AWVALID     (M1_AXI_AWVALID),
        .M_AXI_AWREADY     (M1_AXI_AWREADY),
        .M_AXI_WDATA       (M1_AXI_WDATA),
        .M_AXI_WSTRB       (M1_AXI_WSTRB),
        .M_AXI_WLAST       (M1_AXI_WLAST),
        .M_AXI_WUSER       (M1_AXI_WUSER),
        .M_AXI_WVALID      (M1_AXI_WVALID),
        .M_AXI_WREADY      (M1_AXI_WREADY),
        .M_AXI_BID         (M1_AXI_BID),
        .M_AXI_BRESP       (M1_AXI_BRESP),
        .M_AXI_BUSER       (M1_AXI_BUSER),
        .M_AXI_BVALID      (M1_AXI_BVALID),
        .M_AXI_BREADY      (M1_AXI_BREADY),
        .M_AXI_ARID        (M1_AXI_ARID),
        .M_AXI_ARADDR      (M1_AXI_ARADDR),
        .M_AXI_ARLEN       (M1_AXI_ARLEN),
        .M_AXI_ARSIZE      (M1_AXI_ARSIZE),
        .M_AXI_ARBURST     (M1_AXI_ARBURST),
        .M_AXI_ARLOCK      (M1_AXI_ARLOCK),
        .M_AXI_ARCACHE     (M1_AXI_ARCACHE),
        .M_AXI_ARPROT      (M1_AXI_ARPROT),
        .M_AXI_ARQOS       (M1_AXI_ARQOS),
        .M_AXI_ARUSER      (M1_AXI_ARUSER),
        .M_AXI_ARVALID     (M1_AXI_ARVALID),
        .M_AXI_ARREADY     (M1_AXI_ARREADY),
        .M_AXI_RID         (M1_AXI_RID),
        .M_AXI_RDATA       (M1_AXI_RDATA),
        .M_AXI_RRESP       (M1_AXI_RRESP),
        .M_AXI_RLAST       (M1_AXI_RLAST),
        .M_AXI_RUSER       (M1_AXI_RUSER),
        .M_AXI_RVALID      (M1_AXI_RVALID),
        .M_AXI_RREADY      (M1_AXI_RREADY)
    );

    // wbu模块例化
    wbu u_wbu (
        .clk  (clk),
        .rst_n(rst_n),

        .alu_reg_wdata_i(exu_alu_reg_wdata_o),
        .alu_reg_we_i   (exu_alu_reg_we_o),
        .alu_reg_waddr_i(exu_alu_reg_waddr_o),
        .alu_commit_id_i(exu_alu_commit_id_o),  // 连接ALU commit_id
        .alu_ready_o    (wbu_alu_ready_o),

        // MUL和DIV结果输入
        .mul_reg_wdata_i(exu_mul_reg_wdata_o),
        .mul_reg_we_i   (exu_mul_reg_we_o),
        .mul_reg_waddr_i(exu_mul_reg_waddr_o),
        .mul_commit_id_i(exu_mul_commit_id_o),
        .div_reg_wdata_i(exu_div_reg_wdata_o),
        .div_reg_we_i   (exu_div_reg_we_o),
        .div_reg_waddr_i(exu_div_reg_waddr_o),
        .div_commit_id_i(exu_div_commit_id_o),
        .mul_ready_o    (wbu_mul_ready_o),
        .div_ready_o    (wbu_div_ready_o),

        .csr_wdata_i    (exu_csr_wdata_o),
        .csr_we_i       (exu_csr_we_o),
        .csr_waddr_i    (exu_csr_waddr_o),
        .csr_commit_id_i(exu_csr_commit_id_o),  // 连接CSR commit_id
        .csr_ready_o    (wbu_csr_ready_o),

        // CSR对通用寄存器的写数据输入
        .csr_reg_wdata_i(exu_csr_reg_wdata_o),
        .csr_reg_waddr_i(exu_csr_reg_waddr_o),
        .csr_reg_we_i   (exu_csr_reg_we_o),     // 新增：csr_reg_we输入端口

        .lsu_reg_wdata_i(exu_lsu_reg_wdata_o),
        .lsu_reg_we_i   (exu_lsu_reg_we_o),
        .lsu_reg_waddr_i(exu_lsu_reg_waddr_o),
        .lsu_commit_id_i(exu_lsu_commit_id_o),  // 直接使用全宽度

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

    // clint模块例化 - 增加AXI-lite slave接口直连
    clint u_clint (
        .clk               (clk),
        .rst_n             (rst_n),
        .inst_addr_i       (dispatch_inst_addr_o),
        .inst_data_i       (dispatch_inst_o),
        .inst_valid_i      (inst_clint_valid),
        .jump_flag_i       (jump_addr_valid),
        .jump_addr_i       (exu_jump_addr_o),
        .stall_flag_i      (ctrl_stall_flag_o),
        .atom_opt_busy_i   (atom_opt_busy),
        .sys_op_ecall_i    (exu_ecall_o),
        .sys_op_ebreak_i   (exu_ebreak_o),
        .sys_op_mret_i     (exu_mret_o),
        .illegal_inst_i    (dispatch_illegal_inst_o),      // 连接非法指令信号
        .misaligned_load_i (dispatch_misaligned_load_o),
        .misaligned_store_i(dispatch_misaligned_store_o),
        .misaligned_fetch_i(misaligned_fetch_o),           // misaligned fetch信号输入

        .exu_stall_i      (exu_stall_flag_o),
        .data_i           (csr_clint_data_o),
        .csr_mtvec        (csr_clint_csr_mtvec),
        .csr_mepc         (csr_clint_csr_mepc),
        .csr_mstatus      (csr_clint_csr_mstatus),
        .csr_mie          (csr_clint_csr_mie),
        .we_o             (clint_we_o),
        .waddr_o          (clint_waddr_o),
        .raddr_o          (clint_raddr_o),
        .data_o           (clint_data_o),
        .int_addr_o       (clint_int_addr_o),
        .int_jump_o       (clint_int_jump_o),
        .int_assert_o     (clint_int_assert_o),
        .clint_req_valid_o(clint_req_valid_o),
        // === 连接外部中断信号 ===
        .ext_int_req_i    (ext_int_req),

        // AXI-lite slave接口直连
        .S_AXI_ACLK   (OM1_AXI_ACLK),
        .S_AXI_ARESETN(OM1_AXI_ARESETN),
        .S_AXI_AWADDR (OM1_AXI_AWADDR),
        .S_AXI_AWPROT (OM1_AXI_AWPROT),
        .S_AXI_AWVALID(OM1_AXI_AWVALID),
        .S_AXI_AWREADY(OM1_AXI_AWREADY),
        .S_AXI_WDATA  (OM1_AXI_WDATA),
        .S_AXI_WSTRB  (OM1_AXI_WSTRB),
        .S_AXI_WVALID (OM1_AXI_WVALID),
        .S_AXI_WREADY (OM1_AXI_WREADY),
        .S_AXI_BRESP  (OM1_AXI_BRESP),
        .S_AXI_BVALID (OM1_AXI_BVALID),
        .S_AXI_BREADY (OM1_AXI_BREADY),
        .S_AXI_ARADDR (OM1_AXI_ARADDR),
        .S_AXI_ARPROT (OM1_AXI_ARPROT),
        .S_AXI_ARVALID(OM1_AXI_ARVALID),
        .S_AXI_ARREADY(OM1_AXI_ARREADY),
        .S_AXI_RDATA  (OM1_AXI_RDATA),
        .S_AXI_RRESP  (OM1_AXI_RRESP),
        .S_AXI_RVALID (OM1_AXI_RVALID),
        .S_AXI_RREADY (OM1_AXI_RREADY)
    );

    // plic_top模块例化 - PLIC外部中断控制器
    plic_top #(
        .C_S_AXI_DATA_WIDTH(`BUS_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(`PLIC_ADDR_WIDTH)
    ) u_plic (
        .S_AXI_ACLK   (OM2_AXI_ACLK),
        .S_AXI_ARESETN(OM2_AXI_ARESETN),
        .S_AXI_AWADDR (OM2_AXI_AWADDR),
        .S_AXI_AWPROT (OM2_AXI_AWPROT),
        .S_AXI_AWVALID(OM2_AXI_AWVALID),
        .S_AXI_AWREADY(OM2_AXI_AWREADY),
        .S_AXI_WDATA  (OM2_AXI_WDATA),
        .S_AXI_WSTRB  (OM2_AXI_WSTRB),
        .S_AXI_WVALID (OM2_AXI_WVALID),
        .S_AXI_WREADY (OM2_AXI_WREADY),
        .S_AXI_BRESP  (OM2_AXI_BRESP),
        .S_AXI_BVALID (OM2_AXI_BVALID),
        .S_AXI_BREADY (OM2_AXI_BREADY),
        .S_AXI_ARADDR (OM2_AXI_ARADDR),
        .S_AXI_ARPROT (OM2_AXI_ARPROT),
        .S_AXI_ARVALID(OM2_AXI_ARVALID),
        .S_AXI_ARREADY(OM2_AXI_ARREADY),
        .S_AXI_RDATA  (OM2_AXI_RDATA),
        .S_AXI_RRESP  (OM2_AXI_RRESP),
        .S_AXI_RVALID (OM2_AXI_RVALID),
        .S_AXI_RREADY (OM2_AXI_RREADY),
        .irq_sources  (irq_sources),
        .irq_valid    (ext_int_req)
    );

    // 定义原子操作忙信号 - 使用dispatch提供的HDU原子锁信号
    assign atom_opt_busy = dispatch_long_inst_atom_lock_o | exu_mem_store_busy_o;
endmodule
