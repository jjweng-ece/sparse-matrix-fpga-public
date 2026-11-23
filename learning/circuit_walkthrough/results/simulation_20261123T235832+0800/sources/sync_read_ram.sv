// Synchronous read enable; no generated clock and no reset on memory/data q.
// A caller must not consume q until an enabled read has occurred.
module sync_read_ram #(
    parameter WIDTH=8, ADDR_WIDTH=4
)(
    input wire clk,write_enable,read_enable,
    input wire [ADDR_WIDTH-1:0] write_addr,read_addr,
    input wire [WIDTH-1:0] write_data,
    output reg [WIDTH-1:0] read_data
);
    reg [WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    always @(posedge clk) begin
        if(write_enable) mem[write_addr]<=write_data;
        if(read_enable) read_data<=mem[read_addr];
    end
endmodule
