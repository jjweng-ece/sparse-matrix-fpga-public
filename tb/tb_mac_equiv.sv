`timescale 1ns/1ps
module tb_mac_equiv;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, clear_acc = 0, in_valid = 0;
    reg signed [7:0] in_a = 0, in_b = 0;
    wire base_valid, sparse_valid;
    wire signed [31:0] base_acc, sparse_acc;
    mac_baseline baseline (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .in_valid(in_valid), .in_a(in_a), .in_b(in_b),
        .out_valid(base_valid), .acc_result(base_acc));
    mac_sparse sparse (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .in_valid(in_valid), .in_a(in_a), .in_b(in_b),
        .out_valid(sparse_valid), .acc_result(sparse_acc));

    // Matched observation points. These are TB aliases, not extra RTL hardware.
    wire [7:0] base_mul_a = in_a, base_mul_b = in_b;
    wire [7:0] sparse_mul_a = sparse.mul_a, sparse_mul_b = sparse.mul_b;
    wire [15:0] base_product = baseline.product, sparse_product = sparse.product;
    wire [15:0] base_product_q = baseline.product_q, sparse_product_q = sparse.product_q;
    wire base_pvalid = baseline.product_valid, sparse_pvalid = sparse.product_valid;
    wire sparse_a_zero = sparse.a_is_zero, sparse_b_zero = sparse.b_is_zero;
    wire sparse_zero = sparse.zero_detect, sparse_isolate = sparse.isolate_active;
    // Existing RTL update conditions, NOT newly inserted/gated clocks or CEs.
    wire capture_condition = rst_n && !clear_acc && in_valid;
    wire base_acc_condition = rst_n && !clear_acc && baseline.product_valid;
    wire sparse_acc_condition = rst_n && !clear_acc && sparse.product_valid;
    reg measuring = 0;

    integer fd, fields, cycles = 0, retired = 0;
    integer r,c,v,a,b,expected_valid;
    integer first_measure = 0, measure_rows = 0, unused;
    reg [31:0] expected_acc;
    initial begin
        unused = $value$plusargs("FIRST_MEASURE=%d", first_measure);
        unused = $value$plusargs("MEASURE_ROWS=%d", measure_rows);
        fd = $fopen("vectors.txt", "r");
        if (!fd) $fatal(1, "FAIL: cannot open vectors.txt");
        fields = $fscanf(fd, "%d %d %d %d %d %d %h", r,c,v,a,b,expected_valid,expected_acc);
        while (fields == 7) begin
            @(negedge clk);
            if (first_measure > 0 && cycles + 1 == first_measure) measuring = 1;
            if (first_measure > 0 && cycles + 1 == first_measure + measure_rows) measuring = 0;
            rst_n=r; clear_acc=c; in_valid=v; in_a=a; in_b=b;
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (base_valid !== expected_valid[0] || sparse_valid !== expected_valid[0] ||
                base_acc !== expected_acc || sparse_acc !== expected_acc ||
                base_valid !== sparse_valid || base_acc !== sparse_acc) begin
                $display("FAIL cycle=%0d expected=%0d/%08h baseline=%0b/%08h sparse=%0b/%08h",
                    cycles,expected_valid,expected_acc,base_valid,base_acc,sparse_valid,sparse_acc);
                $fatal(1, "FAIL: baseline/sparse/Python equivalence");
            end
            if (base_valid) retired = retired + 1;
            fields = $fscanf(fd, "%d %d %d %d %d %d %h", r,c,v,a,b,expected_valid,expected_acc);
        end
        if (!$feof(fd)) $fatal(1, "FAIL: malformed vectors");
        if (cycles == 0) $fatal(1, "FAIL: empty vectors");
        $fclose(fd);
        $display("PASS equivalence cycles=%0d retired=%0d", cycles, retired);
        $finish;
    end
    initial begin
        #10000000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
