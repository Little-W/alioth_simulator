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

`include "../core/defines.v"

// alioth soc顶层模块
module alioth_soc_top(

    input wire clk,
    input wire rst,

    output reg over,         // 测试是否完成信号
    output reg succ,         // 测试是否成功信号

    output wire halted_ind,  // jtag是否已经halt住CPU信号

    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚
    inout wire[1:0] gpio,    // GPIO引脚

    input wire jtag_TCK,     // JTAG TCK引脚
    input wire jtag_TMS,     // JTAG TMS引脚
    input wire jtag_TDI,     // JTAG TDI引脚
    output wire jtag_TDO,    // JTAG TDO引脚

    input wire spi_miso,     // SPI MISO引脚
    output wire spi_mosi,    // SPI MOSI引脚
    output wire spi_ss,      // SPI SS引脚
    output wire spi_clk      // SPI CLK引脚

    );

    // jtag接口
    wire jtag_halt_req_o;
    wire jtag_reset_req_o;
    wire[`REG_ADDR_WIDTH-1:0] jtag_reg_addr_o;
    wire[`REG_DATA_WIDTH-1:0] jtag_reg_data_o;
    wire jtag_reg_we_o;
    wire[`REG_DATA_WIDTH-1:0] jtag_reg_data_i;

    // timer0信号
    wire timer0_int;

    // 中断总线
    wire[`INT_BUS] int_flag;
    assign int_flag = {7'h0, timer0_int};

    // halted指示
    assign halted_ind = ~jtag_halt_req_o;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~u_cpu_top.u_regs.regs[26];  // when = 1, run over
            succ <= ~u_cpu_top.u_regs.regs[27];  // when = 1, run succ, otherwise fail
        end
    end

    // alioth处理器核模块例化
    cpu_top u_cpu_top(
        .clk(clk),
        .rst(rst),
        .jtag_reg_addr_i(jtag_reg_addr_o),
        .jtag_reg_data_i(jtag_reg_data_o),
        .jtag_reg_we_i(jtag_reg_we_o),
        .jtag_reg_data_o(jtag_reg_data_i),
        .jtag_halt_flag_i(jtag_halt_req_o),
        .jtag_reset_flag_i(jtag_reset_req_o),
        .int_i(int_flag)
    );

    // timer模块例化
    timer timer_0(
        .clk(clk),
        .rst(rst),
        .data_i(32'h0),  // 暂时不连接
        .addr_i(32'h0),  // 暂时不连接
        .we_i(1'b0),     // 暂时不连接
        .data_o(),       // 暂时不连接
        .int_sig_o(timer0_int)
    );

    // jtag模块例化
    jtag_top #(
        .DMI_ADDR_BITS(6),
        .DMI_DATA_BITS(32),
        .DMI_OP_BITS(2)
    ) u_jtag_top(
        .clk(clk),
        .jtag_rst_n(rst),
        .jtag_pin_TCK(jtag_TCK),
        .jtag_pin_TMS(jtag_TMS),
        .jtag_pin_TDI(jtag_TDI),
        .jtag_pin_TDO(jtag_TDO),
        .reg_we_o(jtag_reg_we_o),
        .reg_addr_o(jtag_reg_addr_o),
        .reg_wdata_o(jtag_reg_data_o),
        .reg_rdata_i(jtag_reg_data_i),
        .mem_we_o(),       // 暂时不连接
        .mem_addr_o(),     // 暂时不连接
        .mem_wdata_o(),    // 暂时不连接
        .mem_rdata_i(32'h0), // 暂时不连接
        .op_req_o(),       // 暂时不连接
        .halt_req_o(jtag_halt_req_o),
        .reset_req_o(jtag_reset_req_o)
    );

endmodule
