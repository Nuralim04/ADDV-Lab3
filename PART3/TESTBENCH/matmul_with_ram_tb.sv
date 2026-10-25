`timescale 1ns/1ns

module matmul_8x8_tb;

    logic clk;
    logic resetn;
    logic pe_resetn;
    logic start;

    wire done;
    wire exception;


    // ============================================================
    // External RAM interfaces
    // ============================================================

    logic [9:0]  bram_addr_a0_ext;
    logic [31:0] bram_wdata_a0_ext;
    logic [3:0]  bram_we_a0_ext;
    wire  [31:0] bram_rdata_a0_ext;

    logic [9:0]  bram_addr_a1_ext;
    logic [31:0] bram_wdata_a1_ext;
    logic [3:0]  bram_we_a1_ext;
    wire  [31:0] bram_rdata_a1_ext;

    logic [9:0]  bram_addr_b0_ext;
    logic [31:0] bram_wdata_b0_ext;
    logic [3:0]  bram_we_b0_ext;
    wire  [31:0] bram_rdata_b0_ext;

    logic [9:0]  bram_addr_b1_ext;
    logic [31:0] bram_wdata_b1_ext;
    logic [3:0]  bram_we_b1_ext;
    wire  [31:0] bram_rdata_b1_ext;

    logic [9:0]  bram_addr_c0_ext;
    logic [31:0] bram_wdata_c0_ext;
    logic [3:0]  bram_we_c0_ext;
    wire  [31:0] bram_rdata_c0_ext;

    logic [9:0]  bram_addr_c1_ext;
    logic [31:0] bram_wdata_c1_ext;
    logic [3:0]  bram_we_c1_ext;
    wire  [31:0] bram_rdata_c1_ext;


    // ============================================================
    // DUT
    // ============================================================

    matrix_multiplication u_matmul (

        .clk              (clk),
        .resetn           (resetn),
        .pe_resetn        (pe_resetn),

        .address_mat_a    (10'd0),
        .address_mat_b    (10'd0),
        .address_mat_c    (10'd0),

        .address_stride_a (8'd1),
        .address_stride_b (8'd1),
        .address_stride_c (8'd1),

        // A0
        .bram_addr_a0_ext  (bram_addr_a0_ext),
        .bram_rdata_a0_ext (bram_rdata_a0_ext),
        .bram_wdata_a0_ext (bram_wdata_a0_ext),
        .bram_we_a0_ext    (bram_we_a0_ext),

        // A1
        .bram_addr_a1_ext  (bram_addr_a1_ext),
        .bram_rdata_a1_ext (bram_rdata_a1_ext),
        .bram_wdata_a1_ext (bram_wdata_a1_ext),
        .bram_we_a1_ext    (bram_we_a1_ext),

        // B0
        .bram_addr_b0_ext  (bram_addr_b0_ext),
        .bram_rdata_b0_ext (bram_rdata_b0_ext),
        .bram_wdata_b0_ext (bram_wdata_b0_ext),
        .bram_we_b0_ext    (bram_we_b0_ext),

        // B1
        .bram_addr_b1_ext  (bram_addr_b1_ext),
        .bram_rdata_b1_ext (bram_rdata_b1_ext),
        .bram_wdata_b1_ext (bram_wdata_b1_ext),
        .bram_we_b1_ext    (bram_we_b1_ext),

        // C0
        .bram_addr_c0_ext  (bram_addr_c0_ext),
        .bram_rdata_c0_ext (bram_rdata_c0_ext),
        .bram_wdata_c0_ext (bram_wdata_c0_ext),
        .bram_we_c0_ext    (bram_we_c0_ext),

        // C1
        .bram_addr_c1_ext  (bram_addr_c1_ext),
        .bram_rdata_c1_ext (bram_rdata_c1_ext),
        .bram_wdata_c1_ext (bram_wdata_c1_ext),
        .bram_we_c1_ext    (bram_we_c1_ext),

        .start             (start),
        .done              (done),
        .exception         (exception)
    );


    // ============================================================
    // Clock
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end


    // ============================================================
    // Test variables
    // ============================================================

    integer i;
    integer errors;


    // ============================================================
    // Main test
    // ============================================================

    initial begin

        start     = 1'b0;
        resetn    = 1'b0;
        pe_resetn = 1'b0;

        errors = 0;


        // --------------------------------------------------------
        // Disable all external RAM writes
        // --------------------------------------------------------

        bram_addr_a0_ext  = '0;
        bram_wdata_a0_ext = '0;
        bram_we_a0_ext    = '0;

        bram_addr_a1_ext  = '0;
        bram_wdata_a1_ext = '0;
        bram_we_a1_ext    = '0;

        bram_addr_b0_ext  = '0;
        bram_wdata_b0_ext = '0;
        bram_we_b0_ext    = '0;

        bram_addr_b1_ext  = '0;
        bram_wdata_b1_ext = '0;
        bram_we_b1_ext    = '0;

        bram_addr_c0_ext  = '0;
        bram_wdata_c0_ext = '0;
        bram_we_c0_ext    = '0;

        bram_addr_c1_ext  = '0;
        bram_wdata_c1_ext = '0;
        bram_we_c1_ext    = '0;


        // ========================================================
        // TEST 1
        //
        // A = all 1.0
        // B = all 1.0
        //
        // FP8:
        // 1.0 = 8'h30
        //
        // C[i][j] = 8.0
        //
        // FP8:
        // 8.0 = 8'h60
        //
        // Expected C RAM word = 32'h60606060
        // ========================================================

        $display("");
        $display("============================================");
        $display("TEST 1: 8x8 ALL ONES x ALL ONES");
        $display("============================================");


        // --------------------------------------------------------
        // Initialize A RAMs
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            u_matmul.matrix_A0.ram[i] = 32'h30303030;
            u_matmul.matrix_A1.ram[i] = 32'h30303030;

        end


        // --------------------------------------------------------
        // Initialize B RAMs
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            u_matmul.matrix_B0.ram[i] = 32'h30303030;
            u_matmul.matrix_B1.ram[i] = 32'h30303030;

        end


        // --------------------------------------------------------
        // Clear C RAMs
        // --------------------------------------------------------

        for (i = 0; i < 16; i = i + 1) begin

            u_matmul.matrix_C0.ram[i] = 32'h00000000;
            u_matmul.matrix_C1.ram[i] = 32'h00000000;

        end


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        #55;

        resetn    = 1'b1;
        pe_resetn = 1'b1;

        #60;


        // --------------------------------------------------------
        // Start Test 1
        // --------------------------------------------------------

        $display(
            "[%0t] Starting 8x8 multiplication",
            $time
        );

        start = 1'b1;


        // --------------------------------------------------------
        // Wait for completion
        // --------------------------------------------------------

        @(posedge done);

        $display(
            "[%0t] done asserted",
            $time
        );

        start = 1'b0;

        // Allow final RAM write to settle.
        #60;


        // ========================================================
        // Exception check - Test 1
        // ========================================================

        if (exception !== 1'b0) begin

            $display(
                "ERROR: exception asserted during normal test"
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: No FP8 exception during normal test"
            );

        end


        // ========================================================
        // Display C RAM contents
        // ========================================================

        $display("");
        $display("============================================");
        $display("Matrix C RAM 0");
        $display("============================================");

        for (i = 0; i < 12; i = i + 1) begin

            $display(
                "C0[%0d] = %h",
                i,
                u_matmul.matrix_C0.ram[i]
            );

        end


        $display("");
        $display("============================================");
        $display("Matrix C RAM 1");
        $display("============================================");

        for (i = 0; i < 12; i = i + 1) begin

            $display(
                "C1[%0d] = %h",
                i,
                u_matmul.matrix_C1.ram[i]
            );

        end


        // ========================================================
        // Check Test 1 result
        // ========================================================

        $display("");
        $display("Checking expected output at addresses 0-7:");

        for (i = 0; i < 8; i = i + 1) begin

            if (u_matmul.matrix_C0.ram[i]
                !== 32'h60606060) begin

                $display(
                    "ERROR: C0[%0d] = %h, expected 60606060",
                    i,
                    u_matmul.matrix_C0.ram[i]
                );

                errors = errors + 1;

            end


            if (u_matmul.matrix_C1.ram[i]
                !== 32'h60606060) begin

                $display(
                    "ERROR: C1[%0d] = %h, expected 60606060",
                    i,
                    u_matmul.matrix_C1.ram[i]
                );

                errors = errors + 1;

            end

        end


        // ========================================================
        // Result for Test 1
        // ========================================================

        $display("");
        $display("============================================");

        if (errors == 0) begin

            $display(
                "PASS: test 1 all-ones matrix multiplication"
            );

        end
        else begin

            $display(
                "CURRENT CHECK: %0d error(s)",
                errors
            );

            $display(
                "Test 1 failed; expected output at C[0]-C[7]."
            );

        end

        $display("============================================");
        $display("");


        // ========================================================
        // RAM READBACK PHASE
        //
        // This phase is included specifically so the input and
        // output matrix contents can be shown clearly in Verdi.
        //
        // All six external RAM read addresses are swept from
        // address 0 through address 7.
        //
        // Expected during Test 1:
        //
        // A0/A1 = 30303030
        // B0/B1 = 30303030
        // C0/C1 = 60606060
        //
        // The RAM is synchronous, therefore each address is held
        // long enough for the corresponding q1 output to update.
        // ========================================================

        $display("");
        $display("============================================");
        $display("TEST 1 RAM READBACK FOR VERDI");
        $display("============================================");


        for (i = 0; i < 8; i = i + 1) begin

            // ----------------------------------------------------
            // Apply external read address to all six RAM banks
            // ----------------------------------------------------

            bram_addr_a0_ext = i;
            bram_addr_a1_ext = i;

            bram_addr_b0_ext = i;
            bram_addr_b1_ext = i;

            bram_addr_c0_ext = i;
            bram_addr_c1_ext = i;


            // ----------------------------------------------------
            // Wait for synchronous RAM read
            // ----------------------------------------------------

            @(posedge clk);

            // Small delay lets NBA-updated q1 signals settle
            // before printing the values.
            #1;


            // ----------------------------------------------------
            // Display readback values
            // ----------------------------------------------------

            $display(
                "ADDR %0d: A0=%h A1=%h B0=%h B1=%h C0=%h C1=%h",
                i,
                bram_rdata_a0_ext,
                bram_rdata_a1_ext,
                bram_rdata_b0_ext,
                bram_rdata_b1_ext,
                bram_rdata_c0_ext,
                bram_rdata_c1_ext
            );


            // Hold each address for another clock so the address
            // and corresponding data are easy to see in Verdi.
            @(posedge clk);

        end


        // --------------------------------------------------------
        // Return external addresses to zero
        // --------------------------------------------------------

        bram_addr_a0_ext = 10'd0;
        bram_addr_a1_ext = 10'd0;

        bram_addr_b0_ext = 10'd0;
        bram_addr_b1_ext = 10'd0;

        bram_addr_c0_ext = 10'd0;
        bram_addr_c1_ext = 10'd0;

        #40;


        // ========================================================
        // TEST 2
        //
        // A = all 0.5
        // B = all 1.0
        //
        // Expected:
        //
        // C[i][j] = 8 � 0.5 � 1.0
        //         = 4.0
        //
        // FP8:
        // 0.5 = 8'h20
        // 1.0 = 8'h30
        // 4.0 = 8'h50
        //
        // Expected C RAM word = 32'h50505050
        // ========================================================

        $display("");
        $display("============================================");
        $display("TEST 2: 8x8 ALL 0.5 x ALL 1.0");
        $display("============================================");


        // Reset before Test 2
        start     = 1'b0;
        resetn    = 1'b0;
        pe_resetn = 1'b0;


        // --------------------------------------------------------
        // Initialize Test 2 RAM contents
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            u_matmul.matrix_A0.ram[i] = 32'h20202020;
            u_matmul.matrix_A1.ram[i] = 32'h20202020;

            u_matmul.matrix_B0.ram[i] = 32'h30303030;
            u_matmul.matrix_B1.ram[i] = 32'h30303030;

            u_matmul.matrix_C0.ram[i] = 32'h00000000;
            u_matmul.matrix_C1.ram[i] = 32'h00000000;

        end


        // --------------------------------------------------------
        // Reset release
        // --------------------------------------------------------

        #55;

        resetn    = 1'b1;
        pe_resetn = 1'b1;

        #60;


        // --------------------------------------------------------
        // Start Test 2
        // --------------------------------------------------------

        start = 1'b1;

        @(posedge done);

        start = 1'b0;

        #60;


        // ========================================================
        // Exception check - Test 2
        // ========================================================

        if (exception !== 1'b0) begin

            $display(
                "ERROR: exception asserted during test 2"
            );

            errors = errors + 1;

        end


        // ========================================================
        // Check Test 2 results
        // ========================================================

        for (i = 0; i < 8; i = i + 1) begin

            if (u_matmul.matrix_C0.ram[i]
                !== 32'h50505050) begin

                $display(
                    "ERROR: TEST 2 C0[%0d] = %h, expected 50505050",
                    i,
                    u_matmul.matrix_C0.ram[i]
                );

                errors = errors + 1;

            end


            if (u_matmul.matrix_C1.ram[i]
                !== 32'h50505050) begin

                $display(
                    "ERROR: TEST 2 C1[%0d] = %h, expected 50505050",
                    i,
                    u_matmul.matrix_C1.ram[i]
                );

                errors = errors + 1;

            end

        end


        // ========================================================
        // Final result
        // ========================================================

        $display("");

        if (errors == 0) begin

            $display(
                "PASS: both 8x8 matrix multiplication tests"
            );

        end
        else begin

            $display(
                "FAIL: %0d total error(s) across both tests",
                errors
            );

            $fatal(
                1,
                "Part 3 simulation failed"
            );

        end


        #100;
        $finish;

    end


    // ============================================================
    // Timeout
    //
    // Increased slightly because the Test 1 readback phase adds
    // extra cycles before Test 2.
    // ============================================================

    initial begin

        #15000;

        $display("");
        $display("ERROR: Simulation timeout.");
        $display("done never asserted.");

        $finish;

    end


    // ============================================================
    // FSDB waveform dump
    // ============================================================

    initial begin

        $fsdbDumpfile("matmul_8x8.fsdb");
        $fsdbDumpvars(0, matmul_8x8_tb);

    end


endmodule 