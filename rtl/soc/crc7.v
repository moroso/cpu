`timescale 1 ps / 1 ps

module crc7(output[6:0] out,
            input clk,
            input dat,
            input rst,
            input en);
   reg [6:0]      state = 0;

   assign out = {
                 state[6] ^ state[3],
                 state[6] ^ state[5] ^ state[2],
                 state[5] ^ state[4] ^ state[1],
                 state[4] ^ state[3] ^ state[0],
                 state[6] ^ state[2],
                 state[5] ^ state[1],
                 state[4] ^ state[0]
                 };

   always @(posedge clk) begin
      if (rst)
        state <= {6'b0, dat};
      else if (en)
        state <= {state[5],
                  state[4],
                  state[3],
                  state[2] ^ state[6],
                  state[1],
                  state[0],
                  dat ^ state[6]};
   end
endmodule // crc7
