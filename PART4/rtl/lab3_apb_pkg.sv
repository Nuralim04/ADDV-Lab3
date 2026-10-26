`timescale 1ns/1ps

// APB byte offsets. Each CSR transfers 16 bits, so implemented offsets are even.
package lab3_apb_pkg;
    localparam logic [15:0] REG_CONTROL  = 16'h0000;
    localparam logic [15:0] REG_STATUS   = 16'h0002;
    localparam logic [15:0] REG_FLAGS    = 16'h0004;
    localparam logic [15:0] REG_ADDR_A   = 16'h0010;
    localparam logic [15:0] REG_ADDR_B   = 16'h0012;
    localparam logic [15:0] REG_ADDR_C   = 16'h0014;
    localparam logic [15:0] REG_STRIDE_A = 16'h0016;
    localparam logic [15:0] REG_STRIDE_B = 16'h0018;
    localparam logic [15:0] REG_STRIDE_C = 16'h001a;
endpackage
