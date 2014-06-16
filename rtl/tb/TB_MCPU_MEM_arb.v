module TB_MCPU_MEM_arb(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_write_req_0, ltc2mc_avl_wdata_0, ltc2mc_avl_size_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_burstbegin_0, ltc2mc_avl_be_0,
   ltc2mc_avl_addr_0, cli2arb_stall, cli2arb_rvalid, cli2arb_rdata,
   // Inputs
   ltc2mc_avl_ready_0, ltc2mc_avl_rdata_valid_0, ltc2mc_avl_rdata_0,
   clkrst_mem_rst_n, clkrst_mem_clk, cli2arb_wdata, cli2arb_wbe,
   cli2arb_valid, cli2arb_opcode, cli2arb_addr
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input [53:0]	cli2arb_addr;		// To arb of MCPU_MEM_arb.v
	input [5:0]	cli2arb_opcode;		// To arb of MCPU_MEM_arb.v
	input [1:0]	cli2arb_valid;		// To arb of MCPU_MEM_arb.v
	input [63:0]	cli2arb_wbe;		// To arb of MCPU_MEM_arb.v
	input [511:0]	cli2arb_wdata;		// To arb of MCPU_MEM_arb.v
	input		clkrst_mem_clk;		// To arb of MCPU_MEM_arb.v, ...
	input		clkrst_mem_rst_n;	// To arb of MCPU_MEM_arb.v, ...
	input [127:0]	ltc2mc_avl_rdata_0;	// To ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_rdata_valid_0;// To ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_ready_0;	// To ltc of MCPU_MEM_ltc.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output [255:0]	cli2arb_rdata;		// From arb of MCPU_MEM_arb.v
	output [1:0]	cli2arb_rvalid;		// From arb of MCPU_MEM_arb.v
	output [1:0]	cli2arb_stall;		// From arb of MCPU_MEM_arb.v
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
	
	MCPU_MEM_arb #(.CLIENTS(2)) 
		arb(/*AUTOINST*/
		    // Outputs
		    .arb2ltc_valid	(arb2ltc_valid),
		    .arb2ltc_opcode	(arb2ltc_opcode[2:0]),
		    .arb2ltc_addr	(arb2ltc_addr[31:5]),
		    .arb2ltc_wdata	(arb2ltc_wdata[255:0]),
		    .arb2ltc_wbe	(arb2ltc_wbe[31:0]),
		    .cli2arb_stall	(cli2arb_stall[1:0]),
		    .cli2arb_rdata	(cli2arb_rdata[255:0]),
		    .cli2arb_rvalid	(cli2arb_rvalid[1:0]),
		    // Inputs
		    .clkrst_mem_clk	(clkrst_mem_clk),
		    .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		    .arb2ltc_stall	(arb2ltc_stall),
		    .arb2ltc_rdata	(arb2ltc_rdata[255:0]),
		    .arb2ltc_rvalid	(arb2ltc_rvalid),
		    .cli2arb_valid	(cli2arb_valid[1:0]),
		    .cli2arb_opcode	(cli2arb_opcode[5:0]),
		    .cli2arb_addr	(cli2arb_addr[53:0]),
		    .cli2arb_wdata	(cli2arb_wdata[511:0]),
		    .cli2arb_wbe	(cli2arb_wbe[63:0]));

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
