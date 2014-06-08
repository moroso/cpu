#ifndef _CMOD_MCPU_MEM_mc_H
#define _CMOD_MCPU_MEM_mc_H

#include "verilated.h"

#define Cmod_MCPU_MEM_mc_MEMSZ 512*1024*1024

/* SIG8 = CData (uint8_t)
 * SIG16 = SData (uint16_t)
 * SIG64 = QData (uint64_t)
 * SIG = IData (uint32_t)
 * SIGW = WData[words] (uint32_t)
 */
class Cmod_MCPU_MEM_mc {

	/* Connections */
#define MC_CMOD_CONNECTIONS(X, obj) \
	/* inputs */ \
	X(CData, &, ltc2mc_avl_burstbegin_0, obj) /* 0:0 */ \
	X(CData, &, ltc2mc_avl_read_req_0, obj) /* 0:0 */ \
	X(CData, &, ltc2mc_avl_size_0, obj) /* 4:0 */ \
	X(SData, &, ltc2mc_avl_be_0, obj) /* 15:0 */ \
	X(IData, &, ltc2mc_avl_addr_0, obj) /* 24:0 */ \
	X(CData, &, ltc2mc_avl_write_req_0, obj) /* 0:0 */ \
	X(WData,  , ltc2mc_avl_wdata_0, obj) /* 127:0 */ \
	\
	/* outputs */ \
	X(CData, &, ltc2mc_avl_ready_0, obj) /* 0:0 */ \
	X(CData, &, ltc2mc_avl_rdata_valid_0, obj) /* 0:0 */ \
	X(WData,  , ltc2mc_avl_rdata_0, obj) /* 127:0 */
	
#define MC_CMOD_CONNECTION_DECL(ty, am, na, obj) ty *na;
#define MC_CMOD_CONNECTION_ARG(ty, am, na, obj) ty *_##na,
#define MC_CMOD_CONNECTION_INST(ty, am, na, obj) na(_##na),
#define MC_CMOD_CONNECTION_CONN(ty, am, na, obj) am ((obj).na),
#define Cmod_MCPU_MEM_mc_CONNECT(obj) MC_CMOD_CONNECTIONS(MC_CMOD_CONNECTION_CONN, obj) 0

	MC_CMOD_CONNECTIONS(MC_CMOD_CONNECTION_DECL,)

	CData ltc2mc_avl_read_req_0_last;
	CData ltc2mc_avl_write_req_0_last;

	/* State */
	uint8_t memory[Cmod_MCPU_MEM_mc_MEMSZ];
	int burst_cycrem;
	int burst_rnw;
	
public:
	Cmod_MCPU_MEM_mc(
		MC_CMOD_CONNECTIONS(MC_CMOD_CONNECTION_ARG,) int _bogus = 0
		);

	void clk();
};

#endif
