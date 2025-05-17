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

// alioth处理器核顶层模块
module cpu_top(

    input wire clk,
    input wire rst

    /*
    input wire[`REG_ADDR_WIDTH-1:0] jtag_reg_addr_i,   // jtag模块读、写寄存器的地址
    input wire[`REG_DATA_WIDTH-1:0] jtag_reg_data_i,   // jtag模块写寄存器数据
    input wire jtag_reg_we_i,                // jtag模块写寄存器标志
    output wire[`REG_DATA_WIDTH-1:0] jtag_reg_data_o,  // jtag模块读取到的寄存器数据

    input wire jtag_halt_flag_i,               // jtag暂停标志
    input wire jtag_reset_flag_i               // jtag复位PC标志
    */

    );

    // pc_reg模块输出信号
    wire[`INST_ADDR_WIDTH-1:0] pc_pc_o;

    // if_id模块输出信号
    wire[`INST_DATA_WIDTH-1:0] if_inst_o;
    wire[`INST_ADDR_WIDTH-1:0] if_inst_addr_o;
    //wire[`INST_DATA_WIDTH-1:0] if_int_flag_o;

    // id模块输出信号
    wire[`REG_ADDR_WIDTH-1:0] id_reg1_raddr_o;
    wire[`REG_ADDR_WIDTH-1:0] id_reg2_raddr_o;
    wire[`INST_DATA_WIDTH-1:0] id_inst_o;
    wire[`INST_ADDR_WIDTH-1:0] id_inst_addr_o;
    wire[`REG_DATA_WIDTH-1:0] id_reg1_rdata_o;
    wire[`REG_DATA_WIDTH-1:0] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`REG_ADDR_WIDTH-1:0] id_reg_waddr_o;
    wire[`BUS_ADDR_WIDTH-1:0] id_csr_raddr_o;
    wire id_csr_we_o;
    wire[`REG_DATA_WIDTH-1:0] id_csr_rdata_o;
    wire[`BUS_ADDR_WIDTH-1:0] id_csr_waddr_o;
    wire[`BUS_ADDR_WIDTH-1:0] id_op1_o;
    wire[`BUS_ADDR_WIDTH-1:0] id_op2_o;
    wire[`BUS_ADDR_WIDTH-1:0] id_op1_jump_o;
    wire[`BUS_ADDR_WIDTH-1:0] id_op2_jump_o;

    // id_ex模块输出信号
    wire[`INST_DATA_WIDTH-1:0] ie_inst_o;
    wire[`INST_ADDR_WIDTH-1:0] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`REG_ADDR_WIDTH-1:0] ie_reg_waddr_o;
    wire[`REG_DATA_WIDTH-1:0] ie_reg1_rdata_o;
    wire[`REG_DATA_WIDTH-1:0] ie_reg2_rdata_o;
    wire ie_csr_we_o;
    wire[`BUS_ADDR_WIDTH-1:0] ie_csr_waddr_o;
    wire[`REG_DATA_WIDTH-1:0] ie_csr_rdata_o;
    wire[`BUS_ADDR_WIDTH-1:0] ie_op1_o;
    wire[`BUS_ADDR_WIDTH-1:0] ie_op2_o;
    wire[`BUS_ADDR_WIDTH-1:0] ie_op1_jump_o;
    wire[`BUS_ADDR_WIDTH-1:0] ie_op2_jump_o;

    // exu模块输出信号
    wire[`BUS_DATA_WIDTH-1:0] exu_mem_wdata_o;
    wire[`BUS_ADDR_WIDTH-1:0] exu_mem_raddr_o;
    wire[`BUS_ADDR_WIDTH-1:0] exu_mem_waddr_o;
    wire exu_mem_we_o;
    wire exu_mem_req_o;
    wire[`REG_DATA_WIDTH-1:0] exu_reg_wdata_o;
    wire exu_reg_we_o;
    wire[`REG_ADDR_WIDTH-1:0] exu_reg_waddr_o;
    wire exu_hold_flag_o;
    wire exu_jump_flag_o;
    wire[`INST_ADDR_WIDTH-1:0] exu_jump_addr_o;
    wire[`REG_DATA_WIDTH-1:0] exu_csr_wdata_o;
    wire exu_csr_we_o;
    wire[`BUS_ADDR_WIDTH-1:0] exu_csr_waddr_o;
    wire exu_div_started_o;

    // regs模块输出信号
    wire[`REG_DATA_WIDTH-1:0] regs_rdata1_o;
    wire[`REG_DATA_WIDTH-1:0] regs_rdata2_o;

    // csr_reg模块输出信号
    wire[`REG_DATA_WIDTH-1:0] csr_data_o;
    wire[`REG_DATA_WIDTH-1:0] csr_clint_data_o;
    wire csr_global_int_en_o;
    wire[`REG_DATA_WIDTH-1:0] csr_clint_csr_mtvec;
    wire[`REG_DATA_WIDTH-1:0] csr_clint_csr_mepc;
    wire[`REG_DATA_WIDTH-1:0] csr_clint_csr_mstatus;

    // ctrl模块输出信号
    wire[`Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`INST_ADDR_WIDTH-1:0] ctrl_jump_addr_o;

    // clint模块输出信号
    wire clint_we_o;
    wire[`BUS_ADDR_WIDTH-1:0] clint_waddr_o;
    wire[`BUS_ADDR_WIDTH-1:0] clint_raddr_o;
    wire[`REG_DATA_WIDTH-1:0] clint_data_o;
    wire[`INST_ADDR_WIDTH-1:0] clint_int_addr_o;
    wire clint_int_assert_o;
    wire clint_hold_flag_o;

    // mems模块接口信号
    wire hold_flag_i;
    wire[`INST_DATA_WIDTH-1:0] inst_data_i;
    wire[`BUS_DATA_WIDTH-1:0] exu_mem_data_i;

    // pc_reg模块例化
    pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        //.jtag_reset_flag_i(jtag_reset_flag_i),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );

    // ctrl模块例化
    ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(exu_jump_flag_o),
        .jump_addr_i(exu_jump_addr_o),
        .hold_flag_ex_i(exu_hold_flag_o),
        .hold_flag_rib_i(hold_flag_i),
        .hold_flag_o(ctrl_hold_flag_o),
        .hold_flag_clint_i(clint_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o)
        //.jtag_halt_flag_i(jtag_halt_flag_i)
    );

    // regs模块例化
    regs u_regs(
        .clk(clk),
        .rst(rst),
        .we_i(exu_reg_we_o),
        .waddr_i(exu_reg_waddr_o),
        .wdata_i(exu_reg_wdata_o),
        .raddr1_i(id_reg1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(id_reg2_raddr_o),
        .rdata2_o(regs_rdata2_o)
        /*
        .jtag_we_i(jtag_reg_we_i),
        .jtag_addr_i(jtag_reg_addr_i),
        .jtag_data_i(jtag_reg_data_i),
        .jtag_data_o(jtag_reg_data_o)
        */
    );

    // csr_reg模块例化
    csr_reg u_csr_reg(
        .clk(clk),
        .rst(rst),
        .we_i(exu_csr_we_o),
        .raddr_i(id_csr_raddr_o),
        .waddr_i(exu_csr_waddr_o),
        .data_i(exu_csr_wdata_o),
        .data_o(csr_data_o),
        .global_int_en_o(csr_global_int_en_o),
        .clint_we_i(clint_we_o),
        .clint_raddr_i(clint_raddr_o),
        .clint_waddr_i(clint_waddr_o),
        .clint_data_i(clint_data_o),
        .clint_data_o(csr_clint_data_o),
        .clint_csr_mtvec(csr_clint_csr_mtvec),
        .clint_csr_mepc(csr_clint_csr_mepc),
        .clint_csr_mstatus(csr_clint_csr_mstatus)
    );

    // if_id模块例化
    if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(inst_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // id模块例化
    id u_id(
        .rst(rst),
        .inst_i(if_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),
        .ex_jump_flag_i(exu_jump_flag_o),
        .reg1_raddr_o(id_reg1_raddr_o),
        .reg2_raddr_o(id_reg2_raddr_o),
        .inst_o(id_inst_o),
        .inst_addr_o(id_inst_addr_o),
        .reg1_rdata_o(id_reg1_rdata_o),
        .reg2_rdata_o(id_reg2_rdata_o),
        .reg_we_o(id_reg_we_o),
        .reg_waddr_o(id_reg_waddr_o),
        .op1_o(id_op1_o),
        .op2_o(id_op2_o),
        .op1_jump_o(id_op1_jump_o),
        .op2_jump_o(id_op2_jump_o),
        .csr_rdata_i(csr_data_o),
        .csr_raddr_o(id_csr_raddr_o),
        .csr_we_o(id_csr_we_o),
        .csr_rdata_o(id_csr_rdata_o),
        .csr_waddr_o(id_csr_waddr_o)
    );

    // id_ex模块例化
    id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o),
        .csr_we_i(id_csr_we_o),
        .csr_waddr_i(id_csr_waddr_o),
        .csr_rdata_i(id_csr_rdata_o),
        .csr_we_o(ie_csr_we_o),
        .csr_waddr_o(ie_csr_waddr_o),
        .csr_rdata_o(ie_csr_rdata_o)
    );

    // exu模块例化
    exu u_exu(
        .clk(clk),
        .rst(rst),
        .inst_i(ie_inst_o),
        .inst_addr_i(ie_inst_addr_o),
        .reg_we_i(ie_reg_we_o),
        .reg_waddr_i(ie_reg_waddr_o),
        .reg1_rdata_i(ie_reg1_rdata_o),
        .reg2_rdata_i(ie_reg2_rdata_o),
        .op1_i(ie_op1_o),
        .op2_i(ie_op2_o),
        .op1_jump_i(ie_op1_jump_o),
        .op2_jump_i(ie_op2_jump_o),
        .mem_rdata_i(exu_mem_data_i),
        .mem_wdata_o(exu_mem_wdata_o),
        .mem_raddr_o(exu_mem_raddr_o),
        .mem_waddr_o(exu_mem_waddr_o),
        .mem_we_o(exu_mem_we_o),
        .mem_req_o(exu_mem_req_o),
        .reg_wdata_o(exu_reg_wdata_o),
        .reg_we_o(exu_reg_we_o),
        .reg_waddr_o(exu_reg_waddr_o),
        .hold_flag_o(exu_hold_flag_o),
        .jump_flag_o(exu_jump_flag_o),
        .jump_addr_o(exu_jump_addr_o),
        .int_assert_i(clint_int_assert_o),
        .int_addr_i(clint_int_addr_o),
        .csr_we_i(ie_csr_we_o),
        .csr_waddr_i(ie_csr_waddr_o),
        .csr_rdata_i(ie_csr_rdata_o),
        .csr_wdata_o(exu_csr_wdata_o),
        .csr_we_o(exu_csr_we_o),
        .csr_waddr_o(exu_csr_waddr_o),
        .div_started_o(exu_div_started_o)
    );

    // clint模块例化
    clint u_clint(
        .clk(clk),
        .rst(rst),
        //.int_flag_i(if_int_flag_o),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .jump_flag_i(exu_jump_flag_o),
        .jump_addr_i(exu_jump_addr_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .div_started_i(exu_div_started_o),
        .data_i(csr_clint_data_o),
        .csr_mtvec(csr_clint_csr_mtvec),
        .csr_mepc(csr_clint_csr_mepc),
        .csr_mstatus(csr_clint_csr_mstatus),
        .we_o(clint_we_o),
        .waddr_o(clint_waddr_o),
        .raddr_o(clint_raddr_o),
        .data_o(clint_data_o),
        .hold_flag_o(clint_hold_flag_o),
        .global_int_en_i(csr_global_int_en_o),
        .int_addr_o(clint_int_addr_o),
        .int_assert_o(clint_int_assert_o)
    );

    // mems模块例化
    mems u_mems(
        .clk(clk),
        .rst(rst),
        // PC接口
        .pc_i(pc_pc_o),
        .inst_o(inst_data_i),
        // EX接口
        .ex_addr_i(exu_mem_we_o ? exu_mem_waddr_o : exu_mem_raddr_o),
        .ex_data_i(exu_mem_wdata_o),
        .ex_data_o(exu_mem_data_i),
        .ex_we_i(exu_mem_we_o),
        .ex_req_i(exu_mem_req_o),
        // 暂停信号
        .hold_flag_o(hold_flag_i)
    );

endmodule
