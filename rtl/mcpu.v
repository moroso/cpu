`timescale 1ns/10ps

module MCPU_pll
  #(parameter OUT_FREQUENCY = "50.000000 MHz") (
						input wire  pad_clk125,
						input wire  rst,
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
   LEDG, LEDR, UART_TX,
   // Inputs
   pad_clk125, in_rst_n, SW, KEY, UART_RX
   );
  input        pad_clk125;
  input        in_rst_n;
  output [7:0] LEDG;
  output [9:0] LEDR;
  input [9:0]  SW;
  input [3:0]  KEY;
  input UART_RX;
  output UART_TX;

	/* Fake verilog-mode out for a bit until we actually wire this up. */
	/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
		(verilog-regexp-words `(
			"mc_ready"
		)))*/


	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [7:0]	ext_led_g;		// From u_int of MCPU_int.v
	wire [9:0]	ext_led_r;		// From u_int of MCPU_int.v
	wire		ext_uart_tx;		// From u_int of MCPU_int.v
	wire [24:0]	ltc2mc_avl_addr_0;	// From u_int of MCPU_int.v
	wire [15:0]	ltc2mc_avl_be_0;	// From u_int of MCPU_int.v
	wire		ltc2mc_avl_burstbegin_0;// From u_int of MCPU_int.v
	wire		ltc2mc_avl_read_req_0;	// From u_int of MCPU_int.v
	wire [4:0]	ltc2mc_avl_size_0;	// From u_int of MCPU_int.v
	wire [127:0]	ltc2mc_avl_wdata_0;	// From u_int of MCPU_int.v
	wire		ltc2mc_avl_write_req_0;	// From u_int of MCPU_int.v
	wire [31:0]	r0;			// From u_int of MCPU_int.v
	// End of automatics

  // TODO: input buffering.
  wire [9:0] 		ext_switches = SW;
  wire [3:0] 		ext_buttons = ~KEY;
  wire 			ext_uart_rx = UART_RX;
  assign UART_TX = ext_uart_tx;
  assign LEDR = ext_led_r;
  assign LEDG = ext_led_g;

  wire 			clkrst_core_rst_n;
  wire 			clkrst_mem_rst_n;

  wire 			clk50;
  wire 			clkrst_avl_clk;

  reg [26:0] 		ctr;

  wire 		   pre2core_done;
  wire 		   clkrst_core_clk = clk50;
  wire 		   clkrst_mem_clk = clk50;

  `ifndef SIM
  MCPU_pll  #(.OUT_FREQUENCY("50.00000 MHz")) u_pll(
						    .pad_clk125(pad_clk125),
						    .rst(0),
						    .outclk_0(clk50),
						    .locked()
						    );
  MCPU_pll
    #(.OUT_FREQUENCY("175.00000 MHz")) u_pll175 (
						 .pad_clk125(pad_clk125),
						 .rst(0),
						 .outclk_0(clkrst_avl_clk),
						 .locked()
						 );

  assign clkrst_core_rst_n = in_rst_n;
  assign clkrst_mem_rst_n = in_rst_n;
  `endif

  `ifdef SIM
  // For running in modelsim.
  reg 		   simclk = 0;
  always #1 simclk <= ~simclk;
  assign clk50 = simclk;

  reg 		   rst = 0;
  assign clkrst_core_rst_n = rst;
  assign clkrst_mem_rst_n = rst;
  initial begin
     rst <= 1;
     #1 rst <= 0;
     #10 rst <= 1;
  end
  `endif //  `ifdef SIM

  always @(posedge clkrst_avl_clk)
    ctr <= ctr + 1;

  wire mc_ready;
  /* TODO: bring this back.
	reg [3:0] clkrst_mem_rst_ctr = 15;
	reg clkrst_mem_rst_n = 0;
	always @(posedge clkrst_mem_clk) begin
		clkrst_mem_rst_n <= ~|clkrst_mem_rst_ctr;
		if (clkrst_mem_rst_ctr != 0)
			clkrst_mem_rst_ctr <= clkrst_mem_rst_ctr - 1;
	end
*/	
	/* We'll tie all this stuff off for now. */
	/* MCPU_int AUTO_TEMPLATE(
		.leds(pad_led_g),
		); */
  MCPU_int u_int(
		 .ltc2mc_avl_rdata_0(),
		 .ltc2mc_avl_rdata_valid_0(1),
		 .ltc2mc_avl_ready_0(1),
		 .meminput	(),
		 .memoutput	(),
		 .r31		(),
		 /*AUTOINST*/
		 // Outputs
		 .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
		 .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
		 .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
		 .ltc2mc_avl_read_req_0	(ltc2mc_avl_read_req_0),
		 .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
		 .ltc2mc_avl_wdata_0	(ltc2mc_avl_wdata_0[127:0]),
		 .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
		 .ext_uart_tx		(ext_uart_tx),
		 .ext_led_g		(ext_led_g[7:0]),
		 .ext_led_r		(ext_led_r[9:0]),
		 .r0			(r0[31:0]),
		 .pre2core_done		(pre2core_done),
		 // Inputs
		 .clkrst_core_clk	(clkrst_core_clk),
		 .clkrst_mem_clk	(clkrst_mem_clk),
		 .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		 .ext_buttons		(ext_buttons[3:0]),
		 .ext_switches		(ext_switches[9:0]),
		 .ext_uart_rx		(ext_uart_rx),
		 .clkrst_core_rst_n	(clkrst_core_rst_n));

  // TODO: having actual memory would probably be nice.
	/* MCPU_mc AUTO_TEMPLATE(
		.clkrst_.*_rst_n(1'b1),
		.mc_ready(mc_ready),
		); */
	// MCPU_mc u_mc(
	// 	/*AUTOINST*/
	// 	     // Outputs
	// 	     .ltc2mc_avl_rdata_0(ltc2mc_avl_rdata_0[127:0]),
	// 	     .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
	// 	     .ltc2mc_avl_ready_0(ltc2mc_avl_ready_0),
	// 	     .pad_mem_ca	(pad_mem_ca[9:0]),
	// 	     .pad_mem_ck	(pad_mem_ck[0:0]),
	// 	     .pad_mem_ck_n	(pad_mem_ck_n[0:0]),
	// 	     .pad_mem_cke	(pad_mem_cke[0:0]),
	// 	     .pad_mem_cs_n	(pad_mem_cs_n[0:0]),
	// 	     .pad_mem_dm	(pad_mem_dm[3:0]),
	// 	     .mc_ready		(mc_ready),
	// 	     // Inouts
	// 	     .pad_mem_dq	(pad_mem_dq[31:0]),
	// 	     .pad_mem_dqs	(pad_mem_dqs[3:0]),
	// 	     .pad_mem_dqs_n	(pad_mem_dqs_n[3:0]),
	// 	     // Inputs
	// 	     .clkrst_global_rst_n(1'b1),
	// 	     .clkrst_mem_clk	(clkrst_mem_clk),
	// 	     .clkrst_mem_rst_n	(1'b1),
	// 	     .clkrst_soft_rst_n	(1'b1),
	// 	     .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
	// 	     .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
	// 	     .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
	// 	     .ltc2mc_avl_read_req_0(ltc2mc_avl_read_req_0),
	// 	     .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
	// 	     .ltc2mc_avl_wdata_0(ltc2mc_avl_wdata_0[127:0]),
	// 	     .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
	// 	     .pad_clk125	(pad_clk125),
	// 	     .pad_mem_oct_rzqin	(pad_mem_oct_rzqin));
endmodule

// Local Variables:
// verilog-library-flags:("-f dirs.vc")
// End:
