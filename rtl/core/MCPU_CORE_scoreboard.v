module MCPU_CORE_scoreboard(/*AUTOARG*/
   // Outputs
   sb2d_reg_scoreboard, sb2d_pred_scoreboard,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, wb2rf_rd_num0, wb2rf_rd_num1,
   wb2rf_rd_num2, wb2rf_rd_num3, wb2rf_rd_we0, wb2rf_rd_we1,
   wb2rf_rd_we2, wb2rf_rd_we3, wb2rf_pred_we0, wb2rf_pred_we1,
   wb2rf_pred_we2, wb2rf_pred_we3, d2pc_out_rd_num0, d2pc_out_rd_num1,
   d2pc_out_rd_num2, d2pc_out_rd_num3, d2pc_out_rd_we0,
   d2pc_out_rd_we1, d2pc_out_rd_we2, d2pc_out_rd_we3,
   d2pc_out_pred_we0, d2pc_out_pred_we1, d2pc_out_pred_we2,
   d2pc_out_pred_we3, d2pc_progress, exception, pipe_flush
   );

  input clkrst_core_clk, clkrst_core_rst_n;

  output [31:0] sb2d_reg_scoreboard;
  output [2:0] 	sb2d_pred_scoreboard;

  input [4:0] 	wb2rf_rd_num0, wb2rf_rd_num1, wb2rf_rd_num2, wb2rf_rd_num3;
  input 	wb2rf_rd_we0, wb2rf_rd_we1, wb2rf_rd_we2, wb2rf_rd_we3;
  input 	wb2rf_pred_we0, wb2rf_pred_we1, wb2rf_pred_we2, wb2rf_pred_we3;

  input [4:0] 	d2pc_out_rd_num0, d2pc_out_rd_num1, d2pc_out_rd_num2, d2pc_out_rd_num3;
  input 	d2pc_out_rd_we0, d2pc_out_rd_we1, d2pc_out_rd_we2, d2pc_out_rd_we3;
  input 	d2pc_out_pred_we0, d2pc_out_pred_we1, d2pc_out_pred_we2, d2pc_out_pred_we3;

  input 	d2pc_progress;
  input 	exception;
  input 	pipe_flush;

  /*AUTOREG*/

  reg [31:0] 	dcd_reg1h0, dcd_reg1h1, dcd_reg1h2, dcd_reg1h3;
  reg 		dcd_regval0, dcd_regval1, dcd_regval2, dcd_regval3;
  reg [31:0] 	wb_reg1c0, wb_reg1c1, wb_reg1c2, wb_reg1c3;
  reg 		wb_regval0, wb_regval1, wb_regval2, wb_regval3;

  reg [2:0] 	dcd_pred1h0, dcd_pred1h1, dcd_pred1h2, dcd_pred1h3;
  reg 		dcd_predval0, dcd_predval1, dcd_predval2, dcd_predval3;
  reg [2:0] 	wb_pred1c0, wb_pred1c1, wb_pred1c2, wb_pred1c3;
  reg 		wb_predval0, wb_predval1, wb_predval2, wb_predval3;

  wire [31:0] 	old_reg_field;
  wire [2:0] 	old_pred_field;

  // Register writes to add to the scoreboard
  wire [31:0] 	reg0_wmask = 32'd1 << d2pc_out_rd_num0;
  wire [31:0] 	reg1_wmask = 32'd1 << d2pc_out_rd_num1;
  wire [31:0] 	reg2_wmask = 32'd1 << d2pc_out_rd_num2;
  wire [31:0] 	reg3_wmask = 32'd1 << d2pc_out_rd_num3;

  wire [2:0] 	pred0_wmask = 3'd1 << d2pc_out_rd_num0[1:0];
  wire [2:0] 	pred1_wmask = 3'd1 << d2pc_out_rd_num1[1:0];
  wire [2:0] 	pred2_wmask = 3'd1 << d2pc_out_rd_num2[1:0];
  wire [2:0] 	pred3_wmask = 3'd1 << d2pc_out_rd_num3[1:0];

  wire 		we_reg0 = d2pc_out_rd_we0 & ~pipe_flush;
  wire 		we_reg1 = d2pc_out_rd_we1 & ~pipe_flush;
  wire 		we_reg2 = d2pc_out_rd_we2 & ~pipe_flush;
  wire 		we_reg3 = d2pc_out_rd_we3 & ~pipe_flush;

  wire 		we_pred0 = d2pc_out_pred_we0 & ~pipe_flush;
  wire 		we_pred1 = d2pc_out_pred_we1 & ~pipe_flush;
  wire 		we_pred2 = d2pc_out_pred_we2 & ~pipe_flush;
  wire 		we_pred3 = d2pc_out_pred_we3 & ~pipe_flush;

  // Registers to set in the scoreboard
  wire [31:0] 	reg_field = (reg0_wmask & {32{we_reg0}})
		| (reg1_wmask & {32{we_reg1}})
		| (reg2_wmask & {32{we_reg2}})
		| (reg3_wmask & {32{we_reg3}});

  // reg_field, from one d2c_progress ago.
  reg [31:0] 	last_reg_field;

  // Mask of registers to clear in the scoreboard--that is,
  // "old" registers that should no longer be set. (This is somewhat confusingly
  // named, given that it's completely different from last_reg_field!)
  assign old_reg_field = (wb_reg1c0 | {32{~wb_regval0}})
    &  (wb_reg1c1 | {32{~wb_regval1}})
      &  (wb_reg1c2 | {32{~wb_regval2}})
        &  (wb_reg1c3 | {32{~wb_regval3}});

  wire [2:0] 	pred_field = (pred0_wmask & {3{we_pred0}})
		| (pred1_wmask & {3{we_pred1}})
		| (pred2_wmask & {3{we_pred2}})
		| (pred3_wmask & {3{we_pred3}});

  reg [2:0] 	last_pred_field;

  assign old_pred_field = (wb_pred1c0 | {3{~wb_predval0}})
    & (wb_pred1c1 | {3{~wb_predval1}})
      & (wb_pred1c2 | {3{~wb_predval2}})
        & (wb_pred1c3 | {3{~wb_predval3}});

  reg [31:0] 	reg_scoreboard;
  assign sb2d_reg_scoreboard = reg_scoreboard & old_reg_field;

  reg [2:0] 	pred_scoreboard;
  assign sb2d_pred_scoreboard = pred_scoreboard & old_pred_field;


  always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
     if(~clkrst_core_rst_n) begin
        wb_reg1c0 <= 0;
        wb_reg1c1 <= 0;
        wb_reg1c2 <= 0;
        wb_reg1c3 <= 0;
        wb_regval0 <= 0;
        wb_regval1 <= 0;
        wb_regval2 <= 0;
        wb_regval3 <= 0;
        wb_pred1c0 <= 0;
        wb_pred1c1 <= 0;
        wb_pred1c2 <= 0;
        wb_pred1c3 <= 0;
        wb_predval0 <= 0;
        wb_predval1 <= 0;
        wb_predval2 <= 0;
        wb_predval3 <= 0;

	reg_scoreboard <= 0;
	pred_scoreboard <= 0;
	last_reg_field <= 0;
	last_pred_field <= 0;
     end
     else begin
        wb_reg1c0 <= ~(32'd1 << wb2rf_rd_num0);
        wb_reg1c1 <= ~(32'd1 << wb2rf_rd_num1);
        wb_reg1c2 <= ~(32'd1 << wb2rf_rd_num2);
        wb_reg1c3 <= ~(32'd1 << wb2rf_rd_num3);

        wb_regval0 <= wb2rf_rd_we0;
        wb_regval1 <= wb2rf_rd_we1;
        wb_regval2 <= wb2rf_rd_we2;
        wb_regval3 <= wb2rf_rd_we3;

        wb_pred1c0 <= ~(3'd1 << wb2rf_rd_num0[1:0]);
        wb_pred1c1 <= ~(3'd1 << wb2rf_rd_num1[1:0]);
        wb_pred1c2 <= ~(3'd1 << wb2rf_rd_num2[1:0]);
        wb_pred1c3 <= ~(3'd1 << wb2rf_rd_num3[1:0]);

        wb_predval0 <= wb2rf_pred_we0;
        wb_predval1 <= wb2rf_pred_we1;
        wb_predval2 <= wb2rf_pred_we2;
        wb_predval3 <= wb2rf_pred_we3;

	reg_scoreboard <= reg_scoreboard & old_reg_field & ~(last_reg_field & {32{exception}});
	pred_scoreboard <= pred_scoreboard & old_pred_field & ~(last_pred_field & {3{exception}});

        if(d2pc_progress) begin
	   reg_scoreboard <= ((reg_scoreboard & old_reg_field) | reg_field) & ~(last_reg_field & {32{exception}});
	   pred_scoreboard <= ((pred_scoreboard & old_pred_field) | pred_field) & ~(last_pred_field & {3{exception}});

	   last_reg_field <= reg_field;
	   last_pred_field <= pred_field;
        end
     end
  end
endmodule
