`timescale 1ns/1ps
module tb_matrix;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,start=0,seed_enable=0;
    reg dl=0,sl=0; reg [2:0] db=0,sb=0;
    reg [4:0] da=0,sa=0;reg [31:0] dd=0,sd=0;
    reg [3:0] ra=0;
    wire dr,sr,dbusy,sbusy,done_d,done_s,err_d,err_s,rv_d,rv_s;
    wire [31:0] rd_d,rd_s,cy_d,cy_s,ct_d,ct_s;
    wire [15:0] mc_d,mc_s;
    matrix_dense dense(.clk(clk),.rst_n(rst_n),.start(start),.seed_enable(seed_enable),
        .load_valid(dl),.load_ready(dr),.load_bank(db),.load_addr(da),.load_data(dd),
        .read_addr(ra),.read_data(rd_d),.busy(dbusy),.done(done_d),.error(err_d),
        .result_valid(rv_d),.cycle_count(cy_d),.mac_count(mc_d),.control_cycles(ct_d));
`ifdef WITH_CSR
    matrix_csr sparse(.clk(clk),.rst_n(rst_n),.start(start),.seed_enable(seed_enable),
        .load_valid(sl),.load_ready(sr),.load_bank(sb),.load_addr(sa),.load_data(sd),
        .read_addr(ra),.read_data(rd_s),.busy(sbusy),.done(done_s),.error(err_s),
        .result_valid(rv_s),.cycle_count(cy_s),.mac_count(mc_s),.control_cycles(ct_s));
`else
    assign sbusy=0;assign done_s=done_d;assign err_s=0;assign rv_s=1;
    assign cy_s=0;assign mc_s=0;assign ct_s=0;assign rd_s=0;assign sr=1;
`endif
    integer av[0:15],bv[0:15],vv[0:15],cc[0:15],pp[0:4];
    reg [31:0] seeds[0:15],expected[0:15];
    integer fd,csv,ncase,id,seeded,nnz,rc,i,j,idx,t,nonempty,dcycles,scycles,checks=0;
    integer dwords,swords,errors_checked=0,reset_checks=0;
    integer tb_cycle=0,d_first,d_last,s_first,s_last;
    always @(posedge clk)tb_cycle=tb_cycle+1;
    reg seen_d,seen_s;
    task tick;begin @(posedge clk);#1;end endtask
    task reset_all;begin
        @(negedge clk);rst_n=0;start=0;dl=0;sl=0;tick;
        if(dbusy || done_d || rv_d || cy_d || mc_d || rd_d) $fatal(1,"Dense reset status");
`ifdef WITH_CSR
        if(sbusy || done_s || rv_s || cy_s || mc_s || rd_s) $fatal(1,"CSR reset status");
`endif
        @(negedge clk);rst_n=1;reset_checks=reset_checks+1;
    end endtask
    task put(input integer which,bank,addr,input reg [31:0] data);
    begin
        @(negedge clk);
        if(which==0) begin if(!dr)$fatal(1,"dense load blocked");dl=1;db=bank;da=addr;dd=data;dwords=dwords+1;end
        else begin if(!sr)$fatal(1,"sparse load blocked");sl=1;sb=bank;sa=addr;sd=data;swords=swords+1;end
        tick;
        if(which==0)begin if(d_first<0)d_first=tb_cycle;d_last=tb_cycle;end
        else begin if(s_first<0)s_first=tb_cycle;s_last=tb_cycle;end
        @(negedge clk);dl=0;sl=0;
    end endtask
    task load_case;begin
        dwords=0;swords=0;d_first=-1;s_first=-1;d_last=-1;s_last=-1;
        for(j=0;j<16;j=j+1)begin put(0,0,j,av[j]);put(0,1,j,bv[j]);if(seeded)put(0,2,j,seeds[j]);end
`ifdef WITH_CSR
        for(j=0;j<16;j=j+1)begin put(1,1,j,bv[j]);if(seeded)put(1,2,j,seeds[j]);end
        for(j=0;j<nnz;j=j+1)begin put(1,0,j,vv[j]);put(1,3,j,cc[j]);end
        for(j=0;j<5;j=j+1)put(1,4,j,pp[j]);
        put(1,5,0,nnz);
`endif
    end endtask
    task launch;begin @(negedge clk);seed_enable=seeded;start=1;tick;
        if(!dbusy || rv_d || done_d)$fatal(1,"dense start");
        @(negedge clk);start=0;
    end endtask
    task run_case(input integer record_csv);begin
        launch;seen_d=0;seen_s=0;dcycles=0;scycles=0;t=0;
        while(!seen_d || !seen_s)begin
            tick;t=t+1;
            if(!rv_d && rd_d!==32'd0)$fatal(1,"invalid Dense output exposed");
`ifdef WITH_CSR
            if(!rv_s && rd_s!==32'd0)$fatal(1,"invalid CSR output exposed");
`endif
            if(done_d)begin seen_d=1;dcycles=t;if(err_d || !rv_d || cy_d!=t || mc_d!=64 || ct_d!=t-64)$fatal(1,"dense done/counters case %0d",id);end
`ifdef WITH_CSR
            if(done_s)begin seen_s=1;scycles=t;if(err_s || !rv_s || cy_s!=t || mc_s!=4*nnz || ct_s!=t-4*nnz)$fatal(1,"CSR done/counters case %0d",id);end
`else
            seen_s=seen_d;
`endif
            if(t>500)$fatal(1,"timeout");
            @(negedge clk);
            // Start and malicious writes during busy must be ignored; seed is latched.
            start=(t==2);dl=(t==2);sl=(t==2);db=0;sb=0;da=0;sa=0;dd=99;sd=99;seed_enable=!seeded;
            if(t==2 && (dr || !dbusy))$fatal(1,"busy load handshake");
        end
        start=0;dl=0;sl=0;
        nonempty=0;for(j=0;j<4;j=j+1)if(pp[j]!=pp[j+1])nonempty=nonempty+1;
        if(dcycles!=178)$fatal(1,"dense cycle prediction");
`ifdef WITH_CSR
        if(scycles!=42+9*nnz+4*nonempty)$fatal(1,"CSR cycle prediction actual=%0d nnz=%0d rows=%0d",scycles,nnz,nonempty);
`endif
        for(j=0;j<16;j=j+1)begin
            ra=j;#1;if(rd_d!==expected[j])$fatal(1,"dense case=%0d out=%0d got=%h expected=%h",id,j,rd_d,expected[j]);
`ifdef WITH_CSR
            if(rd_s!==expected[j] || rd_s!==rd_d)$fatal(1,"CSR case=%0d out=%0d got=%h expected=%h",id,j,rd_s,expected[j]);
`endif
            checks=checks+1;@(negedge clk);
        end
        tick;if(done_d || dbusy || !rv_d)$fatal(1,"done pulse/result hold");
`ifdef WITH_CSR
        if(done_s || sbusy || !rv_s)$fatal(1,"CSR done pulse/result hold");
`endif
        if(record_csv)$fwrite(csv,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",id,dcycles,scycles,mc_d,mc_s,dwords,swords,d_last-d_first+1,s_last-s_first+1);
    end endtask
    task reject_job;begin
        launch;seen_d=0;seen_s=0;t=0;
        while(!seen_d || !seen_s)begin tick;t=t+1;
            if(done_d)begin seen_d=1;if(!err_d || rv_d || mc_d!=0)$fatal(1,"dense missing-load rejection");end
            if(done_s)begin seen_s=1;
`ifdef WITH_CSR
                if(!err_s || rv_s || mc_s!=0)$fatal(1,"CSR malformed rejection");
`endif
            end
            if(t>100)$fatal(1,"reject timeout");
        end
        errors_checked=errors_checked+1;
    end endtask
    initial begin
        fd=$fopen("vectors.txt","r");csv=$fopen("performance.csv","w");
        if(!fd || !csv)$fatal(1,"file open");
        $fwrite(csv,"case_id,dense_cycles,csr_cycles,dense_macs,csr_macs,dense_load_writes,csr_load_writes,dense_tb_load_span,csr_tb_load_span\n");
        rc=$fscanf(fd,"%d",ncase);if(rc!=1)$fatal(1,"header parse");
        for(idx=0;idx<ncase;idx=idx+1)begin
            rc=$fscanf(fd,"%d %d %d",id,seeded,nnz);if(rc!=3)$fatal(1,"case parse");
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%d",av[i]);if(rc!=1)$fatal(1,"A parse");end
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%d",bv[i]);if(rc!=1)$fatal(1,"B parse");end
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%h",seeds[i]);if(rc!=1)$fatal(1,"seed parse");end
            for(i=0;i<5;i=i+1)begin rc=$fscanf(fd,"%d",pp[i]);if(rc!=1)$fatal(1,"ptr parse");end
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%d",vv[i]);if(rc!=1)$fatal(1,"val parse");end
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%d",cc[i]);if(rc!=1)$fatal(1,"col parse");end
            for(i=0;i<16;i=i+1)begin rc=$fscanf(fd,"%h",expected[i]);if(rc!=1)$fatal(1,"gold parse");end
            reset_all;load_case;run_case(1);
            if(idx<3)run_case(0); // Reuse stored inputs, fresh accumulation per job.
        end
        // Abort Dense exactly after its first ISSUE, with a product pending.
        reset_all;load_case;launch;repeat(4)tick;
`ifndef MAPPED
        if(!dense.mac.product_valid)$fatal(1,"dense reset stimulus has no pending product");
`endif
        reset_all;repeat(5)tick;
        if(done_d || dbusy || rv_d)$fatal(1,"reset abort");
        reject_job; // reset invalidated loaded masks
`ifdef WITH_CSR
        // Independently reach a pending CSR product (validation takes extra cycles).
        reset_all;load_case;launch;t=0;
        while(mc_s==0)begin tick;t=t+1;if(t>100)$fatal(1,"CSR pending-product stimulus");end
`ifndef MAPPED
        if(!sparse.mac.product_valid)$fatal(1,"CSR reset stimulus has no pending product");
`endif
        reset_all;repeat(5)tick;
        if(done_s || sbusy || rv_s)$fatal(1,"CSR reset abort");
        reject_job;
`endif
        // Missing one Dense A and one CSR value while otherwise correctly loaded.
        reset_all;
        for(i=0;i<16;i=i+1)begin if(i!=15)put(0,0,i,1);put(0,1,i,1);end
`ifdef WITH_CSR
        for(i=0;i<16;i=i+1)put(1,1,i,1);
        for(i=0;i<5;i=i+1)put(1,4,i,i==0 ? 0:1);
        put(1,5,0,1);put(1,3,0,0);
`endif
        seeded=0;reject_job;
`ifdef WITH_CSR
        // Each malformed case has complete B, plus intentional metadata defect.
        for(idx=0;idx<6;idx=idx+1)begin
            reset_all;
            for(i=0;i<16;i=i+1)put(1,1,i,1);
            put(1,5,0,idx==0 ? 17:2);
            for(i=0;i<5;i=i+1)put(1,4,i,i==0 ? 0:2);
            put(1,0,0,1);put(1,0,1,idx==1 ? 0:1);
            put(1,3,0,idx==3 ? 2:0);put(1,3,1,idx==2 ? 0:1);
            if(idx==4)put(1,4,2,1); // decreasing pointer
            if(idx==5)put(1,4,4,1); // final pointer != nnz
            reject_job;
        end
`endif
        $fclose(fd);$fclose(csv);
        $display("PASS MATRIX cases=%0d output_checks=%0d rejection_checks=%0d resets=%0d",ncase,checks,errors_checked,reset_checks);
        $finish;
    end
    initial begin #20000000;$fatal(1,"global watchdog");end
endmodule
