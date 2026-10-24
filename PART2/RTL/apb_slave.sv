`define REG_ADDRWIDTH 10
`define REG_DATAWIDTH 5
`define REG_STRT_ADDR  10'd1
`define REG_DONE_ADDR  10'd2

module apb_slave (
    input  logic                         PCLK,
    input  logic                         PRESETn,
    input  logic [`REG_ADDRWIDTH-1:0]    PADDR,
    input  logic                         PWRITE,
    input  logic                         PSEL,
    input  logic                         PENABLE,
    input  logic [`REG_DATAWIDTH-1:0]    PWDATA,  

    output logic [`REG_DATAWIDTH-1:0]    PRDATA,  // 5 bits total
    output logic                         PREADY,
    output logic                         start,

    // Add the remaining ports here
    input  logic                         done
);

    // APB controller states
    typedef enum logic [1:0] {
        IDLE         = 2'b00,
        SETUP        = 2'b01,
        READ_ACCESS  = 2'b10,
        WRITE_ACCESS = 2'b11
    } state_t;

    state_t State;

    always_ff @(posedge PCLK) begin

        // Active-low synchronous reset
        if (!PRESETn) begin
            State  <= IDLE;
            PRDATA <= '0;
            PREADY <= 1'b0;
            start  <= 1'b0;

            // Reset the remaining registers here
        end

        else begin
            case (State)

                IDLE: begin
                    // Keep the original IDLE-state logic here
                end

                SETUP: begin
                    // Keep the original SETUP-state logic here
                end

                WRITE_ACCESS: begin
                    if (PWRITE && PENABLE) begin
                        case (PADDR)

                            `REG_STRT_ADDR: begin
                                start <= PWDATA[0];
                            end

                            // Add the remaining writable registers here

                            default: begin
                                // No register selected
                            end

                        endcase
                    end
                end

                READ_ACCESS: begin
                    if (!PWRITE && PENABLE) begin
                        case (PADDR)

                            `REG_DONE_ADDR: begin
                                PRDATA <= {done, 15'b0};  // PRDATA 16 bits ??
                            end

                            // Add the remaining readable registers here

                            default: begin
                                PRDATA <= '0;
                            end

                        endcase
                    end
                end

                default: begin
                    State <= IDLE;
                end

            endcase
        end
    end

endmodule