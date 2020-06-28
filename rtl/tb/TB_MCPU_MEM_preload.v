`timescale 1 ps / 1 ps

module TB_MCPU_MEM_arb(/*AUTOARG*/
   // Outputs
   video2ltc_stall, video2ltc_rvalid, video2ltc_rdata, pre2core_done,
   ltc2mc_avl_write_req_0, ltc2mc_avl_wdata_0, ltc2mc_avl_size_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_burstbegin_0, ltc2mc_avl_be_0,
   ltc2mc_avl_addr_0, cli2arb_rdata, cli0_stall, cli0_rvalid,
   cli0_rdata,
   // Inputs
   video2ltc_re, video2ltc_addr, ltc2mc_avl_ready_0,
   ltc2mc_avl_rdata_valid_0, ltc2mc_avl_rdata_0, clkrst_mem_rst_n,
   clkrst_mem_clk, cli0_wdata, cli0_wbe, cli0_valid, cli0_opcode,
   cli0_addr
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input [31:5]	cli0_addr;		// To arb of MCPU_MEM_arb.v
	input [2:0]	cli0_opcode;		// To arb of MCPU_MEM_arb.v
	input		cli0_valid;		// To arb of MCPU_MEM_arb.v
	input [31:0]	cli0_wbe;		// To arb of MCPU_MEM_arb.v
	input [255:0]	cli0_wdata;		// To arb of MCPU_MEM_arb.v
	input		clkrst_mem_clk;		// To pre of MCPU_MEM_preload.v, ...
	input		clkrst_mem_rst_n;	// To pre of MCPU_MEM_preload.v, ...
	input [127:0]	ltc2mc_avl_rdata_0;	// To ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_rdata_valid_0;// To ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_ready_0;	// To ltc of MCPU_MEM_ltc.v
	input [28:7]	video2ltc_addr;		// To ltc of MCPU_MEM_ltc.v
	input		video2ltc_re;		// To ltc of MCPU_MEM_ltc.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output		cli0_rvalid;		// From arb of MCPU_MEM_arb.v
	output		cli0_stall;		// From arb of MCPU_MEM_arb.v
	output [255:0]	cli2arb_rdata;		// From arb of MCPU_MEM_arb.v
	output [24:0]	ltc2mc_avl_addr_0;	// From ltc of MCPU_MEM_ltc.v
	output [15:0]	ltc2mc_avl_be_0;	// From ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_burstbegin_0;// From ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_read_req_0;	// From ltc of MCPU_MEM_ltc.v
	output [4:0]	ltc2mc_avl_size_0;	// From ltc of MCPU_MEM_ltc.v
	output [127:0]	ltc2mc_avl_wdata_0;	// From ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_write_req_0;	// From ltc of MCPU_MEM_ltc.v
	output		pre2core_done;		// From pre of MCPU_MEM_preload.v
	output [127:0]	video2ltc_rdata;	// From ltc of MCPU_MEM_ltc.v
	output		video2ltc_rvalid;	// From ltc of MCPU_MEM_ltc.v
	output		video2ltc_stall;	// From ltc of MCPU_MEM_ltc.v
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
	wire [31:5]	pre2arb_addr;		// From pre of MCPU_MEM_preload.v
	wire [2:0]	pre2arb_opcode;		// From pre of MCPU_MEM_preload.v
	wire		pre2arb_rvalid;		// From arb of MCPU_MEM_arb.v
	wire		pre2arb_stall;		// From arb of MCPU_MEM_arb.v
	wire		pre2arb_valid;		// From pre of MCPU_MEM_preload.v
	wire [31:0]	pre2arb_wbe;		// From pre of MCPU_MEM_preload.v
	wire [255:0]	pre2arb_wdata;		// From pre of MCPU_MEM_preload.v
	// End of automatics
	
	output wire [255:0] cli0_rdata;
	
	assign cli0_rdata = cli2arb_rdata;
	
	MCPU_MEM_preload pre(/*AUTOINST*/
			     // Outputs
			     .pre2arb_valid	(pre2arb_valid),
			     .pre2arb_opcode	(pre2arb_opcode[2:0]),
			     .pre2arb_addr	(pre2arb_addr[31:5]),
			     .pre2arb_wdata	(pre2arb_wdata[255:0]),
			     .pre2arb_wbe	(pre2arb_wbe[31:0]),
			     .pre2core_done	(pre2core_done),
			     // Inputs
			     .clkrst_mem_clk	(clkrst_mem_clk),
			     .clkrst_mem_rst_n	(clkrst_mem_rst_n),
			     .pre2arb_stall	(pre2arb_stall),
			     .pre2arb_rvalid	(pre2arb_rvalid));

	/* MCPU_MEM_arb AUTO_TEMPLATE(
		.cli2arb_stall({pre2arb_stall, cli0_stall}),
		.cli2arb_rvalid({pre2arb_rvalid, cli0_rvalid}),
		
		.cli2arb_valid({pre2arb_valid, cli0_valid}),
		.cli2arb_opcode({pre2arb_opcode[2:0], cli0_opcode[2:0]}),
		.cli2arb_addr({pre2arb_addr[31:5], cli0_addr[31:5]}),
		.cli2arb_wdata({pre2arb_wdata[255:0], cli0_wdata[255:0]}),
		.cli2arb_wbe({pre2arb_wbe[31:0], cli0_wbe[31:0]}),
		); */
	MCPU_MEM_arb #(.CLIENTS(2), .CLIENTS_BITS(1))
		arb(/*AUTOINST*/
		    // Outputs
		    .arb2ltc_valid	(arb2ltc_valid),
		    .arb2ltc_opcode	(arb2ltc_opcode[2:0]),
		    .arb2ltc_addr	(arb2ltc_addr[31:5]),
		    .arb2ltc_wdata	(arb2ltc_wdata[255:0]),
		    .arb2ltc_wbe	(arb2ltc_wbe[31:0]),
		    .cli2arb_stall	({pre2arb_stall, cli0_stall}), // Templated
		    .cli2arb_rdata	(cli2arb_rdata[255:0]),
		    .cli2arb_rvalid	({pre2arb_rvalid, cli0_rvalid}), // Templated
		    // Inputs
		    .clkrst_mem_clk	(clkrst_mem_clk),
		    .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		    .arb2ltc_stall	(arb2ltc_stall),
		    .arb2ltc_rdata	(arb2ltc_rdata[255:0]),
		    .arb2ltc_rvalid	(arb2ltc_rvalid),
		    .cli2arb_valid	({pre2arb_valid, cli0_valid}), // Templated
		    .cli2arb_opcode	({pre2arb_opcode[2:0], cli0_opcode[2:0]}), // Templated
		    .cli2arb_addr	({pre2arb_addr[31:5], cli0_addr[31:5]}), // Templated
		    .cli2arb_wdata	({pre2arb_wdata[255:0], cli0_wdata[255:0]}), // Templated
		    .cli2arb_wbe	({pre2arb_wbe[31:0], cli0_wbe[31:0]})); // Templated

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
			 .video2ltc_rvalid	(video2ltc_rvalid),
			 .video2ltc_rdata	(video2ltc_rdata[127:0]),
			 .video2ltc_stall	(video2ltc_stall),
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
			 .arb2ltc_wbe		(arb2ltc_wbe[31:0]),
			 .video2ltc_re		(video2ltc_re),
			 .video2ltc_addr	(video2ltc_addr[28:7]));
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
