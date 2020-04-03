`timescale 1 ns / 1 ps
/* Instruction l1 cache.
 * Virtually indexed, physically tagged.
 */

module MCPU_MEM_il1c(
                     input 	    clkrst_mem_clk,
                     input 	    clkrst_mem_rst_n,

                     // Control interface
                     // Addresses are packet-aligned (16 byte).
                     input [31:4]   il1c_addr,
                     input 	    il1c_re,
                     output [127:0] il1c_packet,
                     output 	    il1c_ready,

                     // TLB interface
                     output [31:12] il1c2tlb_addr,
                     output reg     il1c2tlb_re,

                     input [3:0]    il1c2tlb_flags,
                     input [31:12]  il1c2tlb_phys_addr,
                     input 	    il1c2tlb_ready,

                     // Atom interface to arb
                     output reg     il1c2arb_valid,
                     output [2:0]   il1c2arb_opcode,
                     output [31:5]  il1c2arb_addr,

                     // TODO: remove these two; we don't need them.
                     output [255:0] il1c2arb_wdata,
                     output [31:0]  il1c2arb_wbe,

                     input [255:0]  il1c2arb_rdata,
                     input 	    il1c2arb_rvalid,
                     input 	    il1c2arb_stall
                     );
  // Cache lines are 32 bytes (256 bits), the same as in the l2 cache.
  // This is large enough for two packets.
  localparam LINE_SIZE = 32 * 8;
  // Number of bits required to address a specific byte within a line.
  localparam LINE_SIZE_ADDR_BITS = 5;

  // Number of bits required to refer to an address that can be cached
  // (that is, a line-sized chunk of memory). This will end up being
  // the sum of the set and tag widths.
  localparam LINE_ADDR_SIZE = 32 - LINE_SIZE_ADDR_BITS;

  // It's important that the set be contained entirely within the
  // virtual part of the address (so, it's limited to 10 bits).
  localparam SET_WIDTH = 4;
  localparam NUM_SETS = 16;
  localparam TAG_WIDTH = LINE_ADDR_SIZE - SET_WIDTH;


  localparam STATE_BITS = 3; // TODO

  localparam STATE_DEFAULT = 0;
  localparam STATE_READ = 1;
  localparam STATE_WAIT_UPDATE = 2;


  wire [31:4] 			    addr_0a = il1c_addr;
  reg [31:4] 			    addr_1a;

  reg 				    stall;
  wire [22:0] 			    q_tag;
  reg [NUM_SETS - 1:0] 		    valid;

  reg [STATE_BITS-1:0] 		    state;
  reg [STATE_BITS-1:0] 		    nextstate;

  // TLB reads are always for the same address as the cache read (since
  // the TLB access starts on the first cycle of a request).
  assign il1c2tlb_addr = addr_0a[31:12];
  // Reads from the arb are always from the latched address, since
  // they can never happen on the first cycle of a request.
  assign il1c2arb_addr = {{il1c2tlb_phys_addr, addr_1a[11:5]}};

  // Always doing reads from the arb, if anything.
  assign il1c2arb_opcode = 0; // TODO

  wire 				    re_0a = il1c_re;
  reg 				    re_1a;

  // We're ready if we're not stalled.
  assign il1c_ready = ~stall;

  wire [SET_WIDTH-1:0] 		    set_0a = addr_0a[31-TAG_WIDTH-:SET_WIDTH];
  wire 				    offs_0a = addr_0a[31-TAG_WIDTH-SET_WIDTH];

  // The tag spans the page part of the address as well as the
  // page offset part of the address, so we need both here.
  wire [TAG_WIDTH-1:0] 		    tag_1a = {{il1c2tlb_phys_addr[31:12],
					       addr_1a[11-:TAG_WIDTH-(32-12)]}};
  wire [SET_WIDTH-1:0] 		    set_1a = addr_1a[31-TAG_WIDTH-:SET_WIDTH];
  wire 				    offs_1a = addr_1a[31-TAG_WIDTH-SET_WIDTH];

  wire 				    hit_1a = (q_tag == tag_1a) & valid[set_1a];

  wire [255:0] 			    q_data; // from data bram

  // At the end of a lookup, return what the arb gave us instead of
  // what's in the cache memory.
  wire [255:0] 			    line = (state == STATE_DEFAULT ? q_data : il1c2arb_rdata);
  assign il1c_packet = line[{{offs_1a}, {7'b0}}+:128];

  // If we've stalled, keep reading from the old address; otherwise, read
  // from a new one.
  wire [SET_WIDTH-1:0] 		    data_addr = (stall | ~re_0a) ? set_1a : set_0a;

  reg 				    update_cache;

  always @(*) begin
     nextstate = state;
     il1c2arb_valid = 0;
     stall = 0;
     update_cache = 0;
     il1c2tlb_re = 0;

     case (state)
       STATE_DEFAULT: begin
          if (re_1a)
            if (~il1c2tlb_ready) begin
               // We're blocked on the TLB.
               stall = 1;
            end else begin
               if (~hit_1a) begin
                  // A read was in progress, but it missed.
                  nextstate = STATE_READ;
                  il1c2arb_valid = 1;
                  stall = 1;
               end
            end // else: !if(~il1c2tlb_ready)

          if (re_0a & ~stall) begin
             // We're done with the last request, and a new one came in.
             il1c2tlb_re = 1;
          end
       end
       STATE_READ: begin
          if (il1c2arb_rvalid) begin
             nextstate = STATE_WAIT_UPDATE;
             update_cache = 1;
             stall = 1;
          end else begin
             stall = 1;
             il1c2arb_valid = 1;
          end
       end // case: STATE_READ
       STATE_WAIT_UPDATE: begin
          // We need one cycle for the write to complete before we can
          // read it.
          // We could change things around to save this cycle, but it
          // would make the cache a bit more complicated.
          nextstate = STATE_DEFAULT;
          stall = 0;
          il1c2tlb_re = re_0a;
       end
     endcase
  end // always @ (*)

  always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
     if (~clkrst_mem_rst_n) begin
        valid <= 0;
        re_1a <= 0;
        state <= STATE_DEFAULT;
     end else begin
        if (~stall & re_0a) begin
           // Latch new values
           addr_1a <= addr_0a;
           re_1a <= re_0a;
        end

        if (update_cache) begin
           valid[set_1a] <= 1;
        end

        state <= nextstate;
     end
  end

  sp_bram #(
            .DATA_WIDTH(LINE_SIZE),
            .ADDR_WIDTH(SET_WIDTH)
            ) data_bram (
                         // Outputs
                         .q                     (q_data),
                         // Inputs
                         // Always storing what we got from the arb.
                         .data                  (il1c2arb_rdata),
                         .addr                  (data_addr),
                         .we                    (update_cache),
                         .clk                   (clkrst_mem_clk));

  sp_bram #(
            .DATA_WIDTH(TAG_WIDTH),
            .ADDR_WIDTH(SET_WIDTH)
            ) tag_bram (
                        .q (q_tag),
                        // Inputs
                        .data                (tag_1a),
                        .addr                (data_addr),
                        .we                  (update_cache),
                        .clk                 (clkrst_mem_clk));

endmodule
