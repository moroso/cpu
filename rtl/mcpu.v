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
   LEDG, LEDR, UART_TX, I2C_SCL, SD_CLK, pad_mem_ca, pad_mem_ck,
   pad_mem_ck_n, pad_mem_cke, pad_mem_cs_n, pad_mem_dm, GPIO,
   // Inouts
   I2C_SDA, SD_CMD, SD_DAT, pad_mem_dq, pad_mem_dqs, pad_mem_dqs_n,
   // Inputs
   pad_clk125, in_rst_n, SW, KEY, UART_RX, pad_mem_oct_rzqin
   );
  input        pad_clk125;
  input        in_rst_n;
  output [7:0] LEDG;
  output [9:0] LEDR;
  input [9:0]  SW;
  input [3:0]  KEY;
  input UART_RX;
  output UART_TX;

  inout  I2C_SDA;
  output I2C_SCL;

  output  SD_CLK;
  inout   SD_CMD;
  inout [3:0] SD_DAT;

  wire 	 i2c_scl;
  assign I2C_SCL = i2c_scl;

  output [9:0] pad_mem_ca;
  output [0:0] pad_mem_ck;
  output [0:0] pad_mem_ck_n;
  output [0:0] pad_mem_cke;
  output [0:0] pad_mem_cs_n;
  output [3:0] pad_mem_dm;
  inout [31:0] pad_mem_dq;
  inout [3:0]  pad_mem_dqs;
  inout [3:0]  pad_mem_dqs_n;
  input        pad_mem_oct_rzqin;

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
	wire [127:0]	ltc2mc_avl_rdata_0;	// From u_mc of MCPU_mc.v
	wire		ltc2mc_avl_rdata_valid_0;// From u_mc of MCPU_mc.v
	wire		ltc2mc_avl_read_req_0;	// From u_int of MCPU_int.v
	wire		ltc2mc_avl_ready_0;	// From u_mc of MCPU_mc.v
	wire [4:0]	ltc2mc_avl_size_0;	// From u_int of MCPU_int.v
	wire [127:0]	ltc2mc_avl_wdata_0;	// From u_int of MCPU_int.v
	wire		ltc2mc_avl_write_req_0;	// From u_int of MCPU_int.v
	wire [31:0]	r0;			// From u_int of MCPU_int.v
	// End of automatics

  // TODO: more input buffering.
  wire [9:0] 		ext_switches = SW;
  wire [3:0] 		ext_buttons = ~KEY;
  reg [3:0] 		uart_fifo;
  wire 			ext_uart_rx = uart_fifo[0];

  always @(posedge clk50)
    uart_fifo <= {UART_RX, uart_fifo[3:1]};

  output [1:0] 		GPIO;

  assign UART_TX = ext_uart_tx;
  assign LEDR = ext_led_r;
  assign LEDG = ext_led_g;

  wire 			clkrst_core_rst_n;
  wire 			clkrst_mem_rst_n;

  wire 			clk50;

  wire 		   pre2core_done;
  wire 		   clkrst_core_clk = clk50;
  wire 		   clkrst_mem_clk = clk50;
  wire 		   mc_pll_ref;

  `ifndef SIM
  MCPU_pll  #(.OUT_FREQUENCY("50.00000 MHz")) u_pll(
						    .pad_clk125(pad_clk125),
						    .rst(0),
						    .outclk_0(clk50),
						    .locked()
						    );

  assign clkrst_core_rst_n = in_rst_n & mc_ready & KEY[0];
  assign clkrst_mem_rst_n = in_rst_n;
  assign mc_pll_ref = pad_clk125;
  `endif

  `ifdef SIM
  // For running in modelsim.
  reg 		   simclk = 0;
  always #1 simclk <= ~simclk;
  assign clk50 = simclk;
  assign mc_pll_ref = simclk;

  reg 		   rst = 0;
  assign clkrst_core_rst_n = rst;
  assign clkrst_mem_rst_n = rst;
  initial begin
     rst <= 1;
     #1 rst <= 0;
     #10 rst <= 1;
  end
  `endif //  `ifdef SIM

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

	/* MCPU_int AUTO_TEMPLATE(
	 .ext_i2c_sda(I2C_SDA),
	 .ext_i2c_scl(i2c_scl),
	 .ext_sd_clk(SD_CLK),
	 .ext_sd_data(SD_DAT[]),
	 .ext_sd_cmd(SD_CMD),
	 .clkrst_mem_rst_n(clkrst_core_rst_n)); */
  MCPU_int u_int(
  		 //.ltc2mc_avl_rdata_0	(),
  		 //.ltc2mc_avl_rdata_valid_0(1),
  		 //.ltc2mc_avl_ready_0	(1),

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
		 .ext_i2c_scl		(i2c_scl),		 // Templated
		 .ext_sd_clk		(SD_CLK),		 // Templated
		 .r0			(r0[31:0]),
		 .pre2core_done		(pre2core_done),
		 // Inouts
		 .ext_i2c_sda		(I2C_SDA),		 // Templated
		 .ext_sd_cmd		(SD_CMD),		 // Templated
		 .ext_sd_data		(SD_DAT[3:0]),		 // Templated
		 // Inputs
		 .clkrst_core_clk	(clkrst_core_clk),
		 .clkrst_mem_clk	(clkrst_mem_clk),
		 .clkrst_mem_rst_n	(clkrst_core_rst_n),	 // Templated
		 .ext_buttons		(ext_buttons[3:0]),
		 .ext_switches		(ext_switches[9:0]),
		 .ltc2mc_avl_rdata_0	(ltc2mc_avl_rdata_0[127:0]),
		 .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
		 .ltc2mc_avl_ready_0	(ltc2mc_avl_ready_0),
		 .ext_uart_rx		(ext_uart_rx),
		 .clkrst_core_rst_n	(clkrst_core_rst_n));

	/* MCPU_mc AUTO_TEMPLATE(
	 .clkrst_.*_rst_n(clkrst_mem_rst_n),
	 .mc_ready(mc_ready),
	 .clkrst_mem_clk(clkrst_mem_clk),
	 .pad_clk125(mc_pll_ref)); */
	MCPU_mc u_mc(
		/*AUTOINST*/
		     // Outputs
		     .mc_ready		(mc_ready),		 // Templated
		     .ltc2mc_avl_rdata_0(ltc2mc_avl_rdata_0[127:0]),
		     .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
		     .ltc2mc_avl_ready_0(ltc2mc_avl_ready_0),
		     .pad_mem_ca	(pad_mem_ca[9:0]),
		     .pad_mem_ck	(pad_mem_ck[0:0]),
		     .pad_mem_ck_n	(pad_mem_ck_n[0:0]),
		     .pad_mem_cke	(pad_mem_cke[0:0]),
		     .pad_mem_cs_n	(pad_mem_cs_n[0:0]),
		     .pad_mem_dm	(pad_mem_dm[3:0]),
		     // Inouts
		     .pad_mem_dq	(pad_mem_dq[31:0]),
		     .pad_mem_dqs	(pad_mem_dqs[3:0]),
		     .pad_mem_dqs_n	(pad_mem_dqs_n[3:0]),
		     // Inputs
		     .clkrst_global_rst_n(clkrst_mem_rst_n),	 // Templated
		     .clkrst_mem_clk	(clkrst_mem_clk),	 // Templated
		     .clkrst_mem_rst_n	(clkrst_mem_rst_n),	 // Templated
		     .clkrst_soft_rst_n	(clkrst_mem_rst_n),	 // Templated
		     .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
		     .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
		     .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
		     .ltc2mc_avl_read_req_0(ltc2mc_avl_read_req_0),
		     .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
		     .ltc2mc_avl_wdata_0(ltc2mc_avl_wdata_0[127:0]),
		     .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
		     .pad_clk125	(mc_pll_ref),		 // Templated
		     .pad_mem_oct_rzqin	(pad_mem_oct_rzqin));
endmodule

// Local Variables:
// verilog-library-flags:("-f dirs.vc")
// End:
