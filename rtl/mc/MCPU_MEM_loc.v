/* MCPU_MEM_loc
 * Level 1 caches
 * Moroso project SOC
 *
 * Instruction cache:
 *
 * vaddr[ 9: 5]: set
 * vaddr[ 4: 0]: cache line offset
 * paddr[28:10]: tag
 *
 *
 * Data cache:
 *
 * vaddr[ 9: 5]: set
 * vaddr[ 4: 0]: cache line offset
 * paddr[28:10]: tag
 */

module MCPU_MEM_inst_loc(/*AUTOARG*/);

	/* Opcode parameters */

	parameter WAYS = 4;
	parameter WAYS_BITS = 2;

	parameter TAG_UPPER = 29;
	parameter TAG_LOWER = 10;
	parameter TAG_BITS = (TAG_UPPER - TAG_LOWER + 1);

	parameter SETS = 32;
	parameter SET_UPPER = 9;
	parameter SET_LOWER = 5;
	parameter SET_BITS = (SET_UPPER - SET_LOWER + 1);

	parameter BYTE_UPPER = 4;
	parameter BYTE_LOWER = 0;
	parameter BYTE_BITS = (BYTE_UPPER - BYTE_LOWER + 1);

	/*** Portlist ***/

	/* Clocks */
	input          clkrst_mem_clk;
	input          clkrst_mem_rst_n;

	/* Instruction cache / Core interface */
	input [16:0]   mem_inst_ppg; // Physical page (29 - 12 = 17)
	input [19:0]   mem_inst_vpg; // Virtual page (32 - 12 = 20)
	input [11:0]   mem_inst_ppo; // Page offset
	input          mem_inst_req; // Memory access requested
	output [127:0] mem_inst_mdr; // Fetched instruction
	output         mem_inst_rdy; // Memory access done

	assign mem_inst_mdr = 0;
	assign mem_inst_rdy = 0;

endmodule


module MCPU_MEM_data_loc(/*AUTOARG*/);

	/* Opcode parameters */

	parameter WAYS = 4;
	parameter WAYS_BITS = 2;

	parameter TAG_UPPER = 29;
	parameter TAG_LOWER = 10;
	parameter TAG_BITS = (TAG_UPPER - TAG_LOWER + 1);

	parameter SETS = 32;
	parameter SET_UPPER = 9;
	parameter SET_LOWER = 5;
	parameter SET_BITS = (SET_UPPER - SET_LOWER + 1);

	parameter BYTE_UPPER = 4;
	parameter BYTE_LOWER = 0;
	parameter BYTE_BITS = (BYTE_UPPER - BYTE_LOWER + 1);

	/*** Portlist ***/

	/* Clocks */
	input        clkrst_mem_clk;
	input        clkrst_mem_rst_n;

	/* Instruction cache / Core interface for port 0 */
	input [16:0] mem_inst_ppg_0; // Physical page
	input [19:0] mem_inst_vpg_0; // Virtual page
	input [11:0] mem_inst_ppo_0; // Page offset
	input        mem_data_wen_0; // Write enable
	input        mem_data_req_0; // Memory access requested
	inout [31:0] mem_data_mdr_0; // Fetched or stored data
	output       mem_data_rdy_0; // Memory access done

	/* Instruction cache / Core interface for port 1 */
	input [16:0] mem_inst_ppg_1; // Physical page
	input [19:0] mem_inst_vpg_1; // Virtual page
	input [11:0] mem_inst_ppo_1; // Page offset
	input        mem_data_wen_1; // Write enable
	input        mem_data_req_1; // Memory access requested
	inout [31:0] mem_data_mdr_1; // Fetched or stored data
	output       mem_data_rdy_1; // Memory access done

	assign mem_data_mdr_0 = 0;
	assign mem_data_rdy_0 = 0;

	assign mem_data_mdr_1 = 0;
	assign mem_data_rdy_1 = 0;

endmodule
