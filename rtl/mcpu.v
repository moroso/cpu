`timescale 1ns/10ps

module MCPU_pll
  #(parameter OUT_FREQUENCY0, OUT_FREQUENCY1) (
					       input wire  pad_clk125,
					       input wire  rst,
					       output wire outclk_0,
					       output wire outclk_1,
					       output wire locked
					       );

  altera_pll #(
	       .fractional_vco_multiplier("false"),
	       .reference_clock_frequency("125.0 MHz"),
	       .operation_mode("direct"),
	       .number_of_clocks(2),
	       .output_clock_frequency0(OUT_FREQUENCY0),
	       .output_clock_frequency1(OUT_FREQUENCY1),
	       .phase_shift0("0 ps"),
	       .duty_cycle0(50),
	       .pll_type("General"),
	       .pll_subtype("General")
	       ) altera_pll_i (
			       .rst	(rst),
			       .outclk	({outclk_1, outclk_0}),
			       .locked	(locked),
			       .fboutclk	( ),
			       .fbclk	(1'b0),
			       .refclk	(pad_clk125)
			       );
endmodule

module mcpu(/*AUTOARG*/
  // Outputs
  LEDG, LEDR, UART_TX, SD_CLK, GPIO, AUD_XCK, AUD_DACLRCK, AUD_DACDAT,
  AUD_BCLK, HDMI_TX_HS, HDMI_TX_VS, HDMI_TX_DE, HDMI_TX_CLK,
  HDMI_TX_D, pad_mem_ca, pad_mem_ck, pad_mem_ck_n, pad_mem_cke,
  pad_mem_cs_n, pad_mem_dm,
  // Inouts
  I2C_SDA, I2C_SCL, SD_CMD, SD_DAT, pad_mem_dq, pad_mem_dqs,
  pad_mem_dqs_n,
  // Inputs
  pad_clk125, pad_clk50, in_rst_n, SW, KEY, UART_RX, HDMI_TX_INT,
  pad_mem_oct_rzqin
  );
  input        pad_clk125;
  input        pad_clk50;
  input        in_rst_n;
  output [7:0] LEDG;
  output [9:0] LEDR;
  input [9:0]  SW;
  input [3:0]  KEY;
  input UART_RX;
  output UART_TX;

  inout  I2C_SDA;
  inout  I2C_SCL;

  output  SD_CLK;
  inout   SD_CMD;
  inout [3:0] SD_DAT;

  // TODO: make this inout and have a proper gpio system.
  output [18:0] GPIO;

  output 	AUD_XCK;
  output 	AUD_DACLRCK;
  output 	AUD_DACDAT;
  output 	AUD_BCLK;

  output 	HDMI_TX_HS;
  output 	HDMI_TX_VS;
  output 	HDMI_TX_DE;
  output 	HDMI_TX_CLK;
  output [23:0] HDMI_TX_D;
  input 	HDMI_TX_INT;

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
	wire		ext_audio_bclk;		// From u_int of MCPU_int.v
	wire		ext_audio_data;		// From u_int of MCPU_int.v
	wire		ext_audio_lrclk;	// From u_int of MCPU_int.v
	wire		ext_audio_mclk;		// From u_int of MCPU_int.v
	wire [7:0]	ext_hdmi_b;		// From u_int of MCPU_int.v
	wire		ext_hdmi_clk;		// From u_int of MCPU_int.v
	wire		ext_hdmi_de;		// From u_int of MCPU_int.v
	wire [7:0]	ext_hdmi_g;		// From u_int of MCPU_int.v
	wire		ext_hdmi_hsync;		// From u_int of MCPU_int.v
	wire [7:0]	ext_hdmi_r;		// From u_int of MCPU_int.v
	wire		ext_hdmi_vsync;		// From u_int of MCPU_int.v
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

  assign UART_TX = ext_uart_tx;
  assign LEDR = ext_led_r;
  assign LEDG = ext_led_g;

  assign AUD_BCLK = ext_audio_bclk;
  assign AUD_XCK = ext_audio_mclk;
  assign AUD_DACLRCK = ext_audio_lrclk;
  assign AUD_DACDAT = ext_audio_data;

  assign HDMI_TX_HS = ext_hdmi_hsync;
  assign HDMI_TX_VS = ext_hdmi_vsync;
  assign HDMI_TX_DE = ext_hdmi_de;
  assign HDMI_TX_CLK = ext_hdmi_clk;
  assign HDMI_TX_D = {ext_hdmi_r, ext_hdmi_g, ext_hdmi_b};

  //assign GPIO[0] = clkrst_video_clk;
  assign GPIO[1:0] = {I2C_SDA, I2C_SCL};


  wire 			clkrst_core_rst_n;
  wire 			clkrst_mem_rst_n;

  wire 			clk50;

  wire 		   pre2core_done;
  wire 		   clkrst_core_clk = clk50;
  wire 		   clkrst_mem_clk = clk50;
  wire 		   mc_pll_ref;
  wire 		   clkrst_audio_clk;
  wire 		   clkrst_video_clk = clk50;

`ifndef SIM
  // Note: ideally the audio clock would be 11.28960 MHz, but
  // 11.290322 is what we can get. Apologies to the audiophiles
  // for the 64ppm difference.
  MCPU_pll  #(
	      .OUT_FREQUENCY0("50.00000 MHz"),
	      .OUT_FREQUENCY1("11.290322 MHz")
	      ) u_pll(
		      .pad_clk125(pad_clk125),
		      .rst(0),
		      .outclk_0(clk50),
		      .outclk_1(clkrst_audio_clk),
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
	 .ext_i2c_scl(I2C_SCL),
	 .ext_sd_clk(SD_CLK),
	 .ext_sd_data(SD_DAT[]),
	 .ext_sd_cmd(SD_CMD),
	 .clkrst_mem_rst_n(clkrst_core_rst_n)); */
  MCPU_int u_int(
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
		 .ext_i2c_scl		(I2C_SCL),		 // Templated
		 .ext_sd_clk		(SD_CLK),		 // Templated
		 .ext_audio_bclk	(ext_audio_bclk),
		 .ext_audio_mclk	(ext_audio_mclk),
		 .ext_audio_data	(ext_audio_data),
		 .ext_audio_lrclk	(ext_audio_lrclk),
		 .ext_hdmi_clk		(ext_hdmi_clk),
		 .ext_hdmi_hsync	(ext_hdmi_hsync),
		 .ext_hdmi_vsync	(ext_hdmi_vsync),
		 .ext_hdmi_de		(ext_hdmi_de),
		 .ext_hdmi_r		(ext_hdmi_r[7:0]),
		 .ext_hdmi_g		(ext_hdmi_g[7:0]),
		 .ext_hdmi_b		(ext_hdmi_b[7:0]),
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
		 .clkrst_audio_clk	(clkrst_audio_clk),
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
