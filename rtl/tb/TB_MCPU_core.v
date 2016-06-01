module TB_MCPU_core(/*AUTOARG*/
   // Inouts
   clkrst_core_rst_n, clkrst_core_clk,
	memoutput, meminput
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		clkrst_core_clk;	// To core of MCPU_core.v
	input		clkrst_core_rst_n;	// To core of MCPU_core.v
	input [31:0] meminput;
	output [31:0] memoutput;
	// End of automatics

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [27:0]	f2ic_paddr;		// From core of MCPU_core.v
	wire		f2ic_valid;		// From core of MCPU_core.v
	wire		ft2itlb_pagefault;	// From tlb of MCPU_CACHE_tlb_dummy.v
	wire [19:0]	ft2itlb_physpage;	// From tlb of MCPU_CACHE_tlb_dummy.v
	wire		ft2itlb_ready;		// From tlb of MCPU_CACHE_tlb_dummy.v
	wire		ft2itlb_valid;		// From core of MCPU_core.v
	wire [19:0]	ft2itlb_virtpage;	// From core of MCPU_core.v
	wire [127:0]	ic2f_packet;		// From ic of MCPU_CACHE_ic_dummy.v
	wire		ic2f_ready;		// From ic of MCPU_CACHE_ic_dummy.v
	// End of automatics

	wire mem2dc_valid0, mem2dc_valid1;
	wire mem2dc_done0, mem2dc_done1;
	wire [31:0] mem2dc_data0, mem2dc_data1;
	wire [29:0] mem2dc_paddr0, mem2dc_paddr1;
	wire [3:0] mem2dc_write0, mem2dc_write1;
	
	wire [31:0] data_hookup0, data_hookup1;
	assign data_hookup0 = mem2dc_data0;
	assign data_hookup1 = mem2dc_data1;
	
	integer i;
	
	wire int_pending = 0;
	wire [3:0] int_type = 0;
	wire int_clear;
	
	wire [31:0] r0;
	assign memoutput = r0;
	
	/*
	reg [31:0] ram[256];
	
	
	wire [31:0] writemask0, writemask1;
	assign writemask0 = {{8{mem2dc_write0[3]}},{8{mem2dc_write0[2]}},{8{mem2dc_write0[1]}},{8{mem2dc_write0[0]}}};
	assign writemask1 = {{8{mem2dc_write1[3]}},{8{mem2dc_write1[2]}},{8{mem2dc_write1[1]}},{8{mem2dc_write1[0]}}};
	/*
	always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
		if(~clkrst_core_rst_n) begin
			for(i=0; i < 256; i=i+1) begin
				ram[i] <= 32'b0;
			end
		end
				
		else begin
			if(mem2dc_valid0) begin
				if(|mem2dc_write0) begin
					ram[mem2dc_paddr0] <= (mem2dc_data0 & writemask0) | (ram[mem2dc_paddr0] & ~writemask0);
					mem2dc_done0 <= 1;
					mem2dc_data0 <= 32'bZ;
				end
				else begin
					mem2dc_done0 <= 1;
					mem2dc_data0 <= ram[mem2dc_paddr0];
				end
			end
			else begin
				mem2dc_done0 <= 0;
				mem2dc_data0 <= 32'bZ;
			end
			if(mem2dc_valid1) begin
				if(|mem2dc_write1) begin
					ram[mem2dc_paddr1] <= (mem2dc_data1 & writemask1) | (ram[mem2dc_paddr1] & ~writemask1);
					mem2dc_done1 <= 1;
					mem2dc_data1 <= 32'bZ;
				end
				else begin
					mem2dc_done1 <= 1;
					mem2dc_data1 <= ram[mem2dc_paddr1];
				end
			end
			else begin
				mem2dc_done1 <= 0;
				mem2dc_data1 <= 32'bZ;
			end
		end
	end
	*/				

	assign mem2dc_data0 = 32'bZ;
	assign mem2dc_data1 = 32'bZ;
	assign mem2dc_done0 = 0;
	assign mem2dc_done1 = 0;
	
	MCPU_core core(/*AUTOINST*/
		       // Outputs
		       .int_clear	(int_clear),
		       .mem2dc_paddr0	(mem2dc_paddr0[29:0]),
		       .mem2dc_write0	(mem2dc_write0[3:0]),
		       .mem2dc_valid0	(mem2dc_valid0),
		       .mem2dc_paddr1	(mem2dc_paddr1[29:0]),
		       .mem2dc_write1	(mem2dc_write1[3:0]),
		       .mem2dc_valid1	(mem2dc_valid1),
		       .ft2itlb_valid	(ft2itlb_valid),
		       .ft2itlb_virtpage(ft2itlb_virtpage[19:0]),
		       .f2ic_paddr	(f2ic_paddr[27:0]),
		       .f2ic_valid	(f2ic_valid),
		       // Inouts
		       .mem2dc_data0	(data_hookup0[31:0]),
		       .mem2dc_data1	(data_hookup1[31:0]),
		       // Inputs
		       .clkrst_core_clk	(clkrst_core_clk),
		       .clkrst_core_rst_n(clkrst_core_rst_n),
		       .int_pending	(int_pending),
		       .int_type	(int_type[3:0]),
		       .mem2dc_done0	(mem2dc_done0),
		       .mem2dc_done1	(mem2dc_done1),
		       .ft2itlb_ready	(ft2itlb_ready),
		       .ft2itlb_physpage(ft2itlb_physpage[19:0]),
		       .ft2itlb_pagefault(ft2itlb_pagefault),
		       .ic2f_packet	(ic2f_packet[127:0]),
		       .ic2f_ready	(ic2f_ready),
				 .r0(r0), .r31(meminput));

	MCPU_CACHE_ic_dummy ic(/*AUTOINST*/
			       // Outputs
			       .ic2f_ready	(ic2f_ready),
			       .ic2f_packet	(ic2f_packet[127:0]),
			       // Inputs
			       .f2ic_valid	(f2ic_valid),
			       .f2ic_paddr	(f2ic_paddr[27:0]));

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
