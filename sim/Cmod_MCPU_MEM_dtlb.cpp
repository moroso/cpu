#include "Cmod_MCPU_MEM_dtlb.h"
#include "Sim.h"

#define MISS_DELAY_BASE 32
#define MISS_DELAY_RANDOM 32

Cmod_MCPU_MEM_dtlb::Cmod_MCPU_MEM_dtlb(Cmod_MCPU_MEM_dtlb_ports *ports) :
  use_random(false),
  active(false),
  ports(ports)
{
}

void Cmod_MCPU_MEM_dtlb::clear() {
  address_map.clear();
  use_random = false;
  active = false;
}

void Cmod_MCPU_MEM_dtlb::latch() {
  last_dtlb_addr_a = *ports->dtlb_addr_a;
  last_dtlb_re_a = *ports->dtlb_re_a;
  if (ports->dual) {
    last_dtlb_addr_b = *ports->dtlb_addr_b;
    last_dtlb_re_b = *ports->dtlb_re_b;
  }
  last_read_time = Sim::main_time;
}

void Cmod_MCPU_MEM_dtlb::clk() {
  SIM_ASSERT_MSG(
    last_read_time == Sim::main_time,
    "Last read arguments at %d, not at %d (forgot call to latch()?)",
    last_read_time, Sim::main_time
  );

  if (!active && (last_dtlb_re_a || (ports->dual && last_dtlb_re_b))) {
    re[0] = last_dtlb_re_a;
    lookup_addr[0] = last_dtlb_addr_a;
    if (ports->dual) {
      re[1] = last_dtlb_re_b;
      lookup_addr[1] = last_dtlb_addr_b;
    }

    active = 1;
    *ports->dtlb_ready = 0;

    if (Sim::random(2) == 0) {
      // Half the time, simulate a cache hit and give an answer next cycle.
      remaining_cycles = 1;
    } else {
      // The rest of the time, wait a random number of cycles.
      remaining_cycles = MISS_DELAY_BASE + Sim::random(MISS_DELAY_RANDOM);
    }
  }

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
      if (ports->dual && re[1]) {
        dtlb_mapping_entry entry_b = address_map[lookup_addr[1]];
        *ports->dtlb_phys_addr_b = entry_b.phys;
        *ports->dtlb_flags_b = entry_b.flags;
      }
      *ports->dtlb_ready = 1;
    } else { // if (remaining_cycles == 0)
      // Until the ready signal is asserted, the outputs are allowed to have any
      // values and are allowed to change. So, change them!
      *ports->dtlb_phys_addr_a = Sim::random(1<<20);
      *ports->dtlb_flags_a = Sim::random(1<<4);
      if (ports->dual) {
        *ports->dtlb_phys_addr_b = Sim::random(1<<20);
        *ports->dtlb_flags_b = Sim::random(1<<4);
      }
    }
  }
}

void Cmod_MCPU_MEM_dtlb::add_mapping(uint32_t virt, uint32_t phys, uint8_t flags) {
  address_map[virt] = {
    .phys = phys,
    .flags = flags,
  };
}
