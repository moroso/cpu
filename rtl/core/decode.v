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
  output stall;
  output long_imm;
  output link_bit;

  /* AUTOREG */

`include "oper_type.vh"

  wire depend_rt, depend_rs;
  wire [3:0] actual_preds, actual_scoreboard;


  //each execute unit will only take the bits of this that it needs
  //execute units will be responsible for discovering invalid opcodes
  assign execute_opcode = {inst[23:19], inst[13:10]};

  assign rt_num = inst[18:14];
  assign rs_num = inst[4:0];
  assign rd_num = inst[9:5];
  assign link_bit = inst[25];
  assign op1 = rt_data;
  assign actual_preds = {1'b1, preds};
  assign actual_scoreboard = {1'b0, pred_scoreboard};


  //this is going to be enormous...
  //Also needs a pass to make it comprehensible
  always @(/*AUTOSENSE*/OPER_TYPE_ALU or OPER_TYPE_BRANCH
	   or OPER_TYPE_LSU or OPER_TYPE_OTHER or actual_preds
	   or execute_opcode or inst or nextinst or rs_data or rt_data) begin
	   
    rd_we = 0;
    pred_we = 0;
    oper_type = OPER_TYPE_ALU; 
    shift_amount = 6'd0;
    shift_type = 2'b00;
    long_imm = 0;
    op2 = 32'd0;


    if((actual_preds[inst[31:30]] ^ inst[29]) & ~prev_long_imm) begin
      
      if(~inst[28]) begin // alu short
        rd_we = execute_opcode[3:0] != 4'b1111;
        pred_we = ~rd_we;
        
        if(execute_opcode[3:0] == 4'b0111) begin // MOV
          //16 bit constant with optional shift
          op2[15:0] = {inst[27:15], inst[4:0]};
          shift_type = 2'b00;
          shift_amount = {0, inst[14], 4'b0000};
        end
        else begin
          //rotated immediate
          op2[9:0] = inst[27:18];
          shift_type = 2'b11;
          shift_amount = {0, inst[17:14], 1'b0};
          depend_rs = 1;
        end
        
      end

      else if(inst[27:26] == 2'b01) begin //alu reg
        op2 = rs_data;
        rd_we = execute_opcode[3:0] != 4'b1111;
        pred_we = ~rd_we;
        shift_amount = {0, inst[25:21]};
        shift_type = inst[20:19];
        depend_rs = 1;
        depend_rt = execute_opcode[3:0] != 4'b0111; // not MOV
      end

      else if(inst[27:25] == 3'b001) begin // load/store
        oper_type = OPER_TYPE_LSU;
        rd_we = ~execute_opcode[2]; // load
        depend_rs = 1;
        op2[11:0] = inst[24:13];
      end

      else if(inst[27]) begin // branch
        oper_type = OPER_TYPE_BRANCH;
        if(inst[26]) begin // register
          depend_rs = 1;
          op2[23:4] = inst[24:5];
        end
        else //immediate
          op2[28:4] = inst[24:0];
      end

      else if(inst[24]) begin // other
        oper_type = OPER_TYPE_OTHER;
        depend_rs = 1;
        depend_rt = 1; //TODO are both of these always true?
        op2 = rs_data;
      end
      
      else if(inst[23]) begin //shift
        oper_type = OPER_TYPE_ALU;
        depend_rs = 1;
        shift_type = inst[20:19];
        //we don't actually care what the whole value is, only if it's >= 32 
        shift_amt = inst[22] ? {|rt_data[31:5], rt_data[4:0]} : inst[18:14];
        op2 = rs_data;
      end
      
      else begin //ALU long immediate
        oper_type = OPER_TYPE_ALU;
        op2 = nextinst;
        long_imm = 1;
        depend_rs = execute_opcode[3:0] != 4'b0111; // not MOV
      end

    end
  end

  assign stall = (depend_rt & reg_scoreboard[rt_num]) |
                 (depend_rs & reg_scoreboard[rs_num]) |  
                 (actual_scoreboard[inst[31:30]]) |
                 (rd_we & reg_scoreboard[rd_num]) |
                 (pred_we & rd_num < 5'd3 & pred_scoreboard[rd_num]);

endmodule
