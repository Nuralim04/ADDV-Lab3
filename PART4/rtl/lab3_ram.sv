`timescale 1ns/1ps

// Synchronous read, true dual-port 1024 x 32 RAM model.
// The RAM contents are deliberately NOT reset. Each write-enable bit controls
// its corresponding byte. Software/testbench must not write A/B while busy,
// or write C while the accelerator owns its write port.
module lab3_ram (
    input  logic        clk,
    input  logic [9:0]  addr0,
    input  logic [31:0] d0,
    input  logic [3:0]  we0,
    output logic [31:0] q0,
    input  logic [9:0]  addr1,
    input  logic [31:0] d1,
    input  logic [3:0]  we1,
    output logic [31:0] q1
);
    logic [31:0] ram [0:1023];

    // Port 0 is the accelerator port. Read-during-write returns old data.
    always @(posedge clk) begin
        for (integer lane = 0; lane < 4; lane = lane + 1)
            if (we0[lane])
                ram[addr0][lane*8 +: 8] <= d0[lane*8 +: 8];
        q0 <= ram[addr0];
    end

    // Port 1 is the external matrix-loading/inspection port.
    always @(posedge clk) begin
        for (integer lane = 0; lane < 4; lane = lane + 1)
            if (we1[lane])
                ram[addr1][lane*8 +: 8] <= d1[lane*8 +: 8];
        q1 <= ram[addr1];
    end
endmodule
