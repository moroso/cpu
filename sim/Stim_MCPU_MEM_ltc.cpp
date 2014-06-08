#include "verilated.h"

#include "Stim_MCPU_MEM_ltc.h"
#include "Sim.h"

#define LTC_OPC_READ         0x0
#define LTC_OPC_WRITE        0x1
#define LTC_OPC_READTHROUGH  0x2
#define LTC_OPC_WRITETHROUGH 0x3
#define LTC_OPC_PREFETCH     0x4
#define LTC_OPC_CLEAN        0x6

void Stim_MCPU_MEM_ltc::read(uint32_t addr, int through) {
	Stim_MCPU_MEM_ltc::Command cmd;
	int i;
	
	cmd.opcode = through ? LTC_OPC_READTHROUGH : LTC_OPC_READ;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] = random();
	cmd.wbe = random();
	
	cmdq.push(cmd);
}

void Stim_MCPU_MEM_ltc::write(uint32_t addr, uint8_t data[32], uint32_t be, int through) {
	Stim_MCPU_MEM_ltc::Command cmd;
	int i;
	
	cmd.opcode = through ? LTC_OPC_WRITETHROUGH : LTC_OPC_WRITE;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] =
			(data[i*4 + 0] <<  0) | (data[i*4 + 1] <<  8) |
			(data[i*4 + 2] << 16) | (data[i*4 + 3] << 24);
	cmd.wbe = be;
	
	cmdq.push(cmd);
}

void Stim_MCPU_MEM_ltc::prefetch(uint32_t addr) {
	Stim_MCPU_MEM_ltc::Command cmd;
	int i;
	
	cmd.opcode = LTC_OPC_PREFETCH;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] = random();
	cmd.wbe = random();
	
	cmdq.push(cmd);
}

void Stim_MCPU_MEM_ltc::clean(uint32_t addr) {
	Stim_MCPU_MEM_ltc::Command cmd;
	int i;
	
	cmd.opcode = LTC_OPC_CLEAN;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] = random();
	cmd.wbe = random();
	
	cmdq.push(cmd);
}

void Stim_MCPU_MEM_ltc::eval() {
}

void Stim_MCPU_MEM_ltc::clk() {
	/* Do nothing on a clock if stalled. */
	if (ltc->arb2ltc_stall || !ltc->clkrst_mem_rst_n)
		return;

	/* Sometimes, generate a bubble. */
	if (cmdq.empty() || Sim::random(100) < 3) {
		ltc->arb2ltc_valid = 0;
		return;
	}

	/* Otherwise, set up a command for the next clock. */
	Stim_MCPU_MEM_ltc::Command &cmd = cmdq.front();
	int i;
	
	ltc->arb2ltc_valid = 1;
	ltc->arb2ltc_opcode = cmd.opcode;
	ltc->arb2ltc_addr = cmd.addr;
	for (i = 0; i < 8; i++)
		ltc->arb2ltc_wdata[i] = cmd.wdata[i];
	ltc->arb2ltc_wbe = cmd.wbe;
	
	cmdq.pop();
}

int Stim_MCPU_MEM_ltc::done() {
	return cmdq.empty();
}
