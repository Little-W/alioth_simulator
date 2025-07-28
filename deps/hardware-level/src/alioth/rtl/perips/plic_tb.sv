`timescale 1ns/1ps

`define PLIC_AXI_DATA_WIDTH 32
`define PLIC_AXI_ADDR_WIDTH 16
`define PLIC_INT_EN_ADDR 16'h0000
`define PLIC_INT_MVEC_ADDR 16'h0100
`define PLIC_INT_MARG_ADDR 16'h0104
`define PLIC_INT_PRI_ADDR 16'h1000
`define PLIC_INT_VECTABLE_ADDR 16'h2000
`define PLIC_INT_OBJS_ADDR 16'h3000
`define PLIC_NUM_SOURCES 8

module plic_tb;

    reg clk, rst_n;
    reg [`PLIC_AXI_ADDR_WIDTH-1:0] addr;
    reg [`PLIC_AXI_DATA_WIDTH-1:0] wdata;
    reg [3:0] wstrb;
    reg wen;
    wire [`PLIC_AXI_DATA_WIDTH-1:0] rdata;
    reg [`PLIC_NUM_SOURCES-1:0] irq_sources;
    wire irq_valid;

    // 实例化PLIC
    plic uut (
        .clk(clk),
        .rst_n(rst_n),
        .waddr(addr),
        .wdata(wdata),
        .wstrb(wstrb),
        .wen(wen),
        .raddr(addr),
        .rdata(rdata),
        .irq_sources(irq_sources),
        .irq_valid(irq_valid)
    );

    // 时钟生成
    initial clk = 0;
    always #5 clk = ~clk;

    integer i;

    // 任务：写寄存器
    task write_reg(input [`PLIC_AXI_ADDR_WIDTH-1:0] a, input [`PLIC_AXI_DATA_WIDTH-1:0] d);
        begin
            @(negedge clk);
            addr  = a;
            wdata = d;
            wstrb = 4'b1111;
            wen   = 1'b1;
            @(negedge clk);
            wen   = 1'b0;
            addr  = 0;
            wdata = 0;
            wstrb = 0;
        end
    endtask

    // 任务：读寄存器（改为task，使用输出参数）
    task read_reg(input [`PLIC_AXI_ADDR_WIDTH-1:0] a, output [`PLIC_AXI_DATA_WIDTH-1:0] d);
        begin
            @(negedge clk);
            addr = a;
            @(negedge clk);
            d = rdata;
            addr = 0;
        end
    endtask

    // 定义每个中断源的向量地址
    reg [31:0] irq_vec_addr [0:`PLIC_NUM_SOURCES-1];

    // 定义MVEC寄存器读取值
    reg [`PLIC_AXI_DATA_WIDTH-1:0] mvec_val;

    initial begin
        // 初始化
        rst_n = 0;
        addr = 0;
        wdata = 0;
        wstrb = 0;
        wen = 0;
        irq_sources = 0;
        // 初始化向量地址
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            irq_vec_addr[i] = 32'h1000_0000 + i*32'h100;
        end
        #20;
        rst_n = 1;
        #10;

        // 配置8个中断源优先级
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            write_reg(`PLIC_INT_PRI_ADDR + i, (i+1)); // 优先级1~8
        end

        // 配置8个中断源向量地址
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            write_reg(`PLIC_INT_VECTABLE_ADDR + (i << 2), irq_vec_addr[i]);
        end

        // 使能所有中断
        write_reg(`PLIC_INT_EN_ADDR, 32'hFF);

        // 检查优先级和使能寄存器
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            read_reg(`PLIC_INT_PRI_ADDR + i, mvec_val);
        end
        read_reg(`PLIC_INT_EN_ADDR, mvec_val);

        // 检查向量表寄存器
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            read_reg(`PLIC_INT_VECTABLE_ADDR + (i << 2), mvec_val);
        end

        // 模拟中断输入
        #10;
        irq_sources = 8'b0000_0001; // 只触发中断0
        #10;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h)", irq_valid, mvec_val, irq_vec_addr[0]);

        irq_sources = 8'b0000_1001; // 触发中断0和3
        #10;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h)", irq_valid, mvec_val, irq_vec_addr[3]);

        irq_sources = 8'b1000_1001; // 触发中断0、3、7
        #10;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h)", irq_valid, mvec_val, irq_vec_addr[7]);

        irq_sources = 8'b0000_0000; // 无中断
        #10;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0)", irq_valid, mvec_val);

        // 改变优先级测试
        $display("=== Priority Change Test ===");
        write_reg(`PLIC_INT_PRI_ADDR + 3, 10); // 提高中断3优先级
        write_reg(`PLIC_INT_PRI_ADDR + 7, 2);  // 降低中断7优先级
        // 重新触发中断0、3、7
        irq_sources = 8'b1000_1001;
        #10;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, priority 3=10, 7=2)", irq_valid, mvec_val, irq_vec_addr[3]);

        // 再次改变优先级
        write_reg(`PLIC_INT_PRI_ADDR + 7, 15); // 提高中断7优先级
        #10;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, priority 7=15)", irq_valid, mvec_val, irq_vec_addr[7]);

        $finish;
    end

endmodule
