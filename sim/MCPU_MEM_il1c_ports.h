#ifndef __MCPU_MEM_il1c_ports_H
#define __MCPU_MEM_il1c_ports_H

struct MCPU_MEM_il1c_ports {
  /* Inputs */
  CData *clkrst_mem_clk;                /* 0:0 */
  CData *clkrst_mem_rst_n;              /* 0:0 */
  WData *il1c2arb_rdata;                /* 255:0 */
  CData *il1c2arb_rvalid;               /* 0:0 */
  CData *il1c2arb_stall;                /* 0:0 */
  CData *il1c2tlb_flags;                /* 3:0 */
  IData *il1c2tlb_phys_addr;            /* 31:12 */
  CData *il1c2tlb_ready;                /* 0:0 */
  IData *il1c_addr;                     /* 31:4 */
  CData *il1c_re;                       /* 0:0 */

  /* Outputs */
  IData *il1c2arb_addr;                 /* 31:5 */
  CData *il1c2arb_opcode;               /* 2:0 */
  CData *il1c2arb_valid;                /* 0:0 */
  IData *il1c2arb_wbe;                  /* 31:0 */
  WData *il1c2arb_wdata;                /* 255:0 */
  IData *il1c2tlb_addr;                 /* 31:12 */
  CData *il1c2tlb_re;                   /* 0:0 */
  WData *il1c_packet;                   /* 127:0 */
  CData *il1c_ready;                    /* 0:0 */
};

#define MCPU_MEM_il1c_CONNECT(str, cla) \
  do { \
    (str)->clkrst_mem_clk = &((cla)->clkrst_mem_clk); \
    (str)->clkrst_mem_rst_n = &((cla)->clkrst_mem_rst_n); \
    (str)->il1c2arb_rdata = ((cla)->il1c2arb_rdata); \
    (str)->il1c2arb_rvalid = &((cla)->il1c2arb_rvalid); \
    (str)->il1c2arb_stall = &((cla)->il1c2arb_stall); \
    (str)->il1c2tlb_flags = &((cla)->il1c2tlb_flags); \
    (str)->il1c2tlb_phys_addr = &((cla)->il1c2tlb_phys_addr); \
    (str)->il1c2tlb_ready = &((cla)->il1c2tlb_ready); \
    (str)->il1c_addr = &((cla)->il1c_addr); \
    (str)->il1c_re = &((cla)->il1c_re); \
    \
    (str)->il1c2arb_addr = &((cla)->il1c2arb_addr); \
    (str)->il1c2arb_opcode = &((cla)->il1c2arb_opcode); \
    (str)->il1c2arb_valid = &((cla)->il1c2arb_valid); \
    (str)->il1c2arb_wbe = &((cla)->il1c2arb_wbe); \
    (str)->il1c2arb_wdata = ((cla)->il1c2arb_wdata); \
    (str)->il1c2tlb_addr = &((cla)->il1c2tlb_addr); \
    (str)->il1c2tlb_re = &((cla)->il1c2tlb_re); \
    (str)->il1c_packet = ((cla)->il1c_packet); \
    (str)->il1c_ready = &((cla)->il1c_ready); \
  } while(0)

#endif
