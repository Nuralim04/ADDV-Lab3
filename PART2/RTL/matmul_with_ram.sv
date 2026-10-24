`timescale 1ns/1ns

`define DWIDTH                 8
`define AWIDTH                10
`define MEM_SIZE              1024

`define MAT_MUL_SIZE          4
`define MASK_WIDTH            4
`define LOG2_MAT_MUL_SIZE     2

`define BB_MAT_MUL_SIZE       `MAT_MUL_SIZE
`define NUM_CYCLES_IN_MAC     3
`define MEM_ACCESS_LATENCY    1
`define REG_DATAWIDTH         32
`define REG_ADDRWIDTH         8
`define ADDR_STRIDE_WIDTH     8
`define MAX_BITS_POOL         3


//////////////////////////////////////////////////////////////////////
// Matrix Multiplication Module
// Design containing memories and a 4x4 systolic array
//////////////////////////////////////////////////////////////////////

module matrix_multiplication (

    input  logic                              clk,
    input  logic                              resetn,
    input  logic                              pe_resetn,

    input  logic [`AWIDTH-1:0]                address_mat_a,
    input  logic [`AWIDTH-1:0]                address_mat_b,
    input  logic [`AWIDTH-1:0]                address_mat_c,

    input  logic [`ADDR_STRIDE_WIDTH-1:0]     address_stride_a,
    input  logic [`ADDR_STRIDE_WIDTH-1:0]     address_stride_b,
    input  logic [`ADDR_STRIDE_WIDTH-1:0]     address_stride_c,

    // External interface for Matrix A memory
    input  logic [`AWIDTH-1:0]                bram_addr_a_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_a_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_a_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_a_ext,

    // External interface for Matrix B memory
    input  logic [`AWIDTH-1:0]                bram_addr_b_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_b_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_b_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_b_ext,

    // External interface for Matrix C memory
    input  logic [`AWIDTH-1:0]                bram_addr_c_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_c_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_c_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_c_ext,

    input  logic                              start,
    output wire                               done
);


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals for Matrix A
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_a;
    wire [4*`DWIDTH-1:0]      bram_rdata_a;
    wire [4*`DWIDTH-1:0]      bram_wdata_a;
    wire [`MASK_WIDTH-1:0]    bram_we_a;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals for Matrix B
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_b;
    wire [4*`DWIDTH-1:0]      bram_rdata_b;
    wire [4*`DWIDTH-1:0]      bram_wdata_b;
    wire [`MASK_WIDTH-1:0]    bram_we_b;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals for Matrix C
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_c;
    wire [4*`DWIDTH-1:0]      bram_rdata_c;
    wire [4*`DWIDTH-1:0]      bram_wdata_c;
    wire [`MASK_WIDTH-1:0]    bram_we_c;


    //////////////////////////////////////////////////////////////////
    // Control signals
    //////////////////////////////////////////////////////////////////

    logic [3:0] state;
    logic       start_mat_mul;

    wire done_mat_mul;
    wire c_data_available;


    //////////////////////////////////////////////////////////////////
    // RAM for Matrix A
    //
    // Port 0 interfaces with the matrix-multiplication block.
    // Port 1 interfaces with the external system.
    //////////////////////////////////////////////////////////////////

    ram matrix_A (
        .addr0 (bram_addr_a),
        .d0    (bram_wdata_a),
        .we0   (bram_we_a),
        .q0    (bram_rdata_a),

        .addr1 (bram_addr_a_ext),
        .d1    (bram_wdata_a_ext),
        .we1   (bram_we_a_ext),
        .q1    (bram_rdata_a_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // RAM for Matrix B
    //////////////////////////////////////////////////////////////////

    ram matrix_B (
        .addr0 (bram_addr_b),
        .d0    (bram_wdata_b),
        .we0   (bram_we_b),
        .q0    (bram_rdata_b),

        .addr1 (bram_addr_b_ext),
        .d1    (bram_wdata_b_ext),
        .we1   (bram_we_b_ext),
        .q1    (bram_rdata_b_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // RAM for Matrix C
    //////////////////////////////////////////////////////////////////

    ram matrix_C (
        .addr0 (bram_addr_c),
        .d0    (bram_wdata_c),
        .we0   (bram_we_c),
        .q0    (bram_rdata_c),

        .addr1 (bram_addr_c_ext),
        .d1    (bram_wdata_c_ext),
        .we1   (bram_we_c_ext),
        .q1    (bram_rdata_c_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // FSM used to start the matrix-multiplication operation
    //////////////////////////////////////////////////////////////////

    always_ff @(posedge clk) begin

        if (resetn == 1'b0) begin
            state         <= 4'b0000;
            start_mat_mul <= 1'b0;
        end

        else begin
            case (state)

                4'b0000: begin
                    start_mat_mul <= 1'b0;

                    if (start == 1'b1)
                        state <= 4'b0001;
                    else
                        state <= 4'b0000;
                end


                4'b0001: begin
                    start_mat_mul <= 1'b1;
                    state         <= 4'b1010;
                end


                4'b1010: begin
                    if (done_mat_mul == 1'b1) begin
                        start_mat_mul <= 1'b0;
                        state         <= 4'b0000;
                    end
                    else begin
                        state <= 4'b1010;
                    end
                end


                default: begin
                    state <= 4'b0000;
                end

            endcase
        end
    end


    assign done = done_mat_mul;


    //////////////////////////////////////////////////////////////////
    // Matrix C memory connections
    //
    // bram_addr_c  : Generated by the matrix-multiplication block
    // bram_rdata_c : Not used
    // bram_wdata_c : Generated by the matrix-multiplication block
    // bram_we_c    : Asserted when output data is available
    //////////////////////////////////////////////////////////////////

    assign bram_we_c =
        (c_data_available) ? 4'b1111 : 4'b0000;


    //////////////////////////////////////////////////////////////////
    // Matrix A memory connections
    //
    // Matrix A is read-only from the matrix-multiplication block.
    //////////////////////////////////////////////////////////////////

    assign bram_wdata_a = 32'b0;
    assign bram_we_a    = 4'b0;


    //////////////////////////////////////////////////////////////////
    // Matrix B memory connections
    //
    // Matrix B is read-only from the matrix-multiplication block.
    //////////////////////////////////////////////////////////////////

    assign bram_wdata_b = 32'b0;
    assign bram_we_b    = 4'b0;


    //////////////////////////////////////////////////////////////////
    // Unconnected systolic-array boundary signals
    //////////////////////////////////////////////////////////////////

    wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_out_NC;
    wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_out_NC;
    wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_in_NC;
    wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_in_NC;


    //////////////////////////////////////////////////////////////////
    // Reset conversion
    //////////////////////////////////////////////////////////////////

    wire reset;
    wire pe_reset;

    assign reset    = ~resetn;
    assign pe_reset = ~pe_resetn;


    //////////////////////////////////////////////////////////////////
    // 4x4 systolic matrix-multiplication instance
    //////////////////////////////////////////////////////////////////

    matmul_4x4_systolic u_matmul_4x4 (
        .clk                         (clk),
        .reset                       (reset),
        .pe_reset                    (pe_reset),
        .start_mat_mul               (start_mat_mul),
        .done_mat_mul                (done_mat_mul),

        .address_mat_a               (address_mat_a),
        .address_mat_b               (address_mat_b),
        .address_mat_c               (address_mat_c),

        .address_stride_a            (address_stride_a),
        .address_stride_b            (address_stride_b),
        .address_stride_c            (address_stride_c),

        .a_data                      (bram_rdata_a),
        .b_data                      (bram_rdata_b),

        .a_data_in                   (a_data_in_NC),
        .b_data_in                   (b_data_in_NC),
        .c_data_in                   (
            {`BB_MAT_MUL_SIZE*`DWIDTH{1'b0}}
        ),

        .c_data_out                  (bram_wdata_c),
        .a_data_out                  (a_data_out_NC),
        .b_data_out                  (b_data_out_NC),

        .a_addr                      (bram_addr_a),
        .b_addr                      (bram_addr_b),
        .c_addr                      (bram_addr_c),

        .c_data_available            (c_data_available),

        .validity_mask_a_rows        (4'b1111),
        .validity_mask_a_cols_b_rows (4'b1111),
        .validity_mask_b_cols        (4'b1111),

        .final_mat_mul_size          (8'd4),
        .a_loc                       (8'd0),
        .b_loc                       (8'd0)
    );

endmodule


//////////////////////////////////////////////////////////////////////
// Dual-Port RAM
//////////////////////////////////////////////////////////////////////

module ram (

    input  logic [`AWIDTH-1:0]               addr0,
    input  logic [`MASK_WIDTH*`DWIDTH-1:0]   d0,
    input  logic [`MASK_WIDTH-1:0]           we0,
    output logic [`MASK_WIDTH*`DWIDTH-1:0]   q0,

    input  logic [`AWIDTH-1:0]               addr1,
    input  logic [`MASK_WIDTH*`DWIDTH-1:0]   d1,
    input  logic [`MASK_WIDTH-1:0]           we1,
    output logic [`MASK_WIDTH*`DWIDTH-1:0]   q1,

    input  logic                             clk
);


    //////////////////////////////////////////////////////////////////
    // 1024-entry, 32-bit memory
    //////////////////////////////////////////////////////////////////

    logic [31:0] ram [((1 << `AWIDTH)-1):0];


    //////////////////////////////////////////////////////////////////
    // Port 0
    //////////////////////////////////////////////////////////////////

    always @(posedge clk) begin

        if (|we0 == 1'b1) begin
            ram[addr0] <= d0;
        end

        q0 <= ram[addr0];
    end


    //////////////////////////////////////////////////////////////////
    // Port 1
    //////////////////////////////////////////////////////////////////

    always @(posedge clk) begin

        if (|we1 == 1'b1) begin
            ram[addr1] <= d1;
        end

        q1 <= ram[addr1];
    end

endmodule