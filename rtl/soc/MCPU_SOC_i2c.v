module i2c_internal(
		    input 	     reset_n,
		    input 	     clk,

		    input 	     re,
		    input 	     we,
		    input 	     start_cond,
		    input 	     end_cond,
		    input [7:0]      wdata,
		    output reg [7:0] rdata,

		    output 	     ready,

		    output 	     scl,
		    inout 	     sda
		    );
  localparam ST_IDLE = 0;
  localparam ST_START_BIT = 1;
  localparam ST_PREPARE = 2;
  localparam ST_SENDING = 3;
  localparam ST_READ_ACK = 4;
  localparam ST_RECEIVING = 5;
  localparam ST_SEND_ACK = 6;
  localparam ST_STOP_BIT = 7;
  localparam STATE_BITS = 3;
  localparam ctr_max = 32'hff; // TODO

  reg  out;

  // The i2c bit clock. Every two times it reaches ctr_max, we toggle the output clock--so
  // the reset frequency of this is 4x the i2c bit clock frequency.
  reg [31:0] ctr;
  reg [31:0] next_ctr;

  // 0 is the first half of the clock being high.
  reg [1:0]  phase;

  wire 	     i2c_tick = (ctr == ctr_max);
  wire 	     output_bit_tick = i2c_tick & (phase == 2);
  wire 	     read_bit_tick = i2c_tick & (phase == 0);
  wire 	     state_tick = i2c_tick & (phase == 3);
  wire 	     start_bit_tick = read_bit_tick;
  reg 	     latch_inputs;
  reg 	     clock_force_low;
  reg 	     clock_force_high;

  wire 	     clkout = ~phase[1] & ~clock_force_low | clock_force_high;

`ifdef VERILATOR
  assign scl = clkout;
  assign sda = out;
`else
  assign scl = clkout ? 1'bz : 1'b0;
  assign sda = out ? 1'bz : 1'b0;
`endif

  reg [STATE_BITS-1:0] state;
  reg [STATE_BITS-1:0] next_state;

  reg [3:0] 	       bit_count;
  reg [3:0] 	       next_bit_count;

  reg 		       output_bit;

  reg [7:0] 	       wdata_1a;
  reg 		       re_1a;
  reg 		       we_1a;
  reg 		       end_cond_1a;

  reg 		       update_out_bit;

  reg 		       read_bit;

  assign ready = (state == ST_IDLE);

  always @(*) begin
     if (state == ST_IDLE)
       next_ctr = 0;
     else if (i2c_tick)
       next_ctr = 0;
     else
       next_ctr = ctr + 1;
  end

  always @(*) begin
     latch_inputs = 0;
     next_state = state;
     output_bit = 1;
     next_bit_count = 0;
     update_out_bit = output_bit_tick;
     read_bit = 0;
     clock_force_low = 0;
     clock_force_high = 0;

     case (state)
       ST_IDLE: begin
	  latch_inputs = 1;
	  if (re | we) begin
	     if (start_cond)
	       next_state = ST_START_BIT;
	     else begin
		clock_force_low = 1;
		next_state = ST_PREPARE;
	     end
	  end
       end // case: ST_IDLE
       ST_START_BIT: begin
	  if (start_bit_tick) begin
	     output_bit = 0; // Start condition
	     update_out_bit = 1;
	  end else begin
	     if (output_bit_tick) begin
		output_bit = wdata_1a[7];
		update_out_bit = 1;
	     end
	     next_bit_count = 1;
	  end
	  if (re_1a)
	    next_state = ST_RECEIVING;
	  else
	    next_state = ST_SENDING;
       end // case: ST_START_BIT
       ST_PREPARE: begin
	  // When we're not actually sending a start condition, this state
	  // acts as a placeholder.
	  clock_force_low = 1;
	  if (we_1a) begin
	     output_bit = wdata_1a[7];
	     next_state = ST_SENDING;
	  end else begin
	     output_bit = 1;
	     next_state = ST_RECEIVING;
	  end
	  next_bit_count = 1;
       end
       ST_SENDING: begin
	  output_bit = wdata_1a[7-bit_count];
	  next_bit_count = bit_count + 1;
	  if (bit_count == 8) begin
	     next_state = ST_READ_ACK;
	     output_bit = 1; // Prepare to read ACK.
	  end
       end
       ST_READ_ACK: begin
	  if (end_cond_1a) begin
	     output_bit = 0;
	     next_state = ST_STOP_BIT;
	  end else begin
	     output_bit = 1;
	     next_state = ST_IDLE;
	  end
       end
       ST_RECEIVING: begin
	  output_bit = 1;
	  read_bit = read_bit_tick;
	  next_bit_count = bit_count + 1;
	  if (bit_count == 8) begin
	     if (end_cond_1a)
	       next_state = ST_STOP_BIT;
	     else
	       next_state = ST_SEND_ACK;
	     output_bit = 0;
	  end
       end
       ST_SEND_ACK: begin
	  output_bit = 0;
	  clock_force_high = 1;
	  if (end_cond_1a) begin
	     next_state = ST_STOP_BIT;
	  end else begin
	     next_state = ST_IDLE;
	  end
       end
       ST_STOP_BIT: begin
	  update_out_bit = read_bit_tick;
	  output_bit = 1;
	  next_state = ST_IDLE;
       end
     endcase
  end

  always @(posedge clk or negedge reset_n) begin
     if (~reset_n) begin
	out <= 1;
	ctr <= 0;
	state <= 0;
	phase <= 0;
	bit_count <= 0;
     end else begin
	ctr <= next_ctr;

	if (state == ST_IDLE || state_tick) begin
	   state <= next_state;
	   bit_count <= next_bit_count;
	end

	if (i2c_tick) begin
	   phase <= phase + 1;
	end

	if (update_out_bit) begin
	   out <= output_bit;
	end

	if (latch_inputs) begin
	   wdata_1a <= wdata;
	   re_1a <= re;
	   we_1a <= we;
	   end_cond_1a <= end_cond;
	end

	if (read_bit)
	  rdata <= {rdata[6:0], sda};
     end
  end
endmodule

`ifdef IVERILOG
module i2c_internal_tb();
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [7:0]		rdata;			// From i2c of i2c_internal.v
  wire			ready;			// From i2c of i2c_internal.v
  wire			scl;			// From i2c of i2c_internal.v
  wire			sda;			// To/From i2c of i2c_internal.v
  // End of automatics

  reg 			reset_n;
  reg 			clk;
  reg 			re;
  reg 			we;
  reg [31:0] 		wdata;
  reg 			start_cond = 0;
  reg 			end_cond = 0;
  reg 			sda_reg = 1'hz;

  assign sda = sda_reg;

  /* i2c_internal AUTO_TEMPLATE(); */
  i2c_internal i2c(/*AUTOINST*/
		   // Outputs
		   .rdata		(rdata[7:0]),
		   .ready		(ready),
		   .scl			(scl),
		   // Inouts
		   .sda			(sda),
		   // Inputs
		   .reset_n		(reset_n),
		   .clk			(clk),
		   .re			(re),
		   .we			(we),
		   .start_cond		(start_cond),
		   .end_cond		(end_cond),
		   .wdata		(wdata[7:0]));

  always #1 clk <= ~clk;

  initial #10000 $finish();

  initial begin
     clk <= 0;
     reset_n <= 0;

     wdata <= 32'ha5;
     start_cond = 1;
     re <= 0;
     //end_cond = 1;

     #10 reset_n <= 1;
     #10 we <= 1;
     #10 we <= 0;

     @(posedge ready);
     end_cond <= 1;
     sda_reg <= 1;
     #10 re <= 1;
     #10 re <= 0;
     #750 sda_reg <= 0;
     #100 sda_reg <= 'hz;
     //@(posedge ready);
  end

  initial begin
     $dumpfile("iverilog_out.vcd");
     $dumpvars(0, i2c);
  end
endmodule // i2c_internal_tb
`endif

module MCPU_SOC_i2c(/*AUTOARG*/
   // Outputs
   data_out, scl,
   // Inouts
   sda,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, addr, data_in, write_en
   );

  // mmio interface
  input        clkrst_core_clk, clkrst_core_rst_n;
  input        addr; // single bit; only two mmio addresses.
  input [31:0] data_in;
  input [3:0]  write_en;
  output reg [31:0] data_out;

  // i2c wires
  output 	    scl;
  inout 	    sda;

  // Register map:
  // CR: [DRE:1][TXC:1][RXC:1] // TODO: error bits and stuff
  // DR:
  //   write: [WE:1][START:1][STOP:1][DATA:8 (ignored if WE=0)]
  //   read:  [RDATA:8]

  reg [7:0] 	    dr;
  reg 		    dr_valid, dr_valid_1a;
  reg 		    dr_start;
  reg 		    dr_stop;
  reg 		    dr_re, dr_re_1a;
  reg 		    dr_we, dr_we_1a;

  reg 		    txc, rxc;
  wire [2:0] 	    CR = {~dr_valid, txc, rxc};
  wire [7:0] 	    rdata;
  reg [7:0] 	    rdata_buf;

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			ready;			// From i2c of i2c_internal.v
  // End of automatics

  always @(*) begin
     if (addr == 0)
       data_out = {29'h0, CR};
     else
       data_out = {24'h0, rdata_buf};
  end

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	dr_valid <= 0;
	dr_valid_1a <= 0;
	txc <= 0;
	rxc <= 0;
     end else begin

	if (ready) begin
	   if (dr_re_1a & dr_valid_1a) begin
	      rxc <= 1;
	      rdata_buf <= rdata;
	   end
	   if (dr_we_1a & dr_valid_1a) txc <= 1;

	   dr_re_1a <= dr_re;
	   dr_we_1a <= dr_we;
	   dr_valid_1a <= dr_valid;
	   dr_valid <= 0;
	end

	if (write_en != 0) begin
	   if (addr == 0) begin
	      if (write_en[0])
		{txc, rxc} <= {txc & ~data_in[1], rxc & ~data_in[0]};
	   end else begin
	      if (write_en[0])
		dr <= data_in[7:0];
	      if (write_en[1])
		{dr_re, dr_we, dr_start, dr_stop} <= {~data_in[10], data_in[10:8]};
	      dr_valid <= 1;
	   end
	end
     end // else: !if(~clkrst_core_rst_n)
  end

  /* i2c_internal AUTO_TEMPLATE(
   .reset_n(clkrst_core_rst_n),
   .clk(clkrst_core_clk),
   .re(dr_re & dr_valid),
   .we(dr_we & dr_valid),
   .start_cond(dr_start),
   .end_cond(dr_stop),
   .wdata(dr)); */
  i2c_internal i2c(/*AUTOINST*/
		   // Outputs
		   .rdata		(rdata[7:0]),
		   .ready		(ready),
		   .scl			(scl),
		   // Inouts
		   .sda			(sda),
		   // Inputs
		   .reset_n		(clkrst_core_rst_n),	 // Templated
		   .clk			(clkrst_core_clk),	 // Templated
		   .re			(dr_re & dr_valid),	 // Templated
		   .we			(dr_we & dr_valid),	 // Templated
		   .start_cond		(dr_start),		 // Templated
		   .end_cond		(dr_stop),		 // Templated
		   .wdata		(dr));			 // Templated

endmodule

`ifdef IVERILOG
module TB_MCPU_SOC_i2c();
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [31:0]		data_out;		// From i2c of MCPU_SOC_i2c.v
  wire			scl;			// From i2c of MCPU_SOC_i2c.v
  wire			sda;			// To/From i2c of MCPU_SOC_i2c.v
  // End of automatics

  reg 			clkrst_core_clk;
  reg 			clkrst_core_rst_n;
  reg 			addr;
  reg [31:0] 		data_in;
  reg [3:0] 		write_en;

  always #1 clkrst_core_clk <= ~clkrst_core_clk;

  initial begin
     clkrst_core_clk <= 0;
     write_en <= 0;
     clkrst_core_rst_n <= 0;
     #10 clkrst_core_rst_n <= 1;

     #10 addr <= 1;
     data_in <= 12'h673;
     write_en <= 4'hf;
     #2 write_en <= 0;

     #10 addr <= 1;
     data_in <= 12'h445;
     write_en <= 4'hf;
     #2 write_en <= 0;

     #1500
     #10 addr <= 1;
     data_in <= 12'h100;
     write_en <= 4'hf;
     #2 write_en <= 0;

     #3900 addr <= 0;
     data_in <= 'b11;
     write_en <= 4'hf;
     #2 write_en <= 0;
  end

  initial begin
     $dumpfile("iverilog_out.vcd");
     $dumpvars(0, i2c);
  end
  initial #10000 $finish();

  MCPU_SOC_i2c i2c(/*AUTOINST*/
		   // Outputs
		   .data_out		(data_out[31:0]),
		   .scl			(scl),
		   // Inouts
		   .sda			(sda),
		   // Inputs
		   .clkrst_core_clk	(clkrst_core_clk),
		   .clkrst_core_rst_n	(clkrst_core_rst_n),
		   .addr		(addr),
		   .data_in		(data_in[31:0]),
		   .write_en		(write_en[3:0]));
endmodule
`endif
