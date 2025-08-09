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

// 乘法控制单元 - 专门处理乘法指令的控制和结果写回
module exu_mul_ctrl (
    input wire clk,
    input wire rst_n,
    input wire wb_ready_i,

    // 指令和操作数输入 - 来自dispatch
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 从dispatch接收的译码输入
    input wire req_mul_i,
    input wire mul_op_mul_i,
    input wire mul_op_mulh_i,
    input wire mul_op_mulhsu_i,
    input wire mul_op_mulhu_i,
    input wire reg_we_i,        // 寄存器写使能

    // 乘法器接口
    input wire [`REG_DATA_WIDTH-1:0] mul_result_i,
    input wire                       mul_busy_i,
    input wire                       mul_valid_i,

    // 中断信号
    input wire int_assert_i,

    // 乘法控制输出
    output wire                       mul_start_o,
    output wire [`REG_DATA_WIDTH-1:0] mul_multiplicand_o,
    output wire [`REG_DATA_WIDTH-1:0] mul_multiplier_o,
    output wire [                3:0] mul_op_o,

    // 控制输出
    output wire mul_stall_o,

    // 寄存器写回接口 - 输出到WBU
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 内部信号
    wire                        is_mul_op;
    wire                        mul_start_cond;
    wire [                 3:0] mul_op_sel;
    
    // 保存指令信息的寄存器
    wire [ `REG_ADDR_WIDTH-1:0] saved_mul_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul_commit_id;
    wire                        saved_reg_we;
    
    // 结果缓存
    wire                        mul_result_we;
    wire [ `REG_DATA_WIDTH-1:0] saved_mul_result;
    
    // 第二级寄存器（用于写回）
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul_commit_id_stage2;
    wire [ `REG_ADDR_WIDTH-1:0] saved_mul_waddr_stage2;
    wire                        saved_reg_we_stage2;

    // 操作类型解码
    assign mul_op_sel = {mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i};
    
    // 有效乘法操作判断
    assign is_mul_op = req_mul_i && !int_assert_i;
    
    // 乘法启动条件
    assign mul_start_cond = is_mul_op && !mul_busy_i && !mul_result_we;

    // 寄存器更新使能条件
    wire saved_mul_waddr_en = mul_start_cond;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul_waddr_nxt = reg_waddr_i;

    wire saved_mul_commit_id_en = mul_start_cond;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul_commit_id_nxt = commit_id_i;

    wire saved_reg_we_en = mul_start_cond;
    wire saved_reg_we_nxt = reg_we_i;

    wire mul_result_we_en = mul_valid_i || (mul_result_we && wb_ready_i && reg_we_o);
    wire mul_result_we_nxt = mul_valid_i ? 1'b1 : 1'b0;

    wire saved_mul_result_en = mul_valid_i;
    wire [`REG_DATA_WIDTH-1:0] saved_mul_result_nxt = mul_result_i;

    // 第一级寄存器：保存指令信息
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_waddr_en),
        .dnxt (saved_mul_waddr_nxt),
        .qout (saved_mul_waddr)
    );

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_commit_id_en),
        .dnxt (saved_mul_commit_id_nxt),
        .qout (saved_mul_commit_id)
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
    ) mul_result_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (mul_result_we_en),
        .dnxt (mul_result_we_nxt),
        .qout (mul_result_we)
    );

    gnrl_dfflr #(
        .DW(`REG_DATA_WIDTH)
    ) saved_mul_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_result_en),
        .dnxt (saved_mul_result_nxt),
        .qout (saved_mul_result)
    );

    // 第二级寄存器：用于写回阶段
    wire saved_mul_commit_id_stage2_en = mul_valid_i;
    wire [`COMMIT_ID_WIDTH-1:0] saved_mul_commit_id_stage2_nxt = saved_mul_commit_id;

    wire saved_mul_waddr_stage2_en = mul_valid_i;
    wire [`REG_ADDR_WIDTH-1:0] saved_mul_waddr_stage2_nxt = saved_mul_waddr;

    wire saved_reg_we_stage2_en = mul_valid_i;
    wire saved_reg_we_stage2_nxt = saved_reg_we;

    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) saved_mul_commit_id_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_commit_id_stage2_en),
        .dnxt (saved_mul_commit_id_stage2_nxt),
        .qout (saved_mul_commit_id_stage2)
    );

    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) saved_mul_waddr_stage2_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (saved_mul_waddr_stage2_en),
        .dnxt (saved_mul_waddr_stage2_nxt),
        .qout (saved_mul_waddr_stage2)
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
    assign mul_start_o = mul_start_cond;
    assign mul_multiplicand_o = reg1_rdata_i;
    assign mul_multiplier_o = reg2_rdata_i;
    assign mul_op_o = mul_op_sel;

    // 暂停信号
    assign mul_stall_o = is_mul_op && (mul_busy_i || mul_result_we);

    // 写回接口
    assign reg_wdata_o = saved_mul_result;
    assign reg_we_o = mul_result_we && saved_reg_we_stage2;
    assign reg_waddr_o = saved_mul_waddr_stage2;
    assign commit_id_o = saved_mul_commit_id_stage2;

endmodule
