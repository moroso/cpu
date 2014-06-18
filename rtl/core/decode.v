module mcpu_decode(/*AUTOARG*/
   // Outputs
   execute_opcode, shift_type, shift_amount, oper_type, rd_num,
   rs_num, rt_num, rd_we, pred_we, op1, op2, stall, long_imm,
   link_bit,
   // Inputs
   inst, preds, reg_scoreboard, pred_scoreboard, rs_data, rt_data,
   nextinst
   );

  input [31:0] inst;
  input [2:0] preds;
  input [31:0] reg_scoreboard;
  input [2:0] pred_scoreboard;
  input [31:0] rs_data, rt_data;
  input [31:0] nextinst;
  input prev_long_imm;
  
  output [8:0] execute_opcode;
  output [1:0] shift_type;
  output [5:0] shift_amount;
  output [2:0] oper_type;
  output [4:0] rd_num, rs_num, rt_num;
  output rd_we;
  output pred_we;
  output [31:0] op1, op2;
  output [11:0] lsu_offset;
  output dep_stall;
  output long_imm;
  output link_bit;
  output invalid;

  /* AUTOREG */

`include "oper_type.vh"

  wire depend_rt, depend_rs;
  wire [3:0] actual_preds, actual_scoreboard;


  //each execute unit will only take the bits of this that it needs
  //execute units will be responsible for discovering invalid opcodes
  assign execute_opcode = {inst[23:19], inst[13:10]};

  assign rt_num = inst[18:14];
  assign rs_num = inst[4:0];
  assign link_bit = inst[25];
  assign op1 = rs_data;
  assign actual_preds = {1'b1, preds};
  assign actual_scoreboard = {1'b0, pred_scoreboard};
  assign lsu_offset = execute_opcode[2] ? {inst[24:19], inst[13], inst[9:5]} : inst[24:13];
  assign dep_stall = (depend_rt & reg_scoreboard[rt_num]) |
                     (depend_rs & reg_scoreboard[rs_num]) |  
                     (actual_scoreboard[inst[31:30]]) |
                     (rd_we & reg_scoreboard[rd_num]) |
                     (pred_we & actual_scoreboard[rd_num[1:0]]);
  


  //this is going to be enormous...
  //Also needs a pass to make it comprehensible
  always @(/*AUTOSENSE*/OPER_TYPE_ALU or OPER_TYPE_BRANCH
	   or OPER_TYPE_LSU or OPER_TYPE_OTHER or actual_preds
	   or execute_opcode or inst or nextinst or rs_data or rt_data) begin
	   
    rd_num = inst[9:5];
    rd_we = 0;
    pred_we = 0;
    oper_type = OPER_TYPE_ALU; 
    shift_amount = 6'd0;
    shift_type = 2'b00;
    long_imm = 0;
    op2 = 32'd0;
    depend_rs = 0;
    depend_rt = 0;
    invalid = 0;


    if((actual_preds[inst[31:30]] ^ inst[29]) & ~prev_long_imm) begin
      
      if(~inst[28]) begin // alu short
        rd_we = execute_opcode[3:0] != 4'b0111; //write predicate on compares, to register otherwise
        pred_we = ~rd_we;
        shift_type = 2'b11;
        shift_amount = {1'b0, inst[17:14], 1'b0};
        op2[9:0] = inst[27:18];

        if(execute_opcode[3]) begin //1-op
          op2[14:10] = inst[4:0];
        end
        else begin
          depend_rs = 1;
        end
        
      end

      else if(inst[27:26] == 2'b01) begin //alu reg
        op2 = rt_data;
        rd_we = execute_opcode[3:0] != 4'b0111;
        pred_we = ~rd_we;
        shift_amount = {0, inst[25:21]};
        shift_type = inst[20:19];
        depend_rt = 1;
        depend_rs = ~execute_opcode[3]; // 2-op
      end

      else if(inst[27:25] == 3'b001) begin // load/store
        oper_type = OPER_TYPE_LSU;
        op2 = rt_data;
        reg_we = ~execute_opcode[2];
        depend_rs = 1;
        depend_rt = execute_opcode[2];
      end

      else if(inst[27]) begin // branch
        oper_type = OPER_TYPE_BRANCH;
        rd_num = 5'd31;
        rd_we = inst[25];
        if(inst[26]) begin // register
          depend_rs = 1;
          op2[23:4] = inst[24:5];
        end
        else //immediate
          op2[28:4] = inst[24:0];
      end

      else if(inst[24]) begin // other
        
        oper_type = OPER_TYPE_OTHER;
        op2 = rt_data;
        case(execute_opcode[8:5])
          4'b0001: begin end // BREAK
          4'b0010: begin end // SYSCALL
          4'b0011: begin end // FENCE
          4'b0100: begin end // ERET
          4'b0101: begin     // FLUSH
            depend_rs = 1;
          end
          4'b0110: begin     // MFC
            rd_we = 1;
          end
          4'b0111: begin     // MTC
            depend_rs = 1;
          end
          4'b1000: begin     // MULT
            depend_rs = 1;
            depend_rt = 1;
            rd_we = 1;
          end
          4'b1001: begin     // DIV
            depend_rs = 1;
            depend_rt = 1;
            rd_we = 1;
          end
          4'b1010: begin     // MFHI
            rd_we = 1;
          end
          4'b1011: begin     // MTHI
            depend_rs = 1;
          end
          default: begin
            invalid = 1;
          end

        endcase
      end

      else if(|inst[23:22]) begin
        invalid = 1;
      end
      
      else if(inst[23]) begin //shift
        oper_type = OPER_TYPE_ALU;
        depend_rs = 1;
        depend_rt = 1;
        rd_we = 1;
        shift_type = inst[20:19];
        //we don't actually care what the whole value is, only if it's >= 32 
        shift_amt = {|rs_data[31:5], rs_data[4:0]};
        op2 = rt_data;
      end

      else if(|inst[20:14]) begin
        invalid = 1;
      end
      
      else begin //ALU long immediate
        oper_type = OPER_TYPE_ALU;
        op2 = nextinst;
        long_imm = 1;
        depend_rs = ~execute_opcode[3];
        pred_we = execute_opcode[3:0] == 4'b0111; // COMPARE
        rd_we = ~pred_we;
      end
    end
  end

endmodule
