module demo_inputs #(parameter integer DEBOUNCE_CYCLES=1000000)(
    input wire clk,reset_n_async,start_n_async,input wire [3:0] sw_async,
    output wire rst_n,output reg start_pulse,output reg [3:0] switches);
    // Intel assignment is used rather than an ignored Xilinx async_reg attribute.
    (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *) reg [1:0] reset_pipe;
    (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *) reg button_meta,button_sync;
    (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *) reg [3:0] switch_meta;
    reg candidate,stable,armed;
    localparam integer CW=(DEBOUNCE_CYCLES<2) ? 1:$clog2(DEBOUNCE_CYCLES+1);
    reg [CW-1:0] count;
    assign rst_n=reset_pipe[1];
    always @(posedge clk or negedge reset_n_async)
        if(!reset_n_async)reset_pipe<=0;else reset_pipe<={reset_pipe[0],1'b1};
    always @(posedge clk)begin
        if(!rst_n)begin button_meta<=0;button_sync<=0;switch_meta<=0;switches<=0;
            candidate<=0;stable<=0;armed<=0;count<=0;start_pulse<=0;
        end else begin
            button_meta<=!start_n_async;button_sync<=button_meta;
            switch_meta<=sw_async;switches<=switch_meta;start_pulse<=0;
            if(button_sync!=candidate)begin candidate<=button_sync;count<=1;end
            else if(count<DEBOUNCE_CYCLES)begin
                count<=count+1'b1;
                if(count==DEBOUNCE_CYCLES-1)begin
                    stable<=candidate;
                    if(!candidate)armed<=1;
                    else if(!stable && armed)begin start_pulse<=1;armed<=0;end
                end
            end
        end
    end
endmodule
