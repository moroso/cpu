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
	
	/* Basic read-write test */
	for (int i = 0; i < 32; i++)
		buf[i] = i;
	stim->write(0x0, buf, 0xffffffff, 0);
	stim->read(0x0, 0);
	
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
		printf("***clock\n");
		mc_cmod->clk_pre();
		stim->clk_pre();
		check->clk_pre();
		main_time++;
		ltc->eval();
		TRACE;
		
		ltc->clkrst_mem_clk = 1;
		main_time++;
		ltc->eval();
		TRACE;
		
		mc_cmod->clk_post();
		stim->clk_post();
		check->clk_post();
		main_time++;
		ltc->eval();
		TRACE;
		
		ltc->clkrst_mem_clk = 0;
		main_time++;
		ltc->eval();
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
