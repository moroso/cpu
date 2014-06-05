#include "Cmod_MCPU_MEM_mc.h"
#include "check.h"

Cmod_MCPU_MEM_mc::Cmod_MCPU_MEM_mc(
	MC_CMOD_CONNECTIONS(MC_CMOD_CONNECTION_ARG,) int _bogus
	) :
	MC_CMOD_CONNECTIONS(MC_CMOD_CONNECTION_INST,)
	burst_cycrem(0),
	burst_rnw(0) {
	
	*ltc2mc_avl_ready_0 = 0;
	*ltc2mc_avl_rdata_valid_0 = 0;
	ltc2mc_avl_rdata_0[0] = ltc2mc_avl_rdata_0[1] = ltc2mc_avl_rdata_0[2] = ltc2mc_avl_rdata_0[3] = 0;
	
	ltc2mc_avl_ready_0_next = 0;
	ltc2mc_avl_rdata_valid_0_next = 0;
	ltc2mc_avl_rdata_0_next[0] = ltc2mc_avl_rdata_0_next[1] = ltc2mc_avl_rdata_0_next[2] = ltc2mc_avl_rdata_0_next[3] = 0;
}

/* WDatas are little endian. */
void Cmod_MCPU_MEM_mc::clk_pre() {
	/* Clock out anything from last cycle */
	*ltc2mc_avl_ready_0 = ltc2mc_avl_ready_0_next;
	*ltc2mc_avl_rdata_valid_0 = ltc2mc_avl_rdata_valid_0_next;
	ltc2mc_avl_rdata_0[0] = ltc2mc_avl_rdata_0_next[0];
	ltc2mc_avl_rdata_0[1] = ltc2mc_avl_rdata_0_next[1];
	ltc2mc_avl_rdata_0[2] = ltc2mc_avl_rdata_0_next[2];
	ltc2mc_avl_rdata_0[3] = ltc2mc_avl_rdata_0_next[3];

	/* Check for burst validity */
	if (burst_cycrem) {
		if (burst_rnw) /* i.e., read */ {
			if (*ltc2mc_avl_read_req_0)
				burst_cycrem--;
			SIM_CHECK(!*ltc2mc_avl_write_req_0 && "write during read burst");
		} else /* i.e., write */ { 
			if (*ltc2mc_avl_write_req_0)
				burst_cycrem--;
			SIM_CHECK(!*ltc2mc_avl_read_req_0 && "read during write burst");
		}
		SIM_CHECK(!*ltc2mc_avl_burstbegin_0 && "burst start during burst");
	} else if (*ltc2mc_avl_burstbegin_0) {
		SIM_CHECK((*ltc2mc_avl_read_req_0 ^ *ltc2mc_avl_write_req_0) && "invalid burst start type");
		burst_cycrem = *ltc2mc_avl_size_0 - 1;
		burst_rnw = *ltc2mc_avl_read_req_0;
	} else
		SIM_CHECK(!*ltc2mc_avl_read_req_0 && !*ltc2mc_avl_write_req_0 && "read or write outside of burst");
	
	/* Dummy model: one-cycle memory */
	ltc2mc_avl_ready_0_next = 1;
	ltc2mc_avl_rdata_valid_0_next = *ltc2mc_avl_read_req_0;
	if (*ltc2mc_avl_read_req_0) {
		uint32_t memad = *ltc2mc_avl_addr_0 * 16;
		int i;
		
		for (i = 0; i < 4; i++)
			ltc2mc_avl_rdata_0_next[i] =
				(memory[memad + i*4 + 0] <<  0) | (memory[memad + i*4 + 1] <<  8) |
				(memory[memad + i*4 + 2] << 16) | (memory[memad + i*4 + 3] << 24);
	}
	if (*ltc2mc_avl_write_req_0) {
		uint32_t memad = *ltc2mc_avl_addr_0 * 16;
		int i;
	
		for (i = 0; i < 16; i++)
			if (*ltc2mc_avl_be_0 & (1 << i))
				memory[memad + i] = (ltc2mc_avl_wdata_0[i / 4] >> ((i % 4) * 8)) & 0xFF;
	}
}

void Cmod_MCPU_MEM_mc::clk_post() {
}
