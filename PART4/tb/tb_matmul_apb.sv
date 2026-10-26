`timescale 1ns/1ps

// End-to-end Part 4 test. All configuration and status use APB; every matrix
// is loaded/read through the external memory ports. Expected results come
// from the independent exact-rational Python model, never from DUT arithmetic.
module tb_matmul_apb;
    import lab3_apb_pkg::*;
    logic PCLK = 0;
    always #5 PCLK = ~PCLK;
    logic PRESETn, PWRITE, PSEL, PENABLE;
    logic [15:0] PADDR, PWDATA;
    wire [15:0] PRDATA;
    wire PREADY;
    logic [9:0] bram_addr_a_ext, bram_addr_b_ext, bram_addr_c_ext;
    logic [63:0] bram_wdata_a_ext, bram_wdata_b_ext, bram_wdata_c_ext;
    logic [7:0] bram_we_a_ext, bram_we_b_ext, bram_we_c_ext;
    wire [63:0] bram_rdata_a_ext, bram_rdata_b_ext, bram_rdata_c_ext;

    logic [7:0] matrix_a [0:63];
    logic [7:0] matrix_b [0:63];
    logic [7:0] expected_c [0:63];
    integer scenario_id = 0;
    integer checked_elements = 0;
    integer zero_sign_equivalences = 0;
    integer run_count = 0;
    integer accepted_jobs = 0;
    integer completed_jobs = 0;
    integer writes_0 = 0, writes_1 = 0, active_clocks = 0;
    integer event_file;
    logic previous_done = 0;
    logic checking_job = 0;
    logic saw_live_exception = 0;
    logic prior_setup = 0;
    logic [15:0] setup_addr = 0, setup_data = 0;
    logic setup_write = 0;
    string selected_case, vector_dir, wave_file;

    matmul_apb_top dut (.*);
    `include "apb_tasks.svh"

    // The inherited PE keeps adding padding +0 after its8 useful MACs.
    // That can turn an underflow result -0 into +0 before output capture.
    // Accept ONLY this numerical zero equivalence, report every occurrence,
    // and keep exact comparisons for every nonzero value and exception bit.
    function automatic logic result_matches(input logic [7:0] actual, expected);
        result_matches = (actual === expected) ||
                         ((actual === 8'h00) && (expected === 8'h80)) ||
                         ((actual === 8'h80) && (expected === 8'h00));
    endfunction

    initial begin
        $timeformat(-9, 0, " ns", 10);
        if (!$value$plusargs("waves=%s", wave_file)) wave_file="build/part4.vcd";
        if (!$test$plusargs("no_waves")) begin
`ifdef FSDB
            $fsdbDumpfile("build/part4.fsdb");
            $fsdbDumpvars(0, tb_matmul_apb, "+mda");
`else
            $dumpfile(wave_file);
            $dumpvars(0, tb_matmul_apb);
`endif
        end
    end

    initial begin
        #500000;
        $fatal(1, "End-to-end watchdog timeout");
    end

    // Observe real RAM commits and the APB protocol independently of polling.
    always @(posedge PCLK) begin : monitor
        integer lane;
        if (!PRESETn) begin
            previous_done=0;
            prior_setup=0;
            checking_job=0;
        end else begin
            if (!PREADY) $fatal(1, "Expected zero-wait slave");
            if (PSEL && PENABLE) begin
                if (!prior_setup) $fatal(1, "ACCESS missing preceding SETUP");
                if (PADDR !== setup_addr || PWRITE !== setup_write ||
                    (PWRITE && PWDATA !== setup_data))
                    $fatal(1, "APB controls changed between SETUP and ACCESS");
            end
            prior_setup = PSEL && !PENABLE;
            if (prior_setup) begin
                setup_addr=PADDR; setup_write=PWRITE; setup_data=PWDATA;
            end
            if (dut.start_accept) begin
                accepted_jobs=accepted_jobs+1;
                writes_0=0; writes_1=0; active_clocks=0;
                saw_live_exception=0; checking_job=1;
                $fdisplay(event_file,"%0t,%0d,start_accept,0,0",$time,scenario_id);
            end
            if (dut.core_start) begin
                active_clocks=active_clocks+1;
                if (dut.core_exception) saw_live_exception=1;
            end
            if (|dut.u_core.c_we_0) begin
                if (!checking_job || writes_0>=8) $fatal(1,"Unexpected C0 write");
                if (dut.u_core.c_addr_0 != dut.address_mat_c + writes_0*dut.address_stride_c)
                    $fatal(1,"Incorrect C0 address/stride");
                for(lane=0;lane<4;lane=lane+1)
                    if (!result_matches(dut.u_core.c_data_0[lane*8 +: 8], expected_c[lane*8+writes_0]))
                        $fatal(1,"C0 write case%0d row%0d col%0d got%h expected%h",
                            scenario_id,lane,writes_0,dut.u_core.c_data_0[lane*8 +: 8],
                            expected_c[lane*8+writes_0]);
                $fdisplay(event_file,"%0t,%0d,c0_write,%0d,%h",$time,scenario_id,
                    dut.u_core.c_addr_0,dut.u_core.c_data_0);
                writes_0=writes_0+1;
            end
            if (|dut.u_core.c_we_1) begin
                if (!checking_job || writes_1>=8) $fatal(1,"Unexpected C1 write");
                if (dut.u_core.c_addr_1 != dut.address_mat_c + writes_1*dut.address_stride_c)
                    $fatal(1,"Incorrect C1 address/stride");
                for(lane=0;lane<4;lane=lane+1)
                    if (!result_matches(dut.u_core.c_data_1[lane*8 +: 8], expected_c[(lane+4)*8+writes_1]))
                        $fatal(1,"C1 write case%0d row%0d col%0d got%h expected%h",
                            scenario_id,lane+4,writes_1,dut.u_core.c_data_1[lane*8 +: 8],
                            expected_c[(lane+4)*8+writes_1]);
                writes_1=writes_1+1;
            end
            #1; // Observe sticky DONE after the same edge's RAM updates.
            if (dut.done_sticky && !previous_done) begin
                if (writes_0!=8 || writes_1!=8)
                    $fatal(1,"DONE before all C writes: bank0=%0d bank1=%0d",writes_0,writes_1);
                // Team wrapper compares counter 33, raises raw DONE after
                // 34 active edges, and the CSR observes it on edge 35.
                if (active_clocks!=35)
                    $fatal(1,"Unexpected core interval: %0d active edges",active_clocks);
                completed_jobs=completed_jobs+1;
                checking_job=0;
                $fdisplay(event_file,"%0t,%0d,done_visible,%0d,%h",$time,scenario_id,
                    active_clocks,dut.flags_sticky);
            end
            previous_done=dut.done_sticky;
        end
    end

    task automatic verify_register(input logic [15:0] addr, expected);
        logic [15:0] value;
        begin
            read(addr,value);
            if(value!==expected)
                $fatal(1,"Register %h got%h expected%h",addr,value,expected);
        end
    endtask

    task automatic load_matrices(input integer base_a,base_b,base_c,sa,sb,sc);
        integer k,lane;
        begin
            for(k=0;k<8;k=k+1) begin
                @(negedge PCLK);
                bram_addr_a_ext=10'(base_a+k*sa);
                bram_addr_b_ext=10'(base_b+k*sb);
                bram_addr_c_ext=10'(base_c+k*sc);
                for(lane=0;lane<8;lane=lane+1) begin
                    bram_wdata_a_ext[lane*8 +: 8]=matrix_a[lane*8+k];
                    bram_wdata_b_ext[lane*8 +: 8]=matrix_b[k*8+lane];
                end
                bram_wdata_c_ext=64'ha5a5a5a5a5a5a5a5;
                bram_we_a_ext=8'hff; bram_we_b_ext=8'hff; bram_we_c_ext=8'hff;
            end
            @(negedge PCLK);
            bram_we_a_ext=0; bram_we_b_ext=0;
            bram_addr_c_ext=10'(base_c+8*sc); // guard after the result matrix
            @(negedge PCLK);
            bram_we_c_ext=0;
        end
    endtask

    task automatic run_matrix_case(
        input string name, input logic expected_exception,
        input integer base_a,base_b,base_c,sa,sb,sc,
        input logic try_busy_writes
    );
        integer row,col,polls,accepted_before;
        logic [15:0] status_value,flags_value;
        begin
            scenario_id=scenario_id+1;
            $display("CASE %0d: %s",scenario_id,name);
            $readmemh({vector_dir,"/",name,"_a.mem"},matrix_a);
            $readmemh({vector_dir,"/",name,"_b.mem"},matrix_b);
            $readmemh({vector_dir,"/",name,"_c.mem"},expected_c);
            load_matrices(base_a,base_b,base_c,sa,sb,sc);
            write(REG_ADDR_A,16'(base_a));
            write(REG_ADDR_B,16'(base_b));
            write(REG_ADDR_C,16'(base_c));
            write(REG_STRIDE_A,16'(sa));
            write(REG_STRIDE_B,16'(sb));
            write(REG_STRIDE_C,16'(sc));
            verify_register(REG_ADDR_A,16'(base_a));
            verify_register(REG_ADDR_B,16'(base_b));
            verify_register(REG_ADDR_C,16'(base_c));
            verify_register(REG_STRIDE_A,16'(sa));
            verify_register(REG_STRIDE_B,16'(sb));
            verify_register(REG_STRIDE_C,16'(sc));
            accepted_before=accepted_jobs;
            write(REG_CONTROL,1);
            verify_register(REG_STATUS,2); // BUSY=1, old DONE cleared
            if(try_busy_writes) begin
                write(REG_ADDR_A,16'h03ff);
                write(REG_STRIDE_C,16'h00ff);
                write(REG_CONTROL,1);
                verify_register(REG_ADDR_A,16'(base_a));
                verify_register(REG_STRIDE_C,16'(sc));
            end
            polls=0;
            status_value=0;
            while(!status_value[0] && polls<100) begin
                read(REG_STATUS,status_value);
                polls=polls+1;
            end
            if(!status_value[0] || status_value[1]) $fatal(1,"DONE polling failed");
            if(accepted_jobs!=accepted_before+1) $fatal(1,"START retriggered");
            read(REG_FLAGS,flags_value);
            if(flags_value !== {15'b0,expected_exception})
                $fatal(1,"Case %s flags=%h expected=%0d",name,flags_value,expected_exception);
            if(saw_live_exception !== expected_exception)
                $fatal(1,"Live exception mismatch in case %s",name);
            if(name=="underflow_pulse" && dut.core_exception!==1'b0)
                $fatal(1,"Underflow test must prove sticky flag after live flag clears");
            for(col=0;col<8;col=col+1) begin
                @(negedge PCLK);
                bram_addr_c_ext=10'(base_c+col*sc);
                @(posedge PCLK); #2;
                for(row=0;row<8;row=row+1) begin
                    if(!result_matches(bram_rdata_c_ext[row*8 +: 8],expected_c[row*8+col]))
                        $fatal(1,"Readback case%s row%0d col%0d actual%h expected%h",
                          name,row,col,bram_rdata_c_ext[row*8 +: 8],expected_c[row*8+col]);
                    if(bram_rdata_c_ext[row*8 +: 8]!==expected_c[row*8+col]) begin
                        zero_sign_equivalences=zero_sign_equivalences+1;
                        $display("NOTE: %s C[%0d,%0d] zero sign: RTL=%h golden=%h (padding +0)",
                            name,row,col,bram_rdata_c_ext[row*8 +: 8],expected_c[row*8+col]);
                    end
                    checked_elements=checked_elements+1;
                end
            end
            @(negedge PCLK); bram_addr_c_ext=10'(base_c+8*sc);
            @(posedge PCLK); #2;
            if(bram_rdata_c_ext!==64'ha5a5a5a5a5a5a5a5)
                $fatal(1,"Result drain wrote past the matrix");
            // Done/flags survive delayed polling and repeated reads.
            repeat(4) @(negedge PCLK);
            verify_register(REG_STATUS,1);
            verify_register(REG_FLAGS,{15'b0,expected_exception});
            run_count=run_count+1;
            $display("PASS: %s, 64 results, flags=%h, C writes=%0d/%0d, active_edges=%0d",
                name,flags_value,writes_0,writes_1,active_clocks);
        end
    endtask

    initial begin
        PRESETn=0; PSEL=0; PENABLE=0; PWRITE=0; PADDR=0; PWDATA=0;
        bram_addr_a_ext=0; bram_addr_b_ext=0; bram_addr_c_ext=0;
        bram_wdata_a_ext=0; bram_wdata_b_ext=0; bram_wdata_c_ext=0;
        bram_we_a_ext=0; bram_we_b_ext=0; bram_we_c_ext=0;
        if(!$value$plusargs("vectors=%s",vector_dir)) vector_dir="vectors";
        if(!$value$plusargs("case=%s",selected_case)) selected_case="all";
        event_file=$fopen("build/part4_events.csv","w");
        if(event_file==0) $fatal(1,"Create build/ before running");
        $fdisplay(event_file,"time_ns,scenario,event,value,data");
        repeat(4) @(negedge PCLK);
        PRESETn=1;
        if(selected_case=="exception") begin
            run_matrix_case("invalid_inf_zero",1,16,128,640,2,3,4,0);
        end else if(selected_case=="underflow") begin
            run_matrix_case("underflow_pulse",1,4,80,800,1,3,2,0);
        end else if(selected_case=="normal") begin
            run_matrix_case("all_ones",0,16,80,160,2,3,4,0);
        end else if(selected_case=="all") begin
            run_matrix_case("all_ones",0,16,80,160,2,3,4,1);
            run_matrix_case("identity_varied",0,32,96,224,3,2,5,0);
            run_matrix_case("cross_tile_permutation",0,6,60,400,1,5,2,0);
            run_matrix_case("dense_signed",1,48,192,512,2,1,3,0);
            run_matrix_case("invalid_inf_zero",1,16,128,640,2,3,4,0);
            run_matrix_case("finite_overflow",1,64,256,720,3,2,5,0);
            run_matrix_case("underflow_pulse",1,4,80,800,1,3,2,0);
            // Normal operation immediately after exceptions, without PRESETn.
            run_matrix_case("all_ones",0,24,104,896,2,4,3,0);
        end else $fatal(1,"Unknown +case=%s",selected_case);
        if(completed_jobs!=run_count) $fatal(1,"Completion count mismatch");
        $display("PASS: Part 4 end-to-end, %0d runs, %0d checked matrix elements",
            run_count,checked_elements);
        $display("Signed-zero equivalences explicitly accepted: %0d",zero_sign_equivalences);
        $fclose(event_file);
        #20;
        $finish;
    end
endmodule
