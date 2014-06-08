#ifndef _Stim_MCPU_MEM_ltc_H
#define _Stim_MCPU_MEM_ltc_H

#include <queue>
#include <inttypes.h>
#include "VMCPU_MEM_ltc.h"


class Stim_MCPU_MEM_ltc {
	struct Command {
		uint8_t opcode;
		uint32_t addr;
		uint32_t wdata[8];
		uint32_t wbe;
	};
	
	VMCPU_MEM_ltc *ltc;
	std::queue<Command> cmdq;
	
public:
	Stim_MCPU_MEM_ltc(VMCPU_MEM_ltc *_ltc) : ltc(_ltc) { };
	
	void read(uint32_t addr, int through);
	void write(uint32_t addr, uint8_t data[32], uint32_t be, int through);
	void prefetch(uint32_t addr);
	void clean(uint32_t addr);
	
	void clk();
	
	int done();
};

#endif
