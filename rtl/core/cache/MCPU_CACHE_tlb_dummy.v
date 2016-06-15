/* MCPU_CACHE_tlb_dummy
 * Dummy TLB for use before real TLB is ready.
 *
 * This module implements a simple direct-mapping TLB.  It currently uses
 * the zero-cycle protocol, in which the data is returned on the same cycle
 * as the address is submitted.
 *
 * This protocol will likely have to change as we begin synthesizing: RAM
 * reads in zero cycles will result in pretty poor performance in synthesis.
 */

module MCPU_CACHE_tlb_dummy(/*AUTOARG*/
   // Outputs
   ft2itlb_pagefault, ft2itlb_physpage, ft2itlb_ready,
   // Inputs
   ft2itlb_valid, ft2itlb_virtpage
   );

	input ft2itlb_valid;
	input [19:0] ft2itlb_virtpage;
	
	output ft2itlb_pagefault;
	wire ft2itlb_pagefault = 0;
	
	output [19:0] ft2itlb_physpage;
	wire [19:0] ft2itlb_physpage = ft2itlb_virtpage;
	
	output ft2itlb_ready;
	wire ft2itlb_ready = ft2itlb_valid;

endmodule
