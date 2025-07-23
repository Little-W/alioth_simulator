module irq_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] irq_vec,      // 修改为12位
    output reg         irq_req,
    output reg  [7:0]  irq_id
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_req <= 1'b0;
            irq_id  <= 8'b0;
        end else begin
            casex (irq_vec)
                12'bxxxxxxxxxxx1: begin irq_req <= 1'b1; irq_id <= 8'd0; end
                12'bxxxxxxxxxx10: begin irq_req <= 1'b1; irq_id <= 8'd1; end
                12'bxxxxxxxxx100: begin irq_req <= 1'b1; irq_id <= 8'd2; end
                12'bxxxxxxxx1000: begin irq_req <= 1'b1; irq_id <= 8'd3; end
                12'bxxxxxxx10000: begin irq_req <= 1'b1; irq_id <= 8'd4; end
                12'bxxxxxx100000: begin irq_req <= 1'b1; irq_id <= 8'd5; end
                12'bxxxxx1000000: begin irq_req <= 1'b1; irq_id <= 8'd6; end
                12'bxxxx10000000: begin irq_req <= 1'b1; irq_id <= 8'd7; end
                12'bxxx100000000: begin irq_req <= 1'b1; irq_id <= 8'd8; end
                12'bxx1000000000: begin irq_req <= 1'b1; irq_id <= 8'd9; end
                12'bx10000000000: begin irq_req <= 1'b1; irq_id <= 8'd10; end
                12'b100000000000: begin irq_req <= 1'b1; irq_id <= 8'd11; end
                default:          begin irq_req <= 1'b0; irq_id <= 8'd0; end
            endcase
        end
    end
endmodule
