module demo_core(input wire clk,rst_n,start,input wire [1:0] mode,
    input wire [3:0] debug_addr,output wire busy,
    output reg done,pass,fail,done_pulse,output reg [1:0] selected_mode,
    output reg [31:0] dense_cycles,csr_cycles,total_cycles,
    output reg [15:0] dense_macs,csr_macs,dense_loads,csr_loads,
    output wire [31:0] dense_data,csr_data);
    localparam IDLE=0,CLEAR=1,LOAD=2,START=3,WAIT=4,COMPARE=5,FINISH=6;
    reg [2:0] state;
    reg [6:0] di,si;reg [3:0] compare_addr;
    reg seen_d,seen_s,bad;reg [10:0] watchdog;
    wire engine_rst_n=rst_n && state!=CLEAR;
    wire engine_start=(state==START);
    wire [3:0] read_addr=(state==COMPARE)?compare_addr:debug_addr;
    wire dr,sr,dbusy,sbusy,ddone,sdone,derr,serr,dvalid,svalid;
    wire [31:0] ddata,sdata,dcy,scy,dcntl,scntl,expected;
    wire [15:0] dmac,smac;
    wire [2:0] dbank,sbank;wire [4:0] daddr,saddr,nnz;
    wire [31:0] dw,sw;wire [6:0] dt,st;
    wire dv=(state==LOAD && di<dt),sv=(state==LOAD && si<st);
    assign busy=(state!=IDLE);assign dense_data=ddata;assign csr_data=sdata;
    demo_rom rom(.mode(selected_mode),.d_index(di),.s_index(si),.out_addr(compare_addr),
        .d_bank(dbank),.s_bank(sbank),.d_addr(daddr),.s_addr(saddr),.d_data(dw),.s_data(sw),
        .d_total(dt),.s_total(st),.expected(expected),.nnz(nnz));
    matrix_dense dense(.clk(clk),.rst_n(engine_rst_n),.start(engine_start),.seed_enable(1'b0),
        .load_valid(dv),.load_ready(dr),.load_bank(dbank),.load_addr(daddr),.load_data(dw),
        .read_addr(read_addr),.read_data(ddata),.busy(dbusy),.done(ddone),.error(derr),
        .result_valid(dvalid),.cycle_count(dcy),.mac_count(dmac),.control_cycles(dcntl));
    matrix_csr sparse(.clk(clk),.rst_n(engine_rst_n),.start(engine_start),.seed_enable(1'b0),
        .load_valid(sv),.load_ready(sr),.load_bank(sbank),.load_addr(saddr),.load_data(sw),
        .read_addr(read_addr),.read_data(sdata),.busy(sbusy),.done(sdone),.error(serr),
        .result_valid(svalid),.cycle_count(scy),.mac_count(smac),.control_cycles(scntl));
    always @(posedge clk)begin
        if(!rst_n)begin
            state<=IDLE;done<=0;pass<=0;fail<=0;done_pulse<=0;selected_mode<=0;
            dense_cycles<=0;csr_cycles<=0;dense_macs<=0;csr_macs<=0;
            dense_loads<=0;csr_loads<=0;total_cycles<=0;di<=0;si<=0;
            compare_addr<=0;seen_d<=0;seen_s<=0;bad<=0;watchdog<=0;
        end else begin
            done_pulse<=0;
            if(busy)total_cycles<=total_cycles+1'b1;
            case(state)
            IDLE:if(start)begin state<=CLEAR;selected_mode<=mode;done<=0;pass<=0;fail<=0;
                dense_cycles<=0;csr_cycles<=0;dense_macs<=0;csr_macs<=0;
                dense_loads<=0;csr_loads<=0;total_cycles<=0;di<=0;si<=0;
                compare_addr<=0;seen_d<=0;seen_s<=0;bad<=0;watchdog<=0;end
            CLEAR:state<=LOAD;
            LOAD:begin
                if(dv && dr)begin di<=di+1'b1;dense_loads<=dense_loads+1'b1;end
                if(sv && sr)begin si<=si+1'b1;csr_loads<=csr_loads+1'b1;end
                if(di==dt && si==st)state<=START;
            end
            START:state<=WAIT;
            WAIT:begin
                watchdog<=watchdog+1'b1;
                if(ddone)begin seen_d<=1;dense_cycles<=dcy;dense_macs<=dmac;if(derr || !dvalid)bad<=1;end
                if(sdone)begin seen_s<=1;csr_cycles<=scy;csr_macs<=smac;if(serr || !svalid)bad<=1;end
                if((seen_d || ddone) && (seen_s || sdone))begin compare_addr<=0;state<=COMPARE;end
                else if(watchdog==1023)begin bad<=1;state<=FINISH;end
            end
            COMPARE:begin
                if(!dvalid || !svalid || ddata!=sdata || ddata!=expected)bad<=1;
                if(compare_addr==15)state<=FINISH;else compare_addr<=compare_addr+1'b1;
            end
            FINISH:begin done<=1;pass<=!bad;fail<=bad;done_pulse<=1;state<=IDLE;end
            default:begin bad<=1;state<=FINISH;end
            endcase
        end
    end
endmodule
