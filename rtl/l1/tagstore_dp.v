module tagstore_dp(
  addr_a,
  addr_b,
  data_a,
  data_b,
  wr_a,
  wr_b,
  clk,
  rst_n,
  q_a,
  q_b
);

parameter addr_width = 0;
parameter data_width = 0;

input  wire [addr_width - 1:0] addr_a;
input  wire [addr_width - 1:0] addr_b;
input  wire [data_width - 1:0] data_a;
input  wire [data_width - 1:0] data_b;
input  wire                    wr_a;
input  wire                    wr_b;
input  wire                    clk;
input  wire                    rst_n;

output wire [data_width - 1:0] q_a;
output wire [data_width - 1:0] q_b;

altsyncram
  #(
    .byte_size(data_width),
    .widthad_a(addr_width),
    .width_a(data_width),
    .width_byteena_a(1),
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
    .byteena_a (1'b1),
    .byteena_b (1'b1),
    .q_a (q_a),
    .q_b (q_b),
    .wren_a (wr_a),
    .wren_b (wr_b),
    .clock0 (clk),
    .clocken0 (rst_n)
);

endmodule
