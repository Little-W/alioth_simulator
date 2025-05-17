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

// 内存管理模块，包含ITCM和DTCM
module mems (
    input wire clk,
    input wire rst,

    // PC访问接口
    input  wire [`INST_ADDR_WIDTH-1:0] pc_i,   // PC地址
    output wire [`INST_DATA_WIDTH-1:0] inst_o, // 指令输出

    // EX访问接口
    input  wire [`BUS_ADDR_WIDTH-1:0] ex_addr_i,  // EX访问地址
    input  wire [`BUS_DATA_WIDTH-1:0] ex_data_i,  // EX写入数据
    output wire [`BUS_DATA_WIDTH-1:0] ex_data_o,  // EX读出数据
    input  wire                       ex_we_i,    // EX写使能
    input  wire                       ex_req_i,   // EX访问请求
    input  wire [3:0]                 ex_wmask_i, // EX字节写入掩码

    // 暂停信号
    output wire hold_flag_o  // 暂停流水线信号
);

    // 地址译码信号
    wire                        ex_access_itcm;
    wire                        ex_access_dtcm;

    // ITCM仲裁信号
    wire                        pc_itcm_req;
    wire                        ex_itcm_req;
    wire                        itcm_grant_to_ex;

    // ITCM接口
    wire [ `ITCM_ADDR_WIDTH-1:0] itcm_addr;
    wire [`INST_DATA_WIDTH-1:0] itcm_data_out;
    wire                        itcm_ce;
    wire                        itcm_we;
    wire [3:0]                  itcm_wmask;
    wire [`INST_DATA_WIDTH-1:0] itcm_data_in;

    // DTCM接口
    wire [ `DTCM_ADDR_WIDTH-1:0] dtcm_addr;
    wire [`INST_DATA_WIDTH-1:0] dtcm_data_out;
    wire                        dtcm_ce;
    wire                        dtcm_we;
    wire [3:0]                  dtcm_wmask;
    wire [`INST_DATA_WIDTH-1:0] dtcm_data_in;

    // 地址译码 - 确定EX访问的是ITCM还是DTCM
    assign ex_access_itcm   = (ex_addr_i >= `ITCM_BASE_ADDR && ex_addr_i < (`ITCM_BASE_ADDR + `ITCM_SIZE)) && ex_req_i;
    assign ex_access_dtcm   = (ex_addr_i >= `DTCM_BASE_ADDR && ex_addr_i < (`DTCM_BASE_ADDR + `DTCM_SIZE)) && ex_req_i;

    // ITCM仲裁 - PC和EX都可能访问ITCM
    assign pc_itcm_req      = 1'b1;  // PC总是请求ITCM
    assign ex_itcm_req      = ex_access_itcm;

    // 优先考虑EX对ITCM的访问请求
    assign itcm_grant_to_ex = ex_itcm_req;

    // 根据仲裁结果设置ITCM地址和控制信号
    assign itcm_addr        = itcm_grant_to_ex ? (ex_addr_i - `ITCM_BASE_ADDR) : (pc_i - `ITCM_BASE_ADDR);
    assign itcm_ce          = itcm_grant_to_ex ? 1'b1 : pc_itcm_req;
    assign itcm_we          = itcm_grant_to_ex ? ex_we_i : 1'b0;
    assign itcm_wmask       = itcm_grant_to_ex ? ex_wmask_i : 4'b0000;
    assign itcm_data_in     = ex_data_i;

    // 设置DTCM地址和控制信号
    assign dtcm_addr        = ex_addr_i - `DTCM_BASE_ADDR;
    assign dtcm_ce          = ex_access_dtcm;
    assign dtcm_we          = ex_access_dtcm & ex_we_i;
    assign dtcm_wmask       = ex_access_dtcm ? ex_wmask_i : 4'b0000;
    assign dtcm_data_in     = ex_data_i;

    // 选择正确的数据返回给EX
    assign ex_data_o       = ex_access_itcm ? itcm_data_out : ex_access_dtcm ? dtcm_data_out : 32'h0;

    // 选择正确的指令返回给IF
    assign inst_o          = itcm_grant_to_ex ? 32'h00000013 : itcm_data_out;  // 如果EX使用ITCM，返回NOP指令

    // 设置暂停信号
    assign hold_flag_o     = itcm_grant_to_ex;  // 当EX使用ITCM时，暂停流水线

    // ITCM模块例化 - 使用参数化和宏定义控制初始化
    gnrl_ram #(
        .ADDR_WIDTH(`ITCM_ADDR_WIDTH),
        .DATA_WIDTH(`BUS_DATA_WIDTH),
        .INIT_MEM(`INIT_ITCM),           // 使用宏定义控制是否初始化
        .INIT_FILE(`ITCM_INIT_FILE)      // 使用宏定义指定初始化文件
    ) u_itcm (
        .clk   (clk),
        .rst   (rst),
        .we_i  (itcm_we),
        .we_mask_i(itcm_wmask),
        .addr_i(itcm_addr),
        .data_i(itcm_data_in),
        .data_o(itcm_data_out)
    );

    // DTCM模块例化 - 使用参数化，默认不初始化
    gnrl_ram #(
        .ADDR_WIDTH(`DTCM_ADDR_WIDTH),
        .DATA_WIDTH(`BUS_DATA_WIDTH),
        .INIT_MEM(0)                     // DTCM默认不初始化
    ) u_dtcm (
        .clk   (clk),
        .rst   (rst),
        .we_i  (dtcm_we),
        .we_mask_i(dtcm_wmask),
        .addr_i(dtcm_addr),
        .data_i(dtcm_data_in),
        .data_o(dtcm_data_out)
    );

endmodule
