module plic_priority_arbiter #(
    parameter PLIC_NUM_SOURCES = 32
) (
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic [                         7:0] pri_in            [PLIC_NUM_SOURCES-1:0],
    input  logic [        PLIC_NUM_SOURCES-1:0] valid_in,
    output logic [$clog2(PLIC_NUM_SOURCES)-1:0] find_max_id_out,
    output logic                                find_max_valid_out
);

    // 1. 向上取整到2的幂次方
    localparam integer NUM_SOURCES = PLIC_NUM_SOURCES;
    localparam integer MAX_SOURCES_POW2 = 1 << ($clog2(NUM_SOURCES - 1));

    // 2. 计算流水线级数
    localparam integer NUM_STAGES = $clog2(MAX_SOURCES_POW2);
    localparam integer ID_WIDTH = $clog2(MAX_SOURCES_POW2);

    // 中间结果的寄存器数组，用于存储每一级的结果
    logic [         7:0] pri_regs   [NUM_STAGES:0][MAX_SOURCES_POW2-1:0];
    logic [ID_WIDTH-1:0] id_regs    [NUM_STAGES:0][MAX_SOURCES_POW2-1:0];

    // 有效信号流水线
    logic [NUM_STAGES:0] valid_regs;

    // 计算输入是否有效
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_regs[0] <= 1'b0;
        else valid_regs[0] <= |valid_in;
    end

    // 有效信号流水线推进
    genvar vstage;
    generate
        for (vstage = 0; vstage < NUM_STAGES; vstage = vstage + 1) begin : valid_regsline
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) valid_regs[vstage+1] <= 1'b0;
                else valid_regs[vstage+1] <= valid_regs[vstage];
            end
        end
    endgenerate

    // 初始化第一级输入
    genvar i;
    generate
        for (i = 0; i < NUM_SOURCES; i = i + 1) begin : stage0_initial
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) pri_regs[0][i] <= 8'd0;
                else pri_regs[0][i] <= valid_in[i] ? pri_in[i] : 8'd0;
            end
            assign id_regs[0][i] = i;
        end
        for (i = NUM_SOURCES; i < MAX_SOURCES_POW2; i = i + 1) begin : stage0_pad
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) pri_regs[0][i] <= 8'd0;
                else pri_regs[0][i] <= 8'd0;
            end
            assign id_regs[0][i] = i;
        end
    endgenerate

    // 3. 使用generate语句生成流水线各级
    genvar stage;
    generate
        for (stage = 0; stage < NUM_STAGES; stage = stage + 1) begin : arbiter_pipeline
            localparam integer NUM_ELEMENTS_PREV = MAX_SOURCES_POW2 >> stage;
            localparam integer NUM_PAIRS_CURR = NUM_ELEMENTS_PREV >> 1;

            genvar j;
            for (j = 0; j < NUM_PAIRS_CURR; j = j + 1) begin : compare_pair
                // 每一级都从上一级的有效结果中取值
                wire [         7:0] pri_l = pri_regs[stage][2*j];
                wire [         7:0] pri_r = pri_regs[stage][2*j+1];
                wire [ID_WIDTH-1:0] id_l = id_regs[stage][2*j];
                wire [ID_WIDTH-1:0] id_r = id_regs[stage][2*j+1];

                // 组合逻辑，在每个阶段比较
                wire [         7:0] next_pri;
                wire [ID_WIDTH-1:0] next_id;

                assign next_pri = (pri_l > pri_r) ? pri_l : (pri_r > pri_l) ? pri_r : pri_l;

                assign next_id  = (pri_l > pri_r) ? id_l : (pri_r > pri_l) ? id_r : id_l;

                // 注册每个阶段的结果到下一级
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        pri_regs[stage+1][j] <= 8'd0;
                        id_regs[stage+1][j]  <= '0;
                    end else begin
                        pri_regs[stage+1][j] <= next_pri;
                        id_regs[stage+1][j]  <= next_id;
                    end
                end
            end  // for (j)
        end  // for (stage)
    endgenerate


    // 固定优先级旁路流水线
    logic [ID_WIDTH-1:0] fixed_id_regs[NUM_STAGES:0][MAX_SOURCES_POW2-1:0];

    // 初始化第一级输入 - 固定优先级
    generate
        for (i = 0; i < NUM_SOURCES; i = i + 1) begin : fixed_stage0_initial
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) fixed_id_regs[0][i] <= {ID_WIDTH{1'b1}};
                else fixed_id_regs[0][i] <= valid_in[i] ? i : {ID_WIDTH{1'b1}};
            end
        end
        for (i = NUM_SOURCES; i < MAX_SOURCES_POW2; i = i + 1) begin : fixed_stage0_pad
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) fixed_id_regs[0][i] <= {ID_WIDTH{1'b1}};
                else fixed_id_regs[0][i] <= {ID_WIDTH{1'b1}};
            end
        end
    endgenerate

    // 固定优先级流水线
    generate
        for (stage = 0; stage < NUM_STAGES; stage = stage + 1) begin : fixed_pipeline
            localparam integer NUM_ELEMENTS_PREV = MAX_SOURCES_POW2 >> stage;
            localparam integer NUM_PAIRS_CURR = NUM_ELEMENTS_PREV >> 1;

            genvar j;
            for (j = 0; j < NUM_PAIRS_CURR; j = j + 1) begin : fixed_compare_pair
                wire [ID_WIDTH-1:0] id_l = fixed_id_regs[stage][2*j];
                wire [ID_WIDTH-1:0] id_r = fixed_id_regs[stage][2*j+1];

                wire [ID_WIDTH-1:0] next_id;
                assign next_id = (id_l < id_r) ? id_l : id_r;

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) fixed_id_regs[stage+1][j] <= {ID_WIDTH{1'b1}};
                    else fixed_id_regs[stage+1][j] <= next_id;
                end
            end
        end
    endgenerate

    // 检查所有优先级是否相等
    logic all_pri_equal;
    always_comb begin
        all_pri_equal = 1'b1;
        for (int k = 1; k < NUM_SOURCES; k++) begin
            if (pri_regs[0][k] != pri_regs[0][0]) begin
                all_pri_equal = 1'b0;
            end
        end
    end

    // all_pri_equal流水线寄存器
    logic [NUM_STAGES:0] all_pri_equal_regs;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) all_pri_equal_regs[0] <= 1'b0;
        else all_pri_equal_regs[0] <= all_pri_equal;
    end

    genvar estage;
    generate
        for (estage = 0; estage < NUM_STAGES; estage = estage + 1) begin : all_pri_equal_pipeline
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) all_pri_equal_regs[estage+1] <= 1'b0;
                else all_pri_equal_regs[estage+1] <= all_pri_equal_regs[estage];
            end
        end
    endgenerate

    // 最终输出
    assign find_max_id_out    = all_pri_equal_regs[NUM_STAGES] ? fixed_id_regs[NUM_STAGES][0] : id_regs[NUM_STAGES][0];
    assign find_max_valid_out = valid_regs[NUM_STAGES];

endmodule
