#include "Cmod_MCPU_MEM_dtlb.h"
#include "Sim.h"

#define MISS_DELAY_BASE 32
#define MISS_DELAY_RANDOM 32

Cmod_MCPU_MEM_dtlb::Cmod_MCPU_MEM_dtlb(MCPU_MEM_dtlb_ports *ports) :
  use_random(false),
  active(false)
{
}

void Cmod_MCPU_MEM_dtlb::clear() {
  address_map.clear();
  use_random = false;
  active = false;
}

void Cmod_MCPU_MEM_dtlb::clk() {
  if (active) {
    remaining_cycles -= 1;
    if (remaining_cycles == 0) {
      active = 0;
      for (int i = 0; i < 2; i++) {
        if (!re[i]) continue;
        if (address_map.find(lookup_addr[i]) == address_map.end()) {
          if (use_random) {
            add_mapping(lookup_addr[i],
                        (uint32_t)Sim::random(1<<20),
                        (uint8_t)Sim::random(1<<4));
          } else {
            SIM_ERROR("Address map does not contain %x", lookup_addr[i]);
          }
        }
      }
      if (re[0]) {
        dtlb_mapping_entry entry_a = address_map[lookup_addr[0]];
        *ports->dtlb_phys_addr_a = entry_a.phys;
        *ports->dtlb_flags_a = entry_a.flags;
      }
      if (re[1]) {
        dtlb_mapping_entry entry_b = address_map[lookup_addr[1]];
        *ports->dtlb_phys_addr_b = entry_b.phys;
        *ports->dtlb_flags_b = entry_b.flags;
      }
      *ports->dtlb_ready = 1;
    } else { // if (remaining_cycles == 0)
      // Until the ready signal is asserted, the outputs are allowed to have any
      // values and are allowed to change. So, change them!
      *ports->dtlb_phys_addr_a = Sim::random(1<<20);
      *ports->dtlb_phys_addr_b = Sim::random(1<<20);
      *ports->dtlb_flags_a = Sim::random(1<<4);
      *ports->dtlb_flags_b = Sim::random(1<<4);
    }
  }

  if (*ports->dtlb_re_a || *ports->dtlb_re_b) {
    re[0] = *ports->dtlb_re_a;
    re[1] = *ports->dtlb_re_b;
    lookup_addr[0] = *ports->dtlb_addr_a;
    lookup_addr[1] = *ports->dtlb_addr_b;

    active = 1;

    if (Sim::random(2) == 0) {
      // Half the time, simulate a cache hit and give an answer next cycle.
      remaining_cycles = 1;
    } else {
      // The rest of the time, wait a random number of cycles.
      remaining_cycles = MISS_DELAY_BASE + Sim::random(MISS_DELAY_RANDOM);
    }
  }
}

void Cmod_MCPU_MEM_dtlb::add_mapping(uint32_t virt, uint32_t phys, uint8_t flags) {
  address_map[virt] = {
    .phys = phys,
    .flags = flags,
  };
}
