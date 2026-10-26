`timescale 1ns/1ps

// The memory/data plane remains separate from the APB control plane.
// A memory word packs a column: lane r holds A[r][k].
// B memory word packs a row: lane c holds B[k][c].
// C memory word packs a column: lane r holds C[r][c].
// Bank 0 is lanes 0..3; bank 1 is lanes 4..7.
module matmul_8x8_with_ram (
    input  logic        clk,
    input  logic        reset,
    input  logic        pe_reset,
    input  logic        start_mat_mul,
    output wire         done_mat_mul,
    output wire         exception,
    input  logic [9:0]  address_mat_a,
    input  logic [9:0]  address_mat_b,
    input  logic [9:0]  address_mat_c,
    input  logic [7:0]  address_stride_a,
    input  logic [7:0]  address_stride_b,
    input  logic [7:0]  address_stride_c,
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
    wire [9:0]  a_addr_0, a_addr_1, b_addr_0, b_addr_1;
    wire [9:0]  c_addr_0, c_addr_1;
    wire [31:0] a_data_0, a_data_1, b_data_0, b_data_1;
    wire [31:0] c_data_0, c_data_1;
    wire        c_valid_0, c_valid_1;
    wire [3:0]  c_we_0, c_we_1;

    // Suppress a stale write-enable during reset or between operations.
    assign c_we_0 = {4{c_valid_0 && start_mat_mul && !reset}};
    assign c_we_1 = {4{c_valid_1 && start_mat_mul && !reset}};

    // Team Part 3 array; the APB lifecycle replaces the old wrapper FSM.
    matmul_8x8_systolic u_array (
        .clk(clk), .reset(reset), .pe_reset(pe_reset),
        .start_mat_mul(start_mat_mul), .done_mat_mul(done_mat_mul),
        .exception(exception),
        .address_mat_a(address_mat_a), .address_mat_b(address_mat_b),
        .address_mat_c(address_mat_c),
        .address_stride_a(address_stride_a),
        .address_stride_b(address_stride_b),
        .address_stride_c(address_stride_c),
        .a_data_0(a_data_0), .a_data_1(a_data_1),
        .b_data_0(b_data_0), .b_data_1(b_data_1),
        .a_addr_0(a_addr_0), .a_addr_1(a_addr_1),
        .b_addr_0(b_addr_0), .b_addr_1(b_addr_1),
        .c_addr_0(c_addr_0), .c_addr_1(c_addr_1),
        .c_data_0(c_data_0), .c_data_1(c_data_1),
        .c_data_available_0(c_valid_0), .c_data_available_1(c_valid_1)
    );

    lab3_ram matrix_A0 (
        .clk(clk), .addr0(a_addr_0), .d0(32'b0), .we0(4'b0), .q0(a_data_0),
        .addr1(bram_addr_a_ext), .d1(bram_wdata_a_ext[31:0]),
        .we1(bram_we_a_ext[3:0]), .q1(bram_rdata_a_ext[31:0])
    );
    lab3_ram matrix_A1 (
        .clk(clk), .addr0(a_addr_1), .d0(32'b0), .we0(4'b0), .q0(a_data_1),
        .addr1(bram_addr_a_ext), .d1(bram_wdata_a_ext[63:32]),
        .we1(bram_we_a_ext[7:4]), .q1(bram_rdata_a_ext[63:32])
    );
    lab3_ram matrix_B0 (
        .clk(clk), .addr0(b_addr_0), .d0(32'b0), .we0(4'b0), .q0(b_data_0),
        .addr1(bram_addr_b_ext), .d1(bram_wdata_b_ext[31:0]),
        .we1(bram_we_b_ext[3:0]), .q1(bram_rdata_b_ext[31:0])
    );
    lab3_ram matrix_B1 (
        .clk(clk), .addr0(b_addr_1), .d0(32'b0), .we0(4'b0), .q0(b_data_1),
        .addr1(bram_addr_b_ext), .d1(bram_wdata_b_ext[63:32]),
        .we1(bram_we_b_ext[7:4]), .q1(bram_rdata_b_ext[63:32])
    );
    lab3_ram matrix_C0 (
        .clk(clk), .addr0(c_addr_0), .d0(c_data_0), .we0(c_we_0), .q0(),
        .addr1(bram_addr_c_ext), .d1(bram_wdata_c_ext[31:0]),
        .we1(bram_we_c_ext[3:0]), .q1(bram_rdata_c_ext[31:0])
    );
    lab3_ram matrix_C1 (
        .clk(clk), .addr0(c_addr_1), .d0(c_data_1), .we0(c_we_1), .q0(),
        .addr1(bram_addr_c_ext), .d1(bram_wdata_c_ext[63:32]),
        .we1(bram_we_c_ext[7:4]), .q1(bram_rdata_c_ext[63:32])
    );
endmodule
