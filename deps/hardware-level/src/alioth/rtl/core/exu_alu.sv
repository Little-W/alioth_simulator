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

`include "defines.svh"

// 算术逻辑单元
module exu_alu (
    input wire rst_n,

    // ALU
    input wire        req_alu_i,
    input wire [31:0] alu_op1_i,
    input wire [31:0] alu_op2_i,
    input wire        alu_op_add_i,
    input wire        alu_op_sub_i,
    input wire        alu_op_sll_i,
    input wire        alu_op_slt_i,
    input wire        alu_op_sltu_i,
    input wire        alu_op_xor_i,
    input wire        alu_op_srl_i,
    input wire        alu_op_sra_i,
    input wire        alu_op_or_i,
    input wire        alu_op_and_i,
    input wire        alu_op_lui_i,
    input wire        alu_op_auipc_i,
    input wire        alu_op_jump_i,
    input wire [ 4:0] alu_rd_i,

    // 中断信号
    input wire int_assert_i,

    // 结果输出
    output wire [`REG_DATA_WIDTH-1:0] result_o,
    output wire                       reg_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg_waddr_o
);

    // ALU操作数选择
    wire [31:0] mux_op1 = alu_op1_i;
    wire [31:0] mux_op2 = alu_op2_i;
    // ALU运算类型选择(包括R与I类型)
    wire        op_add;
    wire        op_sub;
    wire        op_sll;
    wire        op_slt;
    wire        op_sltu;
    wire        op_xor;
    wire        op_srl;
    wire        op_sra;
    wire        op_or;
    wire        op_and;
    wire        op_lui;
    wire        op_auipc;
    wire        op_jump;

    wire [31:0] xor_res = mux_op1 ^ mux_op2;  //异或
    wire [31:0] or_res = mux_op1 | mux_op2;  //  或
    wire [31:0] and_res = mux_op1 & mux_op2;  // 与
    //加、减
    wire [31:0] add_op1 = mux_op1;
    wire [31:0] add_op2 = mux_op2;
    wire [31:0] add_sub_res = add_op1 + (op_sub ? (-add_op2) : add_op2);
    //左移
    wire [31:0] sll_res = mux_op1 << mux_op2[4:0];
    //逻辑右移
    wire [31:0] srl_res = mux_op1 >> mux_op2[4:0];
    //算数右移  
    wire [31:0] sr_shift_mask = 32'hffffffff >> mux_op2[4:0];
    wire [31:0] sra_res = (srl_res & sr_shift_mask) | ({32{mux_op1[31]}} & (~sr_shift_mask));
    //有符号数比较 op2>op1
    wire        op2_ge_op1_signed = ($signed(mux_op2) > $signed(mux_op1));
    // 无符号数比较 op2>op1
    wire        op2_ge_op1_unsigned = (mux_op2 > mux_op1);

    wire [31:0] slt_res = (op2_ge_op1_signed) ? 32'h1 : 32'h0;
    wire [31:0] sltu_res = (op2_ge_op1_unsigned) ? 32'h1 : 32'h0;

    reg  [31:0] alu_res;
    always @(*) begin
        if (int_assert_i == `INT_ASSERT) begin
            alu_res = 32'h0;
        end else begin
            alu_res = 32'h0;
            if (req_alu_i) begin
                case (1'b1)  //优先级判断
                    op_xor: alu_res = xor_res;
                    op_or: alu_res = or_res;
                    op_and: alu_res = and_res;
                    op_add: alu_res = add_sub_res;
                    op_sub: alu_res = add_sub_res;
                    op_sll: alu_res = sll_res;
                    op_srl: alu_res = srl_res;
                    op_sra: alu_res = sra_res;
                    op_slt: alu_res = slt_res;
                    op_sltu: alu_res = sltu_res;
                    op_lui: alu_res = add_sub_res;
                    op_auipc: alu_res = add_sub_res;
                endcase
            end else if (op_jump) begin
                // 处理跳转指令
                alu_res = add_sub_res;
            end
        end
    end

    assign result_o = alu_res;
    wire [4:0] rd = alu_rd_i;
    // 写使能逻辑
    reg        alu_reg_we;
    always @(*) begin
        if (int_assert_i == `INT_ASSERT) begin
            alu_reg_we = `WriteDisable;
        end else begin
            // 所有算术逻辑操作都需要写回寄存器
            alu_reg_we = (req_alu_i | op_jump) ? `WriteEnable : `WriteDisable;
        end
    end

    assign reg_we_o = alu_reg_we;
    // 目标寄存器地址逻辑
    reg [4:0] alu_reg_waddr;
    always @(*) begin
        if (int_assert_i == `INT_ASSERT) begin
            alu_reg_waddr = 5'b0;
        end else begin
            alu_reg_waddr = rd;
        end
    end
    assign reg_waddr_o = alu_reg_waddr;
    assign {op_add, op_sub, op_sll, op_slt, op_sltu, op_xor, op_srl, op_sra, op_or, op_and, op_lui, op_auipc, op_jump} = {
        alu_op_add_i,
        alu_op_sub_i,
        alu_op_sll_i,
        alu_op_slt_i,
        alu_op_sltu_i,
        alu_op_xor_i,
        alu_op_srl_i,
        alu_op_sra_i,
        alu_op_or_i,
        alu_op_and_i,
        alu_op_lui_i,
        alu_op_auipc_i,
        alu_op_jump_i
    };

endmodule
