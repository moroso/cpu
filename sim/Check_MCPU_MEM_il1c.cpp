#include "Sim.h"

#include "Check_MCPU_MEM_il1c.h"
#include "mem_common.h"

#define FROM_TLB_ADDR(addr) (addr << 12)
#define TO_TLB_ADDR(addr) (addr >> 12)

#define FROM_ARB_ADDR(addr) (addr << 5)
#define TO_ARB_ADDR(addr) (addr >> 5)

#define FROM_L1C_ADDR(addr) (addr << 4)
#define TO_L1C_ADDR(addr) (addr >> 4)

#define SET(addr) ((TO_L1C_ADDR(addr) >> 1) & ((1<<SET_WIDTH)-1))
#define TAG(addr) (TO_L1C_ADDR(addr) >> (SET_WIDTH + 1))

#define OFFS(addr) (TO_L1C_ADDR(addr) & 1)

Check_MCPU_MEM_il1c::Check_MCPU_MEM_il1c(MCPU_MEM_il1c_ports *ports) :
  ports(ports), active(false), lookup_active(false),
  fetch_active(false) {
  for (int i = 0; i < NUM_SETS; i += 1) {
    address_map[i].valid = false;
  }
}

void Check_MCPU_MEM_il1c::clk() {
  if (active) {
    // Note: TLB lookups will have started at the same time as us becoming
    // active.
    if (lookup_active) {
      SIM_CHECK(!fetch_active);

      if (*ports->il1c2tlb_ready) {
        // We were performing a TLB lookup, but it just finished.
        lookup_active = false;
        lookup_result =
          FROM_TLB_ADDR(*ports->il1c2tlb_phys_addr) |
          (active_addr & 0xfff);

        SIM_CHECK_EQ(SET(lookup_result), SET(active_addr));
        // At this point, either we should be making a request to the arb
        // and *not* to the tlb anymore, or we're not doing an arb lookup,
        // in which case we're done.
        SIM_CHECK((*ports->il1c2arb_valid && !*ports->il1c2tlb_re) ||
                  *ports->il1c_ready);
        // TODO: check other signals to the tlb
      }
    }

    if (fetch_active) {
      SIM_CHECK(!lookup_active);

      if (*ports->il1c2arb_rvalid) {
        // We were looking up data, and it's done now.
        fetch_active = false;

        // Save the result of the fetch.
        int set = SET(lookup_result);
        address_map[set].valid = true;
        address_map[set].tag = TAG(lookup_result);
        for (int i = 0; i < LINE_SIZE_WORDS; i += 1) {
          address_map[set].line[i] = ports->il1c2arb_rdata[i];
        }
      } else {
        // Make sure the address doesn't change.
        SIM_CHECK_EQ(TO_ARB_ADDR(fetch_addr), TO_ARB_ADDR(lookup_result));
        SIM_CHECK(*ports->il1c2arb_valid);
      }
    } else if (*ports->il1c2arb_valid) {
      fetch_active = true;
      fetch_addr = FROM_ARB_ADDR(*ports->il1c2arb_addr);
      // Make sure we're looking up the right address.
      SIM_CHECK_EQ(TO_ARB_ADDR(fetch_addr), TO_ARB_ADDR(lookup_result));

      // Make sure we were actually supposed to perform this lookup.
      int set = SET(lookup_result);
      int tag = TAG(lookup_result);

      SIM_CHECK_MSG(!address_map[set].valid ||
                    address_map[set].tag != tag,
                    "Set %d already in cache", set);
    }

    if (lookup_active || fetch_active) {
      SIM_CHECK(!*ports->il1c_ready);
    }

    if (*ports->il1c_ready) {
      active = false;
      int set = SET(lookup_result);
      SIM_CHECK(address_map[set].valid);
      SIM_CHECK_EQ(TAG(lookup_result), address_map[set].tag);
      for (int i = 0; i < 4; i += 1) {
        SIM_CHECK_EQ(address_map[set].line[i + 4 * OFFS(lookup_result)],
                     ports->il1c_packet[i]);
      }
    }
  }

  if (!active) {
    // Not active.
    if (*ports->il1c_re) {
      // Starting a request.
      active = true;
      active_addr = FROM_L1C_ADDR(*ports->il1c_addr);

      SIM_CHECK(*ports->il1c2tlb_re);
      lookup_active = true;
      lookup_addr = FROM_TLB_ADDR(*ports->il1c2tlb_addr);
      SIM_CHECK_EQ(TO_TLB_ADDR(lookup_addr), TO_TLB_ADDR(active_addr));
    } else {
      SIM_CHECK(!*ports->il1c2tlb_re);
    }
    SIM_CHECK(!*ports->il1c2arb_valid);
  }
}
