module demo_leds #(parameter integer CLOCK_HZ=50000000)(
    input wire clk,rst_n,input wire [1:0] page,input wire busy,done,pass,fail,
    input wire [31:0] dense_cycles,csr_cycles,input wire [15:0] dense_macs,csr_macs,
    output reg [3:0] led);
    localparam integer CW=(CLOCK_HZ<2)?1:$clog2(CLOCK_HZ);
    reg [CW-1:0] divider;reg [2:0] nibble;reg [1:0] old_page;
    reg [31:0] data;
    always @(posedge clk)begin
        if(!rst_n)begin divider<=0;nibble<=0;old_page<=0;end
        else begin old_page<=page;
            if(page!=old_page)begin divider<=0;nibble<=0;end
            else if(divider==CLOCK_HZ-1)begin divider<=0;nibble<=nibble+1'b1;end
            else divider<=divider+1'b1;
        end
    end
    always @* begin
        case(page)
        1:data=dense_cycles;
        2:data=csr_cycles;
        3:data={csr_macs,dense_macs};
        default:data=0;
        endcase
        if(page==0)led={fail,pass,done,busy};else led=data[{nibble,2'b00} +: 4];
    end
endmodule
