/* MCPU_int
 * Interior components of MCPU SoC
 * Moroso project
 *
 * MCPU_int is the "least common denominator" between being built for
 * synthesis or for a testbench.
 */

module MCPU_int(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_addr_0, ltc2mc_avl_be_0, ltc2mc_avl_burstbegin_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_size_0, ltc2mc_avl_wdata_0,
   ltc2mc_avl_write_req_0, ext_uart_tx, ext_led_g, ext_led_r,
   ext_i2c_scl, ext_sd_clk, r0, pre2core_done,
   // Inouts
   ext_i2c_sda, ext_sd_cmd, ext_sd_data,
   // Inputs
   ltc2mc_avl_ready_0, ltc2mc_avl_rdata_valid_0, ltc2mc_avl_rdata_0,
   ext_switches, ext_buttons, clkrst_mem_rst_n, clkrst_mem_clk,
   clkrst_core_clk, ext_uart_rx, clkrst_core_rst_n
   );
  /*AUTOINPUT*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  input			clkrst_core_clk;	// To mmio of MCPU_SOC_mmio.v, ...
  input			clkrst_mem_clk;		// To mem of MCPU_mem.v
  input			clkrst_mem_rst_n;	// To mem of MCPU_mem.v
  input [3:0]		ext_buttons;		// To mmio of MCPU_SOC_mmio.v
  input [9:0]		ext_switches;		// To mmio of MCPU_SOC_mmio.v
  input [127:0]		ltc2mc_avl_rdata_0;	// To mem of MCPU_mem.v
  input			ltc2mc_avl_rdata_valid_0;// To mem of MCPU_mem.v
  input			ltc2mc_avl_ready_0;	// To mem of MCPU_mem.v
  // End of automatics
  output [24:0]		ltc2mc_avl_addr_0;	// From mem of MCPU_mem.v
  output [15:0]		ltc2mc_avl_be_0;	// From mem of MCPU_mem.v
  output 		ltc2mc_avl_burstbegin_0;// From mem of MCPU_mem.v
  output 		ltc2mc_avl_read_req_0;	// From mem of MCPU_mem.v
  output [4:0] 		ltc2mc_avl_size_0;	// From mem of MCPU_mem.v
  output [127:0] 	ltc2mc_avl_wdata_0;	// From mem of MCPU_mem.v
  output 		ltc2mc_avl_write_req_0;	// From mem of MCPU_mem.v


  input 	ext_uart_rx;
  output 	ext_uart_tx;

  output [7:0] 	ext_led_g;
  output [9:0] 	ext_led_r;

  inout 	ext_i2c_sda;
  output 	ext_i2c_scl;

  inout 	ext_sd_cmd;
  inout [3:0] 	ext_sd_data;
  output 	ext_sd_clk;

  // For debugging and stuff.
  output [31:0] r0;
  output 	pre2core_done;
  // End of debugging and stuff.

  input 	clkrst_core_rst_n;
  
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			dispatch;		// From core of MCPU_core.v
  wire [31:2]		dl1c2periph_addr;	// From mem of MCPU_mem.v
  wire [31:0]		dl1c2periph_data_out;	// From mem of MCPU_mem.v
  wire			dl1c2periph_re;		// From mem of MCPU_mem.v
  wire [3:0]		dl1c2periph_we;		// From mem of MCPU_mem.v
  wire			dl1c_ready;		// From mem of MCPU_mem.v
  wire [31:12]		dtlb_addr_a;		// From core of MCPU_core.v
  wire [31:12]		dtlb_addr_b;		// From core of MCPU_core.v
  wire [3:0]		dtlb_flags_a;		// From mem of MCPU_mem.v
  wire [3:0]		dtlb_flags_b;		// From mem of MCPU_mem.v
  wire			dtlb_is_write_a;	// From core of MCPU_core.v
  wire			dtlb_is_write_b;	// From core of MCPU_core.v
  wire			dtlb_pf_a;		// From mem of MCPU_mem.v
  wire			dtlb_pf_b;		// From mem of MCPU_mem.v
  wire [31:12]		dtlb_phys_addr_a;	// From mem of MCPU_mem.v
  wire [31:12]		dtlb_phys_addr_b;	// From mem of MCPU_mem.v
  wire			dtlb_re_a;		// From core of MCPU_core.v
  wire			dtlb_re_b;		// From core of MCPU_core.v
  wire			dtlb_ready;		// From mem of MCPU_mem.v
  wire [27:0]		f2ic_vaddr;		// From core of MCPU_core.v
  wire			f2ic_valid;		// From core of MCPU_core.v
  wire [127:0]		ic2d_packet;		// From mem of MCPU_mem.v
  wire			ic2d_pf;		// From mem of MCPU_mem.v
  wire			ic2f_ready;		// From mem of MCPU_mem.v
  wire [31:0]		mem2dc_data_in0;	// From mem of MCPU_mem.v
  wire [31:0]		mem2dc_data_in1;	// From mem of MCPU_mem.v
  wire [31:0]		mem2dc_data_out0;	// From core of MCPU_core.v
  wire [31:0]		mem2dc_data_out1;	// From core of MCPU_core.v
  wire [29:0]		mem2dc_paddr0;		// From core of MCPU_core.v
  wire [29:0]		mem2dc_paddr1;		// From core of MCPU_core.v
  wire			mem2dc_valid0;		// From core of MCPU_core.v
  wire			mem2dc_valid1;		// From core of MCPU_core.v
  wire [3:0]		mem2dc_write0;		// From core of MCPU_core.v
  wire [3:0]		mem2dc_write1;		// From core of MCPU_core.v
  wire			paging_on;		// From core of MCPU_core.v
  wire [19:0]		ptw_pagedir_base;	// From core of MCPU_core.v
  wire			tlb_clear;		// From core of MCPU_core.v
  wire			user_mode;		// From core of MCPU_core.v
  // End of automatics
  wire 		int_pending = 0;
  wire [3:0] 	int_type = 0;
  wire 		int_clear;
  
  //wire [31:0] 	r0;

  wire [31:0] 	dl1c2periph_data_in;


  // TODO: hook this up.
  reg [27:0] 	f2ic_paddr;
  // TODO: hook this up, too.
  reg 		ic2f_pf = 0;

  /* MCPU_mem AUTO_TEMPLATE(
   .il1c_packet (ic2d_packet[127:0]),
   .il1c_ready (ic2f_ready),
   .il1c_addr (f2ic_vaddr[27:0]),
   .il1c_re (f2ic_valid),
   .il1c_pf (ic2d_pf),

   .dl1c_we_a (mem2dc_valid0 ? mem2dc_write0[] : 4'h0),
   .dl1c_we_b (mem2dc_valid1 ? mem2dc_write1[] : 4'h0),
   .dl1c_re_a (mem2dc_valid0 & ~|mem2dc_write0[]),
   .dl1c_re_b (mem2dc_valid1 & ~|mem2dc_write1[]),
   .dl1c_in_a (mem2dc_data_out0[]),
   .dl1c_in_b (mem2dc_data_out1[]),
   .dl1c_out_a (mem2dc_data_in0[]),
   .dl1c_out_b (mem2dc_data_in1[]),
   .dl1c_addr_a (mem2dc_paddr0[29:0]),
   .dl1c_addr_b (mem2dc_paddr1[29:0]),

   .dl1c_valid(0),
   .dtlb_valid(0));*/
  MCPU_mem mem(/*AUTOINST*/
	       // Outputs
	       .il1c_pf			(ic2d_pf),		 // Templated
	       .dtlb_pf_a		(dtlb_pf_a),
	       .dtlb_pf_b		(dtlb_pf_b),
	       .pre2core_done		(pre2core_done),
	       .dl1c2periph_addr	(dl1c2periph_addr[31:2]),
	       .dl1c2periph_data_out	(dl1c2periph_data_out[31:0]),
	       .dl1c2periph_re		(dl1c2periph_re),
	       .dl1c2periph_we		(dl1c2periph_we[3:0]),
	       .dl1c_out_a		(mem2dc_data_in0[31:0]), // Templated
	       .dl1c_out_b		(mem2dc_data_in1[31:0]), // Templated
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
	       .dl1c_addr_a		(mem2dc_paddr0[29:0]),	 // Templated
	       .dl1c_addr_b		(mem2dc_paddr1[29:0]),	 // Templated
	       .dl1c_in_a		(mem2dc_data_out0[31:0]), // Templated
	       .dl1c_in_b		(mem2dc_data_out1[31:0]), // Templated
	       .dl1c_re_a		(mem2dc_valid0 & ~|mem2dc_write0), // Templated
	       .dl1c_re_b		(mem2dc_valid1 & ~|mem2dc_write1), // Templated
	       .dl1c_we_a		(mem2dc_valid0 ? mem2dc_write0[3:0] : 4'h0), // Templated
	       .dl1c_we_b		(mem2dc_valid1 ? mem2dc_write1[3:0] : 4'h0), // Templated
	       .dtlb_addr_a		(dtlb_addr_a[31:12]),
	       .dtlb_addr_b		(dtlb_addr_b[31:12]),
	       .dtlb_is_write_a		(dtlb_is_write_a),
	       .dtlb_is_write_b		(dtlb_is_write_b),
	       .dtlb_re_a		(dtlb_re_a),
	       .dtlb_re_b		(dtlb_re_b),
	       .il1c_addr		(f2ic_vaddr[27:0]),	 // Templated
	       .il1c_re			(f2ic_valid),		 // Templated
	       .ltc2mc_avl_rdata_0	(ltc2mc_avl_rdata_0[127:0]),
	       .ltc2mc_avl_rdata_valid_0(ltc2mc_avl_rdata_valid_0),
	       .ltc2mc_avl_ready_0	(ltc2mc_avl_ready_0),
	       .paging_on		(paging_on),
	       .ptw_pagedir_base	(ptw_pagedir_base[19:0]),
	       .tlb_clear		(tlb_clear),
	       .user_mode		(user_mode));

  MCPU_SOC_mmio mmio(
		     .data_in(dl1c2periph_data_out),
		     .addr(dl1c2periph_addr[30:2]),
		     .wren(dl1c2periph_we),
		     .data_out(dl1c2periph_data_in[31:0]),
		     /*AUTOINST*/
		     // Outputs
		     .ext_led_g		(ext_led_g[7:0]),
		     .ext_led_r		(ext_led_r[9:0]),
		     .ext_uart_tx	(ext_uart_tx),
		     .ext_i2c_scl	(ext_i2c_scl),
		     .ext_sd_clk	(ext_sd_clk),
		     // Inouts
		     .ext_i2c_sda	(ext_i2c_sda),
		     .ext_sd_cmd	(ext_sd_cmd),
		     .ext_sd_data	(ext_sd_data[3:0]),
		     // Inputs
		     .clkrst_core_clk	(clkrst_core_clk),
		     .clkrst_core_rst_n	(clkrst_core_rst_n),
		     .ext_switches	(ext_switches[9:0]),
		     .ext_buttons	(ext_buttons[3:0]),
		     .ext_uart_rx	(ext_uart_rx));

  /* MCPU_core AUTO_TEMPLATE(
   .clkrst_core_rst_n(clkrst_core_rst_n & pre2core_done),
   .\(dtlb_.*\)0 (\1_a[]),
   .\(dtlb_.*\)1 (\1_b[]),
   .pagedir_base (ptw_pagedir_base[]),
   .mem2dc_done. (dl1c_ready));*/
  MCPU_core core(/*AUTOINST*/
		 // Outputs
		 .int_clear		(int_clear),
		 .mem2dc_paddr0		(mem2dc_paddr0[29:0]),
		 .mem2dc_write0		(mem2dc_write0[3:0]),
		 .mem2dc_valid0		(mem2dc_valid0),
		 .mem2dc_data_out0	(mem2dc_data_out0[31:0]),
		 .mem2dc_paddr1		(mem2dc_paddr1[29:0]),
		 .mem2dc_write1		(mem2dc_write1[3:0]),
		 .mem2dc_valid1		(mem2dc_valid1),
		 .mem2dc_data_out1	(mem2dc_data_out1[31:0]),
		 .dispatch		(dispatch),
		 .f2ic_vaddr		(f2ic_vaddr[27:0]),
		 .f2ic_valid		(f2ic_valid),
		 .dtlb_addr0		(dtlb_addr_a[31:12]),	 // Templated
		 .dtlb_addr1		(dtlb_addr_b[31:12]),	 // Templated
		 .dtlb_re0		(dtlb_re_a),		 // Templated
		 .dtlb_re1		(dtlb_re_b),		 // Templated
		 .dtlb_is_write0	(dtlb_is_write_a),	 // Templated
		 .dtlb_is_write1	(dtlb_is_write_b),	 // Templated
		 .paging_on		(paging_on),
		 .pagedir_base		(ptw_pagedir_base[19:0]), // Templated
		 .user_mode		(user_mode),
		 .tlb_clear		(tlb_clear),
		 .r0			(r0[31:0]),
		 // Inputs
		 .clkrst_core_clk	(clkrst_core_clk),
		 .clkrst_core_rst_n	(clkrst_core_rst_n & pre2core_done), // Templated
		 .int_pending		(int_pending),
		 .int_type		(int_type[3:0]),
		 .mem2dc_done0		(dl1c_ready),		 // Templated
		 .mem2dc_data_in0	(mem2dc_data_in0[31:0]),
		 .mem2dc_done1		(dl1c_ready),		 // Templated
		 .mem2dc_data_in1	(mem2dc_data_in1[31:0]),
		 .f2ic_paddr		(f2ic_paddr[27:0]),
		 .ic2d_packet		(ic2d_packet[127:0]),
		 .ic2d_pf		(ic2d_pf),
		 .ic2f_ready		(ic2f_ready),
		 .dtlb_flags0		(dtlb_flags_a[3:0]),	 // Templated
		 .dtlb_flags1		(dtlb_flags_b[3:0]),	 // Templated
		 .dtlb_phys_addr0	(dtlb_phys_addr_a[31:12]), // Templated
		 .dtlb_phys_addr1	(dtlb_phys_addr_b[31:12]), // Templated
		 .dtlb_pf0		(dtlb_pf_a),		 // Templated
		 .dtlb_pf1		(dtlb_pf_b),		 // Templated
		 .dtlb_ready		(dtlb_ready));

endmodule

// Local Variables:
// verilog-library-flags:("-f dirs.vc")
// verilog-auto-inst-param-value: t
// End:
