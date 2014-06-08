#include "verilated.h"
#include "Check_MCPU_MEM_ltc.h"
#include "check.h"

#define LTC_OPC_READ         0x0
#define LTC_OPC_WRITE        0x1
#define LTC_OPC_READTHROUGH  0x2
#define LTC_OPC_WRITETHROUGH 0x3
#define LTC_OPC_PREFETCH     0x4
#define LTC_OPC_CLEAN        0x6

#define LTC_STALLED_CYCLES_MAX 1000
#define LTC_LATENCY_MAX 500

void Check_MCPU_MEM_ltc::clk() {
	/* Check: input stall */
	if (ltc->arb2ltc_stall)
		stalled_cycles++;
	else
		stalled_cycles = 0;
	
	SIM_CHECK(stalled_cycles < LTC_STALLED_CYCLES_MAX);
	
	/* Check: response head-of-line age */
	if (!respq.empty()) {
		Check_MCPU_MEM_ltc::Response &resp = respq.front();
		resp.age++;
		SIM_CHECK(resp.age < LTC_LATENCY_MAX);
	}

	/* Handle responses -- before inbound transactions, since we can't respond same-cycle! */
	if (ltc->arb2ltc_rvalid) {
		if (noisy) printf("Check_MCPU_MEM_ltc::clk_pre(): response valid\n");

		SIM_CHECK(!respq.empty() && "ltc response came back without outbound read request");
		if (respq.empty())
			return;
		
		Check_MCPU_MEM_ltc::Response &resp = respq.front();
		for (int i = 0; i < 32; i++)
			if (resp.atom.valid & (1 << i))
				SIM_CHECK(resp.atom.data[i] == ((ltc->arb2ltc_rdata[i / 4] >> ((i % 4) * 8)) & 0xFF));
		
		respq.pop();
	}

	/* Handle inbound transactions */
	if (ltc->arb2ltc_valid && !ltc->arb2ltc_stall) {
		if (noisy) printf("Check_MCPU_MEM_ltc::clk_pre(): inbound valid with opcode %d, address %08x\n", ltc->arb2ltc_opcode, ltc->arb2ltc_addr);
		
		switch (ltc->arb2ltc_opcode) {
		case LTC_OPC_READ:
		case LTC_OPC_READTHROUGH: {
			Check_MCPU_MEM_ltc::Response resp;
			
			if (noisy) printf("Check_MCPU_MEM_ltc::clk_pre(): pushing read, be %08x\n", memory[ltc->arb2ltc_addr].valid);
			resp.age = 0;
			resp.addr = ltc->arb2ltc_addr;
			resp.atom = memory[ltc->arb2ltc_addr];
			respq.push(resp);
			break;
		}
		
		case LTC_OPC_WRITE:
		case LTC_OPC_WRITETHROUGH: {
			Check_MCPU_MEM_ltc::Atom &atom = memory[ltc->arb2ltc_addr];
			atom.valid |= ltc->arb2ltc_wbe;
			for (int i = 0; i < 32; i++)
				if (ltc->arb2ltc_wbe & (1 << i))
					atom.data[i] = (ltc->arb2ltc_wdata[i / 4] >> ((i % 4) * 8)) & 0xFF;
			break;
		}
		}
	}
}

void Check_MCPU_MEM_ltc::eval() {
}

int Check_MCPU_MEM_ltc::done() {
	return respq.empty();
}
