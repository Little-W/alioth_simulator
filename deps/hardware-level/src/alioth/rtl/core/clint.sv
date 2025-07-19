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


<<<<<<< Updated upstream
    // from id
    input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,

    // from ex
    input wire                        jump_flag_i,
    input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
    input wire                        atom_opt_busy_i, // 原子操作忙标志

    // 添加系统操作输入端口
    input wire sys_op_ecall_i,
    input wire sys_op_ebreak_i,
    input wire sys_op_mret_i,
=======
        input wire clk,
        input wire rst_n,
        input wire int_req_i,    //外部中断请求
        input wire[7:0] int_id_i,//外部中断ID

        //ex内部接线
        input wire inst_dret_i,

        // from id
        input wire [`INST_ADDR_WIDTH-1:0] inst_addr_i,
        input wire                        inst_valid_i,  // 指令有效信号

        // from ex
        input wire                        jump_flag_i,
        input wire [`INST_ADDR_WIDTH-1:0] jump_addr_i,
        input wire                        atom_opt_busy_i,  // 原子操作忙标志
>>>>>>> Stashed changes

        // 添加系统操作输入端口
        input wire sys_op_ecall_i,
        input wire sys_op_ebreak_i,
        input wire sys_op_mret_i,

<<<<<<< Updated upstream
    // from csr_reg
    input wire [`REG_DATA_WIDTH-1:0] data_i,
    input wire [`REG_DATA_WIDTH-1:0] csr_mtvec,
    input wire [`REG_DATA_WIDTH-1:0] csr_mepc,
    input wire [`REG_DATA_WIDTH-1:0] csr_mstatus,
=======
        //新增系统操作
        input wire sys_op_executed_i, // 新增执行完成信号
        input wire sys_op_dret_i,      // 新增调试返回信号**

        // from ctrl
        input wire [`CU_BUS_WIDTH-1:0] stall_flag_i,

        // from csr_reg
        input wire [`REG_DATA_WIDTH-1:0] data_i,
        input wire [`REG_DATA_WIDTH-1:0] csr_mtvec,
        input wire [`REG_DATA_WIDTH-1:0] csr_mepc,
        input wire [`REG_DATA_WIDTH-1:0] csr_mstatus,

        //新增csr寄存器输入
        input wire [`REG_DATA_WIDTH-1:0] csr_mie_i,                     // mie寄存器(似乎没有用到)
        input wire [`REG_DATA_WIDTH-1:0] csr_dpc_i,                     // dpc寄存器
        input wire [`REG_DATA_WIDTH-1:0] csr_dcsr_i,                    // dcsr寄存器

        input wire trigger_match_i,

        input wire global_int_en_i,  // 全局中断使能标志

        // to ctrl
        output wire flush_flag_o,  // 用于刷新流水线
        output wire stall_flag_o,  // 用于暂停流水线

        // to csr_reg
        output reg                       we_o,
        output reg [`BUS_ADDR_WIDTH-1:0] waddr_o,
        output reg [`BUS_ADDR_WIDTH-1:0] raddr_o,//似乎clint不需要进行读操作
        output reg [`REG_DATA_WIDTH-1:0] data_o,

        // to ex
        output reg [`INST_ADDR_WIDTH-1:0] int_addr_o,   //ecall和ebreak的返回地址
        output reg                        int_assert_o  //ecall和ebreak的中断信号
    );

    reg[7:0]  int_id_next,int_id_now;
    reg in_irq_context_next,in_irq_context_now;
    // 新增异常请求信号和异常原因代码
    wire int_or_exception_req;
    wire[31:0] int_or_exception_cause;

    wire interrupt_req_valid;

>>>>>>> Stashed changes

    assign interrupt_req_valid = inst_valid_i &int_req_i &
           ((int_id_i != int_id_now) | (~in_irq_context_now));

<<<<<<< Updated upstream
    // to ctrl
    output wire flush_flag_o,  // 用于刷新流水线
    output wire stall_flag_o,  // 用于暂停流水线
=======
>>>>>>> Stashed changes

    assign int_or_exception_req   = (interrupt_req_valid & global_int_en_i & (~debug_mode_q)) | sys_op_req;
    assign int_or_exception_cause = sys_op_req ? cause : (32'h8 + {24'h0, int_id_i});

    //新增异常操作请求信号
    reg sys_op_req;


    // interrupt state machine
    localparam S_INT_IDLE = 4'b0001;  // 空闲状态
    localparam S_INT_SYNC_ASSERT = 4'b0010;  // 同步中断断言状态
    localparam S_INT_ASYNC_ASSERT = 4'b0100;  // 异步中断断言状态
    localparam S_INT_MRET = 4'b1000;  // 中断返回状态


    // CSR write state machine
    localparam S_CSR_IDLE = 7'b0000001;  // CSR写入空闲状态
    localparam S_CSR_MSTATUS = 7'b0000010;  // 写入mstatus寄存器状态
    localparam S_CSR_MEPC = 7'b0000100;  // 写入mepc寄存器状态
    localparam S_CSR_MSTATUS_MRET = 7'b0001000;  // 中断返回时写入mstatus寄存器状态
    localparam S_CSR_MCAUSE = 7'b0010000;  // 写入mcause寄存器状态
    localparam S_ASSERT = 7'b0100000;    // 新增断言状态
    localparam S_DCSR = 7'b10000000;  // 新增DCSR状态，用于处理调试相关操作

    //新增中断原因本地参数定义
    localparam INT_CAUSE_ECALL = 32'd11;   // ecall中断原因代码
    localparam INT_CAUSE_EBREAK = 32'd3;   // ebreak中断原因代码
    localparam INT_CAUSE_MRET = 32'd12;    // mret中断原因代码

    localparam INT_CAUSE_ILLEGAL_INST = 32'd2; // 非法指令中断原因代码


    // 状态机和相关信号声明
    reg [                 3:0] int_state;  // 中断状态机当前状态
    reg [                 4:0] csr_state;  // CSR写状态机当前状态
    reg [`INST_ADDR_WIDTH-1:0] inst_addr;  // 保存的指令地址
    reg [                31:0] cause;  // 中断原因代码

<<<<<<< Updated upstream
    // 暂停信号产生逻辑 - 当中断状态机或CSR写状态机不在空闲状态时冲刷流水线
    assign flush_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE));
    assign stall_flag_o = ((sys_op_ecall_i || sys_op_ebreak_i) & atom_opt_busy_i);
=======
    wire trigger_matching;
>>>>>>> Stashed changes

    gen_ticks_sync #(
                       .DP(5),
                       .DW(1)
                   ) gen_trigger_sync (
                       .rst_n(rst_n),
                       .clk(clk),
                       .din(trigger_match_now),
                       .dout(trigger_matching)
                   );



    //增加系统下一时态的状态定义
    reg trigger_match_next, trigger_match_now;
    reg debug_mode_next, debug_mode_now;
    reg [3:0] int_state_next;   // 中断状态机下一个状态
    reg [4:0] csr_state_next;   // CSR写状态机下一个状态
    reg [`INST_ADDR_WIDTH-1:0] inst_addr_next;  // 下一个指令地址
    reg [`INST_ADDR_WIDTH-1:0] int_addr_o_next;   // 下一个中断地址
    reg int_assert_o_next;      // 下一个中断断言信号
    reg we_o_next;              // 下一个写使能信号
    reg [`BUS_ADDR_WIDTH-1:0] waddr_o_next;  // 下一个写地址
    reg [`REG_DATA_WIDTH-1:0] data_o_next;  // 下一个写数据

    // 暂停信号产生逻辑 - 当中断状态机或CSR写状态机不在空闲状态时冲刷水线*****新增debug_request
    assign flush_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE));
    assign stall_flag_o = ((sys_op_ecall_i || sys_op_ebreak_i) |debug_mode_req & atom_opt_busy_i);

    // 中断状态机时序逻辑
    always @(*) begin
        if (~rst_n) begin
<<<<<<< Updated upstream
            int_state = S_INT_IDLE;
        end else if ((sys_op_ecall_i || sys_op_ebreak_i) && atom_opt_busy_i == 1'b0) begin
            int_state = S_INT_SYNC_ASSERT;
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
                    if (int_state == S_INT_SYNC_ASSERT) begin
                        csr_state <= S_CSR_MEPC;
                    end else if (int_state == S_INT_MRET) begin
                        csr_state <= S_CSR_MSTATUS_MRET;
=======
            int_state_next = S_INT_IDLE;
        end
        else begin
            case(int_state)
                S_INT_IDLE: begin
                    if ((sys_op_ecall_i || sys_op_ebreak_i) && atom_opt_busy_i == 1'b0) begin
                        int_state_next = S_INT_SYNC_ASSERT;
                    end
                    else if (sys_op_mret_i) begin
                        int_state_next = S_INT_MRET;
                    end
                    else begin
                        int_state_next = S_INT_IDLE;
>>>>>>> Stashed changes
                    end
                end
                S_INT_SYNC_ASSERT: begin
                    int_state_next = S_INT_IDLE; // 同步中断处理后回到空闲状态
                end
                S_INT_ASYNC_ASSERT: begin
                    int_state_next = S_INT_IDLE;  // 异步中断处理后回到空闲状态
                end
                S_INT_MRET: begin
                    int_state_next = S_INT_SYNC_ASSERT;  // 中断返回后回到同步断言状态**
                    default: begin
                        int_state_next = S_INT_IDLE;
                    end

<<<<<<< Updated upstream
    // 中断原因寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cause <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) begin
            if (sys_op_ecall_i) begin
                cause <= 32'd11;
            end else if (sys_op_ebreak_i) begin
                cause <= 32'd3;
            end else begin
                cause <= 32'd10;
            end
        end
    end

    // 保存指令地址寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_addr <= `ZeroWord;
        end else if (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) begin
            if (jump_flag_i == `JumpEnable) begin
                inst_addr <= jump_addr_i - 4'h4;
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
                S_CSR_MCAUSE: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o  <= cause;
                end
                S_CSR_MSTATUS_MRET: begin
                    we_o    <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o  <= {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]};
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
=======
                endcase
            end
        end
        // 内部中断异常原因寄存器更新逻辑
        always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
                cause = `ZeroWord;
                sys_op_req = 1'b0; // 默认不设置系统操作请求
            end
            else if (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) begin
                if (sys_op_ecall_i ) begin
                    cause = INT_CAUSE_ECALL;
                    sys_op_req = 1'b1; // 设置系统操作请求
                end
                else if (sys_op_ebreak_i ) begin//******ebreak与debug相关
                    cause = INT_CAUSE_EBREAK;
                    sys_op_req = 1'b1; // 设置系统操作请求
                end
                else if (sys_op_mret_i) begin
                    cause = INT_CAUSE_MRET;//与系统异常无相关性
                end
                else begin
                    cause = `ZeroWord; // 默认无异常
                    sys_op_req = 1'b0; // 不设置系统操作请求
                end
            end
>>>>>>> Stashed changes
        end

        // 中断断言信号和中断地址逻辑
        always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
                int_assert_o_next = `INT_DEASSERT;
                int_addr_o_next   = `ZeroWord;
            end
            else begin
                case (csr_state)
                    S_ASSERT: begin
                        int_assert_o_next = `INT_ASSERT;
                        // 这里根据实际情况选择断言地址
                        if (int_state == S_INT_MRET)
                            int_addr_o_next = csr_mepc;
                        else
                            int_addr_o_next = csr_mtvec;
                    end
                    default: begin
                        int_assert_o_next = `INT_DEASSERT;
                        int_addr_o_next   = `ZeroWord;
                    end
                endcase
            end
        end

        // CSR写状态机的状态转换逻辑
        always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
                csr_state_next = S_CSR_IDLE;
            end
            else begin
                case (csr_state)
                    S_CSR_IDLE: begin
                        if (int_state == S_INT_SYNC_ASSERT) begin
                            csr_state_next = S_CSR_MEPC;
                        end
                        else if (int_state == S_INT_MRET) begin
                            csr_state_next = S_CSR_MSTATUS_MRET;
                        end
                        else begin
                            csr_state_next = S_CSR_IDLE;
                        end
                    end
                    S_CSR_MEPC: begin
                        csr_state_next = S_CSR_MSTATUS;
                    end
                    S_CSR_MSTATUS: begin
                        csr_state_next = S_CSR_MCAUSE;
                    end
                    S_CSR_MCAUSE: begin
                        csr_state_next = S_ASSERT; // 写完mcause后进入断言状态
                    end
                    S_CSR_MSTATUS_MRET: begin
                        csr_state_next = S_ASSERT; // mret写完后进入断言状态
                    end
                    S_ASSERT: begin
                        csr_state_next = S_CSR_IDLE; // 断言后回到空闲
                    end
                    S_DCSR: begin
                        csr_state_next = S_ASSERT; // DCSR处理后回到同步断言状态
                    end
                    default: begin
                        csr_state_next = S_CSR_IDLE;
                    end
                endcase
            end
        end


        // 保存指令地址寄存器更新逻辑
        always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
                inst_addr_next = `ZeroWord;
            end
            else if (csr_state == S_CSR_IDLE && int_state == S_INT_SYNC_ASSERT) begin
                if (jump_flag_i == `JumpEnable) begin
                    inst_addr_next = jump_addr_i - 4'h4;
                end
                else begin
                    inst_addr_next = inst_addr_i;
                end
            end
        end

        // CSR写使能、写地址和写数据逻辑
        always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
                we_o_next    = `WriteDisable;
                waddr_o_next = `ZeroWord;
                data_o_next  = `ZeroWord;
                int_addr_o_next = `ZeroWord;
                return_addr_o_next = `ZeroWord;
                int_id_next = int_id_now; // 初始化中断ID寄存器
                in_irq_context_next = in_irq_context_now; // 初始化中断上下文状态
                debug_mode_next = debug_mode_now; // 初始化debug模式状态
                trigger_match_next = trigger_match_now; // 初始化触发匹配状态
            end
            else begin
                case (csr_state)
                    S_CSR_IDLE: begin
                        if (int_or_exception_req & (!debug_mode_now)) begin
                            we_o_next    = `WriteEnable;
                            waddr_o_next = {20'h0, `CSR_MCAUSE};
                            data_o_next  = int_or_exception_cause;
                            int_addr_o_next = csr_mtvec; // 设置中断地址为mtvec寄存器
                            return_addr_o_next = inst_addr_i; // 保存返回地址
                            int_id_next = int_id_i; // 保存中断ID
                            in_irq_context_next = 1'b1; // 进入中断上下文
                        end
                        else if (debug_mode_req) begin
                            debug_mode_next = 1'b1; // 进入调试模式
                            if (enter_debug_cause_debugger_req |
                                    enter_debug_cause_single_step |
                                    enter_debug_cause_trigger |
                                    enter_debug_cause_reset_halt) begin
                                we_o_next    = `WriteEnable;
                                waddr_o_next = {20'h0, `CSR_DPC};
                                data_o_next  = enter_debug_cause_reset_halt ? (`CPU_RESET_ADDR) : inst_addr_i;
                                // when run openocd compliance test, use it.
                                // openocd compliance test bug: It report test fail when the reset address is 0x0:
                                // "NDMRESET should move DPC to reset value."
                                //csr_wdata = enter_debug_cause_reset_halt ? (`CPU_RESET_ADDR + 4'h4) : inst_addr_i;
                            end
                            if (enter_debug_cause_trigger) begin
                                trigger_match_next = 1'b1;
                            end
                            int_addr_o_next = debug_halt_addr_i; // 设置调试中断地址    *****还未更改
                            if (enter_debug_cause_ebreak) begin
                                int_state_next = S_INT_SYNC_ASSERT; // 进入同步中断状态
                            end
                            else begin
                                int_state_next = S_DCSR; // 进入调试CSR状态*****
                            end
                        end
                        else if (sys_op_mret_i) begin
                            in_irq_context_next = 1'b0; // 退出中断上下文
                            we_o_next    = `WriteEnable;
                            waddr_o_next = {20'h0, `CSR_MSTATUS};//*************
                            data_o_next  = {csr_mstatus[31:4], 1'b1, csr_mstatus[2:0]};
                            int_addr_o_next = csr_mepc; // 设置中断地址为mepc寄存器
                            int_state_next = S_INT_SYNC_ASSERT; // 进入断言状态*****

                            else if (inst_dret_i) begin
                                int_addr_o_next = csr_dpc_i; // 设置调试返回地址为dpc寄存器
                                int_state_d = S_INT_SYNC_ASSERT; // 进入断言状态
                                debug_mode_d = 1'b0; // 退出调试模式
                                trigger_match_d = 1'b0; // 退出触发匹配状态
                            end


                            S_CSR_MEPC: begin
                                we_o_next    = `WriteEnable;
                                waddr_o_next = {20'h0, `CSR_MEPC};
                                //data_o_next  = inst_addr;
                                data_o_next = return_addr_d; // 使用保存的返回地址
                            end
                            S_CSR_MSTATUS: begin
                                we_o_next    = `WriteEnable;
                                waddr_o_next = {20'h0, `CSR_MSTATUS};
                                data_o_next  = {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]};

                            end
                            S_CSR_MCAUSE: begin
                                we_o_next    = `WriteEnable;
                                waddr_o_next = {20'h0, `CSR_MCAUSE};
                                data_o_next  = cause;
                            end
                            S_CSR_MSTATUS_MRET: begin
                                we_o_next    = `WriteEnable;
                                waddr_o_next = {20'h0, `CSR_MSTATUS};
                                data_o_next  = {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]};
                            end
                            S_DCSR: begin
                                we_o_next    = `WriteEnable;
                                waddr_o_next = {20'h0, `CSR_DCSR};
                                data_o_next  =  {csr_dcsr_i[31:9], dcsr_cause_now, csr_dcsr_i[5:0]}; // 保留原有的DCSR寄存器状态
                            end
                            S_ASSERT: begin
                                we_o_next = `WriteDisable;
                            end

                            default: begin
                                we_o_next = `WriteDisable;
                            end
                        endcase
                    end
                end


                //debug模式状态机
                reg enter_debug_cause_debugger_req;
                reg enter_debug_cause_single_step;
                reg enter_debug_cause_ebreak;
                reg enter_debug_cause_reset_halt;
                reg enter_debug_cause_trigger;
                reg[2:0] dcsr_cause_next, dcsr_cause_now;

                always @ (*) begin
                    enter_debug_cause_debugger_req = 1'b0;
                    enter_debug_cause_single_step = 1'b0;
                    enter_debug_cause_ebreak = 1'b0;
                    enter_debug_cause_reset_halt = 1'b0;
                    enter_debug_cause_trigger = 1'b0;
                    dcsr_cause_next = `DCSR_CAUSE_NONE;

                    if (trigger_match_i
                            & inst_valid_i & (~trigger_matching)) begin
                        enter_debug_cause_trigger = 1'b1;
                        dcsr_cause_next = `DCSR_CAUSE_TRIGGER;
                    end
                    else if (sys_op_ebreak_i & inst_valid_i) begin
                        enter_debug_cause_ebreak = 1'b1;
                        dcsr_cause_next = `DCSR_CAUSE_EBREAK;
                    end
                    else if ((inst_addr_i == `CPU_RESET_ADDR) & inst_valid_i & debug_req_i) begin
                        enter_debug_cause_reset_halt = 1'b1;
                        dcsr_cause_next = `DCSR_CAUSE_HALT;
                    end
                    else if ((~debug_mode_now) & debug_req_i & inst_valid_i) begin
                        enter_debug_cause_debugger_req = 1'b1;
                        dcsr_cause_next = `DCSR_CAUSE_DBGREQ;
                    end
                    else if ((~debug_mode_now) & csr_dcsr_i[2] & inst_valid_i & sys_op_executed_i) begin
                        enter_debug_cause_single_step = 1'b1;
                        dcsr_cause_next = `DCSR_CAUSE_STEP;
                    end
                end

                wire debug_mode_req = enter_debug_cause_debugger_req |
                     enter_debug_cause_single_step |
                     enter_debug_cause_reset_halt |
                     enter_debug_cause_trigger |
                     enter_debug_cause_ebreak;


                // 读地址寄存器更新逻辑
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        raddr_o <= `ZeroWord;
                        int_state    <= S_INT_IDLE;
                        csr_state    <= S_CSR_IDLE;
                        inst_addr    <= `ZeroWord;
                        int_addr_o   <= `ZeroWord;
                        int_assert_o <= `INT_DEASSERT;
                        we_o         <= `WriteDisable;
                        waddr_o      <= `ZeroWord;
                        data_o       <= `ZeroWord;
                        int_id_now     <= 8'h0;
                        debug_mode_now <= 1'b0; // 初始化debug模式为非调试状态
                        dcsr_cause_now <= `DCSR_CAUSE_NONE; // 初始化dcsr寄存器的原因代码
                        trigger_match_now <= 1'b0; // 初始化触发器匹配状态
                    end
                    else begin
                        raddr_o      <= `ZeroWord;
                        int_state    <= int_state_next;
                        csr_state    <= csr_state_next;
                        inst_addr    <= inst_addr_next;
                        int_addr_o   <= int_addr_o_next;
                        int_assert_o <= int_assert_o_next;
                        we_o         <= we_o_next;
                        waddr_o      <= waddr_o_next;
                        data_o       <= data_o_next;
                        int_id_now     <= int_id_i; // 更新中断ID寄存器
                        debug_mode_now <= debug_mode_next; // 更新debug模式状态
                        dcsr_cause_now <= dcsr_cause_next; // 更新dcsr寄存器的原因代码
                        trigger_match_now <= trigger_match_next; // 更新触发器匹配状态
                    end
                end

            endmodule
