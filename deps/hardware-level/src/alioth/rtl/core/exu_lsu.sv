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

// LSU总控模块 - 双发射版本，类似ALU架构，内部例化两个LSU单元，统一AXI接口和冲突处理
module exu_lsu #(
    parameter C_M_AXI_ID_WIDTH     = `BUS_ID_WIDTH,
    parameter C_M_AXI_ADDR_WIDTH   = `BUS_ADDR_WIDTH,
    parameter C_M_AXI_DATA_WIDTH   = `BUS_DATA_WIDTH,
    parameter C_M_AXI_AWUSER_WIDTH = 1,
    parameter C_M_AXI_ARUSER_WIDTH = 1,
    parameter C_M_AXI_WUSER_WIDTH  = 1,
    parameter C_M_AXI_RUSER_WIDTH  = 1,
    parameter C_M_AXI_BUSER_WIDTH  = 1
)(
    input wire clk,
    input wire rst_n,

    // 控制信号
    input wire int_assert_i,

    // LSU0接口 - 第一条指令（inst1，优先级高）
    input wire                        req_mem0_i,
    input wire                        mem0_op_lb_i,
    input wire                        mem0_op_lh_i,
    input wire                        mem0_op_lw_i,
    input wire                        mem0_op_lbu_i,
    input wire                        mem0_op_lhu_i,
    input wire                        mem0_op_load_i,
    input wire                        mem0_op_store_i,
    input wire [                 4:0] mem0_rd_i,
    input wire [                31:0] mem0_addr_i,
    input wire [                63:0] mem0_wdata_i,  // 64位数据
    input wire [                 7:0] mem0_wmask_i,  // 8位掩码
    input wire [`COMMIT_ID_WIDTH-1:0] mem0_commit_id_i,
    input wire                        mem0_reg_we_i,
    input wire                        mem0_wb_ready_i,

    // LSU1接口 - 第二条指令（inst2，优先级低）
    input wire                        req_mem1_i,
    input wire                        mem1_op_lb_i,
    input wire                        mem1_op_lh_i,
    input wire                        mem1_op_lw_i,
    input wire                        mem1_op_lbu_i,
    input wire                        mem1_op_lhu_i,
    input wire                        mem1_op_load_i,
    input wire                        mem1_op_store_i,
    input wire [                 4:0] mem1_rd_i,
    input wire [                31:0] mem1_addr_i,
    input wire [                63:0] mem1_wdata_i,  // 64位数据
    input wire [                 7:0] mem1_wmask_i,  // 8位掩码
    input wire [`COMMIT_ID_WIDTH-1:0] mem1_commit_id_i,
    input wire                        mem1_reg_we_i,
    input wire                        mem1_wb_ready_i,

    // 访存阻塞和忙信号输出
    output wire mem_stall_o,
    output wire mem0_store_busy_o,
    output wire mem1_store_busy_o,

    // LSU0写回接口
    output wire [ `REG_DATA_WIDTH-1:0] lsu0_reg_wdata_o,
    output wire                        lsu0_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] lsu0_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] lsu0_commit_id_o,

    // LSU1写回接口
    output wire [ `REG_DATA_WIDTH-1:0] lsu1_reg_wdata_o,
    output wire                        lsu1_reg_we_o,
    output wire [ `REG_ADDR_WIDTH-1:0] lsu1_reg_waddr_o,
    output wire [`COMMIT_ID_WIDTH-1:0] lsu1_commit_id_o,

    // 统一AXI Master接口 - 64位
    output wire [    C_M_AXI_ID_WIDTH-1:0] M_AXI_AWID,
    output wire [  C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output wire [                     7:0] M_AXI_AWLEN,
    output wire [                     2:0] M_AXI_AWSIZE,
    output wire [                     1:0] M_AXI_AWBURST,
    output wire                            M_AXI_AWLOCK,
    output wire [                     3:0] M_AXI_AWCACHE,
    output wire [                     2:0] M_AXI_AWPROT,
    output wire [                     3:0] M_AXI_AWQOS,
    output wire [C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
    output wire                            M_AXI_AWVALID,
    input  wire                            M_AXI_AWREADY,

    output wire [  C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                            M_AXI_WLAST,
    output wire [ C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER,
    output wire                            M_AXI_WVALID,
    input  wire                            M_AXI_WREADY,

    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [                    1:0] M_AXI_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                           M_AXI_BVALID,
    output wire                           M_AXI_BREADY,

    output wire [    C_M_AXI_ID_WIDTH-1:0] M_AXI_ARID,
    output wire [  C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                     7:0] M_AXI_ARLEN,
    output wire [                     2:0] M_AXI_ARSIZE,
    output wire [                     1:0] M_AXI_ARBURST,
    output wire                            M_AXI_ARLOCK,
    output wire [                     3:0] M_AXI_ARCACHE,
    output wire [                     2:0] M_AXI_ARPROT,
    output wire [                     3:0] M_AXI_ARQOS,
    output wire [C_M_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER,
    output wire                            M_AXI_ARVALID,
    input  wire                            M_AXI_ARREADY,

    input  wire [   C_M_AXI_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [ C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                    1:0] M_AXI_RRESP,
    input  wire                           M_AXI_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                           M_AXI_RVALID,
    output wire                           M_AXI_RREADY
);

    // ===================================================================
    // 内部信号和参数定义
    // ===================================================================
    
    // 冲突检测
    wire addr_conflict = req_mem0_i && req_mem1_i && 
                        (mem0_addr_i[31:2] == mem1_addr_i[31:2]); // 同一字地址
    
    wire both_load = req_mem0_i && req_mem1_i && 
                     mem0_op_load_i && mem1_op_load_i;
    
    wire both_store = req_mem0_i && req_mem1_i && 
                      mem0_op_store_i && mem1_op_store_i;
    
    wire load_store_conflict = req_mem0_i && req_mem1_i && 
                               ((mem0_op_load_i && mem1_op_store_i) ||
                                (mem0_op_store_i && mem1_op_load_i));

    // RAW转发检测 - 当inst1是store，inst2是load，且地址相同时启用转发
    wire raw_forward = req_mem0_i && req_mem1_i && 
                       mem0_op_store_i && mem1_op_load_i && 
                       addr_conflict;

    // 结构冒险检测 - 需要串行处理的情况
    wire structural_hazard = addr_conflict && (both_load || both_store || 
                             (load_store_conflict && !raw_forward));

    // 1位深度FIFO用于存储第二条指令
    reg fifo_valid;
    reg fifo_op_lb, fifo_op_lh, fifo_op_lw, fifo_op_lbu, fifo_op_lhu;
    reg fifo_op_load, fifo_op_store;
    reg [4:0] fifo_rd_addr;
    reg [31:0] fifo_addr;
    reg [63:0] fifo_wdata;
    reg [7:0] fifo_wmask;
    reg [`COMMIT_ID_WIDTH-1:0] fifo_commit_id;
    reg fifo_reg_we;
    reg fifo_wb_ready;

    // 当前处理状态
    typedef enum logic [1:0] {
        STATE_IDLE,      // 空闲状态，可以接受新请求
        STATE_PROC_FIRST, // 处理第一条指令
        STATE_PROC_SECOND // 处理FIFO中的第二条指令
    } lsu_state_t;
    
    lsu_state_t current_state, next_state;

    // LSU单元实例化信号
    reg lsu_req;
    reg lsu_op_lb, lsu_op_lh, lsu_op_lw, lsu_op_lbu, lsu_op_lhu;
    reg lsu_op_load, lsu_op_store;
    reg [4:0] lsu_rd_addr;
    reg [31:0] lsu_addr;
    reg [63:0] lsu_wdata;
    reg [7:0] lsu_wmask;
    reg [`COMMIT_ID_WIDTH-1:0] lsu_commit_id;
    reg lsu_reg_we;
    reg lsu_wb_ready;

    // LSU单元输出信号
    wire lsu_stall;
    wire [`REG_DATA_WIDTH-1:0] lsu_reg_wdata;
    wire lsu_reg_we_out;
    wire [`REG_ADDR_WIDTH-1:0] lsu_reg_waddr;
    wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_out;

    // 指令来源标识 - 用于写回路由
    reg processing_inst1;  // 当前处理的是第一条指令还是第二条指令

    // ===================================================================
    // 状态机控制逻辑
    // ===================================================================
    
    // 状态转换逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // 下一状态逻辑
    always @(*) begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE: begin
                if (req_mem0_i && req_mem1_i && structural_hazard) begin
                    next_state = STATE_PROC_FIRST;  // 需要串行处理
                end else if (req_mem0_i || req_mem1_i) begin
                    // 可以并行处理或只有一条指令，保持IDLE状态
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_PROC_FIRST: begin
                if (!lsu_stall) begin  // 第一条指令处理完成
                    if (fifo_valid) begin
                        next_state = STATE_PROC_SECOND;
                    end else begin
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            STATE_PROC_SECOND: begin
                if (!lsu_stall) begin  // 第二条指令处理完成
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end

    // ===================================================================
    // FIFO控制逻辑 - 1位深度FIFO
    // ===================================================================
    
    // FIFO写入逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_valid <= 1'b0;
            fifo_op_lb <= 1'b0;
            fifo_op_lh <= 1'b0;
            fifo_op_lw <= 1'b0;
            fifo_op_lbu <= 1'b0;
            fifo_op_lhu <= 1'b0;
            fifo_op_load <= 1'b0;
            fifo_op_store <= 1'b0;
            fifo_rd_addr <= 5'b0;
            fifo_addr <= 32'b0;
            fifo_wdata <= 64'b0;
            fifo_wmask <= 8'b0;
            fifo_commit_id <= {`COMMIT_ID_WIDTH{1'b0}};
            fifo_reg_we <= 1'b0;
            fifo_wb_ready <= 1'b0;
        end else begin
            if (current_state == STATE_IDLE && structural_hazard) begin
                // 存储第二条指令到FIFO
                fifo_valid <= 1'b1;
                fifo_op_lb <= mem1_op_lb_i;
                fifo_op_lh <= mem1_op_lh_i;
                fifo_op_lw <= mem1_op_lw_i;
                fifo_op_lbu <= mem1_op_lbu_i;
                fifo_op_lhu <= mem1_op_lhu_i;
                fifo_op_load <= mem1_op_load_i;
                fifo_op_store <= mem1_op_store_i;
                fifo_rd_addr <= mem1_rd_i;
                fifo_addr <= mem1_addr_i;
                fifo_wdata <= mem1_wdata_i;
                fifo_wmask <= mem1_wmask_i;
                fifo_commit_id <= mem1_commit_id_i;
                fifo_reg_we <= mem1_reg_we_i;
                fifo_wb_ready <= mem1_wb_ready_i;
            end else if (current_state == STATE_PROC_SECOND && !lsu_stall) begin
                fifo_valid <= 1'b0;  // FIFO项目处理完成
            end
        end
    end

    // ===================================================================
    // LSU输入选择逻辑
    // ===================================================================
    
    always @(*) begin
        // 默认值
        lsu_req = 1'b0;
        lsu_op_lb = 1'b0;
        lsu_op_lh = 1'b0;
        lsu_op_lw = 1'b0;
        lsu_op_lbu = 1'b0;
        lsu_op_lhu = 1'b0;
        lsu_op_load = 1'b0;
        lsu_op_store = 1'b0;
        lsu_rd_addr = 5'b0;
        lsu_addr = 32'b0;
        lsu_wdata = 64'b0;
        lsu_wmask = 8'b0;
        lsu_commit_id = {`COMMIT_ID_WIDTH{1'b0}};
        lsu_reg_we = 1'b0;
        lsu_wb_ready = 1'b0;
        processing_inst1 = 1'b0;
        
        case (current_state)
            STATE_IDLE: begin
                if (req_mem0_i && !structural_hazard) begin
                    // 处理第一条指令
                    lsu_req = 1'b1;
                    lsu_op_lb = mem0_op_lb_i;
                    lsu_op_lh = mem0_op_lh_i;
                    lsu_op_lw = mem0_op_lw_i;
                    lsu_op_lbu = mem0_op_lbu_i;
                    lsu_op_lhu = mem0_op_lhu_i;
                    lsu_op_load = mem0_op_load_i;
                    lsu_op_store = mem0_op_store_i;
                    lsu_rd_addr = mem0_rd_i;
                    lsu_addr = mem0_addr_i;
                    lsu_wdata = mem0_wdata_i;
                    lsu_wmask = mem0_wmask_i;
                    lsu_commit_id = mem0_commit_id_i;
                    lsu_reg_we = mem0_reg_we_i;
                    lsu_wb_ready = mem0_wb_ready_i;
                    processing_inst1 = 1'b1;
                end else if (req_mem1_i && !req_mem0_i) begin
                    // 只有第二条指令
                    lsu_req = 1'b1;
                    lsu_op_lb = mem1_op_lb_i;
                    lsu_op_lh = mem1_op_lh_i;
                    lsu_op_lw = mem1_op_lw_i;
                    lsu_op_lbu = mem1_op_lbu_i;
                    lsu_op_lhu = mem1_op_lhu_i;
                    lsu_op_load = mem1_op_load_i;
                    lsu_op_store = mem1_op_store_i;
                    lsu_rd_addr = mem1_rd_i;
                    lsu_addr = mem1_addr_i;
                    lsu_wdata = mem1_wdata_i;
                    lsu_wmask = mem1_wmask_i;
                    lsu_commit_id = mem1_commit_id_i;
                    lsu_reg_we = mem1_reg_we_i;
                    lsu_wb_ready = mem1_wb_ready_i;
                    processing_inst1 = 1'b0;
                end
            end
            
            STATE_PROC_FIRST: begin
                // 处理第一条指令（结构冒险情况）
                lsu_req = 1'b1;
                lsu_op_lb = mem0_op_lb_i;
                lsu_op_lh = mem0_op_lh_i;
                lsu_op_lw = mem0_op_lw_i;
                lsu_op_lbu = mem0_op_lbu_i;
                lsu_op_lhu = mem0_op_lhu_i;
                lsu_op_load = mem0_op_load_i;
                lsu_op_store = mem0_op_store_i;
                lsu_rd_addr = mem0_rd_i;
                lsu_addr = mem0_addr_i;
                lsu_wdata = mem0_wdata_i;
                lsu_wmask = mem0_wmask_i;
                lsu_commit_id = mem0_commit_id_i;
                lsu_reg_we = mem0_reg_we_i;
                lsu_wb_ready = mem0_wb_ready_i;
                processing_inst1 = 1'b1;
            end
            
            STATE_PROC_SECOND: begin
                // 处理FIFO中的第二条指令
                lsu_req = fifo_valid;
                lsu_op_lb = fifo_op_lb;
                lsu_op_lh = fifo_op_lh;
                lsu_op_lw = fifo_op_lw;
                lsu_op_lbu = fifo_op_lbu;
                lsu_op_lhu = fifo_op_lhu;
                lsu_op_load = fifo_op_load;
                lsu_op_store = fifo_op_store;
                lsu_rd_addr = fifo_rd_addr;
                lsu_addr = fifo_addr;
                lsu_wdata = fifo_wdata;
                lsu_wmask = fifo_wmask;
                lsu_commit_id = fifo_commit_id;
                lsu_reg_we = fifo_reg_we;
                lsu_wb_ready = fifo_wb_ready;
                processing_inst1 = 1'b0;
            end
        endcase
    end

    // ===================================================================
    // RAW转发逻辑
    // ===================================================================
    
    // RAW转发数据生成（简化版本，从store的低32位提取）
    wire [31:0] forward_data = mem0_wdata_i[31:0];
    
    // ===================================================================
    // 输出控制逻辑
    // ===================================================================
    
    // 暂停信号生成
    assign mem_stall_o = lsu_stall || 
                        (current_state == STATE_PROC_FIRST) ||
                        (current_state == STATE_PROC_SECOND) ||
                        (req_mem0_i && req_mem1_i && structural_hazard);

    // 写回数据路由
    assign lsu0_reg_wdata_o = (processing_inst1 || (current_state == STATE_PROC_FIRST)) ? lsu_reg_wdata : 
                             (raw_forward && req_mem1_i && mem1_op_load_i) ? forward_data : 
                             {`REG_DATA_WIDTH{1'b0}};
    
    assign lsu0_reg_we_o = (processing_inst1 || (current_state == STATE_PROC_FIRST)) ? lsu_reg_we_out : 
                          (raw_forward && req_mem1_i && mem1_op_load_i) ? mem0_reg_we_i : 
                          1'b0;
    
    assign lsu0_reg_waddr_o = (processing_inst1 || (current_state == STATE_PROC_FIRST)) ? lsu_reg_waddr : 
                             (raw_forward && req_mem1_i && mem1_op_load_i) ? mem0_rd_i : 
                             {`REG_ADDR_WIDTH{1'b0}};
    
    assign lsu0_commit_id_o = (processing_inst1 || (current_state == STATE_PROC_FIRST)) ? lsu_commit_id_out : 
                             (raw_forward && req_mem1_i && mem1_op_load_i) ? mem0_commit_id_i : 
                             {`COMMIT_ID_WIDTH{1'b0}};

    assign lsu1_reg_wdata_o = (!processing_inst1 && !(current_state == STATE_PROC_FIRST)) ? lsu_reg_wdata : 
                             (raw_forward && req_mem1_i && mem1_op_load_i) ? forward_data : 
                             (current_state == STATE_PROC_SECOND) ? lsu_reg_wdata :
                             {`REG_DATA_WIDTH{1'b0}};
    
    assign lsu1_reg_we_o = (!processing_inst1 && !(current_state == STATE_PROC_FIRST)) ? lsu_reg_we_out : 
                          (raw_forward && req_mem1_i && mem1_op_load_i) ? mem1_reg_we_i : 
                          (current_state == STATE_PROC_SECOND) ? lsu_reg_we_out :
                          1'b0;
    
    assign lsu1_reg_waddr_o = (!processing_inst1 && !(current_state == STATE_PROC_FIRST)) ? lsu_reg_waddr : 
                             (raw_forward && req_mem1_i && mem1_op_load_i) ? mem1_rd_i : 
                             (current_state == STATE_PROC_SECOND) ? lsu_reg_waddr :
                             {`REG_ADDR_WIDTH{1'b0}};
    
    assign lsu1_commit_id_o = (!processing_inst1 && !(current_state == STATE_PROC_FIRST)) ? lsu_commit_id_out : 
                             (raw_forward && req_mem1_i && mem1_op_load_i) ? mem1_commit_id_i : 
                             (current_state == STATE_PROC_SECOND) ? lsu_commit_id_out :
                             {`COMMIT_ID_WIDTH{1'b0}};

    // ===================================================================
    // LSU单元实例化
    // ===================================================================
    
    lsu_unit u_lsu_unit (
        .clk(clk),
        .rst_n(rst_n),
        .int_assert_i(int_assert_i),
        
        // 访存请求信号
        .req_mem_i(lsu_req),
        .mem_op_lb_i(lsu_op_lb),
        .mem_op_lh_i(lsu_op_lh),
        .mem_op_lw_i(lsu_op_lw),
        .mem_op_lbu_i(lsu_op_lbu),
        .mem_op_lhu_i(lsu_op_lhu),
        .mem_op_load_i(lsu_op_load),
        .mem_op_store_i(lsu_op_store),
        .rd_addr_i(lsu_rd_addr),
        
        // 访存地址和数据
        .mem_addr_i(lsu_addr[31:0]),  // 使用低32位地址
        .mem_wdata_i(lsu_wdata[31:0]), // 使用低32位数据
        .mem_wmask_i(lsu_wmask[3:0]),  // 使用低4位掩码
        
        .commit_id_i(lsu_commit_id),
        
        // 访存阻塞和忙信号输出
        .mem_stall_o(lsu_stall),
        
        // 寄存器写回接口
        .reg_wdata_o(lsu_reg_wdata),
        .reg_we_o(lsu_reg_we_out),
        .reg_waddr_o(lsu_reg_waddr),
        .commit_id_o(lsu_commit_id_out),
        
        // AXI Master接口 - 直接连接到外部
        .M_AXI_AWID(M_AXI_AWID),
        .M_AXI_AWADDR(M_AXI_AWADDR),
        .M_AXI_AWLEN(M_AXI_AWLEN),
        .M_AXI_AWSIZE(M_AXI_AWSIZE),
        .M_AXI_AWBURST(M_AXI_AWBURST),
        .M_AXI_AWLOCK(M_AXI_AWLOCK),
        .M_AXI_AWCACHE(M_AXI_AWCACHE),
        .M_AXI_AWPROT(M_AXI_AWPROT),
        .M_AXI_AWQOS(M_AXI_AWQOS),
        .M_AXI_AWUSER(M_AXI_AWUSER),
        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),
        
        .M_AXI_WDATA(M_AXI_WDATA),
        .M_AXI_WSTRB(M_AXI_WSTRB),
        .M_AXI_WLAST(M_AXI_WLAST),
        .M_AXI_WUSER(M_AXI_WUSER),
        .M_AXI_WVALID(M_AXI_WVALID),
        .M_AXI_WREADY(M_AXI_WREADY),
        
        .M_AXI_BID(M_AXI_BID),
        .M_AXI_BRESP(M_AXI_BRESP),
        .M_AXI_BUSER(M_AXI_BUSER),
        .M_AXI_BVALID(M_AXI_BVALID),
        .M_AXI_BREADY(M_AXI_BREADY),
        
        .M_AXI_ARID(M_AXI_ARID),
        .M_AXI_ARADDR(M_AXI_ARADDR),
        .M_AXI_ARLEN(M_AXI_ARLEN),
        .M_AXI_ARSIZE(M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),
        .M_AXI_ARLOCK(M_AXI_ARLOCK),
        .M_AXI_ARCACHE(M_AXI_ARCACHE),
        .M_AXI_ARPROT(M_AXI_ARPROT),
        .M_AXI_ARQOS(M_AXI_ARQOS),
        .M_AXI_ARUSER(M_AXI_ARUSER),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),
        
        .M_AXI_RID(M_AXI_RID),
        .M_AXI_RDATA(M_AXI_RDATA),
        .M_AXI_RRESP(M_AXI_RRESP),
        .M_AXI_RLAST(M_AXI_RLAST),
        .M_AXI_RUSER(M_AXI_RUSER),
        .M_AXI_RVALID(M_AXI_RVALID),
        .M_AXI_RREADY(M_AXI_RREADY)
    );

    // Store busy信号逻辑 - 检测store操作是否在进行中
    assign mem0_store_busy_o = (processing_inst1 && mem0_op_store_i) || 
                               (state == STATE_PROC_FIRST && mem0_op_store_i) ||
                               (state == STATE_PROC_SECOND && fifo_op_store && processing_inst1);
    
    assign mem1_store_busy_o = (!processing_inst1 && mem1_op_store_i) || 
                               (state == STATE_IDLE && req_mem1_i && mem1_op_store_i && !mem0_req) ||
                               (state == STATE_PROC_SECOND && fifo_op_store && !processing_inst1);

endmodule

endmodule