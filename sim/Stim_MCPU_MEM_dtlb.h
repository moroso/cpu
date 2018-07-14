#ifndef _Stim_MCPU_MEM_dtlb_H
#define _Stim_MCPU_MEM_dtlb_H

#include <queue>
#include "MCPU_MEM_dtlb_ports.h"

class Stim_MCPU_MEM_dtlb {
  struct ReadInfo {
    uint32_t addr_a;
    bool addr_a_valid;
    uint32_t addr_b;
    bool addr_b_valid;

    bool wait_ready; // Whether to wait until this request has finished
                     // before moving on to the next.
  };

  std::queue<ReadInfo> q;
  MCPU_MEM_dtlb_ports *ports;
  bool waiting;

 public:
  Stim_MCPU_MEM_dtlb(MCPU_MEM_dtlb_ports *ports) : ports(ports), waiting(false) {};

  void read(uint32_t addr_a, uint32_t addr_a_valid,
            uint32_t addr_b, uint32_t addr_b_valid);
  void read_nowait(uint32_t addr_a, uint32_t addr_a_valid,
                   uint32_t addr_b, uint32_t addr_b_valid);
  void clk();
  bool done();
};

#endif
