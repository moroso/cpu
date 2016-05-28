#include "VMCPU_core.h"
#include "VMCPU_core_MCPU_core.h"
#include "VMCPU_core_MCPU_CORE_regfile.h"
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

#define RAM_SIZE 65536

#define MIN(x, y) (((x) < (y)) ? (x) : (y))

uint32_t ram[RAM_SIZE];

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
	memcpy(ram, code, MIN(RAM_SIZE / sizeof(uint32_t), stat.st_size));
	VMCPU_core *core = new VMCPU_core;

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

	int cycles = 0, end_time = TIMEOUT, exiting = 0;
	while(cycles < end_time){
		
		if(!exiting){
			core->ic2f_packet[0] = ram[(core->f2ic_paddr * 4) % RAM_SIZE];
			core->ic2f_packet[1] = ram[(core->f2ic_paddr * 4 + 1) % RAM_SIZE];
			core->ic2f_packet[2] = ram[(core->f2ic_paddr * 4 + 2) % RAM_SIZE];
			core->ic2f_packet[3] = ram[(core->f2ic_paddr * 4 + 3) % RAM_SIZE];
			if(core->ic2f_packet[0] == 0xD1183C00){
				//feed in a few NOPs and end the simulation.
				exiting = 1;
				end_time = cycles + 5;
			}
		}
		else{
			core->ic2f_packet[0] = 0xE0000000;
			core->ic2f_packet[1] = 0xE0000000;
			core->ic2f_packet[2] = 0xE0000000;
			core->ic2f_packet[3] = 0xE0000000;
		}
		//TODO mess with the timing?
		if(core->mem2dc_valid0){
			uint32_t addr = core->mem2dc_paddr0 % RAM_SIZE;
			if(core->mem2dc_write0){
				uint32_t writemask = 0;
				writemask |= (core->mem2dc_write0 & 1) ? 0xFF : 0;
				writemask |= (core->mem2dc_write0 & 2) ? 0xFF00 : 0;
				writemask |= (core->mem2dc_write0 & 4) ? 0xFF0000 : 0;
				writemask |= (core->mem2dc_write0 & 8) ? 0xFF000000 : 0;
				ram[addr] = (core->mem2dc_data0 & writemask) | 
							(ram[addr] & ~writemask);
				printf("Lane 0 wrote %x at %x\n", ram[addr], addr);
			}
			else{
				core->mem2dc_data0 = ram[addr];
				printf("Lane 0 read %x at %x\n", ram[addr], addr);
			}
			core->mem2dc_done0 = 1;
		}
		else{
			core->mem2dc_done0 = 0;
		}

		if(core->mem2dc_valid1){
			uint32_t addr = core->mem2dc_paddr1 % RAM_SIZE;
			if(core->mem2dc_write1){
				uint32_t writemask = 0;
				writemask |= (core->mem2dc_write1 & 1) ? 0xFF : 0;
				writemask |= (core->mem2dc_write1 & 2) ? 0xFF00 : 0;
				writemask |= (core->mem2dc_write1 & 4) ? 0xFF0000 : 0;
				writemask |= (core->mem2dc_write1 & 8) ? 0xFF000000 : 0;
				ram[addr] = (core->mem2dc_data1 & writemask) | 
							(ram[addr] & ~writemask);
				printf("Lane 1 wrote %x at %x\n", ram[addr], addr);
			}
			else{
				core->mem2dc_data1 = ram[addr];
				printf("Lane 1 read %x at %x\n", ram[addr], addr);
			}
			core->mem2dc_done1 = 1;
		}
		else{
			core->mem2dc_done1 = 0;
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

	//dump register contents
	printf("Execution completed after %d cycles\n", cycles);
	printf("Beginning register dump\n");
	for(int i = 0; i < 32; i++){
		printf("R%d: 0x%x\n", i, core->v->regs->mem[i]);
	}
}