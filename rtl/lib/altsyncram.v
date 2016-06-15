// This is a dummy module that replicates the features of the altsyncram megafunction
// that we need to use for simulation.



module altsyncram(/*AUTOARG*/
   // Outputs
   q_a, q_b,
   // Inputs
   wren_a, wren_b, data_a, data_b, address_a, address_b, byteena_a,
   clock0, clock1, clocken0, clocken1
   );

  parameter OPERATION_MODE = "BIDIR_DUAL_PORT";
  parameter WIDTH_A = 32;
  parameter WIDTH_B = 128;
  parameter WIDTHAD_A = 14;
  parameter WIDTHAD_B = 12;
  parameter INIT_FILE = "bootrom.hex";
  parameter INIT_FILE_LAYOUT = "PORT_A";

  input wren_a, wren_b;
  input [31:0] data_a;
  input [127:0] data_b;
  input [13:0] address_a;
  input [11:0] address_b;
  input [3:0] byteena_a;
  input clock0, clock1;
  input clocken0, clocken1;

  output reg [31:0] q_a;
  output reg [127:0] q_b;

  reg [WIDTH_A-1:0] ram[1<<WIDTHAD_A-1:0];

  initial $readmemh("bootrom.hex", ram);
  wire writemask0;
  assign writemask0 = {{8{byteena_a[3]}},{8{byteena_a[2]}},{8{byteena_a[1]}},{8{byteena_a[0]}}};
  always @(posedge clock0) begin
    if(clocken0) begin
      q_a <= ram[address_a];
      if(wren_a) ram[address_a] <= (data_a & writemask0) | (ram[address_a] & ~writemask0);
    end
  end

  always @(posedge clock1) begin
    if(clocken1) begin
      q_b[31:0] <= ram[address_b * 4];
      q_b[63:32] <= ram[address_b * 4 + 1];
      q_b[95:64] <= ram[address_b * 4 + 2];
      q_b[127:96] <= ram[address_b * 4 + 3];
    end
  end

endmodule
