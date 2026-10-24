////////////////////////////////////////////
// Task to write into the configuration
// block of the DUT
////////////////////////////////////////////
task automatic write (
    input logic [`REG_ADDRWIDTH-1:0] addr,
    input logic [`REG_DATAWIDTH-1:0] data
);
begin
    @(negedge clk);

    PSEL   = 1'b1;
    PWRITE = 1'b1;
    PADDR  = addr;
    PWDATA = data;

    @(negedge clk);

    PENABLE = 1'b1;

    @(negedge clk);

    PSEL    = 1'b0;
    PENABLE = 1'b0;
    PWRITE  = 1'b0;
    PADDR   = '0;
    PWDATA  = '0;

    $display(
        "%t: PADDR %h, PWDATA %h",
        $time,
        addr,
        data
    );
end
endtask


////////////////////////////////////////////
// Task to read from the configuration
// block of the DUT
////////////////////////////////////////////
task automatic read (
    input  logic [`REG_ADDRWIDTH-1:0] addr,
    output logic [`REG_DATAWIDTH-1:0] data
);
begin
    @(negedge clk);

    PSEL   = 1'b1;
    PWRITE = 1'b0;
    PADDR  = addr;

    @(negedge clk);

    PENABLE = 1'b1;

    @(negedge clk);

    PSEL    = 1'b0;
    PENABLE = 1'b0;
    data    = PRDATA;
    PADDR   = '0;

    $display(
        "%t: PADDR %h, PRDATA %h",
        $time,
        addr,
        data
    );
end
endtask


////////////////////////////////////////////
// Main testbench routine
////////////////////////////////////////////
initial begin

    // Reset the design
    reset = 1'b1;

    $display("Starting simulation");

    // Bring the design out of reset
    #55;
    reset = 1'b0;

    // Wait for a clock or two
    #30;

    $display("Start the matmul");

    write(`REG_STRT_ADDR, wdata);

    // Add the remaining stimulus here

    $display("Wait until done");

    do begin
        read(`REG_DONE_ADDR, rdata);
        done = rdata[15];
    end
    while (done == 1'b0);

    $display("Finishing simulation");

    // Drain time before ending simulation
    #200;

    $finish;
end