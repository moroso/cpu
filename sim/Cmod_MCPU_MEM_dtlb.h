#ifndef _CMOD_MCPU_MEM_dtlb_H
#define _CMOD_MCPU_MEM_dtlb_H

#include <map>

#include "verilated.h"

// Simple cmodel for a dual TLB. Does not include a walker
// interface; like the walker cmodel, this is only suitable
// for testing components that are downstream of it (in this
// case, the l1c). It randomly decides if an access will be
// treated as a hit (giving a result next cycle) or a miss
// (with a longer delay).

struct MCPU_MEM_dtlb_ports {
  /* Inputs */
  CData *clk;                           /* 0:0 */
  IData *dtlb_addr_a;                   /* 31:12 */
  IData *dtlb_addr_b;                   /* 31:12 */
  IData *dtlb_pagedir_base;             /* 19:0 */
  CData *dtlb_re_a;                     /* 0:0 */
  CData *dtlb_re_b;                     /* 0:0 */

  /* Outputs */
  CData *dtlb_flags_a;                  /* 3:0 */
  CData *dtlb_flags_b;                  /* 3:0 */
  IData *dtlb_phys_addr_a;              /* 31:12 */
  IData *dtlb_phys_addr_b;              /* 31:12 */
  CData *dtlb_ready;                    /* 0:0 */
};

#define MCPU_MEM_dtlb_CONNECT(str, cla) \
  do { \
    (str)->clk = &((cla)->clk); \
    (str)->dtlb_addr_a = &((cla)->dtlb_addr_a); \
    (str)->dtlb_addr_b = &((cla)->dtlb_addr_b); \
    (str)->dtlb_pagedir_base = &((cla)->dtlb_pagedir_base); \
    (str)->dtlb_re_a = &((cla)->dtlb_re_a); \
    (str)->dtlb_re_b = &((cla)->dtlb_re_b); \
    \
    (str)->dtlb_flags_a = &((cla)->dtlb_flags_a); \
    (str)->dtlb_flags_b = &((cla)->dtlb_flags_b); \
    (str)->dtlb_phys_addr_a = &((cla)->dtlb_phys_addr_a); \
    (str)->dtlb_phys_addr_b = &((cla)->dtlb_phys_addr_b); \
    (str)->dtlb_ready = &((cla)->dtlb_ready); \
  } while(0)

struct dtlb_mapping_entry {
  uint32_t phys;
  uint8_t flags;
};

class Cmod_MCPU_MEM_dtlb {
  int remaining_cycles;
  bool active;

  MCPU_MEM_dtlb_ports *ports;

  uint32_t lookup_addr[2];
  bool re[2];

  std::map<uint32_t, dtlb_mapping_entry> address_map;
public:
  Cmod_MCPU_MEM_dtlb(MCPU_MEM_dtlb_ports *ports);

  void add_mapping(uint32_t virt, uint32_t phys, uint8_t flags);

  void clk();

  void clear();

  bool use_random;
};

#endif
