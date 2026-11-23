// Canonical CSR-A x dense-B, exactly one pipelined MAC.
module matrix_csr(
    input wire clk,rst_n,start,seed_enable,load_valid,
    output wire load_ready,
    input wire [2:0] load_bank, input wire [4:0] load_addr,
    input wire [31:0] load_data, input wire [3:0] read_addr,
    output wire [31:0] read_data, output wire busy,
    output reg done,error,result_valid,
    output reg [31:0] cycle_count, output reg [15:0] mac_count,
    output wire [31:0] control_cycles);
    localparam IDLE=0,CHECK=1,VROW=2,VENTRY=3,ROW_LOAD=4,SEED=5,
        FETCH=6,ISSUE=7,DRAIN=8,WRITE=9,WRITE_EMPTY=10,FINISH=11,ERROR=12;
    reg [3:0] state;
    reg signed [7:0] values[0:15],b_mem[0:15];
    reg [1:0] columns[0:15];reg [4:0] pointers[0:4];reg [4:0] nnz;
    reg [31:0] seeds[0:15],c_mem[0:15];
    reg [15:0] v_loaded,c_loaded,b_loaded,s_loaded;
    reg [4:0] p_loaded;reg n_loaded;
    reg seeded;
    reg [1:0] row,col,validate_row;
    reg [4:0] pos,begin_pos,end_pos;
    reg signed [7:0] op_a,op_b;
    wire mv;wire [31:0] acc;
    wire [3:0] out_idx={row,col};
    assign busy=(state!=IDLE);
    assign load_ready=rst_n && !busy && !start;
    assign read_data=result_valid ? c_mem[read_addr] : 32'd0;
    assign control_cycles=cycle_count-mac_count;
    matrix_mac mac(.clk(clk),.rst_n(rst_n),.load_acc(state==SEED),
        .in_valid(state==ISSUE),.a(op_a),.b(op_b),
        .init_acc(seeded ? seeds[out_idx] : 32'd0),.out_valid(mv),.acc(acc));
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;done<=0;error<=0;result_valid<=0;cycle_count<=0;mac_count<=0;
            v_loaded<=0;c_loaded<=0;b_loaded<=0;s_loaded<=0;p_loaded<=0;n_loaded<=0;
            seeded<=0;row<=0;col<=0;validate_row<=0;pos<=0;begin_pos<=0;end_pos<=0;
            op_a<=0;op_b<=0;nnz<=0;
        end else begin
            done<=0;
            if(busy)cycle_count<=cycle_count+1'b1;
            case(state)
            IDLE:begin
                if(start)begin
                    state<=CHECK;seeded<=seed_enable;row<=0;col<=0;validate_row<=0;
                    cycle_count<=0;mac_count<=0;error<=0;result_valid<=0;
                end else if(load_valid)begin
                    case(load_bank)
                    0:if(load_addr<16)begin values[load_addr]<=load_data[7:0];v_loaded[load_addr]<=1;end
                    1:if(load_addr<16)begin b_mem[load_addr]<=load_data[7:0];b_loaded[load_addr]<=1;end
                    2:if(load_addr<16)begin seeds[load_addr]<=load_data;s_loaded[load_addr]<=1;end
                    3:if(load_addr<16)begin columns[load_addr]<=load_data[1:0];c_loaded[load_addr]<=1;end
                    4:if(load_addr<5)begin pointers[load_addr]<=load_data[4:0];p_loaded[load_addr]<=1;end
                    5:if(load_addr==0)begin nnz<=load_data[4:0];n_loaded<=1;end
                    default:begin end
                    endcase
                end
            end
            CHECK:begin
                if(!(&b_loaded) || (seeded && !(&s_loaded)) || !(&p_loaded) || !n_loaded || nnz>16 || pointers[0]!=0 || pointers[4]!=nnz)state<=ERROR;
                else state<=VROW;
            end
            VROW:begin
                if(pointers[{1'b0,validate_row}]>pointers[{1'b0,validate_row}+3'd1] || pointers[{1'b0,validate_row}+3'd1]>nnz)state<=ERROR;
                else if(pointers[{1'b0,validate_row}]==pointers[{1'b0,validate_row}+3'd1])begin
                    if(validate_row==3)state<=ROW_LOAD;else begin validate_row<=validate_row+1'b1;state<=VROW;end
                end else begin
                    pos<=pointers[{1'b0,validate_row}];begin_pos<=pointers[{1'b0,validate_row}];
                    end_pos<=pointers[{1'b0,validate_row}+3'd1];state<=VENTRY;
                end
            end
            VENTRY:begin
                if(!v_loaded[pos[3:0]] || !c_loaded[pos[3:0]] || values[pos[3:0]]==0 ||
                    (pos!=begin_pos && columns[pos[3:0]]<=columns[(pos-5'd1)&5'h0f]))state<=ERROR;
                else if(pos+5'd1==end_pos)begin
                    if(validate_row==3)state<=ROW_LOAD;else begin validate_row<=validate_row+1'b1;state<=VROW;end
                end else pos<=pos+1'b1;
            end
            ROW_LOAD:begin begin_pos<=pointers[{1'b0,row}];end_pos<=pointers[{1'b0,row}+3'd1];state<=SEED;end
            SEED:begin pos<=begin_pos;if(begin_pos==end_pos)state<=WRITE_EMPTY;else state<=FETCH;end
            FETCH:begin op_a<=values[pos[3:0]];op_b<=b_mem[{columns[pos[3:0]],col}];state<=ISSUE;end
            ISSUE:begin mac_count<=mac_count+1'b1;if(pos+5'd1==end_pos)state<=DRAIN;else begin pos<=pos+1'b1;state<=FETCH;end end
            DRAIN:state<=WRITE;
            WRITE,WRITE_EMPTY:begin
                if(state==WRITE && !mv)state<=ERROR;
                else begin
                    c_mem[out_idx]<=acc;
                    if(col!=3)begin col<=col+1'b1;state<=SEED;end
                    else if(row!=3)begin row<=row+1'b1;col<=0;state<=ROW_LOAD;end
                    else state<=FINISH;
                end
            end
            FINISH:begin done<=1;result_valid<=1;state<=IDLE;end
            ERROR:begin done<=1;error<=1;result_valid<=0;state<=IDLE;end
            default:state<=ERROR;
            endcase
        end
    end
endmodule
