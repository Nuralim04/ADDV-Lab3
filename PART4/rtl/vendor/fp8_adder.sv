`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////
// FP8 e3m4 combinational adder
//
// Normal operands are first converted to an exact signed fixed-point
// representation whose least-significant unit is 1/64. The exact sum is
// then normalized and rounded back to FP8. This avoids losing alignment
// information before the final rounding step.
//
// Design policy:
//   * Normal values, signed zeros, infinities, and NaNs are supported.
//   * Denormal inputs are treated as zero.
//   * Results below the normal range are flushed to signed zero.
//   * Results are rounded to nearest, ties to even.
//   * NaN results use the canonical encoding 8'h78.
//////////////////////////////////////////////////////////////////////

module fp8_adder (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] result,
    output logic       exception
);
    localparam logic [7:0] FP8_QNAN = 8'h78;

    logic a_is_zero;
    logic b_is_zero;
    logic a_is_inf;
    logic b_is_inf;
    logic a_is_nan;
    logic b_is_nan;
    logic result_sign;

    integer exponent_a;
    integer exponent_b;
    integer magnitude_a;
    integer magnitude_b;
    integer signed_a;
    integer signed_b;
    integer signed_sum;
    integer absolute_sum;

    integer msb_position;
    integer exponent_field;
    integer shift_amount;
    integer significand_keep;
    integer remainder;
    integer halfway;
    integer i;

    always_comb begin
        result             = 8'h00;
        exception          = 1'b0;

        a_is_zero          = (a[6:4] == 3'b000);
        b_is_zero          = (b[6:4] == 3'b000);
        a_is_inf           = (a[6:4] == 3'b111) && (a[3:0] == 4'b0000);
        b_is_inf           = (b[6:4] == 3'b111) && (b[3:0] == 4'b0000);
        a_is_nan           = (a[6:4] == 3'b111) && (a[3:0] != 4'b0000);
        b_is_nan           = (b[6:4] == 3'b111) && (b[3:0] != 4'b0000);
        result_sign        = 1'b0;

        exponent_a         = a[6:4];
        exponent_b         = b[6:4];
        magnitude_a        = 0;
        magnitude_b        = 0;
        signed_a           = 0;
        signed_b           = 0;
        signed_sum         = 0;
        absolute_sum       = 0;

        msb_position       = 0;
        exponent_field     = 0;
        shift_amount       = 0;
        significand_keep   = 0;
        remainder          = 0;
        halfway            = 0;

        // NaN has priority over every other result.
        if (a_is_nan || b_is_nan) begin
            result    = FP8_QNAN;
            exception = 1'b1;
        end

        // Opposite-signed infinities form an invalid operation.
        else if (a_is_inf && b_is_inf && (a[7] != b[7])) begin
            result    = FP8_QNAN;
            exception = 1'b1;
        end

        else if (a_is_inf) begin
            result    = {a[7], 3'b111, 4'b0000};
            exception = 1'b1;
        end

        else if (b_is_inf) begin
            result    = {b[7], 3'b111, 4'b0000};
            exception = 1'b1;
        end

        // For two zero-like operands, -0 + -0 produces -0. All other
        // zero-sign combinations produce +0.
        else if (a_is_zero && b_is_zero) begin
            result = {a[7] & b[7], 7'b0000000};
        end

        else if (a_is_zero) begin
            result = b;
        end

        else if (b_is_zero) begin
            result = a;
        end

        else begin
            // A normal e3m4 value multiplied by 64 is exactly:
            // (16 + fraction) << (stored_exponent - 1).
            magnitude_a = (16 + a[3:0]) << (exponent_a - 1);
            magnitude_b = (16 + b[3:0]) << (exponent_b - 1);

            signed_a = a[7] ? -magnitude_a : magnitude_a;
            signed_b = b[7] ? -magnitude_b : magnitude_b;
            signed_sum = signed_a + signed_b;

            if (signed_sum == 0) begin
                result = 8'h00;
            end
            else begin
                result_sign  = (signed_sum < 0);
                absolute_sum = result_sign ? -signed_sum : signed_sum;

                // Any nonzero value below 16/64 is denormal in e3m4.
                if (absolute_sum < 16) begin
                    result    = {result_sign, 7'b0000000};
                    exception = 1'b1;
                end
                else begin
                    // Locate the leading one. The maximum finite sum uses
                    // only bits 10:0, so the loop has a fixed small bound.
                    msb_position = 0;
                    for (i = 0; i <= 10; i = i + 1) begin
                        if (absolute_sum[i] == 1'b1) begin
                            msb_position = i;
                        end
                    end

                    exponent_field = msb_position - 3;

                    if (exponent_field >= 7) begin
                        result    = {result_sign, 3'b111, 4'b0000};
                        exception = 1'b1;
                    end
                    else begin
                        shift_amount     = exponent_field - 1;
                        significand_keep = absolute_sum >> shift_amount;

                        if (shift_amount > 0) begin
                            remainder = absolute_sum &
                                        ((1 << shift_amount) - 1);
                            halfway   = 1 << (shift_amount - 1);

                            if ((remainder > halfway) ||
                                ((remainder == halfway) &&
                                 (significand_keep[0] == 1'b1))) begin
                                significand_keep = significand_keep + 1;
                            end
                        end

                        // Rounding can produce 10.0000.
                        if (significand_keep >= 32) begin
                            significand_keep = 16;
                            exponent_field   = exponent_field + 1;
                        end

                        if (exponent_field >= 7) begin
                            result = {
                                result_sign,
                                3'b111,
                                4'b0000
                            };
                            exception = 1'b1;
                        end
                        else begin
                            result = {
                                result_sign,
                                exponent_field[2:0],
                                significand_keep[3:0]
                            };
                        end
                    end
                end
            end
        end
    end

endmodule
