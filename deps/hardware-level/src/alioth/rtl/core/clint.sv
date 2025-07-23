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

    // from id
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        atom_opt_busy_i, // 原子操作忙标志

    // 添加系统操作输入端口
    input wire                        sys_op_ecall_i,
    input wire                        sys_op_ebreak_i,
    input wire                        sys_op_mret_i,
    input wire                        illegal_inst_i,     // 非法指令
    input wire [`INST_ADDR_WIDTH-1:0] illegal_inst_pc_i,  // 非法指令发生时的PC
    input wire [ `REG_DATA_WIDTH-1:0] illegal_inst_val_i, // 非法指令内容

    input wire misaligned_load_i,  // Misaligned Load异常输入端口
    input wire misaligned_store_i, // Misaligned Store异常输入端口

    input wire [`INST_ADDR_WIDTH-1:0] ex_exception_pc_i,  // Ex阶段发生异常时的PC
    input wire [ `REG_DATA_WIDTH-1:0] ex_exception_val_i, // Ex阶段发生异常时的指令内容

    // 非对齐取指异常相关端口
    input wire misaligned_fetch_i,  // 非对齐取指异常输入端口

    // === 外部中断输入 ===
    input wire       irq_req_i,
    input wire [7:0] irq_id_i,

    // from ctrl
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i,

    // from csr_reg
    input wire [`REG_DATA_WIDTH-1:0] data_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_mtvec,
    input wire [`REG_DATA_WIDTH-1:0] csr_mepc,
    input wire [`REG_DATA_WIDTH-1:0] csr_mstatus,

    input wire global_int_en_i,  // 全局中断使能标志

    // to ctrl
    output wire flush_flag_o,  // 用于刷新流水线
    output wire stall_flag_o,  // 用于暂停流水线

    // to csr_reg
    output reg                       we_o,
    output reg [`BUS_ADDR_WIDTH-1:0] waddr_o,
    output reg [`BUS_ADDR_WIDTH-1:0] raddr_o,
    output reg [`REG_DATA_WIDTH-1:0] data_o,

    // to ex
    output reg [`INST_ADDR_WIDTH-1:0] int_addr_o,   //ecall和ebreak的返回地址
    output reg                        int_assert_o  //ecall和ebreak的中断信号
);


    // interrupt state machine类型定义
    typedef enum logic [3:0] {
        S_INT_IDLE   = 4'b0001,  // 空闲状态
        S_INT_ASSERT = 4'b0010,  // 同步中断断言状态
        S_INT_MRET   = 4'b0100   // 中断返回状态
    } int_state_e;

    // CSR写状态机类型定义
    typedef enum logic [5:0] {
        S_CSR_IDLE         = 6'b000001,
        S_CSR_MSTATUS      = 6'b000010,
        S_CSR_MEPC         = 6'b000100,
        S_CSR_MSTATUS_MRET = 6'b001000,
        S_CSR_MCAUSE       = 6'b010000,
        S_CSR_MTVAL        = 6'b100000
    } csr_state_e;

    // 状态机和相关信号声明
    int_state_e int_state;  // 中断状态机当前状态
    csr_state_e csr_state;  // CSR写状态机当前状态
    reg [`INST_ADDR_WIDTH-1:0] inst_addr;  // 保存的指令地址
    reg [31:0] cause;  // 中断原因代码

    // === 新增：外部中断请求检测 ===
    wire ext_irq_req = irq_req_i & global_int_en_i;

    // === 修改异常请求检测，外部中断优先级最低 ===
    wire internal_exception_req = (sys_op_ecall_i || sys_op_ebreak_i || illegal_inst_i
                                   || misaligned_load_i || misaligned_store_i
                                   || misaligned_fetch_i);
    wire exception_req = internal_exception_req ? 1'b1 : ext_irq_req;

    // 暂停信号产生逻辑 - 当中断状态机或CSR写状态机不在空闲状态时冲刷水线
    assign flush_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE));
    assign stall_flag_o = (exception_req && atom_opt_busy_i);

    // 中断状态机逻辑
    always @(*) begin
        if (~rst_n) begin
            int_state = S_INT_IDLE;
        end else if (exception_req && atom_opt_busy_i == 1'b0) begin
            int_state = S_INT_ASSERT;
        end else if (sys_op_mret_i) begin
            int_state = S_INT_MRET;
        end else begin
            int_state = S_INT_IDLE;
        end
    end

    // CSR写状态机的状态转换逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            csr_state <= S_CSR_IDLE;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    if (int_state == S_INT_ASSERT) begin
                        csr_state <= S_CSR_MEPC;
                    end else if (int_state == S_INT_MRET) begin
                        csr_state <= S_CSR_MSTATUS_MRET;
                    end
                end
                S_CSR_MEPC: begin
                    csr_state <= S_CSR_MSTATUS;
                end
                S_CSR_MSTATUS: begin
                    if (illegal_inst_i)
                        csr_state <= S_CSR_MTVAL; // 新增：非法指令异常时进入mtval写状态
                    else csr_state <= S_CSR_MCAUSE;
                end
                S_CSR_MTVAL: begin
                    csr_state <= S_CSR_MCAUSE;  // 新增：写完mtval后写mcause
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

    // 中断原因寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cause <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_ASSERT) begin
            if (internal_exception_req) begin
                if (sys_op_ecall_i) begin
                    cause <= 32'd11;
                end else if (sys_op_ebreak_i) begin
                    cause <= 32'd3;
                end else if (misaligned_fetch_i) begin
                    cause <= 32'd0;  // 指令地址非对齐异常
                end else if (misaligned_load_i) begin
                    cause <= 32'd4;  // Misaligned Load
                end else if (misaligned_store_i) begin
                    cause <= 32'd6;  // Misaligned Store
                end else if (illegal_inst_i) begin
                    cause <= 32'd2;  // 非法指令
                end else begin
                    cause <= 32'd10;
                end
            end else if (ext_irq_req) begin
                cause <= 32'h8 + {24'h0, irq_id_i};  // 外部中断cause
            end
        end
    end

    // 删除多余的异常内容寄存器，只保留非法指令内容
    reg [`REG_DATA_WIDTH-1:0] illegal_inst_val_reg;  // 新增：保存非法指令内容
    // 新增：保存MTVAL内容
    reg [`REG_DATA_WIDTH-1:0] mtval_reg;

    // 保存异常内容
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            illegal_inst_val_reg <= `ZeroWord;
            mtval_reg            <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_ASSERT) begin
            // 非法指令内容
            if (misaligned_fetch_i) begin
                mtval_reg <= 0;
            end else if (misaligned_load_i || misaligned_store_i) begin
                mtval_reg <= ex_exception_val_i;
            end else if (jump_flag_i == `JumpEnable) begin
                mtval_reg <= `ZeroWord;
            end else if (illegal_inst_i) begin
                mtval_reg <= illegal_inst_val_i;
            end else begin
                mtval_reg <= `ZeroWord;
            end
        end
    end

    // 保存指令地址寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_addr <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_ASSERT) begin
            if (misaligned_fetch_i) begin
                inst_addr <= ex_exception_pc_i;  // 非对齐取指异常时共用ex_exception_pc_i
            end else if (misaligned_load_i || misaligned_store_i) begin
                inst_addr <= ex_exception_pc_i;  // Misaligned异常时用共用PC
            end else if (jump_flag_i == `JumpEnable) begin
                inst_addr <= jump_addr_i - 4'h4;
            end else if (illegal_inst_i) begin
                inst_addr <= illegal_inst_pc_i;  // 非法指令异常时用非法指令PC
            end else if (sys_op_ecall_i || sys_op_ebreak_i) begin
                inst_addr <= inst_addr_i;
            end else if (ext_irq_req) begin
                inst_addr <= inst_addr_i + 4; // 外部中断时保存pc+4，优先级最低
            end else begin
                inst_addr <= inst_addr_i;
            end
        end
    end

    // CSR写使能、写地址和写数据逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            we_o    <= `WriteDisable;
            waddr_o <= `ZeroWord;
            data_o  <= `ZeroWord;
        end else begin
            case (csr_state)
                S_CSR_MEPC: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MEPC};
                    data_o  <= inst_addr;
                end
                S_CSR_MSTATUS: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o  <= {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]};
                end
                S_CSR_MTVAL: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MTVAL};
                    data_o  <= mtval_reg;
                end
                S_CSR_MCAUSE: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o  <= cause;
                end
                // -----------------------------------------------------------------------------
                // MRET指令处理：
                // 当检测到S_CSR_MSTATUS_MRET时，表示执行RISC-V的MRET（Machine-mode Return）指令。
                // 根据RISC-V官方规范，MRET用于从机器模式异常返回，并需要恢复之前保存的全局中断使能状态（MIE）。
                // 此处对csr_mstatus寄存器进行如下操作：
                //   - 将MIE位（csr_mstatus[7]）恢复到MPIE位（csr_mstatus[3]），并将MPIE位置为1（csr_mstatus[7] -> csr_mstatus[3], csr_mstatus[7] = 1）。
                //   - 其他位保持不变。
                //   - 最终结果写回mstatus CSR（地址为`CSR_MSTATUS`）。
                //   - we_o信号使能写操作，waddr_o指定目标CSR地址，data_o为写入的新mstatus值。
                // 这样保证了异常返回后，机器模式的中断使能状态按照RISC-V规范正确恢复。
                // -----------------------------------------------------------------------------
                S_CSR_MSTATUS_MRET: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {
                        csr_mstatus[31:8], 1'b1, csr_mstatus[6:4], csr_mstatus[7], csr_mstatus[2:0]
                    };
                end
                default: begin
                    we_o <= `WriteDisable;
                end
            endcase
        end
    end

    // 中断断言信号和中断地址逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            int_assert_o <= `INT_DEASSERT;
            int_addr_o   <= `ZeroWord;
        end else begin
            case (csr_state)
                S_CSR_MCAUSE: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o   <= csr_mtvec;
                end
                S_CSR_MSTATUS_MRET: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o   <= csr_mepc;
                end
                default: begin
                    int_assert_o <= `INT_DEASSERT;
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
