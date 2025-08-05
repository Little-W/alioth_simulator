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

// 加载存储单元 - 双发射版本，带RAW转发优化
module exu_lsu #(
    parameter C_M_AXI_ID_WIDTH     = `BUS_ID_WIDTH,
    parameter C_M_AXI_ADDR_WIDTH   = `BUS_ADDR_WIDTH,
    parameter C_M_AXI_DATA_WIDTH   = 32,
    parameter C_M_AXI_AWUSER_WIDTH = 1,
    parameter C_M_AXI_ARUSER_WIDTH = 1,
    parameter C_M_AXI_WUSER_WIDTH  = 1,
    parameter C_M_AXI_RUSER_WIDTH  = 1,
    parameter C_M_AXI_BUSER_WIDTH  = 1,
    parameter UNIT_ID              = 0
)(
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire stall_i,
    input wire flush_i,
    input wire int_assert_i,

    // 访存请求信号
    input wire req_mem_i,
    input wire mem_op_lb_i,
    input wire mem_op_lh_i,
    input wire mem_op_lw_i,
    input wire mem_op_lbu_i,
    input wire mem_op_lhu_i,
    input wire mem_op_load_i,
    input wire mem_op_store_i,
    input wire [4:0] rd_addr_i,

    // 访存地址和数据 - 来自dispatch_logic的AGU计算结果
    input wire [31:0] mem_addr_i,
    input wire [63:0] mem_wdata_i,  // 64位宽以支持双发射
    input wire [ 7:0] mem_wmask_i,  // 8位掩码

    input wire [`COMMIT_ID_WIDTH-1:0] commit_id_i,
    input wire reg_we_i,
    input wire wb_ready_i,

    // 访存阻塞和忙信号输出
    output reg mem_stall_o,
    output reg mem_busy_o,

    // 寄存器写回接口 - 输出到WBU
    output reg [`REG_DATA_WIDTH-1:0] reg_wdata_o,
    output reg                       reg_we_o,
    output reg [`REG_ADDR_WIDTH-1:0] reg_waddr_o,
    output reg [`COMMIT_ID_WIDTH-1:0] commit_id_o,

    // AXI Master接口
    output reg [    C_M_AXI_ID_WIDTH-1:0] M_AXI_AWID,
    output reg [  C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output reg [                     7:0] M_AXI_AWLEN,
    output reg [                     2:0] M_AXI_AWSIZE,
    output reg [                     1:0] M_AXI_AWBURST,
    output reg                            M_AXI_AWLOCK,
    output reg [                     3:0] M_AXI_AWCACHE,
    output reg [                     2:0] M_AXI_AWPROT,
    output reg [                     3:0] M_AXI_AWQOS,
    output reg [C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
    output reg                            M_AXI_AWVALID,
    input  wire                            M_AXI_AWREADY,

    output reg [  C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output reg [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output reg                            M_AXI_WLAST,
    output reg [ C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER,
    output reg                            M_AXI_WVALID,
    input  wire                            M_AXI_WREADY,

    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [                    1:0] M_AXI_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                           M_AXI_BVALID,
    output reg                           M_AXI_BREADY,

    output reg [    C_M_AXI_ID_WIDTH-1:0] M_AXI_ARID,
    output reg [  C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output reg [                     7:0] M_AXI_ARLEN,
    output reg [                     2:0] M_AXI_ARSIZE,
    output reg [                     1:0] M_AXI_ARBURST,
    output reg                            M_AXI_ARLOCK,
    output reg [                     3:0] M_AXI_ARCACHE,
    output reg [                     2:0] M_AXI_ARPROT,
    output reg [                     3:0] M_AXI_ARQOS,
    output reg [C_M_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER,
    output reg                            M_AXI_ARVALID,
    input  wire                            M_AXI_ARREADY,

    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [ C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                    1:0] M_AXI_RRESP,
    input  wire                           M_AXI_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                           M_AXI_RVALID,
    output reg                           M_AXI_RREADY
);

    // ===================================================================
    // 内部信号和参数定义
    // ===================================================================
    
    // FIFO深度参数
    localparam FIFO_DEPTH = 8;
    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);
    
    // 操作类型编码
    localparam [2:0] OP_LB  = 3'b000;
    localparam [2:0] OP_LH  = 3'b001;
    localparam [2:0] OP_LW  = 3'b010;
    localparam [2:0] OP_LBU = 3'b011;
    localparam [2:0] OP_LHU = 3'b100;
    localparam [2:0] OP_SB  = 3'b101;
    localparam [2:0] OP_SH  = 3'b110;
    localparam [2:0] OP_SW  = 3'b111;
    
    // FIFO条目结构
    typedef struct packed {
        logic                       valid;
        logic                       is_load;
        logic                       is_store;
        logic [31:0]               addr;
        logic [63:0]               wdata;    // 64位支持双发射
        logic [7:0]                wmask;    // 8位掩码
        logic [4:0]                rd_addr;
        logic [`COMMIT_ID_WIDTH-1:0] commit_id;
        logic                       reg_we;
        logic [2:0]                op_type;
        logic                       axi_req_sent;
        logic                       axi_resp_received;
        logic [31:0]               result_data;
        logic                       forwarded;
    } mem_fifo_entry_t;
    
    // FIFO存储和指针
    mem_fifo_entry_t mem_fifo[0:FIFO_DEPTH-1];
    reg [FIFO_PTR_WIDTH-1:0] fifo_head, fifo_tail;
    reg [FIFO_PTR_WIDTH:0] fifo_count;
    
    // 内部状态信号
    wire fifo_full, fifo_empty;
    wire valid_op;
    wire [2:0] current_op_type;
    wire can_accept_req;
    
    // RAW前递信号
    reg raw_detected;
    reg [31:0] forward_data;
    reg forward_valid;
    
    // AXI状态机 - 支持Load/Store并行
    typedef enum logic [2:0] {
        AXI_IDLE      = 3'b000,
        AXI_READ_ADDR = 3'b001,
        AXI_READ_DATA = 3'b010,
        AXI_WRITE_ADDR = 3'b011,
        AXI_WRITE_DATA = 3'b100,
        AXI_WRITE_RESP = 3'b101
    } axi_state_t;
    
    axi_state_t axi_read_state, axi_read_state_next;
    axi_state_t axi_write_state, axi_write_state_next;
    reg [FIFO_PTR_WIDTH-1:0] axi_read_processing_idx;
    reg [FIFO_PTR_WIDTH-1:0] axi_write_processing_idx;
    
    // ===================================================================
    // 组合逻辑
    // ===================================================================
    
    // FIFO状态
    assign fifo_full = (fifo_count >= FIFO_DEPTH);
    assign fifo_empty = (fifo_count == 0);
    
    // 有效操作检测
    assign valid_op = req_mem_i && (mem_op_load_i || mem_op_store_i);
    
    // 当前操作类型
    assign current_op_type = mem_op_lb_i  ? OP_LB  :
                            mem_op_lh_i  ? OP_LH  :
                            mem_op_lw_i  ? OP_LW  :
                            mem_op_lbu_i ? OP_LBU :
                            mem_op_lhu_i ? OP_LHU :
                            (mem_wmask_i[3:0] == 4'b0001 || mem_wmask_i[3:0] == 4'b0010 || 
                             mem_wmask_i[3:0] == 4'b0100 || mem_wmask_i[3:0] == 4'b1000) ? OP_SB :
                            (mem_wmask_i[3:0] == 4'b0011 || mem_wmask_i[3:0] == 4'b1100) ? OP_SH :
                            OP_SW;
    
    // 请求接受条件
    assign can_accept_req = !fifo_full && !stall_i;
    
    // 输出阻塞信号 - 简化逻辑
    assign mem_stall_o = valid_op && !can_accept_req;
    assign mem_busy_o = !fifo_empty || (axi_read_state != AXI_IDLE) || (axi_write_state != AXI_IDLE);
    
    // ===================================================================
    // RAW前递检测逻辑 - 改进版本
    // ===================================================================
    
    always_comb begin
        raw_detected = 1'b0;
        forward_data = 32'b0;
        forward_valid = 1'b0;
        
        if (valid_op && mem_op_load_i) begin
            // 从FIFO尾部向头部搜索最近的匹配store（最新的）
            for (int i = FIFO_DEPTH-1; i >= 0; i--) begin
                automatic int idx = (fifo_head + i) % FIFO_DEPTH;
                if (mem_fifo[idx].valid && mem_fifo[idx].is_store) begin
                    // 检查地址是否完全匹配
                    if (mem_fifo[idx].addr == mem_addr_i) begin
                        raw_detected = 1'b1;
                        
                        // 直接前递store数据，不需要等待store完成
                        forward_data = extract_forward_data(mem_fifo[idx].wdata, current_op_type, mem_addr_i[1:0]);
                        forward_valid = 1'b1;
                        
                        break; // 找到最近的匹配项，停止搜索
                    end
                end
            end
            
            // 检查当前周期的同时Load/Store请求（同周期前递）
            if (!raw_detected && req_mem_i && mem_op_load_i && mem_op_store_i) begin
                // 注意：这里假设同一周期内Load和Store地址是相同的mem_addr_i
                raw_detected = 1'b1;
                forward_data = extract_forward_data(mem_wdata_i, current_op_type, mem_addr_i[1:0]);
                forward_valid = 1'b1;
            end
        end
    end
    
    // ===================================================================
    // FIFO管理逻辑 - 支持Load/Store并行处理
    // ===================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_head <= '0;
            fifo_tail <= '0;
            fifo_count <= '0;
            
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                mem_fifo[i] <= '0;
            end
        end else if (flush_i) begin
            fifo_head <= '0;
            fifo_tail <= '0;
            fifo_count <= '0;
            
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                mem_fifo[i].valid <= 1'b0;
            end
        end else begin
            // 入队逻辑：优先处理能前递的load
            if (valid_op && can_accept_req) begin
                mem_fifo[fifo_tail].valid <= 1'b1;
                mem_fifo[fifo_tail].is_load <= mem_op_load_i;
                mem_fifo[fifo_tail].is_store <= mem_op_store_i;
                mem_fifo[fifo_tail].addr <= mem_addr_i;
                mem_fifo[fifo_tail].wdata <= mem_wdata_i;
                mem_fifo[fifo_tail].wmask <= mem_wmask_i;
                mem_fifo[fifo_tail].rd_addr <= rd_addr_i;
                mem_fifo[fifo_tail].commit_id <= commit_id_i;
                mem_fifo[fifo_tail].reg_we <= reg_we_i;
                mem_fifo[fifo_tail].op_type <= current_op_type;
                mem_fifo[fifo_tail].axi_req_sent <= 1'b0;
                mem_fifo[fifo_tail].axi_resp_received <= 1'b0;
                
                // RAW前递优化：load直接从store前递，无需访存
                if (mem_op_load_i && forward_valid) begin
                    mem_fifo[fifo_tail].forwarded <= 1'b1;
                    mem_fifo[fifo_tail].axi_resp_received <= 1'b1; // 标记为已完成
                    mem_fifo[fifo_tail].result_data <= forward_data;
                end else begin
                    mem_fifo[fifo_tail].forwarded <= 1'b0;
                    mem_fifo[fifo_tail].result_data <= 32'b0;
                end
                
                fifo_tail <= (fifo_tail + 1) % FIFO_DEPTH;
                fifo_count <= fifo_count + 1;
            end
            
            // 出队逻辑：处理已完成的操作
            if (!fifo_empty && mem_fifo[fifo_head].valid) begin
                logic can_retire = 1'b0;
                
                if (mem_fifo[fifo_head].is_load) begin
                    // Load：前递的或AXI完成的，且WBU准备好
                    can_retire = (mem_fifo[fifo_head].forwarded || mem_fifo[fifo_head].axi_resp_received) && wb_ready_i;
                end else begin
                    // Store：AXI写响应完成
                    can_retire = mem_fifo[fifo_head].axi_resp_received;
                end
                
                if (can_retire) begin
                    mem_fifo[fifo_head].valid <= 1'b0;
                    fifo_head <= (fifo_head + 1) % FIFO_DEPTH;
                    fifo_count <= fifo_count - 1;
                end
            end
        end
    end
    
    // ===================================================================
    // AXI状态机 - 分离读写通道实现并行处理
    // ===================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_read_state <= AXI_IDLE;
            axi_write_state <= AXI_IDLE;
            axi_read_processing_idx <= '0;
            axi_write_processing_idx <= '0;
        end else if (flush_i) begin
            axi_read_state <= AXI_IDLE;
            axi_write_state <= AXI_IDLE;
            axi_read_processing_idx <= '0;
            axi_write_processing_idx <= '0';
        end else begin
            axi_read_state <= axi_read_state_next;
            axi_write_state <= axi_write_state_next;
            
            // 更新读处理索引
            if (axi_read_state == AXI_IDLE && axi_read_state_next == AXI_READ_ADDR) begin
                for (int i = 0; i < FIFO_DEPTH; i++) begin
                    automatic int idx = (fifo_head + i) % FIFO_DEPTH;
                    if (mem_fifo[idx].valid && mem_fifo[idx].is_load && 
                        !mem_fifo[idx].axi_req_sent && !mem_fifo[idx].forwarded) begin
                        axi_read_processing_idx <= idx;
                        break;
                    end
                end
            end
            
            // 更新写处理索引
            if (axi_write_state == AXI_IDLE && axi_write_state_next == AXI_WRITE_ADDR) begin
                for (int i = 0; i < FIFO_DEPTH; i++) begin
                    automatic int idx = (fifo_head + i) % FIFO_DEPTH;
                    if (mem_fifo[idx].valid && mem_fifo[idx].is_store && 
                        !mem_fifo[idx].axi_req_sent) begin
                        axi_write_processing_idx <= idx;
                        break;
                    end
                end
            end
        end
    end
    
    // 读通道状态机
    always_comb begin
        axi_read_state_next = axi_read_state;
        
        case (axi_read_state)
            AXI_IDLE: begin
                // 检查是否有需要读的Load操作
                for (int i = 0; i < FIFO_DEPTH; i++) begin
                    automatic int idx = (fifo_head + i) % FIFO_DEPTH;
                    if (mem_fifo[idx].valid && mem_fifo[idx].is_load && 
                        !mem_fifo[idx].axi_req_sent && !mem_fifo[idx].forwarded) begin
                        axi_read_state_next = AXI_READ_ADDR;
                        break;
                    end
                end
            end
            
            AXI_READ_ADDR: begin
                if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                    axi_read_state_next = AXI_READ_DATA;
                end
            end
            
            AXI_READ_DATA: begin
                if (M_AXI_RVALID && M_AXI_RREADY) begin
                    axi_read_state_next = AXI_IDLE;
                end
            end
        endcase
    end
    
    // 写通道状态机
    always_comb begin
        axi_write_state_next = axi_write_state;
        
        case (axi_write_state)
            AXI_IDLE: begin
                // 检查是否有需要写的Store操作
                for (int i = 0; i < FIFO_DEPTH; i++) begin
                    automatic int idx = (fifo_head + i) % FIFO_DEPTH;
                    if (mem_fifo[idx].valid && mem_fifo[idx].is_store && 
                        !mem_fifo[idx].axi_req_sent) begin
                        axi_write_state_next = AXI_WRITE_ADDR;
                        break;
                    end
                end
            end
            
            AXI_WRITE_ADDR: begin
                if (M_AXI_AWVALID && M_AXI_AWREADY) begin
                    axi_write_state_next = AXI_WRITE_DATA;
                end
            end
            
            AXI_WRITE_DATA: begin
                if (M_AXI_WVALID && M_AXI_WREADY) begin
                    axi_write_state_next = AXI_WRITE_RESP;
                end
            end
            
            AXI_WRITE_RESP: begin
                if (M_AXI_BVALID && M_AXI_BREADY) begin
                    axi_write_state_next = AXI_IDLE;
                end
            end
        endcase
    end
    
    // ===================================================================
    // AXI输出信号生成 - 分离读写通道
    // ===================================================================
    
    always_comb begin
        // 写地址通道
        M_AXI_AWID = UNIT_ID;
        M_AXI_AWADDR = 32'b0;
        M_AXI_AWLEN = 8'b0;
        M_AXI_AWSIZE = 3'b010; // 4 bytes
        M_AXI_AWBURST = 2'b01; // INCR
        M_AXI_AWLOCK = 1'b0;
        M_AXI_AWCACHE = 4'b0010;
        M_AXI_AWPROT = 3'b000;
        M_AXI_AWQOS = 4'b0000;
        M_AXI_AWUSER = 1'b0;
        M_AXI_AWVALID = 1'b0;
        
        if (axi_write_state == AXI_WRITE_ADDR) begin
            M_AXI_AWVALID = 1'b1;
            M_AXI_AWADDR = mem_fifo[axi_write_processing_idx].addr;
            
            case (mem_fifo[axi_write_processing_idx].op_type)
                OP_SB: M_AXI_AWSIZE = 3'b000; // 1 byte
                OP_SH: M_AXI_AWSIZE = 3'b001; // 2 bytes
                default: M_AXI_AWSIZE = 3'b010; // 4 bytes
            endcase
        end
        
        // 写数据通道
        M_AXI_WDATA = 32'b0;
        M_AXI_WSTRB = 4'b0;
        M_AXI_WLAST = 1'b1;
        M_AXI_WUSER = 1'b0;
        M_AXI_WVALID = 1'b0;
        
        if (axi_write_state == AXI_WRITE_DATA) begin
            M_AXI_WVALID = 1'b1;
            M_AXI_WDATA = mem_fifo[axi_write_processing_idx].wdata[31:0]; // 取低32位
            M_AXI_WSTRB = mem_fifo[axi_write_processing_idx].wmask[3:0];  // 取低4位
        end
        
        // 写响应通道
        M_AXI_BREADY = (axi_write_state == AXI_WRITE_RESP);
        
        // 读地址通道
        M_AXI_ARID = UNIT_ID;
        M_AXI_ARADDR = 32'b0;
        M_AXI_ARLEN = 8'b0;
        M_AXI_ARSIZE = 3'b010; // 4 bytes
        M_AXI_ARBURST = 2'b01; // INCR
        M_AXI_ARLOCK = 1'b0;
        M_AXI_ARCACHE = 4'b0010;
        M_AXI_ARPROT = 3'b000;
        M_AXI_ARQOS = 4'b0000;
        M_AXI_ARUSER = 1'b0;
        M_AXI_ARVALID = 1'b0;
        
        if (axi_read_state == AXI_READ_ADDR) begin
            M_AXI_ARVALID = 1'b1;
            M_AXI_ARADDR = mem_fifo[axi_read_processing_idx].addr;
            
            case (mem_fifo[axi_read_processing_idx].op_type)
                OP_LB, OP_LBU: M_AXI_ARSIZE = 3'b000; // 1 byte
                OP_LH, OP_LHU: M_AXI_ARSIZE = 3'b001; // 2 bytes
                default: M_AXI_ARSIZE = 3'b010; // 4 bytes
            endcase
        end
        
        // 读数据通道
        M_AXI_RREADY = (axi_read_state == AXI_READ_DATA);
    end
    
    // ===================================================================
    // AXI响应处理 - 分离读写通道
    // ===================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                mem_fifo[i].axi_req_sent <= 1'b0;
                mem_fifo[i].axi_resp_received <= 1'b0;
                mem_fifo[i].result_data <= 32'b0;
            end
        end else if (flush_i) begin
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                mem_fifo[i].axi_req_sent <= 1'b0;
                mem_fifo[i].axi_resp_received <= 1'b0;
                mem_fifo[i].result_data <= 32'b0;
            end
        end else begin
            // 标记读请求已发送
            if (axi_read_state == AXI_READ_ADDR && M_AXI_ARVALID && M_AXI_ARREADY) begin
                mem_fifo[axi_read_processing_idx].axi_req_sent <= 1'b1;
            end
            
            // 标记写请求已发送
            if (axi_write_state == AXI_WRITE_ADDR && M_AXI_AWVALID && M_AXI_AWREADY) begin
                mem_fifo[axi_write_processing_idx].axi_req_sent <= 1'b1;
            end
            
            // 处理读响应
            if (M_AXI_RVALID && M_AXI_RREADY) begin
                mem_fifo[axi_read_processing_idx].axi_resp_received <= 1'b1;
                
                // 根据操作类型处理读取的数据
                case (mem_fifo[axi_read_processing_idx].op_type)
                    OP_LB: begin
                        case (mem_fifo[axi_read_processing_idx].addr[1:0])
                            2'b00: mem_fifo[axi_read_processing_idx].result_data <= {{24{M_AXI_RDATA[7]}}, M_AXI_RDATA[7:0]};
                            2'b01: mem_fifo[axi_read_processing_idx].result_data <= {{24{M_AXI_RDATA[15]}}, M_AXI_RDATA[15:8]};
                            2'b10: mem_fifo[axi_read_processing_idx].result_data <= {{24{M_AXI_RDATA[23]}}, M_AXI_RDATA[23:16]};
                            2'b11: mem_fifo[axi_read_processing_idx].result_data <= {{24{M_AXI_RDATA[31]}}, M_AXI_RDATA[31:24]};
                        endcase
                    end
                    OP_LBU: begin
                        case (mem_fifo[axi_read_processing_idx].addr[1:0])
                            2'b00: mem_fifo[axi_read_processing_idx].result_data <= {24'b0, M_AXI_RDATA[7:0]};
                            2'b01: mem_fifo[axi_read_processing_idx].result_data <= {24'b0, M_AXI_RDATA[15:8]};
                            2'b10: mem_fifo[axi_read_processing_idx].result_data <= {24'b0, M_AXI_RDATA[23:16]};
                            2'b11: mem_fifo[axi_read_processing_idx].result_data <= {24'b0, M_AXI_RDATA[31:24]};
                        endcase
                    end
                    OP_LH: begin
                        case (mem_fifo[axi_read_processing_idx].addr[1])
                            1'b0: mem_fifo[axi_read_processing_idx].result_data <= {{16{M_AXI_RDATA[15]}}, M_AXI_RDATA[15:0]};
                            1'b1: mem_fifo[axi_read_processing_idx].result_data <= {{16{M_AXI_RDATA[31]}}, M_AXI_RDATA[31:16]};
                        endcase
                    end
                    OP_LHU: begin
                        case (mem_fifo[axi_read_processing_idx].addr[1])
                            1'b0: mem_fifo[axi_read_processing_idx].result_data <= {16'b0, M_AXI_RDATA[15:0]};
                            1'b1: mem_fifo[axi_read_processing_idx].result_data <= {16'b0, M_AXI_RDATA[31:16]};
                        endcase
                    end
                    OP_LW: begin
                        mem_fifo[axi_read_processing_idx].result_data <= M_AXI_RDATA;
                    end
                endcase
            end
            
            // 处理写响应
            if (M_AXI_BVALID && M_AXI_BREADY) begin
                mem_fifo[axi_write_processing_idx].axi_resp_received <= 1'b1;
            end
        end
    end
    
    // ===================================================================
        end
    
    // ===================================================================
    // 写回接口 - 优化的Load结果输出
    // ===================================================================
    // ===================================================================
    
    always_comb begin
        reg_wdata_o = 32'b0;
        reg_we_o = 1'b0;
        reg_waddr_o = 5'b0;
        commit_id_o = '0;
        
        if (!fifo_empty && mem_fifo[fifo_head].valid && mem_fifo[fifo_head].is_load) begin
            if (mem_fifo[fifo_head].axi_resp_received || mem_fifo[fifo_head].forwarded) begin
                reg_wdata_o = mem_fifo[fifo_head].result_data;
                reg_we_o = mem_fifo[fifo_head].reg_we;
                reg_waddr_o = mem_fifo[fifo_head].rd_addr;
                commit_id_o = mem_fifo[fifo_head].commit_id;
            end
        end
    end
    
    // ===================================================================
    // 辅助函数 - RAW前递数据提取
    // ===================================================================
    
    function automatic [31:0] extract_forward_data(
        input [63:0] store_data,
        input [2:0] load_op_type,
        input [1:0] byte_offset
    );
        logic [31:0] result;
        
        case (load_op_type)
            OP_LB: begin // 有符号字节
                case (byte_offset)
                    2'b00: result = {{24{store_data[7]}}, store_data[7:0]};
                    2'b01: result = {{24{store_data[15]}}, store_data[15:8]};
                    2'b10: result = {{24{store_data[23]}}, store_data[23:16]};
                    2'b11: result = {{24{store_data[31]}}, store_data[31:24]};
                endcase
            end
            OP_LBU: begin // 无符号字节
                case (byte_offset)
                    2'b00: result = {24'b0, store_data[7:0]};
                    2'b01: result = {24'b0, store_data[15:8]};
                    2'b10: result = {24'b0, store_data[23:16]};
                    2'b11: result = {24'b0, store_data[31:24]};
                endcase
            end
            OP_LH: begin // 有符号半字
                case (byte_offset[1])
                    1'b0: result = {{16{store_data[15]}}, store_data[15:0]};
                    1'b1: result = {{16{store_data[31]}}, store_data[31:16]};
                endcase
            end
            OP_LHU: begin // 无符号半字
                case (byte_offset[1])
                    1'b0: result = {16'b0, store_data[15:0]};
                    1'b1: result = {16'b0, store_data[31:16]};
                endcase
            end
            default: result = store_data[31:0]; // LW
        endcase
        
        return result;
    endfunction

endmodule
