#ifndef _CMOD_MCPU_MEM_walk_H
#define _CMOD_MCPU_MEM_walk_H

#include <map>

#include "verilated.h"

// Simple cmodel for walker--just stores a map of addresses;
// doesn't actually interact with the arb. This is suitable
// for unit testing TLBs, but not for much else.

struct Cmod_MCPU_MEM_walk_ports {
  /* Inputs */
  IData *tlb2ptw_addr; // 20 bits
  CData *tlb2ptw_re; // 1 bit

  /* Outputs */
  IData *tlb2ptw_phys_addr; // 20 bits
  CData *tlb2ptw_ready; // 1 bit
  CData *tlb2ptw_pagetab_flags; // 4 bits
  CData *tlb2ptw_pagedir_flags; // 4 bits
};

#define Cmod_MCPU_MEM_walk_CONNECT(str, cla) \
	do { \
		(str)->tlb2ptw_addr = &((cla)->tlb2ptw_addr); \
		(str)->tlb2ptw_re = &((cla)->tlb2ptw_re); \
		\
		(str)->tlb2ptw_phys_addr = &((cla)->tlb2ptw_phys_addr); \
		(str)->tlb2ptw_ready = &((cla)->tlb2ptw_ready); \
		(str)->tlb2ptw_pagetab_flags = &((cla)->tlb2ptw_pagetab_flags); \
		(str)->tlb2ptw_pagedir_flags = &((cla)->tlb2ptw_pagedir_flags); \
	} while(0)

struct mapping_entry {
  uint32_t phys;
  uint8_t pd_flags;
  uint8_t pt_flags;
};

class Cmod_MCPU_MEM_walk {
  int remaining_cycles;
  bool active;

  int accesses;

  Cmod_MCPU_MEM_walk_ports *ports;

  IData last_tlb2ptw_addr;
  CData last_tlb2ptw_re;
  vluint64_t last_read_time;

  std::map<uint32_t, mapping_entry> address_map;
public:
  Cmod_MCPU_MEM_walk(Cmod_MCPU_MEM_walk_ports *ports);

  void add_mapping(uint32_t virt, uint32_t phys, uint8_t pd_flags, uint8_t pt_flags);

  void latch();
  void clk();

  void clear();

  int get_access_count() { return accesses; }

  bool use_random;
};

#endif
