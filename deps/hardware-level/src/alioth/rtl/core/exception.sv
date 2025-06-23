// alioth处理器异常处理模块（SystemVerilog实现）

module exception #(
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // 指令相关
    input  logic [`INST_ADDR_WIDTH-1:0] inst_addr_i,
    input  logic [`DECINFO_WIDTH-1:0]   dec_info_bus_i,
    input  logic [31:0]                 dec_imm_i,
    input  logic                        inst_valid_i,

    // 系统操作信号
    input  logic                        ecall_i,
    input  logic                        ebreak_i,
    input  logic                        mret_i,

    // CSR相关
    input  logic [`REG_DATA_WIDTH-1:0]  csr_mtvec_i,
    input  logic [`REG_DATA_WIDTH-1:0]  csr_mepc_i,
    input  logic [`REG_DATA_WIDTH-1:0]  csr_mstatus_i,
    input  logic                        global_int_en_i,

    // 外部中断
    input  logic                        int_assert_i,
    input  logic [`INST_ADDR_WIDTH-1:0] int_addr_i,

    // 输出到CSR
    output logic                        csr_we_o,
    output logic [`BUS_ADDR_WIDTH-1:0]  csr_waddr_o,
    output logic [`REG_DATA_WIDTH-1:0]  csr_wdata_o,

    // 输出到流水线/控制
    output logic                        stall_flag_o,
    output logic [`INST_ADDR_WIDTH-1:0] excp_jump_addr_o,
    output logic                        excp_jump_flag_o
);

    // CSR地址定义
    localparam logic [11:0] CSR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_MSTATUS = 12'h300;

    // 异常类型定义
    localparam logic [31:0] EXC_NONE    = 32'd0;
    localparam logic [31:0] EXC_ECALL   = 32'd11;
    localparam logic [31:0] EXC_EBREAK  = 32'd3;

    // 状态机定义
    typedef enum logic [1:0] {
        S_IDLE,
        S_WRITE_MCAUSE,
        S_WRITE_MEPC,
        S_WRITE_MSTATUS,
        S_JUMP
    } state_t;

    state_t state_q, state_d;

    logic [31:0] exc_cause_d, exc_cause_q;
    logic [`INST_ADDR_WIDTH-1:0] exc_addr_d, exc_addr_q;

    // 异常/中断判定
    logic exc_ecall, exc_ebreak, exc_mret, exc_int, exc_any;
    assign exc_ecall  = inst_valid_i && ecall_i;
    assign exc_ebreak = inst_valid_i && ebreak_i;
    assign exc_mret   = inst_valid_i && mret_i;
    assign exc_int    = int_assert_i && global_int_en_i;
    assign exc_any    = exc_ecall | exc_ebreak | exc_int;

    // 状态机
    always_comb begin
        // 默认值
        state_d           = state_q;
        csr_we_o          = 1'b0;
        csr_waddr_o       = '0;
        csr_wdata_o       = '0;
        stall_flag_o      = 1'b0;
        excp_jump_addr_o  = '0;
        excp_jump_flag_o  = 1'b0;
        exc_cause_d       = exc_cause_q;
        exc_addr_d        = exc_addr_q;

        case (state_q)
            S_IDLE: begin
                if (exc_int) begin
                    exc_cause_d = 32'h8000000b; // Machine external interrupt
                    exc_addr_d  = inst_addr_i;
                    state_d     = S_WRITE_MCAUSE;
                    stall_flag_o = 1'b1;
                end else if (exc_ecall) begin
                    exc_cause_d = EXC_ECALL;
                    exc_addr_d  = inst_addr_i;
                    state_d     = S_WRITE_MCAUSE;
                    stall_flag_o = 1'b1;
                end else if (exc_ebreak) begin
                    exc_cause_d = EXC_EBREAK;
                    exc_addr_d  = inst_addr_i;
                    state_d     = S_WRITE_MCAUSE;
                    stall_flag_o = 1'b1;
                end else if (exc_mret) begin
                    excp_jump_addr_o = csr_mepc_i;
                    excp_jump_flag_o = 1'b1;
                    csr_we_o    = 1'b1;
                    csr_waddr_o = CSR_MSTATUS;
                    csr_wdata_o = {csr_mstatus_i[`REG_DATA_WIDTH-1:4], 1'b1, csr_mstatus_i[2:0]};
                    state_d     = S_IDLE;
                end
            end

            S_WRITE_MCAUSE: begin
                csr_we_o    = 1'b1;
                csr_waddr_o = CSR_MCAUSE;
                csr_wdata_o = exc_cause_q;
                state_d     = S_WRITE_MEPC;
                stall_flag_o = 1'b1;
            end

            S_WRITE_MEPC: begin
                csr_we_o    = 1'b1;
                csr_waddr_o = CSR_MEPC;
                csr_wdata_o = exc_addr_q;
                state_d     = S_WRITE_MSTATUS;
                stall_flag_o = 1'b1;
            end

            S_WRITE_MSTATUS: begin
                csr_we_o    = 1'b1;
                csr_waddr_o = CSR_MSTATUS;
                csr_wdata_o = {csr_mstatus_i[`REG_DATA_WIDTH-1:4], 1'b0, csr_mstatus_i[2:0]};
                state_d     = S_JUMP;
                stall_flag_o = 1'b1;
            end

            S_JUMP: begin
                excp_jump_flag_o = 1'b1;
                excp_jump_addr_o = exc_int ? int_addr_i : csr_mtvec_i;
                state_d = S_IDLE;
            end

            default: state_d = S_IDLE;
        endcase
    end

    // 状态寄存器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q      <= S_IDLE;
            exc_cause_q  <= 32'd0;
            exc_addr_q   <= '0;
        end else begin
            state_q      <= state_d;
            exc_cause_q  <= exc_cause_d;
            exc_addr_q   <= exc_addr_d;
        end
    end

endmodule