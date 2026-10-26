`timescale 1ns/1ps

// Part 4 top: APB controls/status replace the former start/done/config pins.
// The 64-bit external memory ports remain the separate matrix data interface.
module matmul_apb_top (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [15:0] PADDR,
    input  logic        PWRITE,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic [15:0] PWDATA,
    output wire  [15:0] PRDATA,
    output wire         PREADY,

    input  logic [9:0]  bram_addr_a_ext,
    input  logic [63:0] bram_wdata_a_ext,
    input  logic [7:0]  bram_we_a_ext,
    output wire  [63:0] bram_rdata_a_ext,
    input  logic [9:0]  bram_addr_b_ext,
    input  logic [63:0] bram_wdata_b_ext,
    input  logic [7:0]  bram_we_b_ext,
    output wire  [63:0] bram_rdata_b_ext,
    input  logic [9:0]  bram_addr_c_ext,
    input  logic [63:0] bram_wdata_c_ext,
    input  logic [7:0]  bram_we_c_ext,
    output wire  [63:0] bram_rdata_c_ext
);
    wire [9:0] address_mat_a, address_mat_b, address_mat_c;
    wire [7:0] address_stride_a, address_stride_b, address_stride_c;
    wire core_start, core_reset, core_done, core_exception;
    wire busy, start_accept, done_sticky;
    wire [15:0] flags_sticky;

    apb_matmul_csr u_csr (
        .PCLK, .PRESETn, .PADDR, .PWRITE, .PSEL, .PENABLE, .PWDATA,
        .PRDATA, .PREADY, .core_done, .core_exception,
        .core_start, .core_reset, .address_mat_a, .address_mat_b,
        .address_mat_c, .address_stride_a, .address_stride_b,
        .address_stride_c, .busy, .start_accept, .done_sticky, .flags_sticky
    );

    matmul_8x8_with_ram u_core (
        .clk(PCLK), .reset(core_reset), .pe_reset(core_reset),
        .start_mat_mul(core_start), .done_mat_mul(core_done),
        .exception(core_exception),
        .address_mat_a, .address_mat_b, .address_mat_c,
        .address_stride_a, .address_stride_b, .address_stride_c,
        .bram_addr_a_ext, .bram_wdata_a_ext, .bram_we_a_ext, .bram_rdata_a_ext,
        .bram_addr_b_ext, .bram_wdata_b_ext, .bram_we_b_ext, .bram_rdata_b_ext,
        .bram_addr_c_ext, .bram_wdata_c_ext, .bram_we_c_ext, .bram_rdata_c_ext
    );
endmodule
