`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////
// Directed, self-checking testbench for the FP8 e3m4 arithmetic units
//////////////////////////////////////////////////////////////////////

module fp8_arithmetic_tb;

    logic [7:0] add_a;
    logic [7:0] add_b;
    logic [7:0] add_result;

    logic [7:0] mul_a;
    logic [7:0] mul_b;
    logic [7:0] mul_result;

    integer add_case_id;
    integer mul_case_id;
    integer test_count;
    integer error_count;

    fp8_adder u_fp8_adder (
        .a      (add_a),
        .b      (add_b),
        .result (add_result)
    );

    fp8_multiplier u_fp8_multiplier (
        .a      (mul_a),
        .b      (mul_b),
        .result (mul_result)
    );

    task automatic check_add (
        input logic [7:0] operand_a,
        input logic [7:0] operand_b,
        input logic [7:0] expected,
        input string      description
    );
    begin
        add_case_id = add_case_id + 1;
        test_count  = test_count + 1;
        add_a       = operand_a;
        add_b       = operand_b;

        #10;

        if (add_result !== expected) begin
            error_count = error_count + 1;
            $display(
                "ADD FAIL case %0d: %s | a=%h b=%h expected=%h actual=%h",
                add_case_id,
                description,
                operand_a,
                operand_b,
                expected,
                add_result
            );
        end
        else begin
            $display(
                "ADD PASS case %0d: %s | a=%h b=%h result=%h",
                add_case_id,
                description,
                operand_a,
                operand_b,
                add_result
            );
        end
    end
    endtask

    task automatic check_multiply (
        input logic [7:0] operand_a,
        input logic [7:0] operand_b,
        input logic [7:0] expected,
        input string      description
    );
    begin
        mul_case_id = mul_case_id + 1;
        test_count  = test_count + 1;
        mul_a       = operand_a;
        mul_b       = operand_b;

        #10;

        if (mul_result !== expected) begin
            error_count = error_count + 1;
            $display(
                "MUL FAIL case %0d: %s | a=%h b=%h expected=%h actual=%h",
                mul_case_id,
                description,
                operand_a,
                operand_b,
                expected,
                mul_result
            );
        end
        else begin
            $display(
                "MUL PASS case %0d: %s | a=%h b=%h result=%h",
                mul_case_id,
                description,
                operand_a,
                operand_b,
                mul_result
            );
        end
    end
    endtask

    initial begin
        $fsdbDumpfile("fp8_arithmetic.fsdb");
        $fsdbDumpvars(0, fp8_arithmetic_tb);
    end

    initial begin
        add_a       = 8'h00;
        add_b       = 8'h00;
        mul_a       = 8'h00;
        mul_b       = 8'h00;
        add_case_id = 0;
        mul_case_id = 0;
        test_count  = 0;
        error_count = 0;

        #5;

        // Addition cases
        check_add(8'h30, 8'h40, 8'h48, "1.0 + 2.0 = 3.0");
        check_add(8'h38, 8'h20, 8'h40, "1.5 + 0.5 = 2.0");
        check_add(8'hB0, 8'h20, 8'hA0, "-1.0 + 0.5 = -0.5");
        check_add(8'h30, 8'hB0, 8'h00, "1.0 + -1.0 = +0");
        check_add(8'h6F, 8'h6F, 8'h70, "maximum + maximum overflows");
        check_add(8'h70, 8'hF0, 8'h78, "+infinity + -infinity = NaN");
        check_add(8'h78, 8'h30, 8'h78, "NaN propagates");
        check_add(8'h00, 8'h44, 8'h44, "+0 + 2.5 = 2.5");
        check_add(8'h30, 8'h12, 8'h34, "RNE exact tie rounds down to even");
        check_add(8'h30, 8'h16, 8'h36, "RNE exact tie rounds up to even");

        // Multiplication cases
        check_multiply(8'h38, 8'h40, 8'h48, "1.5 * 2.0 = 3.0");
        check_multiply(8'hC0, 8'h20, 8'hB0, "-2.0 * 0.5 = -1.0");
        check_multiply(8'h00, 8'h54, 8'h00, "+0 * 5.0 = +0");
        check_multiply(8'h70, 8'h00, 8'h78, "infinity * zero = NaN");
        check_multiply(8'h6F, 8'h40, 8'h70, "maximum * 2.0 overflows");
        check_multiply(8'h78, 8'h30, 8'h78, "NaN propagates");
        check_multiply(8'hF0, 8'h40, 8'hF0, "-infinity * 2.0 = -infinity");
        check_multiply(8'h34, 8'h38, 8'h3E, "1.25 * 1.5 = 1.875");
        check_multiply(8'h31, 8'h31, 8'h32, "rounded finite product");
        check_multiply(8'h10, 8'h10, 8'h00, "underflow flushes to zero");
        check_multiply(8'h80, 8'h40, 8'h80, "-0 * 2.0 = -0");

        if (error_count == 0) begin
            $display(
                "FP8 TESTBENCH PASSED: %0d/%0d cases passed",
                test_count,
                test_count
            );
        end
        else begin
            $display(
                "FP8 TESTBENCH FAILED: %0d errors in %0d cases",
                error_count,
                test_count
            );
            $fatal(1, "One or more FP8 arithmetic cases failed");
        end

        #10;
        $finish;
    end

endmodule
