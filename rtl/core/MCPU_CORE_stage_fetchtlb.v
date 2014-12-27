
module MCPU_CORE_stage_fetchtlb(/*AUTOARG*/
   // Outputs
   ft2f_done, ft2f_out_physpage, ft2f_out_virtpc, ft2f_out_inst_pf,
   ft2itlb_valid, ft2itlb_virtpage,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, ft2f_progress, pipe_flush,
   pc2ft_newpc, paging_on, ft2itlb_ready, ft2itlb_physpage,
   ft2itlb_pagefault
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  /* Fetch TLB / Fetch stage interface */
  output ft2f_done;
  input ft2f_progress; // need this to update PC
  output [19:0] ft2f_out_physpage;
  output [27:0] ft2f_out_virtpc;
  output ft2f_out_inst_pf;

  /* Pipeline flush and redirect addr */
  input pipe_flush;
  input [27:0] pc2ft_newpc;

  /* Paging Enabled */
  input paging_on;

  /* ITLB interface */
  output ft2itlb_valid;
  output [19:0] ft2itlb_virtpage;
  input ft2itlb_ready;
  input [19:0] ft2itlb_physpage;
  input ft2itlb_pagefault;

  /*AUTOREG*/
  // Beginning of automatic regs (for this module's undeclared outputs)
  reg [27:0]		ft2f_out_virtpc;
  // End of automatics

  assign ft2itlb_virtpage = ft2f_out_virtpc[27:8];
  assign ft2itlb_valid = paging_on;
  assign ft2f_out_physpage = paging_on ? ft2itlb_physpage : ft2f_out_virtpc[27:8];
  assign ft2f_done = ~ft2itlb_valid | (ft2itlb_ready & ~pipe_flush);
  assign ft2f_out_inst_pf = ft2itlb_pagefault;


  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
    if(~clkrst_core_rst_n) begin
      ft2f_out_virtpc <= 28'd0; // What are we doing about mapping at boot?
    end
    /* TODO handle page faults correctly
     * Propagate an exception signal down the pipeline, give it priority in PC phase
     * when determining exception cause
     */
    else if(ft2itlb_ready | ~paging_on) begin
      if(pipe_flush) begin
        ft2f_out_virtpc <= pc2ft_newpc;
      end
      else if(ft2f_progress) begin
        // if / when we add branch prediction the front half goes here
        ft2f_out_virtpc <= ft2f_out_virtpc + 28'd1;
      end
    end
  end

endmodule
