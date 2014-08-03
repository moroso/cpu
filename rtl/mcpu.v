`timescale 1ns/10ps

module MCPU_pll
	#(parameter OUT_FREQUENCY = "50.000000 MHz") (
	input wire pad_clk125,
	input wire rst,
	output wire outclk_0,
	output wire locked
);

	altera_pll #(
		.fractional_vco_multiplier("false"),
		.reference_clock_frequency("125.0 MHz"),
		.operation_mode("direct"),
		.number_of_clocks(1),
		.output_clock_frequency0(OUT_FREQUENCY),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.pll_type("General"),
		.pll_subtype("General")
	) altera_pll_i (
		.rst	(rst),
		.outclk	({outclk_0}),
		.locked	(locked),
		.fboutclk	( ),
		.fbclk	(1'b0),
		.refclk	(pad_clk125)
	);
endmodule

module mcpu(/*AUTOARG*/
   // Outputs
   pad_mem_dm, pad_mem_cs_n, pad_mem_cke, pad_mem_ck_n, pad_mem_ck,
   pad_mem_ca, pad_led_g,
   // Inouts
   pad_mem_dqs_n, pad_mem_dqs, pad_mem_dq,
   // Inputs
   pad_mem_oct_rzqin, pad_clk125
   );
	input pad_clk125;
	output wire [7:0] pad_led_g;

	/* Fake verilog-mode out for a bit until we actually wire this up. */
	/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
		(verilog-regexp-words `(
			"mc_ready"
		)))*/


	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		pad_mem_oct_rzqin;	// To u_mc of MCPU_mc.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output [9:0]	pad_mem_ca;		// From u_mc of MCPU_mc.v
	output [0:0]	pad_mem_ck;		// From u_mc of MCPU_mc.v
	output [0:0]	pad_mem_ck_n;		// From u_mc of MCPU_mc.v
	output [0:0]	pad_mem_cke;		// From u_mc of MCPU_mc.v
	output [0:0]	pad_mem_cs_n;		// From u_mc of MCPU_mc.v
	output [3:0]	pad_mem_dm;		// From u_mc of MCPU_mc.v
	// End of automatics
	/*AUTOINOUT*/
	// Beginning of automatic inouts (from unused autoinst inouts)
	inout [31:0]	pad_mem_dq;		// To/From u_mc of MCPU_mc.v
	inout [3:0]	pad_mem_dqs;		// To/From u_mc of MCPU_mc.v
	inout [3:0]	pad_mem_dqs_n;		// To/From u_mc of MCPU_mc.v
	// End of automatics
	
	wire clk50;
	wire clkrst_avl_clk;
	
	reg [26:0] ctr;

/* Apparently we're out of PLLs at this site?  So main logic runs on clk175. */	
`ifdef HAVE_MORE_PLLS_THAN_REALITY
	MCPU_pll u_pll(
		.pad_clk125(pad_clk125),
		.rst(0),
		.outclk_0(clk50),
		.locked()
	);
`endif

	MCPU_pll
		#(.OUT_FREQUENCY("175.00000 MHz"))
		u_pll175 (
		.pad_clk125(pad_clk125),
		.rst(0),
		.outclk_0(clkrst_avl_clk),
		.locked()
	);
	
	always @(posedge clkrst_avl_clk)
		ctr <= ctr + 1;
	
	wire mc_ready;
//	assign pad_led_g = {6'b0, mc_ready, ctr[26]};
	
	wire clkrst_mem_clk = clkrst_avl_clk;
	reg [3:0] clkrst_mem_rst_ctr = 15;
	reg clkrst_mem_rst_n = 0;
	always @(posedge clkrst_mem_clk) begin
		clkrst_mem_rst_n <= ~|clkrst_mem_rst_ctr;
		if (clkrst_mem_rst_ctr != 0)
			clkrst_mem_rst_ctr <= clkrst_mem_rst_ctr - 1;
	end
	
	/* We'll tie all this stuff off for now. */
	/* MCPU_int AUTO_TEMPLATE(
		.leds(pad_led_g),
		); */
	MCPU_int u_int(/*AUTOINST*/
		       // Outputs
		       .ltc2mc_avl_addr_0(ltc2mc_avl_addr_0[24:0]),
		       .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
		       .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
		       .ltc2mc_avl_read_req_0(ltc2mc_avl_read_req_0),
		       .ltc2mc_avl_size_0(ltc2mc_avl_size_0[4:0]),
		       .ltc2mc_avl_wdata_0(ltc2mc_avl_wdata_0[127:0]),
		       .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
		       .leds		(pad_led_g),		 // Templated
		       // Inputs
		       .clkrst_mem_clk	(clkrst_mem_clk),
		       .clkrst_mem_rst_n(clkrst_mem_rst_n),
		       .ltc2mc_avl_rdata_0(ltc2mc_avl_rdata_0[127:0]),
		       .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
		       .ltc2mc_avl_ready_0(ltc2mc_avl_ready_0));

	/* MCPU_mc AUTO_TEMPLATE(
		.clkrst_.*_rst_n(1'b1),
		.mc_ready(mc_ready),
		); */
	MCPU_mc u_mc(
		/*AUTOINST*/
		     // Outputs
		     .ltc2mc_avl_rdata_0(ltc2mc_avl_rdata_0[127:0]),
		     .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
		     .ltc2mc_avl_ready_0(ltc2mc_avl_ready_0),
		     .pad_mem_ca	(pad_mem_ca[9:0]),
		     .pad_mem_ck	(pad_mem_ck[0:0]),
		     .pad_mem_ck_n	(pad_mem_ck_n[0:0]),
		     .pad_mem_cke	(pad_mem_cke[0:0]),
		     .pad_mem_cs_n	(pad_mem_cs_n[0:0]),
		     .pad_mem_dm	(pad_mem_dm[3:0]),
		     .mc_ready		(mc_ready),		 // Templated
		     // Inouts
		     .pad_mem_dq	(pad_mem_dq[31:0]),
		     .pad_mem_dqs	(pad_mem_dqs[3:0]),
		     .pad_mem_dqs_n	(pad_mem_dqs_n[3:0]),
		     // Inputs
		     .clkrst_global_rst_n(1'b1),		 // Templated
		     .clkrst_mem_clk	(clkrst_mem_clk),
		     .clkrst_mem_rst_n	(1'b1),			 // Templated
		     .clkrst_soft_rst_n	(1'b1),			 // Templated
		     .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
		     .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
		     .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
		     .ltc2mc_avl_read_req_0(ltc2mc_avl_read_req_0),
		     .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
		     .ltc2mc_avl_wdata_0(ltc2mc_avl_wdata_0[127:0]),
		     .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
		     .pad_clk125	(pad_clk125),
		     .pad_mem_oct_rzqin	(pad_mem_oct_rzqin));
endmodule

// Local Variables:
// verilog-library-flags:("-f dirs.vc")
// End:
