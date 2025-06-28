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

// core local interruptor module
module clint (

    input wire clk,
    input wire rst_n,

    // from ifu_pipe
    input wire int_req_i,  // 中断请求信号
    input wire [7:0] int_id_i,  // 中断ID

    // from id
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input wire                        inst_valid_i,  // 指令有效信号

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        atom_opt_busy_i,  // 原子操作忙标志

    // 添加系统操作输入端口
    input wire                        sys_op_ecall_i,
    input wire                        sys_op_ebreak_i,
    input wire                        sys_op_mret_i,

    // from ctrl
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i,

    // from csr_reg
    input wire [`REG_DATA_WIDTH-1:0] data_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_mtvec,
    input wire [`REG_DATA_WIDTH-1:0] csr_mepc,
    input wire [`REG_DATA_WIDTH-1:0] csr_mstatus,
    input wire [`REG_DATA_WIDTH-1:0] csr_mie,
    input wire [`REG_DATA_WIDTH-1:0] csr_dpc,
    input wire [`REG_DATA_WIDTH-1:0] csr_dcsr,


    input wire global_int_en_i,  // 全局中断使能标志

    // to ctrl
    output wire stall_flag_o,

    // to csr_reg
    output reg                       we_o,
    output reg [`BUS_ADDR_WIDTH-1:0] waddr_o,
    output reg [`BUS_ADDR_WIDTH-1:0] raddr_o,
    output reg [`REG_DATA_WIDTH-1:0] data_o,

    // to ex
    output reg [`INST_ADDR_WIDTH-1:0] int_addr_o,   //ecall和ebreak的返回地址
    output reg                        int_assert_o  //ecall和ebreak的中断信号
);


    // interrupt state machine
    localparam S_INT_IDLE = 4'b0001;  // 空闲状态
    localparam S_INT_SYNC_ASSERT = 4'b0010;  // 同步中断断言状态
    localparam S_INT_ASYNC_ASSERT = 4'b0100;  // 异步中断断言状态 
    localparam S_INT_MRET = 4'b1000;  // 中断返回状态

    // CSR write state machine
    localparam S_CSR_IDLE = 5'b00001;  // CSR写入空闲状态
    localparam S_CSR_MSTATUS = 5'b00010;  // 写入mstatus寄存器状态
    localparam S_CSR_MEPC = 5'b00100;  // 写入mepc寄存器状态
    localparam S_CSR_MSTATUS_MRET = 5'b01000;  // 中断返回时写入mstatus寄存器状态
    localparam S_CSR_MCAUSE = 5'b10000;  // 写入mcause寄存器状态

    // 状态机和相关信号声明
    reg [3:0] int_state;  // 中断状态机当前状态
    reg [4:0] csr_state;  // CSR写状态机当前状态
    reg [`INST_ADDR_WIDTH-1:0] inst_addr;  // 保存的指令地址
    reg [31:0] cause;  // 中断原因代码

    // 暂停信号产生逻辑 - 当中断状态机或CSR写状态机不在空闲状态时暂停流水线
    assign stall_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE)) ? `HoldEnable : `HoldDisable;

    // 中断状态机逻辑
    always @(*) begin
        if (~rst_n) begin
            int_state <= S_INT_IDLE;
        end else if ((sys_op_ecall_i | sys_op_ebreak_i) & (atom_opt_busy_i == 1'b0) & inst_valid_i) begin
            int_state <= S_INT_SYNC_ASSERT;
        end else if (int_req_i & inst_valid_i ) begin
            int_state <= S_INT_ASYNC_ASSERT;  
        end else if (sys_op_mret_i & inst_valid_i) begin
            int_state <= S_INT_MRET;
        end else begin
            int_state <= S_INT_IDLE;
        end
    end
    //硬件中断判断
    //triggr_match


    // 中断原因寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cause <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) begin
            if (sys_op_ecall_i) begin
                cause <= 32'd11;
            end else if (sys_op_ebreak_i) begin
                cause <= 32'd3;
            end else begin
                cause <= 32'd10;
            end
        end
    end

    // 中断断言信号和中断地址逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            int_assert_o <= `INT_DEASSERT;
            int_addr_o <= `ZeroWord;
        end else begin
            case (csr_state)
                S_CSR_MCAUSE: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o <= csr_mtvec;
                end
                S_CSR_MSTATUS_MRET: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o <= csr_mepc;
                end
                default: begin
                    int_assert_o <= `INT_DEASSERT;
                end
            endcase
        end
    end


    // 保存指令地址寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_addr <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) begin
            if (jump_flag_i == `JumpEnable) begin
                inst_addr <= jump_addr_i - 4'h4;
            end else begin
                inst_addr <= inst_addr_i;
            end
        end
    end

  // CSR写状态机的状态转换逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            csr_state <= S_CSR_IDLE;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    if (int_state == S_INT_SYNC_ASSERT) begin
                        csr_state <= S_CSR_MEPC;
                    end else if (int_state == S_INT_MRET) begin
                        csr_state <= S_CSR_MSTATUS_MRET;
                    end
                end
                S_CSR_MEPC: begin
                    csr_state <= S_CSR_MSTATUS;
                end
                S_CSR_MSTATUS: begin
                    csr_state <= S_CSR_MCAUSE;
                end
                S_CSR_MCAUSE: begin
                    csr_state <= S_CSR_IDLE;
                end
                S_CSR_MSTATUS_MRET: begin
                    csr_state <= S_CSR_IDLE;
                end
            endcase
        end
    end

    // CSR写使能、写地址和写数据逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            we_o <= `WriteDisable;
            waddr_o <= `ZeroWord;
            data_o <= `ZeroWord;
        end else begin
            case (csr_state)
                S_CSR_MEPC: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MEPC};
                    data_o <= inst_addr;
                end
                S_CSR_MSTATUS: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]};
                end
                S_CSR_MCAUSE: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o <= cause;
                end
                S_CSR_MSTATUS_MRET: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]};
                end
                default: begin
                    we_o <= `WriteDisable;
                end
            endcase
        end
    end

    // 读地址寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            raddr_o <= `ZeroWord;
        end else begin
            raddr_o <= `ZeroWord;
        end
    end

endmodule
