#ifndef _Check_MCPU_MEM_il1c_H
#define _Check_MCPU_MEM_il1c_H

#define SET_WIDTH 4
#define TAG_WIDTH 23

#define LINE_SIZE 256
#define LINE_SIZE_WORDS (LINE_SIZE / 32)

#define NUM_SETS (1<<SET_WIDTH)

#include "MCPU_MEM_il1c_ports.h"

class Check_MCPU_MEM_il1c {
  struct CacheEntry {
    uint32_t line[LINE_SIZE_WORDS];
    uint32_t tag;
    bool valid;
  };

  bool active;
  bool lookup_active;
  bool fetch_active;

  uint32_t lookup_addr;
  uint32_t lookup_result;

  uint32_t fetch_addr;

  uint32_t active_addr;

  //bool addr_valid;

  MCPU_MEM_il1c_ports *ports;

  Check_MCPU_MEM_il1c::CacheEntry *entry_for_addr(uint32_t addr);
  void check_outputs();

  //std::map<uint32_t, CacheEntry> address_map;
  CacheEntry address_map[NUM_SETS];
 public:
  Check_MCPU_MEM_il1c(MCPU_MEM_il1c_ports *ports);

  void clk();
  void reset();

  bool done() {
    return !active;
  }
};

#endif
