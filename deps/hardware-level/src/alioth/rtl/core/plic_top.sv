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
    input  wire [       `PLIC_NUM_SOURCES-1:0] irq_sources,
    output wire                                irq_valid
);

    // AXI信号寄存器
    reg  [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg                             axi_awready;
    reg                             axi_wready;
    reg  [                   1 : 0] axi_bresp;
    reg                             axi_bvalid;
    reg  [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg                             axi_arready;
    reg  [                   1 : 0] axi_rresp;
    reg                             axi_rvalid;

    // 地址和数据选择逻辑
    wire [C_S_AXI_ADDR_WIDTH-1 : 0] mem_waddr = (S_AXI_AWVALID) ? S_AXI_AWADDR : axi_awaddr;
    wire [C_S_AXI_ADDR_WIDTH-1 : 0] mem_raddr = (S_AXI_ARVALID) ? S_AXI_ARADDR : axi_araddr;
    wire addr_bit2_w = mem_waddr[2];
    wire addr_bit2_r = mem_raddr[2];
    wire [31:0] selected_wdata = addr_bit2_w ? S_AXI_WDATA[63:32] : S_AXI_WDATA[31:0];
    wire [3:0]  selected_wstrb = addr_bit2_w ? S_AXI_WSTRB[7:4]   : S_AXI_WSTRB[3:0];
    wire [`PLIC_AXI_ADDR_WIDTH-1:0] reg_waddr = {mem_waddr[`PLIC_AXI_ADDR_WIDTH-1:3], 1'b0, mem_waddr[1:0]};
    wire [`PLIC_AXI_ADDR_WIDTH-1:0] reg_raddr = {mem_raddr[`PLIC_AXI_ADDR_WIDTH-1:3], 1'b0, mem_raddr[1:0]};

    // PLIC接口信号
    wire [`PLIC_AXI_DATA_WIDTH-1:0] plic_rdata;
    wire [`PLIC_AXI_ADDR_WIDTH-1:0] plic_waddr;
    wire [`PLIC_AXI_ADDR_WIDTH-1:0] plic_raddr;
    wire [`PLIC_AXI_DATA_WIDTH-1:0] plic_wdata;
    wire [                     3:0] plic_wstrb;
    wire                            plic_wen;

    // 写端口
    assign plic_waddr = reg_waddr;
    assign plic_wdata = selected_wdata;
    assign plic_wstrb = selected_wstrb;
    assign plic_wen   = S_AXI_WVALID && axi_wready;
    // 读端口
    assign plic_raddr = reg_raddr;

    // AXI接口信号输出
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // 状态机
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

    // 读取数据寄存器
    reg [31:0] plic_rdata_reg;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) plic_rdata_reg <= 32'b0;
        else if (S_AXI_ARVALID && S_AXI_ARREADY) plic_rdata_reg <= plic_rdata;
    end
    // 输出到AXI总线
    assign S_AXI_RDATA = addr_bit2_r ? {plic_rdata_reg, 32'h0} : {32'h0, plic_rdata_reg};

    // 实例化PLIC
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
