/* MCPU_CORE_CACHE_itlb
 * Instruction interface TLB
 * Moroso project SoC
 *
 * The ITLB is a simple CAM with 8 entries.  It uses the common page table
 * walk mechanism, which encapsulates most of the terrible in one place, at
 * least.  It responds in zero cycles, which is probably a bad idea, but
 * we'll see soon just how bad that is.
 *
 * Two architectures are proposed:
 *
 *  OPTION 1 (less wiring congestion, potentially longer critical path)
 *
 *    Data flows from the fetch unit, as a virtual address, [19:0].
 *    A parallel tag lookup, in which 8 comparators all do an equality
 *      test on their tags, and assert a (nominally) one-hot bus [7:0].
 *        (stall is derived from this one-hot bus)
 *    A priority encoder takes the one-hot bitfield and converts to binary.
 *    A RAM lookup decodes the binary bitfield and produces a physical page
 *      and flag set.
 *    Page fault and physical page is derived from the RAM output.
 *
 *  OPTION 2 (more wiring congestion, potentially shorter critical path)
 *
 *    Data flows from the fetch unit, as a virtual address, [19:0].
 *    A parallel tag lookup and data lookup takes place.  8 comparators all
 *      do an equality test on their tags, and assert both a validity bus
 *      (one bit each), and also a page-and-flag-set output if they are
 *      valid.
 *    The page-and-flag bus is OR'ed together.
 *    Page fault and physical page is derived from the page-and-flag bus.
 *
 * For lulz, we implement option 2.
 *
 * Replacement strategy is random (entry to replace increments once per
 * cycle).
 */

module MCPU_CORE_CACHE_itlb(/*AUTOARG*/
   // Outputs
   ft2itlb_stall_0a, itlb2ft_pagefault_0a, itlb2ft_physpage_0a,
   itlb2arb_valid, itlb2arb_opcode, itlb2arb_addr, itlb2arb_wdata,
   itlb2arb_wbe,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, ft2itlb_valid_0a,
   ft2itlb_kmode_0a, ft2itlb_virtpage_0a, clkrst_mem_clk,
   clkrst_mem_rst_n, itlb2arb_stall, itlb2arb_rvalid, itlb2arb_rdata
   );

`include "MCPU_MEM_ltc.vh"
`include "clog2.vh"

	parameter ITLB_SIZE = 8;

	/*** Portlist ***/
	
	/* Core interface */
	input               clkrst_core_clk;
	input               clkrst_core_rst_n;
	
	input               ft2itlb_valid_0a;
	input               ft2itlb_kmode_0a;
	input        [19:0] ft2itlb_virtpage_0a;
	output wire         ft2itlb_stall_0a;

	output wire         itlb2ft_pagefault_0a = 0;
	output wire  [19:0] itlb2ft_physpage_0a = 0;
	
	/* LTC interface */
	input               clkrst_mem_clk;
	input               clkrst_mem_rst_n;
	
	input               itlb2arb_stall;
	output reg          itlb2arb_valid;
	output reg    [2:0] itlb2arb_opcode;
	output reg    [2:0] itlb2arb_addr;
	
	output wire [255:0] itlb2arb_wdata = {256{1'bx}};
	output wire  [31:0] itlb2arb_wbe   = {32{1'bx}};
	
	input               itlb2arb_rvalid;
	input       [255:0] itlb2arb_rdata;
	
	/*** Wires ***/
	wire        tlbfetch2tlb_stall_0a = 0;
	wire        tlb2tlbfetch_request_0a = 0;
	wire [19:0] tlb2tlbfetch_reqaddr_0a;
	wire [31:0] tlbfetch2tlb_response_0a; /* phys [31:12], g, k, w, p */
	
	/*** TLB implementation ***/
	
	parameter CAM_TAG_SIZE = 20;
	parameter CAM_DATA_SIZE = 1 /* global bit */ + 1 /* kmode bit */ + 20;
	parameter CAM_DATA_GLOBAL = 21;
	parameter CAM_DATA_KMODE = 20;
	
	reg  [CAM_TAG_SIZE-1:0]  cam_tags  [ITLB_SIZE-1:0];
	reg  [ITLB_SIZE-1:0]     cam_valid;
	reg  [CAM_DATA_SIZE-1:0] cam_data  [ITLB_SIZE-1:0];
	
	/* Disturbingly, we invert the cam_lookup dimensions, so that we can
	 * or them together with unary-|.  Eef. */
	wire [ITLB_SIZE-1:0]     cam_lookup[CAM_DATA_SIZE-1:0];
	
	wire [ITLB_SIZE-1:0]     cam_match;
	
	wire [CAM_TAG_SIZE-1:0]  cam_input = ft2itlb_virtpage_0a;
	wire [CAM_DATA_SIZE-1:0] cam_output;
	wire                     cam_nomatch;
	
	genvar ii, jj;
	generate for (ii = 0; ii < ITLB_SIZE; ii = ii + 1) begin: cam_entries
		assign cam_match[ii] = cam_valid[ii] && (cam_tags[ii] == cam_input);
		for (jj = 0; jj < CAM_DATA_SIZE; jj = jj + 1) begin: cam_lookup_gen
			assign cam_lookup[jj][ii] = cam_match[ii] & cam_data[ii][jj];
		end
	end endgenerate
	
	generate for (jj = 0; jj < CAM_DATA_SIZE; jj = jj + 1) begin: cam_lookup_or
		assign cam_output[jj] = |cam_lookup[jj];
	end endgenerate

	assign cam_nomatch = ~|cam_match;
	
	/*** System control bits. ***/
	
	assign tlb2tlbfetch_request_0a = ft2itlb_valid_0a & cam_nomatch;
	assign tlb2tlbfetch_reqaddr_0a = ft2itlb_virtpage_0a;
	wire [CAM_DATA_SIZE-1:0] reformatted_response_0a = {tlbfetch2tlb_response_0a[3/*G*/], tlbfetch2tlb_response_0a[2/*K*/], tlbfetch2tlb_response_0a[31:12]};
	
	/* if we just fetched, use that instead */
	wire [CAM_DATA_SIZE-1:0] use_output = tlb2tlbfetch_request_0a ? reformatted_response_0a : cam_output;
	
	assign itlb2ft_pagefault_0a =
	  (tlb2tlbfetch_request_0a & ~tlbfetch2tlb_response_0a[0/*present*/]) | /* we just fetched, but it ain't there */
	  (use_output[CAM_DATA_KMODE] & ~ft2itlb_kmode_0a) /* Kmode request, but not in Kmode */;
	assign itlb2ft_physpage_0a = use_output[19:0];
	
	assign ft2itlb_stall_0a = tlbfetch2tlb_stall_0a;
	
	/*** TLB fetcher. ***/
	assign      tlbfetch2tlb_stall_0a = tlb2tlbfetch_request_0a;
	assign      tlbfetch2tlb_response_0a = 32'hx; /* "same to you, buddy" */
	
	/*** You know, just have something there to start with. ***/
	integer i;
	initial begin
		for (i = 0; i < ITLB_SIZE; i = i + 1) begin
			cam_tags[i] = i[19:0];
			cam_valid[i] = 1'b1;
			cam_data[i] = i[21:0];
		end
	end
	
endmodule

