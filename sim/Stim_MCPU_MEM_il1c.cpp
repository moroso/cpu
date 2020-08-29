#include "Sim.h"

#include "Stim_MCPU_MEM_il1c.h"

void Stim_MCPU_MEM_il1c::read(uint32_t addr) {
  q.push({
        .addr = addr >> 4,
        .wait_ready = true,
        .is_pause = false,
    });
}

void Stim_MCPU_MEM_il1c::read_nowait(uint32_t addr) {
  q.push({
        .addr = addr >> 4,
        .wait_ready = false,
        .is_pause = false,
    });
}

void Stim_MCPU_MEM_il1c::pause() {
  q.push({
      .addr = 0,
      .wait_ready = false,
      .is_pause = true,
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
