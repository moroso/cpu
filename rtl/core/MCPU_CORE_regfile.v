/* regfile.v
 * 8-read, 4-write register file for the Moroso Project CPU
 */

module MCPU_CORE_regfile(/*AUTOARG*/
   // Outputs
   rf2d_rs_data0, rf2d_rs_data1, rf2d_rs_data2, rf2d_rs_data3,
   rf2d_rt_data0, rf2d_rt_data1, rf2d_rt_data2, rf2d_rt_data3, preds,
   r0,
   // Inputs
   wb2rf_rd_num0, wb2rf_rd_num1, wb2rf_rd_num2, wb2rf_rd_num3,
   d2rf_rs_num0, d2rf_rs_num1, d2rf_rs_num2, d2rf_rs_num3,
   d2rf_rt_num0, d2rf_rt_num1, d2rf_rt_num2, d2rf_rt_num3,
   wb2rf_rd_data0, wb2rf_rd_data1, wb2rf_rd_data2, wb2rf_rd_data3,
   wb2rf_rd_we3, wb2rf_rd_we2, wb2rf_rd_we1, wb2rf_rd_we0,
   wb2rf_pred_we3, wb2rf_pred_we2, wb2rf_pred_we1, wb2rf_pred_we0,
   clkrst_core_clk, clkrst_core_rst_n
   );

    input [4:0] wb2rf_rd_num0, wb2rf_rd_num1, wb2rf_rd_num2, wb2rf_rd_num3;
    input [4:0] d2rf_rs_num0, d2rf_rs_num1, d2rf_rs_num2, d2rf_rs_num3;
    input [4:0] d2rf_rt_num0, d2rf_rt_num1, d2rf_rt_num2, d2rf_rt_num3;
    input [31:0] wb2rf_rd_data0, wb2rf_rd_data1, wb2rf_rd_data2, wb2rf_rd_data3;
    input wb2rf_rd_we3, wb2rf_rd_we2, wb2rf_rd_we1, wb2rf_rd_we0;
    input wb2rf_pred_we3, wb2rf_pred_we2, wb2rf_pred_we1, wb2rf_pred_we0;
    input clkrst_core_clk, clkrst_core_rst_n;

    output wire [31:0] rf2d_rs_data0, rf2d_rs_data1, rf2d_rs_data2, rf2d_rs_data3;
    output wire [31:0] rf2d_rt_data0, rf2d_rt_data1, rf2d_rt_data2, rf2d_rt_data3;
    output reg [2:0] preds /* verilator public */;
	 output [31:0] r0;

    reg [31:0] mem[0:31] /* verilator public */;
    integer i;

  assign r0 = mem[0];
  wire [31:0] r1 = mem[1];
  wire [31:0] r2 = mem[2];
  wire [31:0] r3 = mem[3];
  wire [31:0] r30 = mem[30];
  wire [31:0] r31 = mem[31];
	 
    always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
        if(~clkrst_core_rst_n) begin
            for(i = 0; i < 32; i = i + 1) begin
                mem[i] <= 32'b0;
            end
            preds <= 3'b0;
        end else begin
            // These are done in reverse order; if two lanes write to the same
            // register then the lower-numbered one wins.
            if(wb2rf_rd_we3) mem[wb2rf_rd_num3] <= wb2rf_rd_data3;
            if(wb2rf_rd_we2) mem[wb2rf_rd_num2] <= wb2rf_rd_data2;
            if(wb2rf_rd_we1) mem[wb2rf_rd_num1] <= wb2rf_rd_data1;
            if(wb2rf_rd_we0) mem[wb2rf_rd_num0] <= wb2rf_rd_data0;
            if(wb2rf_pred_we3) preds[wb2rf_rd_num3[1:0]] <= wb2rf_rd_data3[0];
            if(wb2rf_pred_we2) preds[wb2rf_rd_num2[1:0]] <= wb2rf_rd_data2[0];
            if(wb2rf_pred_we1) preds[wb2rf_rd_num1[1:0]] <= wb2rf_rd_data1[0];
            if(wb2rf_pred_we0) preds[wb2rf_rd_num0[1:0]] <= wb2rf_rd_data0[0];
        end
    end
	 
    assign rf2d_rs_data0 = mem[d2rf_rs_num0];
    assign rf2d_rs_data1 = mem[d2rf_rs_num1];
    assign rf2d_rs_data2 = mem[d2rf_rs_num2];
    assign rf2d_rs_data3 = mem[d2rf_rs_num3];

    assign rf2d_rt_data0 = mem[d2rf_rt_num0];
    assign rf2d_rt_data1 = mem[d2rf_rt_num1];
    assign rf2d_rt_data2 = mem[d2rf_rt_num2];
    assign rf2d_rt_data3 = mem[d2rf_rt_num3];

endmodule
