module MCPU_mem(
                ///*AUTOOUTPUT*//*AUTOINPUT*/
		// Beginning of automatic inputs (from unused autoinst inputs)
		input		clkrst_mem_clk,		// To arb of MCPU_MEM_arb.v, ...
		input		clkrst_mem_rst_n,	// To arb of MCPU_MEM_arb.v, ...
		input [31:0]	dl1c2periph_data_in,	// To dl1c of MCPU_MEM_dl1c.v
		input [31:2]	dl1c_addr_a,		// To dl1c of MCPU_MEM_dl1c.v
		input [31:2]	dl1c_addr_b,		// To dl1c of MCPU_MEM_dl1c.v
		input [31:0]	dl1c_in_a,		// To dl1c of MCPU_MEM_dl1c.v
		input [31:0]	dl1c_in_b,		// To dl1c of MCPU_MEM_dl1c.v
		input		dl1c_re_a,		// To dl1c of MCPU_MEM_dl1c.v
		input		dl1c_re_b,		// To dl1c of MCPU_MEM_dl1c.v
		input [3:0]	dl1c_we_a,		// To dl1c of MCPU_MEM_dl1c.v
		input [3:0]	dl1c_we_b,		// To dl1c of MCPU_MEM_dl1c.v
		input [31:12]	dtlb_addr_a,		// To dtlb of MCPU_MEM_dtlb.v
		input [31:12]	dtlb_addr_b,		// To dtlb of MCPU_MEM_dtlb.v
		input		dtlb_is_write_a,	// To dtlb of MCPU_MEM_dtlb.v
		input		dtlb_is_write_b,	// To dtlb of MCPU_MEM_dtlb.v
		input		dtlb_re_a,		// To dtlb of MCPU_MEM_dtlb.v
		input		dtlb_re_b,		// To dtlb of MCPU_MEM_dtlb.v
		input [31:4]	il1c_addr,		// To il1c of MCPU_MEM_il1c.v
		input		il1c_re,		// To il1c of MCPU_MEM_il1c.v
		input [127:0]	ltc2mc_avl_rdata_0,	// To ltc of MCPU_MEM_ltc.v
		input		ltc2mc_avl_rdata_valid_0,// To ltc of MCPU_MEM_ltc.v
		input		ltc2mc_avl_ready_0,	// To ltc of MCPU_MEM_ltc.v
		input		paging_on,		// To dtlb of MCPU_MEM_dtlb.v, ...
		input [19:0]	ptw_pagedir_base,	// To dtlb_walk of MCPU_MEM_pt_walk.v, ...
		input		user_mode,		// To dtlb of MCPU_MEM_dtlb.v, ...
		// End of automatics
		// Beginning of automatic outputs (from unused autoinst outputs)
		output 	       il1c_pf, // From il1c of MCPU_MEM_il1c.v
		// End of automatics
		// Beginning of automatic outputs (from unused autoinst outputs)
		output 	       dtlb_pf_a, // From dtlb of MCPU_MEM_dtlb.v
		output 	       dtlb_pf_b, // From dtlb of MCPU_MEM_dtlb.v
		// End of automatics
                // Beginning of automatic outputs (from unused autoinst outputs)
                output 	       pre2core_done, // From preload_inst of MCPU_MEM_preload.v
                output [31:2]  dl1c2periph_addr, // From dl1c of MCPU_MEM_dl1c.v
                output [31:0]  dl1c2periph_data_out, // From dl1c of MCPU_MEM_dl1c.v
                output 	       dl1c2periph_re, // From dl1c of MCPU_MEM_dl1c.v
                output [3:0]   dl1c2periph_we, // From dl1c of MCPU_MEM_dl1c.v
                output [31:0]  dl1c_out_a, // From dl1c of MCPU_MEM_dl1c.v
                output [31:0]  dl1c_out_b, // From dl1c of MCPU_MEM_dl1c.v
                output 	       dl1c_ready, // From dl1c of MCPU_MEM_dl1c.v
                output [3:0]   dtlb_flags_a, // From dtlb of MCPU_MEM_dtlb.v
                output [3:0]   dtlb_flags_b, // From dtlb of MCPU_MEM_dtlb.v
                output [31:12] dtlb_phys_addr_a, // From dtlb of MCPU_MEM_dtlb.v
                output [31:12] dtlb_phys_addr_b, // From dtlb of MCPU_MEM_dtlb.v
                output 	       dtlb_ready, // From dtlb of MCPU_MEM_dtlb.v
                output [127:0] il1c_packet, // From il1c of MCPU_MEM_il1c.v
                output 	       il1c_ready, // From il1c of MCPU_MEM_il1c.v
                output [24:0]  ltc2mc_avl_addr_0, // From ltc of MCPU_MEM_ltc.v
                output [15:0]  ltc2mc_avl_be_0, // From ltc of MCPU_MEM_ltc.v
                output 	       ltc2mc_avl_burstbegin_0,// From ltc of MCPU_MEM_ltc.v
                output 	       ltc2mc_avl_read_req_0, // From ltc of MCPU_MEM_ltc.v
                output [4:0]   ltc2mc_avl_size_0, // From ltc of MCPU_MEM_ltc.v
                output [127:0] ltc2mc_avl_wdata_0, // From ltc of MCPU_MEM_ltc.v
                output 	       ltc2mc_avl_write_req_0 // From ltc of MCPU_MEM_ltc.v
                               // End of automatics
                );
  parameter ROM_SIZE = 4096;

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [31:5]		arb2ltc_addr;		// From arb of MCPU_MEM_arb.v
   wire [2:0]		arb2ltc_opcode;		// From arb of MCPU_MEM_arb.v
   wire [255:0]		arb2ltc_rdata;		// From ltc of MCPU_MEM_ltc.v
   wire			arb2ltc_rvalid;		// From ltc of MCPU_MEM_ltc.v
   wire			arb2ltc_stall;		// From ltc of MCPU_MEM_ltc.v
   wire			arb2ltc_valid;		// From arb of MCPU_MEM_arb.v
   wire [31:0]		arb2ltc_wbe;		// From arb of MCPU_MEM_arb.v
   wire [255:0]		arb2ltc_wdata;		// From arb of MCPU_MEM_arb.v
   wire [255:0]		cli2arb_rdata;		// From arb of MCPU_MEM_arb.v
   wire [31:5]		dl1c2arb_addr;		// From dl1c of MCPU_MEM_dl1c.v
   wire [2:0]		dl1c2arb_opcode;	// From dl1c of MCPU_MEM_dl1c.v
   wire			dl1c2arb_rvalid;	// From arb of MCPU_MEM_arb.v
   wire			dl1c2arb_stall;		// From arb of MCPU_MEM_arb.v
   wire			dl1c2arb_valid;		// From dl1c of MCPU_MEM_dl1c.v
   wire [31:0]		dl1c2arb_wbe;		// From dl1c of MCPU_MEM_dl1c.v
   wire [255:0]		dl1c2arb_wdata;		// From dl1c of MCPU_MEM_dl1c.v
   wire [31:5]		dptw2arb_addr;		// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [2:0]		dptw2arb_opcode;	// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire			dptw2arb_rvalid;	// From arb of MCPU_MEM_arb.v
   wire			dptw2arb_stall;		// From arb of MCPU_MEM_arb.v
   wire			dptw2arb_valid;		// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [31:0]		dptw2arb_wbe;		// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [255:0]		dptw2arb_wdata;		// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [31:12]		dtlb2dptw_addr;		// From dtlb of MCPU_MEM_dtlb.v
   wire [3:0]		dtlb2dptw_pagedir_flags;// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [3:0]		dtlb2dptw_pagetab_flags;// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [31:12]		dtlb2dptw_phys_addr;	// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire			dtlb2dptw_re;		// From dtlb of MCPU_MEM_dtlb.v
   wire			dtlb2dptw_ready;	// From dtlb_walk of MCPU_MEM_pt_walk.v
   wire [31:5]		il1c2arb_addr;		// From il1c of MCPU_MEM_il1c.v
   wire [2:0]		il1c2arb_opcode;	// From il1c of MCPU_MEM_il1c.v
   wire			il1c2arb_rvalid;	// From arb of MCPU_MEM_arb.v
   wire			il1c2arb_stall;		// From arb of MCPU_MEM_arb.v
   wire			il1c2arb_valid;		// From il1c of MCPU_MEM_il1c.v
   wire [31:0]		il1c2arb_wbe;		// From il1c of MCPU_MEM_il1c.v
   wire [255:0]		il1c2arb_wdata;		// From il1c of MCPU_MEM_il1c.v
   wire [31:12]		il1c2itlb_addr;		// From il1c of MCPU_MEM_il1c.v
   wire [3:0]		il1c2itlb_flags;	// From itlb of MCPU_MEM_dtlb.v
   wire			il1c2itlb_pf;		// From itlb of MCPU_MEM_dtlb.v
   wire [31:12]		il1c2itlb_phys_addr;	// From itlb of MCPU_MEM_dtlb.v
   wire			il1c2itlb_re;		// From il1c of MCPU_MEM_il1c.v
   wire			il1c2itlb_ready;	// From itlb of MCPU_MEM_dtlb.v
   wire [31:5]		iptw2arb_addr;		// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [2:0]		iptw2arb_opcode;	// From itlb_walk of MCPU_MEM_pt_walk.v
   wire			iptw2arb_rvalid;	// From arb of MCPU_MEM_arb.v
   wire			iptw2arb_stall;		// From arb of MCPU_MEM_arb.v
   wire			iptw2arb_valid;		// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [31:0]		iptw2arb_wbe;		// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [255:0]		iptw2arb_wdata;		// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [31:12]		itlb2iptw_addr;		// From itlb of MCPU_MEM_dtlb.v
   wire [3:0]		itlb2iptw_pagedir_flags;// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [3:0]		itlb2iptw_pagetab_flags;// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [31:12]		itlb2iptw_phys_addr;	// From itlb_walk of MCPU_MEM_pt_walk.v
   wire			itlb2iptw_re;		// From itlb of MCPU_MEM_dtlb.v
   wire			itlb2iptw_ready;	// From itlb_walk of MCPU_MEM_pt_walk.v
   wire [31:5]		pre2arb_addr;		// From preload_inst of MCPU_MEM_preload.v
   wire [2:0]		pre2arb_opcode;		// From preload_inst of MCPU_MEM_preload.v
   wire			pre2arb_rvalid;		// From arb of MCPU_MEM_arb.v
   wire			pre2arb_stall;		// From arb of MCPU_MEM_arb.v
   wire			pre2arb_valid;		// From preload_inst of MCPU_MEM_preload.v
   wire [31:0]		pre2arb_wbe;		// From preload_inst of MCPU_MEM_preload.v
   wire [255:0]		pre2arb_wdata;		// From preload_inst of MCPU_MEM_preload.v
   // End of automatics

	 /* MCPU_MEM_arb AUTO_TEMPLATE(
		.cli2arb_stall({dl1c2arb_stall, il1c2arb_stall, dptw2arb_stall, iptw2arb_stall, pre2arb_stall}),
		.cli2arb_rvalid({dl1c2arb_rvalid, il1c2arb_rvalid, dptw2arb_rvalid, iptw2arb_rvalid, pre2arb_rvalid}),
		.cli2arb_valid({dl1c2arb_valid, il1c2arb_valid, dptw2arb_valid, iptw2arb_valid, pre2arb_valid}),
		.cli2arb_opcode({dl1c2arb_opcode[2:0], il1c2arb_opcode[2:0], dptw2arb_opcode[2:0], iptw2arb_opcode[2:0], pre2arb_opcode[2:0]}),
		.cli2arb_addr({dl1c2arb_addr[31:5], il1c2arb_addr[31:5], dptw2arb_addr[31:5], iptw2arb_addr[31:5], pre2arb_addr[31:5]}),
		.cli2arb_wdata({dl1c2arb_wdata[255:0], il1c2arb_wdata[255:0], dptw2arb_wdata[255:0], iptw2arb_wdata[255:0], pre2arb_wdata[255:0]}),
		.cli2arb_wbe({dl1c2arb_wbe[31:0], il1c2arb_wbe[31:0], dptw2arb_wbe[31:0], iptw2arb_wbe[31:0], pre2arb_wbe[31:0]}),
		); */
   MCPU_MEM_arb #(.CLIENTS(5), .CLIENTS_BITS(3))
	 arb(/*AUTOINST*/
	     // Outputs
	     .arb2ltc_valid		(arb2ltc_valid),
	     .arb2ltc_opcode		(arb2ltc_opcode[2:0]),
	     .arb2ltc_addr		(arb2ltc_addr[31:5]),
	     .arb2ltc_wdata		(arb2ltc_wdata[255:0]),
	     .arb2ltc_wbe		(arb2ltc_wbe[31:0]),
	     .cli2arb_stall		({dl1c2arb_stall, il1c2arb_stall, dptw2arb_stall, iptw2arb_stall, pre2arb_stall}), // Templated
	     .cli2arb_rdata		(cli2arb_rdata[255:0]),
	     .cli2arb_rvalid		({dl1c2arb_rvalid, il1c2arb_rvalid, dptw2arb_rvalid, iptw2arb_rvalid, pre2arb_rvalid}), // Templated
	     // Inputs
	     .clkrst_mem_clk		(clkrst_mem_clk),
	     .clkrst_mem_rst_n		(clkrst_mem_rst_n),
	     .arb2ltc_stall		(arb2ltc_stall),
	     .arb2ltc_rdata		(arb2ltc_rdata[255:0]),
	     .arb2ltc_rvalid		(arb2ltc_rvalid),
	     .cli2arb_valid		({dl1c2arb_valid, il1c2arb_valid, dptw2arb_valid, iptw2arb_valid, pre2arb_valid}), // Templated
	     .cli2arb_opcode		({dl1c2arb_opcode[2:0], il1c2arb_opcode[2:0], dptw2arb_opcode[2:0], iptw2arb_opcode[2:0], pre2arb_opcode[2:0]}), // Templated
	     .cli2arb_addr		({dl1c2arb_addr[31:5], il1c2arb_addr[31:5], dptw2arb_addr[31:5], iptw2arb_addr[31:5], pre2arb_addr[31:5]}), // Templated
	     .cli2arb_wdata		({dl1c2arb_wdata[255:0], il1c2arb_wdata[255:0], dptw2arb_wdata[255:0], iptw2arb_wdata[255:0], pre2arb_wdata[255:0]}), // Templated
	     .cli2arb_wbe		({dl1c2arb_wbe[31:0], il1c2arb_wbe[31:0], dptw2arb_wbe[31:0], iptw2arb_wbe[31:0], pre2arb_wbe[31:0]})); // Templated

   MCPU_MEM_preload #(
                      .ROM_SIZE(ROM_SIZE)
                     ) preload_inst(/*AUTOINST*/
				    // Outputs
				    .pre2arb_valid	(pre2arb_valid),
				    .pre2arb_opcode	(pre2arb_opcode[2:0]),
				    .pre2arb_addr	(pre2arb_addr[31:5]),
				    .pre2arb_wdata	(pre2arb_wdata[255:0]),
				    .pre2arb_wbe	(pre2arb_wbe[31:0]),
				    .pre2core_done	(pre2core_done),
				    // Inputs
				    .clkrst_mem_clk	(clkrst_mem_clk),
				    .clkrst_mem_rst_n	(clkrst_mem_rst_n),
				    .pre2arb_stall	(pre2arb_stall),
				    .pre2arb_rvalid	(pre2arb_rvalid));

	 MCPU_MEM_ltc ltc(/*AUTOINST*/
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
			  .arb2ltc_addr		(arb2ltc_addr[31:5]),
			  .arb2ltc_wdata	(arb2ltc_wdata[255:0]),
			  .arb2ltc_wbe		(arb2ltc_wbe[31:0]));

   /* MCPU_MEM_dl1c AUTO_TEMPLATE(
    .dl1c2arb_rdata(cli2arb_rdata[]));
    */
   MCPU_MEM_dl1c dl1c(/*AUTOINST*/
		      // Outputs
		      .dl1c_out_a	(dl1c_out_a[31:0]),
		      .dl1c_out_b	(dl1c_out_b[31:0]),
		      .dl1c_ready	(dl1c_ready),
		      .dl1c2periph_addr	(dl1c2periph_addr[31:2]),
		      .dl1c2periph_re	(dl1c2periph_re),
		      .dl1c2periph_we	(dl1c2periph_we[3:0]),
		      .dl1c2periph_data_out(dl1c2periph_data_out[31:0]),
		      .dl1c2arb_valid	(dl1c2arb_valid),
		      .dl1c2arb_opcode	(dl1c2arb_opcode[2:0]),
		      .dl1c2arb_addr	(dl1c2arb_addr[31:5]),
		      .dl1c2arb_wdata	(dl1c2arb_wdata[255:0]),
		      .dl1c2arb_wbe	(dl1c2arb_wbe[31:0]),
		      // Inputs
		      .clkrst_mem_clk	(clkrst_mem_clk),
		      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		      .dl1c_addr_a	(dl1c_addr_a[31:2]),
		      .dl1c_addr_b	(dl1c_addr_b[31:2]),
		      .dl1c_re_a	(dl1c_re_a),
		      .dl1c_re_b	(dl1c_re_b),
		      .dl1c_we_a	(dl1c_we_a[3:0]),
		      .dl1c_we_b	(dl1c_we_b[3:0]),
		      .dl1c_in_a	(dl1c_in_a[31:0]),
		      .dl1c_in_b	(dl1c_in_b[31:0]),
		      .dl1c2periph_data_in(dl1c2periph_data_in[31:0]),
		      .dl1c2arb_rdata	(cli2arb_rdata[255:0]),	 // Templated
		      .dl1c2arb_rvalid	(dl1c2arb_rvalid),
		      .dl1c2arb_stall	(dl1c2arb_stall));

   /* MCPU_MEM_dtlb AUTO_TEMPLATE(
    .tlb2ptw\(.*\) (dtlb2dptw\1[]));
    */
   MCPU_MEM_dtlb dtlb(/*AUTOINST*/
		      // Outputs
		      .dtlb_phys_addr_a	(dtlb_phys_addr_a[31:12]),
		      .dtlb_phys_addr_b	(dtlb_phys_addr_b[31:12]),
		      .dtlb_flags_a	(dtlb_flags_a[3:0]),
		      .dtlb_flags_b	(dtlb_flags_b[3:0]),
		      .dtlb_pf_a	(dtlb_pf_a),
		      .dtlb_pf_b	(dtlb_pf_b),
		      .dtlb_ready	(dtlb_ready),
		      .tlb2ptw_addr	(dtlb2dptw_addr[31:12]), // Templated
		      .tlb2ptw_re	(dtlb2dptw_re),		 // Templated
		      // Inputs
		      .clkrst_mem_clk	(clkrst_mem_clk),
		      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		      .dtlb_addr_a	(dtlb_addr_a[31:12]),
		      .dtlb_addr_b	(dtlb_addr_b[31:12]),
		      .dtlb_re_a	(dtlb_re_a),
		      .dtlb_re_b	(dtlb_re_b),
		      .dtlb_is_write_a	(dtlb_is_write_a),
		      .dtlb_is_write_b	(dtlb_is_write_b),
		      .paging_on	(paging_on),
		      .user_mode	(user_mode),
		      .tlb2ptw_phys_addr(dtlb2dptw_phys_addr[31:12]), // Templated
		      .tlb2ptw_ready	(dtlb2dptw_ready),	 // Templated
		      .tlb2ptw_pagetab_flags(dtlb2dptw_pagetab_flags[3:0]), // Templated
		      .tlb2ptw_pagedir_flags(dtlb2dptw_pagedir_flags[3:0])); // Templated

   /* MCPU_MEM_pt_walk AUTO_TEMPLATE "\(.\)tlb.+" (
    .ptw2arb_rdata(cli2arb_rdata[]),
    .ptw2arb\(.*\)(@ptw2arb\1[]),
    .tlb2ptw\(.*\)(@tlb2@ptw\1[]));
    */
   MCPU_MEM_pt_walk dtlb_walk(/*AUTOINST*/
			      // Outputs
			      .tlb2ptw_phys_addr(dtlb2dptw_phys_addr[31:12]), // Templated
			      .tlb2ptw_ready	(dtlb2dptw_ready), // Templated
			      .tlb2ptw_pagetab_flags(dtlb2dptw_pagetab_flags[3:0]), // Templated
			      .tlb2ptw_pagedir_flags(dtlb2dptw_pagedir_flags[3:0]), // Templated
			      .ptw2arb_valid	(dptw2arb_valid), // Templated
			      .ptw2arb_opcode	(dptw2arb_opcode[2:0]), // Templated
			      .ptw2arb_addr	(dptw2arb_addr[31:5]), // Templated
			      .ptw2arb_wdata	(dptw2arb_wdata[255:0]), // Templated
			      .ptw2arb_wbe	(dptw2arb_wbe[31:0]), // Templated
			      // Inputs
			      .clkrst_mem_clk	(clkrst_mem_clk),
			      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
			      .tlb2ptw_addr	(dtlb2dptw_addr[31:12]), // Templated
			      .tlb2ptw_re	(dtlb2dptw_re),	 // Templated
			      .ptw_pagedir_base	(ptw_pagedir_base[19:0]),
			      .ptw2arb_rdata	(cli2arb_rdata[255:0]), // Templated
			      .ptw2arb_rvalid	(dptw2arb_rvalid), // Templated
			      .ptw2arb_stall	(dptw2arb_stall)); // Templated

   /* MCPU_MEM_dtlb AUTO_TEMPLATE(
    .dtlb_re_b(1'b0),
    .dtlb_is_write_a(1'b0),
    .dtlb\(.*\)_b (),
    .dtlb\(.*\)_a (il1c2itlb\1[]),
    .tlb2ptw\(.*\) (itlb2iptw\1[]),
    .\(.*\)dtlb\(.*\) (\1il1c2itlb\2[]));
    */
   MCPU_MEM_dtlb itlb(/*AUTOINST*/
		      // Outputs
		      .dtlb_phys_addr_a	(il1c2itlb_phys_addr[31:12]), // Templated
		      .dtlb_phys_addr_b	(),			 // Templated
		      .dtlb_flags_a	(il1c2itlb_flags[3:0]),	 // Templated
		      .dtlb_flags_b	(),			 // Templated
		      .dtlb_pf_a	(il1c2itlb_pf),		 // Templated
		      .dtlb_pf_b	(),			 // Templated
		      .dtlb_ready	(il1c2itlb_ready),	 // Templated
		      .tlb2ptw_addr	(itlb2iptw_addr[31:12]), // Templated
		      .tlb2ptw_re	(itlb2iptw_re),		 // Templated
		      // Inputs
		      .clkrst_mem_clk	(clkrst_mem_clk),
		      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		      .dtlb_addr_a	(il1c2itlb_addr[31:12]), // Templated
		      .dtlb_addr_b	(),			 // Templated
		      .dtlb_re_a	(il1c2itlb_re),		 // Templated
		      .dtlb_re_b	(1'b0),			 // Templated
		      .dtlb_is_write_a	(1'b0),			 // Templated
		      .dtlb_is_write_b	(),			 // Templated
		      .paging_on	(paging_on),
		      .user_mode	(user_mode),
		      .tlb2ptw_phys_addr(itlb2iptw_phys_addr[31:12]), // Templated
		      .tlb2ptw_ready	(itlb2iptw_ready),	 // Templated
		      .tlb2ptw_pagetab_flags(itlb2iptw_pagetab_flags[3:0]), // Templated
		      .tlb2ptw_pagedir_flags(itlb2iptw_pagedir_flags[3:0])); // Templated

   MCPU_MEM_pt_walk itlb_walk(/*AUTOINST*/
			      // Outputs
			      .tlb2ptw_phys_addr(itlb2iptw_phys_addr[31:12]), // Templated
			      .tlb2ptw_ready	(itlb2iptw_ready), // Templated
			      .tlb2ptw_pagetab_flags(itlb2iptw_pagetab_flags[3:0]), // Templated
			      .tlb2ptw_pagedir_flags(itlb2iptw_pagedir_flags[3:0]), // Templated
			      .ptw2arb_valid	(iptw2arb_valid), // Templated
			      .ptw2arb_opcode	(iptw2arb_opcode[2:0]), // Templated
			      .ptw2arb_addr	(iptw2arb_addr[31:5]), // Templated
			      .ptw2arb_wdata	(iptw2arb_wdata[255:0]), // Templated
			      .ptw2arb_wbe	(iptw2arb_wbe[31:0]), // Templated
			      // Inputs
			      .clkrst_mem_clk	(clkrst_mem_clk),
			      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
			      .tlb2ptw_addr	(itlb2iptw_addr[31:12]), // Templated
			      .tlb2ptw_re	(itlb2iptw_re),	 // Templated
			      .ptw_pagedir_base	(ptw_pagedir_base[19:0]),
			      .ptw2arb_rdata	(cli2arb_rdata[255:0]), // Templated
			      .ptw2arb_rvalid	(iptw2arb_rvalid), // Templated
			      .ptw2arb_stall	(iptw2arb_stall)); // Templated

   /* MCPU_MEM_il1c AUTO_TEMPLATE(
    .il1c2tlb\(.*\) (il1c2itlb\1[]),
    .il1c2arb_rdata(cli2arb_rdata[]));
    */
   MCPU_MEM_il1c il1c(/*AUTOINST*/
		      // Outputs
		      .il1c_packet	(il1c_packet[127:0]),
		      .il1c_ready	(il1c_ready),
		      .il1c_pf		(il1c_pf),
		      .il1c2tlb_addr	(il1c2itlb_addr[31:12]), // Templated
		      .il1c2tlb_re	(il1c2itlb_re),		 // Templated
		      .il1c2arb_valid	(il1c2arb_valid),
		      .il1c2arb_opcode	(il1c2arb_opcode[2:0]),
		      .il1c2arb_addr	(il1c2arb_addr[31:5]),
		      .il1c2arb_wdata	(il1c2arb_wdata[255:0]),
		      .il1c2arb_wbe	(il1c2arb_wbe[31:0]),
		      // Inputs
		      .clkrst_mem_clk	(clkrst_mem_clk),
		      .clkrst_mem_rst_n	(clkrst_mem_rst_n),
		      .il1c_addr	(il1c_addr[31:4]),
		      .il1c_re		(il1c_re),
		      .il1c2tlb_flags	(il1c2itlb_flags[3:0]),	 // Templated
		      .il1c2tlb_phys_addr(il1c2itlb_phys_addr[31:12]), // Templated
		      .il1c2tlb_ready	(il1c2itlb_ready),	 // Templated
		      .il1c2tlb_pf	(il1c2itlb_pf),		 // Templated
		      .il1c2arb_rdata	(cli2arb_rdata[255:0]),	 // Templated
		      .il1c2arb_rvalid	(il1c2arb_rvalid),
		      .il1c2arb_stall	(il1c2arb_stall));

endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
