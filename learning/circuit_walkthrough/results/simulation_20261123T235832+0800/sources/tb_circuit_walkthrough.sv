`timescale 1ns/1ps
// Teaching-only self-checking TB. All synthesizable cores are unchanged copies.
module tb_circuit_walkthrough;
  reg clk=0; always #10 clk=~clk;
  reg rst_n=0, load_acc=0, in_valid=0;
  reg signed [7:0] a=0,b=0;
  reg [31:0] init_acc=0;
  wire out_valid; wire [31:0] acc;
  matrix_mac mac(.clk(clk),.rst_n(rst_n),.load_acc(load_acc),.in_valid(in_valid),
    .a(a),.b(b),.init_acc(init_acc),.out_valid(out_valid),.acc(acc));
  reg start=0,dl=0,sl=0; reg [2:0] bank=0; reg [4:0] addr=0;
  reg [31:0] data=0; reg [3:0] ra=0;
  wire dr,sr,db,sb,dd,sd,de,se,drv,srv;
  wire [31:0] dout,sout,dc,sc,dctl,sctl; wire [15:0] dm,sm;
  matrix_dense_memce dense(.clk(clk),.rst_n(rst_n),.start(start),.seed_enable(1'b0),
    .load_valid(dl),.load_ready(dr),.load_bank(bank),.load_addr(addr),.load_data(data),
    .read_addr(ra),.read_data(dout),.busy(db),.done(dd),.error(de),.result_valid(drv),
    .cycle_count(dc),.mac_count(dm),.control_cycles(dctl));
  matrix_csr sparse(.clk(clk),.rst_n(rst_n),.start(start),.seed_enable(1'b0),
    .load_valid(sl),.load_ready(sr),.load_bank(bank),.load_addr(addr),.load_data(data),
    .read_addr(ra),.read_data(sout),.busy(sb),.done(sd),.error(se),.result_valid(srv),
    .cycle_count(sc),.mac_count(sm),.control_cycles(sctl));
  integer mt,et,fd,rc,eng,ib,ia,i,timeout,checks=0; reg [31:0] word;
  reg [31:0] expected[0:15]; reg seen_d=0,seen_s=0;
  always @(posedge clk) begin
    #1;
    $fwrite(mt,"%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",$time,rst_n,load_acc,in_valid,a,b,mac.product_q,mac.product_valid,out_valid,$signed(acc));
    $fwrite(et,"%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",$time,start,dense.state,sparse.state,dense.read_operands,dense.op_a,dense.op_b,dense.mac.product_q,$signed(dense.acc),sparse.op_a,sparse.op_b,sparse.mac.product_q,$signed(sparse.acc),dd,sd,dm,sm);
    if(dd)seen_d=1;
    if(sd)seen_s=1;
  end
  task step;
    input reset_value,load_value,valid_value;
    input signed [7:0] av,bv;
    input [31:0] seed_value,expected_acc;
    input expected_valid;
    begin
      @(negedge clk);rst_n=reset_value;load_acc=load_value;in_valid=valid_value;
      a=av;b=bv;init_acc=seed_value;
      @(posedge clk);#2;
      if(acc!==expected_acc || out_valid!==expected_valid)
        $fatal(1,"MAC mismatch check=%0d acc=%h valid=%b",checks,acc,out_valid);
      checks=checks+1;
    end
  endtask
  initial begin
    mt=$fopen("mac_trace.csv","w");et=$fopen("engine_trace.csv","w");
    $fwrite(mt,"time_ps,rst_n,load_acc,in_valid,a,b,product_q,product_valid,out_valid,acc\n");
    $fwrite(et,"time_ps,start,dense_state,csr_state,dense_read_enable,dense_a,dense_b,dense_product,dense_acc,csr_a,csr_b,csr_product,csr_acc,dense_done,csr_done,dense_mac,csr_mac\n");
    $dumpfile("circuit_trace.vcd");$dumpvars(0,tb_circuit_walkthrough);
    step(0,0,0,0,0,0,0,0);
    step(1,0,1,3,5,0,0,0);
    step(1,0,1,0,-7,0,15,1);
    step(1,0,1,-2,4,0,15,1);
    step(1,0,0,0,0,0,-8+15,1);
    step(1,0,0,0,0,0,7,0);
    step(1,1,0,0,0,32'h7fffffff,32'h7fffffff,0);
    step(1,0,1,1,1,0,32'h7fffffff,0);
    step(1,0,0,0,0,0,32'h80000000,1);
    step(1,0,1,9,9,0,32'h80000000,0);
    step(1,1,1,2,2,0,0,0); // Flush pending81 and reject coincident4.
    step(1,0,0,0,0,0,0,0);
    $readmemh("expected.hex",expected);
    fd=$fopen("loads.txt","r");
    while(!$feof(fd))begin
      rc=$fscanf(fd,"%d %d %d %h\n",eng,ib,ia,word);
      if(rc==4)begin
        @(negedge clk);if(!dr || !sr)$fatal(1,"Loader not ready");
        bank=ib;addr=ia;data=word;dl=(eng==0);sl=(eng==1);
        @(posedge clk);#2;
      end
    end
    $fclose(fd);
    @(negedge clk);dl=0;sl=0;start=1;
    @(posedge clk);#2;
    @(negedge clk);start=0;
    timeout=0;
    while(!(seen_d && seen_s) && timeout<1000)begin @(posedge clk);#2;timeout=timeout+1;end
    if(timeout>=1000 || de || se || !drv || !srv)$fatal(1,"Engine failed or timed out");
    if(dm!=64 || sm!=16)$fatal(1,"Incorrect MAC counts dense=%0d csr=%0d",dm,sm);
    for(i=0;i<16;i=i+1)begin
      @(negedge clk);ra=i;#2;
      if(dout!==expected[i] || sout!==expected[i])$fatal(1,"Matrix mismatch at %0d",i);
      $display("RESULT i=%0d dense=%0d csr=%0d golden=%0d",i,$signed(dout),$signed(sout),$signed(expected[i]));
    end
    $display("COUNTERS dense_cycles=%0d csr_cycles=%0d dense_mac=%0d csr_mac=%0d",dc,sc,dm,sm);
    $display("PASS_CIRCUIT_WALKTHROUGH mac_checks=%0d matrix_outputs=32",checks);
    $fclose(mt);$fclose(et);$finish;
  end
endmodule
