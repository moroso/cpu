#include <stdlib.h>

#include "check.h"
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

vluint64_t main_time = 0;

#if VM_TRACE
void _close_trace() {
	if (tfp) tfp->close();
}
#endif

int assertions_failed = 0;
void sim_assert_failed() {
	assertions_failed++;
	if (assertions_failed > 10) {
		printf("too many assertions failed; exiting\n");
		exit(1);
	}
}

double sc_time_stamp() {
	return main_time;
}

int main(int argc, char **argv, char **env) {
	int cycles = 0;
	
	Verilated::commandArgs(argc, argv);
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
	
	if (!getenv("LTC_RANDOM_SEED")) {
		time_t t = time(NULL);
		printf("ltc_random: rerun with LTC_RANDOM_SEED=%ld\n", t);
		srandom(t);
	} else {
		srandom(atoi(getenv("LTC_RANDOM_SEED")));
	}
	
	if (!getenv("LTC_RANDOM_ADDRESSES")) {
		printf("ltc_random: defaulting to %d addresses\n", MAX_ADDRESSES);
		naddresses = MAX_ADDRESSES;
	} else {
		naddresses = atoi(getenv("LTC_RANDOM_ADDRESSES"));
		if (naddresses > MAX_ADDRESSES)
			naddresses = MAX_ADDRESSES;
	}

	if (!getenv("LTC_RANDOM_OPERATIONS")) {
		printf("ltc_random: defaulting to %d operations\n", OPS_DEFAULT);
		nrandoms = OPS_DEFAULT;
	} else {
		nrandoms = atoi(getenv("LTC_RANDOM_OPERATIONS"));
	}
	
	randomize_bes = !getenv("LTC_NO_RANDOMIZE_BES");
	
	for (int i = 0; i < naddresses; i++)
		addresses[i] = random() % 0x100000;
	
	for (int i = 0; i < nrandoms; i++) {
		uint8_t buf[32];
		
		switch (random() % 2) {
		case 0: /* read */
			stim->read(addresses[random() % naddresses], random() % 2);
			break;
		case 1: /* write */
			for (int j = 0; j < 32; j++)
				buf[j] = random() % 256;
			stim->write(addresses[random() % naddresses], buf, (random() % 0x100000000) | (randomize_bes ? 0 : 0xffffffff), random() % 2);
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
		mc_cmod->clk_pre();
		stim->clk_pre();
		check->clk_pre();
		ltc->eval();
		main_time++;
		TRACE;
		
		ltc->clkrst_mem_clk = 1;
		ltc->eval();
		mc_cmod->clk_post();
		stim->clk_post();
		check->clk_post();
		ltc->eval();
		main_time++;
		TRACE;
		
		main_time++;
		TRACE;
	
		ltc->clkrst_mem_clk = 0;
		ltc->eval();
		main_time++;
		TRACE;
		
		if (main_time % 40000 == 0)
			printf("ran for %lu cycles\n", main_time / 4);
	}
	
	if (assertions_failed > 0) {
		printf("non-zero assertion failures: check logs\n");
		return 1;
	}
	
	return 0;
}
