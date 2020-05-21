`timescale 1ns / 1ps

module tristate_drv(
                    input  oe,
                    input  clk,
                    input  slowclk_on,
                    input  write_bit,
                    output read_bit,

                    inout  line
                    );

  reg 			   inreg;
  assign line = oe ? inreg : 1'bZ;
  assign read_bit = oe ? inreg : line;

  always @(posedge clk)
    if (slowclk_on) begin
       inreg <= write_bit;
    end
endmodule // tristate_drv

module sd_cmd_tx(
		 input 	      clk,
		 input 	      reset_n,
		 input 	      rise,
		 input 	      fall,
		 input [7:0]  cmd,
		 input [31:0] arg,
		 input 	      start_tx,

		 output       out_wire,
		 output       tx_idle
		 );
  localparam STATE_IDLE = 0;
  localparam STATE_START_BIT = 1;
  localparam STATE_FIRST_CMD_BIT = 2;
  localparam STATE_FIRST_ARG_BIT = 10;
  localparam STATE_FIRST_CRC_BIT = 42;
  localparam STATE_STOP_BIT = 49;

  reg 			      next_write_bit = 1;
  reg [5:0] 		      state = 0;
  reg [5:0] 		      next_state = 0;

  wire 			      crc_en;
  wire 			      crc_rst;
  wire [6:0] 		      crc_out;

  // We calculate the CRC of everything from the first command bit (inclusive),
  // which is really the start bit, to the first crc bit (exclusive).
  assign crc_en = (fall & (state >= STATE_FIRST_CMD_BIT)
                   & (state < STATE_FIRST_CRC_BIT));
  assign crc_rst = (state == STATE_FIRST_CMD_BIT);

  assign out_wire = next_write_bit;

  crc7 crc_inst(.out(crc_out),
                .clk(clk),
                .en(crc_en),
                .dat(next_write_bit),
                .rst(crc_rst));

  assign tx_idle = state == STATE_IDLE;

  always @(posedge clk or negedge reset_n) begin
     if (~reset_n) begin
	state <= STATE_IDLE;
     end else if (fall | start_tx) begin
        state <= next_state;
     end
  end

  always @(*) begin
     if (start_tx)
       next_state = STATE_START_BIT;
     else if (state == STATE_IDLE)
       next_state = STATE_IDLE;
     else if (state == STATE_STOP_BIT + 1)
       next_state = STATE_IDLE;
     else
       next_state = state + 1;
  end

  // Bits to output based on state.
  always @(*)
    if (state < STATE_FIRST_CMD_BIT)
      next_write_bit = 1;
    else if (state < STATE_FIRST_ARG_BIT)
      next_write_bit = cmd[7 - (state - STATE_FIRST_CMD_BIT)];
    else if (state < STATE_FIRST_CRC_BIT)
      next_write_bit = arg[31 - (state - STATE_FIRST_ARG_BIT)];
    else if (state < STATE_STOP_BIT)
      next_write_bit = crc_out[6 - (state - STATE_FIRST_CRC_BIT)];
    else
      next_write_bit = 1;

endmodule // sd_tx

module sd_cmd_rx(input clk,
		 input 		reset_n,
                 input 		rise,
                 input 		fall,
                 input [6:0] 	len,
                 input 		rx_start,
		 input 		tx_idle,

                 input 		in_wire,

                 output [127:0] read_val,
                 output 	err,
                 output 	rx_idle
                 );
  localparam STATE_IDLE = 0;
  localparam STATE_WAIT_START = 1;
  localparam STATE_READING = 2;
  localparam STATE_READING_CRC = 3;
  localparam STATE_READING_STOP = 4;

  reg [6:0] 			pos = 0;
  reg [6:0] 			remaining = 0;
  reg [6:0] 			next_remaining = 0;
  reg [127:0] 			read_buf = 0;
  reg [2:0] 			state = 0;
  reg [2:0] 			next_state = 0;
  reg [2:0] 			crc_pos = 0;

  assign read_val = read_buf;

  always @(posedge clk or negedge reset_n) begin
     if (~reset_n) begin
	state <= STATE_IDLE;
     end else begin
	if (rise | rx_start) begin
	   state <= next_state;
	end

	if (rx_start) begin
	   remaining <= len;
	   pos <= 0;
	   crc_pos <= 0;
	   read_buf <= 0;
	end

	if (rise) begin
	   if (next_state == STATE_READING) begin
	      read_buf[127 - pos] <= in_wire;
	      remaining <= remaining - 1;
	      pos <= pos + 1;
	   end

	   if (next_state == STATE_READING_CRC) begin
	      // TODO: actually read the CRC.
	      crc_pos <= crc_pos + 1;
	   end
	end // if (rise)
     end
  end // always @ (posedge clk)

  assign rx_idle = (state == STATE_IDLE);

  always @(*)
    if (rx_start)
      next_state = STATE_WAIT_START;
    else if (state == STATE_WAIT_START & tx_idle & ~in_wire)
      next_state = STATE_READING;
    else if (state == STATE_READING & remaining == 0)
      next_state = STATE_READING_CRC;
    else if (state == STATE_READING_CRC & crc_pos == 7)
      next_state = STATE_READING_STOP;
    else if (state == STATE_READING_STOP)
      next_state = STATE_IDLE;
    else
      next_state = state;

endmodule // sd_cmd_rx

module sd_data_rx(
		  input 	  clk,
                  input 	  rise,
                  input 	  fall,
                  input 	  rx_start,
		  input 	  width,

                  input [3:0] 	  in_wires,

                  output [4095:0] read_val,
                  output 	  err,
                  output 	  rx_idle);

  reg [4095:0] 			  outreg;
  assign read_val = outreg;

  reg [11:0] 			  remaining;
  reg 				  reading;
  reg 				  have_start_bit;

  assign rx_idle = ~reading;

  always @(posedge clk) begin
     if (rx_start) begin
	reading <= 1;
	have_start_bit <= 0;
	if (width == 0)
	  remaining <= 12'hfff;
	else
	  remaining <= 12'h3ff;
     end else if (reading & rise) begin
	if (have_start_bit) begin
	   if (remaining == 0)
	     reading <= 0;
	   if (width == 0)
	     outreg <= {outreg[4094:0], in_wires[0]};
	   else
	     outreg <= {outreg[4091:0], in_wires};
	   remaining <= remaining - 1;
	end else if (~in_wires[0]) begin
	   have_start_bit <= 1;
	end
     end
  end

endmodule // sd_data_rx

module MCPU_SOC_sd(
		   input 	     clk,
		   input 	     reset_n,
		   input [9:0] 	     addr,
		   input 	     write_en,
		   input [31:0]      write_val,
		   output reg [31:0] read_val,

		   inout 	     cmdline,
		   inout [3:0] 	     dataline,
		   output 	     sdclk
		   );
  localparam SD_SPEED = 0;
  localparam SD_CONTROL = 1;
  localparam SD_STATUS = 2;
  localparam SD_CMD = 3;
  localparam SD_ARG = 4;
  localparam SD_RESP = 8;
  localparam SD_DATA = 128;

  localparam STATE_IDLE = 0;
  localparam STATE_TRANSMITTING = 1;
  localparam STATE_RECEIVING = 2;

  reg [31:0] 			     speed = 1024;
  reg [31:0] 			     slowclk = 0;
  reg [31:0] 			     arg = 0;
  reg [7:0] 			     cmd;
  reg 				     data_width;

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			cmd_out_wire;		// From sd_cmd_tx_inst of sd_cmd_tx.v
  wire			cmd_rx_idle;		// From sd_cmd_rx_inst of sd_cmd_rx.v
  wire			cmd_tx_idle;		// From sd_cmd_tx_inst of sd_cmd_tx.v
  wire			data_rx_err;		// From sd_data_rx_inst of sd_data_rx.v
  wire			data_rx_idle;		// From sd_data_rx_inst of sd_data_rx.v
  wire [4095:0]		data_rx_val;		// From sd_data_rx_inst of sd_data_rx.v
  wire			err;			// From sd_cmd_rx_inst of sd_cmd_rx.v
  wire [127:0]		resp_buf;		// From sd_cmd_rx_inst of sd_cmd_rx.v
  // End of automatics

  wire 				     clk_en = 1; // TODO: a register for this.

  always @(posedge clk)
    if (~clk_en | slowclk >= speed - 1)
      slowclk <= 0;
    else
      slowclk <= slowclk + 1;

  assign sdclk = (slowclk > speed[31:1] - 1);
  wire 				     slowclk_rise = (slowclk == (speed[31:1] - 1));
  wire 				     slowclk_fall = (slowclk == (speed - 1));

  wire [11:0] 			     read_base = {7'h7f - addr[6:0], 5'h0};
  always @(*) begin
     case (addr)
       SD_SPEED: read_val = speed;
       SD_CONTROL: read_val = {31'h0, data_width};
       SD_STATUS: read_val = {27'h0, data_rx_err, err, ~cmd_tx_idle, ~data_rx_idle, ~cmd_rx_idle};
       SD_CMD: read_val = 0;
       SD_ARG: read_val = 0;
       SD_RESP: read_val = resp_buf[127:96];
       SD_RESP + 1: read_val = resp_buf[95:64];
       SD_RESP + 2: read_val = resp_buf[63:32];
       SD_RESP + 3: read_val = resp_buf[31:0];
       default: begin
	  read_val = 0;

	  if (addr[9]) begin
	     read_val = {
			 data_rx_val[read_base +: 8],
			 data_rx_val[read_base + 8 +: 8],
			 data_rx_val[read_base + 16 +: 8],
			 data_rx_val[read_base + 24 +: 8]
			 };
	  end
       end
     endcase // case (addr)
  end

  always @(posedge clk) begin

     if (write_en & addr == SD_SPEED)
       speed <= write_val;

     if (write_en & addr == SD_CONTROL)
       data_width <= write_val[0];

     if (write_en & addr == SD_ARG)
       arg <= write_val;

     if (write_en & addr == SD_CMD) begin
	cmd <= {2'b01, write_val[5:0]};
     end
  end // always @ (posedge clk)

  wire begin_transaction = (write_en & addr == SD_CMD);
  wire [7:0] resp_len = write_val[15:8];
  wire 	     data_read = write_val[16];
  wire 	     cmd_oe = ~cmd_tx_idle;

  wire 	     start_cmd_tx = begin_transaction;
  wire 	     start_cmd_rx = begin_transaction & (resp_len > 0);
  wire 	     start_data_rx = begin_transaction & data_read;

  wire 	     cmd_in_wire;
  wire [3:0] data_in_wire;

  tristate_drv cmd_drv(
                       .oe(cmd_oe),
                       .clk(clk),
                       .slowclk_on(slowclk_fall),
                       .write_bit(cmd_out_wire),
                       .read_bit(cmd_in_wire),
                       .line(cmdline)
                       /*AUTOINST*/);

  genvar     ii;

  generate for (ii = 0; ii < 4; ii = ii + 1) begin: drv_gen
     tristate_drv data_drv(
			   .oe(0), // TODO!
			   .clk(clk),
			   .slowclk_on(slowclk_fall),
			   .write_bit(0), // TODO!
			   .read_bit(data_in_wire[ii]),
			   .line(dataline[ii])
			   /*AUTOINST*/);
  end
  endgenerate

  sd_cmd_tx sd_cmd_tx_inst(// Inputs
                           .rise               (slowclk_rise),
                           .fall               (slowclk_fall),
			   .start_tx		(start_cmd_tx),
                           // Outputs
                           .out_wire           (cmd_out_wire),
                           .tx_idle            (cmd_tx_idle),
                           /*AUTOINST*/
			   // Inputs
			   .clk			(clk),
			   .reset_n		(reset_n),
			   .cmd			(cmd[7:0]),
			   .arg			(arg[31:0]));

  sd_cmd_rx sd_cmd_rx_inst(// Inputs
                           .rise               (slowclk_rise),
                           .fall               (slowclk_fall),
                           .len                (resp_len[6:0]),
                           .in_wire            (cmd_in_wire),
			   .tx_idle		(cmd_tx_idle),
			   .rx_start		(start_cmd_rx),
                           // Outputs
                           .read_val           (resp_buf[127:0]),
                           .rx_idle            (cmd_rx_idle),
                           /*AUTOINST*/
			   // Outputs
			   .err			(err),
			   // Inputs
			   .clk			(clk),
			   .reset_n		(reset_n));

  /* sd_data_rx AUTO_TEMPLATE(
   .read_val(data_rx_val[]),
   .err(data_rx_err),
   .rx_idle(data_rx_idle),
   .rx_start(start_data_rx),
   .in_wires(data_in_wire[]),
   .rise(slowclk_rise),
   .fall(slowclk_fall),
   .width(data_width[])); */
  sd_data_rx sd_data_rx_inst(/*AUTOINST*/
			     // Outputs
			     .read_val		(data_rx_val[4095:0]), // Templated
			     .err		(data_rx_err),	 // Templated
			     .rx_idle		(data_rx_idle),	 // Templated
			     // Inputs
			     .clk		(clk),
			     .rise		(slowclk_rise),	 // Templated
			     .fall		(slowclk_fall),	 // Templated
			     .rx_start		(start_data_rx), // Templated
			     .width		(data_width),	 // Templated
			     .in_wires		(data_in_wire[3:0])); // Templated

endmodule // sd
