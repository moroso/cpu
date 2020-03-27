module MCPU_CORE_stage_dtlb(/*AUTOARG*/
  // Outputs
  dtlb2pc_paddr, dtlb2pc_pf, dtlb_addr, dtlb_re,
  // Inputs
  clkrst_core_clk, clkrst_core_rst_n, d2dtlb_vaddr, d2dtlb_oper_type,
  user_mode, dtlb_flags, dtlb_phys_addr, dtlb_ready, progress
  );

`include "oper_type.vh"

   input clkrst_core_clk, clkrst_core_rst_n;

   input [31:0] d2dtlb_vaddr;
   input [1:0] 	d2dtlb_oper_type;
  output [31:0] dtlb2pc_paddr;
   output reg	     dtlb2pc_pf;
   input 	     user_mode;

  // tlb interface
  output [31:12]     dtlb_addr;
  output 	     dtlb_re;

  input [3:0] 	     dtlb_flags;
  input [31:12]      dtlb_phys_addr;
  input 	     dtlb_ready;

  input 	     progress;

  assign dtlb_re = (d2dtlb_oper_type == OPER_TYPE_LSU) & progress;
  assign dtlb_addr = d2dtlb_vaddr[31:12];

  assign dtlb2pc_paddr = {dtlb_phys_addr, prev_offs}; // TODO: lower bits!

  reg [11:0] 	     prev_offs;

   always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
      if (~clkrst_core_rst_n) begin
	prev_offs <= 0;
	dtlb2pc_pf <= 0;
      end else if (progress) begin
	prev_offs <= d2dtlb_vaddr[11:0];
	dtlb2pc_pf <= 0; // TODO: page faults.
      end
   end

endmodule
