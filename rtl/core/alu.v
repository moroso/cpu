module mcpu_alu(/*AUTOARG*/);

  input [31:0] op1, op2;
  input [3:0] opcode;
  input [2:0] compare_type;
  input [1:0] shift_type;
  input [5:0] shift_amount;

  output [31:0] result;
  output invalid;

  /* AUTOREG */

  wire [31:0] shifted_op2;

  mcpu_shifter shifter(.*);

  always @(/*AUTOSENSE*/) begin
    result = 32'b0;
    invalid = 0;
    case(opcode)
      4'b0000: result = op1 + shifted_op2;
      4'b0001: result = op1 & shifted_op2;
      4'b0010: result = ~(op1 | shifted_op2);
      4'b0011: result = op1 | shifted_op2;
      4'b0100: result = op1 - shifted_op2;
      4'b0101: result = shifted_op2 - op1;
      4'b0110: result = op1 ^ shifted_op2;
      4'b0111: result = shifted_op2;
      4'b1010: result = {{24{shifted_op2[7]}}, shifted_op2[7:0]};
      4'b1011: result = {{16{shifted_op2[15]}}, shifted_op2[15:0]};

      4'b1111: case(compare_type)
        3'b000: result[0] = op1 < shifted_op2;
        3'b001: result[0] = op1 <= shifted_op2;
        3'b010: result[0] = op1 == shifted_op2;
        3'b100: result[0] = $signed(op1) < $signed(shifted_op2);
        3'b101: result[0] = $signed(op1) <= $signed(shifted_op2);
      endcase

      default: invalid = 1;
    endcase
  end

endmodule

module mcpu_shifter(/*AUTOARG*/);

  input [31:0] op2;
  input [1:0] shift_type;
  input [5:0] shift_amount;

  output reg [31:0] shifted_op2;

  always @(/*AUTOSENSE*/) begin
    if(shift_amount[5] & (shift_type != 2'b11)) begin
      if(shift_type == 2'b10) shifted_op2 = {32{operand[31]}};
      else shifted_op2 = 32'b0;
    end else begin
      case(shift_type)
        2'b00: shifted_op2 = operand << shift_amount[4:0];
        2'b01: shifted_op2 = operand >> shift_amount[4:0];
        2'b10: shifted_op2 = $signed(operand) >>> shift_amount[4:0]; // lol
        2'b11: shifted_op2 = (operand >> shift_amount[4:0]) | (operand << shift_amount[4:0]);
      endcase
    end
  end

endmodule
