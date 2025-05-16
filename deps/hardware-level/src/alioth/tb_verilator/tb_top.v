`timescale 1 ns / 1 ps

`include "defines.v"

`ifdef JTAGVPI
  `define NO_TIMEOUT
`endif

// 添加新的宏定义控制寄存器调试输出
// `define DEBUG_DISPLAY_REGS 1

module tb_top (
    input clk,
    input rst_n,

    // JTAG接口作为外部输入
    input  tck_i,
    input  tms_i,
    input  tdi_i,
    output tdo_o
);

    // 复位信号反相
    wire rst = rst_n;
    
    // 通用寄存器访问 - 仅用于错误信息显示
    wire    [31:0] x3 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[3];
    // 添加通用寄存器x26和x27的监控 - 用于新的测试结果判断
    wire    [31:0] x26 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[26];
    wire    [31:0] x27 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[27];

    // 新增CSR寄存器状态获取
    wire[31:0] sim_result = tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mstatus;
    wire sim_end = sim_result[0];
    wire sim_succ = sim_result[1];

    integer           r;
    reg     [8*300:1] testcase;
    integer           dumpwave;

    // 计算ROM的深度和字节大小
    localparam ROM_DEPTH = 4096; // ROM中的字数
    localparam ROM_BYTE_SIZE = ROM_DEPTH * 4; // 总字节数

    // 创建与ROM容量相同的临时字节数组
    reg [7:0] prog_mem[0:ROM_BYTE_SIZE-1]; // 注意数组声明顺序调整
    integer i;

    // 新增/保留 CSR 寄存器结束判断逻辑
    reg sim_end_q;
    
    // 新增基于x26的测试结束检测
    reg x26_detected;
    reg [7:0] x26_delay_counter; // 用于替代#100延迟的计数器
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sim_end_q <= 1'b0;
            x26_detected <= 1'b0;
            x26_delay_counter <= 8'd0;
        end else begin
            sim_end_q <= sim_end;
            
            // 检测x26是否为1 - 新增逻辑
            if (x26 == 32'b1 && !x26_detected) begin
                x26_detected <= 1'b1;
            end
            
            // 如果检测到x26为1，则开始计数延迟
            if (x26_detected && x26_delay_counter < 8'd100) begin
                x26_delay_counter <= x26_delay_counter + 8'd1;
            end
            
            // 当延迟计数达到100后，输出测试结果
            if (x26_detected && x26_delay_counter == 8'd100) begin
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~ Test Result Summary ~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~ (x26/x27) ~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

                if (x27 == 32'b1) begin
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
                    $display("x%2d = 0x%x", r, tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[r]);
                end
                $finish;
            end
            
            // 检测sim_end从0变为1的上升沿 - 原有逻辑
            if (sim_end && (!sim_end_q)) begin
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~ Test Result Summary ~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~ (CSR) ~~~~~~~~~~~~~~~~");
                $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

                if (sim_succ == 1'b1) begin
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
                    $display("x%2d = 0x%x", r, tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[r]);
                end
                $finish;
            end
        end
    end

    // 超时监控
    reg [31:0] cycle_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 32'b0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
`ifdef NO_TIMEOUT
`else
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
            $display("itcm_init=%s", testcase);
        end else begin
            $display("No itcm_init defined!");
            $finish;
        end

        // 从.verilog文件中读取字节数据
        $readmemh({testcase, ".verilog"}, prog_mem);

        // 处理小端序格式并更新到新的ROM存储位置
        for (i = 0; i < ROM_DEPTH; i = i + 1) begin // 遍历ROM的每个字
            tinyriscv_soc_top_0.u_rom._rom[i] = {
                prog_mem[i*4+3], prog_mem[i*4+2],
                prog_mem[i*4+1], prog_mem[i*4+0]
            };
        end

        $display("成功加载指令到ROM，ROM深度:%0d字，字节大小:%0d", ROM_DEPTH, ROM_BYTE_SIZE);
        $display("ROM 0x00: %h", tinyriscv_soc_top_0.u_rom._rom[0]);
        $display("ROM 0x01: %h", tinyriscv_soc_top_0.u_rom._rom[1]);
        $display("ROM 0x02: %h", tinyriscv_soc_top_0.u_rom._rom[2]);
        $display("ROM 0x03: %h", tinyriscv_soc_top_0.u_rom._rom[3]);
        $display("ROM 0x04: %h", tinyriscv_soc_top_0.u_rom._rom[4]);
    end

`ifdef JTAGVPI
    wire jtag_TDI;
    wire jtag_TDO;
    wire jtag_TCK;
    wire jtag_TMS;
    assign jtag_TDI = tdi_i;
    assign tdo_o = jtag_TDO;
    assign jtag_TCK = tck_i;
    assign jtag_TMS = tms_i;
`else
    wire jtag_TDI = 1'b0;
    wire jtag_TDO;
    wire jtag_TCK = 1'b0;
    wire jtag_TMS = 1'b0;
    wire jtag_TRST = 1'b0;
`endif

    // 实例化顶层模块
    tinyriscv_soc_top tinyriscv_soc_top_0 (
        .clk           (clk),
        .rst           (rst),
        .uart_debug_pin(1'b0),
        .jtag_TCK      (jtag_TCK),
        .jtag_TMS      (jtag_TMS),
        .jtag_TDI      (jtag_TDI),
        .jtag_TDO      (jtag_TDO)
    );

    // 添加可选的寄存器调试输出功能
`ifdef DEBUG_DISPLAY_REGS
    // 监控GPR寄存器写入
    wire write_gpr_reg = tinyriscv_soc_top_0.u_tinyriscv.u_regs.we_i;
    wire[4:0] write_gpr_addr = tinyriscv_soc_top_0.u_tinyriscv.u_regs.waddr_i;

    // 监控CSR寄存器写入
    wire write_csr_reg = tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.we_i;
    wire[31:0] write_csr_addr = tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.waddr_i;
    
    always @(posedge clk) begin
        if (write_gpr_reg && (write_gpr_addr == 5'd31)) begin
            $display("\n");
            $display("GPR寄存器状态:");
            for (r = 0; r < 32; r = r + 1)
                $display("x%2d = 0x%x", r, tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[r]);
        end else if (write_csr_reg && (write_csr_addr[11:0] == 12'hc00)) begin
            $display("\n");
            $display("CSR寄存器状态:");
            $display("cycle = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.cycle[31:0]);
            $display("cycleh = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.cycle[63:32]);
            $display("mtvec = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mtvec);
            $display("mstatus = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mstatus);
            $display("mepc = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mepc);
            $display("mie = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mie);
            $display("mcause = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mcause);
            $display("mscratch = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mscratch);
            // 用于仿真的结束标志
            $display("sim_result = 0x%x", tinyriscv_soc_top_0.u_tinyriscv.u_csr_reg.mstatus);
        end
    end
`endif

endmodule
