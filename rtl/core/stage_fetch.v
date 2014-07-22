
module stage_fetch(/*AUTOARG*/
   // Outputs
   f2d_done, f2d_out_packet, f2d_out_virtpc, f2ic_paddr, f2ic_valid,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, f_valid, ft2f_progress,
   ft2f_in_physpage, ft2f_in_virtpc, pipe_flush, ic2f_packet,
   ic2f_ready
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  input f_valid;

  /* Fetch TLB / Fetch stage interface */
  input ft2f_progress;
  input [19:0] ft2f_in_physpage;
  input [27:0] ft2f_in_virtpc;

  /* Fetch / Decode stage interface */
  output f2d_done;
  output [127:0] f2d_out_packet;
  output [27:0] f2d_out_virtpc;

  /* Pipeline flush */
  input pipe_flush;

  /* I$ interface */
  output [27:0] f2ic_paddr;
  output f2ic_valid;
  input [127:0] ic2f_packet;
  input ic2f_ready;

  /*AUTOREG*/

  assign f2d_out_virtpc = ft2f_in_virtpc;

  assign f2ic_valid = f_valid;
  assign f2ic_paddr = {ft2f_in_physpage, ft2f_in_virtpc[7:0]};
  assign f2d_out_packet = ic2f_packet;
  assign f2d_done = f2ic_valid & ic2f_ready;


endmodule
