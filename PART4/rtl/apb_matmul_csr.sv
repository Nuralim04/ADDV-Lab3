`timescale 1ns/1ps

// Zero-wait APB slave and per-operation lifecycle controller.
// A completed START write is a command. The existing systolic core instead
// requires start_mat_mul to remain HIGH for the entire operation.
module apb_matmul_csr (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [15:0] PADDR,
    input  logic        PWRITE,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic [15:0] PWDATA,
    output logic [15:0] PRDATA,
    output wire         PREADY,

    input  logic        core_done,
    input  logic        core_exception,
    output wire         core_start,
    output wire         core_reset,
    output logic [9:0]  address_mat_a,
    output logic [9:0]  address_mat_b,
    output logic [9:0]  address_mat_c,
    output logic [7:0]  address_stride_a,
    output logic [7:0]  address_stride_b,
    output logic [7:0]  address_stride_c,

    // Internal observability; these are not additional top-level control pins.
    output wire         busy,
    output wire         start_accept,
    output logic        done_sticky,
    output logic [15:0] flags_sticky
);
    import lab3_apb_pkg::*;

    typedef enum logic [1:0] {IDLE, PREP, RUN} launch_state_t;
    launch_state_t launch_state;

    wire write_access;
    assign PREADY       = 1'b1;
    assign write_access = PRESETn && PSEL && PENABLE && PREADY && PWRITE;
    assign busy         = (launch_state != IDLE);
    assign core_start   = (launch_state == RUN);
    assign core_reset   = !PRESETn || (launch_state == PREP);
    assign start_accept = write_access && !busy &&
                          (PADDR == REG_CONTROL) && PWDATA[0];

    // Read data is valid BEFORE the access completion edge. Generating it only
    // in a posedge block would be one edge too late when PREADY is tied high.
    always_comb begin
        PRDATA = 16'h0000;
        if (PRESETn && PSEL && !PWRITE) begin
            case (PADDR)
                REG_CONTROL:  PRDATA = 16'h0000; // write-one command, no latch
                REG_STATUS:   PRDATA = {14'b0, busy, done_sticky};
                REG_FLAGS:    PRDATA = flags_sticky;
                REG_ADDR_A:   PRDATA = {6'b0, address_mat_a};
                REG_ADDR_B:   PRDATA = {6'b0, address_mat_b};
                REG_ADDR_C:   PRDATA = {6'b0, address_mat_c};
                REG_STRIDE_A: PRDATA = {8'b0, address_stride_a};
                REG_STRIDE_B: PRDATA = {8'b0, address_stride_b};
                REG_STRIDE_C: PRDATA = {8'b0, address_stride_c};
                default:      PRDATA = 16'h0000;
            endcase
        end
    end

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            launch_state     <= IDLE;
            done_sticky      <= 1'b0;
            flags_sticky     <= 16'h0000;
            address_mat_a    <= 10'd0;
            address_mat_b    <= 10'd0;
            address_mat_c    <= 10'd0;
            address_stride_a <= 8'd1;
            address_stride_b <= 8'd1;
            address_stride_c <= 8'd1;
        end else begin
            // Protect the in-flight operation. A write while busy completes
            // on APB but has no effect, including a repeated START command.
            if (write_access && !busy) begin
                case (PADDR)
                    REG_ADDR_A:   address_mat_a    <= PWDATA[9:0];
                    REG_ADDR_B:   address_mat_b    <= PWDATA[9:0];
                    REG_ADDR_C:   address_mat_c    <= PWDATA[9:0];
                    REG_STRIDE_A: address_stride_a <= PWDATA[7:0];
                    REG_STRIDE_B: address_stride_b <= PWDATA[7:0];
                    REG_STRIDE_C: address_stride_c <= PWDATA[7:0];
                    default: begin end // command, read-only, or unmapped
                endcase
            end

            case (launch_state)
                IDLE: begin
                    if (start_accept) begin
                        done_sticky  <= 1'b0;
                        flags_sticky <= 16'h0000;
                        launch_state <= PREP;
                    end
                end
                PREP: begin
                    // A full clock edge resets the PE accumulators and
                    // preloads memory address logic before core_start rises.
                    launch_state <= RUN;
                end
                RUN: begin
                    flags_sticky <= flags_sticky | {15'b0, core_exception};
                    if (core_done) begin
                        // The team Part 3 completion pulse follows the final
                        // valid result write. Latch it so software can poll
                        // after completion without missing the one-cycle pulse.
                        done_sticky  <= 1'b1;
                        launch_state <= IDLE;
                    end
                end
                default: launch_state <= IDLE;
            endcase
        end
    end
endmodule
