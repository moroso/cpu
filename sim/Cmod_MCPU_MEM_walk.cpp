#include "Cmod_MCPU_MEM_walk.h"
#include "Sim.h"
#include "mem_common.h"

#define DELAY_CYCLES_BASE 16
#define DELAY_CYCLES_RAND 1

Cmod_MCPU_MEM_walk::Cmod_MCPU_MEM_walk(Cmod_MCPU_MEM_walk_ports *ports) :
  active(false),
  remaining_cycles(0),
  ports(ports),
  accesses(0)
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

void Cmod_MCPU_MEM_walk::clk() {
  if (active) {
    remaining_cycles -= 1;

    if (remaining_cycles == 0) {
      active = false;

      if (address_map.find(*ports->tlb2ptw_addr) == address_map.end()) {
        SIM_ERROR("Address map does not contain %x", *ports->tlb2ptw_addr);
      }
      mapping_entry entry = address_map[*ports->tlb2ptw_addr];
      *ports->tlb2ptw_phys_addr = entry.phys;
      *ports->tlb2ptw_pagedir_flags = entry.pd_flags;
      *ports->tlb2ptw_pagetab_flags = entry.pt_flags;
      *ports->tlb2ptw_ready = 1;
    }
  } else if (*ports->tlb2ptw_re) {
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
