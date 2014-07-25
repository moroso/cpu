module register(/*AUTOARG*/
   // Outputs
   Q,
   // Inputs
   D, en, clkrst_core_clk, clkrst_core_rst_n
   );
  parameter WIDTH = 8;
  parameter RESET_VAL = 8'd0;
  input [WIDTH-1:0] D;
  output reg [WIDTH-1:0] Q;
  input en;
  input clkrst_core_clk, clkrst_core_rst_n;

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
    if(~clkrst_core_rst_n) begin
      Q <= RESET_VAL;
    end
    else if(en) begin
      Q <= D;
    end
  end
endmodule
