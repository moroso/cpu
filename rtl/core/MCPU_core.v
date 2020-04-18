/*
 Let's say we have a pipeline stage S, and that the previous stage is P
 and the next stage is N. Then we'll have these signals:

 S_valid_in: whether the S_*_in signals are valid (if not, this cycle
             is just a bubble).
 S_ready_in: whether S is ready for its next data. The inputs to S must
             not change when readyin is low, and readyin must always be
             high when valid_in is high.
 S_valid_out: whether the output from this stage is valid, and ready to
              be passed on to the next stage. For stages occuring entirely
              between two clock edges (rather than spanning one), this
              will be the same as S_valid_in. For other stages (e.g.
              memory) which span a clock edge, this will generally be a
              combination of the previous valid_in signal and the cache's
              readyout signal (and will be wired directly to N_valid_in).
 S_ready_out: whether outputs for this stage have settled with the current
              inputs (that is, the stage is not busy.)
 S_out_ok: Whether the stage *after* S is ready to receive data (N_ready_in).

 For stages (like decode) that happen between clocks, there's a register between
 it and the next stage, clocked on ready_in.

 For things like memory stages, some values will go through a register clocked
 on ready_in, but other values (cache result, cache ready) will be combined into
 the ready_out signal, and *not* go through the register. The cache's read/write
 enable signal will depend in the next stage's ready_in.
 */

module MCPU_core(/*AUTOARG*/
   // Outputs
   int_clear, mem2dc_paddr0, mem2dc_write0, mem2dc_valid0,
   mem2dc_data_out0, mem2dc_paddr1, mem2dc_write1, mem2dc_valid1,
   mem2dc_data_out1, dispatch, f2ic_vaddr, f2ic_valid, dtlb_addr0,
   dtlb_addr1, dtlb_re0, dtlb_re1, dtlb_is_write0, dtlb_is_write1,
   paging_on, pagedir_base, user_mode, r0,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, int_pending, int_type,
   mem2dc_done0, mem2dc_data_in0, mem2dc_done1, mem2dc_data_in1,
   f2ic_paddr, ic2d_packet, ic2d_pf, ic2f_ready, dtlb_flags0,
   dtlb_flags1, dtlb_phys_addr0, dtlb_phys_addr1, dtlb_pf0, dtlb_pf1,
   dtlb_ready
   );

  /* Clocks */
  input clkrst_core_clk, clkrst_core_rst_n;

  /* Interrupt Controller */
  input int_pending;
  input [3:0] int_type;
  output      int_clear;
  assign int_clear = int_pending | |int_type; // Get rid of warnings. REPLACE THIS

  /* TODO DTLB/D$ interface */

  output [29:0] mem2dc_paddr0;
  output [3:0] 	mem2dc_write0;
  output 	mem2dc_valid0;
  input 	mem2dc_done0;
  input [31:0] 	mem2dc_data_in0;
  output [31:0] mem2dc_data_out0;
  output [29:0] mem2dc_paddr1;
  output [3:0] 	mem2dc_write1;
  output 	mem2dc_valid1;
  input 	mem2dc_done1;
  input [31:0] 	mem2dc_data_in1;
  output [31:0] mem2dc_data_out1;
  output 	dispatch;

  /* I$ interface */
  output [27:0] f2ic_vaddr;
  input [27:0] 	f2ic_paddr;
  output 	f2ic_valid;
  input [127:0] ic2d_packet;
  input 	ic2d_pf;
  input 	ic2f_ready;

  /* DTLB interface */
  output [31:12] dtlb_addr0;
  output [31:12] dtlb_addr1;
  output 	 dtlb_re0;
  output 	 dtlb_re1;
  input [3:0] 	 dtlb_flags0;
  input [3:0] 	 dtlb_flags1;
  input [31:12]  dtlb_phys_addr0;
  input [31:12]  dtlb_phys_addr1;
  input 	 dtlb_pf0;
  input 	 dtlb_pf1;
  output 	 dtlb_is_write0;
  output 	 dtlb_is_write1;
  input 	 dtlb_ready;

  output 	 paging_on;
  output [19:0]  pagedir_base;
  output 	 user_mode;

  output [31:0]  r0;

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
  wire			dtlb_ready_in0;		// From stage_dtlb0 of MCPU_CORE_stage_dtlb.v
  wire			dtlb_ready_in1;		// From stage_dtlb1 of MCPU_CORE_stage_dtlb.v
  wire			dtlb_ready_out0;	// From stage_dtlb0 of MCPU_CORE_stage_dtlb.v
  wire			dtlb_ready_out1;	// From stage_dtlb1 of MCPU_CORE_stage_dtlb.v
  wire			dtlb_valid_out0;	// From stage_dtlb0 of MCPU_CORE_stage_dtlb.v
  wire			dtlb_valid_out1;	// From stage_dtlb1 of MCPU_CORE_stage_dtlb.v
  wire [27:0]		f2d_out_virtpc;		// From f of MCPU_CORE_stage_fetch.v
  wire			f_ready_out;		// From f of MCPU_CORE_stage_fetch.v
  wire			f_valid_out;		// From f of MCPU_CORE_stage_fetch.v
  wire			interrupts_enabled;	// From coproc of MCPU_CORE_coproc.v
  wire [11:0]		lsu_offset2;		// From d2 of MCPU_CORE_decode.v
  wire [11:0]		lsu_offset3;		// From d3 of MCPU_CORE_decode.v
  wire [31:0]		mem2wb_out_data0;	// From stage_mem0 of MCPU_CORE_stage_mem.v
  wire [31:0]		mem2wb_out_data1;	// From stage_mem1 of MCPU_CORE_stage_mem.v
  wire [4:0]		mem2wb_out_rd_num0;	// From stage_mem0 of MCPU_CORE_stage_mem.v
  wire [4:0]		mem2wb_out_rd_num1;	// From stage_mem1 of MCPU_CORE_stage_mem.v
  wire			mem2wb_out_rd_we0;	// From stage_mem0 of MCPU_CORE_stage_mem.v
  wire			mem2wb_out_rd_we1;	// From stage_mem1 of MCPU_CORE_stage_mem.v
  wire			mem_ready_in0;		// From stage_mem0 of MCPU_CORE_stage_mem.v
  wire			mem_ready_in1;		// From stage_mem1 of MCPU_CORE_stage_mem.v
  wire			mem_ready_out0;		// From stage_mem0 of MCPU_CORE_stage_mem.v
  wire			mem_ready_out1;		// From stage_mem1 of MCPU_CORE_stage_mem.v
  wire			mem_valid_out0;		// From stage_mem0 of MCPU_CORE_stage_mem.v
  wire			mem_valid_out1;		// From stage_mem1 of MCPU_CORE_stage_mem.v
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
  // End of automatics

  // wires that get missed because they're not module outputs :/
  wire [127:0] 	 f2d_in_packet /* verilator public */;
  wire [27:0] 	 f2d_in_virtpc;
  wire 		 f2d_in_inst_pf;
  wire 		 d2pc_in_branchreg;
  wire [31:0] 	 d2pc_in_sop3, d2pc_in_sop2, d2pc_in_sop1, d2pc_in_sop0;
  wire [31:0] 	 d2pc_in_rs_data3, d2pc_in_rs_data2, d2pc_in_rs_data1, d2pc_in_rs_data0;
  wire 		 d2pc_in_rd_we3, d2pc_in_rd_we2, d2pc_in_rd_we1, d2pc_in_rd_we0;
  wire 		 d2pc_in_pred_we3, d2pc_in_pred_we2, d2pc_in_pred_we1, d2pc_in_pred_we0;
  wire [4:0] 	 d2pc_in_rd_num3, d2pc_in_rd_num2, d2pc_in_rd_num1, d2pc_in_rd_num0;
  wire [1:0] 	 d2pc_in_oper_type3, d2pc_in_oper_type2, d2pc_in_oper_type1, d2pc_in_oper_type0;
  wire [1:0] 	 d2pc_in_shift_type3, d2pc_in_shift_type2, d2pc_in_shift_type1, d2pc_in_shift_type0;
  wire [5:0] 	 d2pc_in_shift_amount3, d2pc_in_shift_amount2, d2pc_in_shift_amount1, d2pc_in_shift_amount0;
  wire [8:0] 	 d2pc_in_execute_opcode3, d2pc_in_execute_opcode2, d2pc_in_execute_opcode1, d2pc_in_execute_opcode0;
  wire [11:0] 	 lsu_offset0, lsu_offset1;
  wire 		 d2pc_in_invalid3, d2pc_in_invalid2, d2pc_in_invalid1, d2pc_in_invalid0;
  wire [27:0] 	 d2pc_in_virtpc /* verilator public */;
  wire [27:0] 	 pc2mem_in_virtpc0 /* verilator public */, pc2mem_in_virtpc1 /* verilator public */;
  wire [27:0] 	 wb_in_virtpc0, wb_in_virtpc1, wb_in_virtpc23;
  wire 		 d2pc_in_inst_pf;
  wire [4:0] 	 d2pc_in_rs_num0;
  wire 		 d2pc_out_invalid3;
  wire 		 pc2mem_in_rd_we0, pc2mem_in_rd_we1;
  wire [4:0] 	 pc2mem_in_rd_num0, pc2mem_in_rd_num1;

  wire [31:0] 	 wb2rf_rd_data3, wb2rf_rd_data2, wb2rf_rd_data1, wb2rf_rd_data0 /* verilator public */;
  wire [4:0] 	 wb2rf_rd_num3, wb2rf_rd_num2, wb2rf_rd_num1, wb2rf_rd_num0 /* verilator public */;
  wire 		 wb2rf_rd_we3, wb2rf_rd_we2, wb2rf_rd_we1, wb2rf_rd_we0 /* verilator public */;
  wire 		 wb2rf_pred_we3, wb2rf_pred_we2, wb2rf_pred_we1, wb2rf_pred_we0 /* verilator public */;

  //stage status signals
  // According to Verilator, f_valid_in is circular. I can't figure out why that
  // would be the case, and it seems to *work*, so disable the warning
  // about it.
  /* verilator lint_off UNOPT */
  wire 		 f_valid_in /* verilator public */, d_valid_in /* verilator public */, pc_valid_in /* verilator public */;
  /* verilator lint_on UNOPT */
  wire 		 wb_valid0 /* verilator public */, wb_valid1 /* verilator public */, wb_valid23 /* verilator public */;

  wire 		 pc2wb_readyin0, pc2wb_readyin1;
  wire 		 pc_out_progress;
  wire 		 mem2wb_progress0, mem2wb_progress1;

  wire 		 pipe_flush /* verilator public */, exception /* verilator public */;
  wire [27:0] 	 pc2f_newpc;

  wire 		 f_out_ok, d_ready_out, d_out_ok, dtlb_out_ok, dtlb_valid_out;
  wire 		 pc_ready_in, pc_ready_out, pc_valid_out;
  wire 		 pc_valid_out_alu0, pc_valid_out_alu1, pc_valid_out_alu23;
  wire 		 pc_valid_out_mem0, pc_valid_out_mem1;
  wire 		 wb_ready_in, pc_out_ok;
  wire 		 mem_ready_in, mem_out_ok0, mem_out_ok1;
  wire 		 dtlb_valid_in, d2pc_valid_in;
  wire 		 mem_valid_in0, mem_valid_in1;
  wire 		 d_valid_out;
  wire 		 pc_has_mem_op;

`include "oper_type.vh"


  wire 		 dcd_depstall;
  wire 		 d_ready_in;

  // The decoder, as well as both data TLBs, must be ready for the next
  // data before the fetch stage is allowed to provide it.
  assign f_out_ok = d_ready_in & dtlb_ready_in0 & dtlb_ready_in1;

  // During the decode stage, we have the decoder as well as the TLB lookup.
  assign d_ready_in = ~d_valid_in | (pc_ready_in & ~dcd_depstall & d_ready_out);
  assign d_ready_out = dtlb_ready_out0 & dtlb_ready_out1; // The decoder itself is always ready.
  assign d_out_ok = pc_ready_in;
  assign dtlb_out_ok = pc_ready_in;
  assign d_valid_out = d_valid_in;
  assign dtlb_valid_out = dtlb_valid_out0 & dtlb_valid_out1;

  // d2pc_valid_in is the valid signal from the previous stage.
  // pc_valid_in includes the signals from the cache.
  assign pc_ready_in = pc_out_ok & (~d2pc_valid_in | pc_valid_in);
  // Post-commit stage is between cycles. However, until everything after is is ready,
  // we want to pass along valid=0.
  assign pc_ready_out = pc_out_ok;
  assign pc_valid_out = pc_out_ok & pc_valid_in & ~exception;

  assign pc_valid_out_alu0 = pc_valid_out & (d2pc_in_oper_type0 != OPER_TYPE_LSU);
  assign pc_valid_out_alu1 = pc_valid_out & (d2pc_in_oper_type1 != OPER_TYPE_LSU);
  assign pc_valid_out_alu23 = pc_valid_out;
  assign pc_valid_out_mem0 = pc_valid_out & (d2pc_in_oper_type0 == OPER_TYPE_LSU);
  assign pc_valid_out_mem1 = pc_valid_out & (d2pc_in_oper_type1 == OPER_TYPE_LSU);

  assign pc_has_mem_op = pc_valid_out_mem0 | pc_valid_out_mem1;

  // If memory is writing, we need to stall pc until it's done.
  // TODO: we could make this more specific, and stall in fewer circumstances.
  assign wb_ready_in = ~(mem_valid_out0 | mem_valid_out1);
  assign pc_out_ok = wb_ready_in & mem_ready_in;
  // The two memory ports must be used in lockstep; they're not truly independent.
  // That's why this isn't (~pc_valid_out_mem0 | mem_ready_in0) & ...
  assign mem_ready_in = mem_ready_in0 & mem_ready_in1;

  // Since memory has priority in writeback, it's never blocked by it.
  assign mem_out_ok0 = 1;
  assign mem_out_ok1 = 1;

  // Prioritize access to the writeback stage for the memory stages over the PC stage
  assign {mem2wb_progress0, mem2wb_progress1} = {mem_valid_out0, mem_valid_out1};
  assign pc2wb_readyin0 = ~mem2wb_progress0;
  assign pc2wb_readyin1 = ~mem2wb_progress1;

  // Debugging: Print out every virtpc we send past the commit point, and output a status
  // signal so the testbench can count instructions dispatched
  assign dispatch = pc_out_progress & pc_valid_in;
  /*
   always @(posedge clkrst_core_clk) begin
   if(dispatch) $display("Committing instruction %x", d2pc_in_virtpc);
  end
   */


  //unimplemented control inputs

  assign pipe_flush = (pc_valid_out | exception) & ((d2pc_in_oper_type0 == OPER_TYPE_BRANCH) | coproc_branch);



  wire [27:0] 	 branch_newpc = d2pc_in_sop0[27:0] +
		 (d2pc_in_branchreg ? d2pc_in_rs_data0[31:4] : d2pc_in_virtpc);
  assign pc2f_newpc = coproc_branch ? coproc_branchaddr : branch_newpc;



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
			 .r0			(r0[31:0]),
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
			  .d2pc_progress(d_valid_out & pc_ready_in & ~dcd_depstall),
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

  assign f_valid_in = ~pipe_flush;

  MCPU_CORE_stage_fetch f(/*AUTOINST*/
			  // Outputs
			  .f2d_out_virtpc	(f2d_out_virtpc[27:0]),
			  .f_ready_out		(f_ready_out),
			  .f_valid_out		(f_valid_out),
			  .f2ic_vaddr		(f2ic_vaddr[27:0]),
			  .f2ic_valid		(f2ic_valid),
			  // Inputs
			  .clkrst_core_clk	(clkrst_core_clk),
			  .clkrst_core_rst_n	(clkrst_core_rst_n),
			  .pc2f_newpc		(pc2f_newpc[27:0]),
			  .f_out_ok		(f_out_ok),
			  .f_valid_in		(f_valid_in),
			  .pipe_flush		(pipe_flush),
			  .f2ic_paddr		(f2ic_paddr[27:0]),
			  .ic2f_ready		(ic2f_ready));

  assign dtlb_valid_in = d_valid_in;
  assign f2d_in_packet = ic2d_packet;
  assign f2d_in_inst_pf = ic2d_pf & f_valid_out;
  assign d_valid_in = f_valid_out;
  assign f2d_in_virtpc = f2d_out_virtpc;

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
   .d2pc_out_lsu_offset(lsu_offset@[]),
   .dep_stall(dep_stall@[]),
   .long_imm(long_imm@[]),
   .d2pc_out_invalid(d2pc_out_invalid@[]),
   .d2pc_out_branchreg(d2pc_out_branchreg@[]),
   );*/


  wire 		 long_imm0, long_imm1, long_imm2, long_imm3;
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
		      .d2pc_out_lsu_offset(lsu_offset0[11:0]),	 // Templated
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
		      .d2pc_out_lsu_offset(lsu_offset1[11:0]),	 // Templated
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
		      .d2pc_out_lsu_offset(lsu_offset2[11:0]),	 // Templated
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

  wire 		 dcd_invalid3;
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
		      .d2pc_out_lsu_offset(lsu_offset3[11:0]),	 // Templated
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
  assign dcd_depstall = dep_stall0 | dep_stall1 | dep_stall2 | dep_stall3;

  // Memory stuff!
  // address calculation - sign-extend the immediate offset and add to rs
  wire [31:0] 	 d2dtlb_vaddr0, d2dtlb_vaddr1;
  assign d2dtlb_vaddr0 = rf2d_rs_data0 + {{21{lsu_offset0[11]}}, lsu_offset0[10:0]};
  assign d2dtlb_vaddr1 = rf2d_rs_data1 + {{21{lsu_offset1[11]}}, lsu_offset1[10:0]};

  wire [31:0] 	 dtlb2pc_paddr0, dtlb2pc_paddr1;

  wire [1:0] 	 d2dtlb_oper_type0, d2dtlb_oper_type1;
  assign {d2dtlb_oper_type0, d2dtlb_oper_type1} = {d2pc_out_oper_type0, d2pc_out_oper_type1};
  wire [2:0] 	 d2dtlb_memop_type0, d2dtlb_memop_type1;
  assign {d2dtlb_memop_type0, d2dtlb_memop_type1} = {d2pc_out_execute_opcode0[2:0], d2pc_out_execute_opcode1[2:0]};

  /* MCPU_CORE_stage_dtlb AUTO_TEMPLATE(
   .progress(d2pc_progress),
   .\(d2.*\) (\1@[]),
   .\(dtlb2.*\) (\1@[]),
   .dtlb_ready (dtlb_ready),
   .dtlb_valid_in (dtlb_valid_in),
   .dtlb_out_ok (dtlb_out_ok),
   .dtlb_\(.*\) (dtlb_\1@[]));*/
  MCPU_CORE_stage_dtlb stage_dtlb0(/*AUTOINST*/
				   // Outputs
				   .dtlb2pc_paddr	(dtlb2pc_paddr0[31:0]), // Templated
				   .dtlb_addr		(dtlb_addr0[31:12]), // Templated
				   .dtlb_re		(dtlb_re0),	 // Templated
				   .dtlb_is_write	(dtlb_is_write0), // Templated
				   .dtlb_ready_in	(dtlb_ready_in0), // Templated
				   .dtlb_ready_out	(dtlb_ready_out0), // Templated
				   .dtlb_valid_out	(dtlb_valid_out0), // Templated
				   // Inputs
				   .clkrst_core_clk	(clkrst_core_clk),
				   .clkrst_core_rst_n	(clkrst_core_rst_n),
				   .d2dtlb_vaddr	(d2dtlb_vaddr0[31:0]), // Templated
				   .d2dtlb_oper_type	(d2dtlb_oper_type0[1:0]), // Templated
				   .user_mode		(user_mode),
				   .pipe_flush		(pipe_flush),
				   .dtlb_flags		(dtlb_flags0[3:0]), // Templated
				   .dtlb_phys_addr	(dtlb_phys_addr0[31:12]), // Templated
				   .dtlb_ready		(dtlb_ready),	 // Templated
				   .dtlb_valid_in	(dtlb_valid_in), // Templated
				   .dtlb_out_ok		(dtlb_out_ok),	 // Templated
				   .d2dtlb_memop_type	(d2dtlb_memop_type0[2:0])); // Templated
  MCPU_CORE_stage_dtlb stage_dtlb1(/*AUTOINST*/
				   // Outputs
				   .dtlb2pc_paddr	(dtlb2pc_paddr1[31:0]), // Templated
				   .dtlb_addr		(dtlb_addr1[31:12]), // Templated
				   .dtlb_re		(dtlb_re1),	 // Templated
				   .dtlb_is_write	(dtlb_is_write1), // Templated
				   .dtlb_ready_in	(dtlb_ready_in1), // Templated
				   .dtlb_ready_out	(dtlb_ready_out1), // Templated
				   .dtlb_valid_out	(dtlb_valid_out1), // Templated
				   // Inputs
				   .clkrst_core_clk	(clkrst_core_clk),
				   .clkrst_core_rst_n	(clkrst_core_rst_n),
				   .d2dtlb_vaddr	(d2dtlb_vaddr1[31:0]), // Templated
				   .d2dtlb_oper_type	(d2dtlb_oper_type1[1:0]), // Templated
				   .user_mode		(user_mode),
				   .pipe_flush		(pipe_flush),
				   .dtlb_flags		(dtlb_flags1[3:0]), // Templated
				   .dtlb_phys_addr	(dtlb_phys_addr1[31:12]), // Templated
				   .dtlb_ready		(dtlb_ready),	 // Templated
				   .dtlb_valid_in	(dtlb_valid_in), // Templated
				   .dtlb_out_ok		(dtlb_out_ok),	 // Templated
				   .d2dtlb_memop_type	(d2dtlb_memop_type1[2:0])); // Templated

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
               d_valid_out & ~pipe_flush & ~dcd_depstall,
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
               d2pc_valid_in,
               d2pc_in_branchreg,
               d2pc_in_virtpc,
               d2pc_in_inst_pf,
               d2pc_in_rs_num0
               }),
           .en(pc_ready_in | pipe_flush),
           /*AUTOINST*/
	   // Inputs
	   .clkrst_core_clk		(clkrst_core_clk),
	   .clkrst_core_rst_n		(clkrst_core_rst_n));

  // The TLB might not have performed a lookup; all we need is that the output
  // from the TLB (if any) is ready--if it's not, we stall, and so the data in
  // the pc stage shouldn't be considered valid yet. If we used dtlb_valid_out*,
  // we'd only consider the pc stage valid if memory ops were performed in both
  // of the first two slots.
  assign pc_valid_in = d2pc_valid_in & dtlb_ready_out0 & dtlb_ready_out1;

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

  wire [31:0] 	 alu_result0, alu_result1;
  reg [31:0] 	 pc2wb_out_result0;
  wire [31:0] 	 pc2wb_out_result1;
  

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

  MCPU_CORE_alu alu1(
		     .pc2wb_out_result  (alu_result1[31:0]),
		     /*AUTOINST*/
		     // Outputs
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

  wire 		 pc_dup_rd = (d2pc_in_rd_we0 & d2pc_in_rd_we1 & (d2pc_in_rd_num0 == d2pc_in_rd_num1)) |
                 (d2pc_in_rd_we0 & d2pc_in_rd_we2 & (d2pc_in_rd_num0 == d2pc_in_rd_num2)) |
                 (d2pc_in_rd_we0 & d2pc_in_rd_we3 & (d2pc_in_rd_num0 == d2pc_in_rd_num3)) |
                 (d2pc_in_rd_we1 & d2pc_in_rd_we2 & (d2pc_in_rd_num1 == d2pc_in_rd_num2)) |
                 (d2pc_in_rd_we1 & d2pc_in_rd_we3 & (d2pc_in_rd_num1 == d2pc_in_rd_num3)) |
                 (d2pc_in_rd_we2 & d2pc_in_rd_we3 & (d2pc_in_rd_num2 == d2pc_in_rd_num3));

  wire 		 pc_dup_pred = (d2pc_in_pred_we0 & d2pc_in_pred_we1 & (d2pc_in_rd_num0[1:0] == d2pc_in_rd_num1[1:0])) |
                 (d2pc_in_pred_we0 & d2pc_in_pred_we2 & (d2pc_in_rd_num0[1:0] == d2pc_in_rd_num2[1:0])) |
                 (d2pc_in_pred_we0 & d2pc_in_pred_we3 & (d2pc_in_rd_num0[1:0] == d2pc_in_rd_num3[1:0])) |
                 (d2pc_in_pred_we1 & d2pc_in_pred_we2 & (d2pc_in_rd_num1[1:0] == d2pc_in_rd_num2[1:0])) |
                 (d2pc_in_pred_we1 & d2pc_in_pred_we3 & (d2pc_in_rd_num1[1:0] == d2pc_in_rd_num3[1:0])) |
                 (d2pc_in_pred_we2 & d2pc_in_pred_we3 & (d2pc_in_rd_num2[1:0] == d2pc_in_rd_num3[1:0]));

  wire 		 pc_dup_dest = pc_dup_rd | pc_dup_pred;
  wire 		 pc_data_pf0 = dtlb_pf0 & dtlb_valid_out0;
  wire 		 pc_data_pf1 = dtlb_pf1 & dtlb_valid_out1;
  wire 		 pc_div_zero = 0;

  wire 		 pc_syscall = (d2pc_in_oper_type0 == OPER_TYPE_OTHER) & (d2pc_in_execute_opcode0[8:5] == 4'b0010);
  wire 		 pc_break /* verilator public */ = (d2pc_in_oper_type0 == OPER_TYPE_OTHER) & (d2pc_in_execute_opcode0[8:5] == 4'b0001);

  /* MCPU_CORE_exn_encode AUTO_TEMPLATE(
   .pc_valid(pc_valid_in)); */
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
				  .pc_valid		(pc_valid_in));	 // Templated

  MCPU_CORE_coproc coproc(
			  .coproc_instruction	(pc_valid_in & (d2pc_in_oper_type0 == OPER_TYPE_OTHER)),
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
			  .pagedir_base		(pagedir_base[19:0]),
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


  // MEMORY

  wire [31:0] 	 pc2mem_in_data0, pc2mem_in_data1, pc2mem_out_data0, pc2mem_out_data1;
  wire [2:0] 	 pc2mem_in_type0, pc2mem_in_type1, pc2mem_out_type0, pc2mem_out_type1;

  // actual pc-stage logic
  // The memory op
  assign {pc2mem_out_type0, pc2mem_out_type1} = {d2pc_in_execute_opcode0[2:0], d2pc_in_execute_opcode1[2:0]};
  // The data to store
  assign {pc2mem_out_data0, pc2mem_out_data1} = {d2pc_in_sop0, d2pc_in_sop1};


  wire [31:0] 	 pc2mem_out_paddr0, pc2mem_out_paddr1, pc2mem_in_paddr0, pc2mem_in_paddr1;
  assign {pc2mem_out_paddr0, pc2mem_out_paddr1} = {dtlb2pc_paddr0, dtlb2pc_paddr1};

  register #(.WIDTH(102), .RESET_VAL(102'b0)) pc2mem_reg0(
							  .D({
							      pc2mem_out_paddr0, pc2mem_out_data0, pc2mem_out_type0,
							      d2pc_in_rd_num0, d2pc_in_rd_we0,
							      pc_valid_out_mem0,
							      d2pc_in_virtpc
							      }),
							  .Q({
							      pc2mem_in_paddr0, pc2mem_in_data0, pc2mem_in_type0,

							      pc2mem_in_rd_num0, pc2mem_in_rd_we0,
							      mem_valid_in0,
							      pc2mem_in_virtpc0
							      }),
							  .en(mem_ready_in0),
							  /*AUTOINST*/
							  // Inputs
							  .clkrst_core_clk	(clkrst_core_clk),
							  .clkrst_core_rst_n	(clkrst_core_rst_n));

  register #(.WIDTH(102), .RESET_VAL(102'b0)) pc2mem_reg1(
							  .D({
							      pc2mem_out_paddr1, pc2mem_out_data1, pc2mem_out_type1,
							      d2pc_in_rd_num1, d2pc_in_rd_we1,
							      pc_valid_out_mem1,
							      d2pc_in_virtpc
							      }),
							  .Q({
							      pc2mem_in_paddr1, pc2mem_in_data1, pc2mem_in_type1,
							      pc2mem_in_rd_num1, pc2mem_in_rd_we1,
							      mem_valid_in1,
							      pc2mem_in_virtpc1
							      }),
							  .en(mem_ready_in1),
							  /*AUTOINST*/
							  // Inputs
							  .clkrst_core_clk	(clkrst_core_clk),
							  .clkrst_core_rst_n	(clkrst_core_rst_n));

  /* MCPU_CORE_stage_mem AUTO_TEMPLATE(
   .mem_valid_in(mem_valid_in@),
   .mem_out_ok(mem_out_ok@),
   .mem_ready_in(mem_ready_in@),
   .mem_ready_out(mem_ready_out@),
   .mem_valid_out(mem_valid_out@),
   .pc2mem_in_paddr(pc2mem_in_paddr@[]),
   .pc2mem_in_data(pc2mem_in_data@[]),
   .pc2mem_in_type(pc2mem_in_type@[]),
   .pc2mem_in_rd_num(pc2mem_in_rd_num@[]),
   .pc2mem_in_rd_we(pc2mem_in_rd_we@),
   .mem2wb_out_data(mem2wb_out_data@[]),
   .mem2wb_out_rd_num(mem2wb_out_rd_num@[]),
   .mem2wb_out_rd_we(mem2wb_out_rd_we@),
   .mem2dc_paddr(mem2dc_paddr@[]),
   .mem2dc_write(mem2dc_write@[]),
   .mem2dc_valid(mem2dc_valid@),
   .mem2dc_done(mem2dc_done@),
   .mem2dc_data_out(mem2dc_data_out@[]),
   .mem2dc_data_in(mem2dc_data_in@[]),
   .pc2mem_progress(pc2mem_progress@),
   .mem2wb_progress(mem2wb_progress@),
   );*/

  MCPU_CORE_stage_mem stage_mem0(/*AUTOINST*/
				 // Outputs
				 .mem_ready_in		(mem_ready_in0), // Templated
				 .mem_ready_out		(mem_ready_out0), // Templated
				 .mem_valid_out		(mem_valid_out0), // Templated
				 .mem2wb_out_data	(mem2wb_out_data0[31:0]), // Templated
				 .mem2wb_out_rd_num	(mem2wb_out_rd_num0[4:0]), // Templated
				 .mem2wb_out_rd_we	(mem2wb_out_rd_we0), // Templated
				 .mem2dc_paddr		(mem2dc_paddr0[29:0]), // Templated
				 .mem2dc_write		(mem2dc_write0[3:0]), // Templated
				 .mem2dc_valid		(mem2dc_valid0), // Templated
				 .mem2dc_data_out	(mem2dc_data_out0[31:0]), // Templated
				 // Inputs
				 .clkrst_core_clk	(clkrst_core_clk),
				 .clkrst_core_rst_n	(clkrst_core_rst_n),
				 .mem_valid_in		(mem_valid_in0), // Templated
				 .mem_out_ok		(mem_out_ok0),	 // Templated
				 .pc2mem_in_paddr	(pc2mem_in_paddr0[31:0]), // Templated
				 .pc2mem_in_data	(pc2mem_in_data0[31:0]), // Templated
				 .pc2mem_in_type	(pc2mem_in_type0[2:0]), // Templated
				 .pc2mem_in_rd_num	(pc2mem_in_rd_num0[4:0]), // Templated
				 .pc2mem_in_rd_we	(pc2mem_in_rd_we0), // Templated
				 .mem2dc_done		(mem2dc_done0),	 // Templated
				 .mem2dc_data_in	(mem2dc_data_in0[31:0])); // Templated

  MCPU_CORE_stage_mem stage_mem1(/*AUTOINST*/
				 // Outputs
				 .mem_ready_in		(mem_ready_in1), // Templated
				 .mem_ready_out		(mem_ready_out1), // Templated
				 .mem_valid_out		(mem_valid_out1), // Templated
				 .mem2wb_out_data	(mem2wb_out_data1[31:0]), // Templated
				 .mem2wb_out_rd_num	(mem2wb_out_rd_num1[4:0]), // Templated
				 .mem2wb_out_rd_we	(mem2wb_out_rd_we1), // Templated
				 .mem2dc_paddr		(mem2dc_paddr1[29:0]), // Templated
				 .mem2dc_write		(mem2dc_write1[3:0]), // Templated
				 .mem2dc_valid		(mem2dc_valid1), // Templated
				 .mem2dc_data_out	(mem2dc_data_out1[31:0]), // Templated
				 // Inputs
				 .clkrst_core_clk	(clkrst_core_clk),
				 .clkrst_core_rst_n	(clkrst_core_rst_n),
				 .mem_valid_in		(mem_valid_in1), // Templated
				 .mem_out_ok		(mem_out_ok1),	 // Templated
				 .pc2mem_in_paddr	(pc2mem_in_paddr1[31:0]), // Templated
				 .pc2mem_in_data	(pc2mem_in_data1[31:0]), // Templated
				 .pc2mem_in_type	(pc2mem_in_type1[2:0]), // Templated
				 .pc2mem_in_rd_num	(pc2mem_in_rd_num1[4:0]), // Templated
				 .pc2mem_in_rd_we	(pc2mem_in_rd_we1), // Templated
				 .mem2dc_done		(mem2dc_done1),	 // Templated
				 .mem2dc_data_in	(mem2dc_data_in1[31:0])); // Templated


  /* AUTO_CONSTANT ( OPER_TYPE_BRANCH ) */
  /* AUTO_CONSTANT ( OPER_TYPE_OTHER ) */
  /* AUTO_CONSTANT ( OPER_TYPE_LSU ) */
  reg 		 pc2wb_out_rd_we0;
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
  assign pc2wb_out_result1 = alu_result1; // TODO SC bits

  wire wb_in_rd_we0, wb_in_rd_we1, wb_in_rd_we2, wb_in_rd_we3;
  wire wb_in_pred_we0, wb_in_pred_we1, wb_in_pred_we2, wb_in_pred_we3;


  register #(.WIDTH(107), .RESET_VAL(107'b0))
  pc2wb_reg23(
	      .D({
		  pc2wb_out_result3, pc2wb_out_result2,
		  d2pc_in_rd_num3, d2pc_in_rd_num2,
		  d2pc_in_rd_we3, d2pc_in_rd_we2, d2pc_in_pred_we3, d2pc_in_pred_we2,
		  pc_valid_out_alu23,
		  d2pc_in_virtpc
		  }),
	      .Q({
		  wb2rf_rd_data3, wb2rf_rd_data2,
		  wb2rf_rd_num3, wb2rf_rd_num2,
		  wb_in_rd_we3, wb_in_rd_we2, wb_in_pred_we3, wb_in_pred_we2,
		  wb_valid23,
		  wb_in_virtpc23
		  }),
	      .en(1'b1),
	      /*AUTOINST*/
	      // Inputs
	      .clkrst_core_clk		(clkrst_core_clk),
	      .clkrst_core_rst_n	(clkrst_core_rst_n));

  reg_2 #(.WIDTH(68), .RESET_VAL(68'b0))
  pc2wb_reg0(
	     .D0({
		  mem2wb_out_data0, mem2wb_out_rd_num0, mem2wb_out_rd_we0, 1'b0,
		  mem_valid_out0,
		  pc2mem_in_virtpc0
		  }),
	     .D1({
		  pc2wb_out_result0, d2pc_in_rd_num0, pc2wb_out_rd_we0, d2pc_in_pred_we0,
		  pc_valid_out_alu0,
		  d2pc_in_virtpc
		  }),
	     .Q({
		 wb2rf_rd_data0, wb2rf_rd_num0, wb_in_rd_we0, wb_in_pred_we0,
		 wb_valid0,
		 wb_in_virtpc0
		 }),
	     .en0(mem2wb_progress0), .en1(~mem2wb_progress0),
	     /*AUTOINST*/
	     // Inputs
	     .clkrst_core_clk		(clkrst_core_clk),
	     .clkrst_core_rst_n		(clkrst_core_rst_n));

  reg_2 #(.WIDTH(68), .RESET_VAL(68'b0))
  pc2wb_reg1(
	     .D0({
		  mem2wb_out_data1, mem2wb_out_rd_num1, mem2wb_out_rd_we1, 1'b0,
		  mem_valid_out1,
		  pc2mem_in_virtpc1
		  }),
	     .D1({
		  pc2wb_out_result1, d2pc_in_rd_num1, d2pc_in_rd_we1, d2pc_in_pred_we1,
		  pc_valid_out_alu1,
		  d2pc_in_virtpc
		  }),
	     .Q({
		 wb2rf_rd_data1, wb2rf_rd_num1, wb_in_rd_we1, wb_in_pred_we1,
		 wb_valid1,
		 wb_in_virtpc1
		 }),
	     .en0(mem2wb_progress1), .en1(~mem2wb_progress1),
	     /*AUTOINST*/
	     // Inputs
	     .clkrst_core_clk		(clkrst_core_clk),
	     .clkrst_core_rst_n		(clkrst_core_rst_n));

  assign wb2rf_rd_we0 = wb_in_rd_we0 & wb_valid0;
  assign wb2rf_rd_we1 = wb_in_rd_we1 & wb_valid1;
  assign wb2rf_rd_we2 = wb_in_rd_we2 & wb_valid23;
  assign wb2rf_rd_we3 = wb_in_rd_we3 & wb_valid23;

  assign wb2rf_pred_we0 = wb_in_pred_we0 & wb_valid0;
  assign wb2rf_pred_we1 = wb_in_pred_we1 & wb_valid1;
  assign wb2rf_pred_we2 = wb_in_pred_we2 & wb_valid23;
  assign wb2rf_pred_we3 = wb_in_pred_we3 & wb_valid23;

endmodule

// Local Variables:
// verilog-library-flags:("-f ../dirs.vc")
// End:
