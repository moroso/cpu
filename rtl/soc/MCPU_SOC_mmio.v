module MCPU_SOC_mmio(/*AUTOARG*/
  // Outputs
  data_out, ext_led_g, ext_led_r, ext_uart_tx, ext_i2c_scl,
  ext_sd_clk, ext_audio_bclk, ext_audio_mclk, ext_audio_data,
  ext_audio_lrclk, ext_hdmi_clk, ext_hdmi_hsync, ext_hdmi_vsync,
  ext_hdmi_de, ext_hdmi_r, ext_hdmi_g, ext_hdmi_b,
  // Inouts
  ext_i2c_sda, ext_sd_cmd, ext_sd_data,
  // Inputs
  clkrst_core_clk, clkrst_core_rst_n, clkrst_audio_clk, data_in, addr,
  wren, ext_switches, ext_buttons, ext_uart_rx
  );

  input clkrst_core_clk, clkrst_core_rst_n;
  input clkrst_audio_clk;

  input [31:0] data_in;
  input [30:2] addr;
  input [3:0]  wren;
  output reg [31:0] data_out;

  output [7:0] 	    ext_led_g;
  output [9:0] 	    ext_led_r;
  input [9:0] 	    ext_switches;
  input [3:0] 	    ext_buttons;

  input 	    ext_uart_rx;
  output 	    ext_uart_tx;

  inout 	    ext_i2c_sda;
  output 	    ext_i2c_scl;

  inout 	    ext_sd_cmd;
  inout [3:0] 	    ext_sd_data;
  output 	    ext_sd_clk;

  output 	    ext_audio_bclk;
  output 	    ext_audio_mclk;
  output 	    ext_audio_data;
  output 	    ext_audio_lrclk;

  output 	    ext_hdmi_clk;
  output 	    ext_hdmi_hsync;
  output 	    ext_hdmi_vsync;
  output 	    ext_hdmi_de;
  output [7:0] 	    ext_hdmi_r;
  output [7:0] 	    ext_hdmi_g;
  output [7:0] 	    ext_hdmi_b;

  wire [31:0] 	    write_mask;
  assign write_mask = {{8{wren[3]}},{8{wren[2]}},{8{wren[1]}},{8{wren[0]}}};

  reg 		    is_ledsw, is_uart, is_i2c, is_sd, is_audio;

  wire [31:0] 	    uart_read_val, i2c_read_val;

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [31:0]		audio_read_val;		// From audio_mod of MCPU_SOC_audio.v
  wire [31:0]		ledsw_data_out;		// From ledsw_mod of MCPU_SOC_ledsw.v
  wire [31:0]		sd_read_val;		// From sd_mod of MCPU_SOC_sd.v
  // End of automatics

  always @(*) begin
     is_ledsw = 0;
     is_uart = 0;
     is_i2c = 0;
     is_sd = 0;
     is_audio = 0;
     data_out = 32'bx;

     case(addr[30:12])
       19'd0: begin // LED/SW
	  is_ledsw = 1;
	  data_out = ledsw_data_out;
       end
       19'd1: begin // UART
	  is_uart = 1;
	  data_out = uart_read_val;
       end
       19'd2: begin // I2C
	  is_i2c = 1;
	  data_out = i2c_read_val;
       end
       19'd3: begin // SD
	  is_sd = 1;
	  data_out = sd_read_val;
       end
       19'd4: begin // Audio
	  is_audio = 1;
	  data_out = audio_read_val;
       end
     endcase // addr[28:12]
  end

  uart uart_mod(
		.clk(clkrst_core_clk),
		.tx_pin(ext_uart_tx),
		.rx_pin(ext_uart_rx),
		.addr(addr[2]),
		.write_en(is_uart & wren[0]),
		.write_val(data_in),
		.read_val(uart_read_val)
		);

  /* MCPU_SOC_ledsw AUTO_TEMPLATE(
   .data_out(ledsw_data_out[]),
   .write_mask(is_ledsw ? write_mask[] : 32'h0),
   .addr(addr[2]));*/
  MCPU_SOC_ledsw ledsw_mod(
			   /*AUTOINST*/
			   // Outputs
			   .ext_led_r		(ext_led_r[9:0]),
			   .ext_led_g		(ext_led_g[7:0]),
			   .data_out		(ledsw_data_out[31:0]), // Templated
			   // Inputs
			   .ext_switches	(ext_switches[9:0]),
			   .ext_buttons		(ext_buttons[3:0]),
			   .clkrst_core_clk	(clkrst_core_clk),
			   .clkrst_core_rst_n	(clkrst_core_rst_n),
			   .addr		(addr[2]),	 // Templated
			   .data_in		(data_in[31:0]),
			   .write_mask		(is_ledsw ? write_mask[31:0] : 32'h0)); // Templated

  /* MCPU_SOC_i2c AUTO_TEMPLATE(
   .data_out(i2c_read_val[]),
   .addr(addr[2]),
   .write_en(is_i2c ? wren[] : 4'h0),
   .scl(ext_i2c_scl),
   .sda(ext_i2c_sda));*/
  MCPU_SOC_i2c i2c_mod(/*AUTOINST*/
		       // Outputs
		       .data_out	(i2c_read_val[31:0]),	 // Templated
		       .scl		(ext_i2c_scl),		 // Templated
		       // Inouts
		       .sda		(ext_i2c_sda),		 // Templated
		       // Inputs
		       .clkrst_core_clk	(clkrst_core_clk),
		       .clkrst_core_rst_n(clkrst_core_rst_n),
		       .addr		(addr[2]),		 // Templated
		       .data_in		(data_in[31:0]),
		       .write_en	(is_i2c ? wren[3:0] : 4'h0)); // Templated

  /* MCPU_SOC_sd AUTO_TEMPLATE(
   .read_val(sd_read_val[]),
   .clk(clkrst_core_clk),
   .reset_n(clkrst_core_rst_n),
   .cmdline(ext_sd_cmd),
   .dataline(ext_sd_data[]),
   .sdclk(ext_sd_clk),
   .addr(addr[11:2]),
   .write_en(is_sd & |wren[3:0]),
   .write_val(data_in[]));*/
  MCPU_SOC_sd sd_mod(/*AUTOINST*/
		     // Outputs
		     .read_val		(sd_read_val[31:0]),	 // Templated
		     .sdclk		(ext_sd_clk),		 // Templated
		     // Inouts
		     .cmdline		(ext_sd_cmd),		 // Templated
		     .dataline		(ext_sd_data[3:0]),	 // Templated
		     // Inputs
		     .clk		(clkrst_core_clk),	 // Templated
		     .reset_n		(clkrst_core_rst_n),	 // Templated
		     .addr		(addr[11:2]),		 // Templated
		     .write_en		(is_sd & |wren[3:0]),	 // Templated
		     .write_val		(data_in[31:0]));	 // Templated

  /* MCPU_SOC_audio AUTO_TEMPLATE(
   .write_mask(is_audio ? write_mask[] : 32'h0),
   .data_out(audio_read_val[]),
   .addr(addr[11:2]));*/
  MCPU_SOC_audio audio_mod(/*AUTOINST*/
			   // Outputs
			   .ext_audio_mclk	(ext_audio_mclk),
			   .ext_audio_bclk	(ext_audio_bclk),
			   .ext_audio_data	(ext_audio_data),
			   .ext_audio_lrclk	(ext_audio_lrclk),
			   .data_out		(audio_read_val[31:0]), // Templated
			   // Inputs
			   .clkrst_core_clk	(clkrst_core_clk),
			   .clkrst_core_rst_n	(clkrst_core_rst_n),
			   .clkrst_audio_clk	(clkrst_audio_clk),
			   .addr		(addr[11:2]),	 // Templated
			   .data_in		(data_in[31:0]),
			   .write_mask		(is_audio ? write_mask[31:0] : 32'h0)); // Templated


  MCPU_SOC_video video_mod(/*AUTOINST*/
			   // Outputs
			   .ext_hdmi_clk	(ext_hdmi_clk),
			   .ext_hdmi_hsync	(ext_hdmi_hsync),
			   .ext_hdmi_vsync	(ext_hdmi_vsync),
			   .ext_hdmi_de		(ext_hdmi_de),
			   .ext_hdmi_r		(ext_hdmi_r[7:0]),
			   .ext_hdmi_g		(ext_hdmi_g[7:0]),
			   .ext_hdmi_b		(ext_hdmi_b[7:0]),
			   // Inputs
			   .clkrst_core_clk	(clkrst_core_clk),
			   .clkrst_core_rst_n	(clkrst_core_rst_n));
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
