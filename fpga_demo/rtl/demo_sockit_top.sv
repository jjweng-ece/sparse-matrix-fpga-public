// Narrow logical board wrapper. Port names have documented RevC counterparts;
// no physical locations are assigned here. Board release remains Pending.
module demo_sockit_top #(parameter integer DEBOUNCE_CYCLES=1000000,CLOCK_HZ=50000000)(
    input wire OSC_50_B5B,input wire [1:0] KEY,input wire [3:0] SW,
    output wire [3:0] LED);
    demo_top #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.CLOCK_HZ(CLOCK_HZ)) demo(
        .clk(OSC_50_B5B),.reset_n_async(KEY[0]),.start_n_async(KEY[1]),.sw_async(SW),
        .debug_addr(4'd0),.led(LED),.busy(),.done(),.pass(),.fail(),.done_pulse(),
        .selected_mode(),.dense_cycles(),.csr_cycles(),.total_cycles(),
        .dense_macs(),.csr_macs(),.dense_loads(),.csr_loads(),.dense_data(),.csr_data());
endmodule
