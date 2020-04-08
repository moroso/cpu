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
    output [2:0] sb2d_pred_scoreboard;

    input [4:0] wb2rf_rd_num0, wb2rf_rd_num1, wb2rf_rd_num2, wb2rf_rd_num3;
    input wb2rf_rd_we0, wb2rf_rd_we1, wb2rf_rd_we2, wb2rf_rd_we3;
    input wb2rf_pred_we0, wb2rf_pred_we1, wb2rf_pred_we2, wb2rf_pred_we3;

    input [4:0] d2pc_out_rd_num0, d2pc_out_rd_num1, d2pc_out_rd_num2, d2pc_out_rd_num3;
    input d2pc_out_rd_we0, d2pc_out_rd_we1, d2pc_out_rd_we2, d2pc_out_rd_we3;
    input d2pc_out_pred_we0, d2pc_out_pred_we1, d2pc_out_pred_we2, d2pc_out_pred_we3;

    input d2pc_progress;
    input exception;
    input pipe_flush;

    /*AUTOREG*/

    reg [31:0] dcd_reg1h0, dcd_reg1h1, dcd_reg1h2, dcd_reg1h3;
    reg dcd_regval0, dcd_regval1, dcd_regval2, dcd_regval3;
    reg [31:0] wb_reg1c0, wb_reg1c1, wb_reg1c2, wb_reg1c3;
    reg wb_regval0, wb_regval1, wb_regval2, wb_regval3;

    reg [2:0] dcd_pred1h0, dcd_pred1h1, dcd_pred1h2, dcd_pred1h3;
    reg dcd_predval0, dcd_predval1, dcd_predval2, dcd_predval3;
    reg [2:0] wb_pred1c0, wb_pred1c1, wb_pred1c2, wb_pred1c3;
    reg wb_predval0, wb_predval1, wb_predval2, wb_predval3;

    reg [31:0] prev_reg_scoreboard;
    reg [2:0] prev_pred_scoreboard;

    wire [31:0] new_reg_field, old_reg_field;
    wire [2:0] new_pred_field, old_pred_field;

    assign new_reg_field = (dcd_reg1h0 & {32{dcd_regval0}})
                        |  (dcd_reg1h1 & {32{dcd_regval1}})
                        |  (dcd_reg1h2 & {32{dcd_regval2}})
                        |  (dcd_reg1h3 & {32{dcd_regval3}});

    assign old_reg_field = (wb_reg1c0 | {32{~wb_regval0}})
                        &  (wb_reg1c1 | {32{~wb_regval1}})
                        &  (wb_reg1c2 | {32{~wb_regval2}})
                        &  (wb_reg1c3 | {32{~wb_regval3}});
    
    assign new_pred_field = (dcd_pred1h0 & {3{dcd_predval0}})
                          | (dcd_pred1h1 & {3{dcd_predval1}})
                          | (dcd_pred1h2 & {3{dcd_predval2}})
                          | (dcd_pred1h3 & {3{dcd_predval3}});

    assign old_pred_field = (wb_pred1c0 | {3{~wb_predval0}})
                          & (wb_pred1c1 | {3{~wb_predval1}})
                          & (wb_pred1c2 | {3{~wb_predval2}})
                          & (wb_pred1c3 | {3{~wb_predval3}});

    assign sb2d_reg_scoreboard = (prev_reg_scoreboard | new_reg_field) & old_reg_field;

    assign sb2d_pred_scoreboard = (prev_pred_scoreboard | new_pred_field) & old_pred_field;


    always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
        if(~clkrst_core_rst_n) begin
            dcd_reg1h0 <= 0;
            dcd_reg1h1 <= 0;
            dcd_reg1h2 <= 0;
            dcd_reg1h3 <= 0;
            dcd_regval0 <= 0;
            dcd_regval1 <= 0;
            dcd_regval2 <= 0;
            dcd_regval3 <= 0;
            wb_reg1c0 <= 0;
            wb_reg1c1 <= 0;
            wb_reg1c2 <= 0;
            wb_reg1c3 <= 0;
            wb_regval0 <= 0;
            wb_regval1 <= 0;
            wb_regval2 <= 0;
            wb_regval3 <= 0;
            dcd_pred1h0 <= 0;
            dcd_pred1h1 <= 0;
            dcd_pred1h2 <= 0;
            dcd_pred1h3 <= 0;
            dcd_predval0 <= 0;
            dcd_predval1 <= 0;
            dcd_predval2 <= 0;
            dcd_predval3 <= 0;
            wb_pred1c0 <= 0;
            wb_pred1c1 <= 0;
            wb_pred1c2 <= 0;
            wb_pred1c3 <= 0;
            wb_predval0 <= 0;
            wb_predval1 <= 0;
            wb_predval2 <= 0;
            wb_predval3 <= 0;
            prev_pred_scoreboard <= 0;
            prev_reg_scoreboard <= 0;
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
            
            prev_reg_scoreboard <= sb2d_reg_scoreboard & ~(new_reg_field & {32{exception}});
            prev_pred_scoreboard <= sb2d_pred_scoreboard & ~(new_pred_field & {3{exception}});

            if(d2pc_progress) begin
                dcd_reg1h0 <= 32'd1 << d2pc_out_rd_num0;
                dcd_reg1h1 <= 32'd1 << d2pc_out_rd_num1;
                dcd_reg1h2 <= 32'd1 << d2pc_out_rd_num2;
                dcd_reg1h3 <= 32'd1 << d2pc_out_rd_num3;
    
                dcd_regval0 <= d2pc_out_rd_we0 & ~pipe_flush;
                dcd_regval1 <= d2pc_out_rd_we1 & ~pipe_flush;
                dcd_regval2 <= d2pc_out_rd_we2 & ~pipe_flush;
                dcd_regval3 <= d2pc_out_rd_we3 & ~pipe_flush;
    
                
                dcd_pred1h0 <= 3'd1 << d2pc_out_rd_num0[1:0];
                dcd_pred1h1 <= 3'd1 << d2pc_out_rd_num1[1:0];
                dcd_pred1h2 <= 3'd1 << d2pc_out_rd_num2[1:0];
                dcd_pred1h3 <= 3'd1 << d2pc_out_rd_num3[1:0];
    
                dcd_predval0 <= d2pc_out_pred_we0 & ~pipe_flush;
                dcd_predval1 <= d2pc_out_pred_we1 & ~pipe_flush;
                dcd_predval2 <= d2pc_out_pred_we2 & ~pipe_flush;
                dcd_predval3 <= d2pc_out_pred_we3 & ~pipe_flush;
            end
            else begin
                {dcd_reg1h0, dcd_reg1h1, dcd_reg1h2, dcd_reg1h3} <= 128'd0;
                {dcd_regval0, dcd_regval1, dcd_regval2, dcd_regval3} <= 4'd0;
                {dcd_pred1h0, dcd_pred1h1, dcd_pred1h2, dcd_pred1h3} <= 12'd0;
                {dcd_predval0, dcd_predval1, dcd_predval2, dcd_predval3} <= 4'd0;
            end
        end
      end
endmodule
