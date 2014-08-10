module TB_MCPU_core(/*AUTOARG*/
   // Outputs
   int_clear, pkt_is_break,
   // Inputs
   clkrst_core_rst_n, clkrst_core_clk
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		clkrst_core_clk;	// To core of MCPU_core.v
	input		clkrst_core_rst_n;	// To core of MCPU_core.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output		int_clear;		// From core of MCPU_core.v
	// End of automatics
	/*AUTOINOUT*/

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [27:0]	f2ic_paddr /* verilator public */;		// From core of MCPU_core.v
	wire		f2ic_valid /* verilator public */;		// From core of MCPU_core.v
	wire		ft2itlb_pagefault;	// From tlb of MCPU_CACHE_tlb_dummy.v
	wire [19:0]	ft2itlb_physpage;	// From tlb of MCPU_CACHE_tlb_dummy.v
	wire		ft2itlb_ready;		// From tlb of MCPU_CACHE_tlb_dummy.v
	wire		ft2itlb_valid;		// From core of MCPU_core.v
	wire [19:0]	ft2itlb_virtpage;	// From core of MCPU_core.v
	wire [127:0]	ic2f_packet /* verilator public */;		// From ic of MCPU_CACHE_ic_dummy.v
	wire		ic2f_ready /* verilator public */;		// From ic of MCPU_CACHE_ic_dummy.v
	// End of automatics

	wire int_pending = 0;
	wire [3:0] int_type = 0;
	wire int_clear;

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

	MCPU_CACHE_tlb_dummy tlb(/*AUTOINST*/
				 // Outputs
				 .ft2itlb_pagefault	(ft2itlb_pagefault),
				 .ft2itlb_physpage	(ft2itlb_physpage[19:0]),
				 .ft2itlb_ready		(ft2itlb_ready),
				 // Inputs
				 .ft2itlb_valid		(ft2itlb_valid),
				 .ft2itlb_virtpage	(ft2itlb_virtpage[19:0]));
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
