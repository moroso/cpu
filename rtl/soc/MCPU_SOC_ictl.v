`timescale 1 ps / 1 ps

module MCPU_SOC_ictl(/*AUTOARG*/
   // Outputs
   data_out, int_pending,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, addr, data_in, write_mask,
   interrupt_trigger
   );
  parameter NUM_PERIPHS = 1;

  input clkrst_core_clk, clkrst_core_rst_n;

  // MMIO interface.
  input [9:0] 	addr;
  input [31:0] 	data_in;
  input [31:0]  write_mask;
  output reg [31:0] data_out;

  input [32 * NUM_PERIPHS - 1:0] interrupt_trigger;
  reg [31:0] 	    interrupt_enable[NUM_PERIPHS-1:0];
  reg [31:0] 	    next_interrupt_enable[NUM_PERIPHS-1:0];
  reg [31:0] 	    interrupt_pending[NUM_PERIPHS-1:0];
  reg [31:0] 	    next_interrupt_pending[NUM_PERIPHS-1:0];
  wire [31:0] periph_int_triggered;

  // This is the signal that actually fires an interrupt (if they're globally enabled).
  output 	    int_pending;

  assign int_pending = |periph_int_triggered;

  genvar 	    ii;

  generate for (ii = 0; ii < 32; ii = ii + 1) begin: trigger_gen
     if (ii < NUM_PERIPHS)
       assign periph_int_triggered[ii] = |(interrupt_pending[ii] & interrupt_enable[ii]);
     else
       assign periph_int_triggered[ii] = 0;
  end
  endgenerate

  integer i;

  always @(*) begin
     data_out = 32'hx;

     if (addr == 0) data_out = periph_int_triggered;
     else if (addr[9:8] == 2'b01) begin
	for (i = 0; i < NUM_PERIPHS; i = i + 1) begin
	   if (addr[7:0] == i[7:0]) data_out = interrupt_pending[i];
	end
     end else if (addr[9:8] == 2'b10) begin
	for (i = 0; i < NUM_PERIPHS; i = i + 1) begin
	   if (addr[7:0] == i[7:0]) data_out = interrupt_enable[i];
	end
     end
  end

  always @(*) begin
     for (i = 0; i < NUM_PERIPHS; i = i + 1) begin
	next_interrupt_pending[i] = interrupt_pending[i];
	next_interrupt_enable[i] = interrupt_enable[i];

	if (addr == {2'b01, i[7:0]})
	  next_interrupt_pending[i] = interrupt_pending[i] & ~(data_in & write_mask);
	else if (addr == {2'b10, i[7:0]})
	  next_interrupt_enable[i] = (interrupt_enable[i] & ~write_mask) | (data_in & write_mask);

	next_interrupt_pending[i] = next_interrupt_pending[i] | interrupt_trigger[32 * i +: 32];
     end
  end

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	for (i = 0; i < NUM_PERIPHS; i = i + 1) begin
	   interrupt_enable[i] <= 0;
	   interrupt_pending[i] <= 0;
	end
     end else begin
	for (i = 0; i < NUM_PERIPHS; i = i + 1) begin
	   interrupt_pending[i] <= next_interrupt_pending[i];
	   interrupt_enable[i] <= next_interrupt_enable[i];
	end
     end
  end

endmodule
