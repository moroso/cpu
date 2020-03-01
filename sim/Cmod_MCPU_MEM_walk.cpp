#include "Cmod_MCPU_MEM_walk.h"
#include "Sim.h"
#include "mem_common.h"

#define DELAY_CYCLES_BASE 16
#define DELAY_CYCLES_RAND 1

Cmod_MCPU_MEM_walk::Cmod_MCPU_MEM_walk(Cmod_MCPU_MEM_walk_ports *ports) :
  active(false),
  remaining_cycles(0),
  ports(ports),
  accesses(0),
  use_random(false)
{
}

void Cmod_MCPU_MEM_walk::add_mapping(uint32_t virt,
                                     uint32_t phys,
                                     uint8_t pd_flags,
                                     uint8_t pt_flags) {
  address_map[virt] = mapping_entry {
    .phys = phys,
    .pd_flags = pd_flags,
    .pt_flags = pt_flags,
  };
}

void Cmod_MCPU_MEM_walk::latch() {
  last_tlb2ptw_addr = *ports->tlb2ptw_addr;
  last_tlb2ptw_re = *ports->tlb2ptw_re;
  last_read_time = Sim::main_time;
}

void Cmod_MCPU_MEM_walk::clk() {
  SIM_ASSERT_MSG(
    last_read_time == Sim::main_time,
    "Last read arguments at %d, not at %d (forgot call to latch()?)",
    last_read_time, Sim::main_time
  );

  if (active) {
    remaining_cycles -= 1;

    if (remaining_cycles == 0) {
      active = false;

      if (address_map.find(last_tlb2ptw_addr) == address_map.end()) {
        if (use_random) {
          address_map[last_tlb2ptw_addr] = {
            .phys = (uint32_t)Sim::random(1<<20),
            .pd_flags = (uint8_t)Sim::random(1<<4),
            .pt_flags = (uint8_t)Sim::random(1<<4),
          };
        } else {
          SIM_ERROR("Address map does not contain %x", last_tlb2ptw_addr);
        }
      }
      mapping_entry entry = address_map[last_tlb2ptw_addr];
      *ports->tlb2ptw_phys_addr = entry.phys;
      *ports->tlb2ptw_pagedir_flags = entry.pd_flags;
      *ports->tlb2ptw_pagetab_flags = entry.pt_flags;
      *ports->tlb2ptw_ready = 1;
    }
  } else if (last_tlb2ptw_re) {
    accesses += 1;
    active = true;
    *ports->tlb2ptw_ready = 0;
    remaining_cycles = DELAY_CYCLES_BASE + Sim::random(DELAY_CYCLES_RAND);
  }
}

void Cmod_MCPU_MEM_walk::clear() {
  if (active) { SIM_FATAL("Clearing active walker"); }

  address_map.clear();
}
