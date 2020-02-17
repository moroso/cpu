#include "Sim.h"

#include "Stim_MCPU_MEM_dl1c.h"

Dl1c_Op Op_Noop() {
  return Dl1c_Op(OP_NOOP, 0, 0, 0);
}

Dl1c_Op Op_Read(uint32_t addr) {
  return Dl1c_Op(OP_READ, addr, 0, 0);
}

Dl1c_Op Op_Write(uint32_t addr, uint32_t value) {
  return Op_Write_Mask(addr, value, 0xf);
}

Dl1c_Op Op_Write_Mask(uint32_t addr, uint32_t value, uint8_t mask) {
  return Dl1c_Op(OP_WRITE, addr, value, mask);
}

void Stim_MCPU_MEM_dl1c::perform(Dl1c_Op op0, Dl1c_Op op1) {
  q.push({
          .op0 = op0,
          .op1 = op1,
          .wait_ready = true,
    });
}

void Stim_MCPU_MEM_dl1c::perform_nowait(Dl1c_Op op0, Dl1c_Op op1) {
  q.push({
          .op0 = op0,
          .op1 = op1,
          .wait_ready = false,
    });
}

void Stim_MCPU_MEM_dl1c::clk() {
  if (waiting) {
    if (*ports->dl1c_ready) {
      waiting = false;
    }
  }

  if (!waiting) {
    if (q.empty()) {
      *ports->dl1c_re_a = 0;
      *ports->dl1c_re_b = 0;
      *ports->dl1c_we_a = 0;
      *ports->dl1c_we_b = 0;
      return;
    }

    OpInfo entry = q.front();
    q.pop();

    *ports->dl1c_addr_a = entry.op0.addr >> 2;
    *ports->dl1c_in_a = entry.op0.value;
    *ports->dl1c_addr_b = entry.op1.addr >> 2;
    *ports->dl1c_in_b = entry.op1.value;

    *ports->dl1c_re_a = (entry.op0.op == OP_READ);
    *ports->dl1c_we_a = (entry.op0.op == OP_WRITE ? entry.op0.mask : 0);
    *ports->dl1c_re_b = (entry.op1.op == OP_READ);
    *ports->dl1c_we_b = (entry.op1.op == OP_WRITE ? entry.op0.mask : 0);

    waiting = entry.wait_ready;
  }
}

bool Stim_MCPU_MEM_dl1c::done() {
  return !waiting && q.empty();
}
