`timescale 1 ps / 1 ps

module MCPU_CORE_alu(/*AUTOARG*/
   // Outputs
   pc2wb_out_result, pc_alu_invalid,
   // Inputs
   d2pc_in_rs_data, d2pc_in_sop, d2pc_in_execute_opcode, compare_type,
   d2pc_in_shift_type, d2pc_in_shift_amount
   );

  input [31:0] d2pc_in_rs_data, d2pc_in_sop;
  input [3:0] d2pc_in_execute_opcode;
  input [2:0] compare_type;
  input [1:0] d2pc_in_shift_type;
  input [5:0] d2pc_in_shift_amount;

  output [31:0] pc2wb_out_result;
  output pc_alu_invalid;

  /*AUTOREG*/
  // Beginning of automatic regs (for this module's undeclared outputs)
  reg [31:0]		pc2wb_out_result;
  reg			pc_alu_invalid;
  // End of automatics

  wire [31:0] shifted_op2;

  mcpu_shifter shifter(/*AUTOINST*/
		       // Outputs
		       .shifted_op2	(shifted_op2[31:0]),
		       // Inputs
		       .d2pc_in_sop	(d2pc_in_sop[31:0]),
		       .d2pc_in_shift_type(d2pc_in_shift_type[1:0]),
		       .d2pc_in_shift_amount(d2pc_in_shift_amount[5:0]));

  always @(/*AUTOSENSE*/compare_type or d2pc_in_execute_opcode
	   or d2pc_in_rs_data or shifted_op2) begin
    pc2wb_out_result = 32'dX;
    pc_alu_invalid = 0;
    case(d2pc_in_execute_opcode)
      4'b0000: pc2wb_out_result = d2pc_in_rs_data + shifted_op2;
      4'b0001: pc2wb_out_result = d2pc_in_rs_data & shifted_op2;
      4'b0010: pc2wb_out_result = ~(d2pc_in_rs_data | shifted_op2);
      4'b0011: pc2wb_out_result = d2pc_in_rs_data | shifted_op2;
      4'b0100: pc2wb_out_result = d2pc_in_rs_data - shifted_op2;
      4'b0101: pc2wb_out_result = shifted_op2 - d2pc_in_rs_data;
      4'b0110: pc2wb_out_result = d2pc_in_rs_data ^ shifted_op2;
      4'b1000: pc2wb_out_result = shifted_op2;
      4'b1001: pc2wb_out_result = ~shifted_op2;
      4'b1010: pc2wb_out_result = {{24{shifted_op2[7]}}, shifted_op2[7:0]};
      4'b1011: pc2wb_out_result = {{16{shifted_op2[15]}}, shifted_op2[15:0]};

      4'b0111: case(compare_type)
        3'b000: pc2wb_out_result[0] = d2pc_in_rs_data < shifted_op2;
        3'b001: pc2wb_out_result[0] = d2pc_in_rs_data <= shifted_op2;
        3'b010: pc2wb_out_result[0] = d2pc_in_rs_data == shifted_op2;
        3'b011: pc_alu_invalid = 1;
        3'b100: pc2wb_out_result[0] = $signed(d2pc_in_rs_data) < $signed(shifted_op2);
        3'b101: pc2wb_out_result[0] = $signed(d2pc_in_rs_data) <= $signed(shifted_op2);
        3'b110: pc2wb_out_result[0] = |(d2pc_in_rs_data & shifted_op2);
        3'b111: pc2wb_out_result[0] = ~|(~d2pc_in_rs_data & shifted_op2);
      endcase

      default: pc_alu_invalid = 1;
    endcase
  end

endmodule

module mcpu_shifter(/*AUTOARG*/
   // Outputs
   shifted_op2,
   // Inputs
   d2pc_in_sop, d2pc_in_shift_type, d2pc_in_shift_amount
   );

  input [31:0] d2pc_in_sop;
  input [1:0] d2pc_in_shift_type;
  input [5:0] d2pc_in_shift_amount;

  output reg [31:0] shifted_op2;

  always @(/*AUTOSENSE*/d2pc_in_shift_amount or d2pc_in_shift_type
	   or d2pc_in_sop) begin
    if(d2pc_in_shift_amount[5] & (d2pc_in_shift_type != 2'b11)) begin
      if(d2pc_in_shift_type == 2'b10) shifted_op2 = {32{d2pc_in_sop[31]}};
      else shifted_op2 = 32'b0;
    end else begin
      case(d2pc_in_shift_type)
        2'b00: shifted_op2 = d2pc_in_sop << d2pc_in_shift_amount[4:0];
        2'b01: shifted_op2 = d2pc_in_sop >> d2pc_in_shift_amount[4:0];
        2'b10: shifted_op2 = $signed(d2pc_in_sop) >>> d2pc_in_shift_amount[4:0];
        2'b11: shifted_op2 = (d2pc_in_sop >> d2pc_in_shift_amount[4:0]) | (d2pc_in_sop << (6'd32 - d2pc_in_shift_amount[4:0]));
      endcase
    end
  end

endmodule
