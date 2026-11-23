// Fixed contract: input sampled E[n], corresponding result at E[n+1].
module mac_baseline (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               clear_acc,
    input  wire               in_valid,
    input  wire signed [7:0]  in_a,
    input  wire signed [7:0]  in_b,
    output reg                out_valid,
    output reg signed [31:0]  acc_result
);
    reg signed [15:0] product_q;
    reg product_valid;
    wire signed [15:0] product = in_a * in_b;
    wire signed [31:0] extended_product = {{16{product_q[15]}}, product_q};

    always @(posedge clk) begin
        if (!rst_n) begin
            product_q <= 16'sd0;
            product_valid <= 1'b0;
            out_valid <= 1'b0;
            acc_result <= 32'sd0;
        end else if (clear_acc) begin
            product_q <= 16'sd0;
            product_valid <= 1'b0;
            out_valid <= 1'b0;
            acc_result <= 32'sd0;
        end else begin
            product_valid <= in_valid;
            if (in_valid)
                product_q <= product;
            out_valid <= product_valid;
            if (product_valid)
                acc_result <= acc_result + extended_product;
        end
    end
endmodule
