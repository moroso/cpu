module MCPU_MEM_LTC_bram(/*AUTOARG*/
   // Outputs
   rdata,
   // Inputs
   clkrst_mem_clk, waddr, wbe, wdata, re, raddr
   );
	parameter DEPTH = 512;
	parameter DEPTH_BITS = 9;
	parameter WIDTH_BYTES = 32;
	
	input clkrst_mem_clk;
	
	input [DEPTH_BITS-1:0] waddr;
	input [WIDTH_BYTES-1:0] wbe;
	input [WIDTH_BYTES*8-1:0] wdata;
	
	input re;
	input [DEPTH_BITS-1:0] raddr;
	output reg [WIDTH_BYTES*8-1:0] rdata;

	reg [WIDTH_BYTES-1:0][7:0] ram [DEPTH-1:0];
	
	genvar ii;
	generate for (ii = 0; ii < WIDTH_BYTES; ii = ii + 1) begin: wbes
		always @(posedge clkrst_mem_clk)
			if (wbe[ii])
				ram[waddr][ii] <= wdata[(ii+1)*8-1:ii*8];
	end endgenerate
	
	always @(posedge clkrst_mem_clk) begin
		if (re)
			rdata <= ram[raddr];
	end
endmodule

