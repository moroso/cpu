#ifndef _CMOD_MCPU_MEM_arb_H
#define _CMOD_MCPU_MEM_arb_H

#include <vector>
#include "verilated.h"

#define Cmod_MCPU_MEM_arb_MEMSZ 512*1024*1024

struct Cmod_MCPU_MEM_arb_ports {
  /* Inputs */
  CData *arb_valid; // [0:0]
  CData *arb_opcode; // [3:0]
  IData *arb_addr; // [26:0]
  WData *arb_wdata; // [255:0]
  IData *arb_wbe; // [31:0]

  /* Outputs */
	CData *arb_stall; // [0:0]
  WData *arb_rdata; // [255:0]
  CData *arb_rvalid; // [0:0]
};

#define Cmod_MCPU_MEM_arb_CONNECT(str, cla, prefix) \
	do { \
		(str)->arb_valid = &((cla)->prefix##2arb_valid); \
		(str)->arb_opcode = &((cla)->prefix##2arb_opcode); \
		(str)->arb_addr = &((cla)->prefix##2arb_addr); \
		(str)->arb_wdata = ((cla)->prefix##2arb_wdata); \
		(str)->arb_wbe = &((cla)->prefix##2arb_wbe); \
		\
		(str)->arb_stall = &((cla)->prefix##2arb_stall); \
		(str)->arb_rdata = ((cla)->prefix##2arb_rdata); \
		(str)->arb_rvalid = &((cla)->prefix##2arb_rvalid); \
	} while(0)

class Cmod_MCPU_MEM_arb {
  std::vector<Cmod_MCPU_MEM_arb_ports*> clients;
  int current_client;
  bool active;
  int remaining_cycles;

	uint8_t memory[Cmod_MCPU_MEM_arb_MEMSZ];

public:
  Cmod_MCPU_MEM_arb();
  void add_client(Cmod_MCPU_MEM_arb_ports *client_ports);
  void write_w(uint32_t addr, uint32_t val);
  void write_h(uint32_t addr, uint16_t val);
  void write_b(uint32_t addr, uint8_t  val);

  uint32_t read(uint32_t addr);

  void clk();
};

#endif
