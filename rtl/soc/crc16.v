module crc16(output [15:0] out,
             input clk,
             input dat,
             input rst,
             input en);

   reg [15:0]      state = 0;

   assign out = {
    state[16'h3] ^ state[16'h7] ^ state[16'ha] ^ state[16'hb],
    state[16'h2] ^ state[16'h6] ^ state[16'h9] ^ state[16'ha],
    state[16'h1] ^ state[16'h5] ^ state[16'h8] ^ state[16'h9],
    state[16'h0] ^ state[16'h4] ^ state[16'h7] ^ state[16'h8] ^ state[16'hf],
    state[16'h6] ^ state[16'ha] ^ state[16'hb] ^ state[16'he] ^ state[16'hf],
    state[16'h5] ^ state[16'h9] ^ state[16'ha] ^ state[16'hd] ^ state[16'he],
    state[16'h4] ^ state[16'h8] ^ state[16'h9] ^ state[16'hc] ^ state[16'hd]
                 ^ state[16'hf],
    state[16'h3] ^ state[16'h7] ^ state[16'h8] ^ state[16'hb] ^ state[16'hc]
                 ^ state[16'he] ^ state[16'hf],
    state[16'h2] ^ state[16'h6] ^ state[16'h7] ^ state[16'ha] ^ state[16'hb]
                 ^ state[16'hd] ^ state[16'he] ^ state[16'hf],
    state[16'h1] ^ state[16'h5] ^ state[16'h6] ^ state[16'h9] ^ state[16'ha]
                 ^ state[16'hc] ^ state[16'hd] ^ state[16'he],
    state[16'h0] ^ state[16'h4] ^ state[16'h5] ^ state[16'h8] ^ state[16'h9]
                 ^ state[16'hb] ^ state[16'hc] ^ state[16'hd],
    state[16'h4] ^ state[16'h8] ^ state[16'hc] ^ state[16'hf],
    state[16'h3] ^ state[16'h7] ^ state[16'hb] ^ state[16'he] ^ state[16'hf],
    state[16'h2] ^ state[16'h6] ^ state[16'ha] ^ state[16'hd] ^ state[16'he],
    state[16'h1] ^ state[16'h5] ^ state[16'h9] ^ state[16'hc] ^ state[16'hd],
    state[16'h0] ^ state[16'h4] ^ state[16'h8] ^ state[16'hb] ^ state[16'hc]
   };

   always @(posedge clk) begin
      if (rst)
        state <= {6'b0, dat};
      else if (en)
        state <= {state[14],
                  state[13],
                  state[12],
                  state[11] ^ state[15],
                  state[10],
                  state[9],
                  state[8],
                  state[7],
                  state[6],
                  state[5],
                  state[4] ^ state[15],
                  state[3],
                  state[2],
                  state[1],
                  state[0],
                  dat ^ state[15]};
   end
endmodule
