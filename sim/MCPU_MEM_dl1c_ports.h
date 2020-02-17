#ifndef _MCPU_MEM_dl1c_ports_H
#define _MCPU_MEM_dl1c_ports_H

#include "verilated.h"

struct MCPU_MEM_dl1c_ports {
  /* Inputs */
  CData *clk;                           /* 0:0 */
  WData *dl1c2arb_rdata;                /* 255:0 */
  CData *dl1c2arb_rvalid;               /* 0:0 */
  CData *dl1c2arb_stall;                /* 0:0 */
  IData *dl1c2periph_data_in;           /* 31:0 */
  IData *dl1c_addr_a;                   /* 31:2 */
  IData *dl1c_addr_b;                   /* 31:2 */
  IData *dl1c_in_a;                     /* 31:0 */
  IData *dl1c_in_b;                     /* 31:0 */
  CData *dl1c_re_a;                     /* 0:0 */
  CData *dl1c_re_b;                     /* 0:0 */
  CData *dl1c_we_a;                     /* 3:0 */
  CData *dl1c_we_b;                     /* 3:0 */
  CData *dl1c_reset;                    /* 0:0 */

  /* Outputs */
  IData *dl1c2arb_addr;                 /* 31:5 */
  CData *dl1c2arb_opcode;               /* 2:0 */
  CData *dl1c2arb_valid;                /* 0:0 */
  IData *dl1c2arb_wbe;                  /* 31:0 */
  WData *dl1c2arb_wdata;                /* 255:0 */
  IData *dl1c2periph_addr;              /* 31:2 */
  IData *dl1c2periph_data_out;          /* 31:0 */
  CData *dl1c2periph_re;                /* 0:0 */
  CData *dl1c2periph_we;                /* 3:0 */
  IData *dl1c_out_a;                    /* 31:0 */
  IData *dl1c_out_b;                    /* 31:0 */
  CData *dl1c_ready;                    /* 0:0 */
};

#define MCPU_MEM_dl1c_CONNECT(str, cla) \
  do { \
    (str)->clk = &((cla)->clk); \
    (str)->dl1c2arb_rdata = ((cla)->dl1c2arb_rdata); \
    (str)->dl1c2arb_rvalid = &((cla)->dl1c2arb_rvalid); \
    (str)->dl1c2arb_stall = &((cla)->dl1c2arb_stall); \
    (str)->dl1c2periph_data_in = &((cla)->dl1c2periph_data_in); \
    (str)->dl1c_addr_a = &((cla)->dl1c_addr_a); \
    (str)->dl1c_addr_b = &((cla)->dl1c_addr_b); \
    (str)->dl1c_in_a = &((cla)->dl1c_in_a); \
    (str)->dl1c_in_b = &((cla)->dl1c_in_b); \
    (str)->dl1c_re_a = &((cla)->dl1c_re_a); \
    (str)->dl1c_re_b = &((cla)->dl1c_re_b); \
    (str)->dl1c_we_a = &((cla)->dl1c_we_a); \
    (str)->dl1c_we_b = &((cla)->dl1c_we_b); \
    (str)->dl1c_reset = &((cla)->dl1c_reset); \
    \
    (str)->dl1c2arb_addr = &((cla)->dl1c2arb_addr); \
    (str)->dl1c2arb_opcode = &((cla)->dl1c2arb_opcode); \
    (str)->dl1c2arb_valid = &((cla)->dl1c2arb_valid); \
    (str)->dl1c2arb_wbe = &((cla)->dl1c2arb_wbe); \
    (str)->dl1c2arb_wdata = ((cla)->dl1c2arb_wdata); \
    (str)->dl1c2periph_addr = &((cla)->dl1c2periph_addr); \
    (str)->dl1c2periph_data_out = &((cla)->dl1c2periph_data_out); \
    (str)->dl1c2periph_re = &((cla)->dl1c2periph_re); \
    (str)->dl1c2periph_we = &((cla)->dl1c2periph_we); \
    (str)->dl1c_out_a = &((cla)->dl1c_out_a); \
    (str)->dl1c_out_b = &((cla)->dl1c_out_b); \
    (str)->dl1c_ready = &((cla)->dl1c_ready); \
  } while(0)

#endif
