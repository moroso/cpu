`timescale 1ns / 1ns

module MCPU_top_modelsim();

reg CLOCK_125_p = 1'b0;
reg CPU_RESET_n = 1'b0;

integer i = 0;
wire [31:0] memoutput;
wire uart_tx;

initial begin
  forever begin
    #5 CLOCK_125_p = ~CLOCK_125_p;
    #5 CLOCK_125_p = ~CLOCK_125_p;
    $display("clk %d, reset %d, memoutput %x", i, CPU_RESET_n, memoutput);
  end
end

initial begin
  CPU_RESET_n = 1'b0;
  #15;
  CPU_RESET_n = 1'b1;
end
  

TB_MCPU_core tb(
	.clkrst_core_clk(CLOCK_125_p),
	.clkrst_core_rst_n(CPU_RESET_n),
	.memoutput(memoutput),
	.meminput(32'd5),
	.uart_tx(uart_tx),
	.uart_rx(0)
);

endmodule
