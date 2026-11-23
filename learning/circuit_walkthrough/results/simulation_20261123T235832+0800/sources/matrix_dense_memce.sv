module matrix_dense_memce(
    input wire clk,rst_n,start,seed_enable,load_valid,
    output wire load_ready,
    input wire [2:0] load_bank, input wire [4:0] load_addr,
    input wire [31:0] load_data, input wire [3:0] read_addr,
    output wire [31:0] read_data, output wire busy,
    output reg done,error,result_valid,
    output reg [31:0] cycle_count, output reg [15:0] mac_count,
    output wire [31:0] control_cycles);
    localparam IDLE=0,CHECK=1,SEED=2,FETCH=3,ISSUE=4,DRAIN=5,WRITE=6,FINISH=7,ERROR=8;
    reg [3:0] state;
    reg [3:0] out_idx;
    reg [1:0] k;
    wire [7:0] a_q,b_q;
    reg operands_valid;
    wire read_operands=rst_n && state==FETCH;
    wire loading=rst_n && state==IDLE && !start && load_valid && load_addr<16;
    sync_read_ram a_store(.clk(clk),.write_enable(loading && load_bank==0),
        .write_addr(load_addr[3:0]),.write_data(load_data[7:0]),
        .read_enable(read_operands),.read_addr({out_idx[3:2],k}),.read_data(a_q));
    sync_read_ram b_store(.clk(clk),.write_enable(loading && load_bank==1),
        .write_addr(load_addr[3:0]),.write_data(load_data[7:0]),
        .read_enable(read_operands),.read_addr({k,out_idx[1:0]}),.read_data(b_q));
    reg [31:0] seeds[0:15],c_mem[0:15];
    reg [15:0] a_loaded,b_loaded,s_loaded;
    reg seeded;
    wire signed [7:0] op_a=operands_valid ? a_q : 8'sd0;
    wire signed [7:0] op_b=operands_valid ? b_q : 8'sd0;
    wire mv; wire [31:0] acc;
    assign busy=(state!=IDLE);
    assign load_ready=rst_n && !busy && !start;
    assign read_data=result_valid ? c_mem[read_addr] : 32'd0;
    assign control_cycles=cycle_count-mac_count;
    matrix_mac mac(.clk(clk),.rst_n(rst_n),.load_acc(state==SEED),
        .in_valid(state==ISSUE),.a(op_a),.b(op_b),
        .init_acc(seeded ? seeds[out_idx] : 32'd0),.out_valid(mv),.acc(acc));
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;done<=0;error<=0;result_valid<=0;
            cycle_count<=0;mac_count<=0;a_loaded<=0;b_loaded<=0;s_loaded<=0;
            seeded<=0;out_idx<=0;k<=0;operands_valid<=0;
        end else begin
            done<=0;
            if(busy) cycle_count<=cycle_count+1'b1;
            case(state)
            IDLE: begin
                if(start) begin
                    state<=CHECK;seeded<=seed_enable;out_idx<=0;
                    cycle_count<=0;mac_count<=0;error<=0;result_valid<=0;
                end else if(load_valid && load_addr<16) begin
                    case(load_bank)
                    0:begin a_loaded[load_addr]<=1;end
                    1:begin b_loaded[load_addr]<=1;end
                    2:begin seeds[load_addr]<=load_data;s_loaded[load_addr]<=1;end
                    default:begin end
                    endcase
                end
            end
            CHECK: if((&a_loaded) && (&b_loaded) && (!seeded || (&s_loaded))) state<=SEED; else state<=ERROR;
            SEED:begin k<=0;state<=FETCH;end
            FETCH:begin operands_valid<=1;state<=ISSUE;end
            ISSUE:begin mac_count<=mac_count+1'b1;if(k==3) state<=DRAIN;else begin k<=k+1'b1;state<=FETCH;end end
            DRAIN:state<=WRITE;
            WRITE:begin
                if(!mv) state<=ERROR;
                else begin c_mem[out_idx]<=acc;if(out_idx==15) state<=FINISH;else begin out_idx<=out_idx+1'b1;state<=SEED;end end
            end
            FINISH:begin done<=1;result_valid<=1;state<=IDLE;end
            ERROR:begin done<=1;error<=1;result_valid<=0;state<=IDLE;end
            default:state<=ERROR;
            endcase
        end
    end
endmodule
