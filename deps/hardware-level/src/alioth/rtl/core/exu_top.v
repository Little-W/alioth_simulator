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

`include "defines.v"

// 执行单元顶层模块
module exu(
    input wire clk,
    input wire rst,

    // from id_ex
    input wire[`INST_DATA_WIDTH-1:0] inst_i,
    input wire[`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire reg_we_i,
    input wire[`REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire[`REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire[`REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire csr_we_i,
    input wire[`BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input wire[`REG_DATA_WIDTH-1:0] csr_rdata_i,
    input wire int_assert_i,
    input wire[`INST_ADDR_WIDTH-1:0] int_addr_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op1_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op2_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op1_jump_i,
    input wire[`BUS_ADDR_WIDTH-1:0] op2_jump_i,

    // from mem
    input wire[`BUS_DATA_WIDTH-1:0] mem_rdata_i,

    // to mem
    output wire[`BUS_DATA_WIDTH-1:0] mem_wdata_o,
    output wire[`BUS_ADDR_WIDTH-1:0] mem_raddr_o,
    output wire[`BUS_ADDR_WIDTH-1:0] mem_waddr_o,
    output wire mem_we_o,
    output wire mem_req_o,

    // to regs
    output wire[`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire reg_we_o,
    output wire[`REG_ADDR_WIDTH-1:0] reg_waddr_o,

    // to csr reg
    output wire[`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire csr_we_o,
    output wire[`BUS_ADDR_WIDTH-1:0] csr_waddr_o,

    // to ctrl
    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`INST_ADDR_WIDTH-1:0] jump_addr_o,
    
    // to clint
    output wire div_started_o
);

    // 内部连线定义
    // 除法器信号
    wire div_ready;
    wire[`REG_DATA_WIDTH-1:0] div_result;
    wire div_busy;
    wire[`REG_ADDR_WIDTH-1:0] div_reg_waddr;
    
    wire div_start;
    wire[`REG_DATA_WIDTH-1:0] div_dividend;
    wire[`REG_DATA_WIDTH-1:0] div_divisor;
    wire[2:0] div_op;
    wire[`REG_ADDR_WIDTH-1:0] div_reg_waddr_o;
    
    // 乘法器信号
    wire mul_ready;
    wire[`REG_DATA_WIDTH-1:0] mul_result;
    wire mul_busy;
    wire[`REG_ADDR_WIDTH-1:0] mul_reg_waddr;
    
    wire mul_start;
    wire[`REG_DATA_WIDTH-1:0] mul_multiplicand;
    wire[`REG_DATA_WIDTH-1:0] mul_multiplier;
    wire[2:0] mul_op;
    wire[`REG_ADDR_WIDTH-1:0] mul_reg_waddr_o;
    
    wire[`REG_DATA_WIDTH-1:0] alu_result;
    wire alu_reg_we;
    wire[`REG_ADDR_WIDTH-1:0] alu_reg_waddr;
    
    wire[`REG_DATA_WIDTH-1:0] agu_reg_wdata;
    wire agu_reg_we;
    wire[`REG_ADDR_WIDTH-1:0] agu_reg_waddr;
    
    wire bru_jump_flag;
    wire[`INST_ADDR_WIDTH-1:0] bru_jump_addr;
    
    wire[`REG_DATA_WIDTH-1:0] csr_unit_wdata;
    wire[`REG_DATA_WIDTH-1:0] csr_unit_reg_wdata;
    
    wire muldiv_hold_flag;
    wire muldiv_jump_flag;
    wire[`INST_ADDR_WIDTH-1:0] muldiv_jump_addr;
    wire[`REG_DATA_WIDTH-1:0] muldiv_wdata;
    wire muldiv_we;
    wire[`REG_ADDR_WIDTH-1:0] muldiv_waddr;
    
    // 除法器模块例化
    exu_div u_div(
        .clk(clk),
        .rst(rst),
        .dividend_i(div_dividend),
        .divisor_i(div_divisor),
        .start_i((int_assert_i == `INT_ASSERT)? `DivStop: div_start),
        .op_i(div_op),
        .reg_waddr_i(div_reg_waddr_o),
        .result_o(div_result),
        .ready_o(div_ready),
        .busy_o(div_busy),
        .reg_waddr_o(div_reg_waddr)
    );

    // 乘法器模块例化
    exu_mul u_mul(
        .clk(clk),
        .rst(rst),
        .multiplicand_i(mul_multiplicand),
        .multiplier_i(mul_multiplier),
        .start_i((int_assert_i == `INT_ASSERT)? 1'b0: mul_start),
        .op_i(mul_op),
        .reg_waddr_i(mul_reg_waddr_o),
        .result_o(mul_result),
        .ready_o(mul_ready),
        .busy_o(mul_busy),
        .reg_waddr_o(mul_reg_waddr)
    );

    // 地址生成单元模块例化
    agu u_agu(
        .rst(rst),
        .inst_i(inst_i),
        .op1_i(op1_i),
        .op2_i(op2_i),
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),
        .mem_rdata_i(mem_rdata_i),
        .int_assert_i(int_assert_i),
        
        .mem_wdata_o(mem_wdata_o),
        .mem_raddr_o(mem_raddr_o),
        .mem_waddr_o(mem_waddr_o),
        .mem_we_o(mem_we_o),
        .mem_req_o(mem_req_o),
        .reg_wdata_o(agu_reg_wdata),
        .reg_we_o(agu_reg_we),
        .reg_waddr_o(agu_reg_waddr)
    );
    
    // 算术逻辑单元模块例化
    exu_alu u_alu(
        .rst(rst),
        .inst_i(inst_i),
        .op1_i(op1_i),
        .op2_i(op2_i),
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),
        .int_assert_i(int_assert_i),
        
        .result_o(alu_result),
        .reg_we_o(alu_reg_we),
        .reg_waddr_o(alu_reg_waddr)
    );
    
    // 分支单元模块例化
    exu_bru u_bru(
        .rst(rst),
        .inst_i(inst_i),
        .inst_addr_i(inst_addr_i),
        .op1_i(op1_i),
        .op2_i(op2_i),
        .op1_jump_i(op1_jump_i),
        .op2_jump_i(op2_jump_i),
        .int_assert_i(int_assert_i),
        .int_addr_i(int_addr_i),
        
        .jump_flag_o(bru_jump_flag),
        .jump_addr_o(bru_jump_addr)
    );
    
    // CSR处理单元模块例化
    exu_csr_unit u_csr_unit(
        .rst(rst),
        .inst_i(inst_i),
        .reg1_rdata_i(reg1_rdata_i),
        .csr_rdata_i(csr_rdata_i),
        .int_assert_i(int_assert_i),
        
        .csr_wdata_o(csr_unit_wdata),
        .reg_wdata_o(csr_unit_reg_wdata)
    );
    
    // 乘除法控制逻辑
    exu_muldiv_ctrl u_muldiv_ctrl(
        .rst(rst),
        .inst_i(inst_i),
        .reg_waddr_i(reg_waddr_i),
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),
        .op1_jump_i(op1_jump_i),
        .op2_jump_i(op2_jump_i),
        .div_ready_i(div_ready),
        .div_result_i(div_result),
        .div_busy_i(div_busy),
        .div_reg_waddr_i(div_reg_waddr),
        .mul_ready_i(mul_ready),
        .mul_result_i(mul_result),
        .mul_busy_i(mul_busy),
        .mul_reg_waddr_i(mul_reg_waddr),
        .int_assert_i(int_assert_i),
        
        .div_start_o(div_start),
        .div_dividend_o(div_dividend),
        .div_divisor_o(div_divisor),
        .div_op_o(div_op),
        .div_reg_waddr_o(div_reg_waddr_o),
        .mul_start_o(mul_start),
        .mul_multiplicand_o(mul_multiplicand),
        .mul_multiplier_o(mul_multiplier),
        .mul_op_o(mul_op),
        .mul_reg_waddr_o(mul_reg_waddr_o),
        .muldiv_hold_flag_o(muldiv_hold_flag),
        .muldiv_jump_flag_o(muldiv_jump_flag),
        .muldiv_jump_addr_o(muldiv_jump_addr),
        .reg_wdata_o(muldiv_wdata),
        .reg_we_o(muldiv_we),
        .reg_waddr_o(muldiv_waddr)
    );
    
    // 输出选择逻辑
    assign hold_flag_o = muldiv_hold_flag;
    assign jump_flag_o = muldiv_jump_flag || bru_jump_flag || 
                         ((int_assert_i == `INT_ASSERT)? `JumpEnable: `JumpDisable);
    assign jump_addr_o = (int_assert_i == `INT_ASSERT)? int_addr_i: 
                         (muldiv_jump_flag ? muldiv_jump_addr : bru_jump_addr);
    
    // 寄存器写数据选择
    assign reg_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: 
                      (muldiv_we || alu_reg_we || agu_reg_we || 
                      (csr_we_i && inst_i[6:0] == `INST_CSR));
    
    assign reg_wdata_o = muldiv_we ? muldiv_wdata : 
                         agu_reg_we ? agu_reg_wdata :
                         (csr_we_i && inst_i[6:0] == `INST_CSR) ? csr_unit_reg_wdata :
                         alu_result;
                       
    assign reg_waddr_o = muldiv_we ? muldiv_waddr : 
                         agu_reg_we ? agu_reg_waddr :
                         alu_reg_we ? alu_reg_waddr :
                         reg_waddr_i;
    
    // CSR写数据选择
    assign csr_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: csr_we_i;
    assign csr_waddr_o = csr_waddr_i;
    assign csr_wdata_o = csr_unit_wdata;

    // 将除法和乘法开始信号组合后输出给clint
    assign div_started_o = div_start | mul_start;

endmodule
