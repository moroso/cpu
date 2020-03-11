#ifndef _MCPU_MEM_dtlb_ports_H
#define _MCPU_MEM_dtlb_ports_H

#include "verilated.h"

struct MCPU_MEM_dtlb_ports {
  /* Outputs */
  // Walk interface
  IData *tlb2ptw_addr; // 20 bits
  CData *tlb2ptw_re; // 1 bit

  // Control interface
  IData *dtlb_phys_addr_a; // 20 bits
  IData *dtlb_phys_addr_b; // 20 bits
  CData *dtlb_flags_a; // 4 bits
  CData *dtlb_flags_b; // 4 bits
  CData *dtlb_ready; // 1 bit

  /* Inputs */
  // Walk interface
  IData *tlb2ptw_phys_addr; // 20 bits
  CData *tlb2ptw_ready; // 1 bit
  CData *tlb2ptw_pagetab_flags; // 4 bits
  CData *tlb2ptw_pagedir_flags; // 4 bits

  // Control interface
  IData *dtlb_addr_a; // 20 bits
  IData *dtlb_addr_b; // 20 bits
  CData *dtlb_re_a; // 1 bit
  CData *dtlb_re_b; // 1 bit
};


#define MCPU_MEM_dtlb_CONNECT(str, cla) \
	do { \
    (str)->tlb2ptw_addr = &((cla)->tlb2ptw_addr); \
    (str)->tlb2ptw_re = &((cla)->tlb2ptw_re); \
    \
    (str)->dtlb_phys_addr_a = &((cla)->dtlb_phys_addr_a); \
    (str)->dtlb_phys_addr_b = &((cla)->dtlb_phys_addr_b); \
    (str)->dtlb_flags_a = &((cla)->dtlb_flags_a); \
    (str)->dtlb_flags_b = &((cla)->dtlb_flags_b); \
    (str)->dtlb_ready = &((cla)->dtlb_ready); \
    \
    (str)->tlb2ptw_phys_addr = &((cla)->tlb2ptw_phys_addr); \
    (str)->tlb2ptw_ready = &((cla)->tlb2ptw_ready); \
    (str)->tlb2ptw_pagetab_flags = &((cla)->tlb2ptw_pagetab_flags); \
    (str)->tlb2ptw_pagedir_flags = &((cla)->tlb2ptw_pagedir_flags); \
    \
    (str)->dtlb_addr_a = &((cla)->dtlb_addr_a); \
    (str)->dtlb_addr_b = &((cla)->dtlb_addr_b); \
    (str)->dtlb_re_a = &((cla)->dtlb_re_a); \
    (str)->dtlb_re_b = &((cla)->dtlb_re_b); \
	} while(0)

#endif
