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
    input wire [ `REG_DATA_WIDTH-1:0] inst_data_i,  // 非法指令内容
    input wire                        inst_valid_i, // 指令有效标志

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        atom_opt_busy_i, // 原子操作忙标志

    // 添加系统操作输入端口
    input wire sys_op_ecall_i,
    input wire sys_op_ebreak_i,
    input wire sys_op_mret_i,
    input wire illegal_inst_i,     // 非法指令
    input wire misaligned_load_i,  // Misaligned Load异常输入端口
    input wire misaligned_store_i, // Misaligned Store异常输入端口

    // 非对齐取指异常相关端口
    input wire misaligned_fetch_i,  // 非对齐取指异常输入端口

    // === 外部中断输入 ===
    input wire ext_int_req_i,

    // from ctrl
    input wire [`CU_BUS_WIDTH-1:0] stall_flag_i,

    // from csr_reg
    input wire [`REG_DATA_WIDTH-1:0] data_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_mtvec,
    input wire [`REG_DATA_WIDTH-1:0] csr_mepc,
    input wire [`REG_DATA_WIDTH-1:0] csr_mstatus,
    input wire [`REG_DATA_WIDTH-1:0] csr_mie,

    // EXU暂停信号输入
    input wire exu_stall_i,

    // to csr_reg
    output reg                       we_o,
    output reg [`BUS_ADDR_WIDTH-1:0] waddr_o,
    output reg [`BUS_ADDR_WIDTH-1:0] raddr_o,
    output reg [`REG_DATA_WIDTH-1:0] data_o,

    // to ex
    output reg  [`INST_ADDR_WIDTH-1:0] int_addr_o,
    output reg                         int_jump_o,
    output wire                        int_assert_o, // 中断断言输出信号

    output wire clint_req_valid_o,  // 中断请求有效信号

    // === AXI4-Lite slave interface for clint_swi ===
    input  wire                                 S_AXI_ACLK,
    input  wire                                 S_AXI_ARESETN,
    input  wire [  `CLINT_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire [                          2:0] S_AXI_AWPROT,
    input  wire                                 S_AXI_AWVALID,
    output wire                                 S_AXI_AWREADY,
    input  wire [  `CLINT_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire [(`CLINT_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                                 S_AXI_WVALID,
    output wire                                 S_AXI_WREADY,
    output wire [                          1:0] S_AXI_BRESP,
    output wire                                 S_AXI_BVALID,
    input  wire                                 S_AXI_BREADY,
    input  wire [  `CLINT_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input  wire [                          2:0] S_AXI_ARPROT,
    input  wire                                 S_AXI_ARVALID,
    output wire                                 S_AXI_ARREADY,
    output wire [  `CLINT_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [                          1:0] S_AXI_RRESP,
    output wire                                 S_AXI_RVALID,
    input  wire                                 S_AXI_RREADY
);

    // 合并后的中断状态机类型定义
    typedef enum logic [6:0] {
        S_INT_IDLE         = 7'b0000001,
        S_INT_PENDING      = 7'b0000010,
        // S_INT_MRET        = 7'b0000100, // 删除
        S_INT_MEPC         = 7'b0001000,
        S_INT_MSTATUS      = 7'b0010000,
        S_INT_MTVAL        = 7'b0100000,
        S_INT_MCAUSE       = 7'b1000000,
        S_INT_MSTATUS_MRET = 7'b0000011
    } int_state_e;

    int_state_e                        int_state;  // 合并后的状态机

    reg         [`INST_ADDR_WIDTH-1:0] saved_pc;  // 保存的PC地址
    reg         [                31:0] cause;  // 中断原因代码

    reg jump_flag_r, inst_valid_r;
    reg [`REG_DATA_WIDTH-1:0] inst_data_r;  // 保存的指令数据

    // 新增：mret_req寄存器
    reg mret_req;

    wire global_int_en = (csr_mstatus[3] == 1'b1);  // 全局中断使能标志

    // === 定义MEIE、MTIE、MSIE ===
    wire MEIE = csr_mie[11];  // Machine External Interrupt Enable
    wire MTIE = csr_mie[7];  // Machine Timer Interrupt Enable
    wire MSIE = csr_mie[3];  // Machine Software Interrupt Enable

    // === 定时器中断和软件中断信号 ===
    wire timer_irq;
    wire soft_irq;

    // === 中断请求检测（受csr_mie控制）===
    wire ext_irq_en = ext_int_req_i & MEIE;
    wire timer_irq_en = timer_irq & MTIE;
    wire soft_irq_en = soft_irq & MSIE;

    // === exception_req/int_req/jump_flag_i/inst_valid_i/inst_addr_i/inst_data_i打一拍 ===
    wire exception_req = (sys_op_ecall_i || sys_op_ebreak_i || illegal_inst_i
                            || misaligned_load_i || misaligned_store_i
                            || misaligned_fetch_i);

    wire int_env_valid = (atom_opt_busy_i == 1'b0);

    wire int_req = (ext_irq_en | timer_irq_en | soft_irq_en) & global_int_en;

    // wire exception_or_int = exception_req_r | int_req_r;
    wire exception_or_int = exception_req | int_req;
    wire int_pending = (int_state == S_INT_PENDING);
    wire exception_or_int_valid = (exception_or_int && !exu_stall_i && inst_valid_i);

    assign int_assert_o      = int_pending;

    assign clint_req_valid_o = exception_or_int_valid | sys_op_mret_i;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            int_state    <= S_INT_IDLE;
            jump_flag_r  <= 1'b0;
            inst_valid_r <= 1'b0;
            inst_data_r  <= {`REG_DATA_WIDTH{1'b0}};
            saved_pc     <= `ZeroWord;
            mret_req     <= 1'b0;
        end else begin
            case (int_state)
                S_INT_IDLE: begin
                    mret_req <= 1'b0;  // 清除mret_req标志
                    if (exception_or_int_valid) begin
                        int_state    <= S_INT_PENDING;
                        jump_flag_r  <= jump_flag_i;
                        inst_valid_r <= inst_valid_i;
                        inst_data_r  <= inst_data_i;
                        // 整合保存PC逻辑
                        if (exception_req) begin
                            saved_pc <= inst_addr_i;
                        end else if (int_req) begin
                            if (jump_flag_i) begin
                                saved_pc <= jump_addr_i;
                            end else begin
                                saved_pc <= inst_addr_i + 4;
                            end
                        end
                    end else if (sys_op_mret_i) begin
                        mret_req  <= 1'b1;  // 设置mret_req标志
                        int_state <= S_INT_PENDING;
                    end else begin
                        int_state <= S_INT_IDLE;
                    end
                end
                S_INT_PENDING: begin
                    if (int_env_valid) begin
                        // 判断mret_req分支
                        if (mret_req) int_state <= S_INT_MSTATUS_MRET;
                        else int_state <= S_INT_MEPC;
                    end else int_state <= S_INT_PENDING;
                end
                S_INT_MEPC: begin
                    int_state <= S_INT_MSTATUS;
                end
                S_INT_MSTATUS: begin
                    if (illegal_inst_i) int_state <= S_INT_MTVAL;
                    else int_state <= S_INT_MCAUSE;
                end
                S_INT_MTVAL: begin
                    int_state <= S_INT_MCAUSE;
                end
                S_INT_MCAUSE: begin
                    int_state <= S_INT_IDLE;
                end
                // S_INT_MRET: begin
                //     int_state <= S_INT_MSTATUS_MRET;
                // end
                S_INT_MSTATUS_MRET: begin
                    int_state <= S_INT_IDLE;
                end
                default: int_state <= S_INT_IDLE;
            endcase
        end
    end

    // cause更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cause <= `ZeroWord;
        end else if (int_state == S_INT_IDLE) begin
            // if (exception_req_r) begin
            if (exception_req) begin
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
                // end else if (int_req_r) begin
            end else if (int_req) begin
                // === 按优先级选择 cause ===
                // 优先级：外部最高 > 定时器 > 软件
                if (ext_irq_en) begin
                    // 外部中断
                    cause <= 32'h8000000B;  // 外部中断 cause = 11 | 0x80000000
                end else if (timer_irq_en) begin
                    // 定时器中断 cause = 7 | 0x80000000
                    cause <= 32'h80000007;
                end else if (soft_irq_en) begin
                    // 软件中断 cause = 3 | 0x80000000
                    cause <= 32'h80000003;
                end
            end
        end
    end

    // 删除异常信号打一拍相关内容
    reg [`REG_DATA_WIDTH-1:0] illegal_inst_val_reg;  // 新增：保存非法指令内容
    // 新增：保存MTVAL内容
    reg [`REG_DATA_WIDTH-1:0] mtval_reg;

    // 保存异常内容
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            illegal_inst_val_reg <= `ZeroWord;
            mtval_reg            <= `ZeroWord;
        end else if (int_state == S_INT_MEPC) begin
            // 非法指令内容
            if (misaligned_fetch_i) begin
                mtval_reg <= 0;
            end else if (misaligned_load_i || misaligned_store_i) begin
                mtval_reg <= inst_data_r;
            end else if (jump_flag_r == `JumpEnable) begin
                mtval_reg <= `ZeroWord;
            end else if (illegal_inst_i) begin
                mtval_reg <= inst_data_r;
            end else begin
                mtval_reg <= `ZeroWord;
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
            case (int_state)
                S_INT_MEPC: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MEPC};
                    data_o  <= saved_pc;
                end
                S_INT_MSTATUS: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {
                        csr_mstatus[31:8], csr_mstatus[3], csr_mstatus[6:4], 1'b0, csr_mstatus[2:0]
                    };
                end
                S_INT_MTVAL: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MTVAL};
                    data_o  <= mtval_reg;
                end
                S_INT_MCAUSE: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o  <= cause;
                end
                S_INT_MSTATUS_MRET: begin
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

    // 中断跳转信号和中断地址逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            int_jump_o <= `INT_DEASSERT;
            int_addr_o <= `ZeroWord;
        end else begin
            if (int_state == S_INT_IDLE) begin
                int_jump_o <= 1'b0;
                int_addr_o <= `ZeroWord;
            end else if ((int_state == S_INT_PENDING) && (int_env_valid)) begin
                // 判断mret_req分支
                if (mret_req) begin
                    int_jump_o <= 1'b1;
                    int_addr_o <= csr_mepc;
                end else begin
                    int_jump_o <= 1'b1;
                    if (int_req && csr_mtvec[0]) begin
                        int_addr_o <= {csr_mtvec[31:2], 2'b00} + ((cause[3:0]) << 2);
                    end else begin
                        int_addr_o <= csr_mtvec;
                    end
                end
            end else begin
                int_jump_o <= `INT_DEASSERT;
                int_addr_o <= `ZeroWord;
            end
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


    // === clint_swi实例化 ===
    clint_swi #(
        .C_S_AXI_DATA_WIDTH(`CLINT_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(`CLINT_AXI_ADDR_WIDTH)
    ) u_clint_swi (
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR (S_AXI_AWADDR),
        .S_AXI_AWPROT (S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA  (S_AXI_WDATA),
        .S_AXI_WSTRB  (S_AXI_WSTRB),
        .S_AXI_WVALID (S_AXI_WVALID),
        .S_AXI_WREADY (S_AXI_WREADY),
        .S_AXI_BRESP  (S_AXI_BRESP),
        .S_AXI_BVALID (S_AXI_BVALID),
        .S_AXI_BREADY (S_AXI_BREADY),
        .S_AXI_ARADDR (S_AXI_ARADDR),
        .S_AXI_ARPROT (S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA  (S_AXI_RDATA),
        .S_AXI_RRESP  (S_AXI_RRESP),
        .S_AXI_RVALID (S_AXI_RVALID),
        .S_AXI_RREADY (S_AXI_RREADY),
        .timer_irq    (timer_irq),
        .soft_irq     (soft_irq)
    );

endmodule
