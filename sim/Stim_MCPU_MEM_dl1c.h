#ifndef _Stim_MCPU_MEM_dl1c_H
#define _Stim_MCPU_MEM_dl1c_H

#include <queue>
#include "MCPU_MEM_dl1c_ports.h"

enum OpType {
  OP_NOOP,
  OP_READ,
  OP_WRITE,
};

class Dl1c_Op {
public:
  Dl1c_Op(OpType op, uint32_t addr, uint32_t value, uint8_t mask):
    op(op), addr(addr), value(value), mask(mask) {}

  OpType op;
  uint32_t addr;
  uint32_t value;
  uint8_t mask;
};

Dl1c_Op Op_Noop();
Dl1c_Op Op_Read(uint32_t addr);
Dl1c_Op Op_Write(uint32_t addr, uint32_t value);
Dl1c_Op Op_Write_Mask(uint32_t addr, uint32_t value, uint8_t mask);

class Stim_MCPU_MEM_dl1c {
  struct OpInfo {
    Dl1c_Op op0;
    Dl1c_Op op1;

    bool wait_ready; // Whether to wait until this request has finished
                     // before moving on to the next.
  };

  std::queue<OpInfo> q;
  MCPU_MEM_dl1c_ports *ports;
  bool waiting;

 public:
  Stim_MCPU_MEM_dl1c(MCPU_MEM_dl1c_ports *ports) : ports(ports), waiting(false) {};

  void perform(Dl1c_Op op0, Dl1c_Op op1);
  void perform_nowait(Dl1c_Op op0, Dl1c_Op op1);
  void pause() { perform(Op_Noop(), Op_Noop()); }
  void clk();
  bool done();
};

#endif
