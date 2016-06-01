module MCPU_top();

reg CLOCK_125_p = 1'b0;
reg CPU_RESET_n = 1'b0;

integer i = 0;
wire [31:0] memoutput;

initial begin
  $dumpfile("iverilog_out.vcd");
  $dumpvars(0, tb);
end

initial begin
  for (i = 0; i < 100; i = i + 1) begin
    #5 CLOCK_125_p = ~CLOCK_125_p;
    #5 CLOCK_125_p = ~CLOCK_125_p;
    $display("clk %d, reset %d, memoutput %x", i, CPU_RESET_n, memoutput);
  end
end

initial begin
  CPU_RESET_n = 1'b0;
  #50;
  CPU_RESET_n = 1'b1;
end
  

TB_MCPU_core tb(
	.clkrst_core_clk(CLOCK_125_p),
	.clkrst_core_rst_n(CPU_RESET_n),
	.memoutput(memoutput),
	.meminput(32'd5)
);

endmodule
