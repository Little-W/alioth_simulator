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

//指令发射控制单元
module icu_issue (
    input wire clk,
    input wire rst_n,

    // from idu
    input wire [`INST_ADDR_WIDTH-1:0] inst1_addr_i,
    input wire                        inst1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_i,
    input wire                        inst1_csr_we_i,
    input wire [ 31:0] inst1_csr_waddr_i,
    input wire [ 31:0] inst1_csr_raddr_i,
    input wire [                31:0] inst1_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_i,
    input wire                        inst1_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst1_i,             // 新增：指令1内容输出

    // from idu - 第二路
    input wire [`INST_ADDR_WIDTH-1:0] inst2_addr_i,
    input wire                        inst2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_i,
    input wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_i,
    input wire                        inst2_csr_we_i,
    input wire [ 31:0] inst2_csr_waddr_i,
    input wire [ 31:0] inst2_csr_raddr_i,
    input wire [                31:0] inst2_dec_imm_i,
    input wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_i,
    input wire                        inst2_is_pred_branch_i,
    input wire [`INST_DATA_WIDTH-1:0] inst2_i,             // 新增：指令2内容输出

    // from hdu 控制信号
    input wire [1:0]                  issue_inst_i,
    
    // 新增：流水线寄存器相关输入
    input wire [`COMMIT_ID_WIDTH-1:0] hdu_inst1_commit_id_i,
    input wire [`COMMIT_ID_WIDTH-1:0] hdu_inst2_commit_id_i,
    
    // from control 控制信号
    input wire [`CU_BUS_WIDTH-1:0]   stall_flag_i,

    input wire                        inst1_illegal_inst_i,
    input wire                        inst2_illegal_inst_i,
    
    // 发射指令的完整decode信息
    output wire [`INST_ADDR_WIDTH-1:0] inst1_addr_o,
    output wire                        inst1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst1_reg2_raddr_o,
    output wire [ 31:0] inst1_csr_waddr_o,
    output wire [ 31:0] inst1_csr_raddr_o,
    output wire                        inst1_csr_we_o,
    output wire [                31:0] inst1_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst1_dec_info_bus_o,
    output wire                        inst1_is_pred_branch_o,
    output wire [`INST_DATA_WIDTH-1:0] inst1_o,             // 新增：指令1内容输出
    
    output wire [`INST_ADDR_WIDTH-1:0] inst2_addr_o,
    output wire                        inst2_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg_waddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg1_raddr_o,
    output wire [ `REG_ADDR_WIDTH-1:0] inst2_reg2_raddr_o,
    output wire [ 31:0] inst2_csr_waddr_o,
    output wire [ 31:0] inst2_csr_raddr_o,
    output wire                        inst2_csr_we_o,
    output wire [                31:0] inst2_dec_imm_o,
    output wire [  `DECINFO_WIDTH-1:0] inst2_dec_info_bus_o,
    output wire                        inst2_is_pred_branch_o,
    output wire [`INST_DATA_WIDTH-1:0] inst2_o,             // 新增：指令2内容输出

    // 新增：流水线寄存器相关输出
    output wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_o,
    output wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_o,
    output wire        inst1_illegal_inst_o,
    output wire        inst2_illegal_inst_o,
    output wire        inst1_valid_o,
    output wire        inst2_valid_o
);

        // 控制信号解析
    wire other_flush_en = stall_flag_i[`CU_FLUSH];
    
    // 静态变量，记录上一周期的指令信息，用于检测指令是否发生变化
    reg [`INST_ADDR_WIDTH-1:0] prev_inst1_addr = {`INST_ADDR_WIDTH{1'b0}};
    reg [`INST_ADDR_WIDTH-1:0] prev_inst2_addr = {`INST_ADDR_WIDTH{1'b0}};
    reg prev_inst1_issued = 1'b0;
    reg prev_inst2_issued = 1'b0;
    
    // 检测指令是否与上一周期相同
    wire inst1_same_as_prev = (prev_inst1_addr == inst1_addr_i) && (inst1_addr_i != {`INST_ADDR_WIDTH{1'b0}});
    wire inst2_same_as_prev = (prev_inst2_addr == inst2_addr_i) && (inst2_addr_i != {`INST_ADDR_WIDTH{1'b0}});
    
    // 更新历史记录
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            prev_inst1_addr <= {`INST_ADDR_WIDTH{1'b0}};
            prev_inst2_addr <= {`INST_ADDR_WIDTH{1'b0}};
            prev_inst1_issued <= 1'b0;
            prev_inst2_issued <= 1'b0;
        end else if (other_flush_en) begin
            // 当发生flush时，清除历史记录
            prev_inst1_addr <= {`INST_ADDR_WIDTH{1'b0}};
            prev_inst2_addr <= {`INST_ADDR_WIDTH{1'b0}};
            prev_inst1_issued <= 1'b0;
            prev_inst2_issued <= 1'b0;
        end else if (~stall_flag_i[`CU_STALL_DISPATCH]) begin
            // 记录本周期的指令信息和发射状态
            prev_inst1_addr <= inst1_addr_i;
            prev_inst2_addr <= inst2_addr_i;
            prev_inst1_issued <= issue_inst_i[0];
            prev_inst2_issued <= issue_inst_i[1];
        end
    end
    
    // 发射控制逻辑：
    // 1. 如果指令与上一周期相同且上一周期已经发射过，则不再发射（防止重复发射）
    // 2. 如果指令与上一周期不同，则可以正常发射（新指令）
    // 3. 如果当前不要求发射，则清零输出
    wire flush_en_1 = other_flush_en || (~issue_inst_i[0]) || (inst1_same_as_prev && prev_inst1_issued);
    wire flush_en_2 = other_flush_en || (~issue_inst_i[1]) || (inst2_same_as_prev && prev_inst2_issued);
    
    wire other_stall_en = stall_flag_i[`CU_STALL_DISPATCH];
    wire update_output = ~other_stall_en; 

    // 下一个时钟周期的指令信号 - flush时清零，否则等于输入
    wire [`INST_ADDR_WIDTH-1:0] nxt_inst1_addr = flush_en_1 ? {`INST_ADDR_WIDTH{1'b0}} : inst1_addr_i;
    wire                        nxt_inst1_reg_we = flush_en_1 ? 1'b0 : inst1_reg_we_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst1_reg_waddr = flush_en_1 ? {`REG_ADDR_WIDTH{1'b0}} : inst1_reg_waddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst1_reg1_raddr = flush_en_1 ? {`REG_ADDR_WIDTH{1'b0}} : inst1_reg1_raddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst1_reg2_raddr = flush_en_1 ? {`REG_ADDR_WIDTH{1'b0}} : inst1_reg2_raddr_i;
    wire [ 31:0] nxt_inst1_csr_waddr = flush_en_1 ? {`BUS_ADDR_WIDTH{1'b0}} : inst1_csr_waddr_i;
    wire [ 31:0] nxt_inst1_csr_raddr = flush_en_1 ? {`BUS_ADDR_WIDTH{1'b0}} : inst1_csr_raddr_i;
    wire                        nxt_inst1_csr_we = flush_en_1 ? 1'b0 : inst1_csr_we_i;
    wire [                31:0] nxt_inst1_dec_imm = flush_en_1 ? 32'b0 : inst1_dec_imm_i;
    wire [  `DECINFO_WIDTH-1:0] nxt_inst1_dec_info_bus = flush_en_1 ? {`DECINFO_WIDTH{1'b0}} : inst1_dec_info_bus_i;
    wire                        nxt_inst1_is_pred_branch = flush_en_1 ? 1'b0 : inst1_is_pred_branch_i;
    wire [`INST_DATA_WIDTH-1:0] nxt_inst1 = flush_en_1 ? {`INST_DATA_WIDTH{1'b0}} : inst1_i;

    wire [`INST_ADDR_WIDTH-1:0] nxt_inst2_addr = flush_en_2 ? {`INST_ADDR_WIDTH{1'b0}} : inst2_addr_i;
    wire                        nxt_inst2_reg_we = flush_en_2 ? 1'b0 : inst2_reg_we_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst2_reg_waddr = flush_en_2 ? {`REG_ADDR_WIDTH{1'b0}} : inst2_reg_waddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst2_reg1_raddr = flush_en_2 ? {`REG_ADDR_WIDTH{1'b0}} : inst2_reg1_raddr_i;
    wire [ `REG_ADDR_WIDTH-1:0] nxt_inst2_reg2_raddr = flush_en_2 ? {`REG_ADDR_WIDTH{1'b0}} : inst2_reg2_raddr_i;
    wire [ 31:0] nxt_inst2_csr_waddr = flush_en_2 ? {`BUS_ADDR_WIDTH{1'b0}} : inst2_csr_waddr_i;
    wire [ 31:0] nxt_inst2_csr_raddr = flush_en_2 ? {`BUS_ADDR_WIDTH{1'b0}} : inst2_csr_raddr_i;
    wire                        nxt_inst2_csr_we = flush_en_2 ? 1'b0 : inst2_csr_we_i;
    wire [                31:0] nxt_inst2_dec_imm = flush_en_2 ? 32'b0 : inst2_dec_imm_i;
    wire [  `DECINFO_WIDTH-1:0] nxt_inst2_dec_info_bus = flush_en_2 ? {`DECINFO_WIDTH{1'b0}} : inst2_dec_info_bus_i;
    wire                        nxt_inst2_is_pred_branch = flush_en_2 ? 1'b0 : inst2_is_pred_branch_i;
    wire [`INST_DATA_WIDTH-1:0] nxt_inst2 = flush_en_2 ? {`INST_DATA_WIDTH{1'b0}} : inst2_i;
    

    // 指令1地址寄存器
    wire [`INST_ADDR_WIDTH-1:0] inst1_addr;
    gnrl_dfflr #(`INST_ADDR_WIDTH) inst1_addr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_addr,
        inst1_addr
    );
    assign inst1_addr_o = inst1_addr;

    // 指令1寄存器写使能寄存器
    wire inst1_reg_we;
    gnrl_dfflr #(1) inst1_reg_we_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_reg_we,
        inst1_reg_we
    );
    assign inst1_reg_we_o = inst1_reg_we;

    // 指令1寄存器写地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst1_reg_waddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst1_reg_waddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_reg_waddr,
        inst1_reg_waddr
    );
    assign inst1_reg_waddr_o = inst1_reg_waddr;

    // 指令1寄存器1读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst1_reg1_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst1_reg1_raddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_reg1_raddr,
        inst1_reg1_raddr
    );
    assign inst1_reg1_raddr_o = inst1_reg1_raddr;

    // 指令1寄存器2读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst1_reg2_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst1_reg2_raddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_reg2_raddr,
        inst1_reg2_raddr
    );
    assign inst1_reg2_raddr_o = inst1_reg2_raddr;

    // 指令1 CSR写地址寄存器
    wire [31:0] inst1_csr_waddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst1_csr_waddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_csr_waddr,
        inst1_csr_waddr
    );
    assign inst1_csr_waddr_o = inst1_csr_waddr;

    // 指令1 CSR读地址寄存器
    wire [31:0] inst1_csr_raddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst1_csr_raddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_csr_raddr,
        inst1_csr_raddr
    );
    assign inst1_csr_raddr_o = inst1_csr_raddr;

    // 指令1 CSR写使能寄存器
    wire inst1_csr_we;
    gnrl_dfflr #(1) inst1_csr_we_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_csr_we,
        inst1_csr_we
    );
    assign inst1_csr_we_o = inst1_csr_we;

    // 指令1立即数寄存器
    wire [31:0] inst1_dec_imm;
    gnrl_dfflr #(32) inst1_dec_imm_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_dec_imm,
        inst1_dec_imm
    );
    assign inst1_dec_imm_o = inst1_dec_imm;

    // 指令1译码信息总线寄存器
    wire [`DECINFO_WIDTH-1:0] inst1_dec_info_bus;
    gnrl_dfflr #(`DECINFO_WIDTH) inst1_dec_info_bus_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_dec_info_bus,
        inst1_dec_info_bus
    );
    assign inst1_dec_info_bus_o = inst1_dec_info_bus;

    // 指令1预测分支寄存器
    wire inst1_is_pred_branch;
    gnrl_dfflr #(1) inst1_is_pred_branch_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1_is_pred_branch,
        inst1_is_pred_branch
    );
    assign inst1_is_pred_branch_o = inst1_is_pred_branch;

    wire [`INST_DATA_WIDTH-1:0] inst1;
    gnrl_dfflr #(`INST_DATA_WIDTH) inst1_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst1,
        inst1
    );
    assign inst1_o = inst1; // 新增：指令1内容输出

    // 指令2地址寄存器
    wire [`INST_ADDR_WIDTH-1:0] inst2_addr;
    gnrl_dfflr #(`INST_ADDR_WIDTH) inst2_addr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_addr,
        inst2_addr
    );
    assign inst2_addr_o = inst2_addr;

    // 指令2寄存器写使能寄存器
    wire inst2_reg_we;
    gnrl_dfflr #(1) inst2_reg_we_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_reg_we,
        inst2_reg_we
    );
    assign inst2_reg_we_o = inst2_reg_we;

    // 指令2寄存器写地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst2_reg_waddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst2_reg_waddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_reg_waddr,
        inst2_reg_waddr
    );
    assign inst2_reg_waddr_o = inst2_reg_waddr;

    // 指令2寄存器1读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst2_reg1_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst2_reg1_raddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_reg1_raddr,
        inst2_reg1_raddr
    );
    assign inst2_reg1_raddr_o = inst2_reg1_raddr;

    // 指令2寄存器2读地址寄存器
    wire [`REG_ADDR_WIDTH-1:0] inst2_reg2_raddr;
    gnrl_dfflr #(`REG_ADDR_WIDTH) inst2_reg2_raddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_reg2_raddr,
        inst2_reg2_raddr
    );
    assign inst2_reg2_raddr_o = inst2_reg2_raddr;

    // 指令2 CSR写地址寄存器
    wire [31:0] inst2_csr_waddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst2_csr_waddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_csr_waddr,
        inst2_csr_waddr
    );
    assign inst2_csr_waddr_o = inst2_csr_waddr;

    // 指令2 CSR读地址寄存器
    wire [31:0] inst2_csr_raddr;
    gnrl_dfflr #(`BUS_ADDR_WIDTH) inst2_csr_raddr_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_csr_raddr,
        inst2_csr_raddr
    );
    assign inst2_csr_raddr_o = inst2_csr_raddr;

    // 指令2 CSR写使能寄存器
    wire inst2_csr_we;
    gnrl_dfflr #(1) inst2_csr_we_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_csr_we,
        inst2_csr_we
    );
    assign inst2_csr_we_o = inst2_csr_we;

    // 指令2立即数寄存器
    wire [31:0] inst2_dec_imm;
    gnrl_dfflr #(32) inst2_dec_imm_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_dec_imm,
        inst2_dec_imm
    );
    assign inst2_dec_imm_o = inst2_dec_imm;

    // 指令2译码信息总线寄存器
    wire [`DECINFO_WIDTH-1:0] inst2_dec_info_bus;
    gnrl_dfflr #(`DECINFO_WIDTH) inst2_dec_info_bus_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_dec_info_bus,
        inst2_dec_info_bus
    );
    assign inst2_dec_info_bus_o = inst2_dec_info_bus;

    // 指令2预测分支寄存器
    wire inst2_is_pred_branch;
    gnrl_dfflr #(1) inst2_is_pred_branch_ff (
        clk,
        rst_n,
        update_output,
        nxt_inst2_is_pred_branch,
        inst2_is_pred_branch
    );
    assign inst2_is_pred_branch_o = inst2_is_pred_branch;

    wire [`INST_DATA_WIDTH-1:0] inst2;
    gnrl_dfflr #(`INST_DATA_WIDTH) inst2_ff (   
        clk,
        rst_n,
        update_output,
        nxt_inst2,
        inst2
    );
    assign inst2_o = inst2; // 新增：指令2内容输出

    // 流水线寄存器实现

    // commit ID寄存器实现
    wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_nxt = flush_en_1 ? 3'b0 : hdu_inst1_commit_id_i; 
    wire [`COMMIT_ID_WIDTH-1:0] inst1_commit_id_reg;
    gnrl_dfflr #(`COMMIT_ID_WIDTH) inst1_commit_id_ff (
        clk,
        rst_n,
        update_output,
        inst1_commit_id_nxt,
        inst1_commit_id_reg
    );
    assign inst1_commit_id_o = inst1_commit_id_reg;

    wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_nxt = flush_en_2 ? 3'b0 : hdu_inst2_commit_id_i;
    wire [`COMMIT_ID_WIDTH-1:0] inst2_commit_id_reg;
    gnrl_dfflr #(`COMMIT_ID_WIDTH) inst2_commit_id_ff (
        clk,
        rst_n,
        update_output,
        inst2_commit_id_nxt,
        inst2_commit_id_reg
    );
    assign inst2_commit_id_o = inst2_commit_id_reg;

    wire inst1_illegal_inst_nxt = flush_en_1 ? 1'b0 : inst1_illegal_inst_i;
    wire inst1_illegal_inst_reg;
    gnrl_dfflr #(1) inst1_illegal_inst_ff (
        clk,
        rst_n,
        update_output,
        inst1_illegal_inst_nxt,
        inst1_illegal_inst_reg
    );
    assign inst1_illegal_inst_o = inst1_illegal_inst_reg;

    wire inst2_illegal_inst_nxt = flush_en_2 ? 1'b0 : inst2_illegal_inst_i;
    wire inst2_illegal_inst_reg;
    gnrl_dfflr #(1) inst2_illegal_inst_ff (
        clk,
        rst_n,
        update_output,
        inst2_illegal_inst_nxt,
        inst2_illegal_inst_reg
    );
    assign inst2_illegal_inst_o = inst2_illegal_inst_reg;

    wire inst1_valid_nxt = flush_en_1 ? 1'b0 : issue_inst_i[0];
    wire inst1_valid_reg;
    gnrl_dfflr #(1) inst1_valid_ff (
        clk,
        rst_n,
        update_output,
        inst1_valid_nxt,
        inst1_valid_reg
    );
    assign inst1_valid_o = inst1_valid_reg;

    wire inst2_valid_nxt = flush_en_2 ? 1'b0 : issue_inst_i[1];
    wire inst2_valid_reg;
    gnrl_dfflr #(1) inst2_valid_ff (
        clk,
        rst_n,
        update_output,
        inst2_valid_nxt,
        inst2_valid_reg
    );
    assign inst2_valid_o = inst2_valid_reg;

endmodule