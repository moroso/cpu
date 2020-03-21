module MCPU_CORE_stage_dtlb(/*AUTOARG*/
   // Outputs
   dtlb2pc_paddr, dtlb2pc_pf, d2dtlb_readyin, dtlb2pc_readyout,
   dtlb_re,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, d2dtlb_vaddr, d2dtlb_oper_type,
   user_mode, dtlb2pc_progress
   );

`include "oper_type.vh"

   input clkrst_core_clk, clkrst_core_rst_n;

   input [31:0] d2dtlb_vaddr;
   input [1:0] 	d2dtlb_oper_type;
   output reg [31:0] dtlb2pc_paddr;
   output reg	     dtlb2pc_pf;
   input 	     user_mode;

   // TODO: figure these out.
   output 	 d2dtlb_readyin;
   output 	 dtlb2pc_readyout;

   input 	 dtlb2pc_progress;

   // DTLB interface
   output 	 dtlb_re;

   assign dtlb_re = d2dtlb_oper_type == OPER_TYPE_LSU;

   always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
      if (~clkrst_core_rst_n) begin
	 dtlb2pc_paddr <= 0;
	 dtlb2pc_pf <= 0;
      end else if (dtlb2pc_progress) begin
	 dtlb2pc_paddr <= d2dtlb_vaddr;
	 dtlb2pc_pf <= 0;
      end
   end

endmodule
