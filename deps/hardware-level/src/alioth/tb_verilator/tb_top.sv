`timescale 1 ns / 1 ps

`include "defines.svh"

`ifdef JTAGVPI
`define NO_TIMEOUT
`endif

// 宏定义控制寄存器调试输出
// `define DEBUG_DISPLAY_REGS 1

// 宏定义控制PC监控输出
`define DEBUG_PC_MONITOR 1

// ToHost程序地址,用于监控测试是否结束
`define PC_WRITE_TOHOST 32'h80000040

// 添加监控的PC地址范围 - 修改为新的程序段
`define PC_MONITOR_START 32'h800001f8
`define PC_MONITOR_END 32'h80000330

`define ITCM alioth_soc_top_0.u_cpu_top.u_mems.itcm_inst.ram_inst
`define DTCM alioth_soc_top_0.u_cpu_top.u_mems.perip_bridge_axi_inst.perip_bridge_inst.ram_inst
`define seg_ori_data alioth_soc_top_0.u_cpu_top.u_mems.perip_bridge_axi_inst.perip_bridge_inst.seg_wdata

module tb_top (
    input clk,
    input rst_n,

    // JTAG接口作为外部输入
    input  tck_i,
    input  tms_i,
    input  tdi_i,
    output tdo_o
);

    // 通用寄存器访问 - 仅用于错误信息显示
    wire    [   31:0] x3 = alioth_soc_top_0.u_cpu_top.u_gpr.regs[3];
    // 添加通用寄存器监控 - 用于结果判断
    wire    [   31:0] pc = alioth_soc_top_0.u_cpu_top.u_ifu.u_ifu_ifetch.pc_o;
    wire    [   63:0] csr_cycle = alioth_soc_top_0.u_cpu_top.u_csr.mcycle[31:0];
    wire    [   31:0] csr_instret = alioth_soc_top_0.u_cpu_top.u_csr.minstret[31:0];

    integer           r;
    reg     [8*300:1] testcase;
    integer           dumpwave;

    // 计算ITCM和DTCM的深度和字节大小
    localparam ITCM_DEPTH = (1 << (`ITCM_ADDR_WIDTH - 2));  // ITCM中的字数
    localparam ITCM_BYTE_SIZE = ITCM_DEPTH * 4;  // 总字节数
    localparam DTCM_DEPTH = (1 << (`DTCM_ADDR_WIDTH - 2));  // DTCM中的字数
    localparam DTCM_BYTE_SIZE = DTCM_DEPTH * 4;  // 总字节数

    // 创建与ITCM和DTCM容量相同的临时字节数组
    reg     [ 7:0] itcm_prog_mem                                       [0:ITCM_BYTE_SIZE-1];
    reg     [ 7:0] dtcm_prog_mem                                       [0:DTCM_BYTE_SIZE-1];
    integer        i;

    // 添加PC监控变量
    reg     [31:0] pc_write_to_host_cnt;
    reg     [31:0] pc_write_to_host_cycle;
    reg            pc_write_to_host_flag;
    reg     [31:0] last_pc;  // 保留用于监测PC变化

    // 添加PC范围监控变量
    reg     [31:0] last_monitored_pc;
    reg     [31:0] pc_monitor_counter;
    reg            in_monitor_range;  // 标记是否在监控范围内

    // 不再自己维护周期和指令计数，直接从CSR获取
    wire    [31:0] current_cycle = csr_cycle[31:0];
    wire    [31:0] current_instructions = csr_instret[31:0];

    // 周期计数器 - 简化为只更新last_pc
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_pc            <= 32'b0;
            last_monitored_pc  <= 32'b0;
            pc_monitor_counter <= 32'b0;
            in_monitor_range   <= 1'b0;
        end else begin
            last_pc <= pc;  // 仍然保留PC变化监测，用于触发to_host判断

`ifdef DEBUG_PC_MONITOR
            // PC范围监控逻辑 - 只在指定范围内报告
            if (pc >= `PC_MONITOR_START && pc <= `PC_MONITOR_END) begin
                // 进入监控范围
                if (!in_monitor_range) begin
                    $display(
                        "[PC_MONITOR] Entering monitored code section at PC: 0x%08x, Cycle: %d",
                        pc, current_cycle);
                    in_monitor_range <= 1'b1;
                end

                // 每当PC在监控范围内且发生变化时输出信息
                if (pc != last_monitored_pc) begin
                    $display("[PC_MONITOR] Cycle: %d, PC: 0x%08x, Instruction: %d", current_cycle,
                             pc, current_instructions);
                    last_monitored_pc  <= pc;
                    pc_monitor_counter <= pc_monitor_counter + 1;
                end
            end else begin
                // 离开监控范围
                if (in_monitor_range) begin
                    $display("[PC_MONITOR] Exiting monitored code section at PC: 0x%08x, Cycle: %d",
                             pc, current_cycle);
                    $display("[PC_MONITOR] Total instructions in monitored section: %d",
                             pc_monitor_counter);
                    in_monitor_range <= 1'b0;
                end
                last_monitored_pc <= 32'b0;  // 重置监控PC
            end
`endif
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
            pc_monitor_counter <= 32'b0;  // 使用非阻塞赋值，与其他地方保持一致
            in_monitor_range   <= 1'b0;  // 使用非阻塞赋值，与其他地方保持一致
        end
    end

    // 超时监控 - 使用CSR的cycle计数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
        end else begin
`ifndef NO_TIMEOUT
            if (current_cycle[27] == 1'b1) begin
                $display("Time Out !!!");
                $finish;
            end
`endif
        end
    end

    // 测试用例解析
    initial begin
        $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
`ifdef DEBUG_PC_MONITOR
        $display("PC Monitor enabled for range: 0x%08x - 0x%08x", `PC_MONITOR_START,
                 `PC_MONITOR_END);
`endif
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

        // 处理小端序格式并更新到ITCM
        for (i = 0; i < ITCM_DEPTH; i = i + 1) begin  // 遍历ITCM的每个字
            `ITCM.mem_r[i] = {
                itcm_prog_mem[i*4+3],
                itcm_prog_mem[i*4+2],
                itcm_prog_mem[i*4+1],
                itcm_prog_mem[i*4+0]
            };
        end

        // 处理小端序格式并更新到DTCM
        for (i = 0; i < DTCM_DEPTH; i = i + 1) begin  // 遍历DTCM的每个字
            `DTCM.mem_r[i] = {
                dtcm_prog_mem[i*4+3],
                dtcm_prog_mem[i*4+2],
                dtcm_prog_mem[i*4+1],
                dtcm_prog_mem[i*4+0]
            };
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
`ifdef DEBUG_PC_MONITOR
            $display("~~~~~~~Total monitored PC changes: %d ~~~~~~~~~~~~~~", pc_monitor_counter);
`endif
            $display("~~~~~~~~~~~~~~Total cycle_count value: %d ~~~~~~~~~~~~~", current_cycle);
            $display("~~~~~The test ending reached at cycle: %d ~~~~~~~~~~~~~",
                     pc_write_to_host_cycle);
            $display("~~~~~~~~~~Total instructions executed: %d ~~~~~~~~~~~~~",
                     current_instructions);
            $display("~~~~~~~~~~~~~~~~~~ IPC value: %.4f ~~~~~~~~~~~~~~~~~~", ipc);
            $display("~~~~~~~~~~~~~~~The final x3 Reg value: %d ~~~~~~~~~~~~~", x3);
            // 添加最终PC位置的报告
            $display("~~~~~~~~~~~~~~~Final PC position: 0x%08x ~~~~~~~~~~~~~~", pc);
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
    reg clk_slow;

    always @(posedge clk) begin
        // 生成一个慢时钟信号，频率为原始时钟的1/2
        clk_slow <= ~clk_slow;
    end
    // 实例化顶层模块
    // 声明LED输出信号并连接
    wire [31:0] virtual_led;  // 假设LED输出是8位宽

    alioth_soc_top alioth_soc_top_0 (
        .clk  (clk),
        .rst_n(rst_n),

        // 外设引脚连接
        .cnt_clk           (clk_slow),
        .virtual_sw_input  (),
        .virtual_key_input (),
        .virtual_seg_output(),
        .virtual_led_output(virtual_led)  // 连接LED输出
    );

    // LED监控 - 添加监控逻辑检测LED输出变化
    reg [31:0] last_led_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_led_value <= 0;
        end else begin
            if (virtual_led !== last_led_value) begin
                $display("[LED_MONITOR] Cycle: %d, LED value changed: 0x%02x -> 0x%02x",
                         current_cycle, last_led_value, virtual_led);
                last_led_value <= virtual_led;
            end
        end
    end

    // SEG显示监控 - 添加监控逻辑检测段码显示数据变化
    reg [31:0] last_seg_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_seg_value <= 32'h0;
        end else begin
            if (`seg_ori_data !== last_seg_value) begin
                $display("[SEG_MONITOR] Cycle: %d, SEG value changed: 0x%08x -> 0x%08x",
                         current_cycle, last_seg_value, `seg_ori_data);
                last_seg_value <= `seg_ori_data;
            end
        end
    end

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

endmodule
