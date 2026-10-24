`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////
// FP8 e3m4 combinational multiplier
//
// Format:
//   bit 7     : sign
//   bits 6:4  : exponent, bias = 3
//   bits 3:0  : fraction with an implicit leading 1 for normal values
//
// Design policy:
//   * Normal values, signed zeros, infinities, and NaNs are supported.
//   * Denormal inputs are treated as zero.
//   * Results below the normal range are flushed to signed zero.
//   * Results are rounded to nearest, ties to even.
//   * NaN results use the canonical encoding 8'h78.
//////////////////////////////////////////////////////////////////////

module fp8_multiplier (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] result
);

    localparam logic [7:0] FP8_QNAN = 8'h78;

    logic sign_result;
    logic a_is_zero;
    logic b_is_zero;
    logic a_is_inf;
    logic b_is_inf;
    logic a_is_nan;
    logic b_is_nan;

    logic [4:0] mantissa_a;
    logic [4:0] mantissa_b;
    logic [9:0] mantissa_product;

    integer exponent_work;
    integer exponent_field;
    integer exponent_field_before_rounding;
    integer significand_keep;
    integer remainder;
    integer halfway;

    always_comb begin
        result             = 8'h00;
        sign_result        = a[7] ^ b[7];

        a_is_zero          = (a[6:4] == 3'b000);
        b_is_zero          = (b[6:4] == 3'b000);
        a_is_inf           = (a[6:4] == 3'b111) && (a[3:0] == 4'b0000);
        b_is_inf           = (b[6:4] == 3'b111) && (b[3:0] == 4'b0000);
        a_is_nan           = (a[6:4] == 3'b111) && (a[3:0] != 4'b0000);
        b_is_nan           = (b[6:4] == 3'b111) && (b[3:0] != 4'b0000);

        mantissa_a         = {1'b1, a[3:0]};
        mantissa_b         = {1'b1, b[3:0]};
        mantissa_product   = 10'b0;

        exponent_work      = 0;
        exponent_field     = 0;
        exponent_field_before_rounding = 0;
        significand_keep   = 0;
        remainder          = 0;
        halfway            = 0;

        // NaN has priority over every other result.
        if (a_is_nan || b_is_nan) begin
            result = FP8_QNAN;
        end

        // Infinity multiplied by zero is invalid.
        else if ((a_is_inf && b_is_zero) ||
                 (b_is_inf && a_is_zero)) begin
            result = FP8_QNAN;
        end

        // A remaining infinity operand produces signed infinity.
        else if (a_is_inf || b_is_inf) begin
            result = {sign_result, 3'b111, 4'b0000};
        end

        // Exponent 000 includes zero and unsupported denormals.
        else if (a_is_zero || b_is_zero) begin
            result = {sign_result, 7'b0000000};
        end

        else begin
            mantissa_product = mantissa_a * mantissa_b;

            // The stored exponents are biased by three. Therefore,
            // (Ea - 3) + (Eb - 3) = Ea + Eb - 6.
            exponent_work = $signed({1'b0, a[6:4]}) +
                            $signed({1'b0, b[6:4]}) - 6;

            // A product of at least 2.0 requires a right normalization
            // shift and an exponent increment.
            if (mantissa_product[9] == 1'b1) begin
                significand_keep = mantissa_product >> 5;
                remainder        = mantissa_product & 10'h01F;
                halfway          = 16;
                exponent_work    = exponent_work + 1;
            end
            else begin
                significand_keep = mantissa_product >> 4;
                remainder        = mantissa_product & 10'h00F;
                halfway          = 8;
            end

            // Denormal results are not supported. Check for underflow
            // before rounding so every result below the minimum normal
            // magnitude of 0.25 is flushed to signed zero.
            exponent_field_before_rounding = exponent_work + 3;

            if (exponent_field_before_rounding <= 0) begin
                result = {sign_result, 7'b0000000};
            end
            else begin
                // Round to nearest, with an exact tie rounded to an even LSB.
                if ((remainder > halfway) ||
                    ((remainder == halfway) &&
                     (significand_keep[0] == 1'b1))) begin
                    significand_keep = significand_keep + 1;
                end

                // Rounding can produce 10.0000, requiring renormalization.
                if (significand_keep >= 32) begin
                    significand_keep = 16;
                    exponent_work    = exponent_work + 1;
                end

                exponent_field = exponent_work + 3;

                if (exponent_field >= 7) begin
                    result = {sign_result, 3'b111, 4'b0000};
                end
                else begin
                    result = {
                        sign_result,
                        exponent_field[2:0],
                        significand_keep[3:0]
                    };
                end
            end
        end
    end

endmodule
