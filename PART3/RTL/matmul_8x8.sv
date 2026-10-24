`timescale 1ns / 1ps

module matmul_8x8_systolic (

    input  logic clk,
    input  logic reset,
    input  logic pe_reset,
    input  logic start_mat_mul,

    output logic done_mat_mul,

    // ------------------------------------------------------------
    // Common matrix base addresses
    // ------------------------------------------------------------
    input logic [`AWIDTH-1:0] address_mat_a,
    input logic [`AWIDTH-1:0] address_mat_b,
    input logic [`AWIDTH-1:0] address_mat_c,

    // ------------------------------------------------------------
    // Common matrix address strides
    // ------------------------------------------------------------
    input logic [`ADDR_STRIDE_WIDTH-1:0] address_stride_a,
    input logic [`ADDR_STRIDE_WIDTH-1:0] address_stride_b,
    input logic [`ADDR_STRIDE_WIDTH-1:0] address_stride_c,

    // ------------------------------------------------------------
    // Data from two A RAMs
    // ------------------------------------------------------------
    input logic [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data_0,
    input logic [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data_1,

    // ------------------------------------------------------------
    // Data from two B RAMs
    // ------------------------------------------------------------
    input logic [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data_0,
    input logic [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data_1,

    // ------------------------------------------------------------
    // Output data for two C RAMs
    // ------------------------------------------------------------
    output logic [`MAT_MUL_SIZE*`DWIDTH-1:0] c_data_0,
    output logic [`MAT_MUL_SIZE*`DWIDTH-1:0] c_data_1,

    // ------------------------------------------------------------
    // Addresses for two A RAMs
    // ------------------------------------------------------------
    output logic [`AWIDTH-1:0] a_addr_0,
    output logic [`AWIDTH-1:0] a_addr_1,

    // ------------------------------------------------------------
    // Addresses for two B RAMs
    // ------------------------------------------------------------
    output logic [`AWIDTH-1:0] b_addr_0,
    output logic [`AWIDTH-1:0] b_addr_1,

    // ------------------------------------------------------------
    // Addresses for two C RAMs
    // ------------------------------------------------------------
    output logic [`AWIDTH-1:0] c_addr_0,
    output logic [`AWIDTH-1:0] c_addr_1,

    // ------------------------------------------------------------
    // Output-valid signals for C RAMs
    // ------------------------------------------------------------
    output logic c_data_available_0,
    output logic c_data_available_1,

    // ------------------------------------------------------------
    // Combined FP8 exception
    // ------------------------------------------------------------
    output logic exception
);


    // ============================================================
    // Internal A connections
    // ============================================================

    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] a_link_top;
    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] a_link_bottom;


    // ============================================================
    // Internal B connections
    // ============================================================

    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] b_link_left;
    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] b_link_right;


    // ============================================================
    // Internal C connections
    //
    // Bottom blocks shift their C results into the corresponding
    // top blocks.
    // ============================================================

    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] c_link_left;
    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] c_link_right;

    // The 4x4 output logic's early done pulse leaves its write address
    // two strides ahead when 8x8 result capture begins. Compensate here
    // so the external C RAMs start at address_mat_c.
    wire [`AWIDTH-1:0] c_addr_0_raw;
    wire [`AWIDTH-1:0] c_addr_1_raw;
    wire [`AWIDTH-1:0] c_addr_offset =
        ({{(`AWIDTH-`ADDR_STRIDE_WIDTH){1'b0}}, address_stride_c} << 1);

    assign c_addr_0 = c_addr_0_raw - c_addr_offset;
    assign c_addr_1 = c_addr_1_raw - c_addr_offset;


    // ============================================================
    // Individual 4x4 done signals
    //
    // IMPORTANT:
    // These are NOT used as the final 8x8 done condition.
    //
    // The original 4x4 block asserts done according to its own
    // original timing. For final_mat_mul_size = 8 that happens
    // before the complete 8x8 C-output stream has been shifted.
    // ============================================================

    logic done_00;
    logic done_01;
    logic done_10;
    logic done_11;


    // ============================================================
    // Individual FP8 exception signals
    // ============================================================

    logic exception_00;
    logic exception_01;
    logic exception_10;
    logic exception_11;


    // ============================================================
    // Unused address/output signals
    // ============================================================

    logic [`AWIDTH-1:0] unused_a_addr_10;
    logic [`AWIDTH-1:0] unused_a_addr_11;

    logic [`AWIDTH-1:0] unused_b_addr_01;
    logic [`AWIDTH-1:0] unused_b_addr_11;

    logic [`AWIDTH-1:0] unused_c_addr_10;
    logic [`AWIDTH-1:0] unused_c_addr_11;

    logic unused_c_available_10;
    logic unused_c_available_11;

    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] unused_a_out_01;
    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] unused_a_out_11;

    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] unused_b_out_10;
    logic [`MAT_MUL_SIZE*`DWIDTH-1:0] unused_b_out_11;


    // ============================================================
    // TOP-LEFT 4x4 BLOCK
    //
    // a_loc = 0
    // b_loc = 0
    // ============================================================

    matmul_4x4_systolic matmul_00 (

        .clk                         (clk),
        .reset                       (reset),
        .pe_reset                    (pe_reset),
        .start_mat_mul               (start_mat_mul),

        .done_mat_mul                (done_00),

        .address_mat_a               (address_mat_a),
        .address_mat_b               (address_mat_b),
        .address_mat_c               (address_mat_c),

        .address_stride_a            (address_stride_a),
        .address_stride_b            (address_stride_b),
        .address_stride_c            (address_stride_c),

        .a_data                      (a_data_0),
        .b_data                      (b_data_0),

        .a_data_in                   ('0),
        .b_data_in                   ('0),

        // Bottom-left C stream enters here.
        .c_data_in                   (c_link_left),

        // Final left-side C stream.
        .c_data_out                  (c_data_0),

        .a_data_out                  (a_link_top),
        .b_data_out                  (b_link_left),

        .a_addr                      (a_addr_0),
        .b_addr                      (b_addr_0),
        .c_addr                      (c_addr_0_raw),

        .c_data_available            (c_data_available_0),

        .validity_mask_a_rows        (4'b1111),
        .validity_mask_a_cols_b_rows (4'b1111),
        .validity_mask_b_cols        (4'b1111),

        .final_mat_mul_size          (8'd8),

        .a_loc                       (8'd0),
        .b_loc                       (8'd0),

        .exception                   (exception_00)
    );


    // ============================================================
    // TOP-RIGHT 4x4 BLOCK
    //
    // a_loc = 1
    // b_loc = 0
    // ============================================================

    matmul_4x4_systolic matmul_01 (

        .clk                         (clk),
        .reset                       (reset),
        .pe_reset                    (pe_reset),
        .start_mat_mul               (start_mat_mul),

        .done_mat_mul                (done_01),

        .address_mat_a               (address_mat_a),
        .address_mat_b               (address_mat_b),
        .address_mat_c               (address_mat_c),

        .address_stride_a            (address_stride_a),
        .address_stride_b            (address_stride_b),
        .address_stride_c            (address_stride_c),

        .a_data                      (a_data_1),

        // B comes through the neighboring block.
        .b_data                      ('0),

        .a_data_in                   (a_link_top),
        .b_data_in                   (b_link_left),

        // Bottom-right C stream enters here.
        .c_data_in                   (c_link_right),

        // Final right-side C stream.
        .c_data_out                  (c_data_1),

        .a_data_out                  (unused_a_out_01),
        .b_data_out                  (b_link_right),

        .a_addr                      (a_addr_1),
        .b_addr                      (unused_b_addr_01),
        .c_addr                      (c_addr_1_raw),

        .c_data_available            (c_data_available_1),

        .validity_mask_a_rows        (4'b1111),
        .validity_mask_a_cols_b_rows (4'b1111),
        .validity_mask_b_cols        (4'b1111),

        .final_mat_mul_size          (8'd8),

        .a_loc                       (8'd1),
        .b_loc                       (8'd0),

        .exception                   (exception_01)
    );


    // ============================================================
    // BOTTOM-LEFT 4x4 BLOCK
    //
    // a_loc = 0
    // b_loc = 1
    // ============================================================

    matmul_4x4_systolic matmul_10 (

        .clk                         (clk),
        .reset                       (reset),
        .pe_reset                    (pe_reset),
        .start_mat_mul               (start_mat_mul),

        .done_mat_mul                (done_10),

        .address_mat_a               (address_mat_a),
        .address_mat_b               (address_mat_b),
        .address_mat_c               (address_mat_c),

        .address_stride_a            (address_stride_a),
        .address_stride_b            (address_stride_b),
        .address_stride_c            (address_stride_c),

        .a_data                      ('0),
        .b_data                      (b_data_1),

        .a_data_in                   (a_link_top),
        .b_data_in                   ('0),

        // No block below this one.
        .c_data_in                   ('0),

        // Feed lower-left C results into M00.
        .c_data_out                  (c_link_left),

        .a_data_out                  (a_link_bottom),
        .b_data_out                  (unused_b_out_10),

        .a_addr                      (unused_a_addr_10),
        .b_addr                      (b_addr_1),
        .c_addr                      (unused_c_addr_10),

        .c_data_available            (unused_c_available_10),

        .validity_mask_a_rows        (4'b1111),
        .validity_mask_a_cols_b_rows (4'b1111),
        .validity_mask_b_cols        (4'b1111),

        .final_mat_mul_size          (8'd8),

        .a_loc                       (8'd0),
        .b_loc                       (8'd1),

        .exception                   (exception_10)
    );


    // ============================================================
    // BOTTOM-RIGHT 4x4 BLOCK
    //
    // a_loc = 1
    // b_loc = 1
    // ============================================================

    matmul_4x4_systolic matmul_11 (

        .clk                         (clk),
        .reset                       (reset),
        .pe_reset                    (pe_reset),
        .start_mat_mul               (start_mat_mul),

        .done_mat_mul                (done_11),

        .address_mat_a               (address_mat_a),
        .address_mat_b               (address_mat_b),
        .address_mat_c               (address_mat_c),

        .address_stride_a            (address_stride_a),
        .address_stride_b            (address_stride_b),
        .address_stride_c            (address_stride_c),

        .a_data                      ('0),
        .b_data                      ('0),

        .a_data_in                   (a_link_bottom),
        .b_data_in                   (b_link_right),

        // No block below this one.
        .c_data_in                   ('0),

        // Feed lower-right C results into M01.
        .c_data_out                  (c_link_right),

        .a_data_out                  (unused_a_out_11),
        .b_data_out                  (unused_b_out_11),

        .a_addr                      (unused_a_addr_11),
        .b_addr                      (unused_b_addr_11),
        .c_addr                      (unused_c_addr_11),

        .c_data_available            (unused_c_available_11),

        .validity_mask_a_rows        (4'b1111),
        .validity_mask_a_cols_b_rows (4'b1111),
        .validity_mask_b_cols        (4'b1111),

        .final_mat_mul_size          (8'd8),

        .a_loc                       (8'd1),
        .b_loc                       (8'd1),

        .exception                   (exception_11)
    );


    // ============================================================
    // 8x8 COMPLETION CONTROL
    // ============================================================
    //
    // The original 4x4 module has fixed completion timing intended
    // for the 4x4 case.
    //
    // For final_mat_mul_size = 8, its output_logic starts capturing
    // C when its internal clk_cnt reaches:
    //
    //   (8 << 2) - 8 - 1 + NUM_CYCLES_IN_MAC
    //
    // With NUM_CYCLES_IN_MAC = 1:
    //
    //   32 - 8 - 1 + 1 = 24
    //
    // The top blocks then output:
    //
    //   cycles 24-27 : their own four C words
    //   cycles 28-31 : four C words received from bottom blocks
    //
    // The RAM samples c_data_out on the following clock edge, so
    // the final word must be allowed to write before done is raised.
    //
    // Therefore the 8x8 wrapper keeps the operation alive through
    // the complete output/write window and generates its own done.
    // ============================================================

    // Counts from 0 through 34; six bits cover the full range.
    logic [5:0] clk_cnt_8x8;


    always_ff @(posedge clk) begin

        if (reset || !start_mat_mul) begin

            clk_cnt_8x8 <= 6'd0;
            done_mat_mul <= 1'b0;

        end

        else begin

            // Default: done is a one-cycle pulse.
            done_mat_mul <= 1'b0;

            if (clk_cnt_8x8 < 6'd33) begin

                clk_cnt_8x8 <= clk_cnt_8x8 + 1'b1;

            end

            else if (clk_cnt_8x8 == 6'd33) begin

                // All eight C output words have had time to
                // propagate and be written into the C RAMs.
                done_mat_mul <= 1'b1;
                clk_cnt_8x8 <= 6'd34;

            end

            else begin

                // Keep done as a one-cycle pulse if the parent keeps
                // start_mat_mul asserted for an additional cycle.
                clk_cnt_8x8 <= clk_cnt_8x8;

            end

        end

    end


    // ============================================================
    // Global FP8 exception
    // ============================================================

    assign exception =
        exception_00 |
        exception_01 |
        exception_10 |
        exception_11;


endmodule