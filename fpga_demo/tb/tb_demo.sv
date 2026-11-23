`timescale 1ns/1ps
module tb_demo;
    reg clk=0;always #5 clk=~clk;
    reg reset_n=0,start_n=1;reg [3:0] sw=0,addr=0;
    wire [3:0] led;wire busy,done,pass,fail,done_pulse;
    wire [1:0] selected;wire [31:0] dc,sc,total,dd,sd;
    wire [15:0] dm,sm,dl,sl;
    wire [3:0] board_led;
    reg compare_wrapper=1;
    demo_sockit_top #(.DEBOUNCE_CYCLES(4),.CLOCK_HZ(16)) board_wrapper(
        .OSC_50_B5B(clk),.KEY({start_n,reset_n}),.SW(sw),.LED(board_led));
    demo_top #(.DEBOUNCE_CYCLES(4),.CLOCK_HZ(16)) dut(
        .clk(clk),.reset_n_async(reset_n),.start_n_async(start_n),.sw_async(sw),.debug_addr(addr),.led(led),
        .busy(busy),.done(done),.pass(pass),.fail(fail),.done_pulse(done_pulse),.selected_mode(selected),
        .dense_cycles(dc),.csr_cycles(sc),.total_cycles(total),.dense_macs(dm),.csr_macs(sm),
        .dense_loads(dl),.csr_loads(sl),.dense_data(dd),.csr_data(sd));
    integer nnz[0:3],rows[0:3],dwords[0:3],swords[0:3];
    reg [31:0] expected[0:63],dvect[0:127],svect[0:215];
    integer dbank[0:127],daddr[0:127],sbank[0:215],saddr[0:215];
    integer cycle=0,engine_edge=-1,accept_edge=-1,nd=0,ns=0,obs_d=0,obs_s=0;
    integer fd,csv,rc,m,n,i,j,k,bank,location,runs=0,checks=0,negative=0,aborts=0;
    reg [31:0] word;
    reg previous_pulse=0;
    // Independent edge/handshake monitor: compare every accepted loader word.
    always @(posedge clk)begin
        cycle=cycle+1;
        if(!dut.core.engine_rst_n)begin nd=0;ns=0;engine_edge=-1;obs_d=0;obs_s=0;end
        else begin
            if(dut.core.dv && dut.core.dr)begin
                k=selected*32+nd;
                if(nd>=dwords[selected] || dut.core.dbank!==dbank[k] || dut.core.daddr!==daddr[k] || dut.core.dw!==dvect[k])$fatal(1,"Dense loader word mode=%0d idx=%0d",selected,nd);
                nd=nd+1;
            end
            if(dut.core.sv && dut.core.sr)begin
                k=selected*54+ns;
                if(ns>=swords[selected] || dut.core.sbank!==sbank[k] || dut.core.saddr!==saddr[k] || dut.core.sw!==svect[k])$fatal(1,"CSR loader word mode=%0d idx=%0d",selected,ns);
                ns=ns+1;
            end
            if(dut.core.engine_start)begin
                if(nd!=32 || ns!=swords[selected])$fatal(1,"launch before all loads");
                engine_edge=cycle;
            end
        end
        if(dut.rst_n && dut.start_pulse && !busy)accept_edge=cycle;
        #1;
        if(dut.core.ddone)begin obs_d=cycle-engine_edge;if(dut.core.dcy!=obs_d)$fatal(1,"Dense cycle monitor");end
        if(dut.core.sdone)begin obs_s=cycle-engine_edge;if(dut.core.scy!=obs_s)$fatal(1,"CSR cycle monitor");end
        if(done_pulse)begin
            if(previous_pulse || busy || total!=cycle-accept_edge)$fatal(1,"demo completion timing");
        end
        previous_pulse=done_pulse;
        if(dut.rst_n && compare_wrapper && board_led!==led)$fatal(1,"narrow board wrapper differs from debug top");
    end
    task tick;begin @(posedge clk);#2;end endtask
    task reset_demo(input integer held);begin
        @(negedge clk);reset_n=0;start_n=!held;sw=0;
        repeat(3)tick;
        if(busy || done || pass || fail || total || dl || sl)$fatal(1,"reset status");
        @(negedge clk);reset_n=1;repeat(12)tick;
    end endtask
    task release_button;begin @(negedge clk);start_n=1;repeat(10)tick;end endtask
    task launch(input integer mode);begin
        release_button;@(negedge clk);sw=mode;repeat(5)tick;
        @(negedge clk);start_n=0;
        n=0;while(!busy)begin tick;n=n+1;if(n>30)$fatal(1,"start not accepted");end
        if(done || pass || fail || selected!=mode)$fatal(1,"new-job status/mode");
    end endtask
    task finish_check(input integer mode,input integer expect_fail);begin
        n=0;while(!done_pulse)begin tick;n=n+1;if(n>1400)$fatal(1,"demo timeout");end
        if(!done || busy || fail!=expect_fail || pass==expect_fail)$fatal(1,"PASS/FAIL publication");
        if(!expect_fail)begin
            if(dc!=obs_d || sc!=obs_s || dc!=178 || sc!=42+9*nnz[mode]+4*rows[mode] || dm!=64 || sm!=4*nnz[mode])$fatal(1,"captured compute counters");
            if(dl!=nd || sl!=ns || dl!=32 || sl!=22+2*nnz[mode])$fatal(1,"captured loader counts");
            for(j=0;j<16;j=j+1)begin
                @(negedge clk);addr=j;#1;
                if(dd!==expected[16*mode+j] || sd!==expected[16*mode+j])$fatal(1,"Golden mismatch mode=%0d addr=%0d D=%h S=%h E=%h",mode,j,dd,sd,expected[16*mode+j]);
                checks=checks+1;
            end
            $fwrite(csv,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",mode,total,dc,sc,dm,sm,dl,sl);runs=runs+1;
        end else negative=negative+1;
        @(negedge clk);sw[3:2]=0;repeat(4)tick;
        if(led!={fail,pass,done,1'b0})$fatal(1,"status LEDs");
        repeat(20)tick;if(busy || !done || done_pulse)$fatal(1,"held button repeated or status lost");
    end endtask
    initial begin
        fd=$fopen("tb_vectors.txt","r");csv=$fopen("performance.csv","w");
        if(!fd || !csv)$fatal(1,"file open");
        $fwrite(csv,"mode,demo_total_cycles,dense_cycles,csr_cycles,dense_macs,csr_macs,dense_loads,csr_loads\n");
        for(m=0;m<4;m=m+1)begin
            rc=$fscanf(fd,"%d %d %d %d %d",i,nnz[m],rows[m],dwords[m],swords[m]);if(rc!=5 || i!=m)$fatal(1,"header parse");
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%h",expected[16*m+i]);if(rc!=1)$fatal(1,"gold parse");end
            for(i=0;i<dwords[m];i=i+1)begin rc=$fscanf(fd,"%d %d %h",dbank[32*m+i],daddr[32*m+i],dvect[32*m+i]);if(rc!=3)$fatal(1,"dense parse");end
            for(i=0;i<swords[m];i=i+1)begin rc=$fscanf(fd,"%d %d %h",sbank[54*m+i],saddr[54*m+i],svect[54*m+i]);if(rc!=3)$fatal(1,"CSR parse");end
        end
        $fclose(fd);
        reset_demo(1);repeat(12)tick;if(busy)$fatal(1,"reset-held start was accepted");
        release_button;
        // Short press bounce must not trigger, then all modes and repeated jobs.
        repeat(3)begin @(negedge clk);start_n=0;tick;@(negedge clk);start_n=1;tick;end
        repeat(10)tick;if(busy || done)$fatal(1,"bounce triggered job");
        for(m=0;m<4;m=m+1)begin
            launch(m);
            // Hold start, change mode while busy; the accepted workload is immutable.
            @(negedge clk);sw[1:0]=3-m;
            finish_check(m,0);
            if(selected!=m)$fatal(1,"busy selection changed");
            launch(m);finish_check(m,0);
        end
        // A fresh qualified press while busy must not queue another job.
        launch(2);release_button;@(negedge clk);start_n=0;repeat(10)tick;
        finish_check(2,0);
        // Independent loader hold under an injected ready stall.
        launch(3);wait(dut.core.state==2);@(negedge clk);
        force dut.core.dr=0;repeat(3)tick;release dut.core.dr;
        finish_check(3,0);
        // All eight nibble positions of each counter page are visible.
        for(m=1;m<4;m=m+1)begin
            @(negedge clk);sw[3:2]=m;repeat(4)tick;
            for(i=0;i<140;i=i+1)begin tick;
                case(m)1:word=dc;2:word=sc;3:word={sm,dm};endcase
                if(led!==((word >> (4*dut.display.nibble)) & 15))$fatal(1,"counter display");
            end
        end
        // Reset abort at loading, computing, and comparison.
        for(m=2;m<=5;m=m+1)begin
            if(m!=3)begin launch(3);wait(dut.core.state==m);reset_demo(0);
                repeat(20)tick;if(done || busy || pass || fail)$fatal(1,"late completion after reset");aborts=aborts+1;end
        end
        // Simulation-only wire fault proves that comparison failure reaches LEDs.
        launch(1);compare_wrapper=0;wait(dut.core.state==5);@(negedge clk);
        force dut.core.ddata=32'hbad0bad0;tick;release dut.core.ddata;
        finish_check(1,1);
        // Missing completion pulse exercises watchdog FAIL (no fake success).
        launch(0);force dut.core.sdone=0;finish_check(0,1);release dut.core.sdone;
        launch(0);compare_wrapper=1;finish_check(0,0);
        $fclose(csv);
        $display("PASS DEMO successful_runs=%0d output_pairs=%0d negative_runs=%0d reset_aborts=%0d",runs,checks,negative,aborts);
        $finish;
    end
    initial begin #1000000;$fatal(1,"global watchdog");end
endmodule
