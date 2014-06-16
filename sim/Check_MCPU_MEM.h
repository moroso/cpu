#ifndef _Check_MCPU_MEM_H
#define _Check_MCPU_MEM_H

#include <map>
#include <queue>
#include <inttypes.h>
#include "MCPU_MEM_ports.h"

class Check_MCPU_MEM {
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
	
	MCPU_MEM_ports *ports;
	std::map<uint32_t, Atom> memory;
	std::queue<Response> respq;
	
	int stalled_cycles;

public:
	Check_MCPU_MEM(MCPU_MEM_ports *_ports) : ports(_ports), stalled_cycles(0) { };
	
	void clk();
	
	int done();
};

#endif