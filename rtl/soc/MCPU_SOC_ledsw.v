/* Memory layout:
 0: [LED_R:10][LEDG:8] (rw)
 1: [SW:10][0:4][BUTTON:4] (ro)
 */

module MCPU_SOC_ledsw(/*AUTOARG*/
  // Outputs
  ext_led_r, ext_led_g, data_out,
  // Inputs
  ext_switches, ext_buttons, clkrst_core_clk, clkrst_core_rst_n, addr,
  data_in, write_mask
  );
  // The actual switches/LEDs
  input [9:0] ext_switches;
  input [3:0] ext_buttons;
  output [9:0] ext_led_r;
  output [7:0] ext_led_g;

  // mmio interface
  input        clkrst_core_clk, clkrst_core_rst_n;
  input        addr; // single bit; only two mmio addresses.
  input [31:0] data_in;
  input [31:0] write_mask;
  output reg [31:0] data_out;

  reg [31:0] 	led_buf;

  wire [31:0] 	next_led_buf = addr == 0 ? (led_buf & ~write_mask) | (data_in & write_mask) : led_buf;

  assign {ext_led_r, ext_led_g} = led_buf[17:0];

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	led_buf <= 32'h0;
     end else begin
	led_buf <= next_led_buf;
     end
  end

  always @(*) begin
     case (addr)
       0: data_out = led_buf;
       1: data_out = {6'h0, ext_switches, 12'h0, ext_buttons};
     endcase
  end

endmodule
