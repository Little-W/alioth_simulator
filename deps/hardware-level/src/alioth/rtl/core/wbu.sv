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

module wbu (
    input wire clk,
    input wire rst_n,

    // 来自EXU的ALU数据 (双发射，原 adder+shifter)
    input  wire [ `REG_DATA_WIDTH-1:0] alu1_reg_wdata_i,
    input  wire                        alu1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu1_commit_id_i,
    output wire                        alu1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] alu2_reg_wdata_i,
    input  wire                        alu2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] alu2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] alu2_commit_id_i,
    output wire                        alu2_ready_o,

    // 来自EXU的MUL数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] mul1_reg_wdata_i,
    input  wire                        mul1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul1_commit_id_i,
    output wire                        mul1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] mul2_reg_wdata_i,
    input  wire                        mul2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] mul2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] mul2_commit_id_i,
    output wire                        mul2_ready_o,

    // 来自EXU的DIV数据 (双发射)
    input  wire [ `REG_DATA_WIDTH-1:0] div1_reg_wdata_i,
    input  wire                        div1_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div1_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div1_commit_id_i,
    output wire                        div1_ready_o,

    input  wire [ `REG_DATA_WIDTH-1:0] div2_reg_wdata_i,
    input  wire                        div2_reg_we_i,
    input  wire [ `REG_ADDR_WIDTH-1:0] div2_reg_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] div2_commit_id_i,
    output wire                        div2_ready_o,

    // 来自EXU的CSR数据 (单路)
    input  wire [ `REG_DATA_WIDTH-1:0] csr_wdata_i,
    input  wire                        csr_we_i,
    input  wire [ `BUS_ADDR_WIDTH-1:0] csr_waddr_i,
    input  wire [`COMMIT_ID_WIDTH-1:0] csr_commit_id_i,
    output wire                        csr_ready_o,

    // CSR寄存器写数据输入 (单路)
    input wire [`REG_DATA_WIDTH-1:0] csr_reg_wdata_i,
    input wire [`REG_ADDR_WIDTH-1:0]  csr_reg_waddr_i,
    input wire                        csr_reg_we_i,

    // 来自EXU的LSU数据 (单路)
    input wire [ `REG_DATA_WIDTH-1:0] lsu_reg_wdata_i,
    input wire                        lsu_reg_we_i,
    input wire [ `REG_ADDR_WIDTH-1:0] lsu_reg_waddr_i,
    input wire [`COMMIT_ID_WIDTH-1:0] lsu_commit_id_i,
    output wire                       lsu_ready_o,

    // 提交输出
    output wire                        commit_valid1_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id1_o,
    output wire                        commit_valid2_o,
    output wire [`COMMIT_ID_WIDTH-1:0] commit_id2_o,

    // 通用寄存器写回（双通道）
    output wire [`REG_DATA_WIDTH-1:0] reg1_wdata_o,
    output wire                       reg1_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg1_waddr_o,

    output wire [`REG_DATA_WIDTH-1:0] reg2_wdata_o,
    output wire                       reg2_we_o,
    output wire [`REG_ADDR_WIDTH-1:0] reg2_waddr_o,

    // CSR写回
    output wire [`REG_DATA_WIDTH-1:0] csr_wdata_o,
    output wire                       csr_we_o,
    output wire [`BUS_ADDR_WIDTH-1:0] csr_waddr_o
);

    // 执行单元枚举 (合并ALU)
    localparam EU_ALU1  = 4'd0;
    localparam EU_ALU2  = 4'd1;
    localparam EU_MUL1  = 4'd2;
    localparam EU_MUL2  = 4'd3;
    localparam EU_DIV1  = 4'd4;
    localparam EU_DIV2  = 4'd5;
    localparam EU_CSR   = 4'd6;
    localparam EU_LSU   = 4'd7;
    
    // 聚合各执行单元写回意图 (总数 8)
    wire [7:0] eu_reg_we;
    wire [`REG_DATA_WIDTH-1:0] eu_reg_wdata [0:7];
    wire [4:0]                 eu_reg_waddr [0:7];
    wire [`COMMIT_ID_WIDTH-1:0] eu_commit_id [0:7];

    assign eu_reg_we = {lsu_reg_we_i, csr_reg_we_i,
                        div2_reg_we_i, div1_reg_we_i, mul2_reg_we_i, mul1_reg_we_i,
                        alu2_reg_we_i, alu1_reg_we_i};

    assign eu_reg_wdata[EU_ALU1] = alu1_reg_wdata_i;
    assign eu_reg_wdata[EU_ALU2] = alu2_reg_wdata_i;
    assign eu_reg_wdata[EU_MUL1] = mul1_reg_wdata_i;
    assign eu_reg_wdata[EU_MUL2] = mul2_reg_wdata_i;
    assign eu_reg_wdata[EU_DIV1] = div1_reg_wdata_i;
    assign eu_reg_wdata[EU_DIV2] = div2_reg_wdata_i;
    assign eu_reg_wdata[EU_CSR]  = csr_reg_wdata_i;
    assign eu_reg_wdata[EU_LSU] = lsu_reg_wdata_i;

    assign eu_reg_waddr[EU_ALU1] = alu1_reg_waddr_i;
    assign eu_reg_waddr[EU_ALU2] = alu2_reg_waddr_i;
    assign eu_reg_waddr[EU_MUL1] = mul1_reg_waddr_i;
    assign eu_reg_waddr[EU_MUL2] = mul2_reg_waddr_i;
    assign eu_reg_waddr[EU_DIV1] = div1_reg_waddr_i;
    assign eu_reg_waddr[EU_DIV2] = div2_reg_waddr_i;
    assign eu_reg_waddr[EU_CSR]  = csr_reg_waddr_i;
    assign eu_reg_waddr[EU_LSU] = lsu_reg_waddr_i;

    assign eu_commit_id[EU_ALU1] = alu1_commit_id_i;
    assign eu_commit_id[EU_ALU2] = alu2_commit_id_i;
    assign eu_commit_id[EU_MUL1] = mul1_commit_id_i;
    assign eu_commit_id[EU_MUL2] = mul2_commit_id_i;
    assign eu_commit_id[EU_DIV1] = div1_commit_id_i;
    assign eu_commit_id[EU_DIV2] = div2_commit_id_i;
    assign eu_commit_id[EU_CSR]  = csr_commit_id_i;
    assign eu_commit_id[EU_LSU] = lsu_commit_id_i;

    // 可写回集合
    wire [7:0] eu_can_writeback = eu_reg_we;

    // 简单双通道优先级仲裁（保持原先大类优先顺序）
    reg [3:0] wb_ch1_eu, wb_ch2_eu; reg wb_ch1_valid, wb_ch2_valid;
    always @(*) begin
        wb_ch1_valid = 1'b0; wb_ch2_valid = 1'b0; wb_ch1_eu = 4'd0; wb_ch2_eu = 4'd0;
        // 通道1
        if (eu_can_writeback[EU_LSU])       begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_LSU; end
        else if (eu_can_writeback[EU_DIV2]) begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_DIV2; end
        else if (eu_can_writeback[EU_DIV1]) begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_DIV1; end
        else if (eu_can_writeback[EU_MUL2]) begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_MUL2; end
        else if (eu_can_writeback[EU_MUL1]) begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_MUL1; end
        else if (eu_can_writeback[EU_CSR])  begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_CSR;  end
        else if (eu_can_writeback[EU_ALU2]) begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_ALU2; end
        else if (eu_can_writeback[EU_ALU1]) begin wb_ch1_valid=1'b1; wb_ch1_eu=EU_ALU1; end
        // 通道2
        if (wb_ch1_valid) begin
            if (eu_can_writeback[EU_LSU]       && wb_ch1_eu!=EU_LSU)       begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_LSU; end
            else if (eu_can_writeback[EU_DIV2] && wb_ch1_eu!=EU_DIV2)      begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_DIV2; end
            else if (eu_can_writeback[EU_DIV1] && wb_ch1_eu!=EU_DIV1)      begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_DIV1; end
            else if (eu_can_writeback[EU_MUL2] && wb_ch1_eu!=EU_MUL2)      begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_MUL2; end
            else if (eu_can_writeback[EU_MUL1] && wb_ch1_eu!=EU_MUL1)      begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_MUL1; end
            else if (eu_can_writeback[EU_CSR]  && wb_ch1_eu!=EU_CSR)       begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_CSR; end
            else if (eu_can_writeback[EU_ALU2] && wb_ch1_eu!=EU_ALU2)      begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_ALU2; end
            else if (eu_can_writeback[EU_ALU1] && wb_ch1_eu!=EU_ALU1)      begin wb_ch2_valid=1'b1; wb_ch2_eu=EU_ALU1; end
        end
    end

    // 写回数据输出
    assign reg1_we_o    = wb_ch1_valid & eu_reg_we[wb_ch1_eu];
    assign reg1_waddr_o = reg1_we_o ? eu_reg_waddr[wb_ch1_eu] : {`REG_ADDR_WIDTH{1'b0}};
    assign reg1_wdata_o = reg1_we_o ? eu_reg_wdata[wb_ch1_eu] : {`REG_DATA_WIDTH{1'b0}};

    assign reg2_we_o    = wb_ch2_valid & eu_reg_we[wb_ch2_eu];
    assign reg2_waddr_o = reg2_we_o ? eu_reg_waddr[wb_ch2_eu] : {`REG_ADDR_WIDTH{1'b0}};
    assign reg2_wdata_o = reg2_we_o ? eu_reg_wdata[wb_ch2_eu] : {`REG_DATA_WIDTH{1'b0}};

    // CSR 写回（独立）
    assign csr_we_o    =  csr_we_i; 
    assign csr_waddr_o =  csr_waddr_i;
    assign csr_wdata_o =  csr_wdata_i;

    // 提交信号与ID
    assign commit_valid1_o = wb_ch1_valid ;
    assign commit_valid2_o = wb_ch2_valid ;
    assign commit_id1_o    = wb_ch1_valid ? eu_commit_id[wb_ch1_eu] : {`COMMIT_ID_WIDTH{1'b0}};
    assign commit_id2_o    = wb_ch2_valid ? eu_commit_id[wb_ch2_eu] : {`COMMIT_ID_WIDTH{1'b0}};

    // Ready 信号
    wire eu_selected [0:7];
    assign eu_selected[EU_ALU1] = (wb_ch1_valid && wb_ch1_eu==EU_ALU1) || (wb_ch2_valid && wb_ch2_eu==EU_ALU1);
    assign eu_selected[EU_ALU2] = (wb_ch1_valid && wb_ch1_eu==EU_ALU2) || (wb_ch2_valid && wb_ch2_eu==EU_ALU2);
    assign eu_selected[EU_MUL1] = (wb_ch1_valid && wb_ch1_eu==EU_MUL1) || (wb_ch2_valid && wb_ch2_eu==EU_MUL1);
    assign eu_selected[EU_MUL2] = (wb_ch1_valid && wb_ch1_eu==EU_MUL2) || (wb_ch2_valid && wb_ch2_eu==EU_MUL2);
    assign eu_selected[EU_DIV1] = (wb_ch1_valid && wb_ch1_eu==EU_DIV1) || (wb_ch2_valid && wb_ch2_eu==EU_DIV1);
    assign eu_selected[EU_DIV2] = (wb_ch1_valid && wb_ch1_eu==EU_DIV2) || (wb_ch2_valid && wb_ch2_eu==EU_DIV2);
    assign eu_selected[EU_CSR ] = (wb_ch1_valid && wb_ch1_eu==EU_CSR ) || (wb_ch2_valid && wb_ch2_eu==EU_CSR );
    assign eu_selected[EU_LSU] = (wb_ch1_valid && wb_ch1_eu==EU_LSU) || (wb_ch2_valid && wb_ch2_eu==EU_LSU);

    assign alu1_ready_o =  eu_selected[EU_ALU1];
    assign alu2_ready_o =  eu_selected[EU_ALU2];
    assign mul1_ready_o =  eu_selected[EU_MUL1];
    assign mul2_ready_o =  eu_selected[EU_MUL2];
    assign div1_ready_o =  eu_selected[EU_DIV1];
    assign div2_ready_o =  eu_selected[EU_DIV2];
    assign csr_ready_o  =  eu_selected[EU_CSR ] || csr_we_o;
    assign lsu_ready_o =  eu_selected[EU_LSU];

endmodule
