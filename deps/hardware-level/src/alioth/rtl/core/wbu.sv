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

// 写回单元 - 负责寄存器写回逻辑和仲裁优先级
module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ALU数据
    input  wire [ `REG_DATA_WIDTH-1:0] alu_reg_wdata_i,
    input  wire                        alu_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu_commit_id_i,  // ALU指令ID
    output wire                        alu_ready_o,      // ALU握手信号

    // 来自EXU的MULDIV数据
    input  wire [ `REG_DATA_WIDTH-1:0] muldiv_reg_wdata_i,
    input  wire                        muldiv_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] muldiv_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] muldiv_commit_id_i,  // 乘除法指令ID
    output wire                        muldiv_ready_o,      // MULDIV握手信号

    // 来自EXU的CSR数据
    input  wire [ `REG_DATA_WIDTH-1:0] csr_wdata_i,
    input  wire                        csr_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_i,  // CSR指令ID
    output wire                        csr_ready_o,      // CSR握手信号

    // CSR寄存器写数据输入
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr_reg_waddr_i,  // 保留寄存器写地址输入
    input wire                       csr_reg_we_i,     // 新增：csr写回使能输入

    // 来自EXU的LSU数据
    input wire [ `REG_DATA_WIDTH-1:0] lsu_reg_wdata_i,
    input wire                        lsu_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_i,  // LSU指令ID，修改为3位

    // 来自EXU的FPU数据
    input  wire [ `REG_DATA_WIDTH-1:0] fpu_reg_wdata_i,
    input  wire                        fpu_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] fpu_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] fpu_commit_id_i,  // FPU指令ID
    output wire                        fpu_ready_o,      // FPU握手信号

    // 长指令完成信号（对接hazard_detection）
    output wire commit_valid_int_o,  // 整数寄存器指令完成有效信号
    output wire commit_valid_fp_o,  // 浮点寄存器指令完成有效信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_int_o,  // 整数寄存器完成指令ID
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_fp_o,  // 浮点寄存器完成指令ID

    // 寄存器写回接口
    output wire [`GREG_DATA_WIDTH-1:0] reg_wdata_o,
    output wire                        reg_we_o,
    output wire [`GREG_ADDR_WIDTH-1:0] reg_waddr_o,

    // CSR寄存器写回接口
    output wire [`GREG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                        csr_we_o,
    output wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_o,

    // 浮点寄存器写回接口
    output wire [`FREG_DATA_WIDTH-1:0] fpreg_wdata_o,
    output wire                        fpreg_we_o,
    output wire [`FREG_ADDR_WIDTH-1:0] fpreg_waddr_o
);
    // 判断地址最高位是否为浮点寄存器
    wire lsu_fp_active = lsu_reg_we_i && lsu_reg_waddr_i[`REG_ADDR_WIDTH-1];
    wire fpu_fp_active = fpu_reg_we_i && fpu_reg_waddr_i[`REG_ADDR_WIDTH-1];
    wire fpu_int_active = fpu_reg_we_i && !fpu_reg_waddr_i[`REG_ADDR_WIDTH-1];

    // 普通寄存器写回来源
    wire lsu_int_active = lsu_reg_we_i && !lsu_reg_waddr_i[`REG_ADDR_WIDTH-1];
    wire muldiv_active = muldiv_reg_we_i;
    wire csr_active = csr_reg_we_i;
    wire alu_active = alu_reg_we_i;

    // 浮点寄存器写回仲裁：lsu优先，其次fpu
    wire fpreg_lsu_en = lsu_fp_active;
    wire fpreg_fpu_en = fpu_fp_active && !lsu_fp_active;

    // fpu_ready_o信号：只有当没有lsu_fp_active时允许fpu写回浮点寄存器
    assign fpu_ready_o = !lsu_fp_active;

    // 普通寄存器写回仲裁：lsu > muldiv > fpu_int > csr > alu
    wire reg_lsu_en = lsu_int_active;
    wire reg_muldiv_en = muldiv_active && !lsu_int_active;
    wire reg_fpu_en = fpu_int_active && !lsu_int_active && !muldiv_active;
    wire reg_csr_en = csr_active && !lsu_int_active && !muldiv_active && !fpu_int_active;
    wire reg_alu_en    = alu_active && !lsu_int_active && !muldiv_active && !fpu_int_active && !csr_active;

    // ready信号
    assign muldiv_ready_o = !lsu_int_active;
    assign fpu_ready_o    = !lsu_fp_active;
    assign csr_ready_o    = !lsu_int_active && !muldiv_active && !fpu_int_active;
    assign alu_ready_o    = !lsu_int_active && !muldiv_active && !fpu_int_active && !csr_active;

    // 普通寄存器写回有效
    wire reg_we_effective = reg_lsu_en || reg_muldiv_en || reg_fpu_en || reg_csr_en || reg_alu_en;

    // 普通寄存器写回数据选择
    assign reg_wdata_o = ({`REG_DATA_WIDTH{reg_lsu_en}}    & lsu_reg_wdata_i)   |
                         ({`REG_DATA_WIDTH{reg_muldiv_en}} & muldiv_reg_wdata_i)|
                         ({`REG_DATA_WIDTH{reg_fpu_en}}    & fpu_reg_wdata_i)  |
                         ({`REG_DATA_WIDTH{reg_csr_en && csr_reg_we_i}} & csr_reg_wdata_i)|
                         ({`REG_DATA_WIDTH{reg_alu_en}}    & alu_reg_wdata_i);

    assign reg_waddr_o = ({`GREG_ADDR_WIDTH{reg_lsu_en}}    & lsu_reg_waddr_i)   |
                         ({`GREG_ADDR_WIDTH{reg_muldiv_en}} & muldiv_reg_waddr_i)|
                         ({`GREG_ADDR_WIDTH{reg_fpu_en}}    & fpu_reg_waddr_i)  |
                         ({`GREG_ADDR_WIDTH{reg_csr_en && csr_reg_we_i}} & csr_reg_waddr_i)|
                         ({`GREG_ADDR_WIDTH{reg_alu_en}}    & alu_reg_waddr_i);

    assign reg_we_o = reg_we_effective;

    // 浮点寄存器写回数据选择
    assign fpreg_wdata_o = fpreg_lsu_en ? lsu_reg_wdata_i :
                           fpreg_fpu_en ? fpu_reg_wdata_i : {`REG_DATA_WIDTH{1'b0}};
    assign fpreg_waddr_o = fpreg_lsu_en ? lsu_reg_waddr_i[`FREG_ADDR_WIDTH-1:0] :
                           fpreg_fpu_en ? fpu_reg_waddr_i[`FREG_ADDR_WIDTH-1:0] : {`FREG_ADDR_WIDTH{1'b0}};
    assign fpreg_we_o = fpreg_lsu_en || fpreg_fpu_en;

    // CSR写回信号
    assign csr_we_o = csr_we_i;
    assign csr_wdata_o = csr_wdata_i;
    assign csr_waddr_o = csr_waddr_i;

    // commit信号
    assign commit_valid_int_o = lsu_int_active || muldiv_active || csr_active || fpu_int_active || alu_active;
    assign commit_valid_fp_o = fpu_fp_active || lsu_fp_active;

    // 整数寄存器相关commit_id
    assign commit_id_int_o = lsu_int_active  ? lsu_commit_id_i :
                             muldiv_active   ? muldiv_commit_id_i :
                             csr_active      ? csr_commit_id_i :
                             fpu_int_active  ? fpu_commit_id_i :
                             alu_active      ? alu_commit_id_i :
                             {`COMMIT_ID_WIDTH{1'b0}};

    // 浮点寄存器相关commit_id
    assign commit_id_fp_o = fpu_fp_active    ? fpu_commit_id_i :
                            lsu_fp_active   ? lsu_commit_id_i :
                            {`COMMIT_ID_WIDTH{1'b0}};

endmodule
