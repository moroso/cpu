/* MCPU_MEM_arb
 * Memory preloader
 * Moroso project SoC
 */

`timescale 1 ps / 1 ps

module MCPU_MEM_preload(/*AUTOARG*/
   // Outputs
   pre2arb_valid, pre2arb_opcode, pre2arb_addr, pre2arb_wdata,
   pre2arb_wbe, pre2core_done,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, pre2arb_stall, pre2arb_rvalid
   );

`include "MCPU_MEM_ltc.vh"

	parameter ROM_SIZE = 2048; /* bytes */
	parameter ROM_FILE = "bootrom.hex";
	
	/*** Portlist ***/
	
	/* LTC interface */
	input           clkrst_mem_clk;
	input           clkrst_mem_rst_n;
	
	input           pre2arb_stall;
	
	output          pre2arb_valid;
	output [2:0]    pre2arb_opcode;
	output [31:5]   pre2arb_addr;
	
	output [255:0]  pre2arb_wdata;
	output [31:0]   pre2arb_wbe;
	
	input           pre2arb_rvalid;

	/* Core interface */
	output          pre2core_done;
	
	/*** Stub ***/
	
	/* We write out atoms at a time, so we'll keep a RAM full of atoms. */
	reg [255:0] rom [(ROM_SIZE / 32):0];
	
	initial
        	$readmemh(ROM_FILE, rom);
	
	assign pre2arb_valid = 0;
	assign pre2core_done = 0;
endmodule
