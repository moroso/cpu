`timescale 1 ps / 1 ps

module MCPU_mc(
	/*AUTOARG*/
   // Outputs
   pad_mem_dm, pad_mem_cs_n, pad_mem_cke, pad_mem_ck_n, pad_mem_ck,
   pad_mem_ca, arb2mc_avl_ready_0, arb2mc_avl_rdata_valid_0,
   arb2mc_avl_rdata_0, mc_ready,
   // Inouts
   pad_mem_dqs_n, pad_mem_dqs, pad_mem_dq,
   // Inputs
   pad_mem_oct_rzqin, pad_clk125, clkrst_soft_rst_n,
   clkrst_global_rst_n, clkrst_avl_rst_n, clkrst_avl_clk,
   arb2mc_avl_write_req_0, arb2mc_avl_wdata_0, arb2mc_avl_size_0,
   arb2mc_avl_read_req_0, arb2mc_avl_burstbegin_0, arb2mc_avl_be_0,
   arb2mc_avl_addr_0
   );

	/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
		(verilog-regexp-words `(
			"local_init_done"
			"local_cal_success"
			"local_cal_fail"
			"pll_locked"
		)))*/

	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input [24:0]	arb2mc_avl_addr_0;	// To u_phy of lpddr2_phy.v
	input [15:0]	arb2mc_avl_be_0;	// To u_phy of lpddr2_phy.v
	input		arb2mc_avl_burstbegin_0;// To u_phy of lpddr2_phy.v
	input		arb2mc_avl_read_req_0;	// To u_phy of lpddr2_phy.v
	input [4:0]	arb2mc_avl_size_0;	// To u_phy of lpddr2_phy.v
	input [127:0]	arb2mc_avl_wdata_0;	// To u_phy of lpddr2_phy.v
	input		arb2mc_avl_write_req_0;	// To u_phy of lpddr2_phy.v
	input		clkrst_avl_clk;		// To u_phy of lpddr2_phy.v, ...
	input		clkrst_avl_rst_n;	// To u_phy of lpddr2_phy.v, ...
	input		clkrst_global_rst_n;	// To u_phy of lpddr2_phy.v
	input		clkrst_soft_rst_n;	// To u_phy of lpddr2_phy.v
	input		pad_clk125;		// To u_phy of lpddr2_phy.v
	input		pad_mem_oct_rzqin;	// To u_phy of lpddr2_phy.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output [127:0]	arb2mc_avl_rdata_0;	// From u_phy of lpddr2_phy.v
	output		arb2mc_avl_rdata_valid_0;// From u_phy of lpddr2_phy.v
	output		arb2mc_avl_ready_0;	// From u_phy of lpddr2_phy.v
	output [9:0]	pad_mem_ca;		// From u_phy of lpddr2_phy.v
	output [0:0]	pad_mem_ck;		// From u_phy of lpddr2_phy.v
	output [0:0]	pad_mem_ck_n;		// From u_phy of lpddr2_phy.v
	output [0:0]	pad_mem_cke;		// From u_phy of lpddr2_phy.v
	output [0:0]	pad_mem_cs_n;		// From u_phy of lpddr2_phy.v
	output [3:0]	pad_mem_dm;		// From u_phy of lpddr2_phy.v
	// End of automatics
	/*AUTOINOUT*/
	// Beginning of automatic inouts (from unused autoinst inouts)
	inout [31:0]	pad_mem_dq;		// To/From u_phy of lpddr2_phy.v
	inout [3:0]	pad_mem_dqs;		// To/From u_phy of lpddr2_phy.v
	inout [3:0]	pad_mem_dqs_n;		// To/From u_phy of lpddr2_phy.v
	// End of automatics
	
	wire local_init_done, local_cal_success, local_cal_fail, pll_locked;
	
	output wire mc_ready = local_init_done & local_cal_success & ~local_cal_fail & pll_locked;
	
	/* lpddr2_phy AUTO_TEMPLATE(
		.afi_.*         (),
		.\(mem_.*\)     (pad_\1[]),
		.\(oct_rzqin\)  (pad_mem_\1),
		.\(avl_.*\)     (arb2mc_\1[]),
		.mp_.*_clk      (clkrst_avl_clk),
		.mp_.*_reset_n  (clkrst_avl_rst_n),
		.pll_ref_clk    (pad_clk125),
		.pll_locked     (pll_locked),
		.pll_.*         (),
		.global_reset_n (clkrst_global_rst_n),
		.soft_reset_n   (clkrst_soft_rst_n),
		);
		*/
	lpddr2_phy u_phy(/*AUTOINST*/
			 // Outputs
			 .afi_clk		(),		 // Templated
			 .afi_half_clk		(),		 // Templated
			 .afi_reset_n		(),		 // Templated
			 .afi_reset_export_n	(),		 // Templated
			 .mem_ca		(pad_mem_ca[9:0]), // Templated
			 .mem_ck		(pad_mem_ck[0:0]), // Templated
			 .mem_ck_n		(pad_mem_ck_n[0:0]), // Templated
			 .mem_cke		(pad_mem_cke[0:0]), // Templated
			 .mem_cs_n		(pad_mem_cs_n[0:0]), // Templated
			 .mem_dm		(pad_mem_dm[3:0]), // Templated
			 .avl_ready_0		(arb2mc_avl_ready_0), // Templated
			 .avl_rdata_valid_0	(arb2mc_avl_rdata_valid_0), // Templated
			 .avl_rdata_0		(arb2mc_avl_rdata_0[127:0]), // Templated
			 .local_init_done	(local_init_done),
			 .local_cal_success	(local_cal_success),
			 .local_cal_fail	(local_cal_fail),
			 .pll_mem_clk		(),		 // Templated
			 .pll_write_clk		(),		 // Templated
			 .pll_locked		(pll_locked),	 // Templated
			 .pll_write_clk_pre_phy_clk(),		 // Templated
			 .pll_addr_cmd_clk	(),		 // Templated
			 .pll_avl_clk		(),		 // Templated
			 .pll_config_clk	(),		 // Templated
			 .pll_mem_phy_clk	(),		 // Templated
			 .afi_phy_clk		(),		 // Templated
			 .pll_avl_phy_clk	(),		 // Templated
			 // Inouts
			 .mem_dq		(pad_mem_dq[31:0]), // Templated
			 .mem_dqs		(pad_mem_dqs[3:0]), // Templated
			 .mem_dqs_n		(pad_mem_dqs_n[3:0]), // Templated
			 // Inputs
			 .pll_ref_clk		(pad_clk125),	 // Templated
			 .global_reset_n	(clkrst_global_rst_n), // Templated
			 .soft_reset_n		(clkrst_soft_rst_n), // Templated
			 .avl_burstbegin_0	(arb2mc_avl_burstbegin_0), // Templated
			 .avl_addr_0		(arb2mc_avl_addr_0[24:0]), // Templated
			 .avl_wdata_0		(arb2mc_avl_wdata_0[127:0]), // Templated
			 .avl_be_0		(arb2mc_avl_be_0[15:0]), // Templated
			 .avl_read_req_0	(arb2mc_avl_read_req_0), // Templated
			 .avl_write_req_0	(arb2mc_avl_write_req_0), // Templated
			 .avl_size_0		(arb2mc_avl_size_0[4:0]), // Templated
			 .mp_cmd_clk_0_clk	(clkrst_avl_clk), // Templated
			 .mp_cmd_reset_n_0_reset_n(clkrst_avl_rst_n), // Templated
			 .mp_rfifo_clk_0_clk	(clkrst_avl_clk), // Templated
			 .mp_rfifo_reset_n_0_reset_n(clkrst_avl_rst_n), // Templated
			 .mp_wfifo_clk_0_clk	(clkrst_avl_clk), // Templated
			 .mp_wfifo_reset_n_0_reset_n(clkrst_avl_rst_n), // Templated
			 .mp_rfifo_clk_1_clk	(clkrst_avl_clk), // Templated
			 .mp_rfifo_reset_n_1_reset_n(clkrst_avl_rst_n), // Templated
			 .mp_wfifo_clk_1_clk	(clkrst_avl_clk), // Templated
			 .mp_wfifo_reset_n_1_reset_n(clkrst_avl_rst_n), // Templated
			 .oct_rzqin		(pad_mem_oct_rzqin)); // Templated
endmodule
