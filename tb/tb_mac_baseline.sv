`timescale 1ns/1ps
module tb_mac_baseline;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, clear_acc = 0, in_valid = 0;
    reg signed [7:0] in_a = 0, in_b = 0;
    wire out_valid;
    wire signed [31:0] acc_result;
    mac_baseline dut (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .in_valid(in_valid), .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid), .acc_result(acc_result));

    integer fd, fields, cycles = 0, retired = 0;
    integer r, c, v, a, b, expected_valid;
    reg [31:0] expected_acc;
    initial begin
        fd = $fopen("vectors.txt", "r");
        if (!fd) $fatal(1, "FAIL: cannot open vectors.txt");
        fields = $fscanf(fd, "%d %d %d %d %d %d %h", r,c,v,a,b,expected_valid,expected_acc);
        while (fields == 7) begin
            @(negedge clk);
            rst_n = r; clear_acc = c; in_valid = v; in_a = a; in_b = b;
            @(posedge clk);
            #1; // sample after nonblocking assignments, not in the active region
            cycles = cycles + 1;
            if (out_valid !== expected_valid[0] || acc_result !== expected_acc) begin
                $display("FAIL cycle=%0d rst=%0d clear=%0d valid=%0d a=%0d b=%0d expected=%0d/%08h actual=%0b/%08h",
                    cycles,r,c,v,a,b,expected_valid,expected_acc,out_valid,acc_result);
                $fatal(1, "FAIL: Python reference mismatch");
            end
            if (out_valid) retired = retired + 1;
            fields = $fscanf(fd, "%d %d %d %d %d %d %h", r,c,v,a,b,expected_valid,expected_acc);
        end
        if (!$feof(fd)) $fatal(1, "FAIL: malformed vector file");
        if (cycles == 0) $fatal(1, "FAIL: empty vectors");
        $fclose(fd);
        $display("PASS baseline cycles=%0d retired=%0d", cycles, retired);
        $finish;
    end
    initial begin
        #10000000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
