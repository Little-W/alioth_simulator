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

// 乘法控制单元 - 管理流水线乘法器
module exu_mul (
    input wire clk,
    input wire rst_n,
    input wire wb_ready,

    // 指令和操作数输入
    input wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg1_rdata_i,
    input wire [ `REG_DATA_WIDTH-1:0] reg2_rdata_i,
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,

    // 译码输入
    input wire req_mul_i,
    input wire mul_op_mul_i,
    input wire mul_op_mulh_i,
    input wire mul_op_mulhsu_i,
    input wire mul_op_mulhu_i,

    // 中断信号
    input wire int_assert_i,

    // 控制输出
    output wire mul_stall_flag_o,

    // 寄存器写回接口
    output wire [ `REG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 乘法器输出信号
    wire [`REG_DATA_WIDTH-1:0] mul_result;
    wire mul_valid;
    wire [`REG_ADDR_WIDTH-1:0] mul_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] mul_commit_id;

    // 声明用于连接mul的输入信号
    wire [3:0] mul_op;
    wire [`REG_DATA_WIDTH-1:0] mul_multiplicand;
    wire [`REG_DATA_WIDTH-1:0] mul_multiplier;
    wire mul_valid_in;

    // 直接使用输入的总乘法信号
    wire is_mul_op = req_mul_i && !int_assert_i;

    // Buffer寄存器定义
    reg [`REG_ADDR_WIDTH-1:0] waddr_buffer;
    reg [`REG_DATA_WIDTH-1:0] multiplicand_buffer;
    reg [`REG_DATA_WIDTH-1:0] multiplier_buffer;
    reg [`COMMIT_ID_WIDTH-1:0] commit_id_buffer;
    reg [3:0] mul_op_buffer;  // 4位：mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i
    reg buffer_req_valid;

    // Buffer数据选择
    wire use_buffer = buffer_req_valid;
    wire [`REG_ADDR_WIDTH-1:0] reg_waddr_mux = use_buffer ? waddr_buffer : reg_waddr_i;
    wire [`REG_DATA_WIDTH-1:0] reg1_rdata_mux = use_buffer ? multiplicand_buffer : reg1_rdata_i;
    wire [`REG_DATA_WIDTH-1:0] reg2_rdata_mux = use_buffer ? multiplier_buffer : reg2_rdata_i;
    wire [`COMMIT_ID_WIDTH-1:0] commit_id_mux = use_buffer ? commit_id_buffer : commit_id_i;
    wire [3:0] mul_op_mux = use_buffer ? mul_op_buffer : {mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i};

    // 乘法器输入
    assign mul_op           = mul_op_mux;
    assign mul_multiplicand = reg1_rdata_mux;
    assign mul_multiplier   = reg2_rdata_mux;

    // 流水线控制逻辑
    wire ctrl_stall = mul_valid & ~wb_ready;
    wire ctrl_ready = !ctrl_stall;
    assign mul_valid_in = (is_mul_op || buffer_req_valid);

    // Buffer写入条件 - 当流水线暂停时需要buffer
    wire buffer_write_en = is_mul_op && ctrl_stall;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_req_valid    <= 1'b0;
            waddr_buffer        <= {`REG_ADDR_WIDTH{1'b0}};
            multiplicand_buffer <= {`REG_DATA_WIDTH{1'b0}};
            multiplier_buffer   <= {`REG_DATA_WIDTH{1'b0}};
            commit_id_buffer    <= {`COMMIT_ID_WIDTH{1'b0}};
            mul_op_buffer       <= 4'b0;
        end else if ((buffer_write_en && !buffer_req_valid) || (buffer_req_valid && is_mul_op && ctrl_ready)) begin
            buffer_req_valid    <= 1'b1;
            waddr_buffer        <= reg_waddr_i;
            multiplicand_buffer <= reg1_rdata_i;
            multiplier_buffer   <= reg2_rdata_i;
            commit_id_buffer    <= commit_id_i;
            mul_op_buffer       <= {mul_op_mulhu_i, mul_op_mulhsu_i, mul_op_mulh_i, mul_op_mul_i};
        end else if (mul_valid_in && ctrl_ready) begin
            buffer_req_valid <= 1'b0;
        end
    end

    // 流水线保持控制逻辑
    assign mul_stall_flag_o = buffer_req_valid & is_mul_op & ctrl_stall;

    // 结果写回
    assign reg_wdata_o = mul_result;
    assign reg_waddr_o = mul_waddr;
    assign commit_id_o = mul_commit_id;
    assign reg_we_o = mul_valid;

    mul u_mul (
        .clk           (clk),
        .rst_n         (rst_n),
        .multiplicand_i(mul_multiplicand),
        .multiplier_i  (mul_multiplier),
        .valid_in      (mul_valid_in),
        .ctrl_ready_i  (ctrl_ready),
        .op_i          (mul_op),
        .reg_waddr_i   (reg_waddr_mux),
        .commit_id_i   (commit_id_mux),
        .result_o      (mul_result),
        .valid_o       (mul_valid),
        .reg_waddr_o   (mul_waddr),
        .commit_id_o   (mul_commit_id)
    );

endmodule