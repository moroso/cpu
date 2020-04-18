module MCPU_CORE_stage_dtlb(/*AUTOARG*/
   // Outputs
   dtlb2pc_paddr, dtlb_addr, dtlb_re, dtlb_is_write, dtlb_ready_in,
   dtlb_ready_out, dtlb_valid_out,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, d2dtlb_vaddr, d2dtlb_oper_type,
   user_mode, pipe_flush, dtlb_flags, dtlb_phys_addr, dtlb_ready,
   dtlb_valid_in, dtlb_out_ok, d2dtlb_memop_type
   );

`include "oper_type.vh"

  input clkrst_core_clk, clkrst_core_rst_n;

  input [31:0] d2dtlb_vaddr;
  input [1:0]  d2dtlb_oper_type;
  output [31:0] dtlb2pc_paddr;
  input 	user_mode;
  input 	pipe_flush;

  // tlb interface
  output [31:12] dtlb_addr;
  output 	 dtlb_re;
  output 	 dtlb_is_write;

  input [3:0] 	 dtlb_flags;
  input [31:12]  dtlb_phys_addr;
  input 	 dtlb_ready;

  // Stage signals
  output 	 dtlb_ready_in;
  output 	 dtlb_ready_out;
  output 	 dtlb_valid_out;
  input 	 dtlb_valid_in;
  input 	 dtlb_out_ok;
  input [2:0]	 d2dtlb_memop_type;

  reg [11:0] 	 prev_offs;
  reg 		 prev_valid;

  assign dtlb_addr = d2dtlb_vaddr[31:12];

  assign dtlb2pc_paddr = {dtlb_phys_addr, prev_offs};

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	prev_offs <= 0;
	prev_valid <= 0;
     end else if (pipe_flush) begin
	prev_valid <= 0;
     end else if (dtlb_ready & dtlb_out_ok) begin
	prev_offs <= d2dtlb_vaddr[11:0];
	prev_valid <= dtlb_valid_in & dtlb_re;
     end
  end // always @ (posedge clkrst_core_clk or negedge clkrst_core_rst_n)

  assign dtlb_valid_out = dtlb_ready & prev_valid;
  assign dtlb_ready_out = dtlb_ready;
  assign dtlb_ready_in = ~dtlb_valid_in | dtlb_out_ok;

  // We want to perform a read only if we have something to read, and it's okay to
  // replace the outputs.
  assign dtlb_re = (d2dtlb_oper_type == OPER_TYPE_LSU) & dtlb_valid_in & dtlb_out_ok;

  // Bit 2 is set on exactly the writes.
  assign dtlb_is_write = d2dtlb_memop_type[2];
endmodule
