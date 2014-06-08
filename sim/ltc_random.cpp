#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"
#if VM_TRACE
#include <verilated_vcd_c.h>  
VerilatedVcdC* tfp;
#endif
#include "VMCPU_MEM_ltc.h"
#include "Cmod_MCPU_MEM_mc.h"
#include "Stim_MCPU_MEM_ltc.h"
#include "Check_MCPU_MEM_ltc.h"

#define MAX_ADDRESSES 16384
#define OPS_DEFAULT   4096

#if VM_TRACE
void _close_trace() {
	if (tfp) tfp->close();
}
#endif

int main(int argc, char **argv, char **env) {
	int cycles = 0;

	Sim::init(argc, argv);
	
	VMCPU_MEM_ltc *ltc = new VMCPU_MEM_ltc;
	Cmod_MCPU_MEM_mc *mc_cmod = new Cmod_MCPU_MEM_mc(Cmod_MCPU_MEM_mc_CONNECT(*ltc));
	Stim_MCPU_MEM_ltc *stim = new Stim_MCPU_MEM_ltc(ltc);
	Check_MCPU_MEM_ltc *check = new Check_MCPU_MEM_ltc(ltc);

#if VM_TRACE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	ltc->trace(tfp, 99);
	tfp->open("trace.vcd");
	atexit(_close_trace);
#endif
	
	uint8_t buf[32];
	uint32_t addresses[MAX_ADDRESSES];
	int naddresses;
	int nrandoms;
	int randomize_bes;
	
	naddresses = Sim::param_u64("LTC_RANDOM_ADDRESSES", MAX_ADDRESSES);
	if (naddresses > MAX_ADDRESSES)
		naddresses = MAX_ADDRESSES;
	
	nrandoms = Sim::param_u64("LTC_RANDOM_OPERATIONS", OPS_DEFAULT);
	
	randomize_bes = !getenv("LTC_NO_RANDOMIZE_BES");
	
	for (int i = 0; i < naddresses; i++)
		addresses[i] = Sim::random(0x100000);
	
	for (int i = 0; i < nrandoms; i++) {
		uint8_t buf[32];
		
		switch (Sim::random(2)) {
		case 0: /* read */
			stim->read(addresses[Sim::random(naddresses)], Sim::random(2));
			break;
		case 1: /* write */
			for (int j = 0; j < 32; j++)
				buf[j] = random() % 256;
			stim->write(addresses[Sim::random(naddresses)], buf, Sim::random(0x100000000) | (randomize_bes ? 0 : 0xffffffff), Sim::random(2));
			break;
		}
	}
	
	/* Now, run the simulation */
	ltc->clkrst_mem_clk = 0;
	ltc->clkrst_mem_rst_n = 1;
	ltc->eval();
	ltc->clkrst_mem_rst_n = 0;
	ltc->eval();
	ltc->clkrst_mem_rst_n = 1;
	ltc->eval();
	
#if VM_TRACE
#define TRACE tfp->dump(main_time)
#else
#define TRACE
#endif

	while (!stim->done() || !check->done()) {
		mc_cmod->eval();
		stim->eval();
		check->eval();
		ltc->eval();
		Sim::tick();
		TRACE;
		
		ltc->clkrst_mem_clk = 1;
		ltc->eval();
		mc_cmod->clk();
		stim->clk();
		check->clk();
		ltc->eval();
		Sim::tick();
		TRACE;
		
		Sim::tick();
		TRACE;
	
		ltc->clkrst_mem_clk = 0;
		ltc->eval();
		Sim::tick();
		TRACE;
		
		if (Sim::main_time % 40000 == 0)
			SIM_INFO("ran for %lu cycles", Sim::main_time / 4);
	}
	
	Sim::finish();
	
	return 0;
}
