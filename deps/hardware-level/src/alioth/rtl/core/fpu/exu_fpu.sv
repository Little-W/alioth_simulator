import fpu_types::*;

module exu_fpu (
    input  logic                        clk,
    input  logic                        rst_n,
    // 外部输入信号
    input  logic                        req_fpu_i,
    input  logic                        fpu_op_fadd_i,
    input  logic                        fpu_op_fsub_i,
    input  logic                        fpu_op_fmul_i,
    input  logic                        fpu_op_fdiv_i,
    input  logic                        fpu_op_fsqrt_i,
    input  logic                        fpu_op_fsgnj_i,
    input  logic                        fpu_op_fmax_i,
    input  logic                        fpu_op_fcmp_i,
    input  logic                        fpu_op_fcvt_f2i_i,
    input  logic                        fpu_op_fcvt_i2f_i,
    input  logic                        fpu_op_fcvt_f2f_i, // 新增fcvt_f2f输入
    input  logic                        fpu_op_fmadd_i,
    input  logic                        fpu_op_fmsub_i,
    input  logic                        fpu_op_fnmadd_i,
    input  logic                        fpu_op_fnmsub_i,
    input  logic                        fpu_op_fmv_i2f_i,
    input  logic                        fpu_op_fmv_f2i_i,
    input  logic                        fpu_op_fclass_i,
    input  logic [`FREG_DATA_WIDTH-1:0] fpu_op1_i,
    input  logic [`FREG_DATA_WIDTH-1:0] fpu_op2_i,
    input  logic [`FREG_DATA_WIDTH-1:0] fpu_op3_i,
    input  logic [                 2:0] frm_i,
    input  logic [                 1:0] fcvt_op_i,
    input  logic [                 2:0] csr_frm_i,
    input  logic [`COMMIT_ID_WIDTH-1:0] commit_id_i,
    input  logic [ `REG_ADDR_WIDTH-1:0] reg_waddr_i,
    input  logic                        wb_ready_i,
    input  logic [                 1:0] fmt_i,
    // 输出寄存器接口
    output logic                        reg_we_o,
    output logic [ `REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output logic [`FREG_DATA_WIDTH-1:0] reg_wdata_o,
    output logic                        fcsr_we_o,
    output logic [                 4:0] fcsr_fflags_o,
    output logic                        fflags_pending_o,
    output logic                        fpu_stall_o,
    output logic [`COMMIT_ID_WIDTH-1:0] commit_id_o
);

    // 内部信号定义
    fpu_types::fpu_top_in_type                         fpu_top_i;
    fpu_types::fpu_top_out_type                        fpu_top_o;

    // 补全寄存器定义
    logic                                            reg_we_r;
    logic                     [`FREG_DATA_WIDTH-1:0] reg_wdata_r;
    logic                     [ `REG_ADDR_WIDTH-1:0] reg_waddr_r;
    logic                     [`COMMIT_ID_WIDTH-1:0] commit_id_r;
    logic                                            fcsr_we_r;
    logic                     [                 4:0] fcsr_fflags_r;

    // 输入信号转结构体
    fpu_types::fpu_hub_in_type                          fpu_hub_in_s;

    logic                                            fpu_req_valid;
    assign fpu_req_valid = req_fpu_i & ~fpu_busy;

    always_comb begin
        fpu_hub_in_s.data1       = fpu_op1_i;
        fpu_hub_in_s.data2       = fpu_op2_i;
        fpu_hub_in_s.data3       = fpu_op3_i;
        fpu_hub_in_s.fmt         = fmt_i;
        fpu_hub_in_s.enable      = fpu_req_valid;
        fpu_hub_in_s.op          = fpu_types::init_fpu_operation;
        fpu_hub_in_s.op.fmadd    = fpu_op_fmadd_i;
        fpu_hub_in_s.op.fmsub    = fpu_op_fmsub_i;
        fpu_hub_in_s.op.fnmadd   = fpu_op_fnmadd_i;
        fpu_hub_in_s.op.fnmsub   = fpu_op_fnmsub_i;
        fpu_hub_in_s.op.fadd     = fpu_op_fadd_i;
        fpu_hub_in_s.op.fsub     = fpu_op_fsub_i;
        fpu_hub_in_s.op.fmul     = fpu_op_fmul_i;
        fpu_hub_in_s.op.fdiv     = fpu_op_fdiv_i;
        fpu_hub_in_s.op.fsqrt    = fpu_op_fsqrt_i;
        fpu_hub_in_s.op.fsgnj    = fpu_op_fsgnj_i;
        fpu_hub_in_s.op.fcmp     = fpu_op_fcmp_i;
        fpu_hub_in_s.op.fmax     = fpu_op_fmax_i;
        fpu_hub_in_s.op.fmv_i2f  = fpu_op_fmv_i2f_i;
        fpu_hub_in_s.op.fmv_f2i  = fpu_op_fmv_f2i_i;
        fpu_hub_in_s.op.fcvt_i2f = fpu_op_fcvt_i2f_i;
        fpu_hub_in_s.op.fcvt_f2i = fpu_op_fcvt_f2i_i;
        fpu_hub_in_s.op.fcvt_f2f = fpu_op_fcvt_f2f_i; // 新增fcvt_f2f赋值
        fpu_hub_in_s.op.fclass   = fpu_op_fclass_i;
        fpu_hub_in_s.op.fcvt_op  = fcvt_op_i;
        // frm选择逻辑：frm_i为111时用csr_frm_i，否则用frm_i
        fpu_hub_in_s.rm          = (frm_i == 3'b111) ? csr_frm_i : frm_i;
    end
    assign fpu_top_i = '{fpu_hub_i: fpu_hub_in_s};

    // 实例化 fpu_top
    fpu_top u_fpu_top (
        .rst_n    (rst_n),
        .clk    (clk),
        .fpu_top_i(fpu_top_i),
        .fpu_top_o(fpu_top_o),
        .clear    (1'b0)
    );

    wire                        fpu_ready = fpu_top_o.fpu_hub_o.ready;
    wire [`FREG_DATA_WIDTH-1:0] fpu_result = fpu_top_o.fpu_hub_o.result;
    wire [                 4:0] fpu_flags = fpu_top_o.fpu_hub_o.flags;

    wire                        wb_hsk = (reg_we_r & wb_ready_i);
    // 输出暂存一级寄存器改为握手式
    wire                        update_output = fpu_ready | wb_hsk;

    // 结果寄存器
    gnrl_dfflr #(
        .DW(`FREG_DATA_WIDTH)
    ) u_result_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fpu_result),
        .qout (reg_wdata_r)
    );

    // 写使能寄存器
    gnrl_dfflr #(
        .DW(1)
    ) u_r_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fpu_ready),
        .qout (reg_we_r)
    );

    // 写地址寄存器
    gnrl_dfflr #(
        .DW(`REG_ADDR_WIDTH)
    ) u_r_waddr_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (fpu_req_valid),
        .dnxt (reg_waddr_i),
        .qout (reg_waddr_r)
    );

    // commit_id寄存器
    gnrl_dfflr #(
        .DW(`COMMIT_ID_WIDTH)
    ) u_commit_id_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (fpu_req_valid),
        .dnxt (commit_id_i),
        .qout (commit_id_r)
    );

    // FCSR写使能寄存器
    gnrl_dfflr #(
        .DW(1)
    ) u_fcsr_we_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fpu_ready & (fpu_flags != 5'b0)),
        .qout (fcsr_we_r)
    );

    // FCSR FFLAGS寄存器
    gnrl_dfflr #(
        .DW(5)
    ) u_fcsr_fflags_dfflr (
        .clk  (clk),
        .rst_n(rst_n),
        .lden (update_output),
        .dnxt (fpu_flags),
        .qout (fcsr_fflags_r)
    );

    // FFLAGS相关指令检测wire（筛除不影响FFLAGS的指令）
    wire fflags_req = fpu_req_valid & (
        fpu_op_fadd_i    | fpu_op_fsub_i    | fpu_op_fmul_i    | fpu_op_fdiv_i    |
        fpu_op_fsqrt_i   | fpu_op_fmax_i    | fpu_op_fcmp_i    |
        fpu_op_fcvt_f2i_i| fpu_op_fcvt_i2f_i| fpu_op_fcvt_f2f_i| // 新增fcvt_f2f
        fpu_op_fmadd_i   | fpu_op_fmsub_i   |
        fpu_op_fnmadd_i  | fpu_op_fnmsub_i
    );

    // FFLAGS等待更新状态寄存器
    logic fflags_pending_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) fflags_pending_r <= 1'b0;
        else if (fflags_req) fflags_pending_r <= 1'b1;
        else if (wb_hsk) fflags_pending_r <= 1'b0;
    end

    // fpu_busy定义
    logic fpu_busy;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) fpu_busy <= 1'b0;
        else if (fpu_req_valid) fpu_busy <= 1'b1;
        else if (wb_hsk) fpu_busy <= 1'b0;
    end

    // 输出信号赋值
    assign reg_we_o         = reg_we_r;
    assign reg_waddr_o      = reg_waddr_r;
    assign reg_wdata_o      = reg_wdata_r;
    assign commit_id_o      = commit_id_r;
    assign fcsr_we_o        = fcsr_we_r;
    assign fcsr_fflags_o    = fcsr_fflags_r;
    assign fflags_pending_o = fflags_pending_r;

    // fpu_stall_o逻辑
    assign fpu_stall_o      = fpu_busy & req_fpu_i;

endmodule
