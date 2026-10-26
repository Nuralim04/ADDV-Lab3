`timescale 1ns/1ps
module tb_apb_matmul_csr;
    import lab3_apb_pkg::*;
    logic PCLK = 0;
    always #5 PCLK = ~PCLK;
    logic PRESETn, PWRITE, PSEL, PENABLE;
    logic [15:0] PADDR, PWDATA;
    wire [15:0] PRDATA;
    wire PREADY;
    logic core_done, core_exception;
    wire core_start, core_reset, busy, start_accept, done_sticky;
    wire [15:0] flags_sticky;
    wire [9:0] address_mat_a, address_mat_b, address_mat_c;
    wire [7:0] address_stride_a, address_stride_b, address_stride_c;
    integer checks = 0;
    integer accepted = 0;
    logic [15:0] value;

    apb_matmul_csr dut (.*);
    `include "apb_tasks.svh"

    task automatic check(input logic condition, input string description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) $fatal(1, "CSR CHECK FAILED: %s", description);
        end
    endtask

    task automatic expect_read(input logic [15:0] addr, expected);
        logic [15:0] actual;
        begin
            read(addr, actual);
            checks = checks + 1;
            if (actual !== expected)
                $fatal(1, "CSR %h actual=%h expected=%h", addr, actual, expected);
        end
    endtask

    always @(posedge PCLK) begin
        if (PRESETn && start_accept) accepted = accepted + 1;
    end

    initial begin
        #100000;
        $fatal(1, "CSR unit-test watchdog timeout");
    end

    initial begin
        PRESETn=0; PSEL=0; PENABLE=0; PWRITE=0; PADDR=0; PWDATA=0;
        core_done=0; core_exception=0;
        repeat (3) @(negedge PCLK);
        PRESETn=1;
        expect_read(REG_CONTROL, 0);
        expect_read(REG_STATUS, 0);
        expect_read(REG_FLAGS, 0);
        expect_read(REG_ADDR_A, 0);
        expect_read(REG_ADDR_B, 0);
        expect_read(REG_ADDR_C, 0);
        expect_read(REG_STRIDE_A, 1);
        expect_read(REG_STRIDE_B, 1);
        expect_read(REG_STRIDE_C, 1);
        check(PREADY, "slave is always ready");

        // Setup by itself must not mutate a register.
        @(negedge PCLK);
        PSEL=1; PENABLE=0; PWRITE=1; PADDR=REG_ADDR_A; PWDATA=16'h0055;
        @(posedge PCLK); #1;
        check(address_mat_a==0, "no write during SETUP");
        @(negedge PCLK); PSEL=0; PWRITE=0;
        // PENABLE may belong to another slave: PSEL must qualify the write.
        @(negedge PCLK);
        PENABLE=1; PWRITE=1; PADDR=REG_ADDR_A; PWDATA=16'h0055;
        @(posedge PCLK); #1;
        check(address_mat_a==0, "no write when unselected");
        @(negedge PCLK); PENABLE=0; PWRITE=0;

        write(REG_ADDR_A, 16'hfc25);
        write(REG_ADDR_B, 16'h0155);
        write(REG_ADDR_C, 16'h03a0);
        write(REG_STRIDE_A, 16'hff02);
        write(REG_STRIDE_B, 16'h0003);
        write(REG_STRIDE_C, 16'h0004);
        expect_read(REG_ADDR_A, 16'h0025);
        expect_read(REG_ADDR_B, 16'h0155);
        expect_read(REG_ADDR_C, 16'h03a0);
        expect_read(REG_STRIDE_A, 16'h0002);
        expect_read(REG_STRIDE_B, 16'h0003);
        expect_read(REG_STRIDE_C, 16'h0004);
        write(16'h0011, 16'hffff); // unaligned
        write(16'hfffe, 16'hffff); // unimplemented
        write(REG_STATUS, 16'hffff);
        write(REG_FLAGS, 16'hffff);
        expect_read(16'h0011, 0);
        expect_read(16'hfffe, 0);
        expect_read(REG_ADDR_A, 16'h0025);
        expect_read(REG_STATUS, 0);
        expect_read(REG_FLAGS, 0);

        // Consecutive writes and read, with PSEL held HIGH across all3.
        @(negedge PCLK);
        PSEL=1; PENABLE=0; PWRITE=1; PADDR=REG_ADDR_B; PWDATA=16'h0123;
        @(negedge PCLK); PENABLE=1;
        @(negedge PCLK);
        PENABLE=0; PADDR=REG_STRIDE_B; PWDATA=16'h0007;
        @(negedge PCLK); PENABLE=1;
        @(negedge PCLK);
        PENABLE=0; PWRITE=0; PADDR=REG_ADDR_B;
        @(negedge PCLK); PENABLE=1;
        @(posedge PCLK);
        check(PRDATA==16'h0123, "back-to-back read data before completion edge");
        @(negedge PCLK); PSEL=0; PENABLE=0; PADDR=0;
        expect_read(REG_STRIDE_B, 7);

        write(REG_CONTROL, 0);
        check(!busy && accepted==0, "writing zero does not start");
        @(negedge PCLK); core_exception=1;
        repeat(2) @(negedge PCLK);
        core_exception=0;
        expect_read(REG_FLAGS, 0);

        // Detailed START edge: one PREP reset edge, followed by held RUN.
        @(negedge PCLK);
        PSEL=1; PENABLE=0; PWRITE=1; PADDR=REG_CONTROL; PWDATA=1;
        @(negedge PCLK); PENABLE=1;
        @(posedge PCLK); #1;
        check(busy && core_reset && !core_start, "START enters PREP");
        @(negedge PCLK); PSEL=0; PENABLE=0; PWRITE=0;
        @(posedge PCLK); #1;
        check(busy && !core_reset && core_start, "PREP exits to held RUN");
        expect_read(REG_STATUS, 2);
        write(REG_ADDR_A, 16'h0000);
        write(REG_STRIDE_A, 16'h0009);
        write(REG_CONTROL, 1);
        check(accepted==1, "busy START cannot retrigger");
        expect_read(REG_ADDR_A, 16'h0025);
        expect_read(REG_STRIDE_A, 2);
        check(core_start, "run remains held across APB traffic");

        @(negedge PCLK); core_exception=1;
        @(negedge PCLK); core_exception=0;
        expect_read(REG_FLAGS, 1);
        @(negedge PCLK); core_done=1;
        @(posedge PCLK); #1;
        check(done_sticky && !busy && !core_start, "DONE stops run and latches status");
        @(negedge PCLK); core_done=0;
        repeat(5) @(negedge PCLK);
        expect_read(REG_STATUS, 1);
        expect_read(REG_FLAGS, 1);

        // New job clears old state; exceptions arriving with done are included.
        write(REG_CONTROL, 1);
        expect_read(REG_STATUS, 2);
        expect_read(REG_FLAGS, 0);
        @(negedge PCLK); core_done=1; core_exception=1;
        @(negedge PCLK); core_done=0; core_exception=0;
        expect_read(REG_STATUS, 1);
        expect_read(REG_FLAGS, 1);
        check(accepted==2, "two accepted starts");

        // Reset must abort an active run and restore all CSR defaults.
        write(REG_CONTROL, 1);
        @(negedge PCLK); PRESETn=0;
        #1;
        check(!busy && core_reset && !core_start, "reset aborts operation");
        @(negedge PCLK); PRESETn=1;
        expect_read(REG_STATUS, 0);
        expect_read(REG_FLAGS, 0);
        expect_read(REG_ADDR_A, 0);
        expect_read(REG_STRIDE_A, 1);
        $display("PASS: APB CSR unit test, %0d checks", checks);
        $finish;
    end
endmodule
