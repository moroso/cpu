#ifndef _Check_MCPU_MEM_dl1c_H
#define _Check_MCPU_MEM_dl1c_H

#define NUM_WAYS 2

#define SET_WIDTH 4
#define TAG_WIDTH 23

#define LINE_SIZE 256
#define LINE_SIZE_WORDS (LINE_SIZE / 32)

#define NUM_SETS (1<<SET_WIDTH)

enum Dl1c_Check_Op {
  NONE,
  READ,
  WRITE,
};

#include "MCPU_MEM_dl1c_ports.h"

class Check_MCPU_MEM_dl1c {
  struct CacheEntry {
    uint32_t line[LINE_SIZE_WORDS];
    uint32_t tag;
    uint32_t last_access;
    bool valid;
  };

  struct CacheRequest {
    Dl1c_Check_Op op;
    uint32_t addr;
    uint32_t data;
    uint8_t wmask;

    bool read_finished;
    bool mem_read_finished;
    bool write_finished;

    void reset(void) {
      op = NONE;
      read_finished = false;
      mem_read_finished = false;
      write_finished = false;
    }
  };

  bool active;
  bool fetch_active;
  bool write_active;

  uint32_t ltc_addr;
  uint32_t ltc_val;
  uint32_t ltc_wbe;

  bool expect_read_0;
  bool expect_write_0;
  bool expect_read_1;
  bool expect_write_1;

  CacheEntry *ent0;
  CacheEntry *ent1;

  CacheRequest op0;
  CacheRequest op1;

  MCPU_MEM_dl1c_ports *ports;

  Check_MCPU_MEM_dl1c::CacheEntry *entry_for_addr(uint32_t addr);
  void store(uint32_t addr, uint32_t line[LINE_SIZE_WORDS]);
  void verify_arb_inputs();
  void finish_op(CacheRequest &op, uint32_t outval);

  CacheEntry address_map[NUM_SETS][NUM_WAYS];
 public:
  Check_MCPU_MEM_dl1c(MCPU_MEM_dl1c_ports *ports);

  void clk();
  void reset();
};

#endif
