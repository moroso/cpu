module FIFO(/*AUTOARG*/
   // Outputs
   full, rdata, empty,
   // Inputs
   clk, rst_n, push, wdata, pop
   );

	parameter               DEPTH = 2;
	parameter               WIDTH = 1;

	input                   clk;
	input                   rst_n;
	
	input                   push;
	input [WIDTH-1:0]       wdata;
	output wire             full;
	
	input                   pop;
	output wire [WIDTH-1:0] rdata;
	output                  empty;
	
	/***/

`include "clog2.vh"

	reg [WIDTH-1:0] mem [DEPTH-1:0];
	reg [clog2(DEPTH)-1:0] rptr;
	reg [clog2(DEPTH)-1:0] wptr;
	
	assign full = wptr == rptr + DEPTH;
	assign empty = (rptr == wptr) && ~push;
	
	/*** Read port ***/
	reg [WIDTH-1:0] mem_rdata;
	always @(posedge clk)
		mem_rdata <= mem[rptr[clog2(DEPTH)-2:0]];

	reg             mem_bypass;
	reg [WIDTH-1:0] wdata_m1a;
	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			mem_bypass <= 0;
			wdata_m1a <= {WIDTH{1'b0}};
		end else begin
			mem_bypass <= rptr == wptr /* i.e., empty */;
			wdata_m1a <= wdata;
		end
	
	assign rdata = mem_bypass ? wdata_m1a : mem_rdata;
	
	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			rptr <= {clog2(DEPTH){1'b0}};
		end else begin
			if (pop && !empty)
				rptr <= rptr + {{clog2(DEPTH)-1{1'b0}}, 1'b1};
		end
	
	/*** Write port ***/
	always @(posedge clk)
		if (push && !full)
			mem[wptr[clog2(DEPTH)-2:0]] <= wdata;
	
	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			wptr <= {clog2(DEPTH){1'b0}};
		end else begin
			if (push && !full)
				wptr <= wptr + {{clog2(DEPTH)-1{1'b0}}, 1'b1};
		end

endmodule
