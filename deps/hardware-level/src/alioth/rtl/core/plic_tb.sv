`timescale 1ns/1ps

`define PLIC_AXI_DATA_WIDTH 32
`define PLIC_AXI_ADDR_WIDTH 16
`define PLIC_INT_EN_ADDR 16'h0000
`define PLIC_INT_MVEC_ADDR 16'h0100
`define PLIC_INT_MARG_ADDR 16'h0104
`define PLIC_INT_PRI_ADDR 16'h1000
`define PLIC_INT_VECTABLE_ADDR 16'h2000
`define PLIC_INT_OBJS_ADDR 16'h3000
`define PLIC_NUM_SOURCES 11

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

    // 任务：按字节写寄存器（支持4字节对齐和部分字节写入，数据自动对齐）
    task write_reg_b(input [`PLIC_AXI_ADDR_WIDTH-1:0] a, input [7:0] d);
        reg [3:0] local_wstrb;
        reg [`PLIC_AXI_ADDR_WIDTH-1:0] aligned_addr;
        reg [`PLIC_AXI_DATA_WIDTH-1:0] aligned_data;
        begin
            aligned_addr = {a[`PLIC_AXI_ADDR_WIDTH-1:2], 2'b00};
            case (a[1:0])
                2'b00: begin local_wstrb = 4'b0001; aligned_data = {24'b0, d}; end
                2'b01: begin local_wstrb = 4'b0010; aligned_data = {16'b0, d, 8'b0}; end
                2'b10: begin local_wstrb = 4'b0100; aligned_data = {8'b0, d, 16'b0}; end
                2'b11: begin local_wstrb = 4'b1000; aligned_data = {d, 24'b0}; end
                default: begin local_wstrb = 4'b0000; aligned_data = 0; end
            endcase
            @(negedge clk);
            addr  = aligned_addr;
            wdata = aligned_data;
            wstrb = local_wstrb;
            wen   = 1'b1;
            @(negedge clk);
            wen   = 1'b0;
            addr  = 0;
            wdata = 0;
            wstrb = 0;
        end
    endtask

    // 任务：按字写寄存器（wstrb=4'b1111，写入32位）
    task write_reg_w(input [`PLIC_AXI_ADDR_WIDTH-1:0] a, input [`PLIC_AXI_DATA_WIDTH-1:0] d);
        reg [`PLIC_AXI_ADDR_WIDTH-1:0] aligned_addr;
        begin
            aligned_addr = {a[`PLIC_AXI_ADDR_WIDTH-1:2], 2'b00};
            @(negedge clk);
            addr  = aligned_addr;
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
            write_reg_b(`PLIC_INT_PRI_ADDR + i, (i+1)); // 优先级1~8
        end

        // 配置8个中断源向量地址（恢复为32位写入）
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            write_reg_w(`PLIC_INT_VECTABLE_ADDR + (i << 2), irq_vec_addr[i]);
        end

        // 使能所有中断（恢复为32位写入）
        write_reg_w(`PLIC_INT_EN_ADDR, 32'hFF);

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
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h)", irq_valid, mvec_val, irq_vec_addr[0]);

        irq_sources = 8'b0000_1001; // 触发中断0和3
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h)", irq_valid, mvec_val, irq_vec_addr[3]);

        irq_sources = 8'b1000_1001; // 触发中断0、3、7
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h)", irq_valid, mvec_val, irq_vec_addr[7]);

        irq_sources = 8'b0000_0000; // 无中断
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0)", irq_valid, mvec_val);

        // 改变优先级测试
        $display("=== Priority Change Test ===");
        write_reg_b(`PLIC_INT_PRI_ADDR + 3, 10); // 提高中断3优先级
        write_reg_b(`PLIC_INT_PRI_ADDR + 7, 2);  // 降低中断7优先级
        // 重新触发中断0、3、7
        irq_sources = 8'b1000_1001;
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, priority 3=10, 7=2)", irq_valid, mvec_val, irq_vec_addr[3]);

        // 再次改变优先级
        write_reg_b(`PLIC_INT_PRI_ADDR + 7, 15); // 提高中断7优先级
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, priority 7=15)", irq_valid, mvec_val, irq_vec_addr[7]);

        // 7优先级为2，其余为0，只触发3
        irq_sources = 8'b0000_0000; // 清除所有中断
        #10;
        $display("=== Only IRQ3 Active, Priority 7=2, Others=0 ===");
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
            if (i == 7)
                write_reg_b(`PLIC_INT_PRI_ADDR + i, 2);
            else
                write_reg_b(`PLIC_INT_PRI_ADDR + i, 0);
        end
        irq_sources = 8'b0000_1000; // 只触发中断3
        #200; // 增加等待时间
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, only irq3 active, priority 7=2)", irq_valid, mvec_val, irq_vec_addr[3]);

        // 所有优先级相同，多个输入
        $display("=== All Priorities Same, Multiple IRQs ===");
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1)
            write_reg_b(`PLIC_INT_PRI_ADDR + i, 5);
        irq_sources = 8'b1010_1001; // 触发0,3,5,7
        #200;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, all priorities=5, should pick irq0)", irq_valid, mvec_val, irq_vec_addr[0]);

        // 部分优先级相同，多个输入
        $display("=== Some Priorities Same, Multiple IRQs ===");
        for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1)
            write_reg_b(`PLIC_INT_PRI_ADDR + i, (i == 3 || i == 5 || i == 7) ? 8 : 2);
        irq_sources = 8'b1010_1000; // 触发3,5,7
        #200;
        read_reg(`PLIC_INT_MVEC_ADDR, mvec_val);
        $display("irq_valid=%b, mvec=0x%08h (expect 0x%08h, priorities 3/5/7=8, should pick irq3)", irq_valid, mvec_val, irq_vec_addr[3]);

        $finish;
    end

endmodule
