`timescale 1ns/1ps
`ifndef DUT_MODULE
`define DUT_MODULE mac_baseline
`endif
module tb_mapped;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,clear_acc=0,in_valid=0;
    reg signed [7:0] in_a=0,in_b=0;
    wire out_valid;
    wire [31:0] acc_result;
    `DUT_MODULE dut (.clk(clk),.rst_n(rst_n),.clear_acc(clear_acc),.in_valid(in_valid),
        .in_a(in_a),.in_b(in_b),.out_valid(out_valid),.acc_result(acc_result));
    reg measuring=0;
    integer fd,fields,cycles=0,retired=0;
    integer r,c,v,a,b,expected_valid;
    reg [31:0] expected_acc;
    initial begin
        fd=$fopen("vectors.txt","r");
        if (!fd) $fatal(1,"FAIL: missing vectors");
        fields=$fscanf(fd,"%d %d %d %d %d %d %h",r,c,v,a,b,expected_valid,expected_acc);
        while (fields==7) begin
            @(negedge clk);
            if (cycles+1==25) measuring=1;
            if (cycles+1==4025) measuring=0;
            rst_n=r;clear_acc=c;in_valid=v;in_a=a;in_b=b;
            @(posedge clk); #1;
            cycles=cycles+1;
            if (out_valid !== expected_valid[0] || acc_result !== expected_acc)
                $fatal(1,"FAIL mapped cycle=%0d expected=%0d/%08h actual=%0b/%08h",
                    cycles,expected_valid,expected_acc,out_valid,acc_result);
            if(out_valid) retired=retired+1;
            fields=$fscanf(fd,"%d %d %d %d %d %d %h",r,c,v,a,b,expected_valid,expected_acc);
        end
        if (!$feof(fd) || cycles==0) $fatal(1,"FAIL: invalid vector stream");
        $display("PASS mapped cycles=%0d retired=%0d",cycles,retired);
        $finish;
    end
    initial begin #10000000; $fatal(1,"FAIL: watchdog"); end
endmodule
