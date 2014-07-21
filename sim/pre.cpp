#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>  
VerilatedVcdC* tfp;
#endif
#include "VTB_MCPU_MEM_preload.h"
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
	
	VTB_MCPU_MEM_preload *tb = new VTB_MCPU_MEM_preload;

	Cmod_MCPU_MEM_mc_ports mc_ports;
	Cmod_MCPU_MEM_mc_CONNECT(&mc_ports, tb);
	Cmod_MCPU_MEM_mc *mc_cmod = new Cmod_MCPU_MEM_mc(&mc_ports);
	
	MCPU_MEM_ports cli_ports;
	MCPU_MEM_ports_CONNECT(&cli_ports, tb, cli0_);
	
	Stim_MCPU_MEM *stim;
	stim = new Stim_MCPU_MEM(&cli_ports, "stim_arb0");
	
	Check_MCPU_MEM *check;
	check = new Check_MCPU_MEM(&cli_ports, "check_arb0");
	
#if VM_TRACE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	tb->trace(tfp, 99);
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
	
	stim->read(0x00, 0);
	stim->read(0x10, 0);
	stim->read(0x20, 0);
	stim->read(0x30, 0);
	stim->read(0x40, 0);
	
	/* Now, run the simulation */
	tb->clkrst_mem_clk = 0;
	tb->clkrst_mem_rst_n = 1;
	tb->eval();
	tb->clkrst_mem_rst_n = 0;
	tb->eval();
	tb->clkrst_mem_rst_n = 1;
	tb->eval();
	
#if VM_TRACE
#define TRACE tfp->dump(Sim::main_time)
#else
#define TRACE
#endif

        while (!tb->pre2core_done) {
                tb->clkrst_mem_clk = 1;
                tb->eval();
                mc_cmod->clk();
                tb->eval();
                Sim::tick();
                TRACE;
                
                tb->clkrst_mem_clk = 0;
                tb->eval();
                Sim::tick();
                TRACE;
                
                if (Sim::main_time > 100000)
                        SIM_FATAL("timed out waiting for preloader completion");
        }
        
        SIM_INFO("preloader completed after %lu cycles", Sim::main_time / 2);

	while (!stim->done() || !check->done()) {
		tb->clkrst_mem_clk = 1;
		tb->eval();
		mc_cmod->clk();
		stim->clk();
		tb->eval();
		check->clk();
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
