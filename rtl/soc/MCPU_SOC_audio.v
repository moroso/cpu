module MCPU_SOC_audio(/*AUTOARG*/
  // Outputs
  ext_audio_mclk, ext_audio_bclk, ext_audio_data, ext_audio_lrclk,
  // Inputs
  clkrst_core_clk, clkrst_core_rst_n
  );
  input clkrst_core_clk, clkrst_core_rst_n;

  output ext_audio_mclk;
  output ext_audio_bclk;
  output ext_audio_data;
  output ext_audio_lrclk;

  reg [31:0] ctr;

  reg [17:0] lfsr = 18'h1;

  always @(posedge clkrst_core_clk) if (ctr[4:0] == 0)
    lfsr <= {lfsr[0] ^ lfsr[7], lfsr[17:1]};

  assign ext_audio_mclk = ctr[2];
  assign ext_audio_bclk = ctr[4];
  assign ext_audio_lrclk = ctr[9]; // Toggle every 16 bclk cycles

  //wire [15:0] audio_word = ctr[16] ? 16'h0000 : 16'h0001; //{ctr[9 +: 5], 11'h0};
  wire [15:0] audio_word = ctr[13] ? 16'h0000 : 16'h7000; //{ctr[9 +: 5], 11'h0};
  //wire [15:0] audio_word = {ctr[12 +: 5], 11'h0};
  assign ext_audio_data = audio_word[15 - ctr[5 +: 4]];
  //assign ext_audio_data = ctr[//lfsr[0] & (ctr[9:8] == 2'b10 || ctr[9:8] == 2'b01);

  always @(posedge clkrst_core_clk) begin
     ctr <= ctr + 1;
  end
endmodule
