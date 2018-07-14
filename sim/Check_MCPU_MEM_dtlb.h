#ifndef _Check_MCPU_MEM_dtlb_H
#define _Check_MCPU_MEM_dtlb_H

#define SET_WIDTH 13
#define TAG_WIDTH 7

#define NUM_SETS (1<<SET_WIDTH)

#include <queue>
#include "MCPU_MEM_dtlb_ports.h"

class Check_MCPU_MEM_dtlb {
  struct CacheEntry {
    uint32_t addr;
    uint32_t phys_addr;
    uint8_t flags;
    bool valid;
  };

  CacheEntry lines[NUM_SETS][2];
  uint8_t next_evict[NUM_SETS];

  bool active;
  uint32_t active_addr_a;
  bool addr_a_valid;
  uint32_t active_addr_b;
  bool addr_b_valid;

  uint32_t walk_addr;
  uint32_t walk_active;

  MCPU_MEM_dtlb_ports *ports;

  Check_MCPU_MEM_dtlb::CacheEntry *entry_for_addr(uint32_t addr);
  int way_for_addr(uint32_t addr);
  void update_evict_from_hit(uint32_t addr);
  void update_evict_from_miss(uint32_t addr);
  void check_outputs();

  std::queue<uint32_t> walk_queue;
 public:
  Check_MCPU_MEM_dtlb(MCPU_MEM_dtlb_ports *ports);

  void clk();
  void reset();
};

#endif
