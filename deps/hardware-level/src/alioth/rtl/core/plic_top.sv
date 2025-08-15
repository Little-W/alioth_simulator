`timescale 1 ns / 1 ps
`include "defines.svh"

module plic_top #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 16
) (
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    input  wire [    C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire [                       2 : 0] S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    input  wire [    C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    output wire [                       1 : 0] S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [    C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input  wire [                       2 : 0] S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    output wire [    C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [                       1 : 0] S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY,
    // 外部中断源输入
    input  wire [       `PLIC_NUM_SOURCES-1:0] irq_sources,
    output wire                                irq_valid       // 有效中断输出
);

    reg  [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg                             axi_awready;
    reg                             axi_wready;
    reg  [                   1 : 0] axi_bresp;
    reg                             axi_bvalid;
    reg  [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg                             axi_arready;
    reg  [                   1 : 0] axi_rresp;
    reg                             axi_rvalid;

    wire [C_S_AXI_ADDR_WIDTH-1 : 0] mem_waddr;
    wire [C_S_AXI_DATA_WIDTH-1 : 0] mem_raddr;


    // === 定时器中断和软件中断信号 ===
    // assign timer_irq     = ({mtime_hi, mtime_lo} >= {mtimecmp_hi, mtimecmp_lo});
    // assign soft_irq      = msip;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;
    assign mem_waddr     = (S_AXI_AWVALID) ? S_AXI_AWADDR : axi_awaddr;
    assign mem_raddr     = (S_AXI_ARVALID) ? S_AXI_ARADDR : axi_araddr;

    reg [1:0] state_write;
    reg [1:0] state_read;
    localparam Idle = 2'b00, Raddr = 2'b10, Rdata = 2'b11, Waddr = 2'b10, Wdata = 2'b11;

    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_awready <= 0;
            axi_wready  <= 0;
            axi_bvalid  <= 0;
            axi_bresp   <= 0;
            axi_awaddr  <= 0;
            state_write <= Idle;
        end else begin
            case (state_write)
                Idle: begin
                    if (S_AXI_ARESETN == 1'b1) begin
                        axi_awready <= 1'b1;
                        axi_wready  <= 1'b1;
                        state_write <= Waddr;
                    end else state_write <= state_write;
                end
                Waddr: begin
                    if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                        axi_awaddr <= S_AXI_AWADDR;
                        if (S_AXI_WVALID) begin
                            axi_awready <= 1'b1;
                            state_write <= Waddr;
                            axi_bvalid  <= 1'b1;
                        end else begin
                            axi_awready <= 1'b0;
                            state_write <= Wdata;
                            if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
                        end
                    end else begin
                        state_write <= state_write;
                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
                    end
                end
                Wdata: begin
                    if (S_AXI_WVALID) begin
                        state_write <= Waddr;
                        axi_bvalid  <= 1'b1;
                        axi_awready <= 1'b1;
                    end else begin
                        state_write <= state_write;
                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
                    end
                end
                default: begin
                    state_write <= Idle;
                    axi_awready <= 1'b0;
                    axi_wready  <= 1'b0;
                    axi_bvalid  <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 1'b0;
            state_read  <= Idle;
        end else begin
            case (state_read)
                Idle: begin
                    if (S_AXI_ARESETN == 1'b1) begin
                        state_read  <= Raddr;
                        axi_arready <= 1'b1;
                    end else state_read <= state_read;
                end
                Raddr: begin
                    if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                        state_read  <= Rdata;
                        axi_araddr  <= S_AXI_ARADDR;
                        axi_rvalid  <= 1'b1;
                        axi_arready <= 1'b0;
                    end else state_read <= state_read;
                end
                Rdata: begin
                    if (S_AXI_RVALID && S_AXI_RREADY) begin
                        axi_rvalid  <= 1'b0;
                        axi_arready <= 1'b1;
                        state_read  <= Raddr;
                    end else state_read <= state_read;
                end
                default: begin
                    state_read  <= Idle;
                    axi_arready <= 1'b0;
                    axi_rvalid  <= 1'b0;
                end
            endcase
        end
    end


    // === 伪双端口PLIC接口信号 ===
    wire [`PLIC_AXI_DATA_WIDTH-1:0] plic_rdata;
    wire [`PLIC_AXI_ADDR_WIDTH-1:0] plic_waddr_wire;
    wire [`PLIC_AXI_ADDR_WIDTH-1:0] plic_raddr;
    wire [`PLIC_AXI_DATA_WIDTH-1:0] plic_wdata_wire;
    wire [                     3:0] plic_wstrb_wire;
    wire                            plic_wen_wire;

    // 写端口（先组合出 wire，再寄存一拍）
    assign plic_waddr_wire = (S_AXI_AWVALID) ? S_AXI_AWADDR[`PLIC_AXI_ADDR_WIDTH-1:0] : axi_awaddr[`PLIC_AXI_ADDR_WIDTH-1:0];
    assign plic_wdata_wire = S_AXI_WDATA;
    assign plic_wstrb_wire = S_AXI_WSTRB;
    assign plic_wen_wire   = S_AXI_WVALID && axi_wready;

    reg [`PLIC_AXI_ADDR_WIDTH-1:0] plic_waddr;
    reg [`PLIC_AXI_DATA_WIDTH-1:0] plic_wdata;
    reg [3:0]                      plic_wstrb;
    reg                            plic_wen;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            plic_waddr <= {`PLIC_AXI_ADDR_WIDTH{1'b0}};
            plic_wdata <= {`PLIC_AXI_DATA_WIDTH{1'b0}};
            plic_wstrb <= 4'b0;
            plic_wen   <= 1'b0;
        end else begin
            plic_waddr <= plic_waddr_wire;
            plic_wdata <= plic_wdata_wire;
            plic_wstrb <= plic_wstrb_wire;
            plic_wen   <= plic_wen_wire;
        end
    end

    // 读端口
    assign plic_raddr = (S_AXI_ARVALID) ? S_AXI_ARADDR[`PLIC_AXI_ADDR_WIDTH-1:0] : axi_araddr[`PLIC_AXI_ADDR_WIDTH-1:0];

    // === 同步读取 ===
    reg [`PLIC_AXI_DATA_WIDTH-1:0] plic_rdata_reg;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) plic_rdata_reg <= {`PLIC_AXI_DATA_WIDTH{1'b0}};
        else if (S_AXI_ARVALID && S_AXI_ARREADY) plic_rdata_reg <= plic_rdata;
    end

    assign S_AXI_RDATA = plic_rdata_reg;

    // === 实例化 plic（伪双端口） ===
    plic u_plic (
        .clk        (S_AXI_ACLK),
        .rst_n      (S_AXI_ARESETN),
        .waddr      (plic_waddr),
        .wdata      (plic_wdata),
        .wstrb      (plic_wstrb),
        .wen        (plic_wen),
        .raddr      (plic_raddr),
        .rdata      (plic_rdata),
        .irq_sources(irq_sources),
        .irq_valid  (irq_valid)
    );

endmodule
