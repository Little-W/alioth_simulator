`timescale 1 ns / 1 ps
`include "defines.svh"

module clint_swi #(
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
    output wire                                timer_irq,
    output wire                                soft_irq
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


    // CLINT寄存器
    reg                             msip;
    reg [31:0] mtimecmp_lo, mtimecmp_hi;
    reg [31:0] mtime_lo, mtime_hi;

    // === 定时器中断和软件中断信号 ===
    assign timer_irq     = ({mtime_hi, mtime_lo} >= {mtimecmp_hi, mtimecmp_lo});
    assign soft_irq      = msip;

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
            endcase
        end
    end

    // 写操作
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            msip        <= 1'b0;
            mtimecmp_lo <= 32'hFFFF_FFFF;
            mtimecmp_hi <= 32'hFFFF_FFFF;
            mtime_lo    <= 32'h0;  // 初始化 mtime_lo
            mtime_hi    <= 32'h0;  // 初始化 mtime_hi
        end else begin

            // mtime自增
            {mtime_hi, mtime_lo} <= {mtime_hi, mtime_lo} + 64'd1;

            if (S_AXI_WVALID) begin
                case (mem_waddr)
                    `CLINT_MSIP_ADDR: begin
                        if (S_AXI_WSTRB[0]) msip <= S_AXI_WDATA[0];
                    end
                    `CLINT_MTIMECMP_ADDR: begin
                        for (int i = 0; i < 4; i = i + 1)
                        if (S_AXI_WSTRB[i]) mtimecmp_lo[i*8+:8] <= S_AXI_WDATA[i*8+:8];
                    end
                    `CLINT_MTIMECMP_ADDR_H: begin
                        for (int i = 0; i < 4; i = i + 1)
                        if (S_AXI_WSTRB[i]) mtimecmp_hi[i*8+:8] <= S_AXI_WDATA[i*8+:8];
                    end
                    `CLINT_MTIME_ADDR: begin
                        for (int i = 0; i < 4; i = i + 1)
                        if (S_AXI_WSTRB[i]) mtime_lo[i*8+:8] <= S_AXI_WDATA[i*8+:8];
                    end
                    `CLINT_MTIME_ADDR_H: begin
                        for (int i = 0; i < 4; i = i + 1)
                        if (S_AXI_WSTRB[i]) mtime_hi[i*8+:8] <= S_AXI_WDATA[i*8+:8];
                    end
                    default: ;
                endcase
            end
        end
    end

    // 读操作
    reg [31:0] clint_rdata;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            clint_rdata <= 32'b0;
        end else if (S_AXI_ARVALID && S_AXI_ARREADY) begin
            case (S_AXI_ARADDR)
                `CLINT_MSIP_ADDR:       clint_rdata <= {31'b0, msip};
                `CLINT_MTIMECMP_ADDR:   clint_rdata <= mtimecmp_lo;
                `CLINT_MTIMECMP_ADDR_H: clint_rdata <= mtimecmp_hi;
                `CLINT_MTIME_ADDR:      clint_rdata <= mtime_lo;
                `CLINT_MTIME_ADDR_H:    clint_rdata <= mtime_hi;
                default:                clint_rdata <= 32'b0;
            endcase
        end
    end

    assign S_AXI_RDATA = clint_rdata;

endmodule
