
module MCPU_CORE_stage_fetch(/*AUTOARG*/
   // Outputs
   f2d_out_virtpc, f2d_in_inst_pf, f_ready_out, f_valid_out,
   f2ic_vaddr, f2ic_valid,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, pc2f_newpc, f_out_ok,
   f_valid_in, pipe_flush, f2ic_paddr, ic2f_ready
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;


  /* Fetch stage interface */
  input [27:0] pc2f_newpc;

  /* Fetch / Decode stage interface */
  output reg [27:0] f2d_out_virtpc;
  output 	    f2d_in_inst_pf;

  /* Stage signals */
  output 	    f_ready_out;
  output 	    f_valid_out;
  input 	    f_out_ok;
  input 	    f_valid_in;

  /* Pipeline flush */
  input pipe_flush;

  /* I$ interface */
  output [27:0] f2ic_vaddr;
  input [27:0] 	f2ic_paddr;
  output f2ic_valid;
  input ic2f_ready;

  /*AUTOREG*/

  reg 	valid_inprogress;

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
    if(~clkrst_core_rst_n) begin
       f2d_out_virtpc <= 28'd0;
       valid_inprogress <= 0;
    end
    /* TODO handle page faults correctly
     * Propagate an exception signal down the pipeline, give it priority in PC phase
     * when determining exception cause
     */
    else if(pipe_flush) begin
       f2d_out_virtpc <= pc2f_newpc;
       valid_inprogress <= 0;
    end else if(f2ic_valid & ic2f_ready) begin
       // if / when we add branch prediction the front half goes here
       f2d_out_virtpc <= f2d_out_virtpc + 28'd1;
       // valid_inprogress tells us whether a valid read is going on right now.
       valid_inprogress <= f_valid_in;
    end
  end // always @ (posedge clkrst_core_clk, negedge clkrst_core_rst_n)

  assign f2d_in_inst_pf = 0; // TODO!!!

  // Valid output is ready if we had started a read, and it's now done.
  assign f_ready_out = ic2f_ready;
  assign f_valid_out = valid_inprogress & ic2f_ready;

  assign f2ic_valid = f_valid_in & f_out_ok & clkrst_core_rst_n;
  assign f2ic_vaddr = f2d_out_virtpc;

endmodule
