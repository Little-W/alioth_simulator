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

// 冒险检测单元 - 处理长指令的RAW和WAW相关性
module hdu (
    input wire clk,   // 时钟
    input wire rst_n, // 复位信号，低电平有效

    // 新指令信息
    input wire                          inst_valid,  // 新长指令有效
    input wire [   `REG_ADDR_WIDTH-1:0] rd_addr,     // 新指令写寄存器地址
    input wire [   `REG_ADDR_WIDTH-1:0] rs1_addr,    // 新指令读寄存器1地址
    input wire [   `REG_ADDR_WIDTH-1:0] rs2_addr,    // 新指令读寄存器2地址
    input wire                          rd_we,       // 新指令是否写寄存器
    input wire                          rs1_re,      // 是否检测rs1
    input wire                          rs2_re,      // 是否检测rs2
    input wire [`EX_INFO_BUS_WIDTH-1:0] ex_info_bus, // 新增：指令ex单元类型

    // 长指令完成信号
    input wire                        commit_valid_i,  // 长指令执行完成有效信号
    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,     // 执行完成的长指令ID

    // 控制信号
    output wire hazard_stall_o,  // 暂停流水线信号
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id_o,  // 为新的长指令分配的ID
    output wire long_inst_atom_lock_o  // 原子锁信号，FIFO中有未销毁的长指令时为1
);

    // 定义FIFO表项结构
    typedef struct packed {
        logic [`REG_ADDR_WIDTH-1:0] rd_addr;
        logic [`EX_INFO_BUS_WIDTH-1:0] exu_type;
    } fifo_entry_t;

    reg          [7:0] fifo_valid;  // 有效位，深度8
    fifo_entry_t       fifo_entry                         [0:7];  // 存储表项结构体，深度8

    // 冒险检测信号
    reg                raw_hazard;  // 读后写冒险
    reg                waw_hazard;  // 写后写冒险
    wire               hazard;  // 总冒险信号

    // 并行冒险检测信号
    wire         [7:0] raw_hazard_vec;
    wire         [7:0] waw_hazard_vec;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : hazard_vec_gen
            assign raw_hazard_vec[i] = fifo_valid[i] && !(commit_valid_i && commit_id_i == i) &&
                ((rs1_re && rs1_addr == fifo_entry[i].rd_addr) || (rs2_re && rs2_addr == fifo_entry[i].rd_addr));
            // waw检测：只有exu_type不同才算冲突
            assign waw_hazard_vec[i] = fifo_valid[i] && !(commit_valid_i && commit_id_i == i) &&
                (rd_we && rd_addr == fifo_entry[i].rd_addr && ex_info_bus != fifo_entry[i].exu_type);
        end
    endgenerate

    assign raw_hazard = |raw_hazard_vec;
    assign waw_hazard = |waw_hazard_vec;

    // 只有在有新指令且存在冒险时才暂停流水线
    assign hazard = (raw_hazard || waw_hazard);
    assign hazard_stall_o = hazard || (&fifo_valid);  // 如果FIFO已满也暂停流水线

    // 为新的长指令分配ID - 使用assign语句
    assign commit_id_o = (inst_valid && ~hazard) ?
        ( ~fifo_valid[0] ? 0 :
          ~fifo_valid[1] ? 1 :
          ~fifo_valid[2] ? 2 :
          ~fifo_valid[3] ? 3 :
          ~fifo_valid[4] ? 4 :
          ~fifo_valid[5] ? 5 :
          ~fifo_valid[6] ? 6 :
          ~fifo_valid[7] ? 7 : 0 ) : 0;

    // 更新FIFO
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 复位时清空FIFO
            for (int i = 0; i < 8; i = i + 1) begin
                fifo_valid[i]          <= 1'b0;
                fifo_entry[i].rd_addr  <= 5'h0;
                fifo_entry[i].exu_type <= {`EX_INFO_BUS_WIDTH{1'b0}};
            end
        end else begin
            // 清除已完成的长指令
            if (commit_valid_i) begin
                fifo_valid[commit_id_i] <= 1'b0;
            end

            // 添加新的长指令到FIFO
            if (inst_valid && ~hazard) begin
                fifo_valid[commit_id_o]          <= 1'b1;
                fifo_entry[commit_id_o].rd_addr  <= rd_addr;
                fifo_entry[commit_id_o].exu_type <= ex_info_bus;
            end
        end
    end

    // 生成原子锁信号 - 当FIFO中有任何一个有效的长指令时为1
    assign long_inst_atom_lock_o = |fifo_valid;
endmodule
