`timescale 1 ps / 1 ps

module MCPU_CORE_decode(/*AUTOARG*/
   // Outputs
   d2pc_out_execute_opcode, d2pc_out_shift_type,
   d2pc_out_shift_amount, d2pc_out_oper_type, d2pc_out_rd_num,
   d2pc_out_rd_we, d2pc_out_pred_we, d2rf_rs_num, d2rf_rt_num,
   d2pc_out_sop, d2pc_out_lsu_offset, dep_stall, long_imm,
   d2pc_out_invalid, d2pc_out_branchreg,
   // Inputs
   inst, preds, sb2d_reg_scoreboard, sb2d_pred_scoreboard,
   rf2d_rs_data, rf2d_rt_data, nextinst, prev_long_imm
   );

  input [31:0] inst;
  input [2:0] preds;
  input [31:0] sb2d_reg_scoreboard;
  input [2:0] sb2d_pred_scoreboard;
  input [31:0] rf2d_rs_data, rf2d_rt_data;
  input [31:0] nextinst;
  input prev_long_imm;

  output wire [8:0] d2pc_out_execute_opcode;
  output reg [1:0] d2pc_out_shift_type;
  output reg [5:0] d2pc_out_shift_amount;
  output reg [1:0] d2pc_out_oper_type;
  output reg [4:0] d2pc_out_rd_num;
  output reg d2pc_out_rd_we;
  output reg d2pc_out_pred_we;
  output [4:0] d2rf_rs_num, d2rf_rt_num;
  output reg [31:0] d2pc_out_sop;
  output [11:0] d2pc_out_lsu_offset;
  output wire dep_stall;
  output reg long_imm;
  output reg d2pc_out_invalid;
  output reg d2pc_out_branchreg;

  /* AUTOREG */

`include "oper_type.vh"
`include "coproc_ops.vh"

  reg depend_rt, depend_rs;
  wire [3:0] actual_preds, actual_scoreboard;


  //each execute unit will only take the bits of this that it needs
  //execute units will be responsible for discovering invalid opcodes
  assign d2pc_out_execute_opcode = {inst[23:19], inst[13:10]};

  assign d2rf_rt_num = inst[18:14];
  assign d2rf_rs_num = inst[4:0];
  assign actual_preds = {1'b1, preds};
  assign actual_scoreboard = {1'b0, sb2d_pred_scoreboard};
  assign d2pc_out_lsu_offset = d2pc_out_execute_opcode[2] ? {inst[24:19], inst[13], inst[9:5]} : inst[24:13];
  assign dep_stall = (depend_rt & sb2d_reg_scoreboard[d2rf_rt_num]) |
                     (depend_rs & sb2d_reg_scoreboard[d2rf_rs_num]) |
                     (actual_scoreboard[inst[31:30]]) |
                     (d2pc_out_rd_we & sb2d_reg_scoreboard[d2pc_out_rd_num]) |
                     (d2pc_out_pred_we & actual_scoreboard[d2pc_out_rd_num[1:0]]);



  //this is going to be enormous...
  //Also needs a pass to make it comprehensible
  always @(/*AUTOSENSE*/COPROC_OP_BREAK or COPROC_OP_DIV
	   or COPROC_OP_ERET or COPROC_OP_FENCE or COPROC_OP_FLUSH
	   or COPROC_OP_MFC or COPROC_OP_MFHI or COPROC_OP_MTC
	   or COPROC_OP_MTHI or COPROC_OP_MULT or COPROC_OP_SYSCALL
	   or OPER_TYPE_ALU or OPER_TYPE_BRANCH or OPER_TYPE_LSU
	   or OPER_TYPE_OTHER or actual_preds
	   or d2pc_out_execute_opcode or inst or nextinst
	   or prev_long_imm or rf2d_rs_data or rf2d_rt_data) begin

    d2pc_out_rd_num = inst[9:5];
    d2pc_out_rd_we = 0;
    d2pc_out_pred_we = 0;
    d2pc_out_oper_type = OPER_TYPE_ALU;
    d2pc_out_shift_amount = 6'd0;
    d2pc_out_shift_type = 2'b00;
    d2pc_out_sop = 32'd0;
    depend_rs = 0;
    depend_rt = 0;
    d2pc_out_invalid = 0;
    d2pc_out_rd_we = 0;
    d2pc_out_pred_we = 0;
    d2pc_out_branchreg = 0;

    long_imm = inst[28:14] == 15'b100000000000000;

    if((actual_preds[inst[31:30]] ^ inst[29]) & ~prev_long_imm) begin

      if(~inst[28]) begin // alu short
        d2pc_out_rd_we = d2pc_out_execute_opcode[3:0] != 4'b0111; //write predicate on compares, to register otherwise
        d2pc_out_pred_we = ~d2pc_out_rd_we;
        d2pc_out_shift_type = 2'b11;
        d2pc_out_shift_amount = {1'b0, inst[17:14], 1'b0};
        d2pc_out_sop[9:0] = inst[27:18];

        if(d2pc_out_execute_opcode[3]) begin //1-op
          d2pc_out_sop[14:10] = inst[4:0];
        end
        else begin
          depend_rs = 1;
        end

      end

      else if(inst[27:26] == 2'b01) begin //alu reg
        d2pc_out_sop = rf2d_rt_data;
        d2pc_out_rd_we = d2pc_out_execute_opcode[3:0] != 4'b0111;
        d2pc_out_pred_we = ~d2pc_out_rd_we;
        d2pc_out_shift_amount = {1'b0, inst[25:21]};
        d2pc_out_shift_type = inst[20:19];
        depend_rt = 1;
        depend_rs = ~d2pc_out_execute_opcode[3]; // 2-op
      end

      else if(inst[27:25] == 3'b001) begin // load/store
        d2pc_out_oper_type = OPER_TYPE_LSU;
        d2pc_out_sop = rf2d_rt_data;
        d2pc_out_rd_we = ~d2pc_out_execute_opcode[2];
        depend_rs = 1;
        depend_rt = d2pc_out_execute_opcode[2];
        if(d2pc_out_execute_opcode[2:0] == 3'b111) begin
          d2pc_out_pred_we = 1;
          d2pc_out_rd_num = 5'b0;
        end
      end

      else if(inst[27]) begin // branch
        d2pc_out_oper_type = OPER_TYPE_BRANCH;
        d2pc_out_rd_num = 5'd31;
        d2pc_out_rd_we = inst[25];
        d2pc_out_branchreg = inst[26];
        if(inst[26]) begin // register
          depend_rs = 1;
          d2pc_out_sop[27:0] = {{8{inst[24]}}, inst[24:5]};
        end
        else //immediate
          d2pc_out_sop[27:0] = {{3{inst[24]}}, inst[24:0]};
      end

      else if(inst[24]) begin // other

        d2pc_out_oper_type = OPER_TYPE_OTHER;
        d2pc_out_sop = rf2d_rt_data;
        case(d2pc_out_execute_opcode[8:5])
          COPROC_OP_BREAK: begin end
          COPROC_OP_SYSCALL: begin end
          COPROC_OP_FENCE: begin end
          COPROC_OP_ERET: begin end
          COPROC_OP_FLUSH: begin
            depend_rs = 1;
          end
          COPROC_OP_MFC: begin
            d2pc_out_rd_we = 1;
          end
          COPROC_OP_MTC: begin
            depend_rs = 1;
          end
          COPROC_OP_MULT: begin
            depend_rs = 1;
            depend_rt = 1;
            d2pc_out_rd_we = 1;
          end
          COPROC_OP_DIV: begin
            depend_rs = 1;
            depend_rt = 1;
            d2pc_out_rd_we = 1;
          end
          COPROC_OP_MFHI: begin
            d2pc_out_rd_we = 1;
          end
          COPROC_OP_MTHI: begin
            depend_rs = 1;
          end
          default: begin
            d2pc_out_invalid = 1;
          end
        endcase
      end

      else if(|inst[23:22]) begin
        d2pc_out_invalid = 1;
      end

      else if(inst[21]) begin //shift
        d2pc_out_oper_type = OPER_TYPE_ALU;
        depend_rs = 1;
        depend_rt = 1;
        d2pc_out_rd_we = 1;
        d2pc_out_shift_type = inst[20:19];
        //we don't actually care what the whole value is, only if it's >= 32
        d2pc_out_shift_amount = {|rf2d_rs_data[31:5], rf2d_rs_data[4:0]};
        d2pc_out_sop = rf2d_rt_data;
      end

      else if(|inst[20:14]) begin
        d2pc_out_invalid = 1;
      end

      else begin //ALU long immediate
        d2pc_out_oper_type = OPER_TYPE_ALU;
        d2pc_out_sop = nextinst;
        depend_rs = ~d2pc_out_execute_opcode[3];
        d2pc_out_pred_we = d2pc_out_execute_opcode[3:0] == 4'b0111; // COMPARE
        d2pc_out_rd_we = ~d2pc_out_pred_we;
      end
    end
  end

endmodule
