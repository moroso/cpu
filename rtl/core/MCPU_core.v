
module MCPU_core(/*AUTOARG*/
   // Outputs
   int_clear, ft2itlb_valid, ft2itlb_virtpage, f2ic_paddr, f2ic_valid,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, int_pending, int_type,
   ft2itlb_ready, ft2itlb_physpage, ft2itlb_pagefault, ic2f_packet,
   ic2f_ready
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  /* Interrupt Controller */
  input int_pending;
  input [3:0] int_type;
  output int_clear;
  assign int_clear = int_pending | |int_type; // Get rid of warnings. REPLACE THIS

  /* TODO DTLB/D$ interface */

  /* ITLB interface */
  output ft2itlb_valid;
  output [19:0] ft2itlb_virtpage;
  input ft2itlb_ready;
  input [19:0] ft2itlb_physpage;
  input ft2itlb_pagefault;

  /* I$ interface */
  output [27:0] f2ic_paddr;
  output f2ic_valid;
  input [127:0] ic2f_packet;
  input ic2f_ready;

//  output [31:0]   mem [0:31]; // registers

  /* TODO something about MMIOs */

  /*AUTOREG*/
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [4:0]		combined_ec0;		// From exn_encode of MCPU_CORE_exn_encode.v
  wire [4:0]		combined_ec1;		// From exn_encode of MCPU_CORE_exn_encode.v
  wire [4:0]		combined_ec2;		// From exn_encode of MCPU_CORE_exn_encode.v
  wire [4:0]		combined_ec3;		// From exn_encode of MCPU_CORE_exn_encode.v
  wire			coproc_branch;		// From coproc of MCPU_CORE_coproc.v
  wire [27:0]		coproc_branchaddr;	// From coproc of MCPU_CORE_coproc.v
  wire			coproc_rd_we;		// From coproc of MCPU_CORE_coproc.v
  wire [31:0]		coproc_reg_result;	// From coproc of MCPU_CORE_coproc.v
  wire			d2pc_out_branchreg0;	// From d0 of MCPU_CORE_decode.v
  wire			d2pc_out_branchreg1;	// From d1 of MCPU_CORE_decode.v
  wire			d2pc_out_branchreg2;	// From d2 of MCPU_CORE_decode.v
  wire			d2pc_out_branchreg3;	// From d3 of MCPU_CORE_decode.v
  wire [8:0]		d2pc_out_execute_opcode0;// From d0 of MCPU_CORE_decode.v
  wire [8:0]		d2pc_out_execute_opcode1;// From d1 of MCPU_CORE_decode.v
  wire [8:0]		d2pc_out_execute_opcode2;// From d2 of MCPU_CORE_decode.v
  wire [8:0]		d2pc_out_execute_opcode3;// From d3 of MCPU_CORE_decode.v
  wire			d2pc_out_invalid0;	// From d0 of MCPU_CORE_decode.v
  wire			d2pc_out_invalid1;	// From d1 of MCPU_CORE_decode.v
  wire			d2pc_out_invalid2;	// From d2 of MCPU_CORE_decode.v
  wire [11:0]		d2pc_out_lsu_offset0;	// From d0 of MCPU_CORE_decode.v
  wire [11:0]		d2pc_out_lsu_offset1;	// From d1 of MCPU_CORE_decode.v
  wire [11:0]		d2pc_out_lsu_offset2;	// From d2 of MCPU_CORE_decode.v
  wire [11:0]		d2pc_out_lsu_offset3;	// From d3 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_oper_type0;	// From d0 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_oper_type1;	// From d1 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_oper_type2;	// From d2 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_oper_type3;	// From d3 of MCPU_CORE_decode.v
  wire			d2pc_out_pred_we0;	// From d0 of MCPU_CORE_decode.v
  wire			d2pc_out_pred_we1;	// From d1 of MCPU_CORE_decode.v
  wire			d2pc_out_pred_we2;	// From d2 of MCPU_CORE_decode.v
  wire			d2pc_out_pred_we3;	// From d3 of MCPU_CORE_decode.v
  wire [4:0]		d2pc_out_rd_num0;	// From d0 of MCPU_CORE_decode.v
  wire [4:0]		d2pc_out_rd_num1;	// From d1 of MCPU_CORE_decode.v
  wire [4:0]		d2pc_out_rd_num2;	// From d2 of MCPU_CORE_decode.v
  wire [4:0]		d2pc_out_rd_num3;	// From d3 of MCPU_CORE_decode.v
  wire			d2pc_out_rd_we0;	// From d0 of MCPU_CORE_decode.v
  wire			d2pc_out_rd_we1;	// From d1 of MCPU_CORE_decode.v
  wire			d2pc_out_rd_we2;	// From d2 of MCPU_CORE_decode.v
  wire			d2pc_out_rd_we3;	// From d3 of MCPU_CORE_decode.v
  wire [5:0]		d2pc_out_shift_amount0;	// From d0 of MCPU_CORE_decode.v
  wire [5:0]		d2pc_out_shift_amount1;	// From d1 of MCPU_CORE_decode.v
  wire [5:0]		d2pc_out_shift_amount2;	// From d2 of MCPU_CORE_decode.v
  wire [5:0]		d2pc_out_shift_amount3;	// From d3 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_shift_type0;	// From d0 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_shift_type1;	// From d1 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_shift_type2;	// From d2 of MCPU_CORE_decode.v
  wire [1:0]		d2pc_out_shift_type3;	// From d3 of MCPU_CORE_decode.v
  wire [31:0]		d2pc_out_sop0;		// From d0 of MCPU_CORE_decode.v
  wire [31:0]		d2pc_out_sop1;		// From d1 of MCPU_CORE_decode.v
  wire [31:0]		d2pc_out_sop2;		// From d2 of MCPU_CORE_decode.v
  wire [31:0]		d2pc_out_sop3;		// From d3 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rs_num0;		// From d0 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rs_num1;		// From d1 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rs_num2;		// From d2 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rs_num3;		// From d3 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rt_num0;		// From d0 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rt_num1;		// From d1 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rt_num2;		// From d2 of MCPU_CORE_decode.v
  wire [4:0]		d2rf_rt_num3;		// From d3 of MCPU_CORE_decode.v
  wire			dep_stall0;		// From d0 of MCPU_CORE_decode.v
  wire			dep_stall1;		// From d1 of MCPU_CORE_decode.v
  wire			dep_stall2;		// From d2 of MCPU_CORE_decode.v
  wire			dep_stall3;		// From d3 of MCPU_CORE_decode.v
  wire [127:0]		f2d_out_packet;		// From f of MCPU_CORE_stage_fetch.v
  wire [27:0]		f2d_out_virtpc;		// From f of MCPU_CORE_stage_fetch.v
  wire			ft2f_out_inst_pf;	// From ft of MCPU_CORE_stage_fetchtlb.v
  wire [19:0]		ft2f_out_physpage;	// From ft of MCPU_CORE_stage_fetchtlb.v
  wire			interrupts_enabled;	// From coproc of MCPU_CORE_coproc.v
  wire [31:0]		pc2wb_out_result1;	// From alu1 of MCPU_CORE_alu.v
  wire [31:0]		pc2wb_out_result2;	// From alu2 of MCPU_CORE_alu.v
  wire [31:0]		pc2wb_out_result3;	// From alu3 of MCPU_CORE_alu.v
  wire			pc_alu_invalid0;	// From alu0 of MCPU_CORE_alu.v
  wire			pc_alu_invalid1;	// From alu1 of MCPU_CORE_alu.v
  wire			pc_alu_invalid2;	// From alu2 of MCPU_CORE_alu.v
  wire			pc_alu_invalid3;	// From alu3 of MCPU_CORE_alu.v
  wire [2:0]		preds;			// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rs_data0;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rs_data1;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rs_data2;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rs_data3;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rt_data0;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rt_data1;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rt_data2;		// From regs of MCPU_CORE_regfile.v
  wire [31:0]		rf2d_rt_data3;		// From regs of MCPU_CORE_regfile.v
  wire [2:0]		sb2d_pred_scoreboard;	// From sb of MCPU_CORE_scoreboard.v
  wire [31:0]		sb2d_reg_scoreboard;	// From sb of MCPU_CORE_scoreboard.v
  wire			user_mode;		// From coproc of MCPU_CORE_coproc.v
  // End of automatics

  // wires that get missed because they're not module outputs :/
  wire [27:0] ft2f_out_virtpc /* verilator public */;  // From ft of stage_fetchtlb.v
  wire [19:0] ft2f_in_physpage /* verilator public */;
  wire [27:0] ft2f_in_virtpc /* verilator public */;
  wire ft2f_in_inst_pf;
  wire [127:0] f2d_in_packet /* verilator public */;
  wire [27:0] f2d_in_virtpc;
  wire f2d_in_inst_pf;
  wire d2pc_in_branchreg;
  wire [31:0] d2pc_in_sop3, d2pc_in_sop2, d2pc_in_sop1, d2pc_in_sop0;
  wire [31:0] d2pc_in_rs_data3, d2pc_in_rs_data2, d2pc_in_rs_data1, d2pc_in_rs_data0;
  wire d2pc_in_rd_we3, d2pc_in_rd_we2, d2pc_in_rd_we1, d2pc_in_rd_we0;
  wire d2pc_in_pred_we3, d2pc_in_pred_we2, d2pc_in_pred_we1, d2pc_in_pred_we0;
  wire [4:0] d2pc_in_rd_num3, d2pc_in_rd_num2, d2pc_in_rd_num1, d2pc_in_rd_num0;
  wire [1:0] d2pc_in_oper_type3, d2pc_in_oper_type2, d2pc_in_oper_type1, d2pc_in_oper_type0;
  wire [1:0] d2pc_in_shift_type3, d2pc_in_shift_type2, d2pc_in_shift_type1, d2pc_in_shift_type0;
  wire [5:0] d2pc_in_shift_amount3, d2pc_in_shift_amount2, d2pc_in_shift_amount1, d2pc_in_shift_amount0;
  wire [8:0] d2pc_in_execute_opcode3, d2pc_in_execute_opcode2, d2pc_in_execute_opcode1, d2pc_in_execute_opcode0;
  wire d2pc_in_invalid3, d2pc_in_invalid2, d2pc_in_invalid1, d2pc_in_invalid0;
  wire [27:0] d2pc_in_virtpc /* verilator public */;
  wire d2pc_in_inst_pf;
  wire [4:0] d2pc_in_rs_num0;
  wire d2pc_out_invalid3;

  wire [31:0] wb2rf_rd_data3, wb2rf_rd_data2, wb2rf_rd_data1, wb2rf_rd_data0 /* verilator public */;
  wire [4:0] wb2rf_rd_num3, wb2rf_rd_num2, wb2rf_rd_num1, wb2rf_rd_num0 /* verilator public */;
  wire wb2rf_rd_we3, wb2rf_rd_we2, wb2rf_rd_we1, wb2rf_rd_we0 /* verilator public */;
  wire wb2rf_pred_we3, wb2rf_pred_we2, wb2rf_pred_we1, wb2rf_pred_we0 /* verilator public */;

  //stage status signals
  wire f_valid /* verilator public */, dcd_valid /* verilator public */, pc_valid /* verilator public */, wb_valid /* verilator public */;
  wire ft2f_readyout, ft2f_readyin, f2d_readyout, f2d_readyin;
  wire d2pc_readyout, d2pc_readyin, pc2wb_readyout, pc2wb_readyin;
  wire ft2f_progress, f2d_progress, d2pc_progress, pc2wb_progress;

  wire ft2f_done, f2d_done;


  assign ft2f_readyin = ~f_valid | f2d_progress;
  assign ft2f_readyout = ft2f_done;
  assign ft2f_progress = ft2f_readyin & ft2f_readyout;

  assign f2d_readyin = ~dcd_valid | (d2pc_progress & ~dcd_depstall);
  assign f2d_readyout = ~f_valid | f2d_done;
  assign f2d_progress = f2d_readyout & f2d_readyin;

  assign d2pc_readyin = ~pc_valid | pc2wb_progress;
  assign d2pc_readyout = 1;
  assign d2pc_progress = d2pc_readyin & d2pc_readyout;

  assign pc2wb_readyout = 1; // this will get more complicated later
  assign pc2wb_readyin = 1; // this will also change as we add functional units after commit
  assign pc2wb_progress = pc2wb_readyout & pc2wb_readyin;

  `include "oper_type.vh"

  //unimplemented control inputs
  wire pipe_flush, exception /* verilator public */, paging_on;
  wire [27:0] pc2ft_newpc;
  assign pipe_flush = pc_valid & ((d2pc_in_oper_type0 == OPER_TYPE_BRANCH) | coproc_branch);
  assign paging_on = 0;

  wire [27:0] branch_newpc = d2pc_in_sop0[27:0] +
              (d2pc_in_branchreg ? d2pc_in_rs_data0[31:4] : d2pc_in_virtpc);
  assign pc2ft_newpc = coproc_branch ? coproc_branchaddr : branch_newpc;



  MCPU_CORE_regfile regs(/*AUTOINST*/
			 // Outputs
			 .rf2d_rs_data0		(rf2d_rs_data0[31:0]),
			 .rf2d_rs_data1		(rf2d_rs_data1[31:0]),
			 .rf2d_rs_data2		(rf2d_rs_data2[31:0]),
			 .rf2d_rs_data3		(rf2d_rs_data3[31:0]),
			 .rf2d_rt_data0		(rf2d_rt_data0[31:0]),
			 .rf2d_rt_data1		(rf2d_rt_data1[31:0]),
			 .rf2d_rt_data2		(rf2d_rt_data2[31:0]),
			 .rf2d_rt_data3		(rf2d_rt_data3[31:0]),
			 .preds			(preds[2:0]),
			 // Inputs
			 .wb2rf_rd_num0		(wb2rf_rd_num0[4:0]),
			 .wb2rf_rd_num1		(wb2rf_rd_num1[4:0]),
			 .wb2rf_rd_num2		(wb2rf_rd_num2[4:0]),
			 .wb2rf_rd_num3		(wb2rf_rd_num3[4:0]),
			 .d2rf_rs_num0		(d2rf_rs_num0[4:0]),
			 .d2rf_rs_num1		(d2rf_rs_num1[4:0]),
			 .d2rf_rs_num2		(d2rf_rs_num2[4:0]),
			 .d2rf_rs_num3		(d2rf_rs_num3[4:0]),
			 .d2rf_rt_num0		(d2rf_rt_num0[4:0]),
			 .d2rf_rt_num1		(d2rf_rt_num1[4:0]),
			 .d2rf_rt_num2		(d2rf_rt_num2[4:0]),
			 .d2rf_rt_num3		(d2rf_rt_num3[4:0]),
			 .wb2rf_rd_data0	(wb2rf_rd_data0[31:0]),
			 .wb2rf_rd_data1	(wb2rf_rd_data1[31:0]),
			 .wb2rf_rd_data2	(wb2rf_rd_data2[31:0]),
			 .wb2rf_rd_data3	(wb2rf_rd_data3[31:0]),
			 .wb2rf_rd_we3		(wb2rf_rd_we3),
			 .wb2rf_rd_we2		(wb2rf_rd_we2),
			 .wb2rf_rd_we1		(wb2rf_rd_we1),
			 .wb2rf_rd_we0		(wb2rf_rd_we0),
			 .wb2rf_pred_we3	(wb2rf_pred_we3),
			 .wb2rf_pred_we2	(wb2rf_pred_we2),
			 .wb2rf_pred_we1	(wb2rf_pred_we1),
			 .wb2rf_pred_we0	(wb2rf_pred_we0),
			 .clkrst_core_clk	(clkrst_core_clk),
			 .clkrst_core_rst_n	(clkrst_core_rst_n));

  MCPU_CORE_scoreboard sb(
        .d2pc_progress(d2pc_progress & dcd_valid & ~pipe_flush & ~dcd_depstall),
        /*AUTOINST*/
			  // Outputs
			  .sb2d_reg_scoreboard	(sb2d_reg_scoreboard[31:0]),
			  .sb2d_pred_scoreboard	(sb2d_pred_scoreboard[2:0]),
			  // Inputs
			  .clkrst_core_clk	(clkrst_core_clk),
			  .clkrst_core_rst_n	(clkrst_core_rst_n),
			  .wb2rf_rd_num0	(wb2rf_rd_num0[4:0]),
			  .wb2rf_rd_num1	(wb2rf_rd_num1[4:0]),
			  .wb2rf_rd_num2	(wb2rf_rd_num2[4:0]),
			  .wb2rf_rd_num3	(wb2rf_rd_num3[4:0]),
			  .wb2rf_rd_we0		(wb2rf_rd_we0),
			  .wb2rf_rd_we1		(wb2rf_rd_we1),
			  .wb2rf_rd_we2		(wb2rf_rd_we2),
			  .wb2rf_rd_we3		(wb2rf_rd_we3),
			  .wb2rf_pred_we0	(wb2rf_pred_we0),
			  .wb2rf_pred_we1	(wb2rf_pred_we1),
			  .wb2rf_pred_we2	(wb2rf_pred_we2),
			  .wb2rf_pred_we3	(wb2rf_pred_we3),
			  .d2pc_out_rd_num0	(d2pc_out_rd_num0[4:0]),
			  .d2pc_out_rd_num1	(d2pc_out_rd_num1[4:0]),
			  .d2pc_out_rd_num2	(d2pc_out_rd_num2[4:0]),
			  .d2pc_out_rd_num3	(d2pc_out_rd_num3[4:0]),
			  .d2pc_out_rd_we0	(d2pc_out_rd_we0),
			  .d2pc_out_rd_we1	(d2pc_out_rd_we1),
			  .d2pc_out_rd_we2	(d2pc_out_rd_we2),
			  .d2pc_out_rd_we3	(d2pc_out_rd_we3),
			  .d2pc_out_pred_we0	(d2pc_out_pred_we0),
			  .d2pc_out_pred_we1	(d2pc_out_pred_we1),
			  .d2pc_out_pred_we2	(d2pc_out_pred_we2),
			  .d2pc_out_pred_we3	(d2pc_out_pred_we3),
			  .exception		(exception),
			  .pipe_flush		(pipe_flush));

  /* Pipeline! */
  MCPU_CORE_stage_fetchtlb ft(/*AUTOINST*/
			      // Outputs
			      .ft2f_done	(ft2f_done),
			      .ft2f_out_physpage(ft2f_out_physpage[19:0]),
			      .ft2f_out_virtpc	(ft2f_out_virtpc[27:0]),
			      .ft2f_out_inst_pf	(ft2f_out_inst_pf),
			      .ft2itlb_valid	(ft2itlb_valid),
			      .ft2itlb_virtpage	(ft2itlb_virtpage[19:0]),
			      // Inputs
			      .clkrst_core_clk	(clkrst_core_clk),
			      .clkrst_core_rst_n(clkrst_core_rst_n),
			      .ft2f_progress	(ft2f_progress),
			      .pipe_flush	(pipe_flush),
			      .pc2ft_newpc	(pc2ft_newpc[27:0]),
			      .paging_on	(paging_on),
			      .ft2itlb_ready	(ft2itlb_ready),
			      .ft2itlb_physpage	(ft2itlb_physpage[19:0]),
			      .ft2itlb_pagefault(ft2itlb_pagefault));

  register #(.WIDTH(50), .RESET_VAL(50'd0))
           ft2f_reg(.D({ft2f_out_physpage, ft2f_out_virtpc, ft2f_progress & ~pipe_flush, ft2f_out_inst_pf}),
                    .Q({ft2f_in_physpage, ft2f_in_virtpc, f_valid, ft2f_in_inst_pf}),
                    .en(ft2f_progress),
                    /*AUTOINST*/
		    // Inputs
		    .clkrst_core_clk	(clkrst_core_clk),
		    .clkrst_core_rst_n	(clkrst_core_rst_n));

  MCPU_CORE_stage_fetch f(/*AUTOINST*/
			  // Outputs
			  .f2d_done		(f2d_done),
			  .f2d_out_packet	(f2d_out_packet[127:0]),
			  .f2d_out_virtpc	(f2d_out_virtpc[27:0]),
			  .f2ic_paddr		(f2ic_paddr[27:0]),
			  .f2ic_valid		(f2ic_valid),
			  // Inputs
			  .clkrst_core_clk	(clkrst_core_clk),
			  .clkrst_core_rst_n	(clkrst_core_rst_n),
			  .f_valid		(f_valid),
			  .ft2f_progress	(ft2f_progress),
			  .ft2f_in_physpage	(ft2f_in_physpage[19:0]),
			  .ft2f_in_virtpc	(ft2f_in_virtpc[27:0]),
			  .pipe_flush		(pipe_flush),
			  .ic2f_packet		(ic2f_packet[127:0]),
			  .ic2f_ready		(ic2f_ready));

  register #(.WIDTH(158), .RESET_VAL(158'd0))
           f2d_reg(.D({f2d_out_packet, f2d_out_virtpc, f2d_progress & f_valid & ~pipe_flush, ft2f_in_inst_pf}),
                   .Q({f2d_in_packet, f2d_in_virtpc, dcd_valid, f2d_in_inst_pf}),
                   .en(f2d_progress),
                   /*AUTOINST*/
		   // Inputs
		   .clkrst_core_clk	(clkrst_core_clk),
		   .clkrst_core_rst_n	(clkrst_core_rst_n));


  /* MCPU_CORE_decode AUTO_TEMPLATE(
    .rf2d_rs_data(rf2d_rs_data@[]),
    .rf2d_rt_data(rf2d_rt_data@[]),
    .d2pc_out_execute_opcode(d2pc_out_execute_opcode@[]),
    .d2pc_out_shift_type(d2pc_out_shift_type@[]),
    .d2pc_out_shift_amount(d2pc_out_shift_amount@[]),
    .d2pc_out_oper_type(d2pc_out_oper_type@[]),
    .d2pc_out_rd_num(d2pc_out_rd_num@[]),
    .d2pc_out_rd_we(d2pc_out_rd_we@[]),
    .d2pc_out_pred_we(d2pc_out_pred_we@[]),
    .d2rf_rs_num(d2rf_rs_num@[]),
    .d2rf_rt_num(d2rf_rt_num@[]),
    .d2pc_out_sop(d2pc_out_sop@[]),
    .d2pc_out_lsu_offset(d2pc_out_lsu_offset@[]),
    .dep_stall(dep_stall@[]),
    .long_imm(long_imm@[]),
    .d2pc_out_invalid(d2pc_out_invalid@[]),
    .d2pc_out_branchreg(d2pc_out_branchreg@[]),
  );*/


  wire long_imm0, long_imm1, long_imm2, long_imm3;
  MCPU_CORE_decode d0(
      .inst(f2d_in_packet[31:0]),
      .nextinst(f2d_in_packet[63:32]),
      .prev_long_imm(1'b0),
      /*AUTOINST*/
		      // Outputs
		      .d2pc_out_execute_opcode(d2pc_out_execute_opcode0[8:0]), // Templated
		      .d2pc_out_shift_type(d2pc_out_shift_type0[1:0]), // Templated
		      .d2pc_out_shift_amount(d2pc_out_shift_amount0[5:0]), // Templated
		      .d2pc_out_oper_type(d2pc_out_oper_type0[1:0]), // Templated
		      .d2pc_out_rd_num	(d2pc_out_rd_num0[4:0]), // Templated
		      .d2pc_out_rd_we	(d2pc_out_rd_we0),	 // Templated
		      .d2pc_out_pred_we	(d2pc_out_pred_we0),	 // Templated
		      .d2rf_rs_num	(d2rf_rs_num0[4:0]),	 // Templated
		      .d2rf_rt_num	(d2rf_rt_num0[4:0]),	 // Templated
		      .d2pc_out_sop	(d2pc_out_sop0[31:0]),	 // Templated
		      .d2pc_out_lsu_offset(d2pc_out_lsu_offset0[11:0]), // Templated
		      .dep_stall	(dep_stall0),		 // Templated
		      .long_imm		(long_imm0),		 // Templated
		      .d2pc_out_invalid	(d2pc_out_invalid0),	 // Templated
		      .d2pc_out_branchreg(d2pc_out_branchreg0),	 // Templated
		      // Inputs
		      .preds		(preds[2:0]),
		      .sb2d_reg_scoreboard(sb2d_reg_scoreboard[31:0]),
		      .sb2d_pred_scoreboard(sb2d_pred_scoreboard[2:0]),
		      .rf2d_rs_data	(rf2d_rs_data0[31:0]),	 // Templated
		      .rf2d_rt_data	(rf2d_rt_data0[31:0]));	 // Templated

  MCPU_CORE_decode d1(
      .inst(f2d_in_packet[63:32]),
      .nextinst(f2d_in_packet[95:64]),
      .prev_long_imm(long_imm0),
      /*AUTOINST*/
		      // Outputs
		      .d2pc_out_execute_opcode(d2pc_out_execute_opcode1[8:0]), // Templated
		      .d2pc_out_shift_type(d2pc_out_shift_type1[1:0]), // Templated
		      .d2pc_out_shift_amount(d2pc_out_shift_amount1[5:0]), // Templated
		      .d2pc_out_oper_type(d2pc_out_oper_type1[1:0]), // Templated
		      .d2pc_out_rd_num	(d2pc_out_rd_num1[4:0]), // Templated
		      .d2pc_out_rd_we	(d2pc_out_rd_we1),	 // Templated
		      .d2pc_out_pred_we	(d2pc_out_pred_we1),	 // Templated
		      .d2rf_rs_num	(d2rf_rs_num1[4:0]),	 // Templated
		      .d2rf_rt_num	(d2rf_rt_num1[4:0]),	 // Templated
		      .d2pc_out_sop	(d2pc_out_sop1[31:0]),	 // Templated
		      .d2pc_out_lsu_offset(d2pc_out_lsu_offset1[11:0]), // Templated
		      .dep_stall	(dep_stall1),		 // Templated
		      .long_imm		(long_imm1),		 // Templated
		      .d2pc_out_invalid	(d2pc_out_invalid1),	 // Templated
		      .d2pc_out_branchreg(d2pc_out_branchreg1),	 // Templated
		      // Inputs
		      .preds		(preds[2:0]),
		      .sb2d_reg_scoreboard(sb2d_reg_scoreboard[31:0]),
		      .sb2d_pred_scoreboard(sb2d_pred_scoreboard[2:0]),
		      .rf2d_rs_data	(rf2d_rs_data1[31:0]),	 // Templated
		      .rf2d_rt_data	(rf2d_rt_data1[31:0]));	 // Templated

  MCPU_CORE_decode d2(
      .inst(f2d_in_packet[95:64]),
      .nextinst(f2d_in_packet[127:96]),
      .prev_long_imm(long_imm1),
      /*AUTOINST*/
		      // Outputs
		      .d2pc_out_execute_opcode(d2pc_out_execute_opcode2[8:0]), // Templated
		      .d2pc_out_shift_type(d2pc_out_shift_type2[1:0]), // Templated
		      .d2pc_out_shift_amount(d2pc_out_shift_amount2[5:0]), // Templated
		      .d2pc_out_oper_type(d2pc_out_oper_type2[1:0]), // Templated
		      .d2pc_out_rd_num	(d2pc_out_rd_num2[4:0]), // Templated
		      .d2pc_out_rd_we	(d2pc_out_rd_we2),	 // Templated
		      .d2pc_out_pred_we	(d2pc_out_pred_we2),	 // Templated
		      .d2rf_rs_num	(d2rf_rs_num2[4:0]),	 // Templated
		      .d2rf_rt_num	(d2rf_rt_num2[4:0]),	 // Templated
		      .d2pc_out_sop	(d2pc_out_sop2[31:0]),	 // Templated
		      .d2pc_out_lsu_offset(d2pc_out_lsu_offset2[11:0]), // Templated
		      .dep_stall	(dep_stall2),		 // Templated
		      .long_imm		(long_imm2),		 // Templated
		      .d2pc_out_invalid	(d2pc_out_invalid2),	 // Templated
		      .d2pc_out_branchreg(d2pc_out_branchreg2),	 // Templated
		      // Inputs
		      .preds		(preds[2:0]),
		      .sb2d_reg_scoreboard(sb2d_reg_scoreboard[31:0]),
		      .sb2d_pred_scoreboard(sb2d_pred_scoreboard[2:0]),
		      .rf2d_rs_data	(rf2d_rs_data2[31:0]),	 // Templated
		      .rf2d_rt_data	(rf2d_rt_data2[31:0]));	 // Templated

  wire dcd_invalid3;
  MCPU_CORE_decode d3(
      .inst(f2d_in_packet[127:96]),
      .nextinst('bx),
      .prev_long_imm(long_imm2),
      .d2pc_out_invalid(dcd_invalid3),
      /*AUTOINST*/
		      // Outputs
		      .d2pc_out_execute_opcode(d2pc_out_execute_opcode3[8:0]), // Templated
		      .d2pc_out_shift_type(d2pc_out_shift_type3[1:0]), // Templated
		      .d2pc_out_shift_amount(d2pc_out_shift_amount3[5:0]), // Templated
		      .d2pc_out_oper_type(d2pc_out_oper_type3[1:0]), // Templated
		      .d2pc_out_rd_num	(d2pc_out_rd_num3[4:0]), // Templated
		      .d2pc_out_rd_we	(d2pc_out_rd_we3),	 // Templated
		      .d2pc_out_pred_we	(d2pc_out_pred_we3),	 // Templated
		      .d2rf_rs_num	(d2rf_rs_num3[4:0]),	 // Templated
		      .d2rf_rt_num	(d2rf_rt_num3[4:0]),	 // Templated
		      .d2pc_out_sop	(d2pc_out_sop3[31:0]),	 // Templated
		      .d2pc_out_lsu_offset(d2pc_out_lsu_offset3[11:0]), // Templated
		      .dep_stall	(dep_stall3),		 // Templated
		      .long_imm		(long_imm3),		 // Templated
		      .d2pc_out_branchreg(d2pc_out_branchreg3),	 // Templated
		      // Inputs
		      .preds		(preds[2:0]),
		      .sb2d_reg_scoreboard(sb2d_reg_scoreboard[31:0]),
		      .sb2d_pred_scoreboard(sb2d_pred_scoreboard[2:0]),
		      .rf2d_rs_data	(rf2d_rs_data3[31:0]),	 // Templated
		      .rf2d_rt_data	(rf2d_rt_data3[31:0]));	 // Templated

  assign d2pc_out_invalid3 = dcd_invalid3 | long_imm3;
  wire dcd_depstall;
  assign dcd_depstall = dep_stall0 | dep_stall1 | dep_stall2 | dep_stall3;


  // this is going to get even bigger when we add bits for non-ALU instruction types.
  register #(.WIDTH(400), .RESET_VAL(400'd0)) // wheeeeeeeee
    d2pc_reg(
      .D({d2pc_out_sop3, d2pc_out_sop2, d2pc_out_sop1, d2pc_out_sop0,
          rf2d_rs_data3, rf2d_rs_data2, rf2d_rs_data1, rf2d_rs_data0,
          d2pc_out_rd_we3, d2pc_out_rd_we2, d2pc_out_rd_we1, d2pc_out_rd_we0,
          d2pc_out_pred_we3, d2pc_out_pred_we2, d2pc_out_pred_we1, d2pc_out_pred_we0,
          d2pc_out_rd_num3, d2pc_out_rd_num2, d2pc_out_rd_num1, d2pc_out_rd_num0,
          d2pc_out_oper_type3, d2pc_out_oper_type2, d2pc_out_oper_type1, d2pc_out_oper_type0,
          d2pc_out_shift_type3, d2pc_out_shift_type2, d2pc_out_shift_type1, d2pc_out_shift_type0,
          d2pc_out_shift_amount3, d2pc_out_shift_amount2, d2pc_out_shift_amount1, d2pc_out_shift_amount0,
          d2pc_out_execute_opcode3, d2pc_out_execute_opcode2, d2pc_out_execute_opcode1, d2pc_out_execute_opcode0,
          d2pc_out_invalid3, d2pc_out_invalid2, d2pc_out_invalid1, d2pc_out_invalid0,
          d2pc_progress & dcd_valid & ~pipe_flush & ~dcd_depstall,
          d2pc_out_branchreg0,
          f2d_in_virtpc,
          f2d_in_inst_pf,
          d2rf_rs_num0
        }),
      .Q({
          d2pc_in_sop3, d2pc_in_sop2, d2pc_in_sop1, d2pc_in_sop0,
          d2pc_in_rs_data3, d2pc_in_rs_data2, d2pc_in_rs_data1, d2pc_in_rs_data0,
          d2pc_in_rd_we3, d2pc_in_rd_we2, d2pc_in_rd_we1, d2pc_in_rd_we0,
          d2pc_in_pred_we3, d2pc_in_pred_we2, d2pc_in_pred_we1, d2pc_in_pred_we0,
          d2pc_in_rd_num3, d2pc_in_rd_num2, d2pc_in_rd_num1, d2pc_in_rd_num0,
          d2pc_in_oper_type3, d2pc_in_oper_type2, d2pc_in_oper_type1, d2pc_in_oper_type0,
          d2pc_in_shift_type3, d2pc_in_shift_type2, d2pc_in_shift_type1, d2pc_in_shift_type0,
          d2pc_in_shift_amount3, d2pc_in_shift_amount2, d2pc_in_shift_amount1, d2pc_in_shift_amount0,
          d2pc_in_execute_opcode3, d2pc_in_execute_opcode2, d2pc_in_execute_opcode1, d2pc_in_execute_opcode0,
          d2pc_in_invalid3, d2pc_in_invalid2, d2pc_in_invalid1, d2pc_in_invalid0,
          pc_valid,
          d2pc_in_branchreg,
          d2pc_in_virtpc,
          d2pc_in_inst_pf,
          d2pc_in_rs_num0
        }),
        .en(d2pc_progress),
        /*AUTOINST*/
	     // Inputs
	     .clkrst_core_clk		(clkrst_core_clk),
	     .clkrst_core_rst_n		(clkrst_core_rst_n));


  /* MCPU_CORE_alu AUTO_TEMPLATE(
    .d2pc_in_rs_data(d2pc_in_rs_data@[]),
    .d2pc_in_sop(d2pc_in_sop@[]),
    .d2pc_in_execute_opcode(d2pc_in_execute_opcode@[]),
    .compare_type(d2pc_in_rd_num@[4:2]),
    .d2pc_in_shift_type(d2pc_in_shift_type@[]),
    .d2pc_in_shift_amount(d2pc_in_shift_amount@[]),
    .pc2wb_out_result(pc2wb_out_result@[]),
    .pc_alu_invalid(pc_alu_invalid@[]),
  );*/

  wire [31:0] alu_result0;
  wire [31:0] pc2wb_out_result0;
  /* AUTO_CONSTANT ( OPER_TYPE_BRANCH ) */
  /* AUTO_CONSTANT ( OPER_TYPE_OTHER ) */
  wire pc2wb_out_rd_we0;
  always @(/*AUTOSENSE*/alu_result0 or coproc_rd_we
	   or coproc_reg_result or d2pc_in_oper_type0
	   or d2pc_in_rd_we0 or d2pc_in_virtpc) begin
    pc2wb_out_rd_we0 = d2pc_in_rd_we0;
    case(d2pc_in_oper_type0)
      OPER_TYPE_BRANCH: pc2wb_out_result0 = {d2pc_in_virtpc, 4'b0};
      OPER_TYPE_OTHER: begin
        pc2wb_out_result0 = coproc_reg_result;
        pc2wb_out_rd_we0 = coproc_rd_we;
      end
      default: pc2wb_out_result0 = alu_result0;
    endcase
  end

  MCPU_CORE_alu alu0(
         .pc2wb_out_result(alu_result0[31:0]),
         /*AUTOINST*/
		     // Outputs
		     .pc_alu_invalid	(pc_alu_invalid0),	 // Templated
		     // Inputs
		     .d2pc_in_rs_data	(d2pc_in_rs_data0[31:0]), // Templated
		     .d2pc_in_sop	(d2pc_in_sop0[31:0]),	 // Templated
		     .d2pc_in_execute_opcode(d2pc_in_execute_opcode0[3:0]), // Templated
		     .compare_type	(d2pc_in_rd_num0[4:2]),	 // Templated
		     .d2pc_in_shift_type(d2pc_in_shift_type0[1:0]), // Templated
		     .d2pc_in_shift_amount(d2pc_in_shift_amount0[5:0])); // Templated

  MCPU_CORE_alu alu1(/*AUTOINST*/
		     // Outputs
		     .pc2wb_out_result	(pc2wb_out_result1[31:0]), // Templated
		     .pc_alu_invalid	(pc_alu_invalid1),	 // Templated
		     // Inputs
		     .d2pc_in_rs_data	(d2pc_in_rs_data1[31:0]), // Templated
		     .d2pc_in_sop	(d2pc_in_sop1[31:0]),	 // Templated
		     .d2pc_in_execute_opcode(d2pc_in_execute_opcode1[3:0]), // Templated
		     .compare_type	(d2pc_in_rd_num1[4:2]),	 // Templated
		     .d2pc_in_shift_type(d2pc_in_shift_type1[1:0]), // Templated
		     .d2pc_in_shift_amount(d2pc_in_shift_amount1[5:0])); // Templated

  MCPU_CORE_alu alu2(/*AUTOINST*/
		     // Outputs
		     .pc2wb_out_result	(pc2wb_out_result2[31:0]), // Templated
		     .pc_alu_invalid	(pc_alu_invalid2),	 // Templated
		     // Inputs
		     .d2pc_in_rs_data	(d2pc_in_rs_data2[31:0]), // Templated
		     .d2pc_in_sop	(d2pc_in_sop2[31:0]),	 // Templated
		     .d2pc_in_execute_opcode(d2pc_in_execute_opcode2[3:0]), // Templated
		     .compare_type	(d2pc_in_rd_num2[4:2]),	 // Templated
		     .d2pc_in_shift_type(d2pc_in_shift_type2[1:0]), // Templated
		     .d2pc_in_shift_amount(d2pc_in_shift_amount2[5:0])); // Templated

  MCPU_CORE_alu alu3(/*AUTOINST*/
		     // Outputs
		     .pc2wb_out_result	(pc2wb_out_result3[31:0]), // Templated
		     .pc_alu_invalid	(pc_alu_invalid3),	 // Templated
		     // Inputs
		     .d2pc_in_rs_data	(d2pc_in_rs_data3[31:0]), // Templated
		     .d2pc_in_sop	(d2pc_in_sop3[31:0]),	 // Templated
		     .d2pc_in_execute_opcode(d2pc_in_execute_opcode3[3:0]), // Templated
		     .compare_type	(d2pc_in_rd_num3[4:2]),	 // Templated
		     .d2pc_in_shift_type(d2pc_in_shift_type3[1:0]), // Templated
		     .d2pc_in_shift_amount(d2pc_in_shift_amount3[5:0])); // Templated

  wire pc_dup_rd = (d2pc_in_rd_we0 & d2pc_in_rd_we1 & (d2pc_in_rd_num0 == d2pc_in_rd_num1)) |
                   (d2pc_in_rd_we0 & d2pc_in_rd_we2 & (d2pc_in_rd_num0 == d2pc_in_rd_num2)) |
                   (d2pc_in_rd_we0 & d2pc_in_rd_we3 & (d2pc_in_rd_num0 == d2pc_in_rd_num3)) |
                   (d2pc_in_rd_we1 & d2pc_in_rd_we2 & (d2pc_in_rd_num1 == d2pc_in_rd_num2)) |
                   (d2pc_in_rd_we1 & d2pc_in_rd_we3 & (d2pc_in_rd_num1 == d2pc_in_rd_num3)) |
                   (d2pc_in_rd_we2 & d2pc_in_rd_we3 & (d2pc_in_rd_num2 == d2pc_in_rd_num3));

  wire pc_dup_pred = (d2pc_in_pred_we0 & d2pc_in_pred_we1 & (d2pc_in_rd_num0[1:0] == d2pc_in_rd_num1[1:0])) |
                   (d2pc_in_pred_we0 & d2pc_in_pred_we2 & (d2pc_in_rd_num0[1:0] == d2pc_in_rd_num2[1:0])) |
                   (d2pc_in_pred_we0 & d2pc_in_pred_we3 & (d2pc_in_rd_num0[1:0] == d2pc_in_rd_num3[1:0])) |
                   (d2pc_in_pred_we1 & d2pc_in_pred_we2 & (d2pc_in_rd_num1[1:0] == d2pc_in_rd_num2[1:0])) |
                   (d2pc_in_pred_we1 & d2pc_in_pred_we3 & (d2pc_in_rd_num1[1:0] == d2pc_in_rd_num3[1:0])) |
                   (d2pc_in_pred_we2 & d2pc_in_pred_we3 & (d2pc_in_rd_num2[1:0] == d2pc_in_rd_num3[1:0]));

  wire pc_dup_dest = pc_dup_rd | pc_dup_pred;
  wire pc_data_pf0 = 0;
  wire pc_data_pf1 = 0;
  wire pc_div_zero = 0;

  wire pc_syscall = (d2pc_in_oper_type0 == OPER_TYPE_OTHER) & (d2pc_in_execute_opcode0[8:5] == 4'b0010);
  wire pc_break = (d2pc_in_oper_type0 == OPER_TYPE_OTHER) & (d2pc_in_execute_opcode0[8:5] == 4'b0001);

  MCPU_CORE_exn_encode exn_encode(/*AUTOINST*/
				  // Outputs
				  .combined_ec0		(combined_ec0[4:0]),
				  .combined_ec1		(combined_ec1[4:0]),
				  .combined_ec2		(combined_ec2[4:0]),
				  .combined_ec3		(combined_ec3[4:0]),
				  .exception		(exception),
				  // Inputs
				  .d2pc_in_inst_pf	(d2pc_in_inst_pf),
				  .d2pc_in_invalid0	(d2pc_in_invalid0),
				  .d2pc_in_invalid1	(d2pc_in_invalid1),
				  .d2pc_in_invalid2	(d2pc_in_invalid2),
				  .d2pc_in_invalid3	(d2pc_in_invalid3),
				  .pc_dup_dest		(pc_dup_dest),
				  .pc_data_pf0		(pc_data_pf0),
				  .pc_data_pf1		(pc_data_pf1),
				  .pc_div_zero		(pc_div_zero),
				  .int_pending		(int_pending),
				  .pc_syscall		(pc_syscall),
				  .pc_break		(pc_break),
				  .interrupts_enabled	(interrupts_enabled),
				  .pc_valid		(pc_valid));

  MCPU_CORE_coproc coproc(
			  .coproc_instruction	(pc_valid & (d2pc_in_oper_type0 == OPER_TYPE_OTHER)),
			  .mem_vaddr0		(0),
			  .mem_vaddr1		(0), //TODO connect these
        /*AUTOINST*/
			  // Outputs
			  .coproc_reg_result	(coproc_reg_result[31:0]),
			  .coproc_rd_we		(coproc_rd_we),
			  .user_mode		(user_mode),
			  .paging_on		(paging_on),
			  .interrupts_enabled	(interrupts_enabled),
			  .coproc_branchaddr	(coproc_branchaddr[27:0]),
			  .coproc_branch	(coproc_branch),
			  // Inputs
			  .clkrst_core_clk	(clkrst_core_clk),
			  .clkrst_core_rst_n	(clkrst_core_rst_n),
			  .d2pc_in_rs_data0	(d2pc_in_rs_data0[31:0]),
			  .d2pc_in_sop0		(d2pc_in_sop0[31:0]),
			  .d2pc_in_rs_num0	(d2pc_in_rs_num0[4:0]),
			  .d2pc_in_rd_num0	(d2pc_in_rd_num0[4:0]),
			  .d2pc_in_execute_opcode0(d2pc_in_execute_opcode0[8:0]),
			  .combined_ec0		(combined_ec0[4:0]),
			  .combined_ec1		(combined_ec1[4:0]),
			  .combined_ec2		(combined_ec2[4:0]),
			  .combined_ec3		(combined_ec3[4:0]),
			  .int_type		(int_type[3:0]),
			  .exception		(exception),
			  .d2pc_in_virtpc	(d2pc_in_virtpc[27:0]));


  assign pc2wb_readyin = 1;
  assign pc2wb_readyout = pc_valid & ~exception; // for now, PC always takes one cycle

  wire [27:0] pc2wb_in_virtpc0 /* verilator public */;
  wire [27:0] pc2wb_in_virtpc1 /* verilator public */;
  wire [27:0] pc2wb_in_virtpc2 /* verilator public */;
  wire [27:0] pc2wb_in_virtpc3 /* verilator public */;
  wire pc2wb_in_rd_we0, pc2wb_in_rd_we1, pc2wb_in_rd_we2, pc2wb_in_rd_we3;
  wire pc2wb_in_pred_we0, pc2wb_in_pred_we1, pc2wb_in_pred_we2, pc2wb_in_pred_we3;


  register #(.WIDTH(269), .RESET_VAL(269'b0)) pc2wb_reg(
    .D({
      pc2wb_out_result3, pc2wb_out_result2, pc2wb_out_result1, pc2wb_out_result0,
      d2pc_in_rd_num3, d2pc_in_rd_num2, d2pc_in_rd_num1, d2pc_in_rd_num0,
      d2pc_in_rd_we3, d2pc_in_rd_we2, d2pc_in_rd_we1, pc2wb_out_rd_we0,
      d2pc_in_pred_we3, d2pc_in_pred_we2, d2pc_in_pred_we1, d2pc_in_pred_we0,
      pc2wb_progress & pc_valid,
      d2pc_in_virtpc, d2pc_in_virtpc, d2pc_in_virtpc, d2pc_in_virtpc
    }),
    .Q({
      wb2rf_rd_data3, wb2rf_rd_data2, wb2rf_rd_data1, wb2rf_rd_data0,
      wb2rf_rd_num3, wb2rf_rd_num2, wb2rf_rd_num1, wb2rf_rd_num0,
      pc2wb_in_rd_we3, pc2wb_in_rd_we2, pc2wb_in_rd_we1, pc2wb_in_rd_we0, 
      pc2wb_in_pred_we3, pc2wb_in_pred_we2, pc2wb_in_pred_we1, pc2wb_in_pred_we0, 
      wb_valid,
      pc2wb_in_virtpc0, pc2wb_in_virtpc1, pc2wb_in_virtpc2, pc2wb_in_virtpc3
    }),
    .en(pc2wb_progress),
    /*AUTOINST*/
							// Inputs
							.clkrst_core_clk(clkrst_core_clk),
							.clkrst_core_rst_n(clkrst_core_rst_n));
      
  assign wb2rf_rd_we0 = pc2wb_in_rd_we0 & wb_valid;
  assign wb2rf_rd_we1 = pc2wb_in_rd_we1 & wb_valid;
  assign wb2rf_rd_we2 = pc2wb_in_rd_we2 & wb_valid;
  assign wb2rf_rd_we3 = pc2wb_in_rd_we3 & wb_valid;

  assign wb2rf_pred_we0 = pc2wb_in_pred_we0 & wb_valid;
  assign wb2rf_pred_we1 = pc2wb_in_pred_we1 & wb_valid;
  assign wb2rf_pred_we2 = pc2wb_in_pred_we2 & wb_valid;
  assign wb2rf_pred_we3 = pc2wb_in_pred_we3 & wb_valid;
  //writeback stage doesn't actually have any logic yet, just scoreboard and regfile connections.
  //There will need to be arbitration for multiple register writes on a lane arriving in the same cycle.

endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// End:
