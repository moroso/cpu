/* MCPU_MEM_arb
 * Memory arbiter
 * Moroso project SoC
 */

`timescale 1 ps / 1 ps

module MCPU_MEM_arb(/*AUTOARG*/
   // Outputs
   arb2ltc_valid, arb2ltc_opcode, arb2ltc_addr, arb2ltc_wdata,
   arb2ltc_wbe, cli2arb_stall, cli2arb_rdata, cli2arb_rvalid,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, arb2ltc_stall, arb2ltc_rdata,
   arb2ltc_rvalid, cli2arb_valid, cli2arb_opcode, cli2arb_addr,
   cli2arb_wdata, cli2arb_wbe
   );

`include "MCPU_MEM_ltc.vh"

	parameter CLIENTS = 2;
	parameter CLIENTS_BITS = 1;
	
	parameter CREDITS_DEFAULT = 1;
	parameter CREDITS_BITS = 3;
	
	/*** Portlist ***/
	
	/* LTC interface */
	input               clkrst_mem_clk;
	input               clkrst_mem_rst_n;
	
	input               arb2ltc_stall;
	
	output reg          arb2ltc_valid;
	output reg [2:0]    arb2ltc_opcode;
	output reg [31:5]   arb2ltc_addr;
	
	output reg [255:0]  arb2ltc_wdata;
	output reg [31:0]   arb2ltc_wbe;
	
	input  [255:0]      arb2ltc_rdata;
	input               arb2ltc_rvalid;
	
	/* Client interface */
	output [CLIENTS-1:0]     cli2arb_stall; 
	input  [CLIENTS-1:0]     cli2arb_valid;
	input  [CLIENTS*3-1:0]   cli2arb_opcode;
	input  [CLIENTS*27-1:0]  cli2arb_addr;
	input  [CLIENTS*256-1:0] cli2arb_wdata;
	input  [CLIENTS*32-1:0]  cli2arb_wbe;
	
	output [255:0]           cli2arb_rdata;
	output [CLIENTS-1:0]     cli2arb_rvalid;
	
	/* CSR interface */
	/* xxx */
	
	/*** Logic ***/
	
	genvar cli;
	genvar ii;
	integer i;
	
	/** Flops and wires **/
	
	reg [CLIENTS-1:0] cur_client = 0;
	reg [CLIENTS_BITS-1:0] cur_client_num = 0;
	reg [CLIENTS_BITS:0] cur_client_num_next;
	reg [CREDITS_BITS-1:0] credits_left;
	reg [CREDITS_BITS-1:0] cli_credits [CLIENTS-1:0];
	
	wire [CLIENTS-1:0] cli_ready_rotated;
	
	wire         sel_valid;
	wire   [2:0] sel_opcode;
	wire  [31:5] sel_addr;
	wire [255:0] sel_wdata;
	wire  [31:0] sel_wbe;
	
	wire sel_has_rdata = sel_opcode == LTC_OPC_READ || sel_opcode == LTC_OPC_READTHROUGH;
	
	wire rdfifo_push;
	wire [CLIENTS_BITS-1:0] rdfifo_wdata;
	wire rdfifo_full;
	wire rdfifo_pop;
	wire [CLIENTS_BITS-1:0] rdfifo_rdata;
	wire rdfifo_empty;
	
	wire rdfifo_wait;
	
	reg arb2ltc_rvalid_1a;
	reg [255:0] arb2ltc_rdata_1a;

	/** Client selection logic **/

	/* Contains a priority encoder for incrementing to the next ready
	 * client, and ready-generation logic for the clients (decrementing
	 * credits as selected, and inserting a bubble when needed).  */
	
	generate for (ii = 0; ii < CLIENTS; ii = ii + 1) begin: resets
		always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
			if (~clkrst_mem_rst_n) begin
				cli_credits[ii] <= CREDITS_DEFAULT;
			end else begin
				/* XXX CSR interface */
			end
	end endgenerate
	
	assign cli_ready_rotated = (cli2arb_valid >> cur_client_num) | (cli2arb_valid << (CLIENTS - cur_client_num));
	
	/* cur_client_num_next's high bit is always 0, but internally, it
	 * takes another bit for a moment before we assign it.  */
	always @(*) begin
		cur_client_num_next = {1'b0, cur_client_num};
		for (i = CLIENTS - 1; i > 0; i = i - 1)
			if (cli_ready_rotated[i])
				cur_client_num_next = i[CLIENTS_BITS:0] + {1'b0,cur_client_num};
		if (cur_client_num_next >= CLIENTS)
			cur_client_num_next = cur_client_num_next - CLIENTS[CLIENTS_BITS:0];
	end
	
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			cur_client_num <= 0;
			cur_client <= {{(CLIENTS-1){1'b0}}, 1'b1};
			credits_left <= CREDITS_DEFAULT;
		end else begin
			if (~arb2ltc_stall) begin /* 1) Can't change out from under LTC.  2) Count requests, not clocks. */
				if ((credits_left == 0) || !sel_valid) begin
					credits_left <= cli_credits[cur_client_num_next[CLIENTS_BITS-1:0]];
					cur_client_num <= cur_client_num_next[CLIENTS_BITS-1:0];
					cur_client <= {{(CLIENTS-1){1'b0}}, 1'b1} << cur_client_num_next;
				end else
					credits_left <= credits_left - 1;
			end
		end
	
	/** Client rdata FIFO **/
	
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			arb2ltc_rvalid_1a <= 0;
			arb2ltc_rdata_1a <= {256{1'b0}};
		end else begin
			arb2ltc_rvalid_1a <= arb2ltc_rvalid;
			arb2ltc_rdata_1a <= arb2ltc_rdata;
		end
	
	/* FIFO of all read pushes that are waiting for responses from LTC. 
	 * Relatively small, since LTC's pipeline is relatively small...  */
	
	FIFO #(.DEPTH(4), .WIDTH(CLIENTS_BITS)) rdfifo(
		.clk(clkrst_mem_clk),
		.rst_n(clkrst_mem_rst_n),
		.push(rdfifo_push),
		.wdata(rdfifo_wdata),
		.full(rdfifo_full),
		.pop(rdfifo_pop),
		.rdata(rdfifo_rdata),
		.empty(rdfifo_empty));
	
	assign rdfifo_push  = sel_valid && sel_has_rdata && ~rdfifo_full && ~arb2ltc_stall;
	assign rdfifo_wdata = cur_client_num;
	
	assign rdfifo_pop   = arb2ltc_rvalid;

`ifndef BROKEN_ASSERTS
	always @(posedge clkrst_mem_clk)
		assert (!(rdfifo_pop && rdfifo_empty)) else $error("LTC returned more results than we have entries in FIFO");
`endif
	
	assign rdfifo_wait  = sel_valid && sel_has_rdata && rdfifo_full;
	
	/* And route rdata back to clients. */
	generate
		for (cli = 0; cli < CLIENTS; cli = cli + 1) begin: rvalids assign cli2arb_rvalid[cli] = (rdfifo_rdata == cli[CLIENTS_BITS-1:0]) && arb2ltc_rvalid_1a; end
	endgenerate
	assign cli2arb_rdata = arb2ltc_rdata_1a;
	
	/** Master logic for routing selected client out to ltc **/
	
	/* Since bit selects cannot be variable, this actually needs to live
	 * in a generate block.  */
	generate
		assign sel_valid = cli2arb_valid[cur_client_num];
		for (ii = 0; ii < 3; ii = ii + 1) begin: opcodes assign sel_opcode[ii] = cli2arb_opcode[cur_client_num * 3 + ii]; end
		for (ii = 0; ii < 27; ii = ii + 1) begin: addrs assign sel_addr[ii + 5] = cli2arb_addr[cur_client_num * 27 + ii]; end
		for (ii = 0; ii < 256; ii = ii + 1) begin: wdatas assign sel_wdata[ii] = cli2arb_wdata[cur_client_num * 256 + ii]; end
		for (ii = 0; ii < 32; ii = ii + 1) begin: wbes assign sel_wbe[ii] = cli2arb_wbe[cur_client_num * 32 + ii]; end
	endgenerate
	
	/* Now route stalls back to the selected client. */
	generate
		for (cli = 0; cli < CLIENTS; cli = cli + 1) begin: stalls assign cli2arb_stall[cli] = ((cur_client_num != cli[CLIENTS_BITS-1:0]) || arb2ltc_stall || rdfifo_wait) && cli2arb_valid[cli]; end
	endgenerate
	
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
		if (~clkrst_mem_rst_n) begin
			arb2ltc_valid <= 0;
			arb2ltc_opcode <= 3'b0;
			arb2ltc_addr <= 27'b0;
			arb2ltc_wdata <= 256'b0;
			arb2ltc_wbe <= 32'b0;
		end else begin
			if (~arb2ltc_stall) begin
				arb2ltc_valid <= sel_valid && ~rdfifo_wait;
				arb2ltc_opcode <= sel_opcode;
				arb2ltc_addr <= sel_addr;
				arb2ltc_wdata <= sel_wdata;
				arb2ltc_wbe <= sel_wbe;
			end
		end
	end
endmodule
