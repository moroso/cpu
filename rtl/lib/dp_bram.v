`timescale 1 ns / 1 ps

// True dual-port RAM without byte-enable.
// Taken from Quartus HDL Coding Style Handbook, so this should result in
// inferred block RAMs.
// A write and simultaneous read with the same address, on the same port,
// will return the *new* value.
module dp_bram
  (
   input [(DATA_WIDTH-1):0]      data_a, data_b,
   input [(ADDR_WIDTH-1):0]      addr_a, addr_b,
   input                         we_a, we_b, clk,
   output reg [(DATA_WIDTH-1):0] q_a, q_b
   );
   parameter DATA_WIDTH = 8;
   parameter ADDR_WIDTH = 6;

   // Declare the RAM variable
   reg [DATA_WIDTH-1:0]          ram[2**ADDR_WIDTH-1:0];
   always @ (posedge clk)
     begin // Port A
        if (we_a)
          begin
             ram[addr_a] <= data_a;
             q_a <= data_a;
          end
        else
          q_a <= ram[addr_a];
     end
   always @ (posedge clk)
     begin // Port b
        if (we_b)
          begin
             ram[addr_b] <= data_b;
             q_b <= data_b;
          end
        else
          q_b <= ram[addr_b];
     end
endmodule
