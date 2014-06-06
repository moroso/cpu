#include "verilated.h"

#include "Stim_MCPU_MEM_ltc.h"

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

void Stim_MCPU_MEM_ltc::clk_pre() {
	if (ltc->arb2ltc_stall)
		return;

	if (cmdq.empty() || (random() % 100 < 97)) {
		ltc->arb2ltc_valid = 0;
		return;
	}

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

void Stim_MCPU_MEM_ltc::clk_post() {
}

int Stim_MCPU_MEM_ltc::done() {
	return cmdq.empty();
}
