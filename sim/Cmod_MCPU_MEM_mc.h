#ifndef _CMOD_MCPU_MEM_mc_H
#define _CMOD_MCPU_MEM_mc_H

#include "verilated.h"

#define Cmod_MCPU_MEM_mc_MEMSZ 512*1024*1024

struct Cmod_MCPU_MEM_mc_ports {
	/* inputs */
	CData *ltc2mc_avl_burstbegin_0;  /* 0:0 */
	CData *ltc2mc_avl_read_req_0;    /* 0:0 */
	CData *ltc2mc_avl_size_0;        /* 4:0 */
	SData *ltc2mc_avl_be_0;          /* 15:0 */
	IData *ltc2mc_avl_addr_0;        /* 24:0 */
	CData *ltc2mc_avl_write_req_0;   /* 0:0 */
	WData *ltc2mc_avl_wdata_0;       /* 127:0 */
	
	/* outputs */
	CData *ltc2mc_avl_ready_0;       /* 0:0 */
	CData *ltc2mc_avl_rdata_valid_0; /* 0:0 */
	WData *ltc2mc_avl_rdata_0;       /* 127:0 */
};

#define Cmod_MCPU_MEM_mc_CONNECT(str, cla) \
	do { \
		(str)->ltc2mc_avl_burstbegin_0 = &((cla)->ltc2mc_avl_burstbegin_0); \
		(str)->ltc2mc_avl_read_req_0 = &((cla)->ltc2mc_avl_read_req_0); \
		(str)->ltc2mc_avl_size_0 = &((cla)->ltc2mc_avl_size_0); \
		(str)->ltc2mc_avl_be_0 = &((cla)->ltc2mc_avl_be_0); \
		(str)->ltc2mc_avl_addr_0 = &((cla)->ltc2mc_avl_addr_0); \
		(str)->ltc2mc_avl_write_req_0 = &((cla)->ltc2mc_avl_write_req_0); \
		(str)->ltc2mc_avl_wdata_0 = (cla)->ltc2mc_avl_wdata_0; \
		\
		(str)->ltc2mc_avl_ready_0 = &((cla)->ltc2mc_avl_ready_0); \
		(str)->ltc2mc_avl_rdata_valid_0 = &((cla)->ltc2mc_avl_rdata_valid_0); \
		(str)->ltc2mc_avl_rdata_0 = (cla)->ltc2mc_avl_rdata_0; \
	} while(0)

/* SIG8 = CData (uint8_t)
 * SIG16 = SData (uint16_t)
 * SIG64 = QData (uint64_t)
 * SIG = IData (uint32_t)
 * SIGW = WData[words] (uint32_t)
 */
class Cmod_MCPU_MEM_mc {
	Cmod_MCPU_MEM_mc_ports *ports;

	CData ltc2mc_avl_read_req_0_last;
	CData ltc2mc_avl_write_req_0_last;

	/* State */
	uint8_t memory[Cmod_MCPU_MEM_mc_MEMSZ];
	int burst_cycrem;
	int burst_rnw;
	
public:
	Cmod_MCPU_MEM_mc(Cmod_MCPU_MEM_mc_ports *_ports);

	void clk();
};

#endif
