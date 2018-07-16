`timescale 1 ns / 1 ps

// TODO: have a way to flush the cache.

module MCPU_MEM_dtlb(
                     input              clk,

                     // Control interface
                     input [31:12]      dtlb_addr_a,
                     input [31:12]      dtlb_addr_b,
                     input              dtlb_re_a,
                     input              dtlb_re_b,
                     // 20 bits, since page directories are aligned to pages.
                     // Base address is common to both ports.
                     input [19:0]       dtlb_pagedir_base,

                     output [31:12]     dtlb_phys_addr_a,
                     output [31:12]     dtlb_phys_addr_b,
                     output [3:0]       dtlb_flags_a,
                     output [3:0]       dtlb_flags_b,
                     output             dtlb_ready,

                     // Page table walker interface
                     output reg [31:12] tlb2ptw_addr,
                     output reg         tlb2ptw_re,
                     output [19:0]      tlb2ptw_pagedir_base,

                     input [31:12]      tlb2ptw_phys_addr,
                     input              tlb2ptw_ready,
                     input [3:0]        tlb2ptw_pagetab_flags,
                     input [3:0]        tlb2ptw_pagedir_flags);

`include "MCPU_MEM_pt.vh"

   // Number of bits in a set address and a tag. (Note: this is not the width
   // of the set itself! That's DATA_SIZE * WAYS.)
   localparam SET_WIDTH = 13;
   localparam TAG_WIDTH = 7;

   // Note: this is for clarify of code, not for ease of changing
   // cache parameters. Code changes would be needed if this changes!
   localparam WAYS = 2;

   // Data entries are packed as follows:
   //  1 bit: valid bit
   //  7 bits: tag ( = TAG_WIDTH)
   //  4 bits: address flags
   //  20 bits: translated address
   // for a total of 32 bits.
   localparam DATA_SIZE = 32;

   localparam STATE_BITS = 3;
   localparam ST_IDLE = 0;
   localparam ST_COMPARING = 1; // We just fetched sets, and need
                                // to check valid/tag bits.
   localparam ST_LOOKUP_A = 2; // Performing a walk for address A.
   localparam ST_LOOKUP_B = 3;
   localparam ST_DELAY = 4; // A one-cycle delay before a transition to IDLE.

   reg [STATE_BITS-1:0] state = ST_IDLE;
   reg [STATE_BITS-1:0] next_state = ST_IDLE;

   wire [31:12]         dtlb_addr_a_0a = dtlb_addr_a;
   wire [31:12]         dtlb_addr_b_0a = dtlb_addr_b;

   // Separate addresses into set + tag
   wire [TAG_WIDTH-1:0]  tag_a_0a = dtlb_addr_a_0a[31 -: TAG_WIDTH];
   wire [SET_WIDTH-1:0]  set_a_0a = dtlb_addr_a_0a[31 - TAG_WIDTH -: SET_WIDTH];
   wire [TAG_WIDTH-1:0]  tag_b_0a = dtlb_addr_b_0a[31 -: TAG_WIDTH];
   wire [SET_WIDTH-1:0]  set_b_0a = dtlb_addr_b_0a[31 - TAG_WIDTH -: SET_WIDTH];

   // We latch addresses when doing operations that will take more than one
   // cycle; these are the latched addresses, and wires for their components.
   reg [31:12]           dtlb_addr_a_1a;
   reg [31:12]           dtlb_addr_b_1a;
   wire [TAG_WIDTH-1:0]  tag_a_1a = dtlb_addr_a_1a[31 -: TAG_WIDTH];
   wire [SET_WIDTH-1:0]  set_a_1a = dtlb_addr_a_1a[31 - TAG_WIDTH -: SET_WIDTH];
   wire [TAG_WIDTH-1:0]  tag_b_1a = dtlb_addr_b_1a[31 -: TAG_WIDTH];
   wire [SET_WIDTH-1:0]  set_b_1a = dtlb_addr_b_1a[31 - TAG_WIDTH -: SET_WIDTH];

   assign tlb2ptw_pagedir_base = dtlb_pagedir_base;

   // Wires and registers for data brams
   wire [DATA_SIZE-1:0] q_data_a[WAYS-1:0];
   wire [DATA_SIZE-1:0] data_data_a;
   wire [SET_WIDTH-1:0] addr_data_a;
   reg                  we_data_a[WAYS-1:0];
   wire [DATA_SIZE-1:0] q_data_b[WAYS-1:0];
   wire [DATA_SIZE-1:0] data_data_b;
   wire [SET_WIDTH-1:0] addr_data_b;
   reg                  we_data_b[WAYS-1:0];

   // Unpacked cache entries (from the data bram outputs)
   wire [TAG_WIDTH-1:0] q_data_a_tag[WAYS-1:0];
   wire [19:0]          q_data_a_addr[WAYS-1:0];
   wire [3:0]           q_data_a_flags[WAYS-1:0];
   wire                 q_data_a_valid[WAYS-1:0];
   wire [TAG_WIDTH-1:0] q_data_b_tag[WAYS-1:0];
   wire [19:0]          q_data_b_addr[WAYS-1:0];
   wire [3:0]           q_data_b_flags[WAYS-1:0];
   wire                 q_data_b_valid[WAYS-1:0];

   // Unpacked cache entries, for writing--these are combined to form
   // the inputs to the data brams.
   wire [TAG_WIDTH-1:0] data_data_a_tag;
   wire [19:0]          data_data_a_addr;
   wire [3:0]           data_data_a_flags;
   wire                 data_data_a_valid;
   wire [TAG_WIDTH-1:0] data_data_b_tag;
   wire [19:0]          data_data_b_addr;
   wire [3:0]           data_data_b_flags;
   wire                 data_data_b_valid;

   // Data input to the data brams.
   assign data_data_a = {{data_data_a_valid},
                         {data_data_a_tag},
                         {data_data_a_flags},
                         {data_data_a_addr}};
   assign data_data_b = {{data_data_b_valid},
                         {data_data_b_tag},
                         {data_data_b_flags},
                         {data_data_b_addr}};

   // Wires and registers for evict bram
   wire                  q_evict_a;
   wire                  q_evict_b;
   reg                   data_evict_a;
   reg                   data_evict_b;
   wire [SET_WIDTH-1:0]  addr_evict_a;
   wire [SET_WIDTH-1:0]  addr_evict_b;
   reg                   we_evict_a;
   reg                   we_evict_b;

   // Which ports were hits on which ways.
   // Note that these will be updated even if read enable is low for the port.
   wire [WAYS-1:0]      hit_a_way_1a;
   wire [WAYS-1:0]      hit_b_way_1a;

   wire                 hit_a_1a = |hit_a_way_1a;
   wire                 hit_b_1a = |hit_b_way_1a;

   wire                 dtlb_re_a_0a = dtlb_re_a;
   wire                 dtlb_re_b_0a = dtlb_re_b;
   reg                  dtlb_re_a_1a = 0;
   reg                  dtlb_re_b_1a = 0;

   wire                 tlb2ptw_ready_0a = tlb2ptw_ready;
   reg                  tlb2ptw_ready_1a;

   assign dtlb_ready = state == ST_IDLE ||
                       (state == ST_COMPARING &&
                        (~dtlb_re_a_1a | hit_a_1a) &&
                        (~dtlb_re_b_1a | hit_b_1a));

   // Reads and writes to the evict bram are always from the "last" address;
   // we never read or write on the cycle that we first see the address.
   assign addr_evict_a = set_a_1a;
   assign addr_evict_b = set_b_1a;

   // Flags are a bit annoying: we get the PD and PT flags for the
   // entry separately, and some flags (e.g. "present") must be set on
   // both to be set for the page, but others are set on the page if
   // set on either (e.g. "kernel").
   wire [3:0] phys_addr_flags = {
       {tlb2ptw_pagedir_flags[PAGETAB_GLOBAL] |
        tlb2ptw_pagetab_flags[PAGETAB_GLOBAL]},
       {tlb2ptw_pagedir_flags[PAGETAB_KERNEL] |
        tlb2ptw_pagetab_flags[PAGETAB_KERNEL]},
       {tlb2ptw_pagedir_flags[PAGETAB_WRITEABLE] &
        tlb2ptw_pagetab_flags[PAGETAB_WRITEABLE]},
       {tlb2ptw_pagedir_flags[PAGETAB_PRESENT] &
        tlb2ptw_pagetab_flags[PAGETAB_PRESENT]}
   };

   // We set the new evict bit for a set differently depending on
   // whether the access was a hit or a miss.
   reg evict_update_a_from_hit;
   reg evict_update_a_from_miss;
   reg evict_update_b_from_hit;
   reg evict_update_b_from_miss;

   // Whether we should initiate a page table walk for either address.
   reg lookup_a;
   reg lookup_b;

   // Whether we should be updating the given cache entry this cycle.
   reg       cache_update_a;
   reg       cache_update_b;

   // Whether to latch addresses and re bits this cycle.
   reg       latch_inputs;

   // Whether the input addresses should be used when calculating addresses for
   // bram accesses, or whether latched addresses should be used instead.
   reg       read_addresses_imm;

   // Whether we're starting a walk this cycle. (This is separate from the
   // lookup_a/lookup_b wires, because the walker requires that the address
   // line be held constant while the lookup happens. On the other hand, we
   // only want re to be high for one cycle at the start of the walk, so we
   // don't accidentally walk twice.)
   reg       start_lookup;

   always @(*) begin
      evict_update_a_from_hit = 0;
      evict_update_a_from_miss = 0;
      evict_update_b_from_hit = 0;
      evict_update_b_from_miss = 0;

      lookup_a = 0;
      lookup_b = 0;

      cache_update_a = 0;
      cache_update_b = 0;

      latch_inputs = 0;

      next_state = state;

      // For most states, we want the latched addresses, not the immediate ones.
      read_addresses_imm = 0;

      start_lookup = 0;

      case (state)
        ST_IDLE: begin
           if (dtlb_re_a_0a | dtlb_re_b_0a) begin
              read_addresses_imm = 1;
              latch_inputs = 1;
              next_state = ST_COMPARING;
           end
        end
        ST_COMPARING: begin
           read_addresses_imm = 1;

           // Update eviction bits for any hits.
           if (dtlb_re_a_1a & hit_a_1a)
             evict_update_a_from_hit = 1;
           if (dtlb_re_b_1a & hit_b_1a)
             evict_update_b_from_hit = 1;

           // On cache miss, perform a walk. If both addresses miss, we'll
           // walk address A first.
           if (dtlb_re_a_1a & ~hit_a_1a) begin
              lookup_a = 1;
              start_lookup = 1;
              next_state = ST_LOOKUP_A;
           end else if (dtlb_re_b_1a & ~hit_b_1a) begin
              lookup_b = 1;
              start_lookup = 1;
              next_state = ST_LOOKUP_B;
           end else begin
              // All addresses that were requested were cache hits.
              // If there's another request, we'll have the cache data next
              // cycle, so go to the COMPARING state. Otherwise, we're idle.
              if (dtlb_re_a_0a | dtlb_re_b_0a) begin
                 latch_inputs = 1;
                 next_state = ST_COMPARING;
              end else
                next_state = ST_IDLE;
           end
        end
        ST_LOOKUP_A: begin
           lookup_a = 1;
           if (tlb2ptw_ready_1a) begin
              evict_update_a_from_miss = 1;
              cache_update_a = 1;

              if (dtlb_re_b_1a & ~hit_b_1a) begin
                 // We need one cycle to write the new data to the
                 // cache (during the transition to the DELAY state),
                 // and then one more to read it back out on the other
                 // port.
                 if (dtlb_addr_a_1a == dtlb_addr_b_1a) begin
                    // If we're doing a lookup of the same address twice,
                    // don't walk twice.
                    lookup_a = 0;
                    next_state = ST_DELAY;
                 end else begin
                    lookup_a = 0;
                    lookup_b = 1;
                    start_lookup = 1;
                    next_state = ST_LOOKUP_B;
                 end
              end else begin
                 lookup_a = 0;
                 // It takes one cycle to perform the writes to the cache;
                 // during that time we can't start another read, so we
                 // can't have a path from here directly to ST_COMPARING
                 // even if another request is pending.
                 next_state = ST_IDLE;
              end
           end
        end
        ST_LOOKUP_B: begin
           if (tlb2ptw_ready_1a) begin
              evict_update_b_from_miss = 1;
              cache_update_b = 1;

              next_state = ST_IDLE;
           end else
             lookup_b = 1;
        end
        ST_DELAY: next_state = ST_IDLE;
      endcase
   end // always @ (*)

   // Logic for updating eviction bits.
   always @(*) begin
      we_evict_a = 0;
      data_evict_a = 1'bx;

      if (evict_update_a_from_hit | evict_update_a_from_miss) begin
         we_evict_a = 1;
         if (evict_update_a_from_hit)
            // If the hit was on way 0, we'll next want to evict 1, and
            // if it was on way 1, we'll next want to evict 0.
            data_evict_a = hit_a_way_1a[0];
         else
            data_evict_a = ~q_evict_a;
      end
   end
   always @(*) begin
      we_evict_b = 0;
      data_evict_b = 1'bx;

      if (evict_update_b_from_hit | evict_update_b_from_miss) begin
         we_evict_b = 1;
         if (evict_update_b_from_hit)
           // If the hit was on way 0, we'll next want to evict 1, and
           // if it was on way 1, we'll next want to evict 0.
           data_evict_b = hit_b_way_1a[0];
         else
           data_evict_b = ~q_evict_b;
      end
   end // always @ (evict_update_a_mode)

   // Update inputs to walker
   always @(*) begin
      if (lookup_a) begin
         tlb2ptw_addr = dtlb_addr_a_1a;
      end else if (lookup_b) begin
         tlb2ptw_addr = dtlb_addr_b_1a;
      end else begin
         tlb2ptw_addr = 20'hxxxxx;
      end
   end
   assign tlb2ptw_re = start_lookup;

   // Insert data into the cache.
   assign data_data_a_tag = tag_a_1a;
   assign data_data_a_addr = tlb2ptw_phys_addr[31 -: 20];
   assign data_data_a_flags = phys_addr_flags;
   assign data_data_a_valid = 1;

   assign data_data_b_tag = tag_b_1a;
   assign data_data_b_addr = tlb2ptw_phys_addr[31 -: 20];
   assign data_data_b_flags = phys_addr_flags;
   assign data_data_b_valid = 1;

   always @(*) begin
      we_data_a[q_evict_a] = cache_update_a;
      we_data_a[~q_evict_a] = 0;
      we_data_b[q_evict_b] = cache_update_b;
      we_data_b[~q_evict_b] = 0;
   end

   // Update state and latch inputs
   always @(posedge clk) begin
      state <= next_state;

      tlb2ptw_ready_1a <= tlb2ptw_ready_0a;

      if (latch_inputs) begin
         dtlb_re_a_1a <= dtlb_re_a_0a;
         dtlb_re_b_1a <= dtlb_re_b_0a;
         dtlb_addr_a_1a <= dtlb_addr_a_0a;
         dtlb_addr_b_1a <= dtlb_addr_b_0a;
      end
   end // always @ (posedge clk)

   // Outputs always come from the cache. On a miss, the values will be
   // valid after the cache is updated.
   assign dtlb_phys_addr_a = q_data_a_addr[hit_a_way_1a[1]];
   assign dtlb_flags_a = q_data_a_flags[hit_a_way_1a[1]];
   assign dtlb_phys_addr_b = q_data_b_addr[hit_b_way_1a[1]];
   assign dtlb_flags_b = q_data_b_flags[hit_b_way_1a[1]];

   assign addr_data_a = read_addresses_imm ? set_a_0a : set_a_1a;
   assign addr_data_b = read_addresses_imm ? set_b_0a : set_b_1a;

   genvar i;
   generate
      for (i = 0; i < WAYS; i = i + 1) begin: addr_data_and_hits_gen
         // Each cycle, read both addresses from both ways, whether
         // or not we're actually doing a read.
         // We have a hit on on this way if the tags match and the
         // entry is valid.
         assign hit_a_way_1a[i] = ((q_data_a_tag[i] == tag_a_1a) &&
                                   q_data_a_valid[i]);
         assign hit_b_way_1a[i] = ((q_data_b_tag[i] == tag_b_1a) &&
                                   q_data_b_valid[i]);
      end
   endgenerate

   generate
      for (i = 0; i < WAYS; i = i + 1) begin: data_bram_gen
          dp_bram #(
                  .DATA_WIDTH(DATA_SIZE),
                  .ADDR_WIDTH(SET_WIDTH)
                  ) data_bram0 (
                                // Outputs
                                .q_a                   (q_data_a[i]),
                                .q_b                   (q_data_b[i]),
                                // Inputs
                                .data_a                (data_data_a),
                                .data_b                (data_data_b),
                                .addr_a                (addr_data_a),
                                .addr_b                (addr_data_b),
                                .we_a                  (we_data_a[i]),
                                .we_b                  (we_data_b[i]),
                                .clk                   (clk));

         // Split the output into its components.
         assign q_data_a_valid[i] = q_data_a[i][DATA_SIZE-1];
         assign q_data_a_tag[i] = q_data_a[i][DATA_SIZE-2 -: TAG_WIDTH];
         assign q_data_a_flags[i] = q_data_a[i][23:20];
         assign q_data_a_addr[i] = q_data_a[i][19:0];

         assign q_data_b_valid[i] = q_data_b[i][DATA_SIZE-1];
         assign q_data_b_tag[i] = q_data_b[i][DATA_SIZE-2 -: TAG_WIDTH];
         assign q_data_b_flags[i] = q_data_b[i][23:20];
         assign q_data_b_addr[i] = q_data_b[i][19:0];
      end
   endgenerate

   // Each set has a single bit associated with it to specify which way
   // will be evicted next. (This will need to change if the associativity
   // of the cache is changed.)
   dp_bram #(
             .DATA_WIDTH(1),
             .ADDR_WIDTH(SET_WIDTH)
             ) evict_bram0 (
                         // Outputs
                         .q_a                   (q_evict_a),
                         .q_b                   (q_evict_b),
                         // Inputs
                         .data_a                (data_evict_a),
                         .data_b                (data_evict_b),
                         .addr_a                (addr_evict_a),
                         .addr_b                (addr_evict_b),
                         .we_a                  (we_evict_a),
                         .we_b                  (we_evict_b),
                         .clk                   (clk));
endmodule
