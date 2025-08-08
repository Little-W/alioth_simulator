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

// 除法控制单元 - 专门处理除法指令的控制和结果写回
module exu_div_ctrl (
    input wire clk,
    input wire rst_n,
    input wire wb_ready_i,

    // 指令和操作数输入 - 来自dispatch
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 从dispatch接收的译码输入
    input wire req_div_i,
    input wire div_op_div_i,
    input wire div_op_divu_i,
    input wire div_op_rem_i,
    input wire div_op_remu_i,
    input wire reg_we_i,        // 寄存器写使能

    // 除法器接口
    input wire [`REG_DATA_WIDTH-1:0] div_result_i,
    input wire                       div_busy_i,
    input wire                       div_valid_i,

    // 中断信号
    input wire int_assert_i,

    // 除法控制输出
    output wire                       div_start_o,
    output wire [`REG_DATA_WIDTH-1:0] div_dividend_o,
    output wire [`REG_DATA_WIDTH-1:0] div_divisor_o,
    output wire [                3:0] div_op_o,

    // 控制输出
    output wire div_stall_o,

    // 寄存器写回接口 - 输出到WBU
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 内部信号
    wire                        is_div_op;
    wire                        div_start_cond;
    wire [                 3:0] div_op_sel;
    
    // 保存指令信息的寄存器
    wire [ `REG_ADDR_WIDTH-1:0] saved_div_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div_commit_id;
    wire                        saved_reg_we;
    
    // 结果缓存
    wire                        div_result_we;
    wire [ `REG_DATA_WIDTH-1:0] saved_div_result;
    
    // 第二级寄存器（用于写回）
    wire [`COMMIT_ID_WIDTH-1:0] saved_div_commit_id_stage2;
    wire [ `REG_ADDR_WIDTH-1:0] saved_div_waddr_stage2;
    wire                        saved_reg_we_stage2;

    // 操作类型解码
    assign div_op_sel = {div_op_remu_i, div_op_rem_i, div_op_divu_i, div_op_div_i};
    
    // 有效除法操作判断
    assign is_div_op = req_div_i && !int_assert_i;
    
    // 除法启动条件
    assign div_start_cond = is_div_op && !div_busy_i && !div_result_we;

    // 寄存器更新使能条件
    wire saved_div_waddr_en = div_start_cond;
    wire [`REG_ADDR_WIDTH-1:0] saved_div_waddr_nxt = reg_waddr_i;

    wire saved_div_commit_id_en = div_start_cond;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div_commit_id_nxt = commit_id_i;

    wire saved_reg_we_en = div_start_cond;
    wire saved_reg_we_nxt = reg_we_i;

    wire div_result_we_en = div_valid_i || (div_result_we && wb_ready_i && reg_we_o);
    wire div_result_we_nxt = div_valid_i ? 1'b1 : 1'b0;

    wire saved_div_result_en = div_valid_i;
    wire [`REG_DATA_WIDTH-1:0] saved_div_result_nxt = div_result_i;

    // 第一级寄存器：保存指令信息
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_waddr_en),
        .dnxt (saved_div_waddr_nxt),
        .qout (saved_div_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_commit_id_en),
        .dnxt (saved_div_commit_id_nxt),
        .qout (saved_div_commit_id)
    );

    gnrl_dfflr #(
        .DW(1)
    ) saved_reg_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_reg_we_en),
        .dnxt (saved_reg_we_nxt),
        .qout (saved_reg_we)
    );

    gnrl_dfflr #(
        .DW(1)
    ) div_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (div_result_we_en),
        .dnxt (div_result_we_nxt),
        .qout (div_result_we)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_div_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_result_en),
        .dnxt (saved_div_result_nxt),
        .qout (saved_div_result)
    );

    // 第二级寄存器：用于写回阶段
    wire saved_div_commit_id_stage2_en = div_valid_i;
    wire [`COMMIT_ID_WIDTH-1:0] saved_div_commit_id_stage2_nxt = saved_div_commit_id;

    wire saved_div_waddr_stage2_en = div_valid_i;
    wire [`REG_ADDR_WIDTH-1:0] saved_div_waddr_stage2_nxt = saved_div_waddr;

    wire saved_reg_we_stage2_en = div_valid_i;
    wire saved_reg_we_stage2_nxt = saved_reg_we;

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_div_commit_id_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_commit_id_stage2_en),
        .dnxt (saved_div_commit_id_stage2_nxt),
        .qout (saved_div_commit_id_stage2)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_div_waddr_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_div_waddr_stage2_en),
        .dnxt (saved_div_waddr_stage2_nxt),
        .qout (saved_div_waddr_stage2)
    );

    gnrl_dfflr #(
        .DW(1)
    ) saved_reg_we_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_reg_we_stage2_en),
        .dnxt (saved_reg_we_stage2_nxt),
        .qout (saved_reg_we_stage2)
    );

    // 输出信号连线
    assign div_start_o = div_start_cond;
    assign div_dividend_o = reg1_rdata_i;
    assign div_divisor_o = reg2_rdata_i;
    assign div_op_o = div_op_sel;

    // 暂停信号
    assign div_stall_o = is_div_op && (div_busy_i || div_result_we);

    // 写回接口
    assign reg_wdata_o = saved_div_result;
    assign reg_we_o = div_result_we && saved_reg_we_stage2;
    assign reg_waddr_o = saved_div_waddr_stage2;
    assign commit_id_o = saved_div_commit_id_stage2;

endmodule
