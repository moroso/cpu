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

#define CYCLE_LIMIT 100000

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

#define GENBUF(vec) \
		for (int i = 0; i < 32; i++) \
			buf[i] = (vec << 4) ^ i;
#define ADDR(tag, set, ofs) ((tag) << 7 | ((set) & 31) << 2 | ((ofs) & 3))
#define WRITE(t,s,o) stim->write(ADDR(t,s,o), buf, 0xffffffff, 0)
#define READ(t,s,o) stim->read(ADDR(t,s,o), 0)
	
	const char *testname;
	testname = getenv("LTC_DIRECTED_TEST_NAME");
	if (!testname) {
		printf("ltc_directed: no test name?  defaulting to basic");
		testname = "basic";
	}
	
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
	} else {
		printf("ltc_directed: test %s not supported\n", testname);
		return 1;
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
		
		cycles++;
		SIM_CHECK(cycles < CYCLE_LIMIT);
	}
	
	if (assertions_failed > 0) {
		printf("non-zero assertion failures: check logs\n");
		return 1;
	}
	
	return 0;
}
