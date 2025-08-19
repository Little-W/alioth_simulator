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

// 执行单元顶层模块 - 双发射版本 (已精简为单CSR)
module exu (
    input wire clk,
    input wire rst_n,

    // from id_ex (保持兼容性的信号)
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire                        int_assert_i,
    input wire                        int_jump_i,
    input wire [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 双发射ALU0接口 - 来自dispatch
    input wire                        req_alu0_i,
    input wire [                31:0] alu0_op1_i,
    input wire [                31:0] alu0_op2_i,
    input wire [   `ALU_OP_WIDTH-1:0] alu0_op_info_i,
    input wire [                 4:0] alu0_rd_i,
    input wire [`COMMIT_ID_WIDTH-1:0] alu0_commit_id_i,
    input wire                        alu0_reg_we_i,
    input wire                        alu0_wb_ready_i,

    // 双发射ALU1接口 - 来自dispatch
    input wire                        req_alu1_i,
    input wire [                31:0] alu1_op1_i,
    input wire [                31:0] alu1_op2_i,
    input wire [   `ALU_OP_WIDTH-1:0] alu1_op_info_i,
    input wire [                 4:0] alu1_rd_i,
    input wire [`COMMIT_ID_WIDTH-1:0] alu1_commit_id_i,
    input wire                        alu1_reg_we_i,
    input wire                        alu1_wb_ready_i,

    // 乘法器0接口
    input wire                        req_mul0_i,
    input wire [                31:0] mul0_op1_i,
    input wire [                31:0] mul0_op2_i,
    input wire                        mul0_op_mul_i,
    input wire                        mul0_op_mulh_i,
    input wire                        mul0_op_mulhsu_i,
    input wire                        mul0_op_mulhu_i,
    input wire [`COMMIT_ID_WIDTH-1:0] mul0_commit_id_i,
    input wire [ `REG_ADDR_WIDTH-1:0] mul0_reg_waddr_i,
    input wire                        mul0_wb_ready_i,

    // 乘法器1接口
    input wire                        req_mul1_i,
    input wire [                31:0] mul1_op1_i,
    input wire [                31:0] mul1_op2_i,
    input wire                        mul1_op_mul_i,
    input wire                        mul1_op_mulh_i,
    input wire                        mul1_op_mulhsu_i,
    input wire                        mul1_op_mulhu_i,
    input wire [`COMMIT_ID_WIDTH-1:0] mul1_commit_id_i,
    input wire [ `REG_ADDR_WIDTH-1:0] mul1_reg_waddr_i,
    input wire                        mul1_wb_ready_i,

    // 除法器0接口
    input wire                        req_div0_i,
    input wire [                31:0] div0_op1_i,
    input wire [                31:0] div0_op2_i,
    input wire                        div0_op_div_i,
    input wire                        div0_op_divu_i,
    input wire                        div0_op_rem_i,
    input wire                        div0_op_remu_i,
    input wire [ `REG_ADDR_WIDTH-1:0] div0_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] div0_commit_id_i,
    input wire                        div0_wb_ready_i,

    // 除法器1接口
    input wire                        req_div1_i,
    input wire [                31:0] div1_op1_i,
    input wire [                31:0] div1_op2_i,
    input wire                        div1_op_div_i,
    input wire                        div1_op_divu_i,
    input wire                        div1_op_rem_i,
    input wire                        div1_op_remu_i,
    input wire [ `REG_ADDR_WIDTH-1:0] div1_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] div1_commit_id_i,
    input wire                        div1_wb_ready_i,

    // ===== 新增ALU旁路相关端口 =====
    input wire alu0_pass_alu0_op1_i,
    input wire alu0_pass_alu0_op2_i,
    input wire alu0_pass_alu1_op1_i,
    input wire alu0_pass_alu1_op2_i,
    input wire alu1_pass_alu0_op1_i,
    input wire alu1_pass_alu0_op2_i,
    input wire alu1_pass_alu1_op1_i,
    input wire alu1_pass_alu1_op2_i,
    input wire mul0_pass_alu0_op1_i,
    input wire mul0_pass_alu0_op2_i,
    input wire mul0_pass_alu1_op1_i,
    input wire mul0_pass_alu1_op2_i,
    input wire mul1_pass_alu0_op1_i,
    input wire mul1_pass_alu0_op2_i,
    input wire mul1_pass_alu1_op1_i,
    input wire mul1_pass_alu1_op2_i,
    input wire div0_pass_alu0_op1_i,
    input wire div0_pass_alu0_op2_i,
    input wire div0_pass_alu1_op1_i,
    input wire div0_pass_alu1_op2_i,
    input wire div1_pass_alu0_op1_i,
    input wire div1_pass_alu0_op2_i,
    input wire div1_pass_alu1_op1_i,
    input wire div1_pass_alu1_op2_i,

    // 分支单元接口 (保持单实例)
    input wire        req_bjp_i,
    input wire [31:0] bjp_op1_i,
    input wire [31:0] bjp_op2_i,
    input wire [31:0] bjp_jump_op1_i,
    input wire [31:0] bjp_jump_op2_i,
    input wire        bjp_op_jal_i,
    input wire        bjp_op_beq_i,
    input wire        bjp_op_bne_i,
    input wire        bjp_op_blt_i,
    input wire        bjp_op_bltu_i,
    input wire        bjp_op_bge_i,
    input wire        bjp_op_bgeu_i,
    input wire        bjp_op_jalr_i,
    input wire        is_pred_branch_i,

    // LSU0接口 - 适配双发射64位数据总线
    input wire                        req_mem_i,
    input wire                        mem_op_lb_i,
    input wire                        mem_op_lh_i,
    input wire                        mem_op_lw_i,
    input wire                        mem_op_lbu_i,
    input wire                        mem_op_lhu_i,
    input wire                        mem_op_load_i,
    input wire                        mem_op_store_i,
    input wire [                 4:0] mem_rd_i,
    input wire [                31:0] mem_addr_i,
    input wire [                63:0] mem_wdata_i,      // 升级到64位数据
    input wire [                 7:0] mem_wmask_i,      // 升级到8位掩码
    input wire [`COMMIT_ID_WIDTH-1:0] mem_commit_id_i,
    input wire                        mem_wb_ready_i,

    // CSR接口 (双路输入)
    input wire                        req_csr_0_i,
    input wire [                31:0] csr_op1_0_i,
    input wire [                31:0] csr_addr_0_i,
    input wire                        csr_csrrw_0_i,
    input wire                        csr_csrrs_0_i,
    input wire                        csr_csrrc_0_i,
    input wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_0_i,
    input wire                        csr_we_0_i,
    input wire                        csr_reg_we_0_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_0_i,
    input wire [ `REG_ADDR_WIDTH-1:0] csr_reg_waddr_0_i,

    input wire                        req_csr_1_i,
    input wire [                31:0] csr_op1_1_i,
    input wire [                31:0] csr_addr_1_i,
    input wire                        csr_csrrw_1_i,
    input wire                        csr_csrrs_1_i,
    input wire                        csr_csrrc_1_i,
    input wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_1_i,
    input wire                        csr_we_1_i,
    input wire                        csr_reg_we_1_i,
    input wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_1_i,
    input wire [ `REG_ADDR_WIDTH-1:0] csr_reg_waddr_1_i,

    input wire [`REG_DATA_WIDTH-1:0] csr_rdata_i,
    input wire                       csr_wb_ready_i,

    // 系统操作信号
    input wire sys_op_nop_i,
    input wire sys_op_mret_i,
    input wire sys_op_ecall_i,
    input wire sys_op_ebreak_i,
    input wire sys_op_fence_i,
    input wire sys_op_dret_i,

    // 输出信号 - 到WBU的写回接口
    // ALU0写回
    output wire [ `REG_DATA_WIDTH-1:0] alu0_reg_wdata_o,
    output wire                        alu0_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] alu0_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] alu0_commit_id_o,

    // ALU1写回
    output wire [ `REG_DATA_WIDTH-1:0] alu1_reg_wdata_o,
    output wire                        alu1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] alu1_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] alu1_commit_id_o,

    // 乘法器写回
    output wire [ `REG_DATA_WIDTH-1:0] mul0_reg_wdata_o,
    output wire                        mul0_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] mul0_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] mul0_commit_id_o,

    output wire [ `REG_DATA_WIDTH-1:0] mul1_reg_wdata_o,
    output wire                        mul1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] mul1_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] mul1_commit_id_o,

    // 除法器写回
    output wire [ `REG_DATA_WIDTH-1:0] div0_reg_wdata_o,
    output wire                        div0_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] div0_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] div0_commit_id_o,

    output wire [ `REG_DATA_WIDTH-1:0] div1_reg_wdata_o,
    output wire                        div1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] div1_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] div1_commit_id_o,

    // LSU写回
    output wire [ `REG_DATA_WIDTH-1:0] lsu_reg_wdata_o,
    output wire                        lsu_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_o,

    // CSR写回 (单一路)
    output wire [ `REG_DATA_WIDTH-1:0] csr_reg_wdata_o,
    output wire [ `REG_ADDR_WIDTH-1:0] csr_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_o,
    output wire                        csr_reg_we_o,

    // CSR寄存器写数据输出 (单一路)
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_raddr_o,  // CSR读地址输出

    // 控制输出
    output wire [1:0]                  stall_flag_o,
    output wire                        jump_flag_o,
    output wire [`INST_ADDR_WIDTH-1:0] jump_addr_o,

    // 访存繁忙信号
    output wire mem_store_busy_o,
    output wire exu_lsu_stall_o,

    // 系统操作信号输出
    output wire exu_op_ecall_o,
    output wire exu_op_ebreak_o,
    output wire exu_op_mret_o,

    // misaligned_fetch信号输出
    output wire misaligned_fetch_o,
    // 预测分支跳转信号输出
    output wire                        bru_pred_taken_o,

    // 统一AXI接口 - 64位LSU
    output wire [  `BUS_ID_WIDTH-1:0] M_AXI_AWID,
    output wire [`BUS_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output wire [                7:0] M_AXI_AWLEN,
    output wire [                2:0] M_AXI_AWSIZE,
    output wire [                1:0] M_AXI_AWBURST,
    output wire                       M_AXI_AWLOCK,
    output wire [                3:0] M_AXI_AWCACHE,
    output wire [                2:0] M_AXI_AWPROT,
    output wire [                3:0] M_AXI_AWQOS,
    output wire [                0:0] M_AXI_AWUSER,
    output wire                       M_AXI_AWVALID,
    input  wire                       M_AXI_AWREADY,

    output wire [    `BUS_DATA_WIDTH-1:0] M_AXI_WDATA,
    output wire [(`BUS_DATA_WIDTH/8)-1:0] M_AXI_WSTRB,
    output wire                           M_AXI_WLAST,
    output wire [                    0:0] M_AXI_WUSER,
    output wire                           M_AXI_WVALID,
    input  wire                           M_AXI_WREADY,

    input  wire [`BUS_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [              1:0] M_AXI_BRESP,
    input  wire [              0:0] M_AXI_BUSER,
    input  wire                     M_AXI_BVALID,
    output wire                     M_AXI_BREADY,

    output wire [  `BUS_ID_WIDTH-1:0] M_AXI_ARID,
    output wire [`BUS_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                7:0] M_AXI_ARLEN,
    output wire [                2:0] M_AXI_ARSIZE,
    output wire [                1:0] M_AXI_ARBURST,
    output wire                       M_AXI_ARLOCK,
    output wire [                3:0] M_AXI_ARCACHE,
    output wire [                2:0] M_AXI_ARPROT,
    output wire [                3:0] M_AXI_ARQOS,
    output wire [                0:0] M_AXI_ARUSER,
    output wire                       M_AXI_ARVALID,
    input  wire                       M_AXI_ARREADY,

    input  wire [  `BUS_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [`BUS_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                1:0] M_AXI_RRESP,
    input  wire                       M_AXI_RLAST,
    input  wire [                0:0] M_AXI_RUSER,
    input  wire                       M_AXI_RVALID,
    output wire                       M_AXI_RREADY
);

    // 内部连线定义 (已去除csr1)
    wire alu0_stall, alu1_stall;
    wire mul0_stall, mul1_stall;
    wire div0_stall, div1_stall;
    wire                        lsu_stall;  // 统一LSU stall信号
    wire                        csr_stall;

    // 新增ALU旁路内部连线
    wire [ `REG_DATA_WIDTH-1:0] alu0_result_bypass;
    wire [ `REG_DATA_WIDTH-1:0] alu1_result_bypass;

    // 分支单元信号
    wire                        bru_jump_flag;
    wire [`INST_ADDR_WIDTH-1:0] bru_jump_addr;
    wire                        misaligned_fetch_bru;

    // ALU0实例
    exu_alu u_alu0 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .req_alu_i              (req_alu0_i),
        .alu_op1_i              (alu0_op1_i),
        .alu_op2_i              (alu0_op2_i),
        .alu_op_info_i          (alu0_op_info_i),
        .alu_rd_i               (alu0_rd_i),
        .commit_id_i            (alu0_commit_id_i),
        .reg_we_i               (alu0_reg_we_i),
        .wb_ready_i             (alu0_wb_ready_i),
        .alu_stall_o            (alu0_stall),
        .int_assert_i           (int_assert_i),
        .result_o               (alu0_reg_wdata_o),
        .reg_we_o               (alu0_reg_we_o),
        .reg_waddr_o            (alu0_reg_waddr_o),
        .commit_id_o            (alu0_commit_id_o),
        .alu_result_bypass_o    (alu0_result_bypass),
        // 旁路相关
        .ext_alu_result_bypass_i(alu1_result_bypass),
        .ext_alu_pass_op1_i     (alu0_pass_alu1_op1_i),
        .ext_alu_pass_op2_i     (alu0_pass_alu1_op2_i),
        .alu_pass_op1_i         (alu0_pass_alu0_op1_i),
        .alu_pass_op2_i         (alu0_pass_alu0_op2_i)
    );

    // ALU1实例
    exu_alu u_alu1 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .req_alu_i              (req_alu1_i),
        .alu_op1_i              (alu1_op1_i),
        .alu_op2_i              (alu1_op2_i),
        .alu_op_info_i          (alu1_op_info_i),
        .alu_rd_i               (alu1_rd_i),
        .commit_id_i            (alu1_commit_id_i),
        .reg_we_i               (alu1_reg_we_i),
        .wb_ready_i             (alu1_wb_ready_i),
        .alu_stall_o            (alu1_stall),
        .int_assert_i           (int_assert_i),
        .result_o               (alu1_reg_wdata_o),
        .reg_we_o               (alu1_reg_we_o),
        .reg_waddr_o            (alu1_reg_waddr_o),
        .commit_id_o            (alu1_commit_id_o),
        .alu_result_bypass_o    (alu1_result_bypass),
        // 旁路相关
        .ext_alu_result_bypass_i(alu0_result_bypass),
        .ext_alu_pass_op1_i     (alu1_pass_alu0_op1_i),
        .ext_alu_pass_op2_i     (alu1_pass_alu0_op2_i),
        .alu_pass_op1_i         (alu1_pass_alu1_op1_i),
        .alu_pass_op2_i         (alu1_pass_alu1_op2_i)
    );

    // ================= 新乘法单元实例化 =================
    exu_mul u_exu_mul0 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .wb_ready            (mul0_wb_ready_i),
        .reg_waddr_i         (mul0_reg_waddr_i),
        .reg1_rdata_i        (mul0_op1_i),
        .reg2_rdata_i        (mul0_op2_i),
        .commit_id_i         (mul0_commit_id_i),
        .req_mul_i           (req_mul0_i),
        .mul_op_mul_i        (mul0_op_mul_i),
        .mul_op_mulh_i       (mul0_op_mulh_i),
        .mul_op_mulhsu_i     (mul0_op_mulhsu_i),
        .mul_op_mulhu_i      (mul0_op_mulhu_i),
        .int_assert_i        (int_assert_i),
        .mul_stall_flag_o    (mul0_stall),
        .reg_wdata_o         (mul0_reg_wdata_o),
        .reg_we_o            (mul0_reg_we_o),
        .reg_waddr_o         (mul0_reg_waddr_o),
        .commit_id_o         (mul0_commit_id_o),
        // 新增旁路信号
        .alu1_result_bypass_i(alu0_result_bypass),
        .alu2_result_bypass_i(alu1_result_bypass),
        .mul_pass_alu1_op1_i (mul0_pass_alu0_op1_i),
        .mul_pass_alu1_op2_i (mul0_pass_alu0_op2_i),
        .mul_pass_alu2_op1_i (mul0_pass_alu1_op1_i),
        .mul_pass_alu2_op2_i (mul0_pass_alu1_op2_i)
    );

    exu_mul u_exu_mul1 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .wb_ready            (mul1_wb_ready_i),
        .reg_waddr_i         (mul1_reg_waddr_i),
        .reg1_rdata_i        (mul1_op1_i),
        .reg2_rdata_i        (mul1_op2_i),
        .commit_id_i         (mul1_commit_id_i),
        .req_mul_i           (req_mul1_i),
        .mul_op_mul_i        (mul1_op_mul_i),
        .mul_op_mulh_i       (mul1_op_mulh_i),
        .mul_op_mulhsu_i     (mul1_op_mulhsu_i),
        .mul_op_mulhu_i      (mul1_op_mulhu_i),
        .int_assert_i        (int_assert_i),
        .mul_stall_flag_o    (mul1_stall),
        .reg_wdata_o         (mul1_reg_wdata_o),
        .reg_we_o            (mul1_reg_we_o),
        .reg_waddr_o         (mul1_reg_waddr_o),
        .commit_id_o         (mul1_commit_id_o),
        // 新增旁路信号
        .alu1_result_bypass_i(alu0_result_bypass),
        .alu2_result_bypass_i(alu1_result_bypass),
        .mul_pass_alu1_op1_i (mul1_pass_alu0_op1_i),
        .mul_pass_alu1_op2_i (mul1_pass_alu0_op2_i),
        .mul_pass_alu2_op1_i (mul1_pass_alu1_op1_i),
        .mul_pass_alu2_op2_i (mul1_pass_alu1_op2_i)
    );

    // ================= 新除法单元实例化 =================
    exu_div u_exu_div0 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .wb_ready            (div0_wb_ready_i),
        .reg_waddr_i         (div0_reg_waddr_i),
        .reg1_rdata_i        (div0_op1_i),
        .reg2_rdata_i        (div0_op2_i),
        .commit_id_i         (div0_commit_id_i),
        .req_div_i           (req_div0_i),
        .div_op_div_i        (div0_op_div_i),
        .div_op_divu_i       (div0_op_divu_i),
        .div_op_rem_i        (div0_op_rem_i),
        .div_op_remu_i       (div0_op_remu_i),
        .int_assert_i        (int_assert_i),
        .div_stall_flag_o    (div0_stall),
        .reg_wdata_o         (div0_reg_wdata_o),
        .reg_we_o            (div0_reg_we_o),
        .reg_waddr_o         (div0_reg_waddr_o),
        .commit_id_o         (div0_commit_id_o),
        // 新增旁路信号
        .alu1_result_bypass_i(alu0_result_bypass),
        .alu2_result_bypass_i(alu1_result_bypass),
        .div_pass_alu1_op1_i (div0_pass_alu0_op1_i),
        .div_pass_alu1_op2_i (div0_pass_alu0_op2_i),
        .div_pass_alu2_op1_i (div0_pass_alu1_op1_i),
        .div_pass_alu2_op2_i (div0_pass_alu1_op2_i)
    );

    exu_div u_exu_div1 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .wb_ready            (div1_wb_ready_i),
        .reg_waddr_i         (div1_reg_waddr_i),
        .reg1_rdata_i        (div1_op1_i),
        .reg2_rdata_i        (div1_op2_i),
        .commit_id_i         (div1_commit_id_i),
        .req_div_i           (req_div1_i),
        .div_op_div_i        (div1_op_div_i),
        .div_op_divu_i       (div1_op_divu_i),
        .div_op_rem_i        (div1_op_rem_i),
        .div_op_remu_i       (div1_op_remu_i),
        .int_assert_i        (int_assert_i),
        .div_stall_flag_o    (div1_stall),
        .reg_wdata_o         (div1_reg_wdata_o),
        .reg_we_o            (div1_reg_we_o),
        .reg_waddr_o         (div1_reg_waddr_o),
        .commit_id_o         (div1_commit_id_o),
        // 新增旁路信号
        .alu1_result_bypass_i(alu0_result_bypass),
        .alu2_result_bypass_i(alu1_result_bypass),
        .div_pass_alu1_op1_i (div1_pass_alu0_op1_i),
        .div_pass_alu1_op2_i (div1_pass_alu0_op2_i),
        .div_pass_alu2_op1_i (div1_pass_alu1_op1_i),
        .div_pass_alu2_op2_i (div1_pass_alu1_op2_i)
    );

    // 分支单元实例
    exu_bru u_bru (
        .rst_n             (rst_n),
        .req_bjp_i         (req_bjp_i),
        .bjp_op1_i         (bjp_op1_i),
        .bjp_op2_i         (bjp_op2_i),
        .bjp_jump_op1_i    (bjp_jump_op1_i),
        .bjp_jump_op2_i    (bjp_jump_op2_i),
        .bjp_op_jal_i      (bjp_op_jal_i),
        .bjp_op_beq_i      (bjp_op_beq_i),
        .bjp_op_bne_i      (bjp_op_bne_i),
        .bjp_op_blt_i      (bjp_op_blt_i),
        .bjp_op_bltu_i     (bjp_op_bltu_i),
        .bjp_op_bge_i      (bjp_op_bge_i),
        .bjp_op_bgeu_i     (bjp_op_bgeu_i),
        .bjp_op_jalr_i     (bjp_op_jalr_i),
        .is_pred_branch_i  (is_pred_branch_i),
        .sys_op_fence_i    (sys_op_fence_i),
        .int_assert_i      (int_assert_i),
        .int_addr_i        (int_addr_i),
        .jump_flag_o       (bru_jump_flag),
        .jump_addr_o       (bru_jump_addr),
        .pred_taken_o      (bru_pred_taken_o),
        .misaligned_fetch_o(misaligned_fetch_bru)
    );

    // 单个LSU实例
    exu_lsu u_lsu (
        .clk         (clk),
        .rst_n       (rst_n),
        .int_assert_i(int_assert_i),

        // 单个LSU接口
        .req_mem_i     (req_mem_i),
        .mem_op_lb_i   (mem_op_lb_i),
        .mem_op_lh_i   (mem_op_lh_i),
        .mem_op_lw_i   (mem_op_lw_i),
        .mem_op_lbu_i  (mem_op_lbu_i),
        .mem_op_lhu_i  (mem_op_lhu_i),
        .mem_op_load_i (mem_op_load_i),
        .mem_op_store_i(mem_op_store_i),
        .rd_addr_i     (mem_rd_i),
        .mem_addr_i    (mem_addr_i),
        .mem_wdata_i   (mem_wdata_i),
        .mem_wmask_i   (mem_wmask_i),
        .commit_id_i   (mem_commit_id_i),

        // 输出信号
        .mem_stall_o(lsu_stall),
        .mem_busy_o (mem_store_busy_o),  
        .reg_wdata_o(lsu_reg_wdata_o),
        .reg_we_o   (lsu_reg_we_o),
        .reg_waddr_o(lsu_reg_waddr_o),
        .commit_id_o(lsu_commit_id_o),

        // 统一AXI接口连接
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

    // ===================== CSR实例 (支持双路输入) =====================
    exu_csr_unit u_csr (
        .clk         (clk),
        .rst_n       (rst_n),
        .int_assert_i(int_assert_i),
        .pc_i        (inst_addr_i),

        // 第一路CSR输入
        .req_csr_0_i   (req_csr_0_i),
        .csr_op1_0_i   (csr_op1_0_i),
        .csr_addr_0_i  (csr_addr_0_i),
        .csr_csrrw_0_i (csr_csrrw_0_i),
        .csr_csrrs_0_i (csr_csrrs_0_i),
        .csr_csrrc_0_i (csr_csrrc_0_i),
        .commit_id_0_i (csr_commit_id_0_i),
        .csr_we_0_i    (csr_we_0_i),
        .csr_reg_we_0_i(csr_reg_we_0_i),
        .csr_waddr_0_i (csr_waddr_0_i),
        .reg_waddr_0_i (csr_reg_waddr_0_i),

        // 第二路CSR输入
        .req_csr_1_i   (req_csr_1_i),
        .csr_op1_1_i   (csr_op1_1_i),
        .csr_addr_1_i  (csr_addr_1_i),
        .csr_csrrw_1_i (csr_csrrw_1_i),
        .csr_csrrs_1_i (csr_csrrs_1_i),
        .csr_csrrc_1_i (csr_csrrc_1_i),
        .commit_id_1_i (csr_commit_id_1_i),
        .csr_we_1_i    (csr_we_1_i),
        .csr_reg_we_1_i(csr_reg_we_1_i),
        .csr_waddr_1_i (csr_waddr_1_i),
        .reg_waddr_1_i (csr_reg_waddr_1_i),

        .csr_rdata_i(csr_rdata_i),
        .wb_ready_i (csr_wb_ready_i),

        // 输出信号
        .csr_raddr_o (csr_raddr_o),
        .csr_wdata_o (csr_wdata_o),
        .csr_we_o    (csr_we_o),
        .csr_waddr_o (csr_waddr_o),
        .reg_wdata_o (csr_reg_wdata_o),
        .reg_waddr_o (csr_reg_waddr_o),
        .commit_id_o (csr_commit_id_o),
        .csr_reg_we_o(csr_reg_we_o),
        .csr_stall_o (csr_stall)
    );

    // 控制信号汇总 (统一LSU stall信号)
    assign stall_flag_o[0] = alu0_stall | mul0_stall | div0_stall | (req_csr_0_i & csr_stall);

    assign stall_flag_o[1] = alu1_stall | mul1_stall | div1_stall | (req_csr_1_i & csr_stall);

    assign exu_lsu_stall_o = lsu_stall;

    assign jump_flag_o = bru_jump_flag || int_jump_i;
    assign jump_addr_o = int_jump_i ? int_addr_i : bru_jump_addr;

    // 系统操作信号输出
    assign exu_op_ecall_o = sys_op_ecall_i;
    assign exu_op_ebreak_o = sys_op_ebreak_i;
    assign exu_op_mret_o = sys_op_mret_i;

    // misaligned_fetch信号输出
    assign misaligned_fetch_o = misaligned_fetch_bru;

endmodule
