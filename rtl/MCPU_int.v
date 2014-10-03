/* MCPU_int
 * Interior components of MCPU SoC
 * Moroso project
 *
 * MCPU_int is the "least common denominator" between being built for
 * synthesis or for a testbench.
 */

module MCPU_INT_leds(/*AUTOARG*/
   // Outputs
   rdled_addr, rdled_opcode, rdled_valid, rdled_wbe, rdled_wdata,
   leds,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, pre2core_done, cli2arb_rdata,
   rdled_rvalid, rdled_stall
   );
	input            clkrst_mem_clk;
	input            clkrst_mem_rst_n;
	
	input            pre2core_done;

	output [31:5]    rdled_addr;
	output [2:0]     rdled_opcode;
	output           rdled_valid;
	output [31:0]    rdled_wbe;
	output [255:0]   rdled_wdata;
	input [255:0]    cli2arb_rdata;
	
	input            rdled_rvalid;
	input            rdled_stall;
	
	output [7:0]     leds;
	
`include "MCPU_MEM_ltc.vh"
	
	reg [5:0]        curad = 0;
	reg [7:0]        leds = 8'haa;
	
	reg [26:0]       ctr = 0;
	
	reg rdled_valid = 0;
	reg [31:5] rdled_addr = 27'b0;
	reg [2:0] rdled_opcode = 3'b0;
	wire [31:0] rdled_wbe = 32'b0;
	wire [255:0] rdled_wdata = 256'b0;
	
	always @(posedge clkrst_mem_clk) begin
		if (~rdled_stall) begin
			ctr <= ctr + 1;
			if (~|ctr && pre2core_done) begin
				rdled_valid <= 1;
				rdled_opcode <= LTC_OPC_READ;
				rdled_addr <= {21'b0, curad};
				curad <= curad + 6'b1;
			end else begin
				rdled_valid <= 0;
			end
		end
		
		if (rdled_rvalid) begin
			leds <= cli2arb_rdata[7:0];
		end
	end
endmodule

module MCPU_int(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_addr_0, ltc2mc_avl_be_0, ltc2mc_avl_burstbegin_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_size_0, ltc2mc_avl_wdata_0,
   ltc2mc_avl_write_req_0, leds,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, ltc2mc_avl_rdata_0,
   ltc2mc_avl_rdata_valid_0, ltc2mc_avl_ready_0
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		clkrst_mem_clk;		// To u_leds of MCPU_INT_leds.v, ...
	input		clkrst_mem_rst_n;	// To u_leds of MCPU_INT_leds.v, ...
	input [127:0]	ltc2mc_avl_rdata_0;	// To u_ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_rdata_valid_0;// To u_ltc of MCPU_MEM_ltc.v
	input		ltc2mc_avl_ready_0;	// To u_ltc of MCPU_MEM_ltc.v
	// End of automatics
	/*AUTOOUTPUT*/
	// Beginning of automatic outputs (from unused autoinst outputs)
	output [24:0]	ltc2mc_avl_addr_0;	// From u_ltc of MCPU_MEM_ltc.v
	output [15:0]	ltc2mc_avl_be_0;	// From u_ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_burstbegin_0;// From u_ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_read_req_0;	// From u_ltc of MCPU_MEM_ltc.v
	output [4:0]	ltc2mc_avl_size_0;	// From u_ltc of MCPU_MEM_ltc.v
	output [127:0]	ltc2mc_avl_wdata_0;	// From u_ltc of MCPU_MEM_ltc.v
	output		ltc2mc_avl_write_req_0;	// From u_ltc of MCPU_MEM_ltc.v
	// End of automatics
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:5]	arb2ltc_addr;		// From u_arb of MCPU_MEM_arb.v
	wire [2:0]	arb2ltc_opcode;		// From u_arb of MCPU_MEM_arb.v
	wire [255:0]	arb2ltc_rdata;		// From u_ltc of MCPU_MEM_ltc.v
	wire		arb2ltc_rvalid;		// From u_ltc of MCPU_MEM_ltc.v
	wire		arb2ltc_stall;		// From u_ltc of MCPU_MEM_ltc.v
	wire		arb2ltc_valid;		// From u_arb of MCPU_MEM_arb.v
	wire [31:0]	arb2ltc_wbe;		// From u_arb of MCPU_MEM_arb.v
	wire [255:0]	arb2ltc_wdata;		// From u_arb of MCPU_MEM_arb.v
	wire [255:0]	cli2arb_rdata;		// From u_arb of MCPU_MEM_arb.v
	wire [31:5]	pre2arb_addr;		// From u_pre of MCPU_MEM_preload.v
	wire [2:0]	pre2arb_opcode;		// From u_pre of MCPU_MEM_preload.v
	wire		pre2arb_rvalid;		// From u_arb of MCPU_MEM_arb.v
	wire		pre2arb_stall;		// From u_arb of MCPU_MEM_arb.v
	wire		pre2arb_valid;		// From u_pre of MCPU_MEM_preload.v
	wire [31:0]	pre2arb_wbe;		// From u_pre of MCPU_MEM_preload.v
	wire [255:0]	pre2arb_wdata;		// From u_pre of MCPU_MEM_preload.v
	wire		pre2core_done;		// From u_pre of MCPU_MEM_preload.v
	wire [31:5]	rdled_addr;		// From u_leds of MCPU_INT_leds.v
	wire [2:0]	rdled_opcode;		// From u_leds of MCPU_INT_leds.v
	wire		rdled_rvalid;		// From u_arb of MCPU_MEM_arb.v
	wire		rdled_stall;		// From u_arb of MCPU_MEM_arb.v
	wire		rdled_valid;		// From u_leds of MCPU_INT_leds.v
	wire [31:0]	rdled_wbe;		// From u_leds of MCPU_INT_leds.v
	wire [255:0]	rdled_wdata;		// From u_leds of MCPU_INT_leds.v
	// End of automatics
	
	output [7:0] leds;
	
	MCPU_INT_leds u_leds(/*AUTOINST*/
			     // Outputs
			     .rdled_addr	(rdled_addr[31:5]),
			     .rdled_opcode	(rdled_opcode[2:0]),
			     .rdled_valid	(rdled_valid),
			     .rdled_wbe		(rdled_wbe[31:0]),
			     .rdled_wdata	(rdled_wdata[255:0]),
			     .leds		(leds[7:0]),
			     // Inputs
			     .clkrst_mem_clk	(clkrst_mem_clk),
			     .clkrst_mem_rst_n	(clkrst_mem_rst_n),
			     .pre2core_done	(pre2core_done),
			     .cli2arb_rdata	(cli2arb_rdata[255:0]),
			     .rdled_rvalid	(rdled_rvalid),
			     .rdled_stall	(rdled_stall));
	
	MCPU_MEM_preload u_pre(/*AUTOINST*/
			       // Outputs
			       .pre2arb_valid	(pre2arb_valid),
			       .pre2arb_opcode	(pre2arb_opcode[2:0]),
			       .pre2arb_addr	(pre2arb_addr[31:5]),
			       .pre2arb_wdata	(pre2arb_wdata[255:0]),
			       .pre2arb_wbe	(pre2arb_wbe[31:0]),
			       .pre2core_done	(pre2core_done),
			       // Inputs
			       .clkrst_mem_clk	(clkrst_mem_clk),
			       .clkrst_mem_rst_n(clkrst_mem_rst_n),
			       .pre2arb_stall	(pre2arb_stall),
			       .pre2arb_rvalid	(pre2arb_rvalid));

    /* AUTO_LISP(defun client-signal (s)
                    (let* ((signal (lambda (c) (concat c s))))
                        (format "{ %s }" (mapconcat signal clients ", ")))) */

    /* AUTO_LISP(setq clients (mapcar 'symbol-name '(
                    pre2arb
                    rdled))) */

    /* MCPU_MEM_arb AUTO_TEMPLATE(
		.cli2arb_stall  (@"(client-signal \"_stall\")"),
		.cli2arb_rvalid (@"(client-signal \"_rvalid\")"),

		.cli2arb_valid  (@"(client-signal \"_valid\")"),
		.cli2arb_opcode (@"(client-signal \"_opcode[2:0]\")"),
		.cli2arb_addr   (@"(client-signal \"_addr[31:5]\")"),
		.cli2arb_wdata  (@"(client-signal \"_wdata[255:0]\")"),
		.cli2arb_wbe    (@"(client-signal \"_wbe[31:0]\")"),
        ); */
	MCPU_MEM_arb #(.CLIENTS(2), .CLIENTS_BITS(1))
		u_arb(/*AUTOINST*/
		      // Outputs
		      .arb2ltc_valid	(arb2ltc_valid),
		      .arb2ltc_opcode	(arb2ltc_opcode[2:0]),
		      .arb2ltc_addr	(arb2ltc_addr[31:5]),
		      .arb2ltc_wdata	(arb2ltc_wdata[255:0]),
		      .arb2ltc_wbe	(arb2ltc_wbe[31:0]),
		      .cli2arb_stall	({ pre2arb_stall, rdled_stall }), // Templated
		      .cli2arb_rdata	(cli2arb_rdata[255:0]),
		      .cli2arb_rvalid	({ pre2arb_rvalid, rdled_rvalid }), // Templated
		      // Inputs
		      .clkrst_mem_clk	(clkrst_mem_clk),
		      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		      .arb2ltc_stall	(arb2ltc_stall),
		      .arb2ltc_rdata	(arb2ltc_rdata[255:0]),
		      .arb2ltc_rvalid	(arb2ltc_rvalid),
		      .cli2arb_valid	({ pre2arb_valid, rdled_valid }), // Templated
		      .cli2arb_opcode	({ pre2arb_opcode[2:0], rdled_opcode[2:0] }), // Templated
		      .cli2arb_addr	({ pre2arb_addr[31:5], rdled_addr[31:5] }), // Templated
		      .cli2arb_wdata	({ pre2arb_wdata[255:0], rdled_wdata[255:0] }), // Templated
		      .cli2arb_wbe	({ pre2arb_wbe[31:0], rdled_wbe[31:0] })); // Templated

	MCPU_MEM_ltc u_ltc(/*AUTOINST*/
			   // Outputs
			   .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
			   .ltc2mc_avl_be_0	(ltc2mc_avl_be_0[15:0]),
			   .ltc2mc_avl_burstbegin_0(ltc2mc_avl_burstbegin_0),
			   .ltc2mc_avl_read_req_0(ltc2mc_avl_read_req_0),
			   .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
			   .ltc2mc_avl_wdata_0	(ltc2mc_avl_wdata_0[127:0]),
			   .ltc2mc_avl_write_req_0(ltc2mc_avl_write_req_0),
			   .arb2ltc_rdata	(arb2ltc_rdata[255:0]),
			   .arb2ltc_rvalid	(arb2ltc_rvalid),
			   .arb2ltc_stall	(arb2ltc_stall),
			   // Inputs
			   .clkrst_mem_clk	(clkrst_mem_clk),
			   .clkrst_mem_rst_n	(clkrst_mem_rst_n),
			   .ltc2mc_avl_rdata_0	(ltc2mc_avl_rdata_0[127:0]),
			   .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
			   .ltc2mc_avl_ready_0	(ltc2mc_avl_ready_0),
			   .arb2ltc_valid	(arb2ltc_valid),
			   .arb2ltc_opcode	(arb2ltc_opcode[2:0]),
			   .arb2ltc_addr	(arb2ltc_addr[31:5]),
			   .arb2ltc_wdata	(arb2ltc_wdata[255:0]),
			   .arb2ltc_wbe		(arb2ltc_wbe[31:0]));

endmodule

// Local Variables:
// verilog-library-flags:("-f dirs.vc")
// End:
