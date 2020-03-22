
module MCPU_CORE_stage_fetch(/*AUTOARG*/
   // Outputs
   f2d_done, f2d_out_virtpc, f2d_in_inst_pf, f2ic_vaddr, f2ic_valid,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, f_valid, pc2f_newpc,
   f2d_progress, pipe_flush, f2ic_paddr, ic2f_ready
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  input f_valid;

  /* Fetch stage interface */
  input [27:0] pc2f_newpc;

  /* Fetch / Decode stage interface */
  output f2d_done;
  output reg [27:0] f2d_out_virtpc;
  output 	f2d_in_inst_pf;
  input f2d_progress;

  /* Pipeline flush */
  input pipe_flush;

  /* I$ interface */
  output [27:0] f2ic_vaddr;
  input [27:0] 	f2ic_paddr;
  output f2ic_valid;
  input ic2f_ready;

  /*AUTOREG*/

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
    if(~clkrst_core_rst_n) begin
      f2d_out_virtpc <= 28'd0;
    end
    /* TODO handle page faults correctly
     * Propagate an exception signal down the pipeline, give it priority in PC phase
     * when determining exception cause
     */
    else if(ic2f_ready) begin
      if(pipe_flush) begin
        f2d_out_virtpc <= pc2f_newpc;
      end
      else if(f2d_progress) begin
        // if / when we add branch prediction the front half goes here
        f2d_out_virtpc <= f2d_out_virtpc + 28'd1;
      end
    end
  end

  assign f2d_in_inst_pf = 0; // TODO!!!

  assign f2ic_valid = f_valid & f2d_progress;
  assign f2ic_vaddr = f2d_out_virtpc;
  assign f2d_done = f2ic_valid & ic2f_ready;


endmodule
