#include "Sim.h"

#include "Stim_MCPU_MEM_il1c.h"

void Stim_MCPU_MEM_il1c::read(uint32_t addr) {
  q.push({
        addr >> 4,
        true,
        false,
    });
}

void Stim_MCPU_MEM_il1c::read_nowait(uint32_t addr) {
  q.push({
        addr >> 4,
        false,
        false,
    });
}

void Stim_MCPU_MEM_il1c::pause() {
  q.push({
      0,
      false,
      true,
    });
}

void Stim_MCPU_MEM_il1c::clk() {
  if (waiting) {
    if (*ports->il1c_ready) {
      waiting = false;
    }
  }

  if (!waiting) {
    if (q.empty()) {
      *ports->il1c_re = 0;
      return;
    }

    ReadInfo entry = q.front();
    q.pop();

    *ports->il1c_addr = entry.addr;
    *ports->il1c_re = !entry.is_pause;

    waiting = entry.wait_ready;
  }
}

bool Stim_MCPU_MEM_il1c::done() {
  return !waiting && q.empty();
}
