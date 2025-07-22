`include "defines.svh"

module axi2apb #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 30,
    parameter integer C_APB_ADDR_WIDTH   = 30
) (
    // AXI-lite接口信号
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

    // APB接口信号 - 使用数组定义
    output wire                          PCLK,
    output wire                          PRESETn,
    output wire [    `APB_DEV_COUNT-1:0] PSEL,
    output wire                          PENABLE,
    output wire [  C_APB_ADDR_WIDTH-1:0] PADDR,
    output wire                          PWRITE,
    output wire [C_S_AXI_DATA_WIDTH-1:0] PWDATA,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] PRDATA [`APB_DEV_COUNT],
    input  wire [    `APB_DEV_COUNT-1:0] PREADY,
    input  wire [    `APB_DEV_COUNT-1:0] PSLVERR
);

    // 时钟和复位信号直接连接
    assign PCLK    = S_AXI_ACLK;
    assign PRESETn = S_AXI_ARESETN;

    // APB状态机状态定义
    localparam IDLE = 2'b00;
    localparam SETUP = 2'b01;
    localparam ACCESS = 2'b10;

    // AXI状态机状态定义
    localparam WRITE_IDLE = 2'b00;
    localparam WRITE_ADDR = 2'b01;
    localparam WRITE_DATA = 2'b10;
    localparam WRITE_RESP = 2'b11;

    localparam READ_IDLE = 2'b00;
    localparam READ_ADDR = 2'b01;
    localparam READ_DATA = 2'b10;
    localparam READ_RESP = 2'b11;

    // 状态寄存器
    reg  [                   1:0] apb_state;
    reg  [                   1:0] write_state;
    reg  [                   1:0] read_state;

    // 寄存器定义
    reg  [  C_APB_ADDR_WIDTH-1:0] addr_reg;
    reg  [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;
    reg  [C_S_AXI_DATA_WIDTH-1:0] rdata_reg;
    reg                           write_reg;
    reg  [                   1:0] resp_reg;
    reg  [    `APB_DEV_COUNT-1:0] dev_sel;

    // AXI信号控制
    reg                           awready_reg;
    reg                           wready_reg;
    reg  [                   1:0] bresp_reg;
    reg                           bvalid_reg;
    reg  [  C_APB_ADDR_WIDTH-1:0] araddr_reg;
    reg                           arready_reg;
    reg  [                   1:0] rresp_reg;
    reg                           rvalid_reg;

    // APB信号控制
    reg                           penable_reg;
    reg  [    `APB_DEV_COUNT-1:0] psel_reg;
    reg                           pwrite_reg;

    // 传输控制标志
    reg                           apb_start;
    reg                           apb_write;
    wire                          apb_read_done;
    wire                          apb_write_done;

    // 输出信号赋值
    assign S_AXI_AWREADY = awready_reg;
    assign S_AXI_WREADY  = wready_reg;
    assign S_AXI_BRESP   = bresp_reg;
    assign S_AXI_BVALID  = bvalid_reg | apb_write_done;
    assign S_AXI_ARREADY = arready_reg;
    assign S_AXI_RDATA   = rdata_reg;
    assign S_AXI_RRESP   = rresp_reg;
    assign S_AXI_RVALID  = rvalid_reg;

    assign PSEL          = psel_reg;
    assign PENABLE       = penable_reg;
    assign PADDR         = addr_reg;
    assign PWRITE        = pwrite_reg;
    assign PWDATA        = wdata_reg;

    // 地址解码函数
    function [`APB_DEV_COUNT-1:0] addr_decode;
        input [C_APB_ADDR_WIDTH-1:0] addr;
        begin
            addr_decode = 0;
            if (addr <= `APB_DEV0_ADDR_HIGH) addr_decode[0] = 1'b1;
            else if (addr >= `APB_DEV1_ADDR_LOW && addr <= `APB_DEV1_ADDR_HIGH)
                addr_decode[1] = 1'b1;
            else if (addr >= `APB_DEV2_ADDR_LOW && addr <= `APB_DEV2_ADDR_HIGH)
                addr_decode[2] = 1'b1;
            else if (addr >= `APB_DEV3_ADDR_LOW && addr <= `APB_DEV3_ADDR_HIGH)
                addr_decode[3] = 1'b1;
            else if (addr >= `APB_DEV4_ADDR_LOW && addr <= `APB_DEV4_ADDR_HIGH)
                addr_decode[4] = 1'b1;
        end
    endfunction

    // APB设备选择信号
    always @(*) begin
        dev_sel = addr_decode(addr_reg);
    end

    // 读数据多路复用器 - 使用临时变量避免对rdata_reg进行阻塞赋值
    reg [C_S_AXI_DATA_WIDTH-1:0] rdata_mux;
    always @(*) begin
        rdata_mux = 0;
        for (int i = 0; i < `APB_DEV_COUNT; i++) begin
            if (psel_reg[i]) rdata_mux = PRDATA[i];
        end
    end

    // PREADY信号汇总
    wire apb_ready;
    assign apb_ready = PREADY[dev_sel] == 1'b1;

    // PSLVERR信号汇总
    wire apb_slverr;
    assign apb_slverr     = PSLVERR[dev_sel] == 1'b1;

    assign apb_read_done  = (apb_state == ACCESS) && (!pwrite_reg) && apb_ready;
    assign apb_write_done = (apb_state == ACCESS) && (pwrite_reg) && apb_ready;

    // 写通道状态机
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            write_state <= WRITE_IDLE;
            awready_reg <= 1'b0;
            wready_reg  <= 1'b0;
            bvalid_reg  <= 1'b0;
            bresp_reg   <= 2'b00;  // OKAY
            apb_write   <= 1'b0;
            apb_start   <= 1'b0;
        end else begin
            case (write_state)
                WRITE_IDLE: begin
                    awready_reg <= 1'b1;
                    wready_reg  <= 1'b1;

                    if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                        addr_reg    <= S_AXI_AWADDR[C_APB_ADDR_WIDTH-1:0];
                        awready_reg <= 1'b0;

                        if (S_AXI_WVALID) begin
                            // 地址和数据同时准备好
                            wdata_reg   <= S_AXI_WDATA;
                            wready_reg  <= 1'b0;
                            write_state <= WRITE_RESP;
                            apb_write   <= 1'b1;
                            apb_start   <= 1'b1;
                        end else begin
                            // 只有地址准备好
                            write_state <= WRITE_DATA;
                        end
                    end
                end

                WRITE_DATA: begin
                    if (S_AXI_WVALID) begin
                        wdata_reg   <= S_AXI_WDATA;
                        wready_reg  <= 1'b0;
                        write_state <= WRITE_RESP;
                        apb_write   <= 1'b1;
                        apb_start   <= 1'b1;
                    end
                end

                WRITE_RESP: begin
                    apb_start <= 1'b0;

                    if (apb_write_done) begin
                        bvalid_reg <= 1'b1;
                        bresp_reg  <= apb_slverr ? 2'b10 : 2'b00;  // SLVERR : OKAY
                    end

                    if (S_AXI_BREADY && S_AXI_BVALID) begin
                        bvalid_reg  <= 1'b0;
                        write_state <= WRITE_IDLE;
                        awready_reg <= 1'b1;
                        wready_reg  <= 1'b1;
                        apb_write   <= 1'b0;
                    end
                end

                default: write_state <= WRITE_IDLE;
            endcase
        end
    end

    // 读通道状态机
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            read_state  <= READ_IDLE;
            arready_reg <= 1'b0;
            rvalid_reg  <= 1'b0;
            rresp_reg   <= 2'b00;  // OKAY
            apb_write   <= 1'b0;
            rdata_reg   <= 0;  // 重置rdata_reg
        end else begin
            case (read_state)
                READ_IDLE: begin
                    arready_reg <= 1'b1;

                    if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                        addr_reg    <= S_AXI_ARADDR[C_APB_ADDR_WIDTH-1:0];
                        arready_reg <= 1'b0;
                        read_state  <= READ_DATA;
                        apb_write   <= 1'b0;
                        apb_start   <= 1'b1;
                    end
                end

                READ_DATA: begin
                    apb_start  <= 1'b0;
                    rvalid_reg <= 1'b0;
                    if (apb_read_done) begin
                        rvalid_reg <= 1'b1;
                        rresp_reg  <= apb_slverr ? 2'b10 : 2'b00;  // SLVERR : OKAY
                        rdata_reg  <= rdata_mux;  // 使用多路复用器的输出
                        read_state <= READ_RESP;
                    end
                end

                READ_RESP: begin
                    if (S_AXI_RREADY && S_AXI_RVALID) begin
                        rvalid_reg  <= 1'b0;
                        read_state  <= READ_IDLE;
                        arready_reg <= 1'b1;
                        apb_start   <= 1'b0;
                    end
                end

                default: read_state <= READ_IDLE;
            endcase
        end
    end

    // APB状态机
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            apb_state   <= IDLE;
            psel_reg    <= 0;
            penable_reg <= 1'b0;
            pwrite_reg  <= 1'b0;
        end else begin
            case (apb_state)
                IDLE: begin
                    penable_reg <= 1'b0;
                    psel_reg    <= 0;

                    if (apb_start) begin
                        apb_state  <= SETUP;
                        psel_reg   <= dev_sel;
                        pwrite_reg <= apb_write;
                    end
                end

                SETUP: begin
                    apb_state   <= ACCESS;
                    penable_reg <= 1'b1;
                end

                ACCESS: begin
                    if (apb_ready) begin
                        apb_state   <= IDLE;
                        penable_reg <= 1'b0;
                        psel_reg    <= 0;
                    end
                end

                default: apb_state <= IDLE;
            endcase
        end
    end

endmodule
