/* MCPU_MEM_ltc
 * Level 2 cache
 * Moroso project SOC
 * 
 *** Summary
 *
 * The mcpu LTC further abstracts the LPDDR2 PHY's Avalon memory interface
 * into a 32-byte "atom" interface.  Wider atoms allow more data to be
 * transferred between caches with lower latency; on the other hand, wider
 * atoms also result in more substantial wiring congestion in the SoC.  32
 * bytes seemed as good a compromise as any.
 *
 * The LTC has a command-and-data interface that feeds into an internal
 * FIFO.  It buffers some internally, but enforces a strict ordering on its
 * external interface -- after a write has been issued, it is guaranteed to
 * be accessible to other clients immediately.  Data is returned from read
 * requests some time after they are issued; in the case of cache hits,
 * requests may be returned in just a few cycles, whereas requests that have
 * to go out to main memory can take quite a lot longer.
 *
 * LTC provides a set of six opcodes for users: normal read, normal write,
 * read-through (reads from cache or from main memory, but does not evict a
 * cache line in the latter case), write-through (writes to cache or to main
 * memory, but does not evict a cache line in the latter case), prefetch,
 * and clean.  LTC supports read-under-prefetch.
 *
 * LTC could be extended to support client IDs, allowing for
 * read-under-miss; in the current single-client design, this cannot be
 * achieved while still having responses guaranteed to be returned in the
 * same order as requests.
 *
 * (The following figures are tentative, and may change.)  LTC is a 64kB
 * cache; this means that it stores 2048 atoms.  Cache lines are four atoms
 * (128 bytes) wide; this means that LTC has 128 cache lines.  Cache lines
 * are 4-way set associative; this means that LTC has 32 sets.  So, the
 * system address mapping looks like this:
 *   addr[ 4: 0]: atom offset
 *   addr[ 6: 5]: cache line offset
 *   addr[11: 7]: set
 *   addr[31:12]: tag
 *
 * LTC is going to be an enormous pain to verify.  Let's just hope we get it
 * right the first time.
 *
 *** Implementation details
 *
 * All outputs are zero.  Lol!
 */

`timescale 1 ps / 1 ps


module MCPU_MEM_ltc(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_addr_0, ltc2mc_avl_be_0, ltc2mc_avl_burstbegin_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_size_0, ltc2mc_avl_wdata_0,
   ltc2mc_avl_write_req_0, arb2ltc_rdata, arb2ltc_rvalid,
   arb2ltc_stall,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, ltc2mc_avl_rdata_0,
   ltc2mc_avl_rdata_valid_0, ltc2mc_avl_ready_0, arb2ltc_valid,
   arb2ltc_opcode, arb2ltc_addr, arb2ltc_wdata, arb2ltc_wbe
   );

/* opcode parameters */
`include "MCPU_MEM_ltc.vh"

	/*** Portlist ***/
	
	/* Clocks */
	input           clkrst_mem_clk;
	input           clkrst_mem_rst_n;

	/* Avalon interface */
	output [24:0]	ltc2mc_avl_addr_0;
	output [15:0]	ltc2mc_avl_be_0;
	output		ltc2mc_avl_burstbegin_0;
	output		ltc2mc_avl_read_req_0;
	output [4:0]	ltc2mc_avl_size_0;
	output [127:0]	ltc2mc_avl_wdata_0;
	output		ltc2mc_avl_write_req_0;
	input [127:0]	ltc2mc_avl_rdata_0;
	input		ltc2mc_avl_rdata_valid_0;
	input		ltc2mc_avl_ready_0;
	
	/* Atom interface */
	/* XXX: Add LTC streams */
	input           arb2ltc_valid;
	input [2:0]     arb2ltc_opcode;
	input [26:0]	arb2ltc_addr;
	
	input [255:0]   arb2ltc_wdata;
	input [31:0]    arb2ltc_wbe;
	
	output [255:0]  arb2ltc_rdata;
	output          arb2ltc_rvalid;
	
	output          arb2ltc_stall;
	
	/*** Logic ***/
	
	/*AUTOREG*/
	// Beginning of automatic regs (for this module's undeclared outputs)
	reg [255:0]	arb2ltc_rdata;
	reg		arb2ltc_rvalid;
	reg		arb2ltc_stall;
	reg [24:0]	ltc2mc_avl_addr_0;
	reg [15:0]	ltc2mc_avl_be_0;
	reg		ltc2mc_avl_burstbegin_0;
	reg		ltc2mc_avl_read_req_0;
	reg [4:0]	ltc2mc_avl_size_0;
	reg [127:0]	ltc2mc_avl_wdata_0;
	reg		ltc2mc_avl_write_req_0;
	// End of automatics

	always @(*) begin
		ltc2mc_avl_addr_0 = 25'b0;
		ltc2mc_avl_be_0 = 16'b0;
		ltc2mc_avl_burstbegin_0 = 1'b0;
		ltc2mc_avl_read_req_0 = 1'b0;
		ltc2mc_avl_size_0 = 4'b0;
		ltc2mc_avl_wdata_0 = 128'b0;
		ltc2mc_avl_write_req_0 = 1'b0;
		
		arb2ltc_stall = 1'b1;
		arb2ltc_rdata = 256'b0;
		arb2ltc_rvalid = 1'b0;
	end

endmodule
