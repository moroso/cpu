#include "verilated.h"

#include "Stim_MCPU_MEM.h"
#include "Sim.h"
#include "mem_common.h"

void Stim_MCPU_MEM::read(uint32_t addr, int through) {
	Stim_MCPU_MEM::Command cmd;
	int i;
	
	cmd.opcode = through ? LTC_OPC_READTHROUGH : LTC_OPC_READ;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] = random();
	cmd.wbe = random();
	
	cmdq.push(cmd);
	
	SIM_DEBUG("generating read, address %08x", addr);
}

void Stim_MCPU_MEM::write(uint32_t addr, uint8_t data[32], uint32_t be, int through) {
	Stim_MCPU_MEM::Command cmd;
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

void Stim_MCPU_MEM::prefetch(uint32_t addr) {
	Stim_MCPU_MEM::Command cmd;
	int i;
	
	cmd.opcode = LTC_OPC_PREFETCH;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] = random();
	cmd.wbe = random();
	
	cmdq.push(cmd);
}

void Stim_MCPU_MEM::clean(uint32_t addr) {
	Stim_MCPU_MEM::Command cmd;
	int i;
	
	cmd.opcode = LTC_OPC_CLEAN;
	cmd.addr = addr;
	for (i = 0; i < 8; i++)
		cmd.wdata[i] = random();
	cmd.wbe = random();
	
	cmdq.push(cmd);
}

void Stim_MCPU_MEM::clk() {
	if (!stall_1a && !*ports->stall) {
		*ports->valid = next_valid;
		*ports->opcode = next_opcode;
		*ports->addr = next_addr;
		for (int i = 0; i < 8; i++)
			ports->wdata[i] = next_wdata[i];
		*ports->wbe = next_wbe;
	}
	stall_1a = *ports->stall;
	
	/* Do nothing on a clock if stalled. */
	if (*ports->stall || !ports->clkrst_mem_rst_n)
		return;

	/* Sometimes, generate a bubble. */
	if (cmdq.empty() || Sim::random(100) < 3) {
		next_valid = 0;
		return;
	}

	/* Otherwise, set up a command for the next clock. */
	Stim_MCPU_MEM::Command &cmd = cmdq.front();
	
	SIM_DEBUG("emitting new opcode");
	next_valid = 1;
	next_opcode = cmd.opcode;
	next_addr = cmd.addr;
	for (int i = 0; i < 8; i++)
		next_wdata[i] = cmd.wdata[i];
	next_wbe = cmd.wbe;
	
	cmdq.pop();
}

int Stim_MCPU_MEM::done() {
	return cmdq.empty();
}
