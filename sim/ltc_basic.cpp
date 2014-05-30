#include <stdlib.h>

#include "verilated.h"
#include "VMCPU_MEM_ltc.h"
#include "Cmod_MCPU_MEM_mc.h"
#include "Stim_MCPU_MEM_ltc.h"
#include "Check_MCPU_MEM_ltc.h"

#define CYCLE_LIMIT 100000

int main(int argc, char **argv, char **env) {
	int cycles = 0;
	
	Verilated::commandArgs(argc, argv);
	VMCPU_MEM_ltc *ltc = new VMCPU_MEM_ltc;
	Cmod_MCPU_MEM_mc *mc_cmod = new Cmod_MCPU_MEM_mc(Cmod_MCPU_MEM_mc_CONNECT(*ltc));
	Stim_MCPU_MEM_ltc *stim = new Stim_MCPU_MEM_ltc(ltc);
	Check_MCPU_MEM_ltc *check = new Check_MCPU_MEM_ltc(ltc);
	
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
	
	while (!stim->done() || !check->done()) {
		mc_cmod->clk_pre();
		stim->clk_pre();
		check->clk_pre();
		
		ltc->clkrst_mem_clk = 1;
		ltc->eval();
		
		mc_cmod->clk_post();
		stim->clk_post();
		check->clk_post();
		
		ltc->clkrst_mem_clk = 0;
		ltc->eval();
		
		cycles++;
		if (cycles >= CYCLE_LIMIT) {
			fprintf(stderr, "cycle limit exceeded!\n");
			return 1;
		}
	}
	
	return 0;
}
