module MCPU_MEM_dl1c(
                     input 		clkrst_mem_clk,
                     input 		clkrst_mem_rst_n,

                     // Control interface
                     // Addresses are word-aligned (4 byte), and all reads
                     // will give an (aligned) word of data.
                     input [31:2] 	dl1c_addr_a,
                     input [31:2] 	dl1c_addr_b,
                     input 		dl1c_re_a,
                     input 		dl1c_re_b,
                     input [3:0] 	dl1c_we_a,
                     input [3:0] 	dl1c_we_b,
                     input [31:0] 	dl1c_in_a,
                     input [31:0] 	dl1c_in_b,
                     output [31:0] 	dl1c_out_a,
                     output [31:0] 	dl1c_out_b,
                     output 		dl1c_ready,

                     // Peripheral interface
                     output reg [31:2] 	dl1c2periph_addr,
                     output reg 	dl1c2periph_re,
                     output reg [3:0] 	dl1c2periph_we,
                     output reg [31:0] 	dl1c2periph_data_out,
                     input [31:0] 	dl1c2periph_data_in,
                     // TODO: stall signal for periph interface?
                     // Seems like it might not be necessary; all periph
                     // register reads/writes should be doable in a single
                     // cycle.

                     // Atom interface to arb
                     output reg 	dl1c2arb_valid,
                     output reg [2:0] 	dl1c2arb_opcode,
                     output reg [31:5] 	dl1c2arb_addr,

                     output reg [255:0] dl1c2arb_wdata,
                     output reg [31:0] 	dl1c2arb_wbe,

                     input [255:0] 	dl1c2arb_rdata,
                     input 		dl1c2arb_rvalid,
                     input 		dl1c2arb_stall

                     );

`include "MCPU_MEM_ltc.vh"

  localparam WAYS = 2;

  // Cache lines are 32 bytes (256 bits), the same as in the l2 cache.
  localparam LINE_SIZE_BYTES = 32;
  localparam LINE_SIZE = LINE_SIZE_BYTES * 8;
  // Number of bits required to address a specific byte within a line.
  localparam LINE_SIZE_ADDR_BITS = 5;
  // And to specify a specific word
  localparam LINE_SIZE_WORD_ADDR_BITS = 3;

  // Number of bits required to refer to an address that can be cached
  // (that is, a line-sized chunk of memory). This will end up being
  // the sum of the set and tag widths.
  localparam LINE_ADDR_SIZE = 32 - LINE_SIZE_ADDR_BITS; // 27

  localparam SET_WIDTH = 4;
  localparam NUM_SETS = 16;
  localparam TAG_WIDTH = LINE_ADDR_SIZE - SET_WIDTH; // 23

  wire [31:2] 				addr_a_0a = dl1c_addr_a;
  wire [31:2] 				addr_b_0a = dl1c_addr_b;
  reg [31:2] 				addr_a_1a;
  reg [31:2] 				addr_b_1a;

  wire 					is_periph_a_0a = addr_a_0a[31];
  wire 					is_periph_b_0a = addr_b_0a[31];
  wire 					is_periph_a_1a = addr_a_1a[31];
  wire 					is_periph_b_1a = addr_b_1a[31];

  reg [31:0] 				periph_result_a;
  reg [31:0] 				periph_result_b;

  wire [SET_WIDTH-1:0] 			set_a_0a = addr_a_0a[31-TAG_WIDTH-:SET_WIDTH];
  wire [LINE_SIZE_WORD_ADDR_BITS-1:0] 	offs_a_0a = addr_a_0a[31-TAG_WIDTH-SET_WIDTH
                                                              -:LINE_SIZE_WORD_ADDR_BITS];
  wire [TAG_WIDTH-1:0] 			tag_a_1a = addr_a_1a[31-:TAG_WIDTH];
  wire [SET_WIDTH-1:0] 			set_a_1a = addr_a_1a[31-TAG_WIDTH-:SET_WIDTH];
  wire [LINE_SIZE_WORD_ADDR_BITS-1:0] 	offs_a_1a = addr_a_1a[31-TAG_WIDTH-SET_WIDTH
                                                              -:LINE_SIZE_WORD_ADDR_BITS];

  wire [SET_WIDTH-1:0] 			set_b_0a = addr_b_0a[31-TAG_WIDTH-:SET_WIDTH];
  wire [LINE_SIZE_WORD_ADDR_BITS-1:0] 	offs_b_0a = addr_b_0a[31-TAG_WIDTH-SET_WIDTH
                                                              -:LINE_SIZE_WORD_ADDR_BITS];
  wire [TAG_WIDTH-1:0] 			tag_b_1a = addr_b_1a[31-:TAG_WIDTH];
  wire [SET_WIDTH-1:0] 			set_b_1a = addr_b_1a[31-TAG_WIDTH-:SET_WIDTH];
  wire [LINE_SIZE_WORD_ADDR_BITS-1:0] 	offs_b_1a = addr_b_1a[31-TAG_WIDTH-SET_WIDTH
                                                              -:LINE_SIZE_WORD_ADDR_BITS];

  reg 					latch_inputs;
  reg 					read_addr_imm;

  wire [LINE_SIZE-1:0] 			q_data_a[WAYS-1:0];
  wire [LINE_SIZE-1:0] 			q_data_b[WAYS-1:0];
  wire [TAG_WIDTH-1:0] 			q_tag_a[WAYS-1:0];
  wire [TAG_WIDTH-1:0] 			q_tag_b[WAYS-1:0];

  reg [WAYS-1:0] 			bram_we_a;
  reg [WAYS-1:0] 			bram_we_b;

  wire [SET_WIDTH-1:0] 			bram_addr_a = read_addr_imm ? set_a_0a : set_a_1a;
  wire [SET_WIDTH-1:0] 			bram_addr_b = read_addr_imm ? set_b_0a : set_b_1a;
  reg [LINE_SIZE-1:0] 			data_data_a;
  reg [LINE_SIZE-1:0] 			data_data_b;
  wire [TAG_WIDTH-1:0] 			data_tag_a = tag_a_1a;
  wire [TAG_WIDTH-1:0] 			data_tag_b = tag_b_1a;

  reg [NUM_SETS-1:0] 			valid[WAYS-1:0];
  reg [NUM_SETS-1:0] 			next_valid[WAYS-1:0];
  reg [NUM_SETS-1:0] 			evict = 0;
  reg [NUM_SETS-1:0] 			next_evict = 0;

  wire [1:0] 				hit_a_way_1a = {{(q_tag_a[1] == tag_a_1a) & valid[1][set_a_1a],
							 (q_tag_a[0] == tag_a_1a) & valid[0][set_a_1a]}};
  wire [1:0] 				hit_b_way_1a = {{(q_tag_b[1] == tag_b_1a) & valid[1][set_b_1a],
							 (q_tag_b[0] == tag_b_1a) & valid[0][set_b_1a]}};

  wire 					hit_a_1a = |hit_a_way_1a;
  wire 					hit_b_1a = |hit_b_way_1a;

  // If hit_*_1a is set, this will give us the index of the way that hits.
  // (This will always be the same as whether way 1 hit.)
  wire 					hit_idx_a_1a = hit_a_way_1a[1];
  wire 					hit_idx_b_1a = hit_b_way_1a[1];

  wire 					dl1c_re_a_0a = dl1c_re_a;
  wire 					dl1c_re_b_0a = dl1c_re_b;
  wire [3:0] 				dl1c_we_a_0a = dl1c_we_a;
  wire [3:0] 				dl1c_we_b_0a = dl1c_we_b;
  wire [31:0] 				dl1c_in_a_0a = dl1c_in_a;
  wire [31:0] 				dl1c_in_b_0a = dl1c_in_b;

  reg 					dl1c_re_a_1a = 0;
  reg 					dl1c_re_b_1a = 0;
  reg [3:0] 				dl1c_we_a_1a = 0;
  reg [3:0] 				dl1c_we_b_1a = 0;

  reg 					read_a;
  reg 					read_b;

  reg 					write_a;
  reg 					write_b;

  reg 					periph_op_a;
  reg 					periph_op_b;

  wire 					dl1c_req_a_0a = dl1c_re_a_0a | |dl1c_we_a_0a;
  wire 					dl1c_req_b_0a = dl1c_re_b_0a | |dl1c_we_b_0a;
  wire 					dl1c_req_a_1a = dl1c_re_a_1a | |dl1c_we_a_1a;
  wire 					dl1c_req_b_1a = dl1c_re_b_1a | |dl1c_we_b_1a;
  wire 					dl1c_req_1a = dl1c_req_a_1a | dl1c_req_b_1a;

  reg 					write_a_remaining;
  reg 					write_b_remaining;
  reg 					next_write_a_remaining;
  reg 					next_write_b_remaining;

  reg 					read_a_remaining;
  reg 					read_b_remaining;
  reg 					next_read_a_remaining;
  reg 					next_read_b_remaining;

  reg 					periph_a_remaining;
  reg 					periph_b_remaining;
  reg 					next_periph_a_remaining;
  reg 					next_periph_b_remaining;

  // Wait for bram reads from the same address to settle, if necessary.
  // So: if we were putting the same address in but getting different values
  // out, wait until we're not getting different ones out anymore!
  // (This can happen when we're writing on one port, and reading from
  // the same address on the other port.)
  wire 					same_addr_kludge = ~dl1c_req_1a || ((set_a_1a != set_b_1a) || (q_data_a[0] == q_data_b[0]
												       && q_data_a[1] == q_data_b[1]
												       && q_tag_a[0] == q_tag_b[0]
												       && q_tag_a[1] == q_tag_b[1]));

  assign dl1c_out_a = is_periph_a_1a ? periph_result_a : q_data_a[hit_idx_a_1a][offs_a_1a * 32 +: 32];
  assign dl1c_out_b = is_periph_b_1a ? periph_result_b : q_data_b[hit_idx_b_1a][offs_b_1a * 32 +: 32];

  reg 					ready;
  assign dl1c_ready = ready;


  wire [31:0] 				bit_mask_a_1a = {{dl1c_we_a_1a[3] ? 8'hff : 8'h00},
							 {dl1c_we_a_1a[2] ? 8'hff : 8'h00},
							 {dl1c_we_a_1a[1] ? 8'hff : 8'h00},
							 {dl1c_we_a_1a[0] ? 8'hff : 8'h00}};
  wire [31:0] 				bit_mask_b_1a = {{dl1c_we_b_1a[3] ? 8'hff : 8'h00},
							 {dl1c_we_b_1a[2] ? 8'hff : 8'h00},
							 {dl1c_we_b_1a[1] ? 8'hff : 8'h00},
							 {dl1c_we_b_1a[0] ? 8'hff : 8'h00}};
  reg [31:0] 				dl1c_in_a_1a;
  reg [31:0] 				dl1c_in_b_1a;
  wire [LINE_SIZE-1:0] 			wdata_a =
					// Mask out the bits being overwritten
					q_data_a[hit_idx_a_1a] & ~({{224'h0, bit_mask_a_1a}} << (32 * offs_a_1a))
					| {{224'h0, dl1c_in_a_1a & bit_mask_a_1a}} << (32 * offs_a_1a);
  wire [LINE_SIZE-1:0] 			wdata_b =
					// Mask out the bits being overwritten
					q_data_b[hit_idx_b_1a] & ~({{224'h0, bit_mask_b_1a}} << (32 * offs_b_1a))
					| {{224'h0, dl1c_in_b_1a & bit_mask_b_1a}} << (32 * offs_b_1a);
  // Byte enable signals for the l2 cache
  wire [LINE_SIZE_BYTES-1:0] 		wbe_a = {{28'h0, dl1c_we_a_1a}} << (4 * offs_a_1a);
  wire [LINE_SIZE_BYTES-1:0] 		wbe_b = {{28'h0, dl1c_we_b_1a}} << (4 * offs_b_1a);

  integer 				i;

  always @(*) begin
     latch_inputs = 0;
     read_addr_imm = 0;

     read_a = 0;
     read_b = 0;

     write_a = 0;
     write_b = 0;

     periph_op_a = 0;
     periph_op_b = 0;

     ready = 0;

     if (~same_addr_kludge) begin
        // We're waiting for the bram to settle; don't do anything.
     end else if (dl1c_req_a_1a & ~is_periph_a_1a & ~hit_a_1a) begin
        if (~dl1c2arb_stall) read_a = 1;
     end else if (dl1c_req_b_1a & ~is_periph_b_1a & ~hit_b_1a) begin
        if (~dl1c2arb_stall) read_b = 1;
     end else begin
        // At this point, everything we need has been loaded into the cache.
        // TODO: coalesce writes to the same line
	if (periph_b_remaining & is_periph_b_1a & dl1c_req_b_1a) begin
	   // Note: we can't have a remaining periperal op for port A at this point.
	   periph_op_b = 1;
        end else if (write_a_remaining & ~is_periph_a_1a & |dl1c_we_a_1a) begin
	   // Note: there's some room for improvement here. The peripheral stuff could
	   // mostly be done in parallel with other accesses. OTOH this will only ever
	   // save like one cycle, and only when one slot does a periph access and the
	   // other a non-periph access, so not *that* important.
           if (~dl1c2arb_stall) write_a = 1;
        end else if (write_b_remaining & ~is_periph_b_1a & |dl1c_we_b_1a) begin
           if (~dl1c2arb_stall) write_b = 1;
        end else begin
           // All operations we needed to do are done! Latch the next inputs.
           latch_inputs = 1;
           read_addr_imm = 1;
           ready = 1;
	   if (dl1c_req_a_0a & is_periph_a_0a)
	     periph_op_a = 1;
	   else if (dl1c_req_b_0a & is_periph_b_0a)
	     periph_op_b = 1;
        end
     end // else: !if(dl1c_req_b_1a & ~hit_b_1a)
  end // always @ (*)

  reg                  update_cache_a;
  reg                  update_cache_b;

  reg                  l2c_valid;
  reg [2:0] 	       l2c_opcode;
  reg [31:5] 	       l2c_addr;
  reg [LINE_SIZE-1:0]  l2c_wdata;
  reg [LINE_SIZE_BYTES-1:0] l2c_wbe;

  // Whether the current peripheral access (if any) should use the 0a address
  // instead of the 1a one.
  // In each case, we want to read the immediate address if we have not yet
  // done an access of address A (either because we're doing A right now, or
  // because we're doing B and there's no operation to do for A).
  wire 			    periph_imm_addr = periph_a_remaining;

  always @(*) begin
     update_cache_a = 0;
     update_cache_b = 0;

     next_write_a_remaining = write_a_remaining;
     next_write_b_remaining = write_b_remaining;
     next_read_a_remaining = read_a_remaining;
     next_read_b_remaining = read_b_remaining;

     l2c_valid = 0;
     l2c_opcode = 3'bxxx;
     l2c_addr = 27'hxxxxxxx;

     if (ready) begin
        next_write_a_remaining = 1;
        next_write_b_remaining = 1;
        next_read_a_remaining = 1;
        next_read_b_remaining = 1;
     end else if (read_a | read_b) begin
        // Note: these are not the l2c lines themselves; there is other logic
        // to shift these values to the l2c if the stall signal is deasserted.
        l2c_opcode = LTC_OPC_READ;
        l2c_addr = read_a ? addr_a_1a[31:5] : addr_b_1a[31:5];
        l2c_valid = read_a ? read_a_remaining : read_b_remaining;

        if (read_a) next_read_a_remaining = 0;
        if (read_b) next_read_b_remaining = 0;

        if (~(read_a & read_a_remaining | read_b & read_b_remaining)) begin
           // The read of our address finished. Store it.
           if (dl1c2arb_rvalid & ~dl1c2arb_stall) begin
              if (read_a)
                update_cache_a = 1;
              else
                update_cache_b = 1;

              // TODO: we end up wasting a cycle after every read, since we wait until
              // we've actually read the data out of the cache line again (when actually
              // we know one cycle before that that we'll be done on the next cycle, and
              // could send the next l2c request then).
              //
              // TODO: we might be able to accomplish that by just changing the hit signals
              // to snoop on the l2c address and rvalid, and consider a successful read
              // a hit? Though in that case we'll need to change the output signals to case
              // on that, too.
           end
        end // if (dl1c2arb_addr == l2c_addr)
     end else if (write_a | write_b) begin // if (read_a | read_b)
        l2c_opcode = LTC_OPC_WRITE;
        l2c_addr = write_a ? addr_a_1a[31:5] : addr_b_1a[31:5];
        l2c_valid = 1;
        l2c_wdata = write_a ? wdata_a : wdata_b;
        l2c_wbe = write_a ? wbe_a : wbe_b;

        // TODO: start the write one cycle earlier in the case of a miss.
        // We don't actually need the data from the read to do the write.

        if (write_a)
          next_write_a_remaining = 0;
        else
          next_write_b_remaining = 0;
     end
  end // always @ (*)

  always @(*) begin
     dl1c2periph_addr = 30'hxxxxxxxx;
     dl1c2periph_data_out = 32'hxxxxxxxx;
     dl1c2periph_re = 0;
     dl1c2periph_we = 4'h0;

     next_periph_a_remaining = periph_a_remaining;
     next_periph_b_remaining = periph_b_remaining;

     if (ready) begin
	next_periph_a_remaining = 1;
	next_periph_b_remaining = 1;
     end

     // TODO: reading from peripherals.
     if (periph_op_a) begin
	next_periph_a_remaining = 0;
	// operipheral ops on port a will always be on the first clock edge.
	{
	 dl1c2periph_re,
	 dl1c2periph_we,
	 dl1c2periph_addr,
	 dl1c2periph_data_out
	 } = {
	      dl1c_re_a_0a,
	      dl1c_we_a_0a,
	      addr_a_0a,
	      dl1c_in_a_0a
	      };
     end else if (periph_op_b) begin // if (periph_op_a)
	next_periph_b_remaining = 0;
	if (periph_imm_addr) begin
	   {
	    dl1c2periph_re,
	    dl1c2periph_we,
	    dl1c2periph_addr,
	    dl1c2periph_data_out
	    } = {
		 dl1c_re_b_0a,
		 dl1c_we_b_0a,
		 addr_b_0a,
		 dl1c_in_b_0a
		 };
	end else begin // if (periph_imm_addr)
	   {
	    dl1c2periph_re,
	    dl1c2periph_we,
	    dl1c2periph_addr,
	    dl1c2periph_data_out
	    } = {
		 dl1c_re_b_1a,
		 dl1c_we_b_1a,
		 addr_b_1a,
		 dl1c_in_b_1a
		 };
	end // else: !if(periph_imm_addr)
     end // if (periph_op_b)
  end // always @ (*)

  always @(*) begin
     bram_we_a = 0;
     bram_we_b = 0;

     next_valid[0] = valid[0];
     next_valid[1] = valid[1];

     if (update_cache_a) begin
        // We've fetched data for the cache; now update the cache with it.
        bram_we_a[evict[set_a_1a]] = 1;
        next_valid[evict[set_a_1a]][set_a_1a] = 1;
        data_data_a = dl1c2arb_rdata;
     end else if (write_a) begin
        // TODO: we could also save a cycle on cache updating. Right now, on
        // a write that misses, we do two cache updates (old data, then new data).
        // They could be combined into one.
        bram_we_a[hit_idx_a_1a] = 1;
        // Valid bit doesn't need to be updated.
        data_data_a = wdata_a;
     end

     if (update_cache_b) begin
        bram_we_b[evict[set_b_1a]] = 1;
        next_valid[evict[set_b_1a]][set_b_1a] = 1;
        data_data_b = dl1c2arb_rdata;
     end else if (write_b) begin
        bram_we_b[hit_idx_b_1a] = 1;
        // Valid bit doesn't need to be updated.
        data_data_b = wdata_b;
     end
  end // always @ (*)

  always @(*) begin
     // Eviction logic. Whenever there's a cache hit, mark the *other* way as
     // the next to evict.
     next_evict = evict;

     if (dl1c_req_a_1a & hit_a_1a)
       next_evict[set_a_1a] = ~hit_idx_a_1a;
     if (dl1c_req_b_1a & hit_b_1a)
       next_evict[set_b_1a] = ~hit_idx_b_1a;
  end

  always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
     if (~clkrst_mem_rst_n) begin
	periph_result_a <= 32'hxxxxxxxx;
	periph_result_b <= 32'hxxxxxxxx;
     end else begin
	if (periph_op_a) periph_result_a <= dl1c2periph_data_in;
	if (periph_op_b) periph_result_b <= dl1c2periph_data_in;
     end
  end

  always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n) begin
     if (~clkrst_mem_rst_n) begin
        for (i = 0; i < WAYS; i = i + 1)
          valid[i] <= 0;
        evict <= 0;
        dl1c2arb_valid <= 0;
     end else begin
        if (latch_inputs) begin
           dl1c_re_a_1a <= dl1c_re_a_0a;
           dl1c_re_b_1a <= dl1c_re_b_0a;
           dl1c_we_a_1a <= dl1c_we_a_0a;
           dl1c_we_b_1a <= dl1c_we_b_0a;

	   dl1c_in_a_1a <= dl1c_in_a_0a;
	   dl1c_in_b_1a <= dl1c_in_b_0a;

           addr_a_1a <= addr_a_0a;
           addr_b_1a <= addr_b_0a;
        end

        if (~dl1c2arb_stall) begin
           dl1c2arb_valid <= l2c_valid;
           dl1c2arb_opcode <= l2c_opcode;
           dl1c2arb_addr <= l2c_addr;

           dl1c2arb_wdata <= l2c_wdata;
           dl1c2arb_wbe <= l2c_wbe;
        end

        evict <= next_evict;
        valid[0] <= next_valid[0];
        valid[1] <= next_valid[1];

        write_a_remaining <= next_write_a_remaining;
        write_b_remaining <= next_write_b_remaining;
        read_a_remaining <= next_read_a_remaining;
        read_b_remaining <= next_read_b_remaining;
	periph_a_remaining <= next_periph_a_remaining;
	periph_b_remaining <= next_periph_b_remaining;
     end
  end // always @ (posedge clkrst_mem_clk)

  genvar                   ii;
  generate
     for (ii = 0; ii < WAYS; ii = ii + 1) begin: data_bram_gen

        // Note: we can combine these BRAMs into one if needed. We always read/write them together.
        dp_bram #(
                  .DATA_WIDTH(LINE_SIZE),
                  .ADDR_WIDTH(SET_WIDTH)
                  ) data_bram (
                               // Outputs
                               .q_a                   (q_data_a[ii]),
                               .q_b                   (q_data_b[ii]),
                               // Inputs
                               .data_a                (data_data_a),
                               .data_b                (data_data_b),
                               .addr_a                (bram_addr_a),
                               .addr_b                (bram_addr_b),
                               .we_a                  (bram_we_a[ii]),
                               .we_b                  (bram_we_b[ii]),
                               .clk                   (clkrst_mem_clk));

        dp_bram #(
                  .DATA_WIDTH(TAG_WIDTH),
                  .ADDR_WIDTH(SET_WIDTH)
                  ) tag_bram (
                              // Outputs
                              .q_a                   (q_tag_a[ii]),
                              .q_b                   (q_tag_b[ii]),
                              // Inputs
                              .data_a                (data_tag_a),
                              .data_b                (data_tag_b),
                              .addr_a                (bram_addr_a),
                              .addr_b                (bram_addr_b),
                              .we_a                  (bram_we_a[ii]),
                              .we_b                  (bram_we_b[ii]),
                              .clk                   (clkrst_mem_clk));

     end // block: data_bram_gen
  endgenerate

  // for the sake of iverilog.
  wire [NUM_SETS-1:0] valid0 = valid[0];
  wire [NUM_SETS-1:0] valid1 = valid[1];

endmodule // MCPU_MEM_dl1c
