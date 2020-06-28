`timescale 1 ps / 1 ps

module MCPU_MEM_LTC_bram(/*AUTOARG*/
   // Outputs
   rdata0, rdata1,
   // Inputs
   clkrst_mem_clk, addr0, addr1, wbe0, wdata0, re0, re1
   );
	parameter DEPTH = 512;
	parameter DEPTH_BITS = 9;
	parameter WIDTH_BYTES = 32;
	
	input clkrst_mem_clk;
	
	input [DEPTH_BITS-1:0] addr0;
	input [DEPTH_BITS-1:0] addr1;
	input [WIDTH_BYTES-1:0] wbe0;
	input [WIDTH_BYTES*8-1:0] wdata0;
	
	input re0;
	input re1;
	output reg [WIDTH_BYTES*8-1:0] rdata0;
	output reg [WIDTH_BYTES*8-1:0] rdata1;

	reg [WIDTH_BYTES*8-1:0] ram [DEPTH-1:0];
	
	genvar ii;
	generate for (ii = 0; ii < WIDTH_BYTES; ii = ii + 1) begin: wbes
		always @(posedge clkrst_mem_clk)
			if (wbe0[ii])
				ram[addr0][ii * 8 +: 8] <= wdata0[(ii+1)*8-1:ii*8];
	end endgenerate
	
	always @(posedge clkrst_mem_clk) begin
		if (re0)
			rdata0 <= ram[addr0];
		if (re1)
			rdata1 <= ram[addr1];
	end
endmodule

