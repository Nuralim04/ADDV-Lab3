// Adapted from the supplied PART2/TESTBENCH/example_tb.sv tasks.
// Drive on falling edges, sample PRDATA at the rising completion edge,
// wait for PREADY, and bound the wait so a broken slave cannot hang the test.
task automatic write(input logic [15:0] addr, input logic [15:0] data);
    integer wait_cycles;
    begin
        @(negedge PCLK);
        PSEL = 1'b1; PENABLE = 1'b0; PWRITE = 1'b1;
        PADDR = addr; PWDATA = data;
        @(negedge PCLK);
        PENABLE = 1'b1;
        wait_cycles = 0;
        do begin
            @(posedge PCLK);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 64) $fatal(1, "APB write timeout at %h", addr);
        end while (PREADY !== 1'b1);
        @(negedge PCLK);
        PSEL = 1'b0; PENABLE = 1'b0; PWRITE = 1'b0;
        PADDR = '0; PWDATA = '0;
        if ($test$plusargs("verbose"))
            $display("%0t APB WRITE address=%h data=%h", $time, addr, data);
    end
endtask

task automatic read(input logic [15:0] addr, output logic [15:0] data);
    integer wait_cycles;
    begin
        @(negedge PCLK);
        PSEL = 1'b1; PENABLE = 1'b0; PWRITE = 1'b0;
        PADDR = addr; PWDATA = '0;
        @(negedge PCLK);
        PENABLE = 1'b1;
        wait_cycles = 0;
        do begin
            @(posedge PCLK);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 64) $fatal(1, "APB read timeout at %h", addr);
        end while (PREADY !== 1'b1);
        data = PRDATA; // capture while PSEL/PENABLE and PADDR still valid
        @(negedge PCLK);
        PSEL = 1'b0; PENABLE = 1'b0; PWRITE = 1'b0;
        PADDR = '0;
        if ($test$plusargs("verbose"))
            $display("%0t APB READ  address=%h data=%h", $time, addr, data);
    end
endtask
