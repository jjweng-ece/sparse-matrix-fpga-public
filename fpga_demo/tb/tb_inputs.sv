`timescale 1ns/1ps
// Production debounce threshold, with the documented default 50MHz clock.
module tb_inputs;
    reg clk=0;always #10 clk=~clk;
    reg reset_n=0,button_n=1;reg [3:0] sw=0;
    wire rst_n,pulse;wire [3:0] synchronized_switches;
    integer presses=0;
    demo_inputs inputs(.clk(clk),.reset_n_async(reset_n),.start_n_async(button_n),
        .sw_async(sw),.rst_n(rst_n),.start_pulse(pulse),.switches(synchronized_switches));
    always @(posedge clk)begin #1;if(pulse)presses=presses+1;end
    task wait_cycles(input integer n);begin repeat(n)begin @(posedge clk);#2;end end endtask
    initial begin
        wait_cycles(3);@(negedge clk);reset_n=1;
        wait_cycles(1000010); // qualified release
        @(negedge clk);button_n=0;
        wait_cycles(999999);if(presses!=0)$fatal(1,"debounce shorter than threshold");
        wait_cycles(12);if(presses!=1)$fatal(1,"production threshold press missing");
        wait_cycles(1000010);if(presses!=1)$fatal(1,"held button retrigger");
        @(negedge clk);reset_n=0;wait_cycles(3);
        @(negedge clk);reset_n=1;wait_cycles(1000010);
        if(presses!=1)$fatal(1,"held across reset triggered");
        @(negedge clk);button_n=1;wait_cycles(1000010);
        @(negedge clk);button_n=0;wait_cycles(1000010);
        if(presses!=2)$fatal(1,"release/repress missing");
        $display("PASS INPUTS production_debounce=1000000 presses=2 reset_held_rejected=1");$finish;
    end
    initial begin #200000000;$fatal(1,"input test timeout");end
endmodule
