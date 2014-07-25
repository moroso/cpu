#include "Vmcpu_core.h"
#include "Vmcpu_core_mcpu_core.h"
#include "Vmcpu_core_regfile.h"
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
	if(argc < 2){
		printf("usage: %s [input hex file]\n", argv[0]);
		return 1;
	}
	int infd;
	if((infd = open(argv[1], O_RDONLY)) < 0){
		printf("Could not open file %s: %s\n", argv[1], strerror(errno));
		return 1;
	}
	struct stat stat;
	if(fstat(infd, &stat) < 0){
		printf("Could not stat file %s: %s\n", argv[1], strerror(errno));
		return 1;
	}
	uint32_t *code = (uint32_t*)mmap(NULL, stat.st_size, PROT_READ, MAP_PRIVATE, infd, 0);
	if(code == MAP_FAILED){
		printf("Could not mmap file %s: %s\n", argv[1], strerror(errno));
		return 1;
	}
	Vmcpu_core *core = new Vmcpu_core;

	#if VM_TRACE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	core->trace(tfp, 99);
	tfp->open("trace.vcd");
	atexit(_close_trace);
	#endif

	
	core->ic2f_ready = 1;
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
	while((!core->f2ic_valid || ((core->f2ic_paddr + 1) * 4) <= stat.st_size) && (cycles < TIMEOUT)){
		if(core->f2ic_valid){
			core->ic2f_packet[0] = code[(core->f2ic_paddr * 4)];
			core->ic2f_packet[1] = code[(core->f2ic_paddr * 4 + 1)];
			core->ic2f_packet[2] = code[(core->f2ic_paddr * 4 + 2)];
			core->ic2f_packet[3] = code[(core->f2ic_paddr * 4 + 3)];
		}

		core->eval();

		printf("Cycle %d: FT PC is %x, fetch PC is %x\n", 
			cycles, core->v->ft2f_out_virtpc * 16, core->v->ft2f_in_virtpc * 16);

		printf("f_valid: %d, dcd_valid: %d, pc_valid: %d, wb_valid: %d\n", 
			core->v->f_valid, core->v->dcd_valid, core->v->pc_valid, core->v->wb_valid);

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
	core->ic2f_packet[0] = 0xE0000000;
	core->ic2f_packet[1] = 0xE0000000;
	core->ic2f_packet[2] = 0xE0000000;
	core->ic2f_packet[3] = 0xE0000000;
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
		printf("R%d: 0x%x\n", i, core->v->regs->mem[i]);
	}
}