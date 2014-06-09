/* MCPU_MEM_loc
 * Level 1 caches
 * Moroso project SOC
 */

module MCPU_MEM_inst_loc(/*AUTOARG*/);

	/*** Portlist ***/

	/* Clocks */
	input          clkrst_mem_clk;
	input          clkrst_mem_rst_n;

	/* Instruction cache / Core interface */
	input [31:0]   mem_inst_mar;
	input          mem_inst_wen; // Write enable
	input          mem_inst_req; // Memory access requested
	output [127:0] mem_inst_mdr;
	output         mem_inst_rdy; // Memory access done

	assign mem_inst_mdr = 0;
	assign mem_inst_rdy = 0;

endmodule


module MCPU_MEM_data_loc(/*AUTOARG*/);

	/*** Portlist ***/

	/* Clocks */
	input        clkrst_mem_clk;
	input        clkrst_mem_rst_n;

	/* Instruction cache / Core interface for port 0 */
	input [31:0] mem_data_mar_0;
	input        mem_data_wen_0; // Write enable
	input        mem_data_req_0; // Memory access requested
	inout [31:0] mem_data_mdr_0;
	output       mem_data_rdy_0; // Memory access done

	/* Instruction cache / Core interface for port 1 */
	input [31:0] mem_data_mar_1;
	input        mem_data_wen_1; // Write enable
	input        mem_data_req_1; // Memory access requested
	inout [31:0] mem_data_mdr_1;
	output       mem_data_rdy_1; // Memory access done

	assign mem_data_mdr_0 = 0;
	assign mem_data_rdy_0 = 0;

	assign mem_data_mdr_1 = 0;
	assign mem_data_rdy_1 = 0;

endmodule
