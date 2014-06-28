#include "verilated.h"
#include "Check_MCPU_MEM.h"
#include "Sim.h"

#define MEM_OPC_READ         0x0
#define MEM_OPC_WRITE        0x1
#define MEM_OPC_READTHROUGH  0x2
#define MEM_OPC_WRITETHROUGH 0x3
#define MEM_OPC_PREFETCH     0x4
#define MEM_OPC_CLEAN        0x6

#define MEM_STALLED_CYCLES_MAX 1000
#define MEM_LATENCY_MAX 500

void Check_MCPU_MEM::clk() {
	/* Check: input stall */
	if (*ports->stall)
		stalled_cycles++;
	else
		stalled_cycles = 0;
	
	SIM_CHECK(stalled_cycles < MEM_STALLED_CYCLES_MAX);
	
	/* Check: response head-of-line age */
	if (!respq.empty()) {
		Check_MCPU_MEM::Response &resp = respq.front();
		resp.age++;
		SIM_CHECK(resp.age < MEM_LATENCY_MAX);
	}

	/* Handle responses -- before inbound transactions, since we can't respond same-cycle! */
	if (*ports->rvalid) {
		SIM_DEBUG("response valid");

		SIM_CHECK_MSG(!respq.empty(), "ltc response came back without outbound read request");
		if (respq.empty())
			return;
		
		Check_MCPU_MEM::Response &resp = respq.front();
		for (int i = 0; i < 32; i++)
			if (resp.atom.valid & (1 << i))
				SIM_CHECK_MSG(resp.atom.data[i] == ((ports->rdata[i / 4] >> ((i % 4) * 8)) & 0xFF),
				              "incorrect memory response (addr %08x, byte %d, expected %02x, got %02x)",
				              resp.addr, i, resp.atom.data[i],
				              ((ports->rdata[i / 4] >> ((i % 4) * 8)) & 0xFF));
		
		respq.pop();
	}

	/* Handle inbound transactions */
	if (*ports->valid && !*ports->stall) {
		SIM_DEBUG("inbound valid with opcode %d, address %08x", *ports->opcode, *ports->addr);
		
		switch (*ports->opcode) {
		case MEM_OPC_READ:
		case MEM_OPC_READTHROUGH: {
			Check_MCPU_MEM::Response resp;
			
			SIM_DEBUG("pushing read, be %08x", memory[*ports->addr].valid);
			resp.age = 0;
			resp.addr = *ports->addr;
			resp.atom = memory[*ports->addr];
			respq.push(resp);
			break;
		}
		
		case MEM_OPC_WRITE:
		case MEM_OPC_WRITETHROUGH: {
			Check_MCPU_MEM::Atom &atom = memory[*ports->addr];
			atom.valid |= *ports->wbe;
			for (int i = 0; i < 32; i++)
				if (*ports->wbe & (1 << i))
					atom.data[i] = (ports->wdata[i / 4] >> ((i % 4) * 8)) & 0xFF;
			break;
		}
		}
	}
}

int Check_MCPU_MEM::done() {
	return respq.empty();
}
