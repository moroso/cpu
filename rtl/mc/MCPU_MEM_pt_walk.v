`timescale 1 ns / 1 ps

module MCPU_MEM_pt_walk(
                        input             tlb2ptw_clk,

                        // Control interface
                        input [31:12]     tlb2ptw_addr,
                        input             tlb2ptw_re,
                        // 20 bits, since page directories are aligned to pages.
                        input [19:0]      ptw_pagedir_base,

                        output [31:12]    tlb2ptw_phys_addr,
                        output            tlb2ptw_ready,
                        output [3:0]      tlb2ptw_pagetab_flags,
                        output [3:0]      tlb2ptw_pagedir_flags,


                        // Atom interface to arb
                        output reg        ptw2arb_valid,
                        output [2:0]      ptw2arb_opcode,
                        output reg [31:5] ptw2arb_addr,

                        // TODO: remove this two; we don't need them.
                        output [255:0]    ptw2arb_wdata,
                        output [31:0]     ptw2arb_wbe,

                        input [255:0]     ptw2arb_rdata,
                        input             ptw2arb_rvalid,
                        input             ptw2arb_stall
                        );

`include "MCPU_MEM_ltc.vh"

   parameter STATE_BITS = 3;

   // State machine states
   parameter ST_IDLE = 0; // Waiting for a requests
   parameter ST_BEGIN_READ_DIR = 1; // About to read page directory entry
   parameter ST_READ_DIR = 2; // Reading the page directory entry
   parameter ST_BEGIN_READ_TAB = 3;
   parameter ST_READ_TAB = 4; // Reading the page table entry

   reg [STATE_BITS-1:0]   state = ST_IDLE;
   reg [STATE_BITS-1:0]   next_state = ST_IDLE;

   wire [9:0]             dir_offs = tlb2ptw_addr[31:22];
   wire [9:0]             pt_offs = tlb2ptw_addr[21:12];

   // The start of the relevant entry in the atom for this page directory.
   wire [4:0]             arb_rdata_pd_entry_offs = {{dir_offs[2:0]}, 2'b0};
   // The entire page directory entry.
   wire [31:0]            arb_rdata_pd_entry = ptw2arb_rdata[{{arb_rdata_pd_entry_offs}, {3'b000}} +: 32];
   wire [19:0]            arb_rdata_pd_addr = arb_rdata_pd_entry[31:12];
   wire [3:0]             arb_rdata_pd_flags = arb_rdata_pd_entry[3:0];
   wire                   arb_rdata_pd_present = arb_rdata_pd_flags[0];

   reg [31:0]             latched_arb_rdata_pd_entry = 0;
   assign tlb2ptw_pagedir_flags = latched_arb_rdata_pd_entry[3:0];
   wire [19:0]            pagetab_base = latched_arb_rdata_pd_entry[31:12];

   // The start of the relevant entry in the atom for this page table.
   wire [4:0]             arb_rdata_pt_entry_offs = {{pt_offs[2:0]}, 2'b0};

   wire [31:0]            arb_rdata_pt_entry = ptw2arb_rdata[{{arb_rdata_pt_entry_offs}, {3'b000}} +: 32];
   wire [19:0]            arb_rdata_pt_addr = arb_rdata_pt_entry[31:12];
   wire [3:0]             arb_rdata_pt_flags = arb_rdata_pt_entry[3:0];
   wire                   arb_rdata_pt_present = arb_rdata_pt_flags[0];

   reg [31:0]             latched_arb_rdata_pt_entry = 0;
   assign tlb2ptw_pagetab_flags = latched_arb_rdata_pt_entry[3:0];
   assign tlb2ptw_phys_addr = latched_arb_rdata_pt_entry[31:12];

   // TODO: we could set this a cycle sooner, and have a transition
   // from ST_READ_TAB to ST_READ_DIR when another request comes in
   // immediately.
   assign tlb2ptw_ready = (state == ST_IDLE);

   // We never do anything but ordinary reads from the l2c, so we can
   // just hardwire this.
   assign ptw2arb_opcode = LTC_OPC_READ;

   reg [31:5]             next_ptw2arb_addr;
   reg                    next_ptw2arb_valid;
   reg                    latch_pd;
   reg                    latch_pt;

   always @(*) begin
      next_ptw2arb_addr = 27'hxxxxxxx;
      next_ptw2arb_valid = 0;
      next_state = state;
      latch_pd = 0;
      latch_pt = 0;

      case (state)
        ST_IDLE:
          if (tlb2ptw_re) begin
             if (~ptw2arb_stall)
               next_state = ST_BEGIN_READ_DIR;
             next_ptw2arb_addr = {{ptw_pagedir_base}, {dir_offs[9:3]}};
             next_ptw2arb_valid = 1;
          end else begin
             next_state = ST_IDLE;
          end
        ST_BEGIN_READ_DIR: begin
           next_state = ST_READ_DIR;
           next_ptw2arb_addr = ptw2arb_addr;
           next_ptw2arb_valid = 1;
        end
        ST_READ_DIR:
          if (ptw2arb_rvalid) begin
             if (arb_rdata_pd_present) begin
                next_state = ST_BEGIN_READ_TAB;
                // We haven't yet stored the page *table* address in pagetab_base,
                // so for this cylce we get it from the atom we just read from the ltc.
                next_ptw2arb_addr = {{arb_rdata_pd_addr}, {pt_offs[9:3]}};
                next_ptw2arb_valid = 1;
                // Capture the values we need from the page directory entry we just read.
                latch_pd = 1;
             end else
               next_state = ST_IDLE;
          end else begin
             next_ptw2arb_addr = {{ptw_pagedir_base}, {dir_offs[9:3]}};
              //next_ptw2arb_valid = 1;
           end // else: !if(ptw2arb_rvalid)
        ST_BEGIN_READ_TAB: begin
           next_state = ST_READ_TAB;
           next_ptw2arb_addr = ptw2arb_addr;
           next_ptw2arb_valid = 1;
        end
        ST_READ_TAB:
          if (ptw2arb_rvalid) begin
             next_state = ST_IDLE;
             latch_pt = 1;
          end else
            // At this point the page table base address has been stored in
            // pagetab_base, so we can use that.
            next_ptw2arb_addr = {{pagetab_base}, {pt_offs[9:3]}};
      endcase
   end

   always @(posedge tlb2ptw_clk) begin
      state <= next_state;

      if (~ptw2arb_stall) begin
         ptw2arb_addr <= next_ptw2arb_addr;
         ptw2arb_valid <= next_ptw2arb_valid;
      end

      if (latch_pd) begin
         // arb_rdata contains the page directory entry we want; save
         // that in pagetab_base, along with flags from the pagedir
         // entry.
         latched_arb_rdata_pd_entry <= arb_rdata_pd_entry;
         // For now, treat the page table entry as 0. If the page directory is
         // present and we do a read of the page table entry, this will be overwritten
         // below.
         latched_arb_rdata_pt_entry <= 32'h0;
      end else if (latch_pt) begin
         latched_arb_rdata_pt_entry <= arb_rdata_pt_entry;
      end
   end

endmodule
