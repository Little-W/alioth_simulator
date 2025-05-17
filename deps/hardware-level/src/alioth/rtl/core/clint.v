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


// core local interruptor module
module clint(

    input wire clk,
    input wire rst,

    // from core
    // input wire[`INT_BUS] int_flag_i, // 注释掉该信号

    // from id
    input wire[`INST_DATA_WIDTH-1:0] inst_i,
    input wire[`INST_ADDR_WIDTH-1:0] inst_addr_i,

    // from ex
    input wire jump_flag_i,
    input wire[`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire div_started_i,

    // from ctrl
    input wire[`Hold_Flag_Bus] hold_flag_i,

    // from csr_reg
    input wire[`REG_DATA_WIDTH-1:0] data_i,
    input wire[`REG_DATA_WIDTH-1:0] csr_mtvec,
    input wire[`REG_DATA_WIDTH-1:0] csr_mepc,
    input wire[`REG_DATA_WIDTH-1:0] csr_mstatus,

    input wire global_int_en_i,  // 全局中断使能标志

    // to ctrl
    output wire hold_flag_o,

    // to csr_reg
    output reg we_o,
    output reg[`BUS_ADDR_WIDTH-1:0] waddr_o,
    output reg[`BUS_ADDR_WIDTH-1:0] raddr_o,
    output reg[`REG_DATA_WIDTH-1:0] data_o,

    // to ex
    output reg[`INST_ADDR_WIDTH-1:0] int_addr_o, //ecall和ebreak的返回地址
    output reg int_assert_o //ecall和ebreak的中断信号
    );


    // interrupt state machine
    localparam S_INT_IDLE            = 4'b0001;
    localparam S_INT_SYNC_ASSERT     = 4'b0010;
    localparam S_INT_ASYNC_ASSERT    = 4'b0100;
    localparam S_INT_MRET            = 4'b1000;

    // CSR write state machine
    localparam S_CSR_IDLE            = 5'b00001;
    localparam S_CSR_MSTATUS         = 5'b00010;
    localparam S_CSR_MEPC            = 5'b00100;
    localparam S_CSR_MSTATUS_MRET    = 5'b01000;
    localparam S_CSR_MCAUSE          = 5'b10000;

    reg[3:0] int_state;
    reg[4:0] csr_state;
    reg[`INST_ADDR_WIDTH-1:0] inst_addr;
    reg[31:0] cause;


    assign hold_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE))? `HoldEnable: `HoldDisable;


    // interrupt handling logic
    always @ (*) begin
        if (rst == `RstEnable) begin
            int_state = S_INT_IDLE;
        end else begin
            if (inst_i == `INST_ECALL || inst_i == `INST_EBREAK) begin
                // synchronous interrupt
                if (div_started_i == `DivStop) begin
                    int_state = S_INT_SYNC_ASSERT;
                end else begin
                    int_state = S_INT_IDLE;
                end
            end else if (inst_i == `INST_MRET) begin
                int_state = S_INT_MRET;
            end else begin
                int_state = S_INT_IDLE;
            end
        end
    end

    // CSR write state machine
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            csr_state <= S_CSR_IDLE;
            cause <= `ZeroWord;
            inst_addr <= `ZeroWord;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    // synchronous interrupt
                    if (int_state == S_INT_SYNC_ASSERT) begin
                        csr_state <= S_CSR_MEPC;
                        // if jump occurred, set inst_addr to jump address - 4
                        if (jump_flag_i == `JumpEnable) begin
                            inst_addr <= jump_addr_i - 4'h4;
                        end else begin
                            inst_addr <= inst_addr_i;
                        end
                        case (inst_i)
                            `INST_ECALL: begin
                                cause <= 32'd11;
                            end
                            `INST_EBREAK: begin
                                cause <= 32'd3;
                            end
                            default: begin
                                cause <= 32'd10;
                            end
                        endcase
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
                default: begin
                    csr_state <= S_CSR_IDLE;
                end
            endcase
        end
    end

    // write to CSR registers
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            we_o <= `WriteDisable;
            waddr_o <= `ZeroWord;
            data_o <= `ZeroWord;
        end else begin
            case (csr_state)
                // write to mepc register
                S_CSR_MEPC: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MEPC};
                    data_o <= inst_addr;
                end
                // write to mcause register
                S_CSR_MCAUSE: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o <= cause;
                end
                // disable global interrupt
                S_CSR_MSTATUS: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]};
                end
                // interrupt return
                S_CSR_MSTATUS_MRET: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]};
                end
                default: begin
                    we_o <= `WriteDisable;
                    waddr_o <= `ZeroWord;
                    data_o <= `ZeroWord;
                end
            endcase
        end
    end

    // send interrupt signal to ex module
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            int_assert_o <= `INT_DEASSERT;
            int_addr_o <= `ZeroWord;
        end else begin
            case (csr_state)
                // assert interrupt signal
                S_CSR_MCAUSE: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o <= csr_mtvec;
                end
                // assert interrupt return signal
                S_CSR_MSTATUS_MRET: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o <= csr_mepc;
                end
                default: begin
                    int_assert_o <= `INT_DEASSERT;
                    int_addr_o <= `ZeroWord;
                end
            endcase
        end
    end

endmodule
