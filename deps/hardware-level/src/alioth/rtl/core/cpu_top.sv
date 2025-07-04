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
    // APB AXI-Lite 接口信号
    output wire                             OM0_AXI_ACLK,
    output wire                             OM0_AXI_ARESETN,
    output wire [    `BUS_ADDR_WIDTH-1 : 0] OM0_AXI_AWADDR,
    output wire [                    2 : 0] OM0_AXI_AWPROT,
    output wire                             OM0_AXI_AWVALID,
    input  wire                             OM0_AXI_AWREADY,
    output wire [    `BUS_DATA_WIDTH-1 : 0] OM0_AXI_WDATA,
    output wire [(`BUS_DATA_WIDTH/8)-1 : 0] OM0_AXI_WSTRB,
    output wire                             OM0_AXI_WVALID,
    input  wire                             OM0_AXI_WREADY,
    input  wire [                    1 : 0] OM0_AXI_BRESP,
    input  wire                             OM0_AXI_BVALID,
    output wire                             OM0_AXI_BREADY,
    output wire [    `BUS_ADDR_WIDTH-1 : 0] OM0_AXI_ARADDR,
    output wire [                    2 : 0] OM0_AXI_ARPROT,
    output wire                             OM0_AXI_ARVALID,
    input  wire                             OM0_AXI_ARREADY,
    input  wire [    `BUS_DATA_WIDTH-1 : 0] OM0_AXI_RDATA,
    input  wire [                    1 : 0] OM0_AXI_RRESP,
    input  wire                             OM0_AXI_RVALID,
    output wire                             OM0_AXI_RREADY
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
    wire dispatch_alu_pass_op1;  // 新增：ALU旁路信号
    wire dispatch_alu_pass_op2;  // 新增：ALU旁路信

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

    // 新增 BHT 回写接口信号
    wire bht_update_valid;  // BHT更新有效
    wire [`INST_ADDR_WIDTH-1:0] bht_update_pc;  // BHT更新的PC
    wire bht_real_taken;  // 分支实际结果

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

    // CLINT AXI-Lite接口信号
    wire OM1_AXI_ACLK;
    wire OM1_AXI_ARESETN;
    wire [`BUS_ADDR_WIDTH-1 : 0] OM1_AXI_AWADDR;
    wire [2 : 0] OM1_AXI_AWPROT;
    wire OM1_AXI_AWVALID;
    wire OM1_AXI_AWREADY;
    wire [`BUS_DATA_WIDTH-1 : 0] OM1_AXI_WDATA;
    wire [(`BUS_DATA_WIDTH/8)-1 : 0] OM1_AXI_WSTRB;
    wire OM1_AXI_WVALID;
    wire OM1_AXI_WREADY;
    wire [1 : 0] OM1_AXI_BRESP;
    wire OM1_AXI_BVALID;
    wire OM1_AXI_BREADY;
    wire [`BUS_ADDR_WIDTH-1 : 0] OM1_AXI_ARADDR;
    wire [2 : 0] OM1_AXI_ARPROT;
    wire OM1_AXI_ARVALID;
    wire OM1_AXI_ARREADY;
    wire [`BUS_DATA_WIDTH-1 : 0] OM1_AXI_RDATA;
    wire [1 : 0] OM1_AXI_RRESP;
    wire OM1_AXI_RVALID;
    wire OM1_AXI_RREADY;


    // PLIC AXI-Lite接口信号
    wire OM2_AXI_ACLK;
    wire OM2_AXI_ARESETN;
    wire [`PLIC_ADDR_WIDTH-1 : 0] OM2_AXI_AWADDR;
    wire [2 : 0] OM2_AXI_AWPROT;
    wire OM2_AXI_AWVALID;
    wire OM2_AXI_AWREADY;
    wire [`BUS_DATA_WIDTH-1 : 0] OM2_AXI_WDATA;
    wire [(`BUS_DATA_WIDTH/8)-1 : 0] OM2_AXI_WSTRB;
    wire OM2_AXI_WVALID;
    wire OM2_AXI_WREADY;
    wire [1 : 0] OM2_AXI_BRESP;
    wire OM2_AXI_BVALID;
    wire OM2_AXI_BREADY;
    wire [`PLIC_ADDR_WIDTH-1 : 0] OM2_AXI_ARADDR;
    wire [2 : 0] OM2_AXI_ARPROT;
    wire OM2_AXI_ARVALID;
    wire OM2_AXI_ARREADY;
    wire [`BUS_DATA_WIDTH-1 : 0] OM2_AXI_RDATA;
    wire [1 : 0] OM2_AXI_RRESP;
    wire OM2_AXI_RVALID;
    wire OM2_AXI_RREADY;


    // IFU模块例化
    ifu u_ifu (
        .clk         (clk),
        .rst_n       (rst_n),
        .jump_flag_i (ctrl_jump_flag_o),
        .jump_addr_i (ctrl_jump_addr_o),
        .stall_flag_i(ctrl_stall_flag_o),

        // 连接 BHT 回写接口
        .update_valid_i(bht_update_valid),
        .update_pc_i   (bht_update_pc),
        .real_taken_i  (bht_real_taken),

        .inst_o           (if_inst_o),
        .inst_addr_o      (if_inst_addr_o),
        .read_resp_error_o(ifu_read_resp_error_o),
        .is_pred_branch_o (if_is_pred_branch_o),    // 连接预测分支信号输出
        .inst_valid_o     (if_inst_valid_o),        // 添加指令有效信号输出

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
        .is_pred_branch_i(if_is_pred_branch_o), // 连接预测分支信号输入
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
        // BHT回写接口连接
        .update_valid_o(bht_update_valid),
        .update_pc_o   (bht_update_pc),
        .real_taken_o  (bht_real_taken),
        // 添加AXI接口连接 - 保持不变
        .M_AXI_AWID        (exu_axi_awid),
        .M_AXI_AWADDR      (exu_axi_awaddr),
        .M_AXI_AWLEN       (exu_axi_awlen),
        .M_AXI_AWSIZE      (exu_axi_awsize),
        .M_AXI_AWBURST     (exu_axi_awburst),
        .M_AXI_AWLOCK      (exu_axi_awlock),
        .M_AXI_AWCACHE     (exu_axi_awcache),
        .M_AXI_AWPROT      (exu_axi_awprot),
        .M_AXI_AWQOS       (exu_axi_awqos),
        .M_AXI_AWUSER      (exu_axi_awuser),
        .M_AXI_AWVALID     (exu_axi_awvalid),
        .M_AXI_AWREADY     (exu_axi_awready),
        .M_AXI_WDATA       (exu_axi_wdata),
        .M_AXI_WSTRB       (exu_axi_wstrb),
        .M_AXI_WLAST       (exu_axi_wlast),
        .M_AXI_WUSER       (exu_axi_wuser),
        .M_AXI_WVALID      (exu_axi_wvalid),
        .M_AXI_WREADY      (exu_axi_wready),
        .M_AXI_BID         (exu_axi_bid),
        .M_AXI_BRESP       (exu_axi_bresp),
        .M_AXI_BUSER       (exu_axi_buser),
        .M_AXI_BVALID      (exu_axi_bvalid),
        .M_AXI_BREADY      (exu_axi_bready),
        .M_AXI_ARID        (exu_axi_arid),
        .M_AXI_ARADDR      (exu_axi_araddr),
        .M_AXI_ARLEN       (exu_axi_arlen),
        .M_AXI_ARSIZE      (exu_axi_arsize),
        .M_AXI_ARBURST     (exu_axi_arburst),
        .M_AXI_ARLOCK      (exu_axi_arlock),
        .M_AXI_ARCACHE     (exu_axi_arcache),
        .M_AXI_ARPROT      (exu_axi_arprot),
        .M_AXI_ARQOS       (exu_axi_arqos),
        .M_AXI_ARUSER      (exu_axi_aruser),
        .M_AXI_ARVALID     (exu_axi_arvalid),
        .M_AXI_ARREADY     (exu_axi_arready),
        .M_AXI_RID         (exu_axi_rid),
        .M_AXI_RDATA       (exu_axi_rdata),
        .M_AXI_RRESP       (exu_axi_rresp),
        .M_AXI_RLAST       (exu_axi_rlast),
        .M_AXI_RUSER       (exu_axi_ruser),
        .M_AXI_RVALID      (exu_axi_rvalid),
        .M_AXI_RREADY      (exu_axi_rready)
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

    // mems模块例化
    mems #(
        .ITCM_ADDR_WIDTH     (`ITCM_ADDR_WIDTH),
        .DTCM_ADDR_WIDTH     (`DTCM_ADDR_WIDTH),
        .DATA_WIDTH          (`BUS_DATA_WIDTH),
        .C_AXI_ID_WIDTH      (`BUS_ID_WIDTH),
        .C_AXI_DATA_WIDTH    (`BUS_DATA_WIDTH),
        .C_AXI_ADDR_WIDTH    (`BUS_ADDR_WIDTH),
        .C_OM0_AXI_ADDR_WIDTH(32),
        .C_OM0_AXI_DATA_WIDTH(32),
        .C_OM1_AXI_ADDR_WIDTH(32),
        .C_OM1_AXI_DATA_WIDTH(32),
        .C_OM2_AXI_ADDR_WIDTH(`PLIC_ADDR_WIDTH),
        .C_OM2_AXI_DATA_WIDTH(`BUS_DATA_WIDTH)
    ) u_mems (
        .clk  (clk),
        .rst_n(rst_n),

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
        .M1_AXI_RREADY (exu_axi_rready),

        // APB AXI-Lite 接口连接
        .OM0_AXI_ACLK   (OM0_AXI_ACLK),
        .OM0_AXI_ARESETN(OM0_AXI_ARESETN),
        .OM0_AXI_AWADDR (OM0_AXI_AWADDR),
        .OM0_AXI_AWPROT (OM0_AXI_AWPROT),
        .OM0_AXI_AWVALID(OM0_AXI_AWVALID),
        .OM0_AXI_AWREADY(OM0_AXI_AWREADY),
        .OM0_AXI_WDATA  (OM0_AXI_WDATA),
        .OM0_AXI_WSTRB  (OM0_AXI_WSTRB),
        .OM0_AXI_WVALID (OM0_AXI_WVALID),
        .OM0_AXI_WREADY (OM0_AXI_WREADY),
        .OM0_AXI_BRESP  (OM0_AXI_BRESP),
        .OM0_AXI_BVALID (OM0_AXI_BVALID),
        .OM0_AXI_BREADY (OM0_AXI_BREADY),
        .OM0_AXI_ARADDR (OM0_AXI_ARADDR),
        .OM0_AXI_ARPROT (OM0_AXI_ARPROT),
        .OM0_AXI_ARVALID(OM0_AXI_ARVALID),
        .OM0_AXI_ARREADY(OM0_AXI_ARREADY),
        .OM0_AXI_RDATA  (OM0_AXI_RDATA),
        .OM0_AXI_RRESP  (OM0_AXI_RRESP),
        .OM0_AXI_RVALID (OM0_AXI_RVALID),
        .OM0_AXI_RREADY (OM0_AXI_RREADY),

        // CLINT AXI-Lite 接口内部连线
        .OM1_AXI_ACLK   (OM1_AXI_ACLK),
        .OM1_AXI_ARESETN(OM1_AXI_ARESETN),
        .OM1_AXI_AWADDR (OM1_AXI_AWADDR),
        .OM1_AXI_AWPROT (OM1_AXI_AWPROT),
        .OM1_AXI_AWVALID(OM1_AXI_AWVALID),
        .OM1_AXI_AWREADY(OM1_AXI_AWREADY),
        .OM1_AXI_WDATA  (OM1_AXI_WDATA),
        .OM1_AXI_WSTRB  (OM1_AXI_WSTRB),
        .OM1_AXI_WVALID (OM1_AXI_WVALID),
        .OM1_AXI_WREADY (OM1_AXI_WREADY),
        .OM1_AXI_BRESP  (OM1_AXI_BRESP),
        .OM1_AXI_BVALID (OM1_AXI_BVALID),
        .OM1_AXI_BREADY (OM1_AXI_BREADY),
        .OM1_AXI_ARADDR (OM1_AXI_ARADDR),
        .OM1_AXI_ARPROT (OM1_AXI_ARPROT),
        .OM1_AXI_ARVALID(OM1_AXI_ARVALID),
        .OM1_AXI_ARREADY(OM1_AXI_ARREADY),
        .OM1_AXI_RDATA  (OM1_AXI_RDATA),
        .OM1_AXI_RRESP  (OM1_AXI_RRESP),
        .OM1_AXI_RVALID (OM1_AXI_RVALID),
        .OM1_AXI_RREADY (OM1_AXI_RREADY),

        // PLIC AXI-Lite 接口
        .OM2_AXI_ACLK   (OM2_AXI_ACLK),
        .OM2_AXI_ARESETN(OM2_AXI_ARESETN),
        .OM2_AXI_AWADDR (OM2_AXI_AWADDR),
        .OM2_AXI_AWPROT (OM2_AXI_AWPROT),
        .OM2_AXI_AWVALID(OM2_AXI_AWVALID),
        .OM2_AXI_AWREADY(OM2_AXI_AWREADY),
        .OM2_AXI_WDATA  (OM2_AXI_WDATA),
        .OM2_AXI_WSTRB  (OM2_AXI_WSTRB),
        .OM2_AXI_WVALID (OM2_AXI_WVALID),
        .OM2_AXI_WREADY (OM2_AXI_WREADY),
        .OM2_AXI_BRESP  (OM2_AXI_BRESP),
        .OM2_AXI_BVALID (OM2_AXI_BVALID),
        .OM2_AXI_BREADY (OM2_AXI_BREADY),
        .OM2_AXI_ARADDR (OM2_AXI_ARADDR),
        .OM2_AXI_ARPROT (OM2_AXI_ARPROT),
        .OM2_AXI_ARVALID(OM2_AXI_ARVALID),
        .OM2_AXI_ARREADY(OM2_AXI_ARREADY),
        .OM2_AXI_RDATA  (OM2_AXI_RDATA),
        .OM2_AXI_RRESP  (OM2_AXI_RRESP),
        .OM2_AXI_RVALID (OM2_AXI_RVALID),
        .OM2_AXI_RREADY (OM2_AXI_RREADY)
    );

    // 定义原子操作忙信号 - 使用dispatch提供的HDU原子锁信号
    assign atom_opt_busy = dispatch_long_inst_atom_lock_o | exu_mem_store_busy_o;
endmodule
