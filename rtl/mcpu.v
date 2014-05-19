`timescale 1ns/10ps

module MCPU_pll(
	input wire refclk,
	input wire rst,
	output wire outclk_0,
	output wire locked
);

	altera_pll #(
		.fractional_vco_multiplier("false"),
		.reference_clock_frequency("125.0 MHz"),
		.operation_mode("direct"),
		.number_of_clocks(1),
		.output_clock_frequency0("50.000000 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.pll_type("General"),
		.pll_subtype("General")
	) altera_pll_i (
		.rst	(rst),
		.outclk	({outclk_0}),
		.locked	(locked),
		.fboutclk	( ),
		.fbclk	(1'b0),
		.refclk	(refclk)
	);
endmodule

module mcpu(input clk125, output wire led);
	wire clk50;
	
	reg [24:0] ctr;
	
	MCPU_pll u_pll(
		.refclk(clk125),
		.rst(0),
		.outclk_0(clk50),
		.locked()
	);
	
	always @(posedge clk50)
		ctr <= ctr + 1;
	assign led = ctr[24];
endmodule
