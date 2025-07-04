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

    input wire clk,
    input wire rst_n,

    // 外设相关引脚
    input  wire         cnt_clk,            // 计数器时钟
    input  wire [63:0]  virtual_sw_input,   // 虚拟开关输入
    input  wire [7:0]   virtual_key_input,  // 虚拟按键输入
    output wire [39:0]  virtual_seg_output, // 虚拟七段显示器输出
    output wire [31:0]  virtual_led_output  // 虚拟LED输出
);

    // pc_reg模块输出信号
    wire [`INST_ADDR_WIDTH-1:0] pc_pc_o;

    // if_id模块输出信号
    wire [`INST_DATA_WIDTH-1:0] if_inst_o;
    wire [`INST_ADDR_WIDTH-1:0] if_inst_addr_o;
    wire [`INST_DATA_WIDTH-1:0] if_int_flag_o;

    // id模块输出信号
    wire [`REG_ADDR_WIDTH-1:0] id_reg1_raddr_o;
    wire [`REG_ADDR_WIDTH-1:0] id_reg2_raddr_o;
    wire [`BUS_ADDR_WIDTH-1:0] id_csr_raddr_o;

    // idu模块输出信号 - 直接包含了ID和ID_EX的功能
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

    // exu模块输出信号
    wire exu_stall_flag_o;
    wire exu_jump_flag_o;
    wire [`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;
    wire [`REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire exu_csr_we_o;
    wire [`BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;
    wire exu_muldiv_started_o;

    // 添加CSR寄存器写数据信号
    wire [`REG_DATA_WIDTH-1:0] exu_csr_reg_wdata_o;
    wire [`REG_ADDR_WIDTH-1:0] exu_csr_reg_waddr_o;

    // 系统操作信号
    wire exu_ecall_o;
    wire exu_ebreak_o;
    wire exu_mret_o;

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
    wire hdu_stall_flag_o;
    wire hdu_long_inst_atom_lock_o;
    wire [1:0] hdu_long_inst_id_o;
    wire wbu_commit_valid_o;
    wire [1:0] wbu_commit_id_o;
    wire wbu_alu_ready_o;
    wire wbu_muldiv_ready_o;
    wire wbu_csr_ready_o;
    wire [7:0] exu_alu_commit_id_o;
    wire [7:0] exu_muldiv_commit_id_o;
    wire [7:0] exu_agu_commit_id_o;

    // 显式声明原子操作忙信号，避免隐式定义
    wire atom_opt_busy;

    // 给HDU的译码信息
    wire inst_valid = (idu_dec_info_bus_o[`DECINFO_GRP_BUS] != `DECINFO_GRP_NONE);
    wire is_muldiv_long_inst = (idu_dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_MULDIV);
    wire is_mem_long_inst = ((idu_dec_info_bus_o[`DECINFO_GRP_BUS] == `DECINFO_GRP_MEM) && idu_dec_info_bus_o[`DECINFO_MEM_OP_LOAD]);
    wire is_long_inst = is_muldiv_long_inst | is_mem_long_inst;
    wire new_long_inst_valid = is_long_inst && !exu_stall_flag_o;
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
        .clk              (clk),
        .rst_n            (rst_n),
        .jump_flag_i      (ctrl_jump_flag_o),
        .jump_addr_i      (ctrl_jump_addr_o),
        .stall_flag_i     (ctrl_stall_flag_o),
        .inst_o           (if_inst_o),
        .inst_addr_o      (if_inst_addr_o),
        .read_resp_error_o(ifu_read_resp_error_o),
        .is_pred_branch_o (if_is_pred_branch_o),  // 连接预测分支信号输出

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

    // ctrl模块例化
    ctrl u_ctrl (
        .clk               (clk),
        .rst_n             (rst_n),
        .jump_flag_i       (exu_jump_flag_o),
        .jump_addr_i       (exu_jump_addr_o),
        .atom_opt_busy_i   (atom_opt_busy),
        .stall_flag_ex_i   (exu_stall_flag_o),
        .flush_flag_clint_i(clint_flush_flag_o),  // 添加连接到clint的flush信号
        .stall_flag_clint_i(clint_stall_flag_o),
        .stall_flag_hdu_i  (hdu_stall_flag_o),
        .stall_flag_o      (ctrl_stall_flag_o),
        .jump_flag_o       (ctrl_jump_flag_o),
        .jump_addr_o       (ctrl_jump_addr_o)
    );

    // gpr模块例化
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

    // csr模块例化
    csr u_csr (
        .clk              (clk),
        .rst_n            (rst_n),
        .we_i             (wbu_csr_we_o),
        .raddr_i          (id_csr_raddr_o),
        .waddr_i          (wbu_csr_waddr_o),
        .data_i           (wbu_csr_wdata_o),
        .inst_valid_i     (inst_valid),
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
        .clk         (clk),
        .rst_n       (rst_n),
        .inst_i      (if_inst_o),
        .inst_addr_i (if_inst_addr_o),
        .stall_flag_i(ctrl_stall_flag_o),

        .commit_valid_i(wbu_commit_valid_o),
        .commit_id_i   (wbu_commit_id_o),

        .csr_raddr_o   (id_csr_raddr_o),
        .inst_addr_o   (idu_inst_addr_o),
        .reg_we_o      (idu_reg_we_o),
        .reg_waddr_o   (idu_reg_waddr_o),
        .reg1_raddr_o  (idu_reg1_raddr_o),
        .reg2_raddr_o  (idu_reg2_raddr_o),
        .csr_we_o      (idu_csr_we_o),
        .csr_waddr_o   (idu_csr_waddr_o),
        .dec_imm_o     (idu_dec_imm_o),
        .dec_info_bus_o(idu_dec_info_bus_o)
    );

    // HDU模块例化
    hdu u_hdu (
        .clk  (clk),
        .rst_n(rst_n),

        // 新指令信息 - 从idu输出获取
        .new_long_inst_valid(new_long_inst_valid),
        .new_inst_rd_addr   (idu_reg_waddr_o),      // 从idu获取目标寄存器地址
        .new_inst_rs1_addr  (idu_reg1_raddr_o),     // 从idu获取源寄存器1地址
        .new_inst_rs2_addr  (idu_reg2_raddr_o),     // 从idu获取源寄存器2地址
        .new_inst_rd_we     (idu_reg_we_o),         // 从idu获取写寄存器使能

        // 长指令完成信号 - 从wbu获取
        .commit_valid_i(wbu_commit_valid_o),
        .commit_id_i   (wbu_commit_id_o),

        // 控制信号输出
        .hazard_stall_o       (hdu_stall_flag_o),
        .commit_id_o          (hdu_long_inst_id_o),
        .long_inst_atom_lock_o(hdu_long_inst_atom_lock_o)
    );

    // exu模块例化 - 直接从HDU接收长指令ID
    exu u_exu (
        .clk           (clk),
        .rst_n         (rst_n),
        .inst_addr_i   (idu_inst_addr_o),
        .reg_we_i      (idu_reg_we_o),
        .reg_waddr_i   (idu_reg_waddr_o),
        .csr_we_i      (idu_csr_we_o),
        .csr_waddr_i   (idu_csr_waddr_o),
        .csr_rdata_i   (csr_data_o),
        .dec_info_bus_i(idu_dec_info_bus_o),
        .dec_imm_i     (idu_dec_imm_o),
        .mem_rdata_i   (exu_mem_data_i),
        .int_assert_i  (clint_int_assert_o),
        .int_addr_i    (clint_int_addr_o),

        // 修改：直接从HDU获取长指令ID
        .inst_id_i(hdu_long_inst_id_o),

        // 写回握手信号
        .alu_wb_ready_i   (wbu_alu_ready_o),
        .muldiv_wb_ready_i(wbu_muldiv_ready_o),
        .csr_wb_ready_i   (wbu_csr_ready_o),

        // 直接从寄存器文件读取数据
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),

        .hazard_stall_i(hdu_stall_flag_o),  // 来自HDU的冒险暂停信号

        .mem_stall_o     (exu_mem_stall_o),
        .mem_store_busy_o(exu_mem_store_busy_o),

        .alu_reg_wdata_o(exu_alu_reg_wdata_o),
        .alu_reg_we_o   (exu_alu_reg_we_o),
        .alu_reg_waddr_o(exu_alu_reg_waddr_o),
        .alu_commit_id_o(exu_alu_commit_id_o),  // 新增信号

        .muldiv_reg_wdata_o(exu_muldiv_reg_wdata_o),
        .muldiv_reg_we_o   (exu_muldiv_reg_we_o),
        .muldiv_reg_waddr_o(exu_muldiv_reg_waddr_o),
        .muldiv_commit_id_o(exu_muldiv_commit_id_o),  // 新增信号

        .agu_reg_wdata_o(exu_agu_reg_wdata_o),
        .agu_reg_we_o   (exu_agu_reg_we_o),
        .agu_reg_waddr_o(exu_agu_reg_waddr_o),
        .agu_commit_id_o(exu_agu_commit_id_o),  // 新增信号

        // 连接CSR寄存器写数据信号
        .csr_reg_wdata_o(exu_csr_reg_wdata_o),
        .csr_reg_waddr_o(exu_csr_reg_waddr_o),  // 连接CSR寄存器写地址输出

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

        // 添加AXI接口连接
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

    // wbu模块例化
    wbu u_wbu (
        .clk  (clk),
        .rst_n(rst_n),

        .alu_reg_wdata_i(exu_alu_reg_wdata_o),
        .alu_reg_we_i   (exu_alu_reg_we_o),
        .alu_reg_waddr_i(exu_alu_reg_waddr_o),
        .alu_ready_o    (wbu_alu_ready_o),      // 新增握手信号

        .muldiv_reg_wdata_i(exu_muldiv_reg_wdata_o),
        .muldiv_reg_we_i   (exu_muldiv_reg_we_o),
        .muldiv_reg_waddr_i(exu_muldiv_reg_waddr_o),
        .muldiv_inst_id_i  (exu_muldiv_commit_id_o[1:0]),  // 乘除法指令ID
        .muldiv_ready_o    (wbu_muldiv_ready_o),           // 新增握手信号

        .csr_wdata_i(exu_csr_wdata_o),
        .csr_we_i   (exu_csr_we_o),
        .csr_waddr_i(exu_csr_waddr_o),
        .csr_ready_o(wbu_csr_ready_o),  // 新增握手信号

        // CSR对通用寄存器的写数据输入
        .csr_reg_wdata_i(exu_csr_reg_wdata_o),
        .csr_reg_waddr_i(exu_csr_reg_waddr_o),  // 连接CSR寄存器写地址

        .agu_reg_wdata_i(exu_agu_reg_wdata_o),
        .agu_reg_we_i   (exu_agu_reg_we_o),
        .agu_reg_waddr_i(exu_agu_reg_waddr_o),
        .agu_inst_id_i  (exu_agu_commit_id_o[1:0]), // LSU指令ID

        .idu_reg_waddr_i(idu_reg_waddr_o),

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

    // clint模块例化
    clint u_clint (
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_addr_i    (idu_inst_addr_o),
        .jump_flag_i    (exu_jump_flag_o),
        .jump_addr_i    (exu_jump_addr_o),
        .stall_flag_i   (ctrl_stall_flag_o),
        .atom_opt_busy_i(atom_opt_busy),      // 原子操作忙标志

        // 连接系统操作信号
        .sys_op_ecall_i (exu_ecall_o),
        .sys_op_ebreak_i(exu_ebreak_o),
        .sys_op_mret_i  (exu_mret_o),

        .data_i         (csr_clint_data_o),
        .csr_mtvec      (csr_clint_csr_mtvec),
        .csr_mepc       (csr_clint_csr_mepc),
        .csr_mstatus    (csr_clint_csr_mstatus),
        .we_o           (clint_we_o),
        .waddr_o        (clint_waddr_o),
        .raddr_o        (clint_raddr_o),
        .data_o         (clint_data_o),
        .flush_flag_o   (clint_flush_flag_o),  // 连接flush信号
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

        // 外设相关引脚
        .cnt_clk            (cnt_clk),
        .virtual_sw_input   (virtual_sw_input),
        .virtual_key_input  (virtual_key_input),
        .virtual_seg_output (virtual_seg_output),
        .virtual_led_output (virtual_led_output),

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

    // 定义原子操作忙信号 - 使用HDU的原子锁
    assign atom_opt_busy = hdu_long_inst_atom_lock_o | exu_mem_store_busy_o;

endmodule
