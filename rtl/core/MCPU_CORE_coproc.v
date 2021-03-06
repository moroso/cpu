`timescale 1 ps / 1 ps

module MCPU_CORE_coproc(/*AUTOARG*/
   // Outputs
   coproc_reg_result, coproc_rd_we, user_mode, paging_on,
   interrupts_enabled, coproc_branchaddr, coproc_branch, link,
   pagedir_base, tlb_clear, dl1c_flush, il1c_flush,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, d2pc_in_rs_data0, d2pc_in_sop0,
   d2pc_in_rs_num0, d2pc_in_rd_num0, d2pc_in_execute_opcode0,
   coproc_instruction, combined_ec0, combined_ec1, combined_ec2,
   combined_ec3, exception, d2pc_in_virtpc, mem_vaddr0, mem_vaddr1,
   d2pc_in_set_link, d2pc_in_clear_link, pc_ready_in
   );
`include "coproc_ops.vh"

    input clkrst_core_clk, clkrst_core_rst_n;

    input [31:0] d2pc_in_rs_data0;
    input [31:0] d2pc_in_sop0;
    input [4:0] d2pc_in_rs_num0;
    input [4:0] d2pc_in_rd_num0;
    input [8:0] d2pc_in_execute_opcode0;
    input coproc_instruction;

    input [4:0] combined_ec0, combined_ec1, combined_ec2, combined_ec3;

    output [31:0] coproc_reg_result;
    output coproc_rd_we;

    output reg user_mode;
    output paging_on;
    output interrupts_enabled;

    input exception;
    input [27:0] d2pc_in_virtpc;
    input [31:0] mem_vaddr0, mem_vaddr1;
    output [27:0] coproc_branchaddr;
    output coproc_branch;
  output link;
  input      d2pc_in_set_link;
  input      d2pc_in_clear_link;

  output [19:0] pagedir_base;
  output 	tlb_clear;
  // For now, FLUSH just clears the cache completely, and ignores its argument.
  // Later we should implement FLUSH for individual addresses,
  // but this should be enough for everything to behave correctly.
  // TODO: hook up dl1c_flush, and probably the TLB flush signals too.
  output 	dl1c_flush;
  output 	il1c_flush;
  // For now, we always flush both TLBs together, and we use the tlb_clear signal for that.
  wire 		dtlb_flush;
  wire 		itlb_flush;

  wire 	 eret_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_ERET;
  wire 	 mfc_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_MFC;
  wire 	 mtc_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_MTC;
  wire 	 mfhi_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_MFHI;
  wire 	 mthi_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_MTHI;
  wire 	 mult_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_MULT;
  wire 	 flush_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == COPROC_OP_FLUSH;

  reg [31:0] scratchpad[3:0];
  reg [31:0] coproc_regs[9:0];
  reg [31:0] ovf;

  wire [63:0] umul_result = d2pc_in_sop0 * d2pc_in_rs_data0;
  //Verilog multiplication is signed iff both operands are signed, regardless of the destination
  wire signed [31:0] smul_sop = d2pc_in_sop0;
  wire signed [31:0] smul_rs = d2pc_in_rs_data0;
  wire [63:0] smul_result = smul_sop * smul_rs;
  wire mul_is_signed = d2pc_in_execute_opcode0[4];

  assign paging_on = coproc_regs[0][1];
  assign interrupts_enabled = coproc_regs[0][0];
  assign coproc_reg_result = mult_inst ? (mul_is_signed ? smul_result[31:0] : umul_result[31:0])
                           : mfhi_inst ? ovf 
                           : (d2pc_in_rs_num0[4] ? scratchpad[d2pc_in_rs_num0[1:0]]
                                                 : coproc_regs[d2pc_in_rs_num0[3:0]]);
  wire 	       coproc_rd_we = mfc_inst || mfhi_inst || mult_inst;

    assign coproc_branch = exception | eret_inst;
    assign coproc_branchaddr = exception ? coproc_regs[2][31:4] : coproc_regs[3][31:4]; // EHA or EPC
  assign pagedir_base = coproc_regs[1][31:12];

  

  assign dl1c_flush = flush_inst & d2pc_in_execute_opcode0[1:0] == 2'b00;
  assign il1c_flush = flush_inst & d2pc_in_execute_opcode0[1:0] == 2'b01;
  assign dtlb_flush = flush_inst & d2pc_in_execute_opcode0[1:0] == 2'b10;
  assign itlb_flush = flush_inst & d2pc_in_execute_opcode0[1:0] == 2'b11;

  input        pc_ready_in;

  // Clear TLB on write to PTB.
  assign tlb_clear = (mtc_inst & (~d2pc_in_rd_num0[4]) & d2pc_in_rd_num0[3:0] == 1) | dtlb_flush | itlb_flush;

  reg 	       link_bit;
  assign link = link_bit;


    integer i;
    always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
        if(~clkrst_core_rst_n) begin
            for(i = 0; i < 4; i = i + 1) begin
                scratchpad[i] <= 32'b0;
            end
            for(i = 0; i < 10; i = i + 1) begin
                coproc_regs[i] <= 32'b0;
            end
            user_mode <= 0;
            ovf <= 0;
	    link_bit <= 0;
        end
        else begin
	   if (pc_ready_in) begin
	      // Unlike most operations, clearing the link bit due to
	      // a sc instruction has to wait until we're just about to
	      // shift in new data--otherwise, the memory controller will
	      // get the cleared value of the link bit, instead of the
	      // previous value.
	      if (d2pc_in_clear_link)
		link_bit <= 0;
	      else if (d2pc_in_set_link)
		link_bit <= 1;
	   end

	   if(exception) begin //TODO clear link bit when that exists
              user_mode <= 0;
              link_bit <= 0;
              coproc_regs[0][0] <= 0; // disable interrupts
              coproc_regs[3][31:4] <= d2pc_in_virtpc[27:0]; //EPC
              coproc_regs[3][1] <= interrupts_enabled;
              coproc_regs[3][0] <= ~user_mode;
              coproc_regs[4] <= {27'd0, combined_ec0};
              coproc_regs[5] <= {27'd0, combined_ec1};
              coproc_regs[6] <= {27'd0, combined_ec2};
              coproc_regs[7] <= {27'd0, combined_ec3};
              coproc_regs[8] <= mem_vaddr0;
              coproc_regs[9] <= mem_vaddr1;
           end
           else if(eret_inst) begin
              user_mode <= ~coproc_regs[3][0];
              coproc_regs[0][0] <= coproc_regs[3][1];
              link_bit <= 0;
           end
           else if(mtc_inst) begin
              if(d2pc_in_rd_num0[4])
                scratchpad[d2pc_in_rd_num0[1:0]] <= d2pc_in_rs_data0;
              else
                coproc_regs[d2pc_in_rd_num0[3:0]] <= d2pc_in_rs_data0;
           end
           else if(mthi_inst) begin
              ovf <= d2pc_in_rs_data0;
           end
           else if(mult_inst) begin
              if(mul_is_signed)
                 ovf <= smul_result[63:32];
              else
                 ovf <= umul_result[63:32];
           end
	end
    end


endmodule
