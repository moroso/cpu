#ifndef _Stim_MCPU_MEM_il1c_H
#define _Stim_MCPU_MEM_il1c_H

#include <queue>
#include "MCPU_MEM_il1c_ports.h"

class Stim_MCPU_MEM_il1c {
  struct ReadInfo {
    uint32_t addr;

    bool wait_ready; // Whether to wait until this request has finished
                     // before moving on to the next.
    bool is_pause;
  };

  std::queue<ReadInfo> q;
  MCPU_MEM_il1c_ports *ports;
  bool waiting;

 public:
  Stim_MCPU_MEM_il1c(MCPU_MEM_il1c_ports *ports) : ports(ports), waiting(false) {};

  void read(uint32_t addr);
  void read_nowait(uint32_t addr);
  void pause();
  void clk();
  bool done();
};

#endif
