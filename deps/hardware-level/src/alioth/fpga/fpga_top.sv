`timescale 1 ns / 1 ps

`include "defines.svh"

// ToHost程序地址,用于监控测试是否结束
`define PC_WRITE_TOHOST 32'h00000040

`define ITCM alioth_soc_top_0.u_cpu_top.u_mems.u_itcm

module fpga_top (
    input  wire       clk,      // 系统时钟
    input  wire       rst_n,    // 低电平有效复位
    output reg        led_pass, // 测试通过指示灯
    output reg        led_fail  // 测试失败指示灯
);

    // 通用寄存器访问 - 用于结果判断
    wire    [   31:0] x3 = alioth_soc_top_0.u_cpu_top.u_gpr.regs[3];
    wire    [   31:0] pc = alioth_soc_top_0.u_cpu_top.u_ifu.u_ifu_ifetch.pc_o;

    // 计算ITCM的深度和字节大小
    localparam ITCM_DEPTH = (1 << (`ITCM_ADDR_WIDTH - 2));  // ITCM中的字数

    // 添加PC监控变量
    reg [31:0] pc_write_to_host_cnt;
    reg [31:0] cycle_count;
    reg [31:0] last_pc;  // 添加一个寄存器来存储上一次的PC值
    reg test_completed;  // 测试完成标志

    // 周期计数器 - 保持同步实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 32'b0;
            last_pc     <= 32'b0;  // 初始化上一次的PC值
        end else begin
            cycle_count <= cycle_count + 1'b1;
            last_pc     <= pc;  // 在时钟边缘更新上一次的PC值，用于检测变化
        end
    end

    // PC监控逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_write_to_host_cnt <= 32'b0;
            test_completed <= 1'b0;
            led_pass <= 1'b0;
            led_fail <= 1'b0;
        end else begin
            // 检测PC到达指定地址
            if (pc == `PC_WRITE_TOHOST && pc != last_pc) begin
                pc_write_to_host_cnt <= pc_write_to_host_cnt + 1'b1;
            end
            
            // 检测测试结束条件
            if (pc_write_to_host_cnt == 32'd8 && !test_completed) begin
                test_completed <= 1'b1;
                
                // 根据x3寄存器的值判断测试通过或失败
                if (x3 == 1) begin
                    led_pass <= 1'b1;  // 测试通过，点亮通过指示灯
                    led_fail <= 1'b0;
                end else begin
                    led_pass <= 1'b0;
                    led_fail <= 1'b1;  // 测试失败，点亮失败指示灯
                end
            end
        end
    end

    // 实例化顶层模块
    alioth_soc_top alioth_soc_top_0 (
        .clk           (clk),
        .rst_n           (rst_n)
    );

endmodule
