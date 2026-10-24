`timescale 1ns/1ns

module matmul_tb;

    logic clk;
    logic resetn;
    logic pe_resetn;
    logic start;

    // Driven by the DUT
    wire done;

    // Exception output from the 4x4 systolic matrix multiplier.
    wire exception;
    assign exception = u_matmul.u_matmul_4x4.exception;


    ////////////////////////////////////////////
    // Device Under Test
    ////////////////////////////////////////////

    matrix_multiplication u_matmul (
        .clk              (clk),
        .resetn           (resetn),
        .pe_resetn        (pe_resetn),
        .address_mat_a    (10'b0),
        .address_mat_b    (10'b0),
        .address_mat_c    (10'b0),
        .address_stride_a (8'd1),
        .address_stride_b (8'd1),
        .address_stride_c (8'd1),
        .start            (start),
        .done             (done)
    );


    ////////////////////////////////////////////
    // Clock generation
    ////////////////////////////////////////////

    initial begin
        clk = 1'b0;

        forever begin
            #10;
            clk = ~clk;
        end
    end


    ////////////////////////////////////////////
    // Reset generation
    ////////////////////////////////////////////

    // Reset is controlled by the test sequence below so that both
    // required FP8 test cases can run in the same simulation.


    ////////////////////////////////////////////
    // Perform test
    ////////////////////////////////////////////

    integer errors;
    integer i;

    initial begin
        start     = 1'b0;
        resetn    = 1'b0;
        pe_resetn = 1'b0;
        errors    = 0;

        ////////////////////////////////////////////////////////////////////
        // Test 1: Normal FP8 matrix multiplication
        // A = identity matrix, B = all 1.0, therefore C = B.
        // FP8 E3M4 encodings: 0.0 = 8'h00, 1.0 = 8'h30.
        ////////////////////////////////////////////////////////////////////

        u_matmul.matrix_A.ram[3] = {8'h30, 8'h00, 8'h00, 8'h00};
        u_matmul.matrix_A.ram[2] = {8'h00, 8'h30, 8'h00, 8'h00};
        u_matmul.matrix_A.ram[1] = {8'h00, 8'h00, 8'h30, 8'h00};
        u_matmul.matrix_A.ram[0] = {8'h00, 8'h00, 8'h00, 8'h30};

        u_matmul.matrix_B.ram[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_B.ram[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_B.ram[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_B.ram[0] = {8'h30, 8'h30, 8'h30, 8'h30};

        #55;
        resetn    = 1'b1;
        pe_resetn = 1'b1;

        #60;
        start = 1'b1;
        @(posedge done);
        start = 1'b0;
        #40;

        for (i = 0; i < 4; i = i + 1) begin
            if (u_matmul.matrix_C.ram[i] !== {8'h30, 8'h30, 8'h30, 8'h30}) begin
                $display("ERROR: Normal FP8 test C RAM[%0d] = %h, expected 30303030",
                         i, u_matmul.matrix_C.ram[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: Normal FP8 matrix multiplication");

        ////////////////////////////////////////////////////////////////////
        // Test 2: FP8 exception case
        // Infinity multiplied by zero is invalid and produces NaN.
        // FP8 E3M4 encodings: +Inf = 8'h70, NaN = 8'h78.
        ////////////////////////////////////////////////////////////////////

        resetn    = 1'b0;
        pe_resetn = 1'b0;
        #40;

        for (i = 0; i < 4; i = i + 1) begin
            u_matmul.matrix_A.ram[i] = {8'h70, 8'h70, 8'h70, 8'h70};
            u_matmul.matrix_B.ram[i] = {8'h00, 8'h00, 8'h00, 8'h00};
            u_matmul.matrix_C.ram[i] = 32'h00000000;
        end

        resetn    = 1'b1;
        pe_resetn = 1'b1;
        #60;

        start = 1'b1;
        wait (exception === 1'b1);
        $display("PASS: FP8 exception asserted");

        @(posedge done);
        start = 1'b0;
        #40;

        for (i = 0; i < 4; i = i + 1) begin
            if (u_matmul.matrix_C.ram[i] !== {8'h78, 8'h78, 8'h78, 8'h78}) begin
                $display("ERROR: Exception FP8 test C RAM[%0d] = %h, expected 78787878",
                         i, u_matmul.matrix_C.ram[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: All Part 2 FP8 tests passed");
        else
            $display("FAIL: Part 2 completed with %0d error(s)", errors);

        #100;
        $finish;
    end


    ////////////////////////////////////////////
    // Sample test case
    ////////////////////////////////////////////

    // A           B           Output       Output in hex
    // 1 1 1 1     1 1 1 1     4 4 4 4      4 4 4 4
    // 1 1 1 1     1 1 1 1     4 4 4 4      4 4 4 4
    // 1 1 1 1     1 1 1 1     4 4 4 4      4 4 4 4
    // 1 1 1 1     1 1 1 1     4 4 4 4      4 4 4 4

    // integer i;
    //
    // initial begin
    //     for (i = 0; i < 4; i = i + 1) begin
    //         u_matmul.matrix_A.ram[i] =
    //             {8'h01, 8'h01, 8'h01, 8'h01};
    //
    //         u_matmul.matrix_B.ram[i] =
    //             {8'h01, 8'h01, 8'h01, 8'h01};
    //     end
    // end


    ////////////////////////////////////////////
    // Actual test case
    ////////////////////////////////////////////

    // A           B           Output          Output in hex
    // 8 4 6 8     1 1 3 0     98 90 82 34     62 5A 52 22
    // 3 3 3 7     0 1 4 3     75 63 51 26     4B 3F 33 1A
    // 5 2 1 6     3 5 3 1     62 48 44 19     3E 30 2C 13
    // 9 1 0 5     9 6 3 2     54 40 46 13     36 28 2E 0D


    /*
    initial begin

        // A is stored in row-major format.
        // A[0][0] (8'h08) should be the least significant
        // byte of ram[0].
        //
        // The first column of A should be read together, so
        // it must be placed in the first matrix_A RAM location.
        //
        // This is due to the Verilog/SystemVerilog convention:
        // {MSB, ..., LSB}

        u_matmul.matrix_A.ram[3] =
            {8'h05, 8'h06, 8'h07, 8'h08};

        u_matmul.matrix_A.ram[2] =
            {8'h00, 8'h01, 8'h03, 8'h06};

        u_matmul.matrix_A.ram[1] =
            {8'h01, 8'h02, 8'h03, 8'h04};

        u_matmul.matrix_A.ram[0] =
            {8'h09, 8'h05, 8'h03, 8'h08};


        // B is stored in column-major format.
        // B[0][0] (8'h01) should be the least significant
        // byte of ram[0].
        //
        // The first row of B should be read together, so
        // it must be placed in the first matrix_B RAM location.

        u_matmul.matrix_B.ram[3] =
            {8'h02, 8'h03, 8'h06, 8'h09};

        u_matmul.matrix_B.ram[2] =
            {8'h01, 8'h03, 8'h05, 8'h03};

        u_matmul.matrix_B.ram[1] =
            {8'h03, 8'h04, 8'h01, 8'h00};

        u_matmul.matrix_B.ram[0] =
            {8'h00, 8'h03, 8'h01, 8'h01};
    end
    */


    ////////////////////////////////////////////
    // Generate FSDB waveform
    ////////////////////////////////////////////

    initial begin
        $fsdbDumpvars;
    end

endmodule