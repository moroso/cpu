#include "VTB_MCPU_core.h"
#include "VTB_MCPU_core_TB_MCPU_core.h"
#include "VTB_MCPU_core_MCPU_core.h"
#include "VTB_MCPU_core_MCPU_CORE_regfile.h"
#include "Sim.h"
#include "verilated.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <stdio.h>
#include <sys/stat.h>
#include <errno.h>

#if VM_TRACE
#include <verilated_vcd_c.h>  
VerilatedVcdC* tfp;

void _close_trace() {
	if (tfp) tfp->close();
}
#endif

#if VM_TRACE
#define TRACE tfp->dump(Sim::main_time)
#else
#define TRACE
#endif

#define TIMEOUT 5000

int main(int argc, char **argv){
	Sim::init(argc, argv);

	VTB_MCPU_core *core = new VTB_MCPU_core;

	#if VM_TRACE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	core->trace(tfp, 99);
	tfp->open("trace.vcd");
	atexit(_close_trace);
	#endif

	
	core->clkrst_core_rst_n = 0;
	core->clkrst_core_clk = 0;
	core->eval();
	core->clkrst_core_clk = 1;
	core->eval();
	core->clkrst_core_clk = 0;
	core->eval();
	core->clkrst_core_rst_n = 1;
	core->eval();

	TRACE;

	int cycles = 0;
	while (!core->pkt_is_break && (cycles < TIMEOUT)){
		core->eval();

		printf("Cycle %d: FT PC is %x, fetch PC is %x\n", 
			cycles, core->v->core->ft2f_out_virtpc * 16, core->v->core->ft2f_in_virtpc * 16);

		printf("f_valid: %d, dcd_valid: %d, pc_valid: %d, wb_valid: %d\n", 
			core->v->core->f_valid, core->v->core->dcd_valid, core->v->core->pc_valid, core->v->core->wb_valid);

		Sim::tick();
		TRACE;
		core->clkrst_core_clk = 1;
		core->eval();
		Sim::tick();
		TRACE;
		core->clkrst_core_clk = 0;
		core->eval();
		cycles++;
	}
	//Hack to flush the pipeline in this simple case - just feed it 5 NOPs.
	core->eval();
	for(int i = 0; i < 5; i++){
		core->clkrst_core_clk = 1;
		core->eval();
		core->clkrst_core_clk = 0;
		core->eval();
	}
	//dump register contents
	printf("Execution completed after %d cycles\n", cycles);
	printf("Beginning register dump\n");
	for(int i = 0; i < 32; i++){
		printf("R%d: 0x%x\n", i, core->v->core->regs->mem[i]);
	}
}
