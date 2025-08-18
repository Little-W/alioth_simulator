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

    // if模块输出信号
    wire [`INST_DATA_WIDTH-1:0] if_inst1_o;
    wire [`INST_DATA_WIDTH-1:0] if_inst2_o;  // 第二路指令输出
    wire [`INST_ADDR_WIDTH-1:0] if_inst1_addr_o;
    wire [`INST_ADDR_WIDTH-1:0] if_inst2_addr_o;
    wire if_inst1_is_pred_branch_o;  // 添加预测分支信号线
    wire if_inst2_is_pred_branch_o; // 第二路预测分支信号线

    // id模块输出信号
    wire [`INST_ADDR_WIDTH-1:0] idu_inst1_addr_o;
    wire [`INST_ADDR_WIDTH-1:0] idu_inst2_addr_o;  // 第二路指令地址输出
    wire idu_inst1_reg_we_o;
    wire idu_inst2_reg_we_o;  // 第二路指令寄存器写使能输出
    wire [`REG_ADDR_WIDTH-1:0] idu_inst1_reg_waddr_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_inst2_reg_waddr_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_inst1_reg1_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_inst1_reg2_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] idu_inst2_reg1_raddr_o;  // 第二路指令寄存器1读地址输出
    wire [`REG_ADDR_WIDTH-1:0] idu_inst2_reg2_raddr_o;  // 第二路指令寄存器2读地址输出
    wire idu_inst1_csr_we_o;
    wire idu_inst2_csr_we_o;  // 第二路指令CSR写使能输出
    wire [`BUS_ADDR_WIDTH-1:0] idu_inst1_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] idu_inst2_csr_waddr_o;  // 第二路指令CSR写地址输出
    wire [`REG_DATA_WIDTH-1:0] idu_inst1_csr_rdata_o;
    wire [`REG_DATA_WIDTH-1:0] idu_inst2_csr_rdata_o;  // 第二路指令CSR读数据输出
    wire [31:0] idu_inst1_dec_imm_o;
    wire [31:0] idu_inst2_dec_imm_o;  // 第二路指令立即数输出
    wire [`DECINFO_WIDTH-1:0] idu_inst1_dec_info_bus_o;
    wire [`DECINFO_WIDTH-1:0] idu_inst2_dec_info_bus_o;  // 第二路指令译码信息输出
    wire idu_inst1_is_pred_branch_o;  // 添加预测分支指令标志输出
    wire idu_inst2_is_pred_branch_o; // 第二路预测分支指令标志输出

    // exu模块输出信号
    wire exu_stall_flag_o;
    wire exu_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;

    // 系统操作信号
    wire exu_ecall_o;
    wire exu_ebreak_o;
    wire exu_mret_o;

    // EXU的Commit ID信号
    wire [`COMMIT_ID_WIDTH-1:0] exu_csr_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_lsu_commit_id_o;

    // EXU双发射ALU输出信号
    wire [`REG_DATA_WIDTH-1:0] exu_alu0_reg_wdata_o;
    wire exu_alu0_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_alu0_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_alu0_commit_id_o;
    
    wire [`REG_DATA_WIDTH-1:0] exu_alu1_reg_wdata_o;
    wire exu_alu1_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_alu1_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_alu1_commit_id_o;

    // EXU双发射乘法器输出信号
    wire [`REG_DATA_WIDTH-1:0] exu_mul0_reg_wdata_o;
    wire exu_mul0_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_mul0_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_mul0_commit_id_o;
    
    wire [`REG_DATA_WIDTH-1:0] exu_mul1_reg_wdata_o;
    wire exu_mul1_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_mul1_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_mul1_commit_id_o;

    // EXU双发射除法器输出信号
    wire [`REG_DATA_WIDTH-1:0] exu_div0_reg_wdata_o;
    wire exu_div0_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_div0_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_div0_commit_id_o;
    
    wire [`REG_DATA_WIDTH-1:0] exu_div1_reg_wdata_o;
    wire exu_div1_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_div1_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] exu_div1_commit_id_o;

    // EXU单个LSU输出信号
    wire [`REG_DATA_WIDTH-1:0] exu_lsu_reg_wdata_o;
    wire exu_lsu_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_lsu_reg_waddr_o;

    // EXU双发射CSR输出信号  
    wire [`REG_DATA_WIDTH-1:0] exu_csr_reg_wdata_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_csr_reg_waddr_o;
    wire exu_csr_reg_we_o;

    // EXU CSR寄存器写数据输出
    wire [`REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire exu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] exu_csr_raddr_o;  // CSR读地址输出

    // EXU访存繁忙信号
    wire exu_mem_store_busy_o;
    wire exu_lsu_stall_o;

    // wbu输出信号
    wire [`REG_DATA_WIDTH-1:0] wbu_reg1_wdata_o;
    wire wbu_reg1_we_o;
    wire [`REG_ADDR_WIDTH-1:0] wbu_reg1_waddr_o;
    
    wire [`REG_DATA_WIDTH-1:0] wbu_reg2_wdata_o;
    wire wbu_reg2_we_o;
    wire [`REG_ADDR_WIDTH-1:0] wbu_reg2_waddr_o;

    // WBU CSR输出信号
    wire [`REG_DATA_WIDTH-1:0] wbu_csr_wdata_o;
    wire wbu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] wbu_csr_waddr_o;

    // WBU Ready信号
    wire wbu_alu0_ready_o, wbu_alu1_ready_o;
    wire wbu_mul0_ready_o, wbu_mul1_ready_o;
    wire wbu_div0_ready_o, wbu_div1_ready_o;
    wire wbu_lsu_ready_o;
    wire wbu_csr_ready_o;

    // WBU提交信号
    wire wbu_commit_valid1_o, wbu_commit_valid2_o;
    wire [`COMMIT_ID_WIDTH-1:0] wbu_commit_id1_o, wbu_commit_id2_o;

    // regs模块输出信号 - 4路读取端口
    wire [`REG_DATA_WIDTH-1:0] regs_inst1_rs1_rdata_o;
    wire [`REG_DATA_WIDTH-1:0] regs_inst1_rs2_rdata_o;
    wire [`REG_DATA_WIDTH-1:0] regs_inst2_rs1_rdata_o;
    wire [`REG_DATA_WIDTH-1:0] regs_inst2_rs2_rdata_o;

    // csr_reg模块输出信号
    wire [`REG_DATA_WIDTH-1:0] csr_data_o;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_data_o;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mtvec;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mepc;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mstatus;
    wire [`REG_DATA_WIDTH-1:0] csr_clint_csr_mie;

    // ctrl模块输出信号
    wire [`CU_BUS_WIDTH-1:0] ctrl_stall_flag_o;
    wire [`CU_BUS_WIDTH-1:0] ctrl_stall_flag1_o;
    wire [`CU_BUS_WIDTH-1:0] ctrl_stall_flag2_o;
    wire [`CU_BUS_WIDTH-1:0] ctrl_stall_flag_icu_o;
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
    wire clint_flush_flag_o;  // 添加CLINT flush信号
    
    // IDU信号声明
    wire [`BUS_ADDR_WIDTH-1:0] idu_inst1_csr_raddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] idu_inst2_csr_raddr_o;
    wire idu_inst1_jump_o;      // 第一路跳转指令输出
    wire idu_inst1_branch_o;    // 第一路分支指令输出
    wire idu_inst1_csr_type_o;  // 第一路CSR类型指令输出
    wire idu_inst2_csr_type_o;  // 第二路CSR类型指令输出
    
    // ICU其他信号定义
    wire [`COMMIT_ID_WIDTH-1:0] icu_inst1_rd_addr_o;
    wire [`COMMIT_ID_WIDTH-1:0] icu_inst2_rd_addr_o;

    // 显式声明原子操作忙信号和其他缺失信号
    wire atom_opt_busy;
    wire ifu_read_resp_error_o;
    wire [1:0] issue_inst_o;

    // ICU信号定义
    wire [`INST_ADDR_WIDTH-1:0] icu_inst1_addr_o;
    wire [`INST_ADDR_WIDTH-1:0] icu_inst2_addr_o;
    wire icu_inst1_reg_we_o;
    wire icu_inst2_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] icu_inst1_reg_waddr_o;
    wire [`REG_ADDR_WIDTH-1:0] icu_inst2_reg_waddr_o;
    wire [`REG_ADDR_WIDTH-1:0] icu_inst1_reg1_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] icu_inst1_reg2_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] icu_inst2_reg1_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] icu_inst2_reg2_raddr_o;
    wire icu_inst1_csr_we_o;
    wire icu_inst2_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] icu_inst1_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] icu_inst2_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] icu_inst1_csr_raddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] icu_inst2_csr_raddr_o;
    wire [31:0] icu_inst1_dec_imm_o;
    wire [31:0] icu_inst2_dec_imm_o;
    wire [`DECINFO_WIDTH-1:0] icu_inst1_dec_info_bus_o;
    wire [`DECINFO_WIDTH-1:0] icu_inst2_dec_info_bus_o;
    wire icu_inst1_is_pred_branch_o;
    wire icu_inst2_is_pred_branch_o;
    wire [`COMMIT_ID_WIDTH-1:0] icu_inst1_commit_id_o;
    wire [`COMMIT_ID_WIDTH-1:0] icu_inst2_commit_id_o;
    wire icu_inst1_illegal_inst_o;
    wire icu_inst2_illegal_inst_o;
    wire icu_inst1_valid_o;
    wire icu_inst2_valid_o;
    wire icu_long_inst_atom_lock_o;


    wire [`INST_DATA_WIDTH-1:0] icu_inst1_o;
    wire [`INST_DATA_WIDTH-1:0] icu_inst2_o;

    // inst_valid相关信号定义
    wire if_inst1_valid_o;  // IFU输出指令有效信号
    wire if_inst2_valid_o;
    wire pc_misaligned_o;  // IFU输出PC非对齐信号
    wire idu_inst1_valid_o;  // IDU输出指令有效信号
    wire idu_inst2_valid_o;  // 第二路IDU输出指令有效信号
    wire idu_illegal_inst1_o;  // IDU输出非法指令信号
    wire idu_illegal_inst2_o;  // 第二路IDU输出非法指令信号
    wire [`INST_DATA_WIDTH-1:0] idu_inst1_o;  // IDU输出非法指令内容
    wire [`INST_DATA_WIDTH-1:0] idu_inst2_o;  // 第二路IDU输出非法指令内容
    wire dispatch_misaligned_load_o;  // dispatch输出misaligned load信号
    wire dispatch_misaligned_store_o;  // dispatch输出misaligned store信号
    wire dispatch_illegal_inst_o;  // dispatch输出非法指令信号
    wire misaligned_fetch_o;  // EXU输出misaligned fetch信号

    // 给dispatch和HDU的译码信息
    wire ext_int_req;
    wire inst_exu_valid = (ctrl_stall_flag_o[`CU_STALL_DISPATCH] == 0) && 
                        (idu_inst1_dec_info_bus_o[`DECINFO_GRP_BUS] != `DECINFO_GRP_NONE);
    wire jump_addr_valid = dispatch_bjp_op_jal || exu_jump_flag_o;
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
    wire [`BUS_DATA_WIDTH-1:0] ifu_axi_rdata;  // 保持64位用于获取两条指令
    wire [1:0] ifu_axi_rresp;
    wire ifu_axi_rlast;
    wire [3:0] ifu_axi_ruser;
    wire ifu_axi_rvalid;
    wire ifu_axi_rready;

    // dispatch to ALU - 双发射
    wire [31:0] dispatch_alu_op1;
    wire [31:0] dispatch_alu_op2;
    wire dispatch_req_alu;
    wire [`ALU_OP_WIDTH-1:0] dispatch_alu_op_info;
    
    // dispatch to ALU1 - 第二路ALU
    wire [31:0] dispatch_alu1_op1;
    wire [31:0] dispatch_alu1_op2;
    wire dispatch_req_alu1;
    wire [`ALU_OP_WIDTH-1:0] dispatch_alu1_op_info;

    // dispatch to Bru
    wire dispatch_req_bjp;
    wire [31:0] dispatch_bjp_op1;
    wire [31:0] dispatch_bjp_op2;
    wire [31:0] dispatch_bjp_jump_op1;
    wire [31:0] dispatch_bjp_jump_op2;
    wire dispatch_bjp_op_jal;
    wire dispatch_bjp_op_beq;
    wire dispatch_bjp_op_bne;
    wire dispatch_bjp_op_blt;
    wire dispatch_bjp_op_bltu;
    wire dispatch_bjp_op_bge;
    wire dispatch_bjp_op_bgeu;
    wire dispatch_bjp_op_jalr;
    wire dispatch_inst_is_pred_branch_o;  // 添加预测分支指令标志输出

    // dispatch to MULDIV - 双发射
    wire dispatch_req_mul;
    wire [31:0] dispatch_mul_op1;
    wire [31:0] dispatch_mul_op2;
    wire dispatch_mul_op_mul;
    wire dispatch_mul_op_mulh;
    wire dispatch_mul_op_mulhsu;
    wire dispatch_mul_op_mulhu;
    wire dispatch_req_div;
    wire [31:0] dispatch_div_op1;
    wire [31:0] dispatch_div_op2;
    wire dispatch_div_op_div;
    wire dispatch_div_op_divu;
    wire dispatch_div_op_rem;
    wire dispatch_div_op_remu;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_div_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_mul_commit_id;


    // dispatch to MULDIV2 - 第二路乘除法
    wire dispatch_req_mul2;
    wire [31:0] dispatch_mul2_op1;
    wire [31:0] dispatch_mul2_op2;
    wire dispatch_mul2_op_mul;
    wire dispatch_mul2_op_mulh;
    wire dispatch_mul2_op_mulhsu;
    wire dispatch_mul2_op_mulhu;
    wire dispatch_req_div2;
    wire [31:0] dispatch_div2_op1;
    wire [31:0] dispatch_div2_op2;
    wire dispatch_div2_op_div;
    wire dispatch_div2_op_divu;
    wire dispatch_div2_op_rem;
    wire dispatch_div2_op_remu;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_div2_commit_id;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_mul2_commit_id;

    // dispatch to CSR - 双路输出
    wire dispatch_inst1_req_csr_o;
    wire [31:0] dispatch_inst1_csr_op1_o;
    wire [31:0] dispatch_inst1_csr_addr_o;
    wire dispatch_inst1_csr_csrrw_o;
    wire dispatch_inst1_csr_csrrs_o;
    wire dispatch_inst1_csr_csrrc_o;
    wire dispatch_inst1_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_inst1_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_inst1_csr_raddr_o;
    wire dispatch_inst1_csr_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] dispatch_inst1_csr_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_inst1_csr_commit_id_o;

    wire dispatch_inst2_req_csr_o;
    wire [31:0] dispatch_inst2_csr_op1_o;
    wire [31:0] dispatch_inst2_csr_addr_o;
    wire dispatch_inst2_csr_csrrw_o;
    wire dispatch_inst2_csr_csrrs_o;
    wire dispatch_inst2_csr_csrrc_o;
    wire dispatch_inst2_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_inst2_csr_waddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] dispatch_inst2_csr_raddr_o;
    wire dispatch_inst2_csr_reg_we_o;
    wire [`REG_ADDR_WIDTH-1:0] dispatch_inst2_csr_reg_waddr_o;
    wire [`COMMIT_ID_WIDTH-1:0] dispatch_inst2_csr_commit_id_o;

    // dispatch to MEM
    wire dispatch_req_mem;
    wire dispatch_mem_op_lb;
    wire dispatch_mem_op_lh;
    wire dispatch_mem_op_lw;
    wire dispatch_mem_op_lbu;
    wire dispatch_mem_op_lhu;
    wire dispatch_mem_op_load;
    wire dispatch_mem_op_store;
    wire [2:0] dispatch_mem_commit_id;
    wire [4:0] dispatch_mem_reg_waddr;
    wire [31:0] dispatch_mem_addr;
    wire [63:0] dispatch_mem_wdata;
    wire [7:0] dispatch_mem_wmask;
    wire dispatch_mem_atom_lock_o;
    wire dispatch_mem_stall_req_o;

    // dispatch to SYS
    wire dispatch_sys_op_nop;
    wire dispatch_sys_op_mret;
    wire dispatch_sys_op_ecall;
    wire dispatch_sys_op_ebreak;
    wire dispatch_sys_op_fence;
    wire dispatch_sys_op_dret;

    wire  dispatch_inst1_misaligned_load_o;
    wire  dispatch_inst1_misaligned_store_o;
    wire  dispatch_inst1_illegal_o;
    wire  dispatch_inst2_misaligned_load_o;
    wire  dispatch_inst2_misaligned_store_o;
    wire  dispatch_inst2_illegal_o;

    wire [31:0] dispatch_inst1_addr_o; 
    wire [31:0] dispatch_inst2_addr_o; 
    wire [31:0] dispatch_inst1_o; 
    wire [31:0] dispatch_inst2_o; 
    wire dispatch_inst1_valid_o; 
    wire dispatch_inst2_valid_o; 
    wire dispatch_inst1_reg_we_o; 
    wire dispatch_inst2_reg_we_o; 
    wire [ `REG_ADDR_WIDTH-1:0] dispatch_inst1_reg_waddr_o; 
    wire [ `REG_ADDR_WIDTH-1:0] dispatch_inst2_reg_waddr_o; 
    wire [                31:0] dispatch_inst1_dec_imm_o; 
    wire [  `DECINFO_WIDTH-1:0] dispatch_inst1_dec_info_bus_o; 
    wire [                31:0] dispatch_inst2_dec_imm_o; 
    wire [  `DECINFO_WIDTH-1:0] dispatch_inst2_dec_info_bus_o; 
    wire [               31:0] dispatch_inst1_rs1_rdata_o; 
    wire [               31:0] dispatch_inst1_rs2_rdata_o; 
    wire [               31:0] dispatch_inst2_rs1_rdata_o; 
    wire [               31:0] dispatch_inst2_rs2_rdata_o;  
    wire [2:0] dispatch_inst1_commit_id_o; 
    wire [2:0] dispatch_inst2_commit_id_o;

    

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

    // // 给dispatch和HDU的译码信息 - 修改为双发射
    // // 双发射的指令有效信号
    // // 双发射的指令有效信号 - 64位访存的正确处理
    // // 当PC[2]=0时：可以双发射（inst1和inst2都可能有效）
    // // 当PC[2]=1时：只能单发射（只有inst1有效，inst2无效）
    // wire inst1_valid = (ctrl_stall_flag_o == 0);  // inst1总是可能有效
    // wire inst2_valid = (ctrl_stall_flag_o == 0) && !pc_misaligned_o;  // inst2只在PC对齐时有效
    
    // // 双发射的EXU有效信号 - 64位访存的正确处理
    // wire inst1_exu_valid = (ctrl_stall_flag_o[`CU_STALL_DISPATCH] == 0) && 
    //                       (icu_inst1_dec_info_bus_o[`DECINFO_GRP_BUS] != `DECINFO_GRP_NONE);
    // wire inst2_exu_valid = (ctrl_stall_flag_o[`CU_STALL_DISPATCH] == 0) && 
    //                       !pc_misaligned_o &&
    //                       (icu_inst2_dec_info_bus_o[`DECINFO_GRP_BUS] != `DECINFO_GRP_NONE);
    
    // 双发射的CLINT有效信号 - 考虑PC非对齐
    wire inst1_clint_valid = !dispatch_inst_is_pred_branch_o && (dispatch_inst1_valid_o);
    wire inst2_clint_valid = !dispatch_inst_is_pred_branch_o && (dispatch_inst2_valid_o);

    // // 双发射的寄存器访问有效信号 - 64位访存的正确处理
    // wire inst1_rd_access_valid = icu_inst1_reg_we_o && !ctrl_stall_flag_o && !clint_req_valid_o;
    // wire inst2_rd_access_valid = icu_inst2_reg_we_o && !ctrl_stall_flag_o && !clint_req_valid_o && !pc_misaligned_o;

    wire clint_inst_valid_i = inst1_clint_valid || inst2_clint_valid;
    wire [31:0] clint_inst_addr_i = inst1_clint_valid ? dispatch_inst1_addr_o : dispatch_inst2_addr_o;
    wire [31:0] clint_inst_i = inst1_clint_valid ? dispatch_inst1_o : dispatch_inst2_o;

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
        .clk              (clk),
        .rst_n            (rst_n),
        .jump_flag_i      (ctrl_jump_flag_o),
        .jump_addr_i      (ctrl_jump_addr_o),
        .stall_flag_i     (ctrl_stall_flag_o),
        .inst1_o          (if_inst1_o),
        .inst1_addr_o     (if_inst1_addr_o),
        .inst2_o          (if_inst2_o),
        .inst2_addr_o     (if_inst2_addr_o),
        .read_resp_error_o(ifu_read_resp_error_o),
        .is_pred_branch1_o(if_inst1_is_pred_branch_o),    // 第一条指令预测分支信号输出
        .is_pred_branch2_o(if_inst2_is_pred_branch_o),    // 第二条指令预测分支信号输出
        .inst1_valid_o     (if_inst1_valid_o),   
        .inst2_valid_o     (if_inst2_valid_o),       // 添加指令有效信号输出
        .pc_misaligned_o  (pc_misaligned_o),   // PC非对齐信号输出

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
        .issue_inst_hdu_i  (issue_inst_o),  // 修改为从icu获取数据冒险暂停信号
        .agu_req_stall_i   (dispatch_mem_stall_req_o),
        .stall_flag_o      (ctrl_stall_flag_o),
        .stall_flag1_o     (ctrl_stall_flag1_o),
        .stall_flag2_o     (ctrl_stall_flag2_o),
        .stall_flag_icu_o  (ctrl_stall_flag_icu_o),
        .jump_flag_o       (ctrl_jump_flag_o),
        .jump_addr_o       (ctrl_jump_addr_o)
    );

    // gpr模块例化 - 支持4路读取和双路写回
    gpr u_gpr (
        .clk     (clk),
        .rst_n   (rst_n),
        // 双路写回端口
        .we1_i   (wbu_reg1_we_o),
        .waddr1_i(wbu_reg1_waddr_o),
        .wdata1_i(wbu_reg1_wdata_o),
        .we2_i   (wbu_reg2_we_o),
        .waddr2_i(wbu_reg2_waddr_o),
        .wdata2_i(wbu_reg2_wdata_o),
        // 4路读取端口 (inst1的rs1, rs2和inst2的rs1, rs2)
        .inst1_rs1_raddr_i(icu_inst1_reg1_raddr_o),
        .inst1_rs2_raddr_i(icu_inst1_reg2_raddr_o),
        .inst2_rs1_raddr_i(icu_inst2_reg1_raddr_o),
        .inst2_rs2_raddr_i(icu_inst2_reg2_raddr_o),
        .inst1_rs1_rdata_o(regs_inst1_rs1_rdata_o),
        .inst1_rs2_rdata_o(regs_inst1_rs2_rdata_o),
        .inst2_rs1_rdata_o(regs_inst2_rs1_rdata_o),
        .inst2_rs2_rdata_o(regs_inst2_rs2_rdata_o)
    );

    // csr模块例化 
    csr u_csr (
        .clk              (clk),
        .rst_n            (rst_n),
        .we_i             (wbu_csr_we_o),
        .raddr_i          (exu_csr_raddr_o),
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

    // idu模块例化 - 更新接口，支持双发射
    idu u_idu (
        .clk             (clk),
        .rst_n           (rst_n),
        
        // 控制信号
        .stall_flag1_i    (ctrl_stall_flag1_o),
        .stall_flag2_i    (ctrl_stall_flag2_o),

        // 第一路指令输入
        .inst_i          (if_inst1_o),
        .inst_addr_i     (if_inst1_addr_o),
        .is_pred_branch_i(if_inst1_is_pred_branch_o),  // 连接预测分支信号输入
        .inst_valid_i    (if_inst1_valid_o),            // 添加指令有效信号输入

        // 第二路指令输入（暂时未实现，连接到无效值）
        .inst2_i         (if_inst2_o),                 // 第二路指令
        .inst2_addr_i    (if_inst2_addr_o),            // 第二路地址
        .is_pred_branch2_i(if_inst2_is_pred_branch_o), // 第二路预测分支
        .inst2_valid_i   (if_inst2_valid_o),            // 第二路指令有效信号输入

        // CSR读地址输出
        .inst1_csr_raddr_o     (idu_inst1_csr_raddr_o),
        .inst2_csr_raddr_o     (idu_inst2_csr_raddr_o),     // 第二路CSR读地址

        // 第一路输出
        .inst1_reg_we_o  (idu_inst1_reg_we_o),
        .inst1_reg_waddr_o(idu_inst1_reg_waddr_o),
        .inst1_reg1_raddr_o(idu_inst1_reg1_raddr_o),
        .inst1_reg2_raddr_o(idu_inst1_reg2_raddr_o),
        .inst1_csr_we_o  (idu_inst1_csr_we_o),
        .inst1_csr_waddr_o(idu_inst1_csr_waddr_o),
        .inst1_dec_imm_o (idu_inst1_dec_imm_o),
        .inst1_dec_info_bus_o(idu_inst1_dec_info_bus_o),
        .inst1_is_pred_branch_o(idu_inst1_is_pred_branch_o),  // 连接预测分支信号输出
        .inst1_valid_o   (idu_inst1_valid_o),                  // 添加指令有效信号输出
        .inst1_illegal_inst_o(idu_illegal_inst1_o),
        .inst1_o         (idu_inst1_o),                        // 添加指令内容输出
        .inst1_jump_o    (idu_inst1_jump_o),                   // 跳转指令输出
        .inst1_branch_o  (idu_inst1_branch_o),                 // 分支指令输出
        .inst1_csr_type_o(idu_inst1_csr_type_o),               // CSR类型指令输出 
        .inst1_addr_o    (idu_inst1_addr_o),
        // 第二路输出
        .inst2_addr_o    (idu_inst2_addr_o),
        .inst2_reg_we_o  (idu_inst2_reg_we_o),
        .inst2_reg_waddr_o(idu_inst2_reg_waddr_o),
        .inst2_reg1_raddr_o(idu_inst2_reg1_raddr_o),
        .inst2_reg2_raddr_o(idu_inst2_reg2_raddr_o),
        .inst2_csr_we_o  (idu_inst2_csr_we_o),
        .inst2_csr_waddr_o(idu_inst2_csr_waddr_o),
        .inst2_dec_imm_o (idu_inst2_dec_imm_o),
        .inst2_dec_info_bus_o(idu_inst2_dec_info_bus_o),
        .inst2_is_pred_branch_o(idu_inst2_is_pred_branch_o),
        .inst2_valid_o   (idu_inst2_valid_o),
        .inst2_illegal_inst_o(idu_illegal_inst2_o),
        .inst2_o         (idu_inst2_o),
        .inst2_csr_type_o(idu_inst2_csr_type_o)
    );

    // ICU模块例化 - 指令控制单元
    icu u_icu (
        .clk                    (clk),
        .rst_n                  (rst_n),
        
        // from idu - 第一路指令
        .inst1_addr_i           (idu_inst1_addr_o),
        .inst1_reg_we_i         (idu_inst1_reg_we_o),
        .inst1_reg_waddr_i      (idu_inst1_reg_waddr_o),
        .inst1_reg1_raddr_i     (idu_inst1_reg1_raddr_o),
        .inst1_reg2_raddr_i     (idu_inst1_reg2_raddr_o),
        .inst1_csr_we_i         (idu_inst1_csr_we_o),
        .inst1_csr_waddr_i      (idu_inst1_csr_waddr_o),
        .inst1_csr_raddr_i      (idu_inst1_csr_raddr_o),
        .inst1_dec_imm_i        (idu_inst1_dec_imm_o),
        .inst1_dec_info_bus_i   (idu_inst1_dec_info_bus_o),
        .inst1_is_pred_branch_i (idu_inst1_is_pred_branch_o),
        .inst1_i                (idu_inst1_o),
        .inst1_illegal_inst_i   (idu_illegal_inst1_o),
        .inst1_valid_i          (idu_inst1_valid_o),
        .inst1_jump_i           (idu_inst1_jump_o),  // 第一路跳转信号
        .inst1_branch_i         (idu_inst1_branch_o), // 第一路分支信号
        .inst1_csr_type_i       (idu_inst1_csr_type_o), // 第一路CSR类型指令

        // from idu - 第二路指令
        .inst2_addr_i           (idu_inst2_addr_o),
        .inst2_reg_we_i         (idu_inst2_reg_we_o),
        .inst2_reg_waddr_i      (idu_inst2_reg_waddr_o),
        .inst2_reg1_raddr_i     (idu_inst2_reg1_raddr_o),
        .inst2_reg2_raddr_i     (idu_inst2_reg2_raddr_o),
        .inst2_csr_we_i         (idu_inst2_csr_we_o),
        .inst2_csr_waddr_i      (idu_inst2_csr_waddr_o),
        .inst2_csr_raddr_i      (idu_inst2_csr_raddr_o),
        .inst2_dec_imm_i        (idu_inst2_dec_imm_o),
        .inst2_dec_info_bus_i   (idu_inst2_dec_info_bus_o),
        .inst2_is_pred_branch_i (idu_inst2_is_pred_branch_o),
        .inst2_i                (idu_inst2_o),
        .inst2_illegal_inst_i   (idu_illegal_inst2_o),
        .inst2_valid_i          (idu_inst2_valid_o),
        .inst2_csr_type_i       (idu_inst2_csr_type_o),

        // 指令完成信号
        .commit_valid_i         (wbu_commit_valid1_o),
        .commit_id_i            (wbu_commit_id1_o),
        .commit_valid2_i        (wbu_commit_valid2_o),
        .commit_id2_i           (wbu_commit_id2_o),
        
        // from control 控制信号
        .stall_flag_i           (ctrl_stall_flag_icu_o),
        .jump_flag_i            (ctrl_jump_flag_o),  // 跳转标志

        .clint_req_valid_i      (clint_req_valid_o),

        // 发射指令的完整decode信息 - 第一路输出
        .inst1_addr_o           (icu_inst1_addr_o),
        .inst1_reg_we_o         (icu_inst1_reg_we_o),
        .inst1_reg_waddr_o      (icu_inst1_reg_waddr_o),
        .inst1_reg1_raddr_o     (icu_inst1_reg1_raddr_o),
        .inst1_reg2_raddr_o     (icu_inst1_reg2_raddr_o),
        .inst1_csr_waddr_o      (icu_inst1_csr_waddr_o),
        .inst1_csr_raddr_o      (icu_inst1_csr_raddr_o),
        .inst1_csr_we_o         (icu_inst1_csr_we_o),
        .inst1_dec_imm_o        (icu_inst1_dec_imm_o),
        .inst1_dec_info_bus_o   (icu_inst1_dec_info_bus_o),
        .inst1_is_pred_branch_o (icu_inst1_is_pred_branch_o),
        .inst1_o                (icu_inst1_o),
        .inst1_illegal_inst_o   (icu_inst1_illegal_inst_o),
        .inst1_valid_o           (icu_inst1_valid_o),

        // 发射指令的完整decode信息 - 第二路输出
        .inst2_addr_o           (icu_inst2_addr_o),
        .inst2_reg_we_o         (icu_inst2_reg_we_o),
        .inst2_reg_waddr_o      (icu_inst2_reg_waddr_o),
        .inst2_reg1_raddr_o     (icu_inst2_reg1_raddr_o),
        .inst2_reg2_raddr_o     (icu_inst2_reg2_raddr_o),
        .inst2_csr_waddr_o      (icu_inst2_csr_waddr_o),
        .inst2_csr_raddr_o      (icu_inst2_csr_raddr_o),
        .inst2_csr_we_o         (icu_inst2_csr_we_o),
        .inst2_dec_imm_o        (icu_inst2_dec_imm_o),
        .inst2_dec_info_bus_o   (icu_inst2_dec_info_bus_o),
        .inst2_is_pred_branch_o (icu_inst2_is_pred_branch_o),
        .inst2_o                (icu_inst2_o),
        .inst2_illegal_inst_o   (icu_inst2_illegal_inst_o),
        .inst2_valid_o          (icu_inst2_valid_o),

        // HDU输出信号
        .issue_inst_o      (issue_inst_o), // to ctrl
        .inst1_commit_id_o      (icu_inst1_commit_id_o), //to dispatch
        .inst2_commit_id_o      (icu_inst2_commit_id_o), 
        .long_inst_atom_lock_o  (icu_long_inst_atom_lock_o) //used in top
    );

    // 添加dispatch模块例化 
    dispatch u_dispatch (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall_flag_i  (ctrl_stall_flag_o),

        // 第一路指令信息输入 - 从ICU获取
        .inst1_addr_i(icu_inst1_addr_o),
        .inst1_reg_we_i(icu_inst1_reg_we_o),
        .inst1_reg_waddr_i(icu_inst1_reg_waddr_o),
        .inst1_reg1_raddr_i(icu_inst1_reg1_raddr_o),
        .inst1_reg2_raddr_i(icu_inst1_reg2_raddr_o),
        .inst1_csr_waddr_i(icu_inst1_csr_waddr_o),
        .inst1_csr_raddr_i(icu_inst1_csr_raddr_o),
        .inst1_csr_we_i(icu_inst1_csr_we_o),
        .inst1_dec_imm_i(icu_inst1_dec_imm_o),
        .inst1_dec_info_bus_i(icu_inst1_dec_info_bus_o),
        .inst1_is_pred_branch_i(icu_inst1_is_pred_branch_o),
        .inst1_i(icu_inst1_o),
        .inst1_commit_id_i(icu_inst1_commit_id_o),
        
        // 第二路指令信息输入 - 从ICU获取
        .inst2_addr_i(icu_inst2_addr_o),
        .inst2_reg_we_i(icu_inst2_reg_we_o),
        .inst2_reg_waddr_i(icu_inst2_reg_waddr_o),
        .inst2_reg1_raddr_i(icu_inst2_reg1_raddr_o),
        .inst2_reg2_raddr_i(icu_inst2_reg2_raddr_o),
        .inst2_csr_waddr_i(icu_inst2_csr_waddr_o),
        .inst2_csr_raddr_i(icu_inst2_csr_raddr_o),
        .inst2_csr_we_i(icu_inst2_csr_we_o),
        .inst2_dec_imm_i(icu_inst2_dec_imm_o),
        .inst2_dec_info_bus_i(icu_inst2_dec_info_bus_o),
        .inst2_is_pred_branch_i(icu_inst2_is_pred_branch_o),
        .inst2_i(icu_inst2_o),
        .inst2_commit_id_i(icu_inst2_commit_id_o),

        // 来自寄存器堆的读取数据
        .inst1_rs1_rdata_i(regs_inst1_rs1_rdata_o),
        .inst1_rs2_rdata_i(regs_inst1_rs2_rdata_o),
        .inst2_rs1_rdata_i(regs_inst2_rs1_rdata_o),
        .inst2_rs2_rdata_i(regs_inst2_rs2_rdata_o),

        // 指令有效和非法指令信号
        .inst1_valid_i (icu_inst1_valid_o),
        .inst2_valid_i (icu_inst2_valid_o),
        .inst1_illegal_inst_i(icu_inst1_illegal_inst_o),
        .inst2_illegal_inst_i(icu_inst2_illegal_inst_o),

        .exu_lsu_stall_i(exu_lsu_stall_o),

        // 分发到各功能单元的信号 
        //第一路ALU
        .inst1_req_alu_o    (dispatch_req_alu),
        .inst1_alu_op1_o    (dispatch_alu_op1),
        .inst1_alu_op2_o    (dispatch_alu_op2),
        .inst1_alu_op_info_o(dispatch_alu_op_info),

        // 第二路ALU输出连接到EXU的ALU1
        .inst2_req_alu_o    (dispatch_req_alu1),
        .inst2_alu_op1_o    (dispatch_alu1_op1),
        .inst2_alu_op2_o    (dispatch_alu1_op2),
        .inst2_alu_op_info_o(dispatch_alu1_op_info),

        // 跳转/分支指令 - to bru
        .req_bjp_o     (dispatch_req_bjp),
        .bjp_op1_o     (dispatch_bjp_op1),
        .bjp_op2_o     (dispatch_bjp_op2),
        .bjp_jump_op1_o(dispatch_bjp_jump_op1),
        .bjp_jump_op2_o(dispatch_bjp_jump_op2),
        .bjp_op_jal_o  (dispatch_bjp_op_jal),
        .bjp_op_beq_o  (dispatch_bjp_op_beq),
        .bjp_op_bne_o  (dispatch_bjp_op_bne),
        .bjp_op_blt_o  (dispatch_bjp_op_blt),
        .bjp_op_bltu_o (dispatch_bjp_op_bltu),
        .bjp_op_bge_o  (dispatch_bjp_op_bge),
        .bjp_op_bgeu_o (dispatch_bjp_op_bgeu),
        .bjp_op_jalr_o (dispatch_bjp_op_jalr),
        .inst_is_pred_branch_o  (dispatch_inst_is_pred_branch_o), // 连接预测分支信号输出

        // 第一路乘除法指令
        .inst1_req_mul_o      (dispatch_req_mul),
        .inst1_mul_op1_o      (dispatch_mul_op1),
        .inst1_mul_op2_o      (dispatch_mul_op2),
        .inst1_mul_op_mul_o   (dispatch_mul_op_mul),
        .inst1_mul_op_mulh_o  (dispatch_mul_op_mulh),
        .inst1_mul_op_mulhsu_o(dispatch_mul_op_mulhsu),
        .inst1_mul_op_mulhu_o (dispatch_mul_op_mulhu),
        .inst1_req_div_o      (dispatch_req_div),
        .inst1_div_op1_o      (dispatch_div_op1),
        .inst1_div_op2_o      (dispatch_div_op2),
        .inst1_div_op_div_o   (dispatch_div_op_div),
        .inst1_div_op_divu_o  (dispatch_div_op_divu),
        .inst1_div_op_rem_o   (dispatch_div_op_rem),
        .inst1_div_op_remu_o  (dispatch_div_op_remu),
        .inst1_mul_commit_id_o(dispatch_mul_commit_id),
        .inst1_div_commit_id_o(dispatch_div_commit_id),

        // 第二路乘除法指令
        .inst2_req_mul_o      (dispatch_req_mul2),
        .inst2_mul_op1_o      (dispatch_mul2_op1),
        .inst2_mul_op2_o      (dispatch_mul2_op2),
        .inst2_mul_op_mul_o   (dispatch_mul2_op_mul),
        .inst2_mul_op_mulh_o  (dispatch_mul2_op_mulh),
        .inst2_mul_op_mulhsu_o(dispatch_mul2_op_mulhsu),
        .inst2_mul_op_mulhu_o (dispatch_mul2_op_mulhu),
        .inst2_req_div_o      (dispatch_req_div2),
        .inst2_div_op1_o      (dispatch_div2_op1),
        .inst2_div_op2_o      (dispatch_div2_op2),
        .inst2_div_op_div_o   (dispatch_div2_op_div),
        .inst2_div_op_divu_o  (dispatch_div2_op_divu),
        .inst2_div_op_rem_o   (dispatch_div2_op_rem),
        .inst2_div_op_remu_o  (dispatch_div2_op_remu),
        .inst2_mul_commit_id_o(dispatch_mul2_commit_id),
        .inst2_div_commit_id_o(dispatch_div2_commit_id),


        // csr指令信号- to csru
        .inst1_req_csr_o  (dispatch_inst1_req_csr_o),
        .inst1_csr_op1_o  (dispatch_inst1_csr_op1_o),
        .inst1_csr_addr_o (dispatch_inst1_csr_addr_o),
        .inst1_csr_csrrw_o(dispatch_inst1_csr_csrrw_o),
        .inst1_csr_csrrs_o(dispatch_inst1_csr_csrrs_o),
        .inst1_csr_csrrc_o(dispatch_inst1_csr_csrrc_o),
        .inst1_csr_we_o (dispatch_inst1_csr_we_o),
        .inst1_csr_waddr_o(dispatch_inst1_csr_waddr_o),
        .inst1_csr_raddr_o(dispatch_inst1_csr_raddr_o),
        .inst1_csr_reg_we_o(dispatch_inst1_csr_reg_we_o),
        .inst1_csr_reg_waddr_o(dispatch_inst1_csr_reg_waddr_o),
        .inst1_csr_commit_id_o(dispatch_inst1_csr_commit_id_o),

        .inst2_req_csr_o  (dispatch_inst2_req_csr_o),
        .inst2_csr_op1_o  (dispatch_inst2_csr_op1_o),
        .inst2_csr_addr_o (dispatch_inst2_csr_addr_o),
        .inst2_csr_csrrw_o(dispatch_inst2_csr_csrrw_o),
        .inst2_csr_csrrs_o(dispatch_inst2_csr_csrrs_o),
        .inst2_csr_csrrc_o(dispatch_inst2_csr_csrrc_o),
        .inst2_csr_we_o (dispatch_inst2_csr_we_o),
        .inst2_csr_waddr_o(dispatch_inst2_csr_waddr_o),
        .inst2_csr_raddr_o(dispatch_inst2_csr_raddr_o),
        .inst2_csr_reg_we_o(dispatch_inst2_csr_reg_we_o),
        .inst2_csr_reg_waddr_o(dispatch_inst2_csr_reg_waddr_o),
        .inst2_csr_commit_id_o(dispatch_inst2_csr_commit_id_o),

        //to lsu - 修改为正确的接口名称
        .req_mem_o               (dispatch_req_mem),
        .mem_op_lb_o             (dispatch_mem_op_lb),
        .mem_op_lh_o             (dispatch_mem_op_lh),
        .mem_op_lw_o             (dispatch_mem_op_lw),
        .mem_op_lbu_o            (dispatch_mem_op_lbu),
        .mem_op_lhu_o            (dispatch_mem_op_lhu),
        .mem_op_load_o           (dispatch_mem_op_load),
        .mem_op_store_o          (dispatch_mem_op_store),
        .mem_addr_o              (dispatch_mem_addr),
        .mem_wmask_o             (dispatch_mem_wmask),
        .mem_wdata_o             (dispatch_mem_wdata),
        .mem_commit_id_o         (dispatch_mem_commit_id),
        .mem_reg_waddr_o         (dispatch_mem_reg_waddr),
        .mem_atom_lock_o         (dispatch_mem_atom_lock_o),
        .mem_stall_req_o         (dispatch_mem_stall_req_o),

        // sys指令 - 只需要一路
        .sys_op_nop_o      (dispatch_sys_op_nop),
        .sys_op_mret_o     (dispatch_sys_op_mret),
        .sys_op_ecall_o    (dispatch_sys_op_ecall),
        .sys_op_ebreak_o   (dispatch_sys_op_ebreak),
        .sys_op_fence_o    (dispatch_sys_op_fence),
        .sys_op_dret_o     (dispatch_sys_op_dret),

        // 其他指令信号 - 第一路
        .misaligned_load_o (dispatch_misaligned_load_o),
        .misaligned_store_o(dispatch_misaligned_store_o),
        .inst1_illegal_inst_o    (dispatch_inst1_illegal_o),       // 连接IDU的非法指令输出

        // 其他指令信号 - 第二路
        .inst2_illegal_inst_o    (dispatch_inst2_illegal_o),

        .inst1_addr_o          (dispatch_inst1_addr_o),
        .inst2_addr_o          (dispatch_inst2_addr_o),
        .inst1_o                (dispatch_inst1_o),
        .inst2_o                (dispatch_inst2_o),
        .inst1_valid_o         (dispatch_inst1_valid_o),
        .inst2_valid_o         (dispatch_inst2_valid_o),
        .inst1_reg_we_o        (dispatch_inst1_reg_we_o),
        .inst2_reg_we_o        (dispatch_inst2_reg_we_o),
        .inst1_reg_waddr_o     (dispatch_inst1_reg_waddr_o),
        .inst2_reg_waddr_o     (dispatch_inst2_reg_waddr_o),
        .inst1_dec_imm_o       (dispatch_inst1_dec_imm_o),
        .inst1_dec_info_bus_o  (dispatch_inst1_dec_info_bus_o),
        .inst2_dec_imm_o       (dispatch_inst2_dec_imm_o),
        .inst2_dec_info_bus_o  (dispatch_inst2_dec_info_bus_o),
        .inst1_rs1_rdata_o     (dispatch_inst1_rs1_rdata_o),
        .inst1_rs2_rdata_o     (dispatch_inst1_rs2_rdata_o),
        .inst2_rs1_rdata_o     (dispatch_inst2_rs1_rdata_o),
        .inst2_rs2_rdata_o     (dispatch_inst2_rs2_rdata_o),
        .inst1_commit_id_o     (dispatch_inst1_commit_id_o),
        .inst2_commit_id_o     (dispatch_inst2_commit_id_o)
    );

    // exu模块例化 - 修改为双发射接口
    exu u_exu (
        .clk(clk),
        .rst_n(rst_n),
        .stall_i(ctrl_stall_flag_o[`CU_STALL_DISPATCH]),
        .flush_i(ctrl_jump_flag_o),

        // (保持兼容性的信号)
        .inst_addr_i(dispatch_inst2_addr_o),
        .int_assert_i(clint_int_assert_o),
        .int_jump_i(clint_int_jump_o),
        .int_addr_i(clint_int_addr_o),

        // 双发射ALU0接口 - 来自dispatch
        .req_alu0_i(dispatch_req_alu),
        .alu0_op1_i(dispatch_alu_op1),
        .alu0_op2_i(dispatch_alu_op2),
        .alu0_op_info_i(dispatch_alu_op_info),
        .alu0_rd_i(dispatch_inst1_reg_waddr_o),
        .alu0_commit_id_i(dispatch_inst1_commit_id_o),
        .alu0_reg_we_i(dispatch_inst1_reg_we_o),
        .alu0_wb_ready_i(wbu_alu0_ready_o),

        // 双发射ALU1接口 - 来自dispatch
        .req_alu1_i(dispatch_req_alu1),
        .alu1_op1_i(dispatch_alu1_op1),
        .alu1_op2_i(dispatch_alu1_op2),
        .alu1_op_info_i(dispatch_alu1_op_info),
        .alu1_rd_i(dispatch_inst2_reg_waddr_o),
        .alu1_commit_id_i(dispatch_inst2_commit_id_o),
        .alu1_reg_we_i(dispatch_inst2_reg_we_o),
        .alu1_wb_ready_i(wbu_alu1_ready_o),

        // 乘法器0接口
        .req_mul0_i(dispatch_req_mul),
        .mul0_op1_i(dispatch_mul_op1),
        .mul0_op2_i(dispatch_mul_op2),
        .mul0_op_mul_i(dispatch_mul_op_mul),
        .mul0_op_mulh_i(dispatch_mul_op_mulh),
        .mul0_op_mulhsu_i(dispatch_mul_op_mulhsu),
        .mul0_op_mulhu_i(dispatch_mul_op_mulhu),
        .mul0_commit_id_i(dispatch_mul_commit_id),
        .mul0_reg_waddr_i(dispatch_inst1_reg_waddr_o),
        .mul0_wb_ready_i(wbu_mul0_ready_o),

        // 乘法器1接口
        .req_mul1_i(dispatch_req_mul2),
        .mul1_op1_i(dispatch_mul2_op1),
        .mul1_op2_i(dispatch_mul2_op2),
        .mul1_op_mul_i(dispatch_mul2_op_mul),
        .mul1_op_mulh_i(dispatch_mul2_op_mulh),
        .mul1_op_mulhsu_i(dispatch_mul2_op_mulhsu),
        .mul1_op_mulhu_i(dispatch_mul2_op_mulhu),
        .mul1_commit_id_i(dispatch_mul2_commit_id),
        .mul1_reg_waddr_i(dispatch_inst2_reg_waddr_o),
        .mul1_wb_ready_i(wbu_mul1_ready_o),

        // 除法器0接口
        .req_div0_i(dispatch_req_div),
        .div0_op1_i(dispatch_div_op1),
        .div0_op2_i(dispatch_div_op2),
        .div0_op_div_i(dispatch_div_op_div),
        .div0_op_divu_i(dispatch_div_op_divu),
        .div0_op_rem_i(dispatch_div_op_rem),
        .div0_op_remu_i(dispatch_div_op_remu),
        .div0_reg_waddr_i(dispatch_inst1_reg_waddr_o),
        .div0_commit_id_i(dispatch_div_commit_id),
        .div0_wb_ready_i(wbu_div0_ready_o),


        // 除法器1接口
        .req_div1_i(dispatch_req_div2),
        .div1_op1_i(dispatch_div2_op1),
        .div1_op2_i(dispatch_div2_op2),
        .div1_op_div_i(dispatch_div2_op_div),
        .div1_op_divu_i(dispatch_div2_op_divu),
        .div1_op_rem_i(dispatch_div2_op_rem),
        .div1_op_remu_i(dispatch_div2_op_remu),
        .div1_reg_waddr_i(dispatch_inst2_reg_waddr_o),
        .div1_commit_id_i(dispatch_div2_commit_id),
        .div1_wb_ready_i(wbu_div1_ready_o),

        // 分支单元接口
        .req_bjp_i(dispatch_req_bjp),
        .bjp_op1_i(dispatch_bjp_op1),
        .bjp_op2_i(dispatch_bjp_op2),
        .bjp_jump_op1_i(dispatch_bjp_jump_op1),
        .bjp_jump_op2_i(dispatch_bjp_jump_op2),
        .bjp_op_jal_i(dispatch_bjp_op_jal),
        .bjp_op_beq_i(dispatch_bjp_op_beq),
        .bjp_op_bne_i(dispatch_bjp_op_bne),
        .bjp_op_blt_i(dispatch_bjp_op_blt),
        .bjp_op_bltu_i(dispatch_bjp_op_bltu),
        .bjp_op_bge_i(dispatch_bjp_op_bge),
        .bjp_op_bgeu_i(dispatch_bjp_op_bgeu),
        .bjp_op_jalr_i(dispatch_bjp_op_jalr),
        .is_pred_branch_i(dispatch_inst_is_pred_branch_o),

        // LSU0接口
        .req_mem_i(dispatch_req_mem),
        .mem_op_lb_i(dispatch_mem_op_lb),
        .mem_op_lh_i(dispatch_mem_op_lh),
        .mem_op_lw_i(dispatch_mem_op_lw),
        .mem_op_lbu_i(dispatch_mem_op_lbu),
        .mem_op_lhu_i(dispatch_mem_op_lhu),
        .mem_op_load_i(dispatch_mem_op_load),
        .mem_op_store_i(dispatch_mem_op_store),
        .mem_rd_i(dispatch_mem_reg_waddr),
        .mem_addr_i(dispatch_mem_addr),
        .mem_wdata_i(dispatch_mem_wdata),
        .mem_wmask_i(dispatch_mem_wmask),
        .mem_commit_id_i(dispatch_mem_commit_id),
        .mem_wb_ready_i(wbu_lsu_ready_o),

        // 单一路CSR接口
        .req_csr_0_i(dispatch_inst1_req_csr_o),
        .csr_op1_0_i(dispatch_inst1_csr_op1_o),
        .csr_addr_0_i(dispatch_inst1_csr_addr_o),
        .csr_csrrw_0_i(dispatch_inst1_csr_csrrw_o),
        .csr_csrrs_0_i(dispatch_inst1_csr_csrrs_o),
        .csr_csrrc_0_i(dispatch_inst1_csr_csrrc_o),
        .csr_commit_id_0_i(dispatch_inst1_csr_commit_id_o),
        .csr_we_0_i(dispatch_inst1_csr_we_o),
        .csr_reg_we_0_i(dispatch_inst1_csr_reg_we_o),
        .csr_waddr_0_i(dispatch_inst1_csr_waddr_o),
        .csr_reg_waddr_0_i(dispatch_inst1_csr_reg_waddr_o),

        .req_csr_1_i(dispatch_inst2_req_csr_o),
        .csr_op1_1_i(dispatch_inst2_csr_op1_o),
        .csr_addr_1_i(dispatch_inst2_csr_addr_o),
        .csr_csrrw_1_i(dispatch_inst2_csr_csrrw_o),
        .csr_csrrs_1_i(dispatch_inst2_csr_csrrs_o),
        .csr_csrrc_1_i(dispatch_inst2_csr_csrrc_o),
        .csr_commit_id_1_i(dispatch_inst2_csr_commit_id_o),
        .csr_we_1_i(dispatch_inst2_csr_we_o),
        .csr_reg_we_1_i(dispatch_inst2_csr_reg_we_o),
        .csr_waddr_1_i(dispatch_inst2_csr_waddr_o),
        .csr_reg_waddr_1_i(dispatch_inst2_csr_reg_waddr_o),

        .csr_rdata_i(csr_data_o),
        .csr_wb_ready_i(wbu_csr_ready_o),

        // 系统操作信号
        .sys_op_nop_i(dispatch_sys_op_nop),
        .sys_op_mret_i(dispatch_sys_op_mret),
        .sys_op_ecall_i(dispatch_sys_op_ecall),
        .sys_op_ebreak_i(dispatch_sys_op_ebreak),
        .sys_op_fence_i(dispatch_sys_op_fence),
        .sys_op_dret_i(dispatch_sys_op_dret),

        // 输出信号 - 到WBU的写回接口
        .alu0_reg_wdata_o(exu_alu0_reg_wdata_o),
        .alu0_reg_we_o(exu_alu0_reg_we_o),
        .alu0_reg_waddr_o(exu_alu0_reg_waddr_o),
        .alu0_commit_id_o(exu_alu0_commit_id_o),

        .alu1_reg_wdata_o(exu_alu1_reg_wdata_o),
        .alu1_reg_we_o(exu_alu1_reg_we_o),
        .alu1_reg_waddr_o(exu_alu1_reg_waddr_o),
        .alu1_commit_id_o(exu_alu1_commit_id_o),

        .mul0_reg_wdata_o(exu_mul0_reg_wdata_o),
        .mul0_reg_we_o(exu_mul0_reg_we_o),
        .mul0_reg_waddr_o(exu_mul0_reg_waddr_o),
        .mul0_commit_id_o(exu_mul0_commit_id_o),

        .mul1_reg_wdata_o(exu_mul1_reg_wdata_o),
        .mul1_reg_we_o(exu_mul1_reg_we_o),
        .mul1_reg_waddr_o(exu_mul1_reg_waddr_o),
        .mul1_commit_id_o(exu_mul1_commit_id_o),

        .div0_reg_wdata_o(exu_div0_reg_wdata_o),
        .div0_reg_we_o(exu_div0_reg_we_o),
        .div0_reg_waddr_o(exu_div0_reg_waddr_o),
        .div0_commit_id_o(exu_div0_commit_id_o),

        .div1_reg_wdata_o(exu_div1_reg_wdata_o),
        .div1_reg_we_o(exu_div1_reg_we_o),
        .div1_reg_waddr_o(exu_div1_reg_waddr_o),
        .div1_commit_id_o(exu_div1_commit_id_o),

        .lsu_reg_wdata_o(exu_lsu_reg_wdata_o),
        .lsu_reg_we_o(exu_lsu_reg_we_o),
        .lsu_reg_waddr_o(exu_lsu_reg_waddr_o),
        .lsu_commit_id_o(exu_lsu_commit_id_o),

        .csr_reg_wdata_o(exu_csr_reg_wdata_o),
        .csr_reg_waddr_o(exu_csr_reg_waddr_o),
        .csr_commit_id_o(exu_csr_commit_id_o),
        .csr_reg_we_o(exu_csr_reg_we_o),
        .csr_wdata_o(exu_csr_wdata_o),
        .csr_we_o(exu_csr_we_o),
        .csr_waddr_o(exu_csr_waddr_o),
        .csr_raddr_o(exu_csr_raddr_o),  // CSR读地址输出

        // 控制输出
        .stall_flag_o(exu_stall_flag_o),
        .jump_flag_o(exu_jump_flag_o),
        .jump_addr_o(exu_jump_addr_o),

        // 访存繁忙信号
        .mem_store_busy_o(exu_mem_store_busy_o),
        .exu_lsu_stall_o(exu_lsu_stall_o),

        // 系统操作信号输出
        .exu_op_ecall_o(exu_ecall_o),
        .exu_op_ebreak_o(exu_ebreak_o),
        .exu_op_mret_o(exu_mret_o),

        // misaligned_fetch信号输出
        .misaligned_fetch_o(misaligned_fetch_o),

        // AXI接口 - 统一LSU
        .M_AXI_AWID(exu_axi_awid),
        .M_AXI_AWADDR(exu_axi_awaddr),
        .M_AXI_AWLEN(exu_axi_awlen),
        .M_AXI_AWSIZE(exu_axi_awsize),
        .M_AXI_AWBURST(exu_axi_awburst),
        .M_AXI_AWLOCK(exu_axi_awlock),
        .M_AXI_AWCACHE(exu_axi_awcache),
        .M_AXI_AWPROT(exu_axi_awprot),
        .M_AXI_AWQOS(exu_axi_awqos),
        .M_AXI_AWUSER(exu_axi_awuser),
        .M_AXI_AWVALID(exu_axi_awvalid),
        .M_AXI_AWREADY(exu_axi_awready),
        .M_AXI_WDATA(exu_axi_wdata),
        .M_AXI_WSTRB(exu_axi_wstrb),
        .M_AXI_WLAST(exu_axi_wlast),
        .M_AXI_WUSER(exu_axi_wuser),
        .M_AXI_WVALID(exu_axi_wvalid),
        .M_AXI_WREADY(exu_axi_wready),
        .M_AXI_BID(exu_axi_bid),
        .M_AXI_BRESP(exu_axi_bresp),
        .M_AXI_BUSER(exu_axi_buser),
        .M_AXI_BVALID(exu_axi_bvalid),
        .M_AXI_BREADY(exu_axi_bready),
        .M_AXI_ARID(exu_axi_arid),
        .M_AXI_ARADDR(exu_axi_araddr),
        .M_AXI_ARLEN(exu_axi_arlen),
        .M_AXI_ARSIZE(exu_axi_arsize),
        .M_AXI_ARBURST(exu_axi_arburst),
        .M_AXI_ARLOCK(exu_axi_arlock),
        .M_AXI_ARCACHE(exu_axi_arcache),
        .M_AXI_ARPROT(exu_axi_arprot),
        .M_AXI_ARQOS(exu_axi_arqos),
        .M_AXI_ARUSER(exu_axi_aruser),
        .M_AXI_ARVALID(exu_axi_arvalid),
        .M_AXI_ARREADY(exu_axi_arready),
        .M_AXI_RID(exu_axi_rid),
        .M_AXI_RDATA(exu_axi_rdata),
        .M_AXI_RRESP(exu_axi_rresp),
        .M_AXI_RLAST(exu_axi_rlast),
        .M_AXI_RUSER(exu_axi_ruser),
        .M_AXI_RVALID(exu_axi_rvalid),
        .M_AXI_RREADY(exu_axi_rready)
    );

    // wbu模块例化 - 更新为新的双发射接口
    wbu u_wbu (
        .clk  (clk),
        .rst_n(rst_n),

        // 来自EXU的ALU数据 (双发射)
        .alu1_reg_wdata_i(exu_alu0_reg_wdata_o),
        .alu1_reg_we_i(exu_alu0_reg_we_o),
        .alu1_reg_waddr_i(exu_alu0_reg_waddr_o),
        .alu1_commit_id_i(exu_alu0_commit_id_o),
        .alu1_ready_o(wbu_alu0_ready_o),

        .alu2_reg_wdata_i(exu_alu1_reg_wdata_o),
        .alu2_reg_we_i(exu_alu1_reg_we_o),
        .alu2_reg_waddr_i(exu_alu1_reg_waddr_o),
        .alu2_commit_id_i(exu_alu1_commit_id_o),
        .alu2_ready_o(wbu_alu1_ready_o),

        // 来自EXU的MUL数据 (双发射)
        .mul1_reg_wdata_i(exu_mul0_reg_wdata_o),
        .mul1_reg_we_i(exu_mul0_reg_we_o),
        .mul1_reg_waddr_i(exu_mul0_reg_waddr_o),
        .mul1_commit_id_i(exu_mul0_commit_id_o),
        .mul1_ready_o(wbu_mul0_ready_o),

        .mul2_reg_wdata_i(exu_mul1_reg_wdata_o),
        .mul2_reg_we_i(exu_mul1_reg_we_o),
        .mul2_reg_waddr_i(exu_mul1_reg_waddr_o),
        .mul2_commit_id_i(exu_mul1_commit_id_o),
        .mul2_ready_o(wbu_mul1_ready_o),

        // 来自EXU的DIV数据 (双发射)
        .div1_reg_wdata_i(exu_div0_reg_wdata_o),
        .div1_reg_we_i(exu_div0_reg_we_o),
        .div1_reg_waddr_i(exu_div0_reg_waddr_o),
        .div1_commit_id_i(exu_div0_commit_id_o),
        .div1_ready_o(wbu_div0_ready_o),

        .div2_reg_wdata_i(exu_div1_reg_wdata_o),
        .div2_reg_we_i(exu_div1_reg_we_o),
        .div2_reg_waddr_i(exu_div1_reg_waddr_o),
        .div2_commit_id_i(exu_div1_commit_id_o),
        .div2_ready_o(wbu_div1_ready_o),

        // 来自EXU的CSR数据 (单路) - 合并来自两个CSR单元的输出
        .csr_wdata_i(exu_csr_wdata_o),
        .csr_we_i(exu_csr_we_o),
        .csr_waddr_i(exu_csr_waddr_o),
        .csr_commit_id_i(exu_csr_commit_id_o),
        .csr_ready_o(wbu_csr_ready_o),

        // CSR寄存器写数据输入 (单路) - 合并来自两个CSR单元的输出
        .csr_reg_wdata_i(exu_csr_reg_wdata_o),
        .csr_reg_waddr_i(exu_csr_reg_waddr_o),
        .csr_reg_we_i(exu_csr_reg_we_o),

        // 来自EXU的LSU数据 (单路)
        .lsu_reg_wdata_i(exu_lsu_reg_wdata_o),
        .lsu_reg_we_i(exu_lsu_reg_we_o),
        .lsu_reg_waddr_i(exu_lsu_reg_waddr_o),
        .lsu_commit_id_i(exu_lsu_commit_id_o),
        .lsu_ready_o(wbu_lsu_ready_o),

        // 长指令完成信号（对接icu）
        .commit_valid1_o(wbu_commit_valid1_o),
        .commit_id1_o(wbu_commit_id1_o),
        .commit_valid2_o(wbu_commit_valid2_o),
        .commit_id2_o(wbu_commit_id2_o),

        // 双寄存器写回接口
        .reg1_wdata_o(wbu_reg1_wdata_o),
        .reg1_we_o(wbu_reg1_we_o),
        .reg1_waddr_o(wbu_reg1_waddr_o),

        .reg2_wdata_o(wbu_reg2_wdata_o),
        .reg2_we_o(wbu_reg2_we_o),
        .reg2_waddr_o(wbu_reg2_waddr_o),

        // 单CSR寄存器写回接口
        .csr_wdata_o(wbu_csr_wdata_o),
        .csr_we_o(wbu_csr_we_o),
        .csr_waddr_o(wbu_csr_waddr_o)
    );

    // clint模块例化 - 增加AXI-lite slave接口直连
    clint u_clint (
        .clk               (clk),
        .rst_n             (rst_n),
        .inst_addr_i       (clint_inst_addr_i),
        .inst_data_i       (clint_inst_i),
        .inst_valid_i      (clint_inst_valid_i),  // 使用双发射的inst1_clint_valid
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
        .C_OM0_AXI_DATA_WIDTH(64),  // APB - 改为64位
        .C_OM1_AXI_ADDR_WIDTH(32),
        .C_OM1_AXI_DATA_WIDTH(64),  // CLINT - 改为64位
        .C_OM2_AXI_ADDR_WIDTH(`PLIC_ADDR_WIDTH),
        .C_OM2_AXI_DATA_WIDTH(64)   // PLIC - 改为64位
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
    assign atom_opt_busy = icu_long_inst_atom_lock_o | exu_mem_store_busy_o | dispatch_mem_stall_req_o;


    assign dispatch_misaligned_load_o = dispatch_inst1_misaligned_load_o | dispatch_inst2_misaligned_load_o;
    assign dispatch_misaligned_store_o = dispatch_inst1_misaligned_store_o | dispatch_inst2_misaligned_store_o;
    assign dispatch_illegal_inst_o = dispatch_inst1_illegal_o | dispatch_inst2_illegal_o;


endmodule
