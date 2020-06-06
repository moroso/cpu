module MCPU_SOC_video(/*AUTOARG*/
  // Outputs
  ext_hdmi_clk, ext_hdmi_hsync, ext_hdmi_vsync, ext_hdmi_de,
  ext_hdmi_r, ext_hdmi_g, ext_hdmi_b,
  // Inputs
  clkrst_core_clk, clkrst_core_rst_n
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

  reg [639:0]  triangle;

  wire 	       triangle_pix = triangle[639 - (pixel_count - 16 - 96 - 48)];

  assign ext_hdmi_r = triangle_pix ? 8'hff : (pixel_count[7:0] - offs[7:0]);
  assign ext_hdmi_g = triangle_pix ? 8'hff : row_count[7:0];
  assign ext_hdmi_b = triangle_pix ? 8'hff : ext_hdmi_r ^ ext_hdmi_g;
  assign ext_hdmi_clk = ~hdmi_clk;
  assign ext_hdmi_hsync = ~(pixel_count >= 16 && pixel_count < 16 + 96);
  assign ext_hdmi_vsync = ~(row_count >= 480 + 11 && row_count < 480 + 11 + 2);
  assign ext_hdmi_de = (pixel_count >= 16 + 96 + 48 && row_count < 480);

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	hdmi_clk <= 0;
	pixel_count <= 0;
	row_count <= 0;
	triangle <= 0;
	offs <= 0;
     end else begin
	hdmi_clk <= ~hdmi_clk;
	if (~hdmi_clk) begin
	   if (pixel_count < 800 - 1)
	     pixel_count <= pixel_count + 1;
	   else begin
	      pixel_count <= 0;
	      if (row_count < 525 - 1) begin
		 row_count <= row_count + 1;
		 triangle <= triangle ^ {1'b0, triangle[639:1]};
	      end else begin
		 offs <= offs + 1;
		 row_count <= 0;
		 triangle <= {1'b1, 639'b0};
	      end
	   end
	end
     end
  end
endmodule
