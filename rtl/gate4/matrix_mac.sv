// One signed multiplier, L=1; seed load flushes the product pipeline.
module matrix_mac(input wire clk, rst_n, load_acc, in_valid,
    input wire signed [7:0] a,b, input wire [31:0] init_acc,
    output reg out_valid, output reg [31:0] acc);
    reg signed [15:0] product_q;
    reg product_valid;
    wire signed [15:0] product = a*b;
    always @(posedge clk) begin
        if (!rst_n || load_acc) begin
            acc <= !rst_n ? 32'd0 : init_acc;
            product_q<=0; product_valid<=0; out_valid<=0;
        end else begin
            product_valid<=in_valid; out_valid<=product_valid;
            if(in_valid) product_q<=product;
            if(product_valid) acc<=acc+{{16{product_q[15]}},product_q};
        end
    end
endmodule
