module TB_MCPU_MEM_arb(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_write_req_0, ltc2mc_avl_wdata_0, ltc2mc_avl_size_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_burstbegin_0, ltc2mc_avl_be_0,
   ltc2mc_avl_addr_0, cli2arb_rdata, cli2_stall, cli2_rvalid,
   cli1_stall, cli1_rvalid, cli0_stall, cli0_rvalid,
   // Inputs
   ltc2mc_avl_ready_0, ltc2mc_avl_rdata_valid_0, ltc2mc_avl_rdata_0,
   clkrst_mem_rst_n, clkrst_mem_clk, cli2_wdata, cli2_wbe, cli2_valid,
   cli2_opcode, cli2_addr, cli1_wdata, cli1_wbe, cli1_valid,
   cli1_opcode, cli1_addr, cli0_wdata, cli0_wbe, cli0_valid,
   cli0_opcode, cli0_addr
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input [31:5]	cli0_addr;		// To arb of MCPU_MEM_arb.v
	input [2:0]	cli0_opcode;		// To arb of MCPU_MEM_arb.v
	input		cli0_valid;		// To arb of MCPU_MEM_arb.v
	input [31:0]	cli0_wbe;		// To arb of MCPU_MEM_arb.v
	input [255:0]	cli0_wdata;		// To arb of MCPU_MEM_arb.v
	input [31:5]	cli1_addr;		// To arb of MCPU_MEM_arb.v
	input [2:0]	cli1_opcode;		// To arb of MCPU_MEM_arb.v
	input		cli1_valid;		// To arb of MCPU_MEM_arb.v
	input [31:0]	cli1_wbe;		// To arb of MCPU_MEM_arb.v
	input [255:0]	cli1_wdata;		// To arb of MCPU_MEM_arb.v
	input [31:5]	cli2_addr;		// To arb of MCPU_MEM_arb.v
	input [2:0]	cli2_opcode;		// To arb of MCPU_MEM_arb.v
	input		cli2_valid;		// To arb of MCPU_MEM_arb.v
	input [31:0]	cli2_wbe;		// To arb of MCPU_MEM_arb.v
	input [255:0]	cli2_wdata;		// To arb of MCPU_MEM_arb.v
	input		clkrst_mem_clk;		// To arb of MCPU_MEM_arb.v, ...
	input		clkrst_mem_rst_n;	// To arb of MCPU_MEM_arb.v, ...
	input [127:0]	ltc2mc_avl_rdata_0;	// To ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_rdata_valid_0;// To ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_ready_0;	// To ltc of MCPU_MEM_ltc.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output		cli0_rvalid;		// From arb of MCPU_MEM_arb.v
	output		cli0_stall;		// From arb of MCPU_MEM_arb.v
	output		cli1_rvalid;		// From arb of MCPU_MEM_arb.v
	output		cli1_stall;		// From arb of MCPU_MEM_arb.v
	output		cli2_rvalid;		// From arb of MCPU_MEM_arb.v
	output		cli2_stall;		// From arb of MCPU_MEM_arb.v
	output [255:0]	cli2arb_rdata;		// From arb of MCPU_MEM_arb.v
	output [24:0]	ltc2mc_avl_addr_0;	// From ltc of MCPU_MEM_ltc.v
	output [15:0]	ltc2mc_avl_be_0;	// From ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_burstbegin_0;// From ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_read_req_0;	// From ltc of MCPU_MEM_ltc.v
	output [4:0]	ltc2mc_avl_size_0;	// From ltc of MCPU_MEM_ltc.v
	output [127:0]	ltc2mc_avl_wdata_0;	// From ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_write_req_0;	// From ltc of MCPU_MEM_ltc.v
	// End of automatics
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:5]	arb2ltc_addr;		// From arb of MCPU_MEM_arb.v
	wire [2:0]	arb2ltc_opcode;		// From arb of MCPU_MEM_arb.v
	wire [255:0]	arb2ltc_rdata;		// From ltc of MCPU_MEM_ltc.v
	wire		arb2ltc_rvalid;		// From ltc of MCPU_MEM_ltc.v
	wire		arb2ltc_stall;		// From ltc of MCPU_MEM_ltc.v
	wire		arb2ltc_valid;		// From arb of MCPU_MEM_arb.v
	wire [31:0]	arb2ltc_wbe;		// From arb of MCPU_MEM_arb.v
	wire [255:0]	arb2ltc_wdata;		// From arb of MCPU_MEM_arb.v
	// End of automatics
	
	/* MCPU_MEM_arb AUTO_TEMPLATE(
		.cli2arb_stall({cli2_stall, cli1_stall, cli0_stall}),
		.cli2arb_rvalid({cli2_rvalid, cli1_rvalid, cli0_rvalid}),
		
		.cli2arb_valid({cli2_valid, cli1_valid, cli0_valid}),
		.cli2arb_opcode({cli2_opcode[2:0], cli1_opcode[2:0], cli0_opcode[2:0]}),
		.cli2arb_addr({cli2_addr[31:5], cli1_addr[31:5], cli0_addr[31:5]}),
		.cli2arb_wdata({cli2_wdata[255:0], cli1_wdata[255:0], cli0_wdata[255:0]}),
		.cli2arb_wbe({cli2_wbe[31:0], cli1_wbe[31:0], cli0_wbe[31:0]}),
		); */
	MCPU_MEM_arb #(.CLIENTS(3), .CLIENTS_BITS(2))
		arb(/*AUTOINST*/
		    // Outputs
		    .arb2ltc_valid	(arb2ltc_valid),
		    .arb2ltc_opcode	(arb2ltc_opcode[2:0]),
		    .arb2ltc_addr	(arb2ltc_addr[31:5]),
		    .arb2ltc_wdata	(arb2ltc_wdata[255:0]),
		    .arb2ltc_wbe	(arb2ltc_wbe[31:0]),
		    .cli2arb_stall	({cli2_stall, cli1_stall, cli0_stall}), // Templated
		    .cli2arb_rdata	(cli2arb_rdata[255:0]),
		    .cli2arb_rvalid	({cli2_rvalid, cli1_rvalid, cli0_rvalid}), // Templated
		    // Inputs
		    .clkrst_mem_clk	(clkrst_mem_clk),
		    .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		    .arb2ltc_stall	(arb2ltc_stall),
		    .arb2ltc_rdata	(arb2ltc_rdata[255:0]),
		    .arb2ltc_rvalid	(arb2ltc_rvalid),
		    .cli2arb_valid	({cli2_valid, cli1_valid, cli0_valid}), // Templated
		    .cli2arb_opcode	({cli2_opcode[2:0], cli1_opcode[2:0], cli0_opcode[2:0]}), // Templated
		    .cli2arb_addr	({cli2_addr[31:5], cli1_addr[31:5], cli0_addr[31:5]}), // Templated
		    .cli2arb_wdata	({cli2_wdata[255:0], cli1_wdata[255:0], cli0_wdata[255:0]}), // Templated
		    .cli2arb_wbe	({cli2_wbe[31:0], cli1_wbe[31:0], cli0_wbe[31:0]})); // Templated

	MCPU_MEM_ltc ltc(/*AUTOINST*/
			 // Outputs
			 .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
			 .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
			 .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
			 .ltc2mc_avl_read_req_0	(ltc2mc_avl_read_req_0),
			 .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
			 .ltc2mc_avl_wdata_0	(ltc2mc_avl_wdata_0[127:0]),
			 .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
			 .arb2ltc_rdata		(arb2ltc_rdata[255:0]),
			 .arb2ltc_rvalid	(arb2ltc_rvalid),
			 .arb2ltc_stall		(arb2ltc_stall),
			 // Inputs
			 .clkrst_mem_clk	(clkrst_mem_clk),
			 .clkrst_mem_rst_n	(clkrst_mem_rst_n),
			 .ltc2mc_avl_rdata_0	(ltc2mc_avl_rdata_0[127:0]),
			 .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
			 .ltc2mc_avl_ready_0	(ltc2mc_avl_ready_0),
			 .arb2ltc_valid		(arb2ltc_valid),
			 .arb2ltc_opcode	(arb2ltc_opcode[2:0]),
			 .arb2ltc_addr		(arb2ltc_addr[31:5]),
			 .arb2ltc_wdata		(arb2ltc_wdata[255:0]),
			 .arb2ltc_wbe		(arb2ltc_wbe[31:0]));
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
