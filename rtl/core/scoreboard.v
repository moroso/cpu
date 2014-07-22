module scoreboard(/*AUTOARG*/
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
   d2pc_out_pred_we3
   );

    input clkrst_core_clk, clkrst_core_rst_n;

    output [31:0] sb2d_reg_scoreboard;
    output [2:0] sb2d_pred_scoreboard;

    input [4:0] wb2rf_rd_num0, wb2rf_rd_num1, wb2rf_rd_num2, wb2rf_rd_num3;
    input wb2rf_rd_we0, wb2rf_rd_we1, wb2rf_rd_we2, wb2rf_rd_we3;
    input wb2rf_pred_we0, wb2rf_pred_we1, wb2rf_pred_we2, wb2rf_pred_we3;

    input [4:0] d2pc_out_rd_num0, d2pc_out_rd_num1, d2pc_out_rd_num2, d2pc_out_rd_num3;
    input d2pc_out_rd_we0, d2pc_out_rd_we1, d2pc_out_rd_we2, d2pc_out_rd_we3;
    input d2pc_out_pred_we0, d2pc_out_pred_we1, d2pc_out_pred_we2, d2pc_out_pred_we3;

    /*AUTOREG*/
    // Beginning of automatic regs (for this module's undeclared outputs)
    reg [2:0]		sb2d_pred_scoreboard;
    reg [31:0]		sb2d_reg_scoreboard;
    // End of automatics


    always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
        if(~clkrst_core_rst_n) begin
            sb2d_reg_scoreboard <= 32'd0;
            sb2d_pred_scoreboard <= 3'd0;
        end
        else begin
            sb2d_pred_scoreboard <= (sb2d_pred_scoreboard
                                    | ({2'd0, d2pc_out_pred_we0} << d2pc_out_rd_num0)
                                    | ({2'd0, d2pc_out_pred_we1} << d2pc_out_rd_num1)
                                    | ({2'd0, d2pc_out_pred_we2} << d2pc_out_rd_num2)
                                    | ({2'd0, d2pc_out_pred_we3} << d2pc_out_rd_num3))
                                    & ~({2'd0, wb2rf_pred_we0} << wb2rf_rd_num0)
                                    & ~({2'd0, wb2rf_pred_we1} << wb2rf_rd_num1)
                                    & ~({2'd0, wb2rf_pred_we2} << wb2rf_rd_num2)
                                    & ~({2'd0, wb2rf_pred_we3} << wb2rf_rd_num3);

            sb2d_reg_scoreboard <= (sb2d_reg_scoreboard | ({31'd0, d2pc_out_rd_we0} << d2pc_out_rd_num0)
                                                        | ({31'd0, d2pc_out_rd_we1} << d2pc_out_rd_num1)
                                                        | ({31'd0, d2pc_out_rd_we2} << d2pc_out_rd_num2)
                                                        | ({31'd0, d2pc_out_rd_we3} << d2pc_out_rd_num3))
                                                        & ~({31'd0, wb2rf_rd_we0} << wb2rf_rd_num0)
                                                        & ~({31'd0, wb2rf_rd_we1} << wb2rf_rd_num1)
                                                        & ~({31'd0, wb2rf_rd_we2} << wb2rf_rd_num2)
                                                        & ~({31'd0, wb2rf_rd_we3} << wb2rf_rd_num3);
        end
      end
endmodule