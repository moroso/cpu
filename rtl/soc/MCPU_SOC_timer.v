`timescale 1 ps / 1 ps

module MCPU_SOC_timer(/*AUTOARG*/
   // Outputs
   data_out, interrupt_trigger,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, addr, data_in, write_mask
   );

  input clkrst_core_clk, clkrst_core_rst_n;

  // MMIO interface.
  input [9:0] 	addr;
  input [31:0] 	data_in;
  input [31:0]  write_mask;
  output reg [31:0] data_out;

  output [31:0]     interrupt_trigger;
  reg 		    interrupt;

  reg [31:0] 	    top;
  reg [31:0] 	    ctr;
  reg 		    enabled;

  reg 		    next_interrupt;
  reg [31:0] 	    next_top;
  reg [31:0] 	    next_ctr;
  reg 		    next_enabled;

  assign interrupt_trigger = {31'h0, interrupt};

  always @(*) begin
     case (addr)
       0: data_out = ctr;
       1: data_out = top;
       2: data_out = {31'h0, enabled};
       default: data_out = 32'hx;
     endcase
  end


  always @(*) begin
     next_interrupt = 0;
     next_top = top;
     next_ctr = ctr;
     next_enabled = enabled;

     if (enabled) begin
	if (ctr + 1 == top) begin
	   next_interrupt = 1;
	   next_ctr = 0;
	end else begin
	   next_ctr = ctr + 1;
	end
     end

     case (addr)
       0: next_ctr = (next_ctr & ~write_mask) | (data_in & write_mask);
       1: next_top = (next_top & ~write_mask) | (data_in & write_mask);
       2: next_enabled = (next_enabled & ~write_mask[0]) | (data_in[0] & write_mask[0]);
     endcase
  end

  always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
     if (~clkrst_core_rst_n) begin
	top <= 0;
	ctr <= 0;
	enabled <= 0;
	interrupt <= 0;
     end else begin
	ctr <= next_ctr;
	top <= next_top;
	enabled <= next_enabled;
	interrupt <= next_interrupt;
     end
  end

endmodule
