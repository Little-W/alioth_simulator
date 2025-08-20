`include "defines.svh"

module plic (
    input wire clk,
    input wire rst_n,

    // 写端口
    input wire [`PLIC_AXI_ADDR_WIDTH-1:0] waddr,  // 写地址
    input wire [`PLIC_AXI_DATA_WIDTH-1:0] wdata,  // 写数据
    input wire [                     3:0] wstrb,  // 写字节使能
    input wire                            wen,    // 写使能

    // 读端口
    input  wire [`PLIC_AXI_ADDR_WIDTH-1:0] raddr,  // 读地址
    output reg  [`PLIC_AXI_DATA_WIDTH-1:0] rdata,  // 读数据

    // 外部中断源输入
    input wire [`PLIC_NUM_SOURCES-1:0] irq_sources,

    // 输出最高优先级中断号和中断有效信号
    output reg irq_valid  // 有效中断输出
);

    parameter PLIC_INT_VECTABLE_ADDR = `PLIC_INT_VECTABLE_ADDR;  // 中断向量表地址
    parameter PLIC_INT_OBJS_ADDR = `PLIC_INT_OBJS_ADDR;  // 中断对象参数表地址

    // 使能寄存器，每位对应一个中断源
    reg     [`PLIC_NUM_SOURCES-1:0] int_en;

    // 优先级寄存器，每个中断源8位优先级
    reg     [                  7:0] int_pri [`PLIC_NUM_SOURCES-1:0];

    // 中断向量表，每个中断源32位入口地址
    reg     [                 31:0] vectable[`PLIC_NUM_SOURCES-1:0];

    // MVEC寄存器
    reg     [                 31:0] mvec;
    reg     [                 31:0] mvec_next; // 新增打一拍寄存器

    // OBJ参数表，每个中断源32位参数
    reg     [                 31:0] objtable[`PLIC_NUM_SOURCES-1:0];

    // MARG寄存器
    reg     [                 31:0] marg;
    reg     [                 31:0] marg_next; // 新增打一拍寄存器

    integer                         i;

    reg [        `PLIC_NUM_SOURCES-1:0] valid_mask;
    reg [        `PLIC_NUM_SOURCES-1:0] valid_mask_r;
    reg [$clog2(`PLIC_NUM_SOURCES)-1:0] irq_id_next;
    reg                                 irq_valid_next;
    reg [$clog2(`PLIC_NUM_SOURCES)-1:0] irq_id;  // 最高优先级中断号

    // 实例化流水优先级选择模块
    wire [$clog2(`PLIC_NUM_SOURCES)-1:0] arbiter_max_id;
    wire                                arbiter_max_valid;
    plic_priority_arbiter #(
        .PLIC_NUM_SOURCES(`PLIC_NUM_SOURCES)
    ) u_plic_priority_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .pri_in(int_pri),         // 直接用int_pri
        .valid_in(valid_mask),    // 直接用valid_mask
        .find_max_id_out(arbiter_max_id),
        .find_max_valid_out(arbiter_max_valid)
    );

    reg [`PLIC_NUM_SOURCES-1:0] irq_sources_r; // 新增打一拍寄存器

    // irq_sources打一拍
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            irq_sources_r <= {`PLIC_NUM_SOURCES{1'b0}};
        else
            irq_sources_r <= irq_sources;
    end

    // valid_mask直接用int_en和打一拍后的irq_sources_r
    always @(*) begin
        valid_mask = irq_sources_r & int_en;
    end

    // valid_mask打一拍
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_mask_r <= {`PLIC_NUM_SOURCES{1'b0}};
        else valid_mask_r <= valid_mask;
    end

    // 优先级选择和中断有效判断使用arbiter输出
    always @(*) begin
        irq_valid_next = arbiter_max_valid;
        irq_id_next    = arbiter_max_id;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_id    <= {($clog2(`PLIC_NUM_SOURCES)) {1'b0}};
            irq_valid <= 1'b0;
            // MVEC寄存器复位
            mvec      <= 32'd0;
            // MARG寄存器复位
            marg      <= 32'd0;
            mvec_next <= 32'd0;
            marg_next <= 32'd0;
        end else begin
            irq_id    <= irq_id_next;
            irq_valid <= irq_valid_next;
            // 先打一拍优化时序
            if (irq_valid_next) begin
                mvec_next <= vectable[irq_id_next];
                marg_next <= objtable[irq_id_next];
            end
            mvec <= mvec_next;
            marg <= marg_next;
        end
    end

    // 写操作
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_en <= {`PLIC_NUM_SOURCES{1'b0}};
            for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) int_pri[i] <= 8'd0;
            for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) vectable[i] <= 32'd0;
            for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) objtable[i] <= 32'd0;
        end else if (wen) begin
            // 使能寄存器
            if (waddr == `PLIC_INT_EN_ADDR) begin
                // 修正为逐位赋值，避免越界
                for (i = 0; i < `PLIC_NUM_SOURCES; i = i + 1) begin
                    if (wstrb[i/8] && (i < 32)) begin
                        int_en[i] <= wdata[i];
                    end
                end
            end  // 优先级寄存器
            else if ((waddr >= `PLIC_INT_PRI_ADDR) && (waddr < (`PLIC_INT_PRI_ADDR + `PLIC_NUM_SOURCES))) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (wstrb[i]) begin
                        if (({waddr[`PLIC_AXI_ADDR_WIDTH-1:2],2'b0} - `PLIC_INT_PRI_ADDR + i) < `PLIC_NUM_SOURCES)
                            int_pri[{waddr[`PLIC_AXI_ADDR_WIDTH-1:2],2'b0} -`PLIC_INT_PRI_ADDR+i] <= wdata[i*8+:8];
                    end
                end
            end
            else if ((waddr[`PLIC_AXI_ADDR_WIDTH-1:2] >= PLIC_INT_VECTABLE_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2]) && (waddr[`PLIC_AXI_ADDR_WIDTH-1:2] < (PLIC_INT_VECTABLE_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2] + `PLIC_NUM_SOURCES))) begin
                vectable[waddr[10:2]] <= wdata;
            end  // objtable写操作
            else if ((waddr[`PLIC_AXI_ADDR_WIDTH-1:2] >= PLIC_INT_OBJS_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2]) && (waddr[`PLIC_AXI_ADDR_WIDTH-1:2] < (PLIC_INT_OBJS_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2] + `PLIC_NUM_SOURCES))) begin
                objtable[waddr[10:2]] <= wdata;
            end
        end
    end

    // 读操作
    always @(*) begin
        rdata = 32'd0;
        // 使能寄存器
        if (raddr == `PLIC_INT_EN_ADDR) begin
            rdata = {{(32 - `PLIC_NUM_SOURCES) {1'b0}}, int_en};
        end  // 优先级寄存器
        else if ((raddr >= `PLIC_INT_PRI_ADDR) && (raddr < (`PLIC_INT_PRI_ADDR + `PLIC_NUM_SOURCES))) begin
            for (i = 0; i < 4; i = i + 1) begin
                if ((raddr - `PLIC_INT_PRI_ADDR + i) < `PLIC_NUM_SOURCES)
                    rdata[i*8+:8] = int_pri[raddr-`PLIC_INT_PRI_ADDR+i];
            end
        end  // 最高优先级中断号
        else if (raddr == `PLIC_INT_VECTABLE_ADDR) begin
            rdata = {(32 - $clog2(`PLIC_NUM_SOURCES))'(0), irq_id};
        end  // 最高优先级中断对象
        else if (raddr == `PLIC_INT_MVEC_ADDR) begin      // 读取MVEC寄存器
            rdata = mvec;
        end else if (raddr == `PLIC_INT_MARG_ADDR) begin  // 读取MARG寄存器
            rdata = marg;
        end  // 读取vec_table寄存器组
        else if ((raddr[`PLIC_AXI_ADDR_WIDTH-1:2] >= PLIC_INT_VECTABLE_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2]) && (raddr[`PLIC_AXI_ADDR_WIDTH-1:2] < (PLIC_INT_VECTABLE_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2] + `PLIC_NUM_SOURCES))) begin
            rdata = vectable[raddr[10:2]];
        end  // 读取objtable寄存器组
        else if ((raddr[`PLIC_AXI_ADDR_WIDTH-1:2] >= PLIC_INT_OBJS_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2]) && (raddr[`PLIC_AXI_ADDR_WIDTH-1:2] < (PLIC_INT_OBJS_ADDR[`PLIC_AXI_ADDR_WIDTH-1:2] + `PLIC_NUM_SOURCES))) begin
            rdata = objtable[raddr[10:2]];
        end
    end

endmodule