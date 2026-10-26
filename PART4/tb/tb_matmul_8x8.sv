`timescale 1ns/1ps

// Standalone Part 3 integration check. The Part 4 APB bench is the final
// end-to-end check; this bench isolates tile wiring and matrix memory layout.
module tb_matmul_8x8;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic reset = 1'b1;
    logic pe_reset = 1'b1;
    logic start_mat_mul = 1'b0;
    wire done_mat_mul, exception;
    logic [9:0] address_mat_a = 10'd0;
    logic [9:0] address_mat_b = 10'd0;
    logic [9:0] address_mat_c = 10'd0;
    logic [7:0] address_stride_a = 8'd1;
    logic [7:0] address_stride_b = 8'd1;
    logic [7:0] address_stride_c = 8'd1;
    logic [9:0] bram_addr_a_ext = 10'd0;
    logic [9:0] bram_addr_b_ext = 10'd0;
    logic [9:0] bram_addr_c_ext = 10'd0;
    logic [63:0] bram_wdata_a_ext = 64'd0;
    logic [63:0] bram_wdata_b_ext = 64'd0;
    logic [63:0] bram_wdata_c_ext = 64'd0;
    logic [7:0] bram_we_a_ext = 8'd0;
    logic [7:0] bram_we_b_ext = 8'd0;
    logic [7:0] bram_we_c_ext = 8'd0;
    wire [63:0] bram_rdata_a_ext, bram_rdata_b_ext, bram_rdata_c_ext;

    matmul_8x8_with_ram dut (.*);

    logic [7:0] matrix_a [0:7][0:7];
    logic [7:0] matrix_b [0:7][0:7];
    logic [7:0] expected_c [0:7][0:7];
    logic seen_exception;
    integer write_count_0, write_count_1;
    integer errors = 0;
    integer test_case_id = 0;

    always @(posedge clk) begin
        if (reset) begin
            seen_exception <= 1'b0;
            write_count_0 <= 0;
            write_count_1 <= 0;
        end else if (start_mat_mul) begin
            seen_exception <= seen_exception | exception;
            if (|dut.c_we_0) write_count_0 <= write_count_0 + 1;
            if (|dut.c_we_1) write_count_1 <= write_count_1 + 1;
        end
    end

    task automatic load_matrices;
        logic [63:0] a_word, b_word;
        for (integer k = 0; k < 8; k = k + 1) begin
            a_word = 0;
            b_word = 0;
            for (integer lane = 0; lane < 8; lane = lane + 1) begin
                a_word[lane*8 +: 8] = matrix_a[lane][k];
                b_word[lane*8 +: 8] = matrix_b[k][lane];
            end
            @(negedge clk);
            bram_addr_a_ext = address_mat_a + k * address_stride_a;
            bram_addr_b_ext = address_mat_b + k * address_stride_b;
            bram_addr_c_ext = address_mat_c + k * address_stride_c;
            bram_wdata_a_ext = a_word;
            bram_wdata_b_ext = b_word;
            bram_wdata_c_ext = 64'hdeadbeef_deadbeef;
            bram_we_a_ext = 8'hff;
            bram_we_b_ext = 8'hff;
            bram_we_c_ext = 8'hff;
        end
        @(negedge clk);
        bram_we_a_ext = 0;
        bram_we_b_ext = 0;
        bram_we_c_ext = 0;
    endtask

    task automatic execute_case(input string label, input logic expected_exception);
        integer cycles;
        integer errors_before;
        logic [63:0] expected_word;
        errors_before = errors;
        test_case_id = test_case_id + 1;
        @(negedge clk);
        reset = 1'b1;
        pe_reset = 1'b1;
        start_mat_mul = 1'b0;
        // Exercise independent base addresses and all three nonunit strides.
        address_mat_a = 10'd16;
        address_mat_b = 10'd80;
        address_mat_c = 10'd160;
        address_stride_a = 8'd2;
        address_stride_b = 8'd3;
        address_stride_c = 8'd4;
        load_matrices();
        repeat (2) @(negedge clk);
        reset = 1'b0;
        pe_reset = 1'b0;
        @(negedge clk);
        start_mat_mul = 1'b1;
        cycles = 0;
        while (!done_mat_mul && cycles < 80) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (!done_mat_mul)
            $fatal(1, "Part 3 timeout in %s", label);
        // Raw tile done rises when the final output word is presented.
        // Keep start high through the next positive edge to commit that word.
        @(negedge clk);
        start_mat_mul = 1'b0;
        if (seen_exception !== expected_exception) begin
            $error("%s exception=%b expected=%b", label,
                   seen_exception, expected_exception);
            errors = errors + 1;
        end
        if (write_count_0 != 8 || write_count_1 != 8) begin
            $error("%s C write counts %0d/%0d, expected 8/8", label,
                   write_count_0, write_count_1);
            errors = errors + 1;
        end
        for (integer col = 0; col < 8; col = col + 1) begin
            expected_word = 0;
            for (integer row = 0; row < 8; row = row + 1)
                expected_word[row*8 +: 8] = expected_c[row][col];
            @(negedge clk);
            bram_addr_c_ext = address_mat_c + col * address_stride_c;
            @(negedge clk);
            if (bram_rdata_c_ext !== expected_word) begin
                $error("%s C column %0d actual=%h expected=%h", label,
                       col, bram_rdata_c_ext, expected_word);
                errors = errors + 1;
            end
        end
        if (errors == errors_before)
            $display("PASS Part3 case %0d: %s; raw_done after %0d clocks; 64 outputs checked",
                     test_case_id, label, cycles);
    endtask

    initial begin
`ifdef FSDB
        $fsdbDumpfile("matmul_8x8.fsdb");
        $fsdbDumpvars(0, tb_matmul_8x8);
`else
        $dumpfile("matmul_8x8.vcd");
        $dumpvars(0, tb_matmul_8x8);
`endif
        for (integer r = 0; r < 8; r = r + 1)
            for (integer c = 0; c < 8; c = c + 1) begin
                matrix_a[r][c] = 8'h30;
                matrix_b[r][c] = 8'h30;
                expected_c[r][c] = 8'h60;
            end
        execute_case("ones times ones produces eight", 1'b0);

        for (integer r = 0; r < 8; r = r + 1)
            for (integer c = 0; c < 8; c = c + 1) begin
                matrix_a[r][c] = (r == c) ? 8'h30 : 8'h00;
                matrix_b[r][c] = 8'h20 + ((r*8+c) % 48);
                if ((r+c) % 2) matrix_b[r][c][7] = 1'b1;
                expected_c[r][c] = matrix_b[r][c];
            end
        execute_case("identity preserves distinct signed values in every quadrant", 1'b0);

        for (integer r = 0; r < 8; r = r + 1)
            for (integer c = 0; c < 8; c = c + 1) begin
                matrix_a[r][c] = 8'h40;
                matrix_b[r][c] = 8'h40;
                expected_c[r][c] = 8'h70;
            end
        execute_case("finite operands overflow accumulation to infinity", 1'b1);

        for (integer r = 0; r < 8; r = r + 1)
            for (integer c = 0; c < 8; c = c + 1) begin
                matrix_a[r][c] = 8'h10;
                matrix_b[r][c] = 8'h10;
                expected_c[r][c] = 8'h00;
            end
        execute_case("underflow pulses are observed with zero final outputs", 1'b1);

        if (errors != 0) $fatal(1, "Part 3 integration failed: %0d errors", errors);
        $display("PASS Part3 integration: 4 cases, 256 element results, all byte lanes and tile quadrants");
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Part 3 global watchdog expired");
    end
endmodule
