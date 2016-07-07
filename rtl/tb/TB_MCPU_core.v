module TB_MCPU_core(/*AUTOARG*/
   // Outputs
   uart_tx, uart_status, memoutput,
   // Inputs
   r31, clkrst_core_rst_n, clkrst_core_clk, uart_rx, meminput
   );
	/*AUTOINPUT*/
	// Beginning of automatic inputs (from unused autoinst inputs)
	input		clkrst_core_clk;	// To core of MCPU_core.v
	input		clkrst_core_rst_n;	// To core of MCPU_core.v
	input [31:0]	r31;			// To core of MCPU_core.v
	// End of automatics
	input uart_rx;
	output uart_tx;
    output [4:0] uart_status;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [27:0]	f2ic_paddr;		// From core of MCPU_core.v
	wire		f2ic_valid;		// From core of MCPU_core.v
	wire		ft2itlb_pagefault;	// From tlb of MCPU_CACHE_tlb_dummy.v
	wire [19:0]	ft2itlb_physpage;	// From tlb of MCPU_CACHE_tlb_dummy.v
	wire		ft2itlb_ready;		// From tlb of MCPU_CACHE_tlb_dummy.v
	wire		ft2itlb_valid;		// From core of MCPU_core.v
	wire [19:0]	ft2itlb_virtpage;	// From core of MCPU_core.v
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
	
    reg [22:0] ctr;
    always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n)
        if(~clkrst_core_rst_n) ctr <= 0;
        else if(dispatch) ctr <= ctr + 1;
    assign uart_status[4] = ctr[22];

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
		.address_b(f2ic_paddr[11:0]),
		.clock0(clkrst_core_clk),
		.clock1(clkrst_core_clk),
		.byteena_a(byteen),
		.clocken0(mem2dc_valid0 | mem2dc_valid1),
		.clocken1(f2ic_valid),

		.q_a(q_a),
		.q_b(ic2d_packet)
	);

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
		       .ft2itlb_valid	(ft2itlb_valid),
		       .ft2itlb_virtpage(ft2itlb_virtpage[19:0]),
		       .f2ic_paddr	(f2ic_paddr[27:0]),
		       .f2ic_valid	(f2ic_valid),
		       .r0		(r0[31:0]),
               .dispatch(dispatch),
		       // Inputs
		       .clkrst_core_clk	(clkrst_core_clk),
		       .clkrst_core_rst_n(clkrst_core_rst_n),
		       .int_pending	(int_pending),
		       .int_type	(int_type[3:0]),
		       .mem2dc_done0	(mem2dc_done0),
		       .mem2dc_data_in0	(mem2dc_data_in0[31:0]),
		       .mem2dc_done1	(mem2dc_done1),
		       .mem2dc_data_in1	(mem2dc_data_in1[31:0]),
		       .ft2itlb_ready	(ft2itlb_ready),
		       .ft2itlb_physpage(ft2itlb_physpage[19:0]),
		       .ft2itlb_pagefault(ft2itlb_pagefault),
		       .ic2d_packet	(ic2d_packet[127:0]),
		       .ic2f_ready	(ic2f_ready),
		       .r31		(r31[31:0]));

//	MCPU_CACHE_ic_dummy ic(/*AUTOINST*/
//			       // Outputs
//			       .ic2f_ready	(ic2f_ready),
//			       .ic2f_packet	(ic2f_packet[127:0]),
//			       // Inputs
//			       .f2ic_valid	(f2ic_valid),
//			       .f2ic_paddr	(f2ic_paddr[27:0]));
assign ic2f_ready = f2ic_valid;

	MCPU_CACHE_tlb_dummy tlb(/*AUTOINST*/
				 // Outputs
				 .ft2itlb_pagefault	(ft2itlb_pagefault),
				 .ft2itlb_physpage	(ft2itlb_physpage[19:0]),
				 .ft2itlb_ready		(ft2itlb_ready),
				 // Inputs
				 .ft2itlb_valid		(ft2itlb_valid),
				 .ft2itlb_virtpage	(ft2itlb_virtpage[19:0]));
endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// verilog-auto-inst-param-value: t
// End:
