/* Memory layout:
 0: [LED_R:10][LEDG:8] (rw)
 1: [SW:10][0:4][BUTTON:4] (ro)
 */

`timescale 1 ps / 1 ps

module MCPU_SOC_ledsw(/*AUTOARG*/
   // Outputs
   ext_led_r, ext_led_g, data_out, interrupts,
   // Inputs
   ext_switches, ext_buttons, clkrst_core_clk, clkrst_core_rst_n,
   addr, data_in, write_mask
   );
  // The actual switches/LEDs
  input [9:0] ext_switches;
  input [3:0] ext_buttons;
  output [9:0] ext_led_r;
  output [7:0] ext_led_g;

  // mmio interface
  input        clkrst_core_clk, clkrst_core_rst_n;
  input [9:0]  addr;
  input [31:0] data_in;
  input [31:0] write_mask;
  output reg [31:0] data_out;
  output [31:0]	    interrupts;

  reg [31:0] 	led_buf;

  assign {ext_led_r, ext_led_g} = led_buf[17:0];

  reg [13:0] 	    last_inputs;

  // TODO: more configurability around interrupts (which edge, or level, etc.)
  assign interrupts = {18'h0, {ext_switches, ext_buttons} ^ last_inputs};

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	led_buf <= 32'h0;
	last_inputs <= 0;
     end else begin
	last_inputs <= {ext_switches, ext_buttons};

	if (addr == 0) begin
	   led_buf <= (led_buf & ~write_mask) | (data_in & write_mask);
	end
     end
  end

  always @(*) begin
     case (addr)
       0: data_out = led_buf;
       1: data_out = {6'h0, ext_switches, 12'h0, ext_buttons};
       default: data_out = 32'hx;
     endcase
  end

endmodule
