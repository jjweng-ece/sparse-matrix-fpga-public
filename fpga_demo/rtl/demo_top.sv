// Pin-neutral top. This file does not assert a physical SoCKit pin assignment.
module demo_top #(parameter integer DEBOUNCE_CYCLES=1000000, CLOCK_HZ=50000000)(
    input wire clk,reset_n_async,start_n_async,input wire [3:0] sw_async,
    input wire [3:0] debug_addr,output wire [3:0] led,
    output wire busy,done,pass,fail,done_pulse,output wire [1:0] selected_mode,
    output wire [31:0] dense_cycles,csr_cycles,total_cycles,
    output wire [15:0] dense_macs,csr_macs,dense_loads,csr_loads,
    output wire [31:0] dense_data,csr_data);
    wire rst_n,start_pulse;wire [3:0] switches;
    demo_inputs #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) inputs(
        .clk(clk),.reset_n_async(reset_n_async),.start_n_async(start_n_async),.sw_async(sw_async),
        .rst_n(rst_n),.start_pulse(start_pulse),.switches(switches));
    demo_core core(.clk(clk),.rst_n(rst_n),.start(start_pulse),.mode(switches[1:0]),
        .debug_addr(debug_addr),.busy(busy),.done(done),.pass(pass),.fail(fail),.done_pulse(done_pulse),
        .selected_mode(selected_mode),.dense_cycles(dense_cycles),.csr_cycles(csr_cycles),
        .total_cycles(total_cycles),.dense_macs(dense_macs),.csr_macs(csr_macs),
        .dense_loads(dense_loads),.csr_loads(csr_loads),.dense_data(dense_data),.csr_data(csr_data));
    demo_leds #(.CLOCK_HZ(CLOCK_HZ)) display(.clk(clk),.rst_n(rst_n),.page(switches[3:2]),
        .busy(busy),.done(done),.pass(pass),.fail(fail),.dense_cycles(dense_cycles),
        .csr_cycles(csr_cycles),.dense_macs(dense_macs),.csr_macs(csr_macs),.led(led));
endmodule
