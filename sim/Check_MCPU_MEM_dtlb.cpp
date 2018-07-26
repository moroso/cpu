#include "Sim.h"

#include "Check_MCPU_MEM_dtlb.h"
#include "mem_common.h"

uint8_t combine_flags(uint8_t pd_flags, uint8_t pt_flags) {
  return ((pd_flags & pt_flags) |
          ((pd_flags | pt_flags) & 0xc));
}

Check_MCPU_MEM_dtlb::Check_MCPU_MEM_dtlb(MCPU_MEM_dtlb_ports *ports):
  ports(ports), active(false), addr_a_valid(false), addr_b_valid(false),
  walk_active(false)
{
}

void Check_MCPU_MEM_dtlb::reset() {
  active = false;
  walk_active = false;
  addr_a_valid = false;
  addr_b_valid = false;
  for (int i = 0; i < NUM_SETS; i++) {
    address_map.clear();
  }
}

void Check_MCPU_MEM_dtlb::check_outputs() {
  if (addr_a_valid) {
    CacheEntry *entry = &address_map[active_addr_a];
    SIM_ASSERT(entry);
    if (entry->flags & (1<<PT_BIT_PRESENT)) {
      SIM_CHECK_MSG(entry->phys_addr == *ports->dtlb_phys_addr_a,
                    "Addr A: expected %x, got %x",
                    entry->phys_addr, *ports->dtlb_phys_addr_a);
      SIM_CHECK(entry->flags == *ports->dtlb_flags_a);
    }
  }
  if (addr_b_valid) {
    CacheEntry *entry = &address_map[active_addr_b];
    SIM_ASSERT(entry);
    if (entry->flags & (1<<PT_BIT_PRESENT)) {
      SIM_CHECK_MSG(entry->phys_addr == *ports->dtlb_phys_addr_b,
                    "Addr B: expected %x, got %x",
                    entry->phys_addr, *ports->dtlb_phys_addr_b);
      SIM_CHECK(entry->flags == *ports->dtlb_flags_b);
    }
  }
}

void Check_MCPU_MEM_dtlb::clk() {
  SIM_CHECK(*ports->dtlb_pagedir_base == *ports->tlb2ptw_pagedir_base);
  if (active) {
    if (walk_active && *ports->tlb2ptw_ready) {
      // Just finished walking; store the result.
      walk_active = false;

      address_map[walk_addr] = {
        .phys_addr = *ports->tlb2ptw_phys_addr,
        .flags = combine_flags(*ports->tlb2ptw_pagedir_flags,
                               *ports->tlb2ptw_pagetab_flags),
        .valid = true,
      };
    }

    if (walk_active) {
      SIM_CHECK(*ports->tlb2ptw_addr == walk_addr);
    } else {
      if (*ports->tlb2ptw_re) {
        // Beginning a walk. Make sure we were expecting it.
        walk_active = true;
        walk_addr = *ports->tlb2ptw_addr;
      }
    }

    if (*ports->dtlb_ready) {
      active = false;

      check_outputs();
    }
  }
  if (!active) {
    if (*ports->dtlb_re_a || *ports->dtlb_re_b) {
      active = true;
      addr_a_valid = *ports->dtlb_re_a;
      addr_b_valid = *ports->dtlb_re_b;
      active_addr_a = *ports->dtlb_addr_a;
      active_addr_b = *ports->dtlb_addr_b;
    } else {
      SIM_CHECK(!*ports->tlb2ptw_re);
      // Outputs should not change until a new request comes in.
      check_outputs();
    }
  }
}
