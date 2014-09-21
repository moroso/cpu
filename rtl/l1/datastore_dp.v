module datastore_dp(
  addr_a,
  addr_b,
  data_a,
  data_b,
  byte_enable_a,
  byte_enable_b,
  wr_a,
  wr_b,
  clk,
  rst_n,
  q_a,
  q_b
);

parameter addr_width = 0;

input  wire [addr_width - 1:0] addr_a;
input  wire [addr_width - 1:0] addr_b;
input  wire [31:0]             data_a;
input  wire [31:0]             data_b;
input  wire [3:0]              byte_enable_a;
input  wire [3:0]              byte_enable_b;
input  wire                    wr_a;
input  wire                    wr_b;
input  wire                    clk;
input  wire                    rst_n;

output wire [31:0]             q_a;
output wire [31:0]             q_b;

altsyncram
  #(
    .byte_size(8),
    .widthad_a(addr_width),
    .width_a(32),
    .width_byteena_a(4),
    .lpm_type("altsyncram"),
    .operation_mode("BIDIR_DUAL_PORT"),
    .outdata_reg_a("UNREGISTERED"),
    .ram_block_type("AUTO"),
    .read_during_write_mode_mixed_ports("DONT_CARE")
  )
  the_altsyncram (
    .address_a (addr_a),
    .address_b (addr_b),
    .data_a (data_a),
    .data_b (data_b),
    .byteena_a (byte_enable_a),
    .byteena_b (byte_enable_b),
    .q_a (q_a),
    .q_b (q_b),
    .wren_a (wr_a),
    .wren_b (wr_b),
    .clock0 (clk),
    .clocken0 (rst_n)
);

endmodule
