`timescale 1 ns / 1 ps

`include "defines.v"

`ifdef JTAGVPI
  `define NO_TIMEOUT
`endif

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
    wire rst = ~rst_n;
    
    wire    [`REG_DATA_WIDTH-1:0] x3 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[3];
    wire    [`REG_DATA_WIDTH-1:0] x26 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[26];
    wire    [`REG_DATA_WIDTH-1:0] x27 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[27];

    integer           r;
    reg     [8*300:1] testcase;
    integer           dumpwave;

    // 计算ROM的深度和字节大小
    localparam ROM_DEPTH = (1 << (`ROM_ADDR_WIDTH - 2)); // ROM中的字数
    localparam ROM_BYTE_SIZE = ROM_DEPTH * 4; // 总字节数

    // 创建与ROM容量相同的临时字节数组
    reg [7:0] rom_mem[ROM_BYTE_SIZE-1:0]; // 注意数组声明顺序调整
    integer i;

    // 监控测试结果
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位逻辑
        end else if (x26 == 32'b1) begin  // 等待测试结束信号
            #100
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
    end

    // 超时监控
    reg [31:0] cycle_count;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
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

        // 从.verilog文件中读取字节数据 - 不使用返回值赋值
        $readmemh({testcase, ".verilog"}, rom_mem);

        // 处理小端序格式
        for (i = 0; i < ROM_DEPTH; i = i + 1) begin // 遍历ROM的每个字
            tinyriscv_soc_top_0.u_rom._rom[i] = {
                rom_mem[i*4+3], rom_mem[i*4+2], 
                rom_mem[i*4+1], rom_mem[i*4+0]
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

endmodule
