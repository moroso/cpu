#ifndef _MCPU_MEM_ports_H
#define _MCPU_MEM_ports_H

#include "verilated.h"

struct MCPU_MEM_ports {
	CData *clkrst_mem_clk;   /* 0:0 */
	CData *clkrst_mem_rst_n; /* 0:0 */
	
	/* inputs */
	CData *valid;            /* 0:0 */
	CData *opcode;           /* 2:0 */
	IData *addr;             /* 31:5 */
	WData *wdata;            /* 255:0 */
	WData *wbe;              /* 31:0 */
	
	/* outputs */
	CData *rvalid;           /* 0:0 */
	CData *stall;            /* 0:0 */
	WData *rdata;            /* 255:0 */
};

#define MCPU_MEM_ports_CONNECT(str, cla, pfx) \
	do { \
		(str)->clkrst_mem_clk = &((cla)->clkrst_mem_clk); \
		(str)->clkrst_mem_rst_n = &((cla)->clkrst_mem_rst_n); \
		\
		(str)->valid = &((cla)->pfx##valid); \
		(str)->opcode = &((cla)->pfx##opcode); \
		(str)->addr = &((cla)->pfx##addr); \
		(str)->wdata = (cla)->pfx##wdata; \
		(str)->wbe = &((cla)->pfx##wbe); \
		\
		(str)->rvalid = &((cla)->pfx##rvalid); \
		(str)->stall = &((cla)->pfx##stall); \
		(str)->rdata = (cla)->pfx##rdata; \
	} while(0)


#endif
