`include "defines.svh"

module plic (
    input wire clk,
    input wire rst_n,

    // 写端口
    input wire [`PLIC_AXI_ADDR_WIDTH-1:0] waddr,  // 写地址
    input wire [                    31:0] wdata,  // 写数据 - 固定32位
    input wire [                     3:0] wstrb,  // 写字节使能
    input wire                            wen,    // 写使能

    // 读端口
    input  wire [`PLIC_AXI_ADDR_WIDTH-1:0] raddr,  // 读地址
    output reg  [                    31:0] rdata,  // 读数据 - 固定32位

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

    // OBJ参数表，每个中断源32位参数
    reg     [                 31:0] objtable[`PLIC_NUM_SOURCES-1:0];

    // MARG寄存器
    reg     [                 31:0] marg;

    integer                         i;

    // 最高优先级选择逻辑（二分查找）
    function automatic [$clog2(`PLIC_NUM_SOURCES)-1:0] find_max_id;
        input [7:0] pri[`PLIC_NUM_SOURCES-1:0];
        input [`PLIC_NUM_SOURCES-1:0] valid;
        input integer left, right;
        reg [$clog2(`PLIC_NUM_SOURCES)-1:0] l_idx, r_idx;
        reg [7:0] l_pri, r_pri;
        begin
            if (left == right) begin
                if (valid[left]) find_max_id = left[$clog2(`PLIC_NUM_SOURCES)-1:0];
                else find_max_id = {($clog2(`PLIC_NUM_SOURCES)) {1'b0}};
            end else begin
                integer mid;
                mid   = (left + right) >> 1;
                l_idx = find_max_id(pri, valid, left, mid);
                r_idx = find_max_id(pri, valid, mid + 1, right);
                l_pri = (valid[l_idx]) ? pri[l_idx] : 8'd0;
                r_pri = (valid[r_idx]) ? pri[r_idx] : 8'd0;
                // 优先级非零优先，否则选第一个valid
                if (l_pri > r_pri) find_max_id = l_idx;
                else if (r_pri > l_pri) find_max_id = r_idx;
                else if (valid[l_idx]) find_max_id = l_idx;
                else find_max_id = r_idx;
            end
        end
    endfunction

    reg [        `PLIC_NUM_SOURCES-1:0] valid_mask;
    reg [        `PLIC_NUM_SOURCES-1:0] valid_mask_r;
    reg [$clog2(`PLIC_NUM_SOURCES)-1:0] irq_id_next;
    reg                                 irq_valid_next;
    reg [$clog2(`PLIC_NUM_SOURCES)-1:0] irq_id;  // 最高优先级中断号

    always @(*) begin
        valid_mask = irq_sources & int_en;
    end

    // valid_mask打一拍
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_mask_r <= {`PLIC_NUM_SOURCES{1'b0}};
        else valid_mask_r <= valid_mask;
    end

    // 优先级选择和中断有效判断使用valid_mask_r
    always @(*) begin
        irq_valid_next = |valid_mask_r;
        irq_id_next    = find_max_id(int_pri, valid_mask_r, 0, `PLIC_NUM_SOURCES - 1);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_id    <= {($clog2(`PLIC_NUM_SOURCES)) {1'b0}};
            irq_valid <= 1'b0;
            // MVEC寄存器复位
            mvec      <= 32'd0;
            // MARG寄存器复位
            marg      <= 32'd0;
        end else begin
            irq_id    <= irq_id_next;
            irq_valid <= irq_valid_next;
            // irq_valid有效时，MVEC寄存器更新为对应vectable项
            if (irq_valid) begin
                mvec <= vectable[irq_id];
                marg <= objtable[irq_id];
            end
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
