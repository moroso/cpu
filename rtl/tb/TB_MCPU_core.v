module TB_MCPU_core(/*AUTOARG*/
   // Outputs
   uart_tx, uart_status, memoutput,
   // Inputs
   r31, ptw_pagedir_base, ltc2mc_avl_ready_0,
   ltc2mc_avl_rdata_valid_0, ltc2mc_avl_rdata_0, ic2f_pf, f2ic_paddr,
   dtlb_re_b, dtlb_re_a, dtlb_addr_b, dtlb_addr_a, dl1c_we_b,
   dl1c_we_a, dl1c_re_b, dl1c_re_a, dl1c_in_b, dl1c_in_a, dl1c_addr_b,
   dl1c_addr_a, dl1c2periph_data_in, clkrst_mem_rst_n, clkrst_mem_clk,
   clkrst_core_clk, uart_rx, clkrst_core_rst_n, meminput
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		clkrst_core_clk;	// To core of MCPU_core.v
	input		clkrst_mem_clk;		// To mem of MCPU_mem.v
	input		clkrst_mem_rst_n;	// To mem of MCPU_mem.v
	input [31:0]	dl1c2periph_data_in;	// To mem of MCPU_mem.v
	input [31:2]	dl1c_addr_a;		// To mem of MCPU_mem.v
	input [31:2]	dl1c_addr_b;		// To mem of MCPU_mem.v
	input [31:0]	dl1c_in_a;		// To mem of MCPU_mem.v
	input [31:0]	dl1c_in_b;		// To mem of MCPU_mem.v
	input		dl1c_re_a;		// To mem of MCPU_mem.v
	input		dl1c_re_b;		// To mem of MCPU_mem.v
	input [3:0]	dl1c_we_a;		// To mem of MCPU_mem.v
	input [3:0]	dl1c_we_b;		// To mem of MCPU_mem.v
	input [31:12]	dtlb_addr_a;		// To mem of MCPU_mem.v
	input [31:12]	dtlb_addr_b;		// To mem of MCPU_mem.v
	input		dtlb_re_a;		// To mem of MCPU_mem.v
	input		dtlb_re_b;		// To mem of MCPU_mem.v
	input [27:0]	f2ic_paddr;		// To core of MCPU_core.v
	input		ic2f_pf;		// To core of MCPU_core.v
	input [127:0]	ltc2mc_avl_rdata_0;	// To mem of MCPU_mem.v
	input		ltc2mc_avl_rdata_valid_0;// To mem of MCPU_mem.v
	input		ltc2mc_avl_ready_0;	// To mem of MCPU_mem.v
	input [19:0]	ptw_pagedir_base;	// To mem of MCPU_mem.v
	input [31:0]	r31;			// To core of MCPU_core.v
	// End of automatics
	input uart_rx;
	output uart_tx;
    output [4:0] uart_status;

  input 	 clkrst_core_rst_n;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:2]	dl1c2periph_addr;	// From mem of MCPU_mem.v
	wire [31:0]	dl1c2periph_data_out;	// From mem of MCPU_mem.v
	wire		dl1c2periph_re;		// From mem of MCPU_mem.v
	wire [3:0]	dl1c2periph_we;		// From mem of MCPU_mem.v
	wire [31:0]	dl1c_out_a;		// From mem of MCPU_mem.v
	wire [31:0]	dl1c_out_b;		// From mem of MCPU_mem.v
	wire		dl1c_ready;		// From mem of MCPU_mem.v
	wire [3:0]	dtlb_flags_a;		// From mem of MCPU_mem.v
	wire [3:0]	dtlb_flags_b;		// From mem of MCPU_mem.v
	wire [31:12]	dtlb_phys_addr_a;	// From mem of MCPU_mem.v
	wire [31:12]	dtlb_phys_addr_b;	// From mem of MCPU_mem.v
	wire		dtlb_ready;		// From mem of MCPU_mem.v
	wire [27:0]	f2ic_vaddr;		// From core of MCPU_core.v
	wire		f2ic_valid;		// From core of MCPU_core.v
	wire [24:0]	ltc2mc_avl_addr_0;	// From mem of MCPU_mem.v
	wire [15:0]	ltc2mc_avl_be_0;	// From mem of MCPU_mem.v
	wire		ltc2mc_avl_burstbegin_0;// From mem of MCPU_mem.v
	wire		ltc2mc_avl_read_req_0;	// From mem of MCPU_mem.v
	wire [4:0]	ltc2mc_avl_size_0;	// From mem of MCPU_mem.v
	wire [127:0]	ltc2mc_avl_wdata_0;	// From mem of MCPU_mem.v
	wire		ltc2mc_avl_write_req_0;	// From mem of MCPU_mem.v
	wire		paging_on;		// From core of MCPU_core.v
	wire		pre2core_done;		// From mem of MCPU_mem.v
	// End of automatics
	input [31:0] meminput;
	output [31:0] memoutput;
	wire ic2f_ready;		// To core of MCPU_core.v
	wire dispatch;
	wire mem2dc_valid0, mem2dc_valid1;
	wire mem2dc_done0, mem2dc_done1;
	wire [31:0] mem2dc_data_out0, mem2dc_data_out1;
	wire [31:0] mem2dc_data_in0, mem2dc_data_in1;
	wire [29:0] mem2dc_paddr0, mem2dc_paddr1;
	wire [3:0] mem2dc_write0, mem2dc_write1;
	wire [127:0] ic2d_packet;
	
	wire int_pending = 0;
	wire [3:0] int_type = 0;
	wire int_clear;
	
	wire [31:0] r0;

	wire write0, write1;
	wire [3:0] byteen;
	wire [29:0] addr_a;
	wire [31:0] data_a;
	wire [31:0] q_a;
	wire [31:0] periph_q;
	reg [31:0] prev_addr0, prev_addr1;
	reg prev_valid0, prev_valid1;

	assign write0 = |mem2dc_write0 & mem2dc_valid0;
	assign write1 = |mem2dc_write1 & mem2dc_valid1;
	always @(posedge clkrst_core_clk) begin
		prev_addr0 <= mem2dc_paddr0;
		prev_addr1 <= mem2dc_paddr1;
		prev_valid0 <= mem2dc_valid0;
		prev_valid1 <= mem2dc_valid1 & ~mem2dc_valid0;
	end
	assign mem2dc_done0 = prev_valid0 & (prev_addr0 == mem2dc_paddr0);
	assign mem2dc_done1 = prev_valid1 & (prev_addr1 == mem2dc_paddr1);

	assign addr_a = mem2dc_valid0 ? mem2dc_paddr0 : mem2dc_paddr1;
	assign data_a = mem2dc_valid0 ? mem2dc_data_out0 : mem2dc_data_out1;
	assign byteen = mem2dc_valid0 ? mem2dc_write0 : mem2dc_write1;
	
	assign mem2dc_data_in0 = mem2dc_paddr0[29] ? periph_q : q_a;
	assign mem2dc_data_in1 = mem2dc_paddr1[29] ? periph_q : q_a;

  //assign ic2f_ready = 1;

    reg [22:0] ctr;
    always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n)
        if(~clkrst_core_rst_n) ctr <= 0;
        else if(dispatch) ctr <= ctr + 1;
    assign uart_status[4] = ctr[22];

  /*
	altsyncram #(
		.OPERATION_MODE("BIDIR_DUAL_PORT"),
		.WIDTH_A(32),
		.WIDTHAD_A(14), // 14 bits => 16k addrs => 64KB
		.WIDTH_B(128),
		.WIDTHAD_B(12),
		.INIT_FILE("bootrom.mif"),
		.INIT_FILE_LAYOUT("PORT_A"),
		.WIDTH_BYTEENA_A(4)
	) ram(
		.wren_a((write0 | write1) & ~addr_a[29]),
		.wren_b(1'b0),
		.data_a(data_a),
		.address_a(addr_a[13:0]),
		.address_b(f2ic_vaddr[11:0]),
		.clock0(clkrst_core_clk),
		.clock1(clkrst_core_clk),
		.byteena_a(byteen),
		.clocken0(mem2dc_valid0 | mem2dc_valid1),
		.clocken1(f2ic_valid),

		.q_a(q_a),
		.q_b(ic2d_packet)
	);
*/

  // Hack: pretend the memory controller is returning valid data right away.
  // (This means we'll be running entirely out of the caches.)
  // TODO: fix this, obviously.
  assign ltc2mc_avl_ready_0 = 1;
  assign ltc2mc_avl_rdata_valid_0 = 1;

  /* MCPU_mem AUTO_TEMPLATE(
   .il1c_packet (ic2d_packet[127:0]),
   .il1c_ready (ic2f_ready),
   .il1c_addr (f2ic_vaddr[27:0]),
   .il1c_re (f2ic_valid),

   .dl1c_valid(0),
   .dtlb_valid(0));*/
  MCPU_mem mem(/*AUTOINST*/
	       // Outputs
	       .pre2core_done		(pre2core_done),
	       .dl1c2periph_addr	(dl1c2periph_addr[31:2]),
	       .dl1c2periph_data_out	(dl1c2periph_data_out[31:0]),
	       .dl1c2periph_re		(dl1c2periph_re),
	       .dl1c2periph_we		(dl1c2periph_we[3:0]),
	       .dl1c_out_a		(dl1c_out_a[31:0]),
	       .dl1c_out_b		(dl1c_out_b[31:0]),
	       .dl1c_ready		(dl1c_ready),
	       .dtlb_flags_a		(dtlb_flags_a[3:0]),
	       .dtlb_flags_b		(dtlb_flags_b[3:0]),
	       .dtlb_phys_addr_a	(dtlb_phys_addr_a[31:12]),
	       .dtlb_phys_addr_b	(dtlb_phys_addr_b[31:12]),
	       .dtlb_ready		(dtlb_ready),
	       .il1c_packet		(ic2d_packet[127:0]),	 // Templated
	       .il1c_ready		(ic2f_ready),		 // Templated
	       .ltc2mc_avl_addr_0	(ltc2mc_avl_addr_0[24:0]),
	       .ltc2mc_avl_be_0		(ltc2mc_avl_be_0[15:0]),
	       .ltc2mc_avl_burstbegin_0	(ltc2mc_avl_burstbegin_0),
	       .ltc2mc_avl_read_req_0	(ltc2mc_avl_read_req_0),
	       .ltc2mc_avl_size_0	(ltc2mc_avl_size_0[4:0]),
	       .ltc2mc_avl_wdata_0	(ltc2mc_avl_wdata_0[127:0]),
	       .ltc2mc_avl_write_req_0	(ltc2mc_avl_write_req_0),
	       // Inputs
	       .clkrst_mem_clk		(clkrst_mem_clk),
	       .clkrst_mem_rst_n	(clkrst_mem_rst_n),
	       .dl1c2periph_data_in	(dl1c2periph_data_in[31:0]),
	       .dl1c_addr_a		(dl1c_addr_a[31:2]),
	       .dl1c_addr_b		(dl1c_addr_b[31:2]),
	       .dl1c_in_a		(dl1c_in_a[31:0]),
	       .dl1c_in_b		(dl1c_in_b[31:0]),
	       .dl1c_re_a		(dl1c_re_a),
	       .dl1c_re_b		(dl1c_re_b),
	       .dl1c_we_a		(dl1c_we_a[3:0]),
	       .dl1c_we_b		(dl1c_we_b[3:0]),
	       .dtlb_addr_a		(dtlb_addr_a[31:12]),
	       .dtlb_addr_b		(dtlb_addr_b[31:12]),
	       .dtlb_re_a		(dtlb_re_a),
	       .dtlb_re_b		(dtlb_re_b),
	       .il1c_addr		(f2ic_vaddr[27:0]),	 // Templated
	       .il1c_re			(f2ic_valid),		 // Templated
	       .ltc2mc_avl_rdata_0	(ltc2mc_avl_rdata_0[127:0]),
	       .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
	       .ltc2mc_avl_ready_0	(ltc2mc_avl_ready_0),
	       .paging_on		(paging_on),
	       .ptw_pagedir_base	(ptw_pagedir_base[19:0]));

	MCPU_SOC_mmio mmio(
		.clkrst_core_clk(clkrst_core_clk),
		.clkrst_core_rst_n(clkrst_core_rst_n),
		.data_in(data_a),
		.addr(addr_a[28:0]),
		.wren(byteen & {4{addr_a[29] & (mem2dc_valid0 | mem2dc_valid1)}}),
		.data_out(periph_q),
		.meminput(meminput),
		.memoutput(memoutput),
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
        .uart_status(uart_status[3:0])
	);

  /* MCPU_core AUTO_TEMPLATE(
   .clkrst_core_rst_n(clkrst_core_rst_n & pre2core_done));*/
	MCPU_core core(/*AUTOINST*/
		       // Outputs
		       .int_clear	(int_clear),
		       .mem2dc_paddr0	(mem2dc_paddr0[29:0]),
		       .mem2dc_write0	(mem2dc_write0[3:0]),
		       .mem2dc_valid0	(mem2dc_valid0),
		       .mem2dc_data_out0(mem2dc_data_out0[31:0]),
		       .mem2dc_paddr1	(mem2dc_paddr1[29:0]),
		       .mem2dc_write1	(mem2dc_write1[3:0]),
		       .mem2dc_valid1	(mem2dc_valid1),
		       .mem2dc_data_out1(mem2dc_data_out1[31:0]),
		       .dispatch	(dispatch),
		       .f2ic_vaddr	(f2ic_vaddr[27:0]),
		       .f2ic_valid	(f2ic_valid),
		       .paging_on	(paging_on),
		       .r0		(r0[31:0]),
		       // Inputs
		       .clkrst_core_clk	(clkrst_core_clk),
		       .clkrst_core_rst_n(clkrst_core_rst_n & pre2core_done), // Templated
		       .int_pending	(int_pending),
		       .int_type	(int_type[3:0]),
		       .mem2dc_done0	(mem2dc_done0),
		       .mem2dc_data_in0	(mem2dc_data_in0[31:0]),
		       .mem2dc_done1	(mem2dc_done1),
		       .mem2dc_data_in1	(mem2dc_data_in1[31:0]),
		       .f2ic_paddr	(f2ic_paddr[27:0]),
		       .ic2d_packet	(ic2d_packet[127:0]),
		       .ic2f_pf		(ic2f_pf),
		       .ic2f_ready	(ic2f_ready),
		       .r31		(r31[31:0]));

endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
