`timescale 1 ns / 1 ps

`include "defines.svh"

`ifdef JTAGVPI
`define NO_TIMEOUT
`endif

// 宏定义控制寄存器调试输出
// `define DEBUG_DISPLAY_REGS 1

// ToHost程序地址,用于监控测试是否结束
`define PC_WRITE_TOHOST 32'h000000a0

`define ITCM alioth_soc_top_0.u_cpu_top.u_mems.u_itcm

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
    wire    [   31:0] x3 = alioth_soc_top_0.u_cpu_top.u_regs.regs[3];
    // 添加通用寄存器监控 - 用于结果判断
    wire    [   31:0] pc = alioth_soc_top_0.u_cpu_top.u_ifu.pc_o;

    integer           r;
    reg     [8*300:1] testcase;
    integer           dumpwave;

    // 计算ITCM的深度和字节大小
    localparam ITCM_DEPTH = (1 << (`ITCM_ADDR_WIDTH - 2));  // ITCM中的字数
    localparam ITCM_BYTE_SIZE = ITCM_DEPTH * 4;  // 总字节数

    // 创建与ITCM容量相同的临时字节数组
    reg [7:0] prog_mem[0:ITCM_BYTE_SIZE-1];  // 注意数组声明顺序调整
    integer i;

    // 添加PC监控变量
    reg [31:0] pc_write_to_host_cnt;
    reg [31:0] pc_write_to_host_cycle;
    reg [31:0] valid_ir_cycle;
    reg [31:0] cycle_count;
    reg pc_write_to_host_flag;
    reg [31:0] last_pc;  // 添加一个寄存器来存储上一次的PC值

    // 添加指令计数和IPC计算相关变量
    reg [31:0] instruction_count;
    wire valid_instruction = (pc != last_pc);  // PC变化时认为执行了一条指令
    real ipc;

    // 周期计数器 - 保持同步实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count       <= 32'b0;
            last_pc           <= 32'b0;  // 初始化上一次的PC值
            instruction_count <= 32'b0;  // 重置指令计数
        end else begin
            cycle_count <= cycle_count + 1'b1;
            last_pc     <= pc;  // 在时钟边缘更新上一次的PC值，用于检测变化

            // 基于PC变化进行指令计数
            if (valid_instruction) begin
                instruction_count <= instruction_count + 1'b1;
            end
        end
    end

    // PC监控逻辑
    always @(pc) begin
        if (pc == `PC_WRITE_TOHOST && pc != last_pc) begin
            pc_write_to_host_cnt = pc_write_to_host_cnt + 1'b1;
            if (pc_write_to_host_flag == 1'b0) begin
                pc_write_to_host_cycle = cycle_count;
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

    // 超时监控
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
        end else begin
`ifndef NO_TIMEOUT
            if (cycle_count[20] == 1'b1) begin
                $display("Time Out !!!");
                $finish;
            end
`endif
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

        // 从.verilog文件中读取字节数据
        $readmemh({testcase, ".verilog"}, prog_mem);

        // 处理小端序格式并更新到新的ITCM存储位置
        for (i = 0; i < ITCM_DEPTH; i = i + 1) begin  // 遍历ITCM的每个字
            `ITCM.mem_r[i] = {prog_mem[i*4+3], prog_mem[i*4+2], prog_mem[i*4+1], prog_mem[i*4+0]};
        end

        $display("Successfully loaded instructions to ITCM");
        $display("ITCM 0x00: %h", `ITCM.mem_r[0]);
        $display("ITCM 0x01: %h", `ITCM.mem_r[1]);
        $display("ITCM 0x02: %h", `ITCM.mem_r[2]);
        $display("ITCM 0x03: %h", `ITCM.mem_r[3]);
        $display("ITCM 0x04: %h", `ITCM.mem_r[4]);
    end

    // 对pc_write_to_host_cnt的变化进行监控
    always @(pc_write_to_host_cnt) begin
        if (pc_write_to_host_cnt == 32'd8) begin
            // 计算IPC
            ipc = (instruction_count > 0 && cycle_count > 0) ? (instruction_count * 1.0) / cycle_count : 0.0;

            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~ Test Result Summary ~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            // 使用处理过的输出代替直接输出testcase
            $write("~TESTCASE: ");
            display_testcase_name();
            $display("~");
            $display("~~~~~~~~~~~~~~Total cycle_count value: %d ~~~~~~~~~~~~~", cycle_count);
            $display("~~~~~The test ending reached at cycle: %d ~~~~~~~~~~~~~", pc_write_to_host_cycle);
            $display("~~~~~~~~~~Total instructions executed: %d ~~~~~~~~~~~~~", instruction_count);
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
                for (r = 0; r < 32; r = r + 1) $display("x%2d = 0x%x", r, alioth_soc_top_0.u_cpu_top.u_regs.regs[r]);
            end
            // 输出性能指标，方便脚本提取
            $display("PERF_METRIC: CYCLES=%-d INSTS=%-d IPC=%.4f", cycle_count, instruction_count, ipc);
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

    // 实例化顶层模块
    alioth_soc_top alioth_soc_top_0 (
        .clk  (clk),
        .rst_n(rst_n)
    );

    // 添加可选的寄存器调试输出功能
`ifdef DEBUG_DISPLAY_REGS
    // 监控GPR寄存器写入
    wire        write_gpr_reg = alioth_soc_top_0.u_cpu_top.u_regs.we_i;
    wire [ 4:0] write_gpr_addr = alioth_soc_top_0.u_cpu_top.u_regs.waddr_i;

    // 监控CSR寄存器写入
    wire        write_csr_reg = alioth_soc_top_0.u_cpu_top.u_csr_reg.we_i;
    wire [31:0] write_csr_addr = alioth_soc_top_0.u_cpu_top.u_csr_reg.waddr_i;

    always @(posedge clk) begin
        if (write_gpr_reg && (write_gpr_addr == 5'd31)) begin
            $display("\n");
            $display("GPR Register Status:");
            for (r = 0; r < 32; r = r + 1) $display("x%2d = 0x%x", r, alioth_soc_top_0.u_cpu_top.u_regs.regs[r]);
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
