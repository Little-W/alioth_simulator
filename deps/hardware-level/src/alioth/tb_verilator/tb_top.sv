`define verilator5
`define verilator5
`define DISABLE_TIMEOUT
`timescale 1 ns / 1 ps

`include "defines.svh"

`ifdef JTAGVPI
`define NO_TIMEOUT
`endif

// 宏定义控制寄存器调试输出
// `define DEBUG_DISPLAY_REGS 1
// `define ENABLE_IRQ_MONITOR // 监控IRQ相关信号变化
// `define ENABLE_EXT_IRQ_MONITOR // 监控外部中断源变化 
// `define ENABLE_DUMP_EN
// ToHost程序地址,用于监控测试是否结束
`define ENABLE_PC_WRITE_TOHOST
`ifdef ENABLE_PC_WRITE_TOHOST
`define PC_WRITE_TOHOST 32'h80000040
`endif

`define ITCM alioth_soc_top_0.u_cpu_top.u_mems.itcm_inst.ram_inst
`define DTCM alioth_soc_top_0.u_cpu_top.u_mems.dtcm_inst.ram_inst

// 支持dump使能区间
parameter DUMP_START_CYCLE = 133262798;
parameter DUMP_END_CYCLE = 136262728;  // 可根据需要修改，默认最大32位无符号数

module tb_top (
    input clk,
    input rst_n,

    // JTAG接口作为外部输入
    input  tck_i,
    input  tms_i,
    input  tdi_i,
    output tdo_o,
    output dump_en, // 新增dump_en输出端口

    // UART接口引脚
    output uart_tx,
    input  uart_rx
);

    // 通用寄存器访问 - 仅用于错误信息显示
    wire [31:0] x3 = alioth_soc_top_0.u_cpu_top.u_gpr.regs[3];
    // 添加通用寄存器监控 - 用于结果判断
    wire [31:0] pc = alioth_soc_top_0.u_cpu_top.u_dispatch.inst2_addr_o;
    wire [31:0] csr_cyclel = alioth_soc_top_0.u_cpu_top.u_csr.cycle[31:0];
    wire [31:0] csr_cycleh = alioth_soc_top_0.u_cpu_top.u_csr.cycleh[31:0];
    wire [31:0] csr_instret = alioth_soc_top_0.u_cpu_top.u_csr.minstret[31:0];
    wire swi = alioth_soc_top_0.u_cpu_top.u_clint.soft_irq;
    wire timer_irq = alioth_soc_top_0.u_cpu_top.u_clint.timer_irq;
    wire [10:0] irq_sources = alioth_soc_top_0.u_cpu_top.u_plic.irq_sources;  // 修改为11位
    wire irq_valid = alioth_soc_top_0.u_cpu_top.u_plic.irq_valid;

    integer r;
    reg [8*300:1] testcase;
    integer dumpwave;

    // 计算ITCM和DTCM的深度和字节大小（64位内存版本）
    localparam ITCM_DEPTH = (1 << (`ITCM_ADDR_WIDTH - 3));  // ITCM中的64位字数 (减3位因为64位=8字节)
    localparam ITCM_BYTE_SIZE = ITCM_DEPTH * 8;  // 总字节数（64位字 * 8字节）
    localparam DTCM_DEPTH = (1 << (`DTCM_ADDR_WIDTH - 3));  // DTCM中的64位字数 (减3位因为64位=8字节)
    localparam DTCM_BYTE_SIZE = DTCM_DEPTH * 8;  // 总字节数（64位字 * 8字节）

    // 创建与ITCM和DTCM容量相同的临时字节数组
    reg     [ 7:0] itcm_prog_mem                                             [0:ITCM_BYTE_SIZE-1];
    reg     [ 7:0] dtcm_prog_mem                                             [0:DTCM_BYTE_SIZE-1];
    integer        i;

    wire    [63:0] cycle = {csr_cycleh, csr_cyclel};  // 合并cycle高低位
    wire    [31:0] current_cycle = csr_cyclel[31:0];
    wire    [31:0] current_cycleh = csr_cycleh[31:0];

`ifdef ENABLE_DUMP_EN
    reg dump_en_reg;
    assign dump_en = dump_en_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dump_en_reg <= 1'b0;
        end else begin
            // 支持dump使能区间
            if (cycle >= DUMP_START_CYCLE && cycle < DUMP_END_CYCLE) dump_en_reg <= 1'b1;
            else dump_en_reg <= 1'b0;
        end
    end
`else
    assign dump_en = 1'b1;
`endif

`ifdef ENABLE_PC_WRITE_TOHOST
    // 添加PC监控变量
    reg  [31:0] pc_write_to_host_cnt;
    reg  [31:0] pc_write_to_host_cycle;
    reg         pc_write_to_host_flag;
    reg  [31:0] last_pc;  // 保留用于监测PC变化

    // 不再自己维护周期和指令计数，直接从CSR获取
    wire [31:0] current_instructions = csr_instret[31:0];

    // 周期计数器 - 简化为只更新last_pc
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_pc <= 32'b0;
        end else begin
            last_pc <= pc;  // 仍然保留PC变化监测，用于触发to_host判断
        end
    end

    // PC监控逻辑 - 保留用于测试结束判断
    always @(pc) begin
        if (pc == `PC_WRITE_TOHOST && pc != last_pc) begin
            pc_write_to_host_cnt = pc_write_to_host_cnt + 1'b1;
            if (pc_write_to_host_flag == 1'b0) begin
                pc_write_to_host_cycle = current_cycle;  // 使用CSR获取的cycle值
                pc_write_to_host_flag  = 1'b1;
            end
        end
    end

    // 添加异步复位逻辑
    always @(negedge rst_n) begin
        if (!rst_n) begin
            pc_write_to_host_cnt   = 32'b0;
            pc_write_to_host_flag  = 1'b0;
            pc_write_to_host_cycle = 32'b0;
        end
    end
`endif

    // 超时监控 - 使用mcycleh的最高位作为超时
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
        end else begin
`ifndef NO_TIMEOUT
`ifndef DISABLE_TIMEOUT
            if (current_cycle[20] == 1'b1) begin
                $display("Time Out !!!");
                $finish;
            end
`endif
`endif
        end
    end

    // PC卡死检测相关变量
    reg [31:0] pc_last;
    reg [ 7:0] pc_stuck_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_last      <= 32'b0;
            pc_stuck_cnt <= 8'b0;
        end else begin
            // PC stuck detection: if PC does not change for 100 cycles, terminate simulation
            if (pc == pc_last) begin
                pc_stuck_cnt <= pc_stuck_cnt + 1'b1;
            end else begin
                pc_stuck_cnt <= 8'b0;
                pc_last      <= pc;
            end
            if (pc_stuck_cnt >= 8'd100) begin
                $display(
                    "PC stuck detection: PC has not changed for 100 cycles, simulation terminated!");
                $display("PC value when stuck: 0x%08x", pc_last);
                $finish;
            end
        end
    end

    // 测试用例解析
    initial begin
        $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        if ($value$plusargs("itcm_init=%s", testcase)) begin
            // 只输出有效的testcase内容
            display_testcase_name();
            $display("");
        end else begin
            $display("No itcm_init defined!");
            $finish;
        end

        // 初始化内存数组
        for (i = 0; i < ITCM_BYTE_SIZE; i = i + 1) begin
            itcm_prog_mem[i] = 8'h00;
        end
        for (i = 0; i < DTCM_BYTE_SIZE; i = i + 1) begin
            dtcm_prog_mem[i] = 8'h00;
        end

        // 从分割后的.verilog文件中读取字节数据
        $readmemh({testcase, "_itcm.verilog"}, itcm_prog_mem);
        $readmemh({testcase, "_dtcm.verilog"}, dtcm_prog_mem);

        // 处理小端序格式并更新到ITCM（64位内存版本）
        // 每个64位字包含两个32位指令：{inst1[31:0], inst0[31:0]}
        for (i = 0; i < ITCM_DEPTH; i = i + 1) begin  // 遍历ITCM的每个64位字
            if (i*8+7 < ITCM_BYTE_SIZE) begin
                `ITCM.mem_r[i] = {
                    itcm_prog_mem[i*8+7], itcm_prog_mem[i*8+6], itcm_prog_mem[i*8+5], itcm_prog_mem[i*8+4],  // inst1[31:0]
                    itcm_prog_mem[i*8+3], itcm_prog_mem[i*8+2], itcm_prog_mem[i*8+1], itcm_prog_mem[i*8+0]   // inst0[31:0]
                };
            end else begin
                `ITCM.mem_r[i] = 64'h0;
            end
        end

        // 处理小端序格式并更新到DTCM（64位内存版本）
        for (i = 0; i < DTCM_DEPTH; i = i + 1) begin  // 遍历DTCM的每个64位字
            if (i*8+7 < DTCM_BYTE_SIZE) begin
                `DTCM.mem_r[i] = {
                    dtcm_prog_mem[i*8+7], dtcm_prog_mem[i*8+6], dtcm_prog_mem[i*8+5], dtcm_prog_mem[i*8+4],  // high 32 bits
                    dtcm_prog_mem[i*8+3], dtcm_prog_mem[i*8+2], dtcm_prog_mem[i*8+1], dtcm_prog_mem[i*8+0]   // low 32 bits
                };
            end else begin
                `DTCM.mem_r[i] = 64'h0;
            end
        end

        $display("Successfully loaded instructions to ITCM and data to DTCM");
        $display("ITCM 0x00: %h", `ITCM.mem_r[0]);
        $display("ITCM 0x01: %h", `ITCM.mem_r[1]);
        $display("ITCM 0x02: %h", `ITCM.mem_r[2]);
        $display("ITCM 0x03: %h", `ITCM.mem_r[3]);
        $display("ITCM 0x04: %h", `ITCM.mem_r[4]);
        $display("DTCM 0x00: %h", `DTCM.mem_r[0]);
        $display("DTCM 0x01: %h", `DTCM.mem_r[1]);
    end

`ifdef ENABLE_PC_WRITE_TOHOST
    // 对pc_write_to_host_cnt的变化进行监控
    always @(pc_write_to_host_cnt) begin
        if (pc_write_to_host_cnt == 32'd2) begin
            // 计算IPC - 使用CSR计数器
            real ipc = (current_instructions > 0 && current_cycle > 0) ? 
                      (current_instructions * 1.0) / current_cycle : 0.0;

            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~ Test Result Summary ~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            // 使用处理过的输出代替直接输出testcase
            $write("~TESTCASE: ");
            display_testcase_name();
            $display("~");
            $display("~~~~~~~~~~~~~~Total cycle_count value: %d ~~~~~~~~~~~~~", current_cycle);
            $display("~~~~~The test ending reached at cycle: %d ~~~~~~~~~~~~~",
                     pc_write_to_host_cycle);
            $display("~~~~~~~~~~Total instructions executed: %d ~~~~~~~~~~~~~",
                     current_instructions);
            $display("~~~~~~~~~~~~~~~~~~ IPC value: %.4f ~~~~~~~~~~~~~~~~~~", ipc);
            $display("~~~~~~~~~~~~~~~The final x3 Reg value: %d ~~~~~~~~~~~~~", x3);
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

            if (x3 == 1) begin
                $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~");
                $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~");
                $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~");
                $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~");
                $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~");
                $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            end else begin
                $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~######    ##       #    #     ~~~~~~~~~~");
                $display("~~~~~~~~~~#        #  #      #    #     ~~~~~~~~~~");
                $display("~~~~~~~~~~#####   #    #     #    #     ~~~~~~~~~~");
                $display("~~~~~~~~~~#       ######     #    #     ~~~~~~~~~~");
                $display("~~~~~~~~~~#       #    #     #    #     ~~~~~~~~~~");
                $display("~~~~~~~~~~#       #    #     #    ######~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("fail testnum = %2d", x3);
                for (r = 0; r < 32; r = r + 1)
                $display("x%2d = 0x%x", r, alioth_soc_top_0.u_cpu_top.u_gpr.regs[r]);
            end
            // 输出性能指标，方便脚本提取
            $display("PERF_METRIC: CYCLES=%-d INSTS=%-d IPC=%.4f", current_cycle,
                     current_instructions, ipc);
            $finish;
        end
    end
`endif

    // 添加一个任务来显示处理过的testcase名称
    task automatic display_testcase_name;
        integer       i;
        reg     [7:0] ch;
        reg           printing;

        printing = 0;

        // 跳过前导空格和空字符
        for (i = 300; i >= 1; i = i - 1) begin
            ch = testcase[i*8-:8];

            // 如果找到有效字符，开始打印
            if (!printing && ch != " " && ch != 8'h00 && ch != 8'h20) begin
                printing = 1;
            end

            // 如果处于打印模式且碰到结束字符，则停止
            if (printing && (ch == 8'h00 || ch == 8'h0A)) begin
                printing = 0;
                // 完成打印
                break;
            end

            // 处于打印模式且有有效字符时输出
            if (printing && ch >= 8'h20) begin
                $write("%c", ch);
            end
        end
    endtask

    /*
`ifdef JTAGVPI
    wire jtag_TDI;
    wire jtag_TDO;
    wire jtag_TCK;
    wire jtag_TMS;
    assign jtag_TDI = tdi_i;
    assign tdo_o    = jtag_TDO;
    assign jtag_TCK = tck_i;
    assign jtag_TMS = tms_i;
`else
    wire jtag_TDI = 1'b0;
    wire jtag_TDO;
    wire jtag_TCK = 1'b0;
    wire jtag_TMS = 1'b0;
    wire jtag_TRST = 1'b0;
`endif
    */

    // 主时钟64分频，生成低速时钟 lfextclk
    wire       lfextclk;
    reg  [5:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
        end
    end
    assign lfextclk = cnt[5];

    // 实例化顶层模块
    alioth_soc_top alioth_soc_top_0 (
        .clk            (clk),
        .rst_n          (rst_n),
        .low_speed_clk_i(lfextclk),
        // UART端口连接
        .tx_o           (uart_tx),
        .rx_i           (uart_rx)
    );

    // 添加可选的寄存器调试输出功能
`ifdef DEBUG_DISPLAY_REGS
    // 监控GPR寄存器写入
    wire        write_gpr_reg = alioth_soc_top_0.u_cpu_top.u_gpr.we_i;
    wire [ 4:0] write_gpr_addr = alioth_soc_top_0.u_cpu_top.u_gpr.waddr_i;

    // 监控CSR寄存器写入
    wire        write_csr_reg = alioth_soc_top_0.u_cpu_top.u_csr_reg.we_i;
    wire [31:0] write_csr_addr = alioth_soc_top_0.u_cpu_top.u_csr_reg.waddr_i;

    always @(posedge clk) begin
        if (write_gpr_reg && (write_gpr_addr == 5'd31)) begin
            $display("\n");
            $display("GPR Register Status:");
            for (r = 0; r < 32; r = r + 1)
            $display("x%2d = 0x%x", r, alioth_soc_top_0.u_cpu_top.u_gpr.regs[r]);
        end else if (write_csr_reg && (write_csr_addr[11:0] == 12'hc00)) begin
            $display("\n");
            $display("CSR Register Status:");
            $display("cycle = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.cycle[31:0]);
            $display("cycleh = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.cycle[63:32]);
            $display("mtvec = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.mtvec);
            $display("mstatus = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.mstatus);
            $display("mepc = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.mepc);
            $display("mie = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.mie);
            $display("mcause = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.mcause);
            $display("mscratch = 0x%x", alioth_soc_top_0.u_cpu_top.u_csr_reg.mscratch);
        end
    end
`endif

`ifdef ENABLE_IRQ_MONITOR
    // 监控swi变化并打印pc和cycle
    reg swi_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            swi_last <= 1'b0;
        end else begin
            if (swi != swi_last) begin
                $display("------------------------------------------------------------");
                $display("swi changed to %b at pc=0x%08x, cycle=%0d", swi, pc, cycle);
                $display("------------------------------------------------------------");
                swi_last <= swi;
            end
        end
    end

    // 监控timer_irq变化并打印pc和cycle
    reg timer_irq_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_irq_last <= 1'b0;
        end else begin
            if (timer_irq != timer_irq_last) begin
                $display("------------------------------------------------------------");
                $display("timer_irq changed to %b at pc=0x%08x, cycle=%0d", timer_irq, pc, cycle);
                $display("------------------------------------------------------------");
                timer_irq_last <= timer_irq;
            end
        end
    end
`endif

`ifdef ENABLE_EXT_IRQ_MONITOR
    // 新增：监控irq_sources和irq_valid变化
    reg [10:0] irq_sources_last;  // 修改为11位
    reg        irq_valid_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_sources_last <= 11'b0;  // 修改为11位
            irq_valid_last   <= 1'b0;
        end else begin
            if (irq_sources != irq_sources_last) begin
                $display("------------------------------------------------------------");
                $display("irq_sources changed to %b at pc=0x%08x, cycle=%0d", irq_sources, pc,
                         cycle);
                $display("------------------------------------------------------------");
                irq_sources_last <= irq_sources;
            end
            if (irq_valid != irq_valid_last) begin
                $display("------------------------------------------------------------");
                $display("irq_valid changed to %b at pc=0x%08x, cycle=%0d", irq_valid, pc, cycle);
                $display("------------------------------------------------------------");
                irq_valid_last <= irq_valid;
            end
        end
    end

`endif
endmodule
