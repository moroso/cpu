module TB_MCPU_core(/*AUTOARG*/
   // Outputs
   int_clear, ft2itlb_virtpage, ft2itlb_valid, pkt_is_break,
   // Inputs
   int_type, int_pending, ft2itlb_ready, ft2itlb_physpage,
   ft2itlb_pagefault, clkrst_core_rst_n, clkrst_core_clk
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		clkrst_core_clk;	// To core of MCPU_core.v
	input		clkrst_core_rst_n;	// To core of MCPU_core.v
	input		ft2itlb_pagefault;	// To core of MCPU_core.v
	input [19:0]	ft2itlb_physpage;	// To core of MCPU_core.v
	input		ft2itlb_ready;		// To core of MCPU_core.v
	input		int_pending;		// To core of MCPU_core.v
	input [3:0]	int_type;		// To core of MCPU_core.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output		ft2itlb_valid;		// From core of MCPU_core.v
	output [19:0]	ft2itlb_virtpage;	// From core of MCPU_core.v
	output		int_clear;		// From core of MCPU_core.v
	// End of automatics
	/*AUTOINOUT*/

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [27:0]	f2ic_paddr;		// From core of MCPU_core.v
	wire		f2ic_valid;		// From core of MCPU_core.v
	wire [127:0]	ic2f_packet;		// From ic of MCPU_CACHE_ic_dummy.v
	wire		ic2f_ready;		// From ic of MCPU_CACHE_ic_dummy.v
	// End of automatics
	
	MCPU_core core(/*AUTOINST*/
		       // Outputs
		       .int_clear	(int_clear),
		       .ft2itlb_valid	(ft2itlb_valid),
		       .ft2itlb_virtpage(ft2itlb_virtpage[19:0]),
		       .f2ic_paddr	(f2ic_paddr[27:0]),
		       .f2ic_valid	(f2ic_valid),
		       // Inputs
		       .clkrst_core_clk	(clkrst_core_clk),
		       .clkrst_core_rst_n(clkrst_core_rst_n),
		       .int_pending	(int_pending),
		       .int_type	(int_type[3:0]),
		       .ft2itlb_ready	(ft2itlb_ready),
		       .ft2itlb_physpage(ft2itlb_physpage[19:0]),
		       .ft2itlb_pagefault(ft2itlb_pagefault),
		       .ic2f_packet	(ic2f_packet[127:0]),
		       .ic2f_ready	(ic2f_ready));
	MCPU_CACHE_ic_dummy ic(/*AUTOINST*/
			       // Outputs
			       .ic2f_ready	(ic2f_ready),
			       .ic2f_packet	(ic2f_packet[127:0]),
			       // Inputs
			       .f2ic_valid	(f2ic_valid),
			       .f2ic_paddr	(f2ic_paddr[27:0]));
	
	output wire pkt_is_break = ic2f_packet[31:0] == 32'hD1183C00;
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
