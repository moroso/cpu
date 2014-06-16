#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>  
VerilatedVcdC* tfp;
#endif
#include "VTB_MCPU_MEM_arb.h"
#include "Cmod_MCPU_MEM_mc.h"
#include "MCPU_MEM_ports.h"
#include "Stim_MCPU_MEM.h"
#include "Check_MCPU_MEM.h"

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

	Cmod_MCPU_MEM_mc_ports mc_ports;
	Cmod_MCPU_MEM_mc_CONNECT(&mc_ports, tb);
	Cmod_MCPU_MEM_mc *mc_cmod = new Cmod_MCPU_MEM_mc(&mc_ports);
	
	MCPU_MEM_ports cli_ports[3];
	MCPU_MEM_ports_CONNECT(&cli_ports[0], tb, cli0_);
	MCPU_MEM_ports_CONNECT(&cli_ports[1], tb, cli1_);
	MCPU_MEM_ports_CONNECT(&cli_ports[2], tb, cli2_);
	
	Stim_MCPU_MEM *stim[3];
	stim[0] = new Stim_MCPU_MEM(&cli_ports[0]);
	stim[1] = new Stim_MCPU_MEM(&cli_ports[1]);
	stim[2] = new Stim_MCPU_MEM(&cli_ports[2]);
	
	Check_MCPU_MEM *check[3];
	check[0] = new Check_MCPU_MEM(&cli_ports[0]);
	check[1] = new Check_MCPU_MEM(&cli_ports[1]);
	check[2] = new Check_MCPU_MEM(&cli_ports[2]);
	
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
#define WRITE(c,addr) stim[c]->write(addr, buf, 0xffffffff, 0)
#define READ(c,addr) stim[c]->read(addr, 0)
	
	const char *testname;
	testname = Sim::param_str("ARB_DIRECTED_TEST_NAME", "basic");
	
	if (!strcmp(testname, "basic")) {
		/* Basic read-write test */
		GENBUF( 0); WRITE(0, 0x0000);
		GENBUF( 1); WRITE(0, 0x1000);
		GENBUF( 2); WRITE(0, 0x2000);
		GENBUF( 3); WRITE(0, 0x3000);
		
		GENBUF( 4); WRITE(1, 0x4000);
		GENBUF( 5); WRITE(1, 0x5000);
		GENBUF( 6); WRITE(1, 0x6000);
		GENBUF( 7); WRITE(1, 0x7000);
		
		GENBUF( 8); WRITE(2, 0x8000);
		GENBUF( 9); WRITE(2, 0x9000);
		GENBUF(10); WRITE(2, 0xA000);
		GENBUF(11); WRITE(2, 0xB000);
		
		
		READ(0, 0x0000);
		READ(0, 0x1000);
		READ(0, 0x2000);
		READ(0, 0x3000);
		
		READ(1, 0x4000);
		READ(1, 0x5000);
		READ(1, 0x6000);
		READ(1, 0x7000);
		
		READ(2, 0x8000);
		READ(2, 0x9000);
		READ(2, 0xA000);
		READ(2, 0xB000);
		
#if 0
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
#endif
	} else {
		SIM_FATAL("test %s not supported", testname);
	}
	
	/* Now, run the simulation */
	tb->clkrst_mem_clk = 0;
	tb->clkrst_mem_rst_n = 1;
	tb->eval();
	tb->clkrst_mem_rst_n = 0;
	tb->eval();
	tb->clkrst_mem_rst_n = 1;
	tb->eval();
	
#if VM_TRACE
#define TRACE tfp->dump(main_time)
#else
#define TRACE
#endif

	while (!stim[0]->done() || !check[0]->done() ||
	       !stim[1]->done() || !check[1]->done() ||
	       !stim[2]->done() || !check[2]->done()) {
		tb->clkrst_mem_clk = 1;
		tb->eval();
		mc_cmod->clk();
		for (int i = 0; i < 3; i++) {
			stim[i]->clk();
			check[i]->clk();
		}
		tb->eval();
		Sim::tick();
		TRACE;
		
		tb->clkrst_mem_clk = 0;
		tb->eval();
		Sim::tick();
		TRACE;
		
		if (Sim::main_time % 20000 == 0)
			SIM_INFO("ran for %lu cycles", Sim::main_time / 2);
	}

	Sim::finish();
	
	return 0;
}
