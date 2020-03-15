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

// TODO: simulate the reset signal

struct Cmod_MCPU_MEM_dtlb_ports {
  /* Inputs */
  CData *clkrst_mem_clk;                /* 0:0 */
  CData *clkrst_mem_rst_n;              /* 0:0 */
  IData *dtlb_addr_a;                   /* 31:12 */
  IData *dtlb_addr_b;                   /* 31:12 */
  CData *dtlb_re_a;                     /* 0:0 */
  CData *dtlb_re_b;                     /* 0:0 */

  /* Outputs */
  CData *dtlb_flags_a;                  /* 3:0 */
  CData *dtlb_flags_b;                  /* 3:0 */
  IData *dtlb_phys_addr_a;              /* 31:12 */
  IData *dtlb_phys_addr_b;              /* 31:12 */
  CData *dtlb_ready;                    /* 0:0 */

  // Marks whether we're using both ports or just one.
  int dual;
};

#define Cmod_MCPU_MEM_dtlb_CONNECT(str, cla, pfx) \
  do { \
    (str)->clkrst_mem_clk = &((cla)->clkrst_mem_clk); \
    (str)->clkrst_mem_rst_n = &((cla)->clkrst_mem_rst_n); \
    (str)->dtlb_addr_a = &((cla)->pfx##addr_a); \
    (str)->dtlb_addr_b = &((cla)->pfx##addr_b); \
    (str)->dtlb_re_a = &((cla)->pfx##re_a); \
    (str)->dtlb_re_b = &((cla)->pfx##re_b); \
    \
    (str)->dtlb_flags_a = &((cla)->pfx##flags_a); \
    (str)->dtlb_flags_b = &((cla)->pfx##flags_b); \
    (str)->dtlb_phys_addr_a = &((cla)->pfx##phys_addr_a); \
    (str)->dtlb_phys_addr_b = &((cla)->pfx##phys_addr_b); \
    (str)->dtlb_ready = &((cla)->pfx##ready); \
    (str)->dual = 1; \
  } while(0)

#define Cmod_MCPU_MEM_dtlb_CONNECT_SINGLE(str, cla, pfx) \
  do { \
    (str)->clkrst_mem_clk = &((cla)->clkrst_mem_clk); \
    (str)->clkrst_mem_rst_n = &((cla)->clkrst_mem_rst_n); \
    (str)->dtlb_addr_a = &((cla)->pfx##addr); \
    (str)->dtlb_re_a = &((cla)->pfx##re); \
    \
    (str)->dtlb_flags_a = &((cla)->pfx##flags); \
    (str)->dtlb_phys_addr_a = &((cla)->pfx##phys_addr); \
    (str)->dtlb_ready = &((cla)->pfx##ready); \
    (str)->dual = 0; \
  } while(0)

struct dtlb_mapping_entry {
  uint32_t phys;
  uint8_t flags;
};

class Cmod_MCPU_MEM_dtlb {
  int remaining_cycles;
  bool active;

  Cmod_MCPU_MEM_dtlb_ports *ports;

  uint32_t lookup_addr[2];
  bool re[2];

  std::map<uint32_t, dtlb_mapping_entry> address_map;

  IData last_dtlb_addr_a;
  IData last_dtlb_addr_b;
  CData last_dtlb_re_a;
  CData last_dtlb_re_b;
  vluint64_t last_read_time;

public:

  Cmod_MCPU_MEM_dtlb(Cmod_MCPU_MEM_dtlb_ports *ports);

  void add_mapping(uint32_t virt, uint32_t phys, uint8_t flags);

  void latch();
  void clk();

  void clear();

  bool use_random;
};

#endif
