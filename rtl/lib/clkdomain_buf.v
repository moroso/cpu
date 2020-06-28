/* Simple (slow) buffer for crossing clock domains.
 * This won't get the data to you anytime soon.
 * Eventually we'll probably want a proper FIFO.
 */

`timescale 1 ps / 1 ps

module clkdomain_buf(/*AUTOARG*/
   // Outputs
   out, out_valid, in_ready,
   // Inputs
   rst_n, out_clk, in, in_clk, in_valid
   );
  parameter WIDTH = 32;
  parameter DEPTH = 2;

  input rst_n;

  output [WIDTH-1:0] out;
  input 	     out_clk;
  output reg 	     out_valid;

  input [WIDTH-1:0]  in;
  input 	     in_clk;
  input 	     in_valid;
  output 	     in_ready;

  reg [WIDTH-1:0]    inbuf;
  reg [WIDTH-1:0]    outbuf;
  reg [DEPTH-1:0]    i2o_signal;
  reg [DEPTH-1:0]    o2i_signal;

  reg 		     i2o_signal0_1a;

  reg 		     i_state;

  assign in_ready = ~i_state & ~o2i_signal[0];
  assign out = outbuf;

  always @(posedge in_clk or negedge rst_n) begin
     if (~rst_n) begin
	i_state <= 0;
	o2i_signal <= 0;
     end else begin
	if (in_valid) begin
	   i_state <= 1;
	   inbuf <= in;
	end else if (o2i_signal[0]) begin
	   i_state <= 0;
	end

	o2i_signal <= {i2o_signal[0], o2i_signal[DEPTH-1:1]};
     end
  end

  always @(posedge out_clk or negedge rst_n) begin
     if (~rst_n) begin
	i2o_signal <= 0;
	i2o_signal0_1a <= 0;
     end else begin
	i2o_signal <= {i_state, i2o_signal[DEPTH-1:1]};
	i2o_signal0_1a <= i2o_signal[0];
	if (i2o_signal[0] & ~i2o_signal0_1a) begin
	   outbuf <= inbuf;
	   out_valid <= 1;
	end else begin
	   out_valid <= 0;
	end
     end
  end
endmodule

`ifdef IVERILOG
module TB_clkdomain_buf();
  reg in_clk;
  reg out_clk;
  reg in_valid;
  reg rst_n;
  reg [32:0] in;

  localparam WIDTH=32;
  localparam DEPTH=16;

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			in_ready;		// From c of clkdomain_buf.v
  wire [WIDTH-1:0]	out;			// From c of clkdomain_buf.v
  wire			out_valid;		// From c of clkdomain_buf.v
  // End of automatics

  initial begin
     in_clk <= 0;
     rst_n <= 1;
     in_valid <= 0;
     out_clk <= 0;

     #10 rst_n <= 0;
     #10 rst_n <= 1;
  end

  always #16 in_clk <= ~in_clk;
  always #10 out_clk <= ~out_clk;

  initial begin
     #100;
     in_valid <= 1;
     in <= 32'habcd6789;
     #20 in_valid <= 0;
     in <= 32'hx;
  end

  initial begin
     $dumpfile("iverilog_out.vcd");
     $dumpvars(0, c);
  end
  initial #10000 $finish();


  clkdomain_buf #(.WIDTH(WIDTH), .DEPTH(DEPTH)) c(/*AUTOINST*/
						  // Outputs
						  .out			(out[WIDTH-1:0]),
						  .out_valid		(out_valid),
						  .in_ready		(in_ready),
						  // Inputs
						  .rst_n		(rst_n),
						  .out_clk		(out_clk),
						  .in			(in[WIDTH-1:0]),
						  .in_clk		(in_clk),
						  .in_valid		(in_valid));
endmodule
`endif
