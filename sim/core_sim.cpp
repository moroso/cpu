#include "Vmcpu_core.h"
#include "verilated.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <stdio.h>
#include <sys/stat.h>
#include <errno.h>

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

	int cycles = 0;
	while(!core->f2ic_valid || ((core->f2ic_paddr + 1) * 4) <= stat.st_size){
		if(core->f2ic_valid){
			core->ic2f_packet[0] = code[(core->f2ic_paddr * 4)];
			core->ic2f_packet[1] = code[(core->f2ic_paddr * 4 + 1)];
			core->ic2f_packet[2] = code[(core->f2ic_paddr * 4 + 2)];
			core->ic2f_packet[3] = code[(core->f2ic_paddr * 4 + 3)];
		}

		printf("Cycle %d: FT PC is %x, fetch PC is %x\n", 
			cycles, core->ft2f_out_virtpc * 16, core->ft2f_in_virtpc * 16);

		printf("f_valid: %d, dcd_valid: %d, pc_valid: %d, wb_valid: %d\n", 
			core->f_valid, core->dcd_valid, core->pc_valid, core->wb_valid);

		printf("Decoding Packet: %x %x %x %x\n", 
			core->f2d_in_packet[0], core->f2d_in_packet[1], core->f2d_in_packet[2], core->f2d_in_packet[3]);

		printf("PC Lane 0: rd_num = %d, %s%s rt_data = %x, sop = %x, shift type = %d, shift amount = %d, ALU output %x\n",
			core->d2pc_in_rd_num0, core->d2pc_in_rd_we0 ? "rd_we, " : "", core->d2pc_in_pred_we0 ? "pred_we, " : "",
			core->d2pc_in_rt_data0, core->d2pc_in_sop0, core->d2pc_in_shift_type0, core->d2pc_in_shift_amount0,
			core->pc2wb_out_result0);
		printf("PC Lane 1: rd_num = %d, %s%s rt_data = %x, sop = %x, shift type = %d, shift amount = %d, ALU output %x\n",
			core->d2pc_in_rd_num1, core->d2pc_in_rd_we1 ? "rd_we, " : "", core->d2pc_in_pred_we1 ? "pred_we, " : "",
			core->d2pc_in_rt_data1, core->d2pc_in_sop1, core->d2pc_in_shift_type1, core->d2pc_in_shift_amount1,
			core->pc2wb_out_result1);
		printf("PC Lane 2: rd_num = %d, %s%s rt_data = %x, sop = %x, shift type = %d, shift amount = %d, ALU output %x\n",
			core->d2pc_in_rd_num2, core->d2pc_in_rd_we2 ? "rd_we, " : "", core->d2pc_in_pred_we2 ? "pred_we, " : "",
			core->d2pc_in_rt_data2, core->d2pc_in_sop2, core->d2pc_in_shift_type2, core->d2pc_in_shift_amount2,
			core->pc2wb_out_result2);
		printf("PC Lane 3: rd_num = %d, %s%s rt_data = %x, sop = %x, shift type = %d, shift amount = %d, ALU output %x\n",
			core->d2pc_in_rd_num3, core->d2pc_in_rd_we3 ? "rd_we, " : "", core->d2pc_in_pred_we3 ? "pred_we, " : "",
			core->d2pc_in_rt_data3, core->d2pc_in_sop3, core->d2pc_in_shift_type3, core->d2pc_in_shift_amount3,
			core->pc2wb_out_result3);

		printf("WB Lane 0: rd_num = %d, %s%s rd_data = %x\n", core->wb2rf_rd_num0,
			core->wb2rf_rd_we0 ? "reg_we, " : "", core->wb2rf_pred_we0 ? "pred_we, " : "", core->wb2rf_rd_data0);
		printf("WB Lane 1: rd_num = %d, %s%s rd_data = %x\n", core->wb2rf_rd_num1,
			core->wb2rf_rd_we1 ? "reg_we, " : "", core->wb2rf_pred_we1 ? "pred_we, " : "", core->wb2rf_rd_data1);
		printf("WB Lane 2: rd_num = %d, %s%s rd_data = %x\n", core->wb2rf_rd_num2,
			core->wb2rf_rd_we2 ? "reg_we, " : "", core->wb2rf_pred_we2 ? "pred_we, " : "", core->wb2rf_rd_data2);
		printf("WB Lane 3: rd_num = %d, %s%s rd_data = %x\n", core->wb2rf_rd_num3,
			core->wb2rf_rd_we3 ? "reg_we, " : "", core->wb2rf_pred_we3 ? "pred_we, " : "", core->wb2rf_rd_data3);

		core->eval();
		core->clkrst_core_clk = 1;
		core->eval();
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
		printf("R%d: 0x%x\n", i, core->mem[i]);
	}
}