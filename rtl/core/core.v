
module mcpu_core(/*AUTOARG*/);

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  /* Interrupt Controller */
  input int_pending;
  input [3:0] int_type; // TODO how big is this???
  output int_clear;

  /* TODO DTLB/I$/D$ interface */

  /* ITLB interface */
  output [19:0] ft2itlb_virtpage;
  input ft2itlb_ready;
  input [19:0] ft2itlb_physpage;

  /* TODO something about MMIOs */

  /*AUTOREG*/
  /*AUTOWIRE*/


  /* TODO make sure all of these autos actually do the right thing oh god */

  mcpu_regfile regs(/*AUTOINST*/);

  /* Pipeline! */
  stage_fetchtlb ft(/*AUTOINST*/);

  register #(.WIDTH(48), .RESET_VAL(48'd0)) 
           ft2f_reg(.D({ft2f_out_physpage, ft2f_out_virtpc}), 
                    .Q({ft2f_in_physpage, ft2f_in_virtpc}), 
                    .en(ft2f_readyout & ft2f_readyin),
                    /*AUTOINST*/);

  stage_fetch f(/*AUTOINST*/);

  wire f2d_in_packet;
  wire f2d_in_virtpc;
  wire f2d_readyin;
  assign f2d_readyin = d2pc_readyin; // decode always takes 1 cycle

  register #(.WIDTH(156), .RESET_VAL(156'd0))
           f2d_reg(.D({f2d_out_packet, f2d_out_virtpc}),
                   .Q({f2d_in_packet, f2d_in_virtpc}),
                   .en(f2d_readyout, f2d_readyin),
                   /*AUTOINST*/);

  wire long_imm0, long_imm1, long_imm2, long_imm3;
  mcpu_decode d0(.inst(f2d_in_packet[31:0]),
                 .nextinst(f2d_in_packet[63:32]),
                 .prev_long_imm(1'b0);
                 /*AUTOINST*/);
  mcpu_decode d1(.inst(f2d_in_packet[63:32]),
                 .nextinst(f2d_in_packet[95:64]),
                 .prev_long_imm(long_imm0);
                 /*AUTOINST*/);
  mcpu_decode d2(.inst(f2d_in_packet[63:32]),
                 .nextinst(f2d_in_packet[95:64]),
                 .prev_long_imm(long_imm1);
                 /*AUTOINST*/);
  mcpu_decode d3(.inst(f2d_in_packet[95:64]),
                 .nextinst('x),
                 .prev_long_imm(long_imm2);
                 /*AUTOINST*/);



endmodule


module register(/*AUTOARG*/);
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
