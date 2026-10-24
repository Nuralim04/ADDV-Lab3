`timescale 1ns/1ns

`define DWIDTH                 8
`define AWIDTH                10
`define MEM_SIZE              1024

`define MAT_MUL_SIZE          4
`define MASK_WIDTH            4
`define LOG2_MAT_MUL_SIZE     2

`define BB_MAT_MUL_SIZE       `MAT_MUL_SIZE
//`define NUM_CYCLES_IN_MAC     3
`define MEM_ACCESS_LATENCY    1
`define REG_DATAWIDTH         32
`define REG_ADDRWIDTH         8
`define ADDR_STRIDE_WIDTH     8
`define MAX_BITS_POOL         3


//////////////////////////////////////////////////////////////////////
// Matrix Multiplication Module
// 8x8 matrix multiplier with:
//   2 RAMs for Matrix A
//   2 RAMs for Matrix B
//   2 RAMs for Matrix C
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


    //////////////////////////////////////////////////////////////////
    // External interface - Matrix A RAM 0
    //////////////////////////////////////////////////////////////////

    input  logic [`AWIDTH-1:0]                bram_addr_a0_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_a0_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_a0_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_a0_ext,


    //////////////////////////////////////////////////////////////////
    // External interface - Matrix A RAM 1
    //////////////////////////////////////////////////////////////////

    input  logic [`AWIDTH-1:0]                bram_addr_a1_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_a1_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_a1_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_a1_ext,


    //////////////////////////////////////////////////////////////////
    // External interface - Matrix B RAM 0
    //////////////////////////////////////////////////////////////////

    input  logic [`AWIDTH-1:0]                bram_addr_b0_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_b0_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_b0_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_b0_ext,


    //////////////////////////////////////////////////////////////////
    // External interface - Matrix B RAM 1
    //////////////////////////////////////////////////////////////////

    input  logic [`AWIDTH-1:0]                bram_addr_b1_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_b1_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_b1_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_b1_ext,


    //////////////////////////////////////////////////////////////////
    // External interface - Matrix C RAM 0
    //////////////////////////////////////////////////////////////////

    input  logic [`AWIDTH-1:0]                bram_addr_c0_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_c0_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_c0_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_c0_ext,


    //////////////////////////////////////////////////////////////////
    // External interface - Matrix C RAM 1
    //////////////////////////////////////////////////////////////////

    input  logic [`AWIDTH-1:0]                bram_addr_c1_ext,
    output wire  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_c1_ext,
    input  logic [`MAT_MUL_SIZE*`DWIDTH-1:0]  bram_wdata_c1_ext,
    input  logic [`MASK_WIDTH-1:0]            bram_we_c1_ext,


    //////////////////////////////////////////////////////////////////
    // Control
    //////////////////////////////////////////////////////////////////

    input  logic                              start,
    output wire                               done,

    // Combined FP8 exception from complete 8x8 array
    output wire                               exception
);


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals - Matrix A RAM 0
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_a0;
    wire [4*`DWIDTH-1:0]      bram_rdata_a0;
    wire [4*`DWIDTH-1:0]      bram_wdata_a0;
    wire [`MASK_WIDTH-1:0]    bram_we_a0;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals - Matrix A RAM 1
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_a1;
    wire [4*`DWIDTH-1:0]      bram_rdata_a1;
    wire [4*`DWIDTH-1:0]      bram_wdata_a1;
    wire [`MASK_WIDTH-1:0]    bram_we_a1;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals - Matrix B RAM 0
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_b0;
    wire [4*`DWIDTH-1:0]      bram_rdata_b0;
    wire [4*`DWIDTH-1:0]      bram_wdata_b0;
    wire [`MASK_WIDTH-1:0]    bram_we_b0;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals - Matrix B RAM 1
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_b1;
    wire [4*`DWIDTH-1:0]      bram_rdata_b1;
    wire [4*`DWIDTH-1:0]      bram_wdata_b1;
    wire [`MASK_WIDTH-1:0]    bram_we_b1;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals - Matrix C RAM 0
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_c0;
    wire [4*`DWIDTH-1:0]      bram_rdata_c0;
    wire [4*`DWIDTH-1:0]      bram_wdata_c0;
    wire [`MASK_WIDTH-1:0]    bram_we_c0;


    //////////////////////////////////////////////////////////////////
    // Internal BRAM signals - Matrix C RAM 1
    //////////////////////////////////////////////////////////////////

    wire [`AWIDTH-1:0]        bram_addr_c1;
    wire [4*`DWIDTH-1:0]      bram_rdata_c1;
    wire [4*`DWIDTH-1:0]      bram_wdata_c1;
    wire [`MASK_WIDTH-1:0]    bram_we_c1;


    //////////////////////////////////////////////////////////////////
    // Control signals
    //////////////////////////////////////////////////////////////////

    logic [3:0] state;
    logic       start_mat_mul;

    wire done_mat_mul;

    wire c_data_available_0;
    wire c_data_available_1;


    //////////////////////////////////////////////////////////////////
    // Matrix A - RAM 0
    //////////////////////////////////////////////////////////////////

    ram matrix_A0 (
        .addr0 (bram_addr_a0),
        .d0    (bram_wdata_a0),
        .we0   (bram_we_a0),
        .q0    (bram_rdata_a0),

        .addr1 (bram_addr_a0_ext),
        .d1    (bram_wdata_a0_ext),
        .we1   (bram_we_a0_ext),
        .q1    (bram_rdata_a0_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // Matrix A - RAM 1
    //////////////////////////////////////////////////////////////////

    ram matrix_A1 (
        .addr0 (bram_addr_a1),
        .d0    (bram_wdata_a1),
        .we0   (bram_we_a1),
        .q0    (bram_rdata_a1),

        .addr1 (bram_addr_a1_ext),
        .d1    (bram_wdata_a1_ext),
        .we1   (bram_we_a1_ext),
        .q1    (bram_rdata_a1_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // Matrix B - RAM 0
    //////////////////////////////////////////////////////////////////

    ram matrix_B0 (
        .addr0 (bram_addr_b0),
        .d0    (bram_wdata_b0),
        .we0   (bram_we_b0),
        .q0    (bram_rdata_b0),

        .addr1 (bram_addr_b0_ext),
        .d1    (bram_wdata_b0_ext),
        .we1   (bram_we_b0_ext),
        .q1    (bram_rdata_b0_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // Matrix B - RAM 1
    //////////////////////////////////////////////////////////////////

    ram matrix_B1 (
        .addr0 (bram_addr_b1),
        .d0    (bram_wdata_b1),
        .we0   (bram_we_b1),
        .q0    (bram_rdata_b1),

        .addr1 (bram_addr_b1_ext),
        .d1    (bram_wdata_b1_ext),
        .we1   (bram_we_b1_ext),
        .q1    (bram_rdata_b1_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // Matrix C - RAM 0
    //////////////////////////////////////////////////////////////////

    ram matrix_C0 (
        .addr0 (bram_addr_c0),
        .d0    (bram_wdata_c0),
        .we0   (bram_we_c0),
        .q0    (bram_rdata_c0),

        .addr1 (bram_addr_c0_ext),
        .d1    (bram_wdata_c0_ext),
        .we1   (bram_we_c0_ext),
        .q1    (bram_rdata_c0_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // Matrix C - RAM 1
    //////////////////////////////////////////////////////////////////

    ram matrix_C1 (
        .addr0 (bram_addr_c1),
        .d0    (bram_wdata_c1),
        .we0   (bram_we_c1),
        .q0    (bram_rdata_c1),

        .addr1 (bram_addr_c1_ext),
        .d1    (bram_wdata_c1_ext),
        .we1   (bram_we_c1_ext),
        .q1    (bram_rdata_c1_ext),

        .clk   (clk)
    );


    //////////////////////////////////////////////////////////////////
    // FSM
    //////////////////////////////////////////////////////////////////

    always_ff @(posedge clk) begin

        if (resetn == 1'b0) begin
            state         <= 4'b0000;
            start_mat_mul <= 1'b0;
        end

        else begin

            case (state)

                // IDLE
                4'b0000: begin
                    start_mat_mul <= 1'b0;

                    if (start == 1'b1)
                        state <= 4'b0001;
                    else
                        state <= 4'b0000;
                end


                // Start multiplication
                4'b0001: begin
                    start_mat_mul <= 1'b1;
                    state         <= 4'b1010;
                end


                // Wait for completion
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
                    state         <= 4'b0000;
                    start_mat_mul <= 1'b0;
                end

            endcase
        end
    end


    assign done = done_mat_mul;


    //////////////////////////////////////////////////////////////////
    // Matrix A RAMs are read-only from the multiplier
    //////////////////////////////////////////////////////////////////

    assign bram_wdata_a0 = 32'b0;
    assign bram_we_a0    = 4'b0000;

    assign bram_wdata_a1 = 32'b0;
    assign bram_we_a1    = 4'b0000;


    //////////////////////////////////////////////////////////////////
    // Matrix B RAMs are read-only from the multiplier
    //////////////////////////////////////////////////////////////////

    assign bram_wdata_b0 = 32'b0;
    assign bram_we_b0    = 4'b0000;

    assign bram_wdata_b1 = 32'b0;
    assign bram_we_b1    = 4'b0000;


    //////////////////////////////////////////////////////////////////
    // Matrix C write enables
    //////////////////////////////////////////////////////////////////

    assign bram_we_c0 =
        (c_data_available_0) ? 4'b1111 : 4'b0000;

    assign bram_we_c1 =
        (c_data_available_1) ? 4'b1111 : 4'b0000;


    //////////////////////////////////////////////////////////////////
    // Reset conversion
    //////////////////////////////////////////////////////////////////

    wire reset;
    wire pe_reset;

    assign reset    = ~resetn;
    assign pe_reset = ~pe_resetn;


    //////////////////////////////////////////////////////////////////
    // 8x8 systolic matrix multiplier
    //////////////////////////////////////////////////////////////////

    matmul_8x8_systolic u_matmul_8x8 (

        .clk                  (clk),
        .reset                (reset),
        .pe_reset             (pe_reset),
        .start_mat_mul        (start_mat_mul),

        .done_mat_mul         (done_mat_mul),

        .address_mat_a        (address_mat_a),
        .address_mat_b        (address_mat_b),
        .address_mat_c        (address_mat_c),

        .address_stride_a     (address_stride_a),
        .address_stride_b     (address_stride_b),
        .address_stride_c     (address_stride_c),


        //////////////////////////////////////////////////////////////
        // A RAM data
        //////////////////////////////////////////////////////////////

        .a_data_0             (bram_rdata_a0),
        .a_data_1             (bram_rdata_a1),


        //////////////////////////////////////////////////////////////
        // B RAM data
        //////////////////////////////////////////////////////////////

        .b_data_0             (bram_rdata_b0),
        .b_data_1             (bram_rdata_b1),


        //////////////////////////////////////////////////////////////
        // C RAM data
        //////////////////////////////////////////////////////////////

        .c_data_0             (bram_wdata_c0),
        .c_data_1             (bram_wdata_c1),


        //////////////////////////////////////////////////////////////
        // A RAM addresses
        //////////////////////////////////////////////////////////////

        .a_addr_0             (bram_addr_a0),
        .a_addr_1             (bram_addr_a1),


        //////////////////////////////////////////////////////////////
        // B RAM addresses
        //////////////////////////////////////////////////////////////

        .b_addr_0             (bram_addr_b0),
        .b_addr_1             (bram_addr_b1),


        //////////////////////////////////////////////////////////////
        // C RAM addresses
        //////////////////////////////////////////////////////////////

        .c_addr_0             (bram_addr_c0),
        .c_addr_1             (bram_addr_c1),


        //////////////////////////////////////////////////////////////
        // C write-valid signals
        //////////////////////////////////////////////////////////////

        .c_data_available_0   (c_data_available_0),
        .c_data_available_1   (c_data_available_1),


        //////////////////////////////////////////////////////////////
        // Combined FP8 exception
        //////////////////////////////////////////////////////////////

        .exception            (exception)
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


endmodule 