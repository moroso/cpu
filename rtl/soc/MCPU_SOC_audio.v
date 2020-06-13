module MCPU_SOC_audio(/*AUTOARG*/
   // Outputs
   ext_audio_mclk, ext_audio_bclk, ext_audio_data, ext_audio_lrclk,
   data_out,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, clkrst_audio_clk, addr,
   data_in, write_mask
   );

  parameter BUF_SIZE = 16; // Note: in samples (32 bits), not bytes.
  parameter BUF_ADDR_BITS = 4;

  localparam AUDIO_STATUS = 0;

  input clkrst_core_clk, clkrst_core_rst_n;
  input clkrst_audio_clk;

  output ext_audio_mclk;
  output ext_audio_bclk;
  output ext_audio_data;
  output ext_audio_lrclk;

  // MMIO interface.
  input [9:0] addr;
  input [31:0] data_in;
  input [31:0]  write_mask;
  output reg [31:0] data_out;

  wire 		    c_sample_req;
  wire 		    a_request_sample;
  wire 		    a_sample_available;
  wire [31:0] 	    a_sample;
  reg [31:0] 	    c_sample;
  wire 		    c_sample_valid;

  reg [31:0] a_ctr = 0;

  /* Audio clock domain */
  always @(posedge clkrst_audio_clk) a_ctr <= a_ctr + 1;
  assign ext_audio_mclk = clkrst_audio_clk;
  assign ext_audio_bclk = a_ctr[2]; // 1/8th of mclk. (Note that ctr[0] is already half-speed.)
  assign ext_audio_lrclk = ~a_ctr[7]; // 1/256th of mclk.

  assign a_request_sample = a_ctr[7:0] == 0;

  reg [31:0] a_next_audio_word;
  reg [31:0] a_audio_word;

  always @(posedge clkrst_audio_clk) begin
     // Note: this value might be wrong for one clock cycle (we really should do this
     // one cycle earlier), but it reads on the positive edge and this happens right
     // around the negative edge, so probably not worth caring about.
     if (a_request_sample)
       a_audio_word <= a_next_audio_word;

     if (a_sample_available)
       a_next_audio_word <= a_sample;
  end

  assign ext_audio_data = a_audio_word[31 - a_ctr[3 +: 5]];


  /* Core clock domain */

  reg [31:0] c_audio_buffer[BUF_SIZE-1:0];
  reg [BUF_ADDR_BITS-1:0] c_buf_ptr;

  reg 			  c_buf_start, c_buf_half;

  always @(*) begin
     case (addr)
	AUDIO_STATUS: data_out = {30'h0, c_buf_start, c_buf_half};
	default: begin
	   data_out = 0;
	   if (addr[9])
	     data_out = c_audio_buffer[addr[BUF_ADDR_BITS-1:0]];
	end
     endcase
  end

  integer i;
  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	c_buf_ptr <= 0;
	for (i = 0; i < BUF_SIZE; i = i + 1) c_audio_buffer[i] <= 0;
     end else begin
	if (addr == AUDIO_STATUS)
	  {c_buf_start, c_buf_half} <= {c_buf_start, c_buf_half} & ~(data_in[1:0] & write_mask[1:0]);

	if (c_sample_req) begin
	  c_buf_ptr <= c_buf_ptr + 1;

	   if (c_buf_ptr[BUF_ADDR_BITS-2:0] == 0) begin
	      if (c_buf_ptr[BUF_ADDR_BITS-1] == 0)
		c_buf_start <= 1;
	      else
		c_buf_half <= 1;
	   end
	end

	if (addr[9])
	  c_audio_buffer[addr[BUF_ADDR_BITS-1:0]] <= (c_audio_buffer[addr[BUF_ADDR_BITS-1:0]] & ~write_mask
						      | data_in & write_mask);
     end
  end

  reg [31:0] c_counter = 0;
  always @(posedge clkrst_core_clk) c_counter <= c_counter + 1;
  always @(*) c_sample = c_audio_buffer[c_buf_ptr];

  reg 	     c_sample_req_1a;
  always @(posedge clkrst_core_clk)
    c_sample_req_1a = c_sample_req;
  assign c_sample_valid = c_sample_req & ~c_sample_req_1a;

  /* Clock interface */
  clkdomain_buf #(.WIDTH(32)) core2audio_buf(.out(a_sample),
					     .in(c_sample),
					     .in_valid(c_sample_valid),
					     .out_valid(a_sample_available),
					     .in_ready(),
					     .rst_n(clkrst_core_rst_n),

					     .in_clk(clkrst_core_clk),
					     .out_clk(clkrst_audio_clk)
					     /*AUTOINST*/);

  // TODO: WIDTH=0 doesn't work. WIDTH=1 is probably fine, since those regs
  // should get optimized out. A little inelegant, though...
  clkdomain_buf #(.WIDTH(1)) audio2core_buf(.out(),
					    .in(),
					    .out_valid(c_sample_req),
					    .rst_n(clkrst_core_rst_n),
					    .in_clk(clkrst_audio_clk),
					    .out_clk(clkrst_core_clk),
					    .in_ready(),
					    .in_valid(a_request_sample)
					    /*AUTOINST*/);
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
