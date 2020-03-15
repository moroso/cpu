`timescale 1 ns / 1 ps

// Single-port (with simultaneous read and write) RAM without byte-enable.
// A write and simultaneous read with the same address, on the same port,
// will return the *new* value.
module sp_bram
  (/*AUTOARG*/
   // Outputs
   q,
   // Inputs
   data, addr, we, clk
   );
   parameter DATA_WIDTH = 8;
   parameter ADDR_WIDTH = 6;

   input [(DATA_WIDTH-1):0]      data;
   input [(ADDR_WIDTH-1):0]      addr;
   input                         we, clk;
   output reg [(DATA_WIDTH-1):0] q;

   // Declare the RAM variable
   reg [DATA_WIDTH-1:0]          ram[2**ADDR_WIDTH-1:0];
   always @ (posedge clk)
     begin // Port A
        if (we)
          begin
             ram[addr] <= data;
             q <= data;
          end
        else
          q <= ram[addr];
     end
endmodule
