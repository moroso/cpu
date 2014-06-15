#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>  
VerilatedVcdC* tfp;
#endif
#include "VTB_MCPU_MEM_arb.h"
/*
#include "Cmod_MCPU_MEM_mc.h"
#include "Stim_MCPU_MEM_ltc.h"
*/
#define MAX_ADDRESSES 16384
#define OPS_DEFAULT   4096

#if VM_TRACE
void _close_trace() {
	if (tfp) tfp->close();
}
#endif

int main(int argc, char **argv, char **env) {
	Sim::init(argc, argv);
	
	VTB_MCPU_MEM_arb *tb = new VTB_MCPU_MEM_arb;

#if 0	
	Cmod_MCPU_MEM_mc_ports mc_ports;
	Cmod_MCPU_MEM_mc_CONNECT(&mc_ports, tb);
	Cmod_MCPU_MEM_mc *mc_cmod = new Cmod_MCPU_MEM_mc(&mc_ports);
//	Stim_MCPU_MEM_ltc *stim = new Stim_MCPU_MEM_ltc(ltc);
//	Check_MCPU_MEM_ltc *check = new Check_MCPU_MEM_ltc(ltc);

#if VM_TRACE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	ltc->trace(tfp, 99);
	tfp->open("trace.vcd");
	atexit(_close_trace);
#endif
	
	uint8_t buf[32];

#define GENBUF(vec) \
		for (int i = 0; i < 32; i++) \
			buf[i] = (vec << 4) ^ i;
#define ADDR(tag, set, ofs) ((tag) << 7 | ((set) & 31) << 2 | ((ofs) & 3))
#define WRITE(t,s,o) stim->write(ADDR(t,s,o), buf, 0xffffffff, 0)
#define READ(t,s,o) stim->read(ADDR(t,s,o), 0)
	
	const char *testname;
	testname = Sim::param_str("LTC_DIRECTED_TEST_NAME", "basic");
	
	if (!strcmp(testname, "basic")) {
		/* Basic read-write test */
		GENBUF(0);
		WRITE(0,0,0);
		READ (0,0,0);
	} else if (!strcmp(testname, "backtoback")) {
		/* Write back-to-back, then read back-to-back */
		GENBUF(0);
		WRITE(0,0,0);
		GENBUF(1);
		WRITE(1,0,0);
		WRITE(1,0,1);
		READ (0,0,0);
		READ (1,0,0);
		READ (0,0,0);
		READ (1,0,1);
		GENBUF(2);
		WRITE(0,0,0);
		READ (0,0,0);
		GENBUF(3);
		WRITE(0,0,1);
		READ (0,0,1);
	} else if (!strcmp(testname, "evict")) {
		/* Basic evict test */
		GENBUF(0);
		WRITE(0,0,0);
		GENBUF(1);
		WRITE(1,0,0);
		GENBUF(2);
		WRITE(2,0,0);
		GENBUF(3);
		WRITE(3,0,0);
		GENBUF(4);
		WRITE(4,0,0);
		GENBUF(5);
		WRITE(5,0,0);
		
		READ (0,0,0);
		READ (1,0,0);
		READ (2,0,0);
		READ (3,0,0);
		READ (4,0,0);
		READ (5,0,0);
	} else if (!strcmp(testname, "regress_two_set")) {
		GENBUF(0);
		WRITE(0,0,0);
		READ (1,0,0);
		READ (2,0,0);
		READ (3,0,0);
		READ (3,1,0);
		READ (0,0,0);
	} else if (!strcmp(testname, "random")) {
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
	} else {
		SIM_FATAL("test %s not supported", testname);
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
		ltc->clkrst_mem_clk = 1;
		ltc->eval();
		mc_cmod->clk();
		stim->clk();
		check->clk();
		ltc->eval();
		Sim::tick();
		TRACE;
		
		ltc->clkrst_mem_clk = 0;
		ltc->eval();
		Sim::tick();
		TRACE;
		
		if (Sim::main_time % 20000 == 0)
			SIM_INFO("ran for %lu cycles", Sim::main_time / 2);
	}
#endif	
	Sim::finish();
	
	return 0;
}
