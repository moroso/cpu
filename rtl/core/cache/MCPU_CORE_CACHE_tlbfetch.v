/* MCPU_CORE_CACHE_itlb
 * Common TLB cache fetcher
 * Moroso project SoC
 *
 * We use a simple flag synchronizer to move requests from the core clock
 * domain and back.  The way it is implemented adds a shitload of latency
 * (like, one cclk cycle of it plus three mclk cycles of it out, and the
 * converse back); sucks to be us.  Beyond that, we implement internally as
 * a state machine.
 *
 * The flag synchronizer works by toggling back and forth for each request
 * down the pipeline, in essence implementing a very simple size-one FIFO. 
 * It generates a width-1 pulse on the mclk side, and on the cclk side,
 * holds state.  The state machine is expected to generate a width-1 pulse
 * internally.
 *
 * Naming: signals that do not have a suffix (cclk or mclk) and are not
 * external signals are assumed to be on mclk.
 */

module MCPU_CORE_CACHE_tlbfetch(/*AUTOARG*/
   // Outputs
   tlbfetch2tlb_stall_0a, tlbfetch2tlb_response_0a, xtlb2arb_valid,
   xtlb2arb_opcode, xtlb2arb_addr, xtlb2arb_wdata, xtlb2arb_wbe,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, core2tlb_ptbr,
   tlb2tlbfetch_request_0a, tlb2tlbfetch_reqaddr_0a, clkrst_mem_clk,
   clkrst_mem_rst_n, xtlb2arb_stall, xtlb2arb_rvalid, xtlb2arb_rdata
   );
`include "MCPU_MEM_ltc.vh"
`include "clog2.vh"

	input               clkrst_core_clk;
	input               clkrst_core_rst_n;
	
	input        [19:0] core2tlb_ptbr;
	
	output wire         tlbfetch2tlb_stall_0a;
	input               tlb2tlbfetch_request_0a;
	input        [19:0] tlb2tlbfetch_reqaddr_0a;
	output wire  [31:0] tlbfetch2tlb_response_0a; /* phys [31:12], g, k, w, p */

	input               clkrst_mem_clk;
	input               clkrst_mem_rst_n;

	input               xtlb2arb_stall;
	output reg          xtlb2arb_valid = 1'b0;
	output reg    [2:0] xtlb2arb_opcode = {3{1'bx}};
	output reg   [31:5] xtlb2arb_addr = {27{1'bx}};
	
	output wire [255:0] xtlb2arb_wdata = {256{1'bx}};
	output wire  [31:0] xtlb2arb_wbe   = {32{1'bx}};
	
	input               xtlb2arb_rvalid;
	input       [255:0] xtlb2arb_rdata;
	
	/*** Wires. ***/
	wire        request_cclk;

	wire [31:0] response;
	wire        response_ready;
	
	/*** Cross-clock-domain synchronization: cclk to mclk, and flag generation ***/
	reg        request_cclk_1a = 1'b0; /* i.e., the request flag, synchronous with other _1a bits */
	reg        request_prev_cclk_0a = 1'b0; /* i.e., request flag of the previously submitted request */
	wire       request_cclk_0a = tlb2tlbfetch_request_0a ? ~request_prev_cclk_0a : request_prev_cclk_0a;
	reg [19:0] tlb2tlbfetch_reqaddr_cclk_1a = {20{1'b0}};
	reg [19:0] core2tlb_ptbr_1a = {20{1'b0}};
	always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
		if (~clkrst_core_rst_n) begin
			request_cclk_1a <= 1'b0;
			tlb2tlbfetch_reqaddr_cclk_1a <= {20{1'b0}};
			core2tlb_ptbr_1a <= {20{1'b0}};
		end else begin
			request_cclk_1a <= request_cclk_0a;
			if (~tlbfetch2tlb_stall_0a)
				request_prev_cclk_0a <= request_cclk_0a;
		 	tlb2tlbfetch_reqaddr_cclk_1a <= tlb2tlbfetch_reqaddr_0a;
		 	core2tlb_ptbr_1a <= core2tlb_ptbr;
		end
	end
	reg         request_cclk_mclk_s, request_cclk_mclk_ss, request_cclk_mclk_ss_1a;
	reg [19:0]  tlb2tlbfetch_reqaddr_cclk_mclk_s, tlb2tlbfetch_reqaddr_cclk_mclk_ss;
	reg [19:0]  core2tlb_ptbr_cclk_mclk_s, core2tlb_ptbr_cclk_mclk_ss;
	wire [19:0] ptbr = core2tlb_ptbr_cclk_mclk_ss;
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
		if (~clkrst_mem_rst_n) begin
			request_cclk_mclk_s <= 1'b0;
			request_cclk_mclk_ss <= 1'b0;
			request_cclk_mclk_ss_1a <= 1'b0;
			tlb2tlbfetch_reqaddr_cclk_mclk_s <= {20{1'b0}};
			tlb2tlbfetch_reqaddr_cclk_mclk_ss <= {20{1'b0}};
			core2tlb_ptbr_cclk_mclk_s <= {20{1'b0}};
			core2tlb_ptbr_cclk_mclk_ss <= {20{1'b0}};
		end else begin
			request_cclk_mclk_s <= request_cclk_1a;
			request_cclk_mclk_ss <= request_cclk_mclk_s;
			request_cclk_mclk_ss_1a <= request_cclk_mclk_ss;
			tlb2tlbfetch_reqaddr_cclk_mclk_s <= tlb2tlbfetch_reqaddr_cclk_1a;
			tlb2tlbfetch_reqaddr_cclk_mclk_ss <= tlb2tlbfetch_reqaddr_cclk_mclk_s;
			core2tlb_ptbr_cclk_mclk_s <= core2tlb_ptbr_1a;
			core2tlb_ptbr_cclk_mclk_ss <= core2tlb_ptbr_cclk_mclk_s;
		end
	end
	
	wire        request_m1a = request_cclk_mclk_ss != request_cclk_mclk_ss_1a; /* we have a transition */
	reg         request_0a = 1'b0; /* delay it by one cycle to allow reqaddr to catch up and synchronize; we'll call *that* 0a */
	wire [19:0] reqaddr_0a = tlb2tlbfetch_reqaddr_cclk_mclk_ss;
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
		if (~clkrst_mem_rst_n)
			request_0a <= 1'b0;
		else
			request_0a <= request_m1a;
	end
	
	/*** Cross-clock-domain synchronization: mclk to cclk, and cclk control signal generation. ***/
	reg        response_ready_flag_1a = 1'b0;
	reg [31:0] response_1a = 32'b0;
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
		if (~clkrst_mem_rst_n) begin
			response_ready_flag_1a <= 1'b0;
			response_1a <= {32{1'b0}};
		end else begin
			if (response_ready)
				response_ready_flag_1a <= request_cclk_mclk_ss;
			response_1a <= response;
		end
	end
	
	reg        response_ready_flag_mclk_cclk_s = 1'b0, response_ready_flag_mclk_cclk_ss = 1'b0;
	reg [31:0] response_mclk_cclk_s = 32'b0, response_mclk_cclk_ss = 32'b0;
	always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
		if (~clkrst_core_rst_n) begin
			response_ready_flag_mclk_cclk_s <= 1'b0;
			response_ready_flag_mclk_cclk_ss <= 1'b0;
			response_mclk_cclk_s <= {32{1'b0}};
			response_mclk_cclk_ss <= {32{1'b0}};
		end else begin
			response_ready_flag_mclk_cclk_s <= response_ready_flag_1a;
			response_ready_flag_mclk_cclk_ss <= response_ready_flag_mclk_cclk_s;
			response_mclk_cclk_s <= response_1a;
			response_mclk_cclk_ss <= response_mclk_cclk_s;
		end
	end
	
	wire        response_ready_cclk_m1a = response_ready_flag_mclk_cclk_ss == request_cclk_0a;
	reg         response_ready_cclk_0a = 1'b0; /* again, delayed by one cycle to synchronize */
	wire [31:0] response_cclk_0a = response_mclk_cclk_ss;
	always @(posedge clkrst_core_clk or negedge clkrst_core_rst_n) begin
		if (~clkrst_core_rst_n)
			response_ready_cclk_0a <= 1'b0;
		else
			response_ready_cclk_0a <= response_ready_cclk_m1a;
	end
	
	assign      tlbfetch2tlb_stall_0a = tlb2tlbfetch_request_0a && !response_ready_cclk_0a;
	assign      tlbfetch2tlb_response_0a = response_cclk_0a;
	
	/*** Now the work of actually fetching. ***/
	assign response_ready = request_0a;
	assign response = 32'b0;

endmodule
