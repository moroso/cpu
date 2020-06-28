`timescale 1 ps / 1 ps

module reg_2(/*AUTOARG*/
   // Outputs
   Q,
   // Inputs
   D0, D1, en0, en1, clkrst_core_clk, clkrst_core_rst_n
   );
  parameter WIDTH = 8;
  parameter RESET_VAL = 8'd0;
  input [WIDTH-1:0] D0, D1;
  output reg [WIDTH-1:0] Q;
  input en0, en1;
  input clkrst_core_clk, clkrst_core_rst_n;

  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
    if(~clkrst_core_rst_n) begin
      Q <= RESET_VAL;
    end
    else if(en0) begin
      Q <= D0;
    end
    else if(en1) begin
      Q <= D1;
    end
  end
endmodule
