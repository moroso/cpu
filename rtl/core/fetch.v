
module stage_fetchtlb(/*AUTOARG*/);

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  /* Fetch TLB / Fetch stage interface */
  output ft2f_readyout;
  input ft2f_readyin; 
  output [19:0] ft2f_out_physpage;
  output [27:0] ft2f_out_virtpc;

  /* Pipeline flush and redirect addr */
  input pipe_flush;
  input [27:0] pc2ft_newpc;

  /* ITLB interface */
  output [19:0] ft2itlb_virtpage;
  input ft2itlb_ready;
  input [19:0] ft2itlb_physpage;
  input ft2itlb_pagefault;

  /*AUTOREG*/

  assign ft2itlb_virtpage = ft2f_virtpc[27:16];
  assign ft2f_physpage = ft2itlb_physpage;
  assign ft2f_readyout = clkrst_core_rst_n & ft2itlb_ready & ~pipe_flush;

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
    if(~clkrst_core_rst_n) begin
      ft2f_virtpc <= 20'd0; // What are we doing about mapping at boot?
    end
    /* TODO handle page faults correctly
     * Drain pipeline until fetch, decode, precommit are all ready in, then
     * set cause regs, PL and jump
     */
    else if(ft2itlb_ready) begin
      if(pipe_flush) begin
        ft2f_virtpc <= pc2ft_newpc;
      end
      else if(ft2f_readyout & ft2f_readyin) begin
        // if / when we add a branch prediction the front half goes here
        ft2f_virtpc <= ft2f_virtpc + 28'd1; 
      end
    end
  end

endmodule


module stage_fetch(/*AUTOARG*/);
  
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

  assign ft2f_readyin = ~clkrst_core_rst_n & f2d_readyout & f2d_readyin & ~pipe_flush;
  
  //TODO the rest of this stage really depends on the I$ interface :/

endmodule
