module MCPU_SOC_video(/*AUTOARG*/
   // Outputs
   ext_hdmi_clk, ext_hdmi_hsync, ext_hdmi_vsync, ext_hdmi_de,
   ext_hdmi_r, ext_hdmi_g, ext_hdmi_b, video2ltc_re, video2ltc_addr,
   data_out,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, video2ltc_rvalid,
   video2ltc_rdata, video2ltc_stall, addr, data_in, write_mask
   );

  input clkrst_core_clk;
  input clkrst_core_rst_n;

  output ext_hdmi_clk;
  output ext_hdmi_hsync;
  output ext_hdmi_vsync;
  output ext_hdmi_de;

  output [7:0] ext_hdmi_r;
  output [7:0] ext_hdmi_g;
  output [7:0] ext_hdmi_b;

  reg 	       hdmi_clk;

  reg [31:0]   pixel_count;
  reg [31:0]   row_count;
  reg [31:0]   offs;


  // Video memory interface
  output reg      video2ltc_re;
  output reg [28:7] video2ltc_addr;
  input 	video2ltc_rvalid;
  input [127:0] video2ltc_rdata;
  input 	video2ltc_stall;

  // MMIO interface.
  input [9:0] 	addr;
  input [31:0] 	data_in;
  input [31:0]  write_mask;
  output reg [31:0] data_out;

  reg [1023:0] 	ltc_buffer;
  reg [2047:0] 	pixel_buffer;
  reg [2047:0] 	next_pixel_buffer;

  reg 		ltc_re;
  reg [28:7] 	ltc_addr;
  reg [2:0] 	ltc_read_pos;
  reg [1:0] 	video_ctr;


  reg [639:0]  triangle;

  wire 	       triangle_pix = triangle[639 - (pixel_count - 16 - 96 - 48)];

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			fifo_empty;		// From video_fifo of FIFO.v
  wire			fifo_full;		// From video_fifo of FIFO.v
  wire [1023:0]		fifo_rdata;		// From video_fifo of FIFO.v
  // End of automatics

  assign ext_hdmi_r = pixel_buffer[pixel_pos +: 8];
  assign ext_hdmi_g = pixel_buffer[pixel_pos + 8 +: 8];
  assign ext_hdmi_b = pixel_buffer[pixel_pos + 16 +: 8];

  assign ext_hdmi_clk = ~hdmi_clk;
  assign ext_hdmi_hsync = ~(pixel_count >= 16 && pixel_count < 16 + 96);
  assign ext_hdmi_vsync = ~(row_count >= 480 + 11 && row_count < 480 + 11 + 2);
  assign ext_hdmi_de = (pixel_count >= 16 + 96 + 48 && row_count < 480);

  // TODO: size.
  reg [31:0] 		pixel_pos;
  reg [31:0] 		next_pixel_pos;
  reg [1:0] 		preload_pos;
  reg [1:0] 		next_preload_pos;

  wire 			advance = pixel_pos >= 1024;

  reg 			fifo_pop;
  reg 			fifo_pop_1a;
  reg 			next_fifo_pop;

  // The HDMI side. Later, we might want this part of the logic to be on separate clock from the core,
  // with the FIFO transferring the data between them.
  always @(*) begin
     next_pixel_pos = pixel_pos;
     next_pixel_buffer = pixel_buffer;
     fifo_pop = 0;
     next_preload_pos = preload_pos;

     if (ext_hdmi_de) begin
	if (~hdmi_clk) next_pixel_pos = pixel_pos + 3 * 8;

	if (pixel_pos >= 1024) begin
	   if (hdmi_clk) begin
	      if (~fifo_empty)
		fifo_pop = 1;
	   end
	end
	// Note: 490 is kind of arbitrary. Just needs to be during the vsync.
     //end else if (row_count == 490 && pixel_count == 0) begin
	//next_preload_pos = 1;
	//next_pixel_pos = 0;
     end else if (preload_pos < 2 && ~fifo_empty) begin
	fifo_pop = 1;
	next_preload_pos = preload_pos + 1;
     end

     if (fifo_pop_1a) begin
	next_pixel_buffer = {fifo_rdata, pixel_buffer[2047:1024] };
	if (ext_hdmi_de) next_pixel_pos = pixel_pos - 1024 + 3 * 8;
     end
  end

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	hdmi_clk <= 0;
	pixel_count <= 0;
	row_count <= 525; // Start in the back porch.
	offs <= 0;
	pixel_pos <= 0;
	preload_pos <= 0;
     end else begin
	hdmi_clk <= ~hdmi_clk;

	//fifo_pop <= next_fifo_pop;
	fifo_pop_1a <= fifo_pop;

	pixel_pos <= next_pixel_pos;
	pixel_buffer <= next_pixel_buffer;
	preload_pos <= next_preload_pos;

	if (~hdmi_clk) begin

	   if (pixel_count < 800 - 1) begin
	      pixel_count <= pixel_count + 1;
	   end else begin
	      pixel_count <= 0;
	      if (row_count < 525 - 1) begin
		 //pixel_pos <= 0;
		 row_count <= row_count + 1;
	      end else begin
		 offs <= offs + 1;
		 row_count <= 0;
		 //if (row_count == 525 - 1)
		 //  preload_pos <= 0;
	      end
	   end
	end // if (~hdmi_clk)
     end // else: !if(~clkrst_core_rst_n)
  end // always @ (posedge clkrst_core_clk or negedge clkrst_core_rst_n)


  // The core side.
  reg req_sent;
  reg [21:0] ltc_addr_offs;

  reg [21:0] 	    vmem_base; // The actual video memory base, latched from vmem_reg at vsync

  reg [21:0] 	    vmem_reg; // User-visible vmem base register.
  reg 		    vsync_reg;

  localparam VMEM_BASE = 0;
  localparam STATUS = 1;

  always @(*) begin
    case (addr)
      VMEM_BASE: data_out = {3'h0, vmem_base, 7'h0};
      STATUS: data_out = {31'h0, vsync_reg};
      default: data_out = 0;
    endcase
  end

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	ltc_read_pos <= 0;
	video_ctr <= 0;
	ltc_buffer <= 1024'h0;
	ltc_addr_offs <= 0;
	req_sent <= 0;
       vmem_base <= 22'h200; // 0x10000
       vsync_reg <= 0;
     end else begin
       /* mmio interface */
       if (write_mask != 0) begin
	 if (addr == VMEM_BASE) vmem_reg <= (vmem_reg & ~write_mask[21:0]) | (data_in[28:7] & write_mask[28:7]);
	 if (addr == STATUS) vsync_reg <= vsync_reg & ~(write_mask[0] & data_in[0]);
       end

       /* video logic */
	if (~video2ltc_stall) begin
	   video2ltc_re <= ltc_re;
	   video2ltc_addr <= ltc_addr;
	end

	if (video2ltc_rvalid) begin
	   ltc_buffer[{ltc_read_pos, 7'b0} +: 128] <= video2ltc_rdata;
	   ltc_read_pos <= ltc_read_pos + 1;
	end

	if (ltc_read_pos <= 0) begin
	   video_ctr <= video_ctr + 1;
	end

	if (fifo_push) begin
	   if (ltc_addr_offs >= /*648 * 480 * 3 * 8 / (128 * 8) */ 7200 - 1) begin
	     ltc_addr_offs <= 0;
	     vmem_base <= vmem_reg;
	     vsync_reg <= 1;
	   end else
	     ltc_addr_offs <= ltc_addr_offs + 1;
	end
     end
  end // always @ (posedge clkrst_core_clk or negedge clkrst_core_rst_n)

  wire fifo_push = ltc_read_pos == 3'd7 && video2ltc_rvalid;

  always @(*) begin
     ltc_re = ltc_read_pos == 0 && ~fifo_full & ~video2ltc_re;
     ltc_addr = vmem_base + ltc_addr_offs;
  end

  /* FIFO AUTO_TEMPLATE(
   .clk (clkrst_core_clk),
   .rst_n (clkrst_core_rst_n),
   .wdata ({video2ltc_rdata, ltc_buffer[1024 - 128 - 1:0]}),
   .\(.*\) (fifo_\1[]));*/
  FIFO #(
  	 .WIDTH(1024),
  	 .DEPTH(16)
  	 ) video_fifo(/*AUTOINST*/
		      // Outputs
		      .full		(fifo_full),		 // Templated
		      .rdata		(fifo_rdata[1023:0]),	 // Templated
		      .empty		(fifo_empty),		 // Templated
		      // Inputs
		      .clk		(clkrst_core_clk),	 // Templated
		      .rst_n		(clkrst_core_rst_n),	 // Templated
		      .push		(fifo_push),		 // Templated
		      .wdata		({video2ltc_rdata, ltc_buffer[1024 - 128 - 1:0]}), // Templated
		      .pop		(fifo_pop));		 // Templated
endmodule


// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
