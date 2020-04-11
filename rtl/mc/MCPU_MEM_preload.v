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
`include "clog2.vh"

	parameter ROM_SIZE = 2048; /* bytes */
	parameter ROM_FILE = "bootrom.hex";
	
	/*** Portlist ***/
	
	/* LTC interface */
	input               clkrst_mem_clk;
	input               clkrst_mem_rst_n;
	
	input               pre2arb_stall;
	
	output reg          pre2arb_valid;
	output reg [2:0]    pre2arb_opcode;
	output reg [31:5]   pre2arb_addr;
	
	output reg [255:0]  pre2arb_wdata;
	output reg [31:0]   pre2arb_wbe;
	
	input               pre2arb_rvalid;

	/* Core interface */
	output              pre2core_done;
	
	/*** Stub ***/
	
	/* We write out atoms at a time, so we'll keep a RAM full of atoms. */
	parameter ROM_ATOMS = ROM_SIZE / 32;
        reg [255:0] rom [ROM_ATOMS - 1:0] /* verilator public */;
	initial
        	$readmemh(ROM_FILE, rom);
	
	reg [clog2(ROM_ATOMS - 1) - 1 : 0] romad;
	reg loading;
	
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
		if (!clkrst_mem_rst_n) begin
			loading <= 1;
			romad <= 0;
			pre2arb_valid <= 0;
			pre2arb_opcode <= LTC_OPC_WRITETHROUGH;
			pre2arb_addr <= 0;
			pre2arb_wdata <= 0;
			pre2arb_wbe <= {32{1'b1}};
		end else begin
			if (~pre2arb_stall) begin
				if (~loading) begin
					pre2arb_valid <= 0;
				end else begin
					pre2arb_valid <= 1;
					pre2arb_opcode <= LTC_OPC_WRITETHROUGH;
					pre2arb_wdata <= rom[romad];
					pre2arb_wbe <= {32{1'b1}};
					/* verilator lint_off WIDTH */
					pre2arb_addr <= romad;
					romad <= romad + 1;
					if (romad == (ROM_ATOMS - 1))
						loading <= 0;
					/* verilator lint_on WIDTH */
				end
			end
		end
	end
	
	assign pre2core_done = ~loading && ~pre2arb_stall;
endmodule
