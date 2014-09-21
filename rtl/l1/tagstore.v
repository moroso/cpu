module tagstore(
  addr,
  data,
  wr,
  clk,
  rst_n,
  q
);

parameter addr_width = 0;
parameter data_width = 0;

input  wire [addr_width - 1:0] addr;
input  wire [data_width - 1:0] data;
input  wire                    wr;
input  wire                    clk;
input  wire                    rst_n;

output wire [data_width - 1:0] q;

altsyncram
  #(
    .byte_size(data_width),
    .widthad_a(addr_width),
    .width_a(data_width),
    .width_byteena_a(1),
    .lpm_type("altsyncram"),
    .operation_mode("SINGLE_PORT"),
    .outdata_reg_a("UNREGISTERED"),
    .ram_block_type("AUTO"),
    .read_during_write_mode_mixed_ports("DONT_CARE")
  )
  the_altsyncram (
    .address_a (addr),
    .data_a (data),
    .byteena_a (1'b1),
    .q_a (q),
    .wren_a (wr),
    .clock0 (clk),
    .clocken0 (rst_n)
);

endmodule
