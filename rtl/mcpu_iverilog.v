`timescale 1 ps / 1 ps

module mcpu_iverilog();
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			ext_audio_bclk;		// From mcpu_int_inst of MCPU_int.v
  wire			ext_audio_data;		// From mcpu_int_inst of MCPU_int.v
  wire			ext_audio_lrclk;	// From mcpu_int_inst of MCPU_int.v
  wire			ext_audio_mclk;		// From mcpu_int_inst of MCPU_int.v
  wire			ext_i2c_scl;		// From mcpu_int_inst of MCPU_int.v
  wire			ext_i2c_sda;		// To/From mcpu_int_inst of MCPU_int.v
  wire [7:0]		ext_led_g;		// From mcpu_int_inst of MCPU_int.v
  wire [9:0]		ext_led_r;		// From mcpu_int_inst of MCPU_int.v
  wire			ext_sd_clk;		// From mcpu_int_inst of MCPU_int.v
  wire			ext_sd_cmd;		// To/From mcpu_int_inst of MCPU_int.v
  wire [3:0]		ext_sd_data;		// To/From mcpu_int_inst of MCPU_int.v
  wire			ext_uart_tx;		// From mcpu_int_inst of MCPU_int.v
  wire [24:0]		ltc2mc_avl_addr_0;	// From mcpu_int_inst of MCPU_int.v
  wire [15:0]		ltc2mc_avl_be_0;	// From mcpu_int_inst of MCPU_int.v
  wire			ltc2mc_avl_burstbegin_0;// From mcpu_int_inst of MCPU_int.v
  wire			ltc2mc_avl_read_req_0;	// From mcpu_int_inst of MCPU_int.v
  wire [4:0]		ltc2mc_avl_size_0;	// From mcpu_int_inst of MCPU_int.v
  wire [127:0]		ltc2mc_avl_wdata_0;	// From mcpu_int_inst of MCPU_int.v
  wire			ltc2mc_avl_write_req_0;	// From mcpu_int_inst of MCPU_int.v
  wire			pre2core_done;		// From mcpu_int_inst of MCPU_int.v
  wire [31:0]		r0;			// From mcpu_int_inst of MCPU_int.v
  // End of automatics

  reg CLOCK_125_p = 1'b0;
  reg CPU_RESET_n = 1'b0;
  reg audio_clk = 1'b0;

  integer i = 0;
  wire [31:0] memoutput;

  initial begin
     $dumpfile("iverilog_out.vcd");
     $dumpvars(0, mcpu_int_inst);

     #400000 $finish();
  end

  always #5 CLOCK_125_p = ~CLOCK_125_p;
  always #16 audio_clk <= ~audio_clk;

/*
  initial begin
     for (i = 0; i < 20000; i = i + 1) begin
	#5 CLOCK_125_p = ~CLOCK_125_p;
	#5 CLOCK_125_p = ~CLOCK_125_p;
	//$display("clk %d, reset %d, memoutput %x", i, CPU_RESET_n, memoutput);
     end
  end

  initial begin
     for (i = 0; i < 20000; i = i + 1) begin
	#5 CLOCK_125_p = ~CLOCK_125_p;
	#5 CLOCK_125_p = ~CLOCK_125_p;
	//$display("clk %d, reset %d, memoutput %x", i, CPU_RESET_n, memoutput);
     end
  end
*/
  initial begin
     CPU_RESET_n = 1'b0;
     #50;
     CPU_RESET_n = 1'b1;
  end

  // Hack: pretend the memory controller is returning valid data right away.
  // (This means we'll be running entirely out of the caches.)
  // TODO: fix this, obviously.
  wire ltc2mc_avl_ready_0 = 1;
  wire ltc2mc_avl_rdata_valid_0 = 1;

  reg [3:0] ext_buttons = 4'hc;
  reg [9:0] ext_switches = 10'h30f;

  /* MCPU_int AUTO_TEMPLATE(
   .clkrst_core_clk(CLOCK_125_p),
   .clkrst_core_rst_n(CPU_RESET_n),
   .clkrst_mem_clk(CLOCK_125_p),
   .clkrst_mem_rst_n(CPU_RESET_n),
   .ltc2mc_avl_rdata_0(),
   .clkrst_audio_clk(audio_clk)); */
  MCPU_int mcpu_int_inst(
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
			 .ext_i2c_scl		(ext_i2c_scl),
			 .ext_sd_clk		(ext_sd_clk),
			 .ext_audio_bclk	(ext_audio_bclk),
			 .ext_audio_mclk	(ext_audio_mclk),
			 .ext_audio_data	(ext_audio_data),
			 .ext_audio_lrclk	(ext_audio_lrclk),
			 .r0			(r0[31:0]),
			 .pre2core_done		(pre2core_done),
			 // Inouts
			 .ext_i2c_sda		(ext_i2c_sda),
			 .ext_sd_cmd		(ext_sd_cmd),
			 .ext_sd_data		(ext_sd_data[3:0]),
			 // Inputs
			 .clkrst_core_clk	(CLOCK_125_p),	 // Templated
			 .clkrst_mem_clk	(CLOCK_125_p),	 // Templated
			 .clkrst_mem_rst_n	(CPU_RESET_n),	 // Templated
			 .ext_buttons		(ext_buttons[3:0]),
			 .ext_switches		(ext_switches[9:0]),
			 .ltc2mc_avl_rdata_0	(),		 // Templated
			 .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
			 .ltc2mc_avl_ready_0	(ltc2mc_avl_ready_0),
			 .ext_uart_rx		(ext_uart_rx),
			 .clkrst_audio_clk	(audio_clk),	 // Templated
			 .clkrst_core_rst_n	(CPU_RESET_n));	 // Templated

endmodule
