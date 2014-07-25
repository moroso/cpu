
module MCPU_CORE_stage_fetch(/*AUTOARG*/
   // Outputs
   ft2f_readyin, f2d_readyout, f2d_out_packet, f2d_out_virtpc,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, ft2f_readyout,
   ft2f_in_physpage, ft2f_in_virtpc, f2d_readyin, pipe_flush
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  /* Fetch TLB / Fetch stage interface */
  input ft2f_readyout;
  output ft2f_readyin;
  input [19:0] ft2f_in_physpage;
  input [27:0] ft2f_in_virtpc;

  /* Fetch / Decode stage interface */
  output f2d_readyout;
  input f2d_readyin;
  output [127:0] f2d_out_packet;
  output [27:0] f2d_out_virtpc;

  /* Pipeline flush */
  input pipe_flush;

  /* TODO I$ interface */

  /*AUTOREG*/
  // Beginning of automatic regs (for this module's undeclared outputs)
  reg [127:0]		f2d_out_packet;
  reg [27:0]		f2d_out_virtpc;
  reg			f2d_readyout;
  // End of automatics

  assign ft2f_readyin = ~clkrst_core_rst_n & f2d_readyout & f2d_readyin & ~pipe_flush;

  //TODO the rest of this stage really depends on the I$ interface :/

endmodule
