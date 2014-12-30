module MCPU_CORE_exn_encode(/*AUTOARG*/
   // Outputs
   combined_ec0, combined_ec1, combined_ec2, combined_ec3, exception,
   // Inputs
   d2pc_in_inst_pf, d2pc_in_invalid0, d2pc_in_invalid1,
   d2pc_in_invalid2, d2pc_in_invalid3, pc_dup_dest, pc_data_pf0,
   pc_data_pf1, pc_div_zero, int_pending, pc_syscall, pc_break,
   interrupts_enabled, pc_valid
   );
    
    input d2pc_in_inst_pf;
    input d2pc_in_invalid0, d2pc_in_invalid1, d2pc_in_invalid2, d2pc_in_invalid3;
    input pc_dup_dest;
    input pc_data_pf0, pc_data_pf1;
    input pc_div_zero;
    input int_pending;
    input pc_syscall;
    input pc_break;
    input interrupts_enabled;
    input pc_valid;

    output [4:0] combined_ec0, combined_ec1, combined_ec2, combined_ec3;
    output exception;

    `include "exn_codes.vh"

    wire exn0 = combined_ec0 != EXN_CODE_NOERR;
    wire exn1 = combined_ec1 != EXN_CODE_NOERR;
    wire exn2 = combined_ec2 != EXN_CODE_NOERR;
    wire exn3 = combined_ec3 != EXN_CODE_NOERR;
    assign exception = (exn0 | exn1 | exn2 | exn3) & pc_valid;

    always @(/*AUTOSENSE*/EXN_CODE_BREAK or EXN_CODE_DATA_PF
	     or EXN_CODE_DIVZERO or EXN_CODE_DUP_DEST or EXN_CODE_ILL
	     or EXN_CODE_INST_PF or EXN_CODE_INTERRUPT
	     or EXN_CODE_NOERR or EXN_CODE_SYSCALL or d2pc_in_inst_pf
	     or d2pc_in_invalid0 or int_pending or interrupts_enabled
	     or pc_break or pc_data_pf0 or pc_div_zero or pc_dup_dest
	     or pc_syscall) begin
        combined_ec0 = EXN_CODE_NOERR;
        if(int_pending & interrupts_enabled)
            combined_ec0 = EXN_CODE_INTERRUPT;
        if(d2pc_in_inst_pf)
            combined_ec0 = EXN_CODE_INST_PF;
        else if(d2pc_in_invalid0)
            combined_ec0 = EXN_CODE_ILL;
        else if(pc_dup_dest)
            combined_ec0 = EXN_CODE_DUP_DEST;
        else if(pc_data_pf0)
            combined_ec0 = EXN_CODE_DATA_PF;
        else if(pc_div_zero)
            combined_ec0 = EXN_CODE_DIVZERO;
        else if(pc_syscall)
            combined_ec0 = EXN_CODE_SYSCALL;
        else if(pc_break)
            combined_ec0 = EXN_CODE_BREAK;
    end

    always @(/*AUTOSENSE*/EXN_CODE_DATA_PF or EXN_CODE_ILL
	     or EXN_CODE_NOERR or d2pc_in_invalid1 or pc_data_pf1) begin
        combined_ec1 = EXN_CODE_NOERR;
        if(d2pc_in_invalid1)
            combined_ec1 = EXN_CODE_ILL;
        else if(pc_data_pf1)
            combined_ec1 = EXN_CODE_DATA_PF;
    end

    assign combined_ec2 = d2pc_in_invalid2 ? EXN_CODE_ILL : EXN_CODE_NOERR;
    assign combined_ec3 = d2pc_in_invalid3 ? EXN_CODE_ILL : EXN_CODE_NOERR;
endmodule
