/* MCPU_CACHE_ic_dummy
 * Dummy instruction cache for use before real icache is ready.
 *
 * This module implements a simple ROM-driven Icache with data read from a
 * fixed boot-ROM hex file, like the preloader.  It currently uses the
 * zero-cycle protocol, in which the data is returned on the same cycle as
 * the address is submitted.
 *
 * This protocol will likely have to change as we begin synthesizing: RAM
 * reads in zero cycles will result in pretty poor performance in synthesis.
 */

module MCPU_CACHE_ic_dummy(/*AUTOARG*/
   // Outputs
   ic2f_ready, ic2f_packet,
   // Inputs
   f2ic_valid, f2ic_paddr
   );

`include "clog2.vh"
   
   	parameter ROM_SIZE = 2048; /* bytes */
   	parameter ROM_FILE = "bootrom.hex";
   
	input f2ic_valid;
	input [27:0] f2ic_paddr;
	
	output reg ic2f_ready;
	output reg [127:0] ic2f_packet;

	/* The hex file format is an atom at a time, so we load our RAM as
	 * atoms, and then mux out later. */
	parameter ROM_ATOMS = ROM_SIZE / 32;
	parameter ROMAD_BITS = clog2(ROM_ATOMS - 1);
	reg [255:0] rom [ROM_ATOMS - 1:0];
	initial
		$readmemh(ROM_FILE, rom);
	
	reg [255:0] rom_q;
	always @(*) begin
		ic2f_ready = 1'b0;
		ic2f_packet = {128{1'bx}};
		rom_q = {256{1'bx}};
		if (f2ic_valid) begin
			ic2f_ready = 1'b1;
			rom_q = rom[f2ic_paddr[ROMAD_BITS:1]];
			/* Little endian, so bit 0 being clear means that we access the LSBs. */
			ic2f_packet = f2ic_paddr[0] ? rom_q[255:128] : rom_q[127:0];
		end
	end
endmodule
