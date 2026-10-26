`timescale 1ns/1ps
module team_directed_audit;
logic clk=0, resetn=0, pe_resetn=0, start=0;
wire done, exception;
always #5 clk=~clk;
matrix_multiplication dut(
.clk(clk),.resetn(resetn),.pe_resetn(pe_resetn),.start(start),.done(done),.exception(exception),
.address_mat_a(10'd0),.address_mat_b(10'd0),.address_mat_c(10'd0),
.address_stride_a(8'd1),.address_stride_b(8'd1),.address_stride_c(8'd1),
.bram_addr_a0_ext(10'd0),
.bram_wdata_a0_ext(32'd0),
.bram_we_a0_ext(4'd0),
.bram_rdata_a0_ext(),
.bram_addr_a1_ext(10'd0),
.bram_wdata_a1_ext(32'd0),
.bram_we_a1_ext(4'd0),
.bram_rdata_a1_ext(),
.bram_addr_b0_ext(10'd0),
.bram_wdata_b0_ext(32'd0),
.bram_we_b0_ext(4'd0),
.bram_rdata_b0_ext(),
.bram_addr_b1_ext(10'd0),
.bram_wdata_b1_ext(32'd0),
.bram_we_b1_ext(4'd0),
.bram_rdata_b1_ext(),
.bram_addr_c0_ext(10'd0),
.bram_wdata_c0_ext(32'd0),
.bram_we_c0_ext(4'd0),
.bram_rdata_c0_ext(),
.bram_addr_c1_ext(10'd0),
.bram_wdata_c1_ext(32'd0),
.bram_we_c1_ext(4'd0),
.bram_rdata_c1_ext());
integer count0=0,count1=0,mismatches=0,guards=0;
logic [7:0] a[0:7][0:7],b[0:7][0:7];
logic [31:0] aw0,aw1,bw0,bw1,expected0,expected1;
always @(posedge clk) begin
 if (dut.bram_we_c0 != 0) begin
   count0=count0+1;
   $display("AUDIT C0 WRITE #%0d t=%0t addr=%0d data=%h arraycnt=%0d internalstart=%b done=%b",count0,$time,dut.bram_addr_c0,dut.bram_wdata_c0,dut.u_matmul_8x8.clk_cnt_8x8,dut.start_mat_mul,done);
 end
 if (dut.bram_we_c1 != 0) count1=count1+1;
end
initial begin
 for(integer r=0;r<8;r++) for(integer c=0;c<8;c++) begin
  a[r][c]=(r==c)?8'h30:8'h00;
  b[r][c]=8'h20+r*8+c;
 end
 for(integer k=0;k<8;k++) begin
  for(integer lane=0;lane<4;lane++) begin
   aw0[lane*8+:8]=a[lane][k];aw1[lane*8+:8]=a[lane+4][k];
   bw0[lane*8+:8]=b[k][lane];bw1[lane*8+:8]=b[k][lane+4];
  end
  dut.matrix_A0.ram[k]=aw0;dut.matrix_A1.ram[k]=aw1;
  dut.matrix_B0.ram[k]=bw0;dut.matrix_B1.ram[k]=bw1;
 end
 for(integer k=0;k<16;k++) begin
  dut.matrix_C0.ram[k]=32'hdeadbeef;dut.matrix_C1.ram[k]=32'hdeadbeef;
 end
 repeat(3) @(negedge clk);
 resetn=1;pe_resetn=1;
 repeat(2) @(negedge clk);
 start=1;
 @(posedge done);
 $display("AUDIT DONE t=%0t count0=%0d count1=%0d",$time,count0,count1);
 @(negedge clk);start=0;
 repeat(5) @(negedge clk);
 for(integer c=0;c<8;c++) for(integer lane=0;lane<4;lane++) begin
   if(dut.matrix_C0.ram[c][lane*8+:8]!==b[lane][c]) begin
    mismatches++;$display("AUDIT MISMATCH row=%0d col=%0d got=%h expected=%h",lane,c,dut.matrix_C0.ram[c][lane*8+:8],b[lane][c]);
   end
   if(dut.matrix_C1.ram[c][lane*8+:8]!==b[lane+4][c]) begin
    mismatches++;$display("AUDIT MISMATCH row=%0d col=%0d got=%h expected=%h",lane+4,c,dut.matrix_C1.ram[c][lane*8+:8],b[lane+4][c]);
   end
 end
 for(integer k=8;k<16;k++) begin
  if(dut.matrix_C0.ram[k]!==32'hdeadbeef) begin
   guards++;$display("AUDIT C0 GUARD MODIFIED addr=%0d actual=%h",k,dut.matrix_C0.ram[k]);
  end
  if(dut.matrix_C1.ram[k]!==32'hdeadbeef) begin
   guards++;$display("AUDIT C1 GUARD MODIFIED addr=%0d actual=%h",k,dut.matrix_C1.ram[k]);
  end
 end
 $display("AUDIT SUMMARY numerical_mismatches=%0d guard_words_modified=%0d writes_per_bank=%0d/%0d",mismatches,guards,count0,count1);
 $finish;
end
initial begin #20000;$fatal(1,"AUDIT TIMEOUT");end
endmodule
