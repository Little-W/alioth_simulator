module irq_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  irq_vec,
    output reg         irq_req,
    output reg  [7:0]  irq_id
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_req <= 1'b0;
            irq_id  <= 8'b0;
        end else begin
            casex (irq_vec)
                8'bxxxxxxx1: begin irq_req <= 1'b1; irq_id <= 8'd0; end
                8'bxxxxxx10: begin irq_req <= 1'b1; irq_id <= 8'd1; end
                8'bxxxxx100: begin irq_req <= 1'b1; irq_id <= 8'd2; end
                8'bxxxx1000: begin irq_req <= 1'b1; irq_id <= 8'd3; end
                8'bxxx10000: begin irq_req <= 1'b1; irq_id <= 8'd4; end
                8'bxx100000: begin irq_req <= 1'b1; irq_id <= 8'd5; end
                8'bx1000000: begin irq_req <= 1'b1; irq_id <= 8'd6; end
                8'b10000000: begin irq_req <= 1'b1; irq_id <= 8'd7; end
                default:     begin irq_req <= 1'b0; irq_id <= 8'd0; end
            endcase
        end
    end
endmodule
