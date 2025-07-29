/*         
 The MIT License (MIT)

 Copyright © 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
                                                                         
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
                                                                         
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "defines.svh"

// 写回单元 - 负责寄存器写回逻辑、仲裁优先级和WAW冲突处理
module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ADDER数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] adder1_reg_wdata_i,
    input  wire                        adder1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] adder1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] adder1_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] adder1_timestamp_exu,
    output wire                        adder1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] adder2_reg_wdata_i,
    input  wire                        adder2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] adder2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] adder2_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] adder2_timestamp_exu,
    output wire                        adder2_ready_o,

    // 来自EXU的SHIFTER数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] shifter1_reg_wdata_i,
    input  wire                        shifter1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] shifter1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] shifter1_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] shifter1_timestamp_exu,
    output wire                        shifter1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] shifter2_reg_wdata_i,
    input  wire                        shifter2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] shifter2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] shifter2_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] shifter2_timestamp_exu,
    output wire                        shifter2_ready_o,

    // 来自EXU的MUL数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] mul1_reg_wdata_i,
    input  wire                        mul1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul1_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] mul1_timestamp_exu,
    output wire                        mul1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] mul2_reg_wdata_i,
    input  wire                        mul2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul2_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] mul2_timestamp_exu,
    output wire                        mul2_ready_o,

    // 来自EXU的DIV数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] div1_reg_wdata_i,
    input  wire                        div1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div1_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] div1_timestamp_exu,
    output wire                        div1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] div2_reg_wdata_i,
    input  wire                        div2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div2_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] div2_timestamp_exu,
    output wire                        div2_ready_o,

    // 来自EXU的CSR数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] csr1_wdata_i,
    input  wire                        csr1_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr1_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr1_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] csr1_timestamp_exu,
    output wire                        csr1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] csr2_wdata_i,
    input  wire                        csr2_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr2_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr2_commit_id_i,
    input  wire [`TIMESTAMP_WIDTH-1:0] csr2_timestamp_exu,
    output wire                        csr2_ready_o,

    // CSR寄存器写数据输入 (双发射)
    input wire [`REG_DATA_WIDTH-1:0] csr1_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr1_reg_waddr_i,
    input wire                       csr1_reg_we_i,

    input wire [`REG_DATA_WIDTH-1:0] csr2_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0] csr2_reg_waddr_i,
    input wire                       csr2_reg_we_i,

    // 来自EXU的LSU数据 (双发射)
    input wire [ `REG_DATA_WIDTH-1:0] lsu1_reg_wdata_i,
    input wire                        lsu1_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu1_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu1_commit_id_i,
    output wire                       lsu1_ready_o,

    input wire [ `REG_DATA_WIDTH-1:0] lsu2_reg_wdata_i,
    input wire                        lsu2_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu2_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu2_commit_id_i,
    output wire                       lsu2_ready_o,

    // HDU指令地址和时间戳输入
    input wire [`REG_ADDR_WIDTH-1:0] inst1_rd_addr_i,
    input wire [`REG_ADDR_WIDTH-1:0] inst2_rd_addr_i,
    input wire [`TIMESTAMP_WIDTH-1:0] inst1_timestamp_hdu,
    input wire [`TIMESTAMP_WIDTH-1:0] inst2_timestamp_hdu,

    input wire [`REG_ADDR_WIDTH-1:0] idu_reg_waddr_i,

    // 中断信号
    input wire int_assert_i,

    // 长指令完成信号（对接hazard_detection）
    output wire                        commit_valid1_o,  // 指令完成有效信号1
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id1_o,     // 完成指令ID1
    output wire                        commit_valid2_o,  // 指令完成有效信号2
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id2_o,     // 完成指令ID2

    // 双寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] reg1_wdata_o,
    output wire                       reg1_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg1_waddr_o,

    output wire [`REG_DATA_WIDTH-1:0] reg2_wdata_o,
    output wire                       reg2_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg2_waddr_o,

    // 双CSR寄存器写回接口
    output wire [`REG_DATA_WIDTH-1:0] csr1_wdata_o,
    output wire                       csr1_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr1_waddr_o,

    output wire [`REG_DATA_WIDTH-1:0] csr2_wdata_o,
    output wire                       csr2_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr2_waddr_o
);

    // ========================================================================
    // FIFO结构定义和WAW冲突处理逻辑
    // ========================================================================
    
    // 定义执行单元标识
    localparam EU_ADDER1   = 4'd0;
    localparam EU_ADDER2   = 4'd1;
    localparam EU_SHIFTER1 = 4'd2;
    localparam EU_SHIFTER2 = 4'd3;
    localparam EU_MUL1     = 4'd4;
    localparam EU_MUL2     = 4'd5;
    localparam EU_DIV1     = 4'd6;
    localparam EU_DIV2     = 4'd7;
    localparam EU_CSR1     = 4'd8;
    localparam EU_CSR2     = 4'd9;
    localparam EU_LSU1     = 4'd10;
    localparam EU_LSU2     = 4'd11;
    
    // FIFO参数
    localparam FIFO_DEPTH = 8;
    localparam FIFO_ADDR_WIDTH = 3;
    
    // FIFO表项
    reg [`REG_ADDR_WIDTH-1:0] fifo_waddr [0:FIFO_DEPTH-1];
    reg [`TIMESTAMP_WIDTH-1:0] fifo_timestamp [0:FIFO_DEPTH-1];
    reg [FIFO_DEPTH-1:0] fifo_valid;
    
    // 缓冲队列参数
    localparam BUFFER_SIZE = 8;
    localparam BUFFER_ADDR_WIDTH = 3;
    
    // 待写回缓冲队列
    reg [`REG_DATA_WIDTH-1:0] pending_reg_wdata [0:BUFFER_SIZE-1];
    reg [`REG_ADDR_WIDTH-1:0] pending_reg_waddr [0:BUFFER_SIZE-1];
    reg [`COMMIT_ID_WIDTH-1:0] pending_commit_id [0:BUFFER_SIZE-1];
    reg [`TIMESTAMP_WIDTH-1:0] pending_timestamp [0:BUFFER_SIZE-1];
    reg [3:0] pending_eu_type [0:BUFFER_SIZE-1];  // 执行单元类型
    reg [BUFFER_SIZE-1:0] pending_valid;          // 缓冲有效标志
    reg [BUFFER_SIZE-1:0] pending_is_csr;         // 标识是否为CSR写回
    reg [`BUS_ADDR_WIDTH-1:0] pending_csr_waddr [0:BUFFER_SIZE-1];
    reg [`REG_DATA_WIDTH-1:0] pending_csr_wdata [0:BUFFER_SIZE-1];
    
    // 缓冲队列控制信号
    wire [BUFFER_ADDR_WIDTH-1:0] buffer_alloc_ptr;
    wire buffer_full, buffer_empty;
    reg [BUFFER_ADDR_WIDTH:0] buffer_count;
    
    // 当前周期执行单元写回请求
    wire [11:0] eu_reg_we;
    wire [11:0] eu_csr_we;
    wire [`REG_DATA_WIDTH-1:0] eu_reg_wdata [0:11];
    wire [`REG_ADDR_WIDTH-1:0] eu_reg_waddr [0:11];
    wire [`COMMIT_ID_WIDTH-1:0] eu_commit_id [0:11];
    wire [`TIMESTAMP_WIDTH-1:0] eu_timestamp [0:11];
    wire [`BUS_ADDR_WIDTH-1:0] eu_csr_waddr [0:11];
    wire [`REG_DATA_WIDTH-1:0] eu_csr_wdata [0:11];
    
    // 组织执行单元输入信号
    assign eu_reg_we = {lsu2_reg_we_i, lsu1_reg_we_i, csr2_reg_we_i, csr1_reg_we_i,
                       div2_reg_we_i, div1_reg_we_i, mul2_reg_we_i, mul1_reg_we_i,
                       shifter2_reg_we_i, shifter1_reg_we_i, adder2_reg_we_i, adder1_reg_we_i};
    
    assign eu_csr_we = {2'b0, csr2_we_i, csr1_we_i, 8'b0};
    
    assign eu_reg_wdata[0] = adder1_reg_wdata_i;
    assign eu_reg_wdata[1] = adder2_reg_wdata_i;
    assign eu_reg_wdata[2] = shifter1_reg_wdata_i;
    assign eu_reg_wdata[3] = shifter2_reg_wdata_i;
    assign eu_reg_wdata[4] = mul1_reg_wdata_i;
    assign eu_reg_wdata[5] = mul2_reg_wdata_i;
    assign eu_reg_wdata[6] = div1_reg_wdata_i;
    assign eu_reg_wdata[7] = div2_reg_wdata_i;
    assign eu_reg_wdata[8] = csr1_reg_wdata_i;
    assign eu_reg_wdata[9] = csr2_reg_wdata_i;
    assign eu_reg_wdata[10] = lsu1_reg_wdata_i;
    assign eu_reg_wdata[11] = lsu2_reg_wdata_i;
    
    assign eu_reg_waddr[0] = adder1_reg_waddr_i;
    assign eu_reg_waddr[1] = adder2_reg_waddr_i;
    assign eu_reg_waddr[2] = shifter1_reg_waddr_i;
    assign eu_reg_waddr[3] = shifter2_reg_waddr_i;
    assign eu_reg_waddr[4] = mul1_reg_waddr_i;
    assign eu_reg_waddr[5] = mul2_reg_waddr_i;
    assign eu_reg_waddr[6] = div1_reg_waddr_i;
    assign eu_reg_waddr[7] = div2_reg_waddr_i;
    assign eu_reg_waddr[8] = csr1_reg_waddr_i;
    assign eu_reg_waddr[9] = csr2_reg_waddr_i;
    assign eu_reg_waddr[10] = lsu1_reg_waddr_i;
    assign eu_reg_waddr[11] = lsu2_reg_waddr_i;
    
    assign eu_commit_id[0] = adder1_commit_id_i;
    assign eu_commit_id[1] = adder2_commit_id_i;
    assign eu_commit_id[2] = shifter1_commit_id_i;
    assign eu_commit_id[3] = shifter2_commit_id_i;
    assign eu_commit_id[4] = mul1_commit_id_i;
    assign eu_commit_id[5] = mul2_commit_id_i;
    assign eu_commit_id[6] = div1_commit_id_i;
    assign eu_commit_id[7] = div2_commit_id_i;
    assign eu_commit_id[8] = csr1_commit_id_i;
    assign eu_commit_id[9] = csr2_commit_id_i;
    assign eu_commit_id[10] = lsu1_commit_id_i;
    assign eu_commit_id[11] = lsu2_commit_id_i;
    
    assign eu_timestamp[0] = adder1_timestamp_exu;
    assign eu_timestamp[1] = adder2_timestamp_exu;
    assign eu_timestamp[2] = shifter1_timestamp_exu;
    assign eu_timestamp[3] = shifter2_timestamp_exu;
    assign eu_timestamp[4] = mul1_timestamp_exu;
    assign eu_timestamp[5] = mul2_timestamp_exu;
    assign eu_timestamp[6] = div1_timestamp_exu;
    assign eu_timestamp[7] = div2_timestamp_exu;
    assign eu_timestamp[8] = csr1_timestamp_exu;
    assign eu_timestamp[9] = csr2_timestamp_exu;
    assign eu_timestamp[10] = {`TIMESTAMP_WIDTH{1'b0}}; // LSU1没有timestamp
    assign eu_timestamp[11] = {`TIMESTAMP_WIDTH{1'b0}}; // LSU2没有timestamp
    
    assign eu_csr_waddr[8] = csr1_waddr_i;
    assign eu_csr_waddr[9] = csr2_waddr_i;
    assign eu_csr_wdata[8] = csr1_wdata_i;
    assign eu_csr_wdata[9] = csr2_wdata_i;
    
    // WAW冲突检测 - 基于FIFO的新逻辑
    reg [11:0] waw_conflict_detected;  // 检测到WAW冲突的执行单元
    reg [11:0] waw_conflict_delay;     // 需要延迟写回的执行单元
    
    // FIFO管理信号
    reg [FIFO_ADDR_WIDTH:0] fifo_count;
    wire [FIFO_ADDR_WIDTH-1:0] fifo_alloc_ptr1, fifo_alloc_ptr2;
    wire fifo_full, fifo_empty;
    
    assign fifo_full = (fifo_count >= FIFO_DEPTH - 1);  // 保留一个位置给第二个指令
    assign fifo_empty = (fifo_count == 0);
    assign fifo_alloc_ptr1 = fifo_count[FIFO_ADDR_WIDTH-1:0];
    assign fifo_alloc_ptr2 = (fifo_count + 1)[FIFO_ADDR_WIDTH-1:0];
    
    // WAW冲突检测逻辑
    always @(*) begin
        waw_conflict_detected = 12'b0;
        waw_conflict_delay = 12'b0;
        
        for (integer eu_idx = 0; eu_idx < 12; eu_idx = eu_idx + 1) begin
            if (eu_reg_we[eu_idx] || eu_csr_we[eu_idx]) begin
                for (integer fifo_idx = 0; fifo_idx < FIFO_DEPTH; fifo_idx = fifo_idx + 1) begin
                    if (fifo_valid[fifo_idx] && 
                        fifo_waddr[fifo_idx] == eu_reg_waddr[eu_idx]) begin
                        
                        waw_conflict_detected[eu_idx] = 1'b1;
                        
                        // 比较timestamp，决定是否延迟
                        if (eu_timestamp[eu_idx] != fifo_timestamp[fifo_idx]) begin
                            // timestamp不同，比较大小
                            if (eu_timestamp[eu_idx] > fifo_timestamp[fifo_idx]) begin
                                waw_conflict_delay[eu_idx] = 1'b1;
                            end
                        end
                        // timestamp相同认为是同一个指令，不产生冲突
                        break;
                    end
                end
            end
        end
    end
    
    // 同周期内的WAW冲突检测
    reg [11:0] current_cycle_conflict;
    always @(*) begin
        current_cycle_conflict = 12'b0;
        
        for (integer i = 0; i < 12; i = i + 1) begin
            for (integer j = i + 1; j < 12; j = j + 1) begin
                if ((eu_reg_we[i] || eu_csr_we[i]) && 
                    (eu_reg_we[j] || eu_csr_we[j]) &&
                    eu_reg_waddr[i] == eu_reg_waddr[j]) begin
                    
                    // 比较timestamp，小的优先
                    if (eu_timestamp[i] > eu_timestamp[j]) begin
                        current_cycle_conflict[i] = 1'b1;
                    end else if (eu_timestamp[j] > eu_timestamp[i]) begin
                        current_cycle_conflict[j] = 1'b1;
                    end
                    // timestamp相同时按优先级处理（在后面的仲裁逻辑中）
                end
            end
        end
    end
    
    // 缓冲队列管理
    assign buffer_full = (buffer_count == BUFFER_SIZE);
    assign buffer_empty = (buffer_count == 0);
    assign buffer_alloc_ptr = buffer_count[BUFFER_ADDR_WIDTH-1:0];
    
    // 找到最高优先级的缓冲项进行释放
    reg [BUFFER_ADDR_WIDTH-1:0] buffer_release_ptr;
    reg buffer_release_valid;
    reg [`COMMIT_ID_WIDTH-1:0] max_commit_id;
    
    always @(*) begin
        buffer_release_valid = 1'b0;
        buffer_release_ptr = 3'b0;
        max_commit_id = 3'b0;
        
        for (integer idx = 0; idx < BUFFER_SIZE; idx = idx + 1) begin
            if (pending_valid[idx] && pending_commit_id[idx] >= max_commit_id) begin
                max_commit_id = pending_commit_id[idx];
                buffer_release_ptr = idx[BUFFER_ADDR_WIDTH-1:0];
                buffer_release_valid = 1'b1;
            end
        end
    end
    
    // 当前周期可以直接写回的执行单元
    wire [11:0] eu_can_writeback;
    assign eu_can_writeback = (eu_reg_we | eu_csr_we) & 
                             (~waw_conflict_delay) & 
                             (~current_cycle_conflict) &
                             {12{~buffer_full}};  // 缓冲满时暂停所有新的写回
    
    // 选择两个最高优先级的写回请求（优先级：LSU > DIV > MUL > CSR > ADDER > SHIFTER）
    reg [3:0] wb_ch1_eu, wb_ch2_eu;
    reg wb_ch1_valid, wb_ch2_valid;
    reg wb_ch1_from_buffer, wb_ch2_from_buffer;
    
    always @(*) begin
        wb_ch1_valid = 1'b0;
        wb_ch2_valid = 1'b0;
        wb_ch1_eu = 4'd0;
        wb_ch2_eu = 4'd0;
        wb_ch1_from_buffer = 1'b0;
        wb_ch2_from_buffer = 1'b0;
        
        // 优先处理缓冲队列中的请求
        if (buffer_release_valid && !buffer_empty) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_from_buffer = 1'b1;
        end
        
        // 从当前周期请求中选择最高优先级的
        // 按优先级顺序检查：LSU2, LSU1, DIV2, DIV1, MUL2, MUL1, CSR2, CSR1, ADDER2, ADDER1, SHIFTER2, SHIFTER1
        if (!wb_ch1_valid && eu_can_writeback[11]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_LSU2;
        end else if (!wb_ch1_valid && eu_can_writeback[10]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_LSU1;
        end else if (!wb_ch1_valid && eu_can_writeback[7]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_DIV2;
        end else if (!wb_ch1_valid && eu_can_writeback[6]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_DIV1;
        end else if (!wb_ch1_valid && eu_can_writeback[5]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_MUL2;
        end else if (!wb_ch1_valid && eu_can_writeback[4]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_MUL1;
        end else if (!wb_ch1_valid && eu_can_writeback[9]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_CSR2;
        end else if (!wb_ch1_valid && eu_can_writeback[8]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_CSR1;
        end else if (!wb_ch1_valid && eu_can_writeback[1]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_ADDER2;
        end else if (!wb_ch1_valid && eu_can_writeback[0]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_ADDER1;
        end else if (!wb_ch1_valid && eu_can_writeback[3]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_SHIFTER2;
        end else if (!wb_ch1_valid && eu_can_writeback[2]) begin
            wb_ch1_valid = 1'b1;
            wb_ch1_eu = EU_SHIFTER1;
        end
        
        // 选择第二个写回通道（排除已选择的）
        if (wb_ch1_valid && !wb_ch1_from_buffer) begin
            // 屏蔽已选择的执行单元
            if (eu_can_writeback[11] && wb_ch1_eu != EU_LSU2) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_LSU2;
            end else if (eu_can_writeback[10] && wb_ch1_eu != EU_LSU1) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_LSU1;
            end else if (eu_can_writeback[7] && wb_ch1_eu != EU_DIV2) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_DIV2;
            end else if (eu_can_writeback[6] && wb_ch1_eu != EU_DIV1) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_DIV1;
            end else if (eu_can_writeback[5] && wb_ch1_eu != EU_MUL2) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_MUL2;
            end else if (eu_can_writeback[4] && wb_ch1_eu != EU_MUL1) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_MUL1;
            end else if (eu_can_writeback[9] && wb_ch1_eu != EU_CSR2) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_CSR2;
            end else if (eu_can_writeback[8] && wb_ch1_eu != EU_CSR1) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_CSR1;
            end else if (eu_can_writeback[1] && wb_ch1_eu != EU_ADDER2) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_ADDER2;
            end else if (eu_can_writeback[0] && wb_ch1_eu != EU_ADDER1) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_ADDER1;
            end else if (eu_can_writeback[3] && wb_ch1_eu != EU_SHIFTER2) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_SHIFTER2;
            end else if (eu_can_writeback[2] && wb_ch1_eu != EU_SHIFTER1) begin
                wb_ch2_valid = 1'b1;
                wb_ch2_eu = EU_SHIFTER1;
            end
        end
    end
    
    // ========================================================================
    // FIFO管理和时序逻辑
    // ========================================================================
    
    // FIFO管理时序逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= {(FIFO_ADDR_WIDTH+1){1'b0}};
            fifo_valid <= {FIFO_DEPTH{1'b0}};
        end else if (int_assert_i == `INT_ASSERT) begin
            // 中断时清空FIFO
            fifo_count <= {(FIFO_ADDR_WIDTH+1){1'b0}};
            fifo_valid <= {FIFO_DEPTH{1'b0}};
        end else begin
            // 处理新指令入FIFO
            if (!fifo_full) begin
                // inst1入FIFO
                if (inst1_rd_addr_i != {`REG_ADDR_WIDTH{1'b0}}) begin
                    fifo_valid[fifo_alloc_ptr1] <= 1'b1;
                    fifo_waddr[fifo_alloc_ptr1] <= inst1_rd_addr_i;
                    fifo_timestamp[fifo_alloc_ptr1] <= inst1_timestamp_hdu;
                    fifo_count <= fifo_count + 1'b1;
                    
                    // inst2入FIFO（如果还有空间）
                    if (fifo_count < FIFO_DEPTH - 1 && 
                        inst2_rd_addr_i != {`REG_ADDR_WIDTH{1'b0}}) begin
                        fifo_valid[fifo_alloc_ptr2] <= 1'b1;
                        fifo_waddr[fifo_alloc_ptr2] <= inst2_rd_addr_i;
                        fifo_timestamp[fifo_alloc_ptr2] <= inst2_timestamp_hdu;
                        fifo_count <= fifo_count + 2'd2;
                    end
                end else if (inst2_rd_addr_i != {`REG_ADDR_WIDTH{1'b0}}) begin
                    // 只有inst2需要入FIFO
                    fifo_valid[fifo_alloc_ptr1] <= 1'b1;
                    fifo_waddr[fifo_alloc_ptr1] <= inst2_rd_addr_i;
                    fifo_timestamp[fifo_alloc_ptr1] <= inst2_timestamp_hdu;
                    fifo_count <= fifo_count + 1'b1;
                end
            end
            
            // 处理写回完成，清除对应FIFO项
            if (wb_ch1_valid && !wb_ch1_from_buffer) begin
                for (integer idx = 0; idx < FIFO_DEPTH; idx = idx + 1) begin
                    if (fifo_valid[idx] && 
                        fifo_waddr[idx] == eu_reg_waddr[wb_ch1_eu] &&
                        fifo_timestamp[idx] == eu_timestamp[wb_ch1_eu]) begin
                        fifo_valid[idx] <= 1'b0;
                        fifo_count <= fifo_count - 1'b1;
                        break;
                    end
                end
            end
            
            if (wb_ch2_valid) begin
                for (integer idx = 0; idx < FIFO_DEPTH; idx = idx + 1) begin
                    if (fifo_valid[idx] && 
                        fifo_waddr[idx] == eu_reg_waddr[wb_ch2_eu] &&
                        fifo_timestamp[idx] == eu_timestamp[wb_ch2_eu]) begin
                        fifo_valid[idx] <= 1'b0;
                        fifo_count <= fifo_count - 1'b1;
                        break;
                    end
                end
            end
            
            // 处理从缓冲队列写回完成
            if (wb_ch1_valid && wb_ch1_from_buffer) begin
                for (integer idx = 0; idx < FIFO_DEPTH; idx = idx + 1) begin
                    if (fifo_valid[idx] && 
                        fifo_waddr[idx] == pending_reg_waddr[buffer_release_ptr] &&
                        fifo_timestamp[idx] == pending_timestamp[buffer_release_ptr]) begin
                        fifo_valid[idx] <= 1'b0;
                        fifo_count <= fifo_count - 1'b1;
                        break;
                    end
                end
            end
        end
    end
    
    // 缓冲队列管理和时序逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_count <= {(BUFFER_ADDR_WIDTH+1){1'b0}};
            pending_valid <= {BUFFER_SIZE{1'b0}};
        end else if (int_assert_i == `INT_ASSERT) begin
            // 中断时清空缓冲队列
            buffer_count <= {(BUFFER_ADDR_WIDTH+1){1'b0}};
            pending_valid <= {BUFFER_SIZE{1'b0}};
        end else begin
            // 正常操作：入队和出队
            case ({buffer_release_valid, |waw_conflict_delay})
                2'b00: buffer_count <= buffer_count;  // 无入队无出队
                2'b01: buffer_count <= buffer_count + 1'b1;  // 仅入队
                2'b10: buffer_count <= buffer_count - 1'b1;  // 仅出队
                2'b11: buffer_count <= buffer_count;  // 同时入队出队
            endcase
            
            // 出队：释放缓冲项
            if (buffer_release_valid && !buffer_empty) begin
                pending_valid[buffer_release_ptr] <= 1'b0;
            end
            
            // 入队：存储WAW冲突的请求
            if (|waw_conflict_delay && !buffer_full) begin
                for (integer eu_idx = 0; eu_idx < 12; eu_idx = eu_idx + 1) begin
                    if (waw_conflict_delay[eu_idx]) begin
                        pending_valid[buffer_alloc_ptr] <= 1'b1;
                        pending_reg_wdata[buffer_alloc_ptr] <= eu_reg_wdata[eu_idx];
                        pending_reg_waddr[buffer_alloc_ptr] <= eu_reg_waddr[eu_idx];
                        pending_commit_id[buffer_alloc_ptr] <= eu_commit_id[eu_idx];
                        pending_timestamp[buffer_alloc_ptr] <= eu_timestamp[eu_idx];
                        pending_eu_type[buffer_alloc_ptr] <= eu_idx[3:0];
                        
                        // 处理CSR写回
                        if (eu_idx == EU_CSR1 || eu_idx == EU_CSR2) begin
                            pending_is_csr[buffer_alloc_ptr] <= 1'b1;
                            pending_csr_waddr[buffer_alloc_ptr] <= eu_csr_waddr[eu_idx];
                            pending_csr_wdata[buffer_alloc_ptr] <= eu_csr_wdata[eu_idx];
                        end else begin
                            pending_is_csr[buffer_alloc_ptr] <= 1'b0;
                        end
                        
                        break;  // 每次只处理一个冲突请求
                    end
                end
            end
        end
    end
    
    // ========================================================================
    // 输出信号生成
    // ========================================================================
    
    // 寄存器写回通道1输出
    always @(*) begin
        if (wb_ch1_valid && !wb_ch1_from_buffer) begin
            // 从当前周期执行单元输出
            reg1_wdata_o = eu_reg_wdata[wb_ch1_eu];
            reg1_waddr_o = eu_reg_waddr[wb_ch1_eu];
            reg1_we_o = (int_assert_i != `INT_ASSERT) && eu_reg_we[wb_ch1_eu];
        end else if (wb_ch1_valid && wb_ch1_from_buffer && !pending_is_csr[buffer_release_ptr]) begin
            // 从缓冲队列输出（非CSR）
            reg1_wdata_o = pending_reg_wdata[buffer_release_ptr];
            reg1_waddr_o = pending_reg_waddr[buffer_release_ptr];
            reg1_we_o = (int_assert_i != `INT_ASSERT);
        end else begin
            reg1_wdata_o = {`REG_DATA_WIDTH{1'b0}};
            reg1_waddr_o = {`REG_ADDR_WIDTH{1'b0}};
            reg1_we_o = 1'b0;
        end
    end
    
    // 寄存器写回通道2输出
    always @(*) begin
        if (wb_ch2_valid) begin
            reg2_wdata_o = eu_reg_wdata[wb_ch2_eu];
            reg2_waddr_o = eu_reg_waddr[wb_ch2_eu];
            reg2_we_o = (int_assert_i != `INT_ASSERT) && eu_reg_we[wb_ch2_eu];
        end else begin
            reg2_wdata_o = {`REG_DATA_WIDTH{1'b0}};
            reg2_waddr_o = {`REG_ADDR_WIDTH{1'b0}};
            reg2_we_o = 1'b0;
        end
    end
    
    // CSR写回通道1输出
    always @(*) begin
        if (wb_ch1_valid && !wb_ch1_from_buffer && (wb_ch1_eu == EU_CSR1 || wb_ch1_eu == EU_CSR2)) begin
            // 从当前周期CSR执行单元输出
            csr1_wdata_o = eu_csr_wdata[wb_ch1_eu];
            csr1_waddr_o = eu_csr_waddr[wb_ch1_eu];
            csr1_we_o = (int_assert_i != `INT_ASSERT) && eu_csr_we[wb_ch1_eu];
        end else if (wb_ch1_valid && wb_ch1_from_buffer && pending_is_csr[buffer_release_ptr]) begin
            // 从缓冲队列输出（CSR）
            csr1_wdata_o = pending_csr_wdata[buffer_release_ptr];
            csr1_waddr_o = pending_csr_waddr[buffer_release_ptr];
            csr1_we_o = (int_assert_i != `INT_ASSERT);
        end else begin
            csr1_wdata_o = {`REG_DATA_WIDTH{1'b0}};
            csr1_waddr_o = {`BUS_ADDR_WIDTH{1'b0}};
            csr1_we_o = 1'b0;
        end
    end
    
    // CSR写回通道2输出
    always @(*) begin
        if (wb_ch2_valid && (wb_ch2_eu == EU_CSR1 || wb_ch2_eu == EU_CSR2)) begin
            csr2_wdata_o = eu_csr_wdata[wb_ch2_eu];
            csr2_waddr_o = eu_csr_waddr[wb_ch2_eu];
            csr2_we_o = (int_assert_i != `INT_ASSERT) && eu_csr_we[wb_ch2_eu];
        end else begin
            csr2_wdata_o = {`REG_DATA_WIDTH{1'b0}};
            csr2_waddr_o = {`BUS_ADDR_WIDTH{1'b0}};
            csr2_we_o = 1'b0;
        end
    end
    
    // Ready信号生成
    assign adder1_ready_o = ~(waw_conflict_delay[0] | current_cycle_conflict[0] | buffer_full);
    assign adder2_ready_o = ~(waw_conflict_delay[1] | current_cycle_conflict[1] | buffer_full);
    assign shifter1_ready_o = ~(waw_conflict_delay[2] | current_cycle_conflict[2] | buffer_full);
    assign shifter2_ready_o = ~(waw_conflict_delay[3] | current_cycle_conflict[3] | buffer_full);
    assign mul1_ready_o = ~(waw_conflict_delay[4] | current_cycle_conflict[4] | buffer_full);
    assign mul2_ready_o = ~(waw_conflict_delay[5] | current_cycle_conflict[5] | buffer_full);
    assign div1_ready_o = ~(waw_conflict_delay[6] | current_cycle_conflict[6] | buffer_full);
    assign div2_ready_o = ~(waw_conflict_delay[7] | current_cycle_conflict[7] | buffer_full);
    assign csr1_ready_o = ~(waw_conflict_delay[8] | current_cycle_conflict[8] | buffer_full);
    assign csr2_ready_o = ~(waw_conflict_delay[9] | current_cycle_conflict[9] | buffer_full);
    assign lsu1_ready_o = ~(waw_conflict_delay[10] | current_cycle_conflict[10] | buffer_full);
    assign lsu2_ready_o = ~(waw_conflict_delay[11] | current_cycle_conflict[11] | buffer_full);
    
    // 提交信号生成
    assign commit_valid1_o = wb_ch1_valid && (int_assert_i != `INT_ASSERT);
    assign commit_valid2_o = wb_ch2_valid && (int_assert_i != `INT_ASSERT);
    
    // 提交ID生成
    always @(*) begin
        if (wb_ch1_valid) begin
            if (wb_ch1_from_buffer) begin
                commit_id1_o = pending_commit_id[buffer_release_ptr];
            end else begin
                commit_id1_o = eu_commit_id[wb_ch1_eu];
            end
        end else begin
            commit_id1_o = {`COMMIT_ID_WIDTH{1'b0}};
        end
    end
    
    always @(*) begin
        if (wb_ch2_valid) begin
            commit_id2_o = eu_commit_id[wb_ch2_eu];
        end else begin
            commit_id2_o = {`COMMIT_ID_WIDTH{1'b0}};
        end
    end

endmodule
