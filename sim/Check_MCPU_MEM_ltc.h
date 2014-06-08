#ifndef _Check_MCPU_MEM_ltc_H
#define _Check_MCPU_MEM_ltc_H

#include <map>
#include <queue>
#include <inttypes.h>
#include "VMCPU_MEM_ltc.h"

class Check_MCPU_MEM_ltc {
	struct Atom {
		uint8_t data[32];
		uint32_t valid;
		Atom() : valid(0) { };
	};
	
	struct Response {
		int age;
		uint32_t addr;
		Atom atom;
	};
	
	VMCPU_MEM_ltc *ltc;
	std::map<uint32_t, Atom> memory;
	std::queue<Response> respq;
	
	int stalled_cycles;
	int noisy;

public:
	Check_MCPU_MEM_ltc(VMCPU_MEM_ltc *_ltc) : ltc(_ltc), stalled_cycles(0) {
		noisy = !!getenv("SIM_LTC_CMODEL_NOISY");
	};
	
	void eval();
	void clk();
	
	int done();
};

#endif