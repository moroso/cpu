#include "Sim.h"

#include "Stim_MCPU_MEM_dtlb.h"

void Stim_MCPU_MEM_dtlb::read(uint32_t addr_a, uint32_t addr_a_valid,
                              uint32_t addr_b, uint32_t addr_b_valid) {
  q.push({
        .addr_a = addr_a,
        .addr_a_valid = addr_a_valid,
        .addr_b = addr_b,
        .addr_b_valid = addr_b_valid,
        .wait_ready = true,
    });
}

void Stim_MCPU_MEM_dtlb::read_nowait(uint32_t addr_a, uint32_t addr_a_valid,
                                     uint32_t addr_b, uint32_t addr_b_valid) {
  q.push({
        .addr_a = addr_a,
        .addr_a_valid = addr_a_valid,
        .addr_b = addr_b,
        .addr_b_valid = addr_b_valid,
        .wait_ready = false,
    });
}

void Stim_MCPU_MEM_dtlb::clk() {
  if (waiting) {
    if (*ports->dtlb_ready) {
      waiting = false;
    }
  }

  if (!waiting) {
    if (q.empty()) {
      *ports->dtlb_re_a = 0;
      *ports->dtlb_re_b = 0;
      return;
    }

    ReadInfo entry = q.front();
    q.pop();

    *ports->dtlb_addr_a = entry.addr_a;
    *ports->dtlb_re_a = entry.addr_a_valid;
    *ports->dtlb_addr_b = entry.addr_b;
    *ports->dtlb_re_b = entry.addr_b_valid;

    waiting = entry.wait_ready;
  }
}

bool Stim_MCPU_MEM_dtlb::done() {
  return !waiting && q.empty();
}
