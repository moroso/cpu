`timescale 1 ns / 1 ps

module MCPU_MEM_pt_walk(
                      input             clk,

                      // Control interface
                      input [31:0]      addr,
                      input             re,
                      // 20 bits, since page directories are aligned to pages.
                      input [19:0]      pagedir_base,

                      output reg [31:0] phys_addr,
                      output            ready,
                      output reg        present = 0,
                      output reg [3:0]  pagetab_flags = 0,
                      output reg [3:0]  pagedir_flags = 0,



                      // Atom interface to arb
                      output reg        arb_valid,
                      output [2:0]      arb_opcode,
                      output reg [31:5] arb_addr,

                      // TODO: remove this two; we don't need them.
                      output [255:0]    arb_wdata,
                      output [31:0]     arb_wbe,

                      input [255:0]     arb_rdata,
                      input             arb_rvalid,
                      input             arb_stall
                      );


`include "MCPU_MEM_ltc.vh"

   parameter STATE_BITS = 3;

   // State machine states
   parameter ST_IDLE = 0; // Waiting for a requests
   parameter ST_READ_DIR = 1; // Reading the page directory entry
   parameter ST_READ_TAB = 2; // Reading the page table entry

   reg [STATE_BITS-1:0]   state = ST_IDLE;
   reg [STATE_BITS-1:0]   next_state = ST_IDLE;

   reg [19:0]             pagetab_base = 0;

   wire [9:0]             dir_offs = addr[31:22];
   wire [9:0]             pt_offs = addr[21:12];

   wire [31:0]            mem_addr = 0;

   // The start of the relevant entry in the atom for this page directory.
   wire [4:0]             arb_rdata_pd_entry_offs = {{dir_offs[2:0]}, 2'b0};
   // The entire page directory entry.
   wire [31:0]            arb_rdata_pd_entry = arb_rdata[arb_rdata_pd_entry_offs * 8 +: 32];
   wire [19:0]            arb_rdata_pd_addr = arb_rdata_pd_entry[31:12];
   wire [3:0]             arb_rdata_pd_flags = arb_rdata_pd_entry[3:0];
   wire                   arb_rdata_pd_present = arb_rdata_pd_flags[0];

   // The start of the relevant entry in the atom for this page table.
   wire [4:0]             arb_rdata_pt_entry_offs = {{pt_offs[2:0]}, 2'b0};

   wire [31:0]            arb_rdata_pt_entry = arb_rdata[arb_rdata_pt_entry_offs * 8 +: 32];
   wire [19:0]            arb_rdata_pt_addr = arb_rdata_pt_entry[31:12];
   wire [3:0]             arb_rdata_pt_flags = arb_rdata_pt_entry[3:0];
   wire                   arb_rdata_pt_present = arb_rdata_pt_flags[0];


   // TODO: we could set this a cycle sooner, and have a transition
   // from ST_READ_TAB to ST_READ_DIR when another request comes in
   // immediately.
   assign ready = (state == ST_IDLE);

   // We never do anything but ordinary reads from the l2c, so we can
   // just hardwire this.
   assign arb_opcode = LTC_OPC_READ;

   always @(*)
     case (state)
       ST_IDLE:
         if (re) begin
            next_state = ST_READ_DIR;
            arb_addr = {{pagedir_base}, {dir_offs[9:3]}};
         end else begin
            next_state = ST_IDLE;
            arb_addr = 0;
         end
       ST_READ_DIR:
         if (arb_rvalid) begin
            if (arb_rdata_pd_present) begin
               next_state = ST_READ_TAB;
               // We haven't yet stored the page *table* address in pagetab_base,
               // so for this cylce we get it from the atom we just read from the ltc.
               arb_addr = {{arb_rdata_pd_addr}, {pt_offs[9:3]}};
            end else begin
               next_state = ST_IDLE;
               arb_addr = 0;
            end
         end else begin
            next_state = ST_READ_DIR;
            // At this point the page table base address has been stored in
            // pagedir_base, so we can use that.
            arb_addr = {{pagedir_base}, {dir_offs[9:3]}};
         end
       ST_READ_TAB:
         if (arb_rvalid) begin
            next_state = ST_IDLE;
            arb_addr = 0;
         end else begin
            next_state = ST_READ_TAB;
            arb_addr = {{pagetab_base}, {pt_offs[9:3]}};
         end
       default: begin
          next_state = ST_IDLE;
          arb_addr = 0;
       end
     endcase

   always @(posedge clk) begin
      state <= next_state;

      if (state == ST_IDLE && next_state == ST_READ_DIR) begin
         // Perform a read on the transition from IDLE -> ST_READ DIR
         arb_valid = 1;
      end else if (state == ST_READ_DIR && next_state == ST_READ_TAB) begin
         // We're entering the ST_READ_TAB state. arb_rdata contains
         // the page directory entry we want; save that in pagetab_base,
         // along with flags from the pagedir entry.

         pagetab_base = arb_rdata_pd_addr;
         pagedir_flags = arb_rdata_pd_flags;
         // Perform a read for the page table atom.
         arb_valid = 1;
      end else if (state == ST_READ_DIR && next_state == ST_IDLE) begin
         // The page directory entry wasn't present.
         present = 0;
      end else if (state == ST_READ_TAB && next_state == ST_IDLE) begin
         if (arb_rdata_pt_present) begin
            present = 1;
            phys_addr = {{arb_rdata_pt_addr}, {addr[11:0]}};
            pagetab_flags = arb_rdata_pt_flags;
         end else begin
            present = 0;
         end
      end else
        arb_valid = 0;
   end

endmodule
