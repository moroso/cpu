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
  for (int i = 0; i < NUM_SETS; i++) {
    lines[i][0].valid = 0;
    lines[i][1].valid = 0;
    next_evict[i] = 0;
  }
}

static int set_for_addr(uint32_t addr) {
  return addr & ((1<<SET_WIDTH)-1);
}

int Check_MCPU_MEM_dtlb::way_for_addr(uint32_t addr) {
  uint32_t set = set_for_addr(addr);

  for (int way = 0; way < 2; way++) {
    if (lines[set][way].addr == addr && lines[set][way].valid) {
      return way;
    }
  }

  return -1;
}

Check_MCPU_MEM_dtlb::CacheEntry *Check_MCPU_MEM_dtlb::entry_for_addr(uint32_t addr) {
  int way = way_for_addr(addr);
  int set = set_for_addr(addr);
  if (way < 0)
    return NULL;
  else
    return &lines[set][way];
}

void Check_MCPU_MEM_dtlb::update_evict_from_hit(uint32_t addr) {
  int way = way_for_addr(addr);
  assert(way >= 0);

  next_evict[set_for_addr(addr)] = !way;
}

void Check_MCPU_MEM_dtlb::update_evict_from_miss(uint32_t addr) {
  next_evict[set_for_addr(addr)] = !next_evict[set_for_addr(addr)];
}

void Check_MCPU_MEM_dtlb::reset() {
  active = false;
  walk_active = false;
  addr_a_valid = false;
  addr_b_valid = false;
  for (int i = 0; i < NUM_SETS; i++) {
    lines[i][0].valid = 0;
    lines[i][1].valid = 0;
    next_evict[i] = 0;
  }
}

void Check_MCPU_MEM_dtlb::check_outputs() {
  if (addr_a_valid) {
    CacheEntry *entry = entry_for_addr(active_addr_a);
    SIM_ASSERT(entry);
    if (entry->flags & (1<<PT_BIT_PRESENT)) {
      SIM_CHECK_MSG(entry->phys_addr == *ports->dtlb_phys_addr_a,
                    "Addr A: expected %x, got %x",
                    entry->phys_addr, *ports->dtlb_phys_addr_a);
      SIM_CHECK(entry->flags == *ports->dtlb_flags_a);
    }
  }
  if (addr_b_valid) {
    CacheEntry *entry = entry_for_addr(active_addr_b);
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

      uint32_t set = set_for_addr(walk_addr);
      lines[set][next_evict[set]] = {
        .addr = walk_addr,
        .phys_addr = *ports->tlb2ptw_phys_addr,
        .flags = combine_flags(*ports->tlb2ptw_pagedir_flags,
                               *ports->tlb2ptw_pagetab_flags),
        .valid = true,
      };
      update_evict_from_miss(walk_addr);
    }

    if (walk_active) {
      SIM_CHECK(*ports->tlb2ptw_addr == walk_addr);
    } else {
      if (*ports->tlb2ptw_re) {
        // Beginning a walk. Make sure we were expecting it.
        walk_active = true;
        walk_addr = *ports->tlb2ptw_addr;

        SIM_CHECK(!walk_queue.empty());
        uint32_t addr = walk_queue.front();
        walk_queue.pop();

        SIM_CHECK_MSG(addr == walk_addr,
                      "Expected walk of %x, but walked %x instead",
                      addr, walk_addr);
      }
    }

    if (*ports->dtlb_ready) {
      // By now, all walks should have been done.
      SIM_CHECK(walk_queue.empty());

      active = false;

      check_outputs();
    }
  } else {
    if (*ports->dtlb_re_a || *ports->dtlb_re_b) {
      active = true;
      addr_a_valid = *ports->dtlb_re_a;
      addr_b_valid = *ports->dtlb_re_b;
      active_addr_a = *ports->dtlb_addr_a;
      active_addr_b = *ports->dtlb_addr_b;

      bool addr_a_miss = entry_for_addr(active_addr_a) == NULL;
      bool addr_b_miss = entry_for_addr(active_addr_b) == NULL;

      if (addr_a_valid) {
        if (addr_a_miss) {
          // Address A is not in the cache; expect a lookup of it.
          walk_queue.push(active_addr_a);
        } else {
          update_evict_from_hit(active_addr_a);
        }
      }
      if (addr_b_valid) {
        if (addr_b_miss) {
          if (!(addr_a_valid && addr_a_miss && (active_addr_a == active_addr_b))) {
            // If B is reading the same address as A and both miss, we should only
            // do a single walk.
            walk_queue.push(active_addr_b);
          }
        } else {
          update_evict_from_hit(active_addr_b);
        }
      }
    } else {
      SIM_CHECK(!*ports->tlb2ptw_re);
      // Outputs should not change until a new request comes in.
      check_outputs();
    }
  }
}
