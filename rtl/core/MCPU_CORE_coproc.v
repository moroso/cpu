module MCPU_CORE_coproc(/*AUTOARG*/
   // Outputs
   coproc_reg_result, coproc_rd_we, user_mode, paging_on,
   interrupts_enabled, coproc_branchaddr, coproc_branch, pagedir_base,
   tlb_clear,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, d2pc_in_rs_data0, d2pc_in_sop0,
   d2pc_in_rs_num0, d2pc_in_rd_num0, d2pc_in_execute_opcode0,
   coproc_instruction, combined_ec0, combined_ec1, combined_ec2,
   combined_ec3, int_type, exception, d2pc_in_virtpc, mem_vaddr0,
   mem_vaddr1
   );

    input clkrst_core_clk, clkrst_core_rst_n;

    input [31:0] d2pc_in_rs_data0;
    input [31:0] d2pc_in_sop0;
    input [4:0] d2pc_in_rs_num0;
    input [4:0] d2pc_in_rd_num0;
    input [8:0] d2pc_in_execute_opcode0;
    input coproc_instruction;

    input [4:0] combined_ec0, combined_ec1, combined_ec2, combined_ec3;
    input [3:0] int_type;

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

  output [19:0] pagedir_base;
  output 	tlb_clear;

    reg [31:0] scratchpad[3:0];
    reg [31:0] coproc_regs[9:0];

    assign paging_on = coproc_regs[0][1];
    assign interrupts_enabled = coproc_regs[0][0];
    assign coproc_reg_result = d2pc_in_rs_num0[4] ? scratchpad[d2pc_in_rs_num0[1:0]]
                                                  : coproc_regs[d2pc_in_rs_num0[3:0]];
    wire coproc_rd_we = coproc_instruction & d2pc_in_execute_opcode0[8:5] == 4'b0110;

    wire eret_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == 4'b0100;
    wire mtc_inst = coproc_instruction & d2pc_in_execute_opcode0[8:5] == 4'b0111;

    assign coproc_branch = exception | eret_inst;
    assign coproc_branchaddr = exception ? coproc_regs[2][31:4] : coproc_regs[3][31:4]; // EHA or EPC
  assign pagedir_base = coproc_regs[1][31:12];
  assign tlb_clear = (mtc_inst & (~d2pc_in_rd_num0[4]) & d2pc_in_rd_num0[3:0] == 1);

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
        end
        else if(exception) begin //TODO clear link bit when that exists
            user_mode <= 0;
            coproc_regs[3][31:4] <= d2pc_in_virtpc[27:0]; //EPC
            coproc_regs[3][1] <= interrupts_enabled;
            coproc_regs[3][0] <= ~user_mode;
            coproc_regs[4] <= {23'd0, int_type, combined_ec0};
            coproc_regs[5] <= {27'd0, combined_ec1};
            coproc_regs[6] <= {27'd0, combined_ec2};
            coproc_regs[7] <= {27'd0, combined_ec3};
            coproc_regs[8] <= mem_vaddr0;
            coproc_regs[9] <= mem_vaddr1;
        end
        else if(eret_inst) begin
            user_mode <= ~coproc_regs[3][0];
            coproc_regs[0][0] <= coproc_regs[3][1];
        end
        else if(mtc_inst) begin
            if(d2pc_in_rd_num0[4])
                scratchpad[d2pc_in_rd_num0[1:0]] <= d2pc_in_rs_data0;
            else
                coproc_regs[d2pc_in_rd_num0[3:0]] <= d2pc_in_rs_data0;
        end
    end


endmodule
