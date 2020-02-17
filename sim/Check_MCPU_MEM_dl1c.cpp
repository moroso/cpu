#include "Sim.h"

#include "Check_MCPU_MEM_dl1c.h"
#include "mem_common.h"

#define FROM_L1C_ADDR(addr) ((addr) << 2)
#define TO_L1C_ADDR(addr) ((addr) >> 2)

#define FROM_ARB_ADDR(addr) ((addr) << 5)
#define TO_ARB_ADDR(addr) ((addr) >> 5)

#define SET(addr) ((TO_ARB_ADDR(addr)) & ((1<<SET_WIDTH)-1))
#define TAG(addr) (TO_ARB_ADDR(addr) >> (SET_WIDTH))

#define OFFS(addr) ((addr) & 0x1f)


Check_MCPU_MEM_dl1c::Check_MCPU_MEM_dl1c(MCPU_MEM_dl1c_ports *ports) :
  ports(ports), active(false), fetch_active(false), write_active(false) {
  for (int set = 0; set < NUM_SETS; set++) {
    for (int way = 0; way < NUM_WAYS; way++) {
      address_map[set][way].valid = 0;
    }
  }
}

Check_MCPU_MEM_dl1c::CacheEntry *Check_MCPU_MEM_dl1c::entry_for_addr(uint32_t addr) {
  uint32_t set = SET(addr);
  uint32_t tag = TAG(addr);
  for (int way = 0; way < NUM_WAYS; way++) {
    if (address_map[set][way].tag == tag && address_map[set][way].valid) {
      address_map[set][way].last_access = Sim::main_time;
      return &address_map[set][way];
    }
  }

  return NULL;
}

void Check_MCPU_MEM_dl1c::store(uint32_t addr, uint32_t line[LINE_SIZE_WORDS]) {
  uint32_t set = SET(addr);
  uint32_t tag = TAG(addr);

  CacheEntry *ent = entry_for_addr(addr);

  if (!ent) {
    uint32_t way;
    if (!address_map[set][0].valid) {
      way = 0;
    } else if (address_map[set][1].valid && address_map[set][0].last_access <= address_map[set][1].last_access) {
      // Note: in the event of a tie, we evict from way 0.
      way = 0;
    } else {
      way = 1;
    }

    ent = &address_map[set][way];
  }

  ent->valid = 1;
  ent->last_access = Sim::main_time;
  ent->tag = tag;
  for (int i = 0; i < LINE_SIZE_WORDS; i++) {
    ent->line[i] = line[i];
  }
}

Dl1c_Check_Op op_from_re_we(CData re, CData we) {
  if (re) {
    return READ;
  } else if (we) {
    return WRITE;
  } else {
    return NONE;
  }
}

uint32_t mask(uint32_t origval, uint32_t newval, uint8_t bytemask) {
  uint32_t res = 0;

  for (int i = 0; i < 4; i++) {
    if (bytemask & (1<<i)) {
      res |= ((newval >> (8*i)) & 0xff) << (8*i);
    } else {
      res |= ((origval >> (8*i)) & 0xff) << (8*i);
    }
  }

  return res;
}

void Check_MCPU_MEM_dl1c::finish_op(CacheRequest &op, uint32_t outval) {
  if (op.op != NONE) {
    uint32_t offs = TO_L1C_ADDR(op.addr) & 0x7;
    CacheEntry *ent = entry_for_addr(op.addr);
    SIM_CHECK(ent);

    if (op.op == WRITE) {
      ent->line[offs] = mask(ent->line[offs], op.data, op.wmask);
    } else {
      SIM_CHECK_EQ(outval, ent->line[offs]);
    }
  }
}

void Check_MCPU_MEM_dl1c::verify_arb_inputs() {
  // Verify that arb signals don't change while operations are in progress
  SIM_CHECK_EQ(TO_ARB_ADDR(ltc_addr), *ports->dl1c2arb_addr);
  if (write_active) {
    SIM_CHECK_EQ(ltc_val, *ports->dl1c2arb_wdata);
    SIM_CHECK_EQ(ltc_wbe, *ports->dl1c2arb_wbe);
    SIM_CHECK_EQ(*ports->dl1c2arb_opcode, LTC_OPC_WRITE);
  } else {
    SIM_CHECK(fetch_active);
    SIM_CHECK_EQ(*ports->dl1c2arb_opcode, LTC_OPC_READ);
  }
}

void Check_MCPU_MEM_dl1c::clk() {
  if (fetch_active || write_active) {
    verify_arb_inputs();
    if (fetch_active && *ports->dl1c2arb_rvalid) {
      SIM_INFO("Finished fetch. Read ...%x from %x", *ports->dl1c2arb_rdata, ltc_addr);
      fetch_active = false;

      store(ltc_addr, ports->dl1c2arb_rdata);
      if (expect_read_0) {
        expect_read_0 = false;
      } else {
        SIM_CHECK(expect_read_1);
        expect_read_1 = false;
      }
    }
    if (write_active && !*ports->dl1c2arb_stall) {
      SIM_INFO("Finished write");
      write_active = false;
    }
  } else {
    if (*ports->dl1c2arb_valid) {
      ltc_addr = FROM_ARB_ADDR(*ports->dl1c2arb_addr);
      if (*ports->dl1c2arb_opcode == LTC_OPC_READ) {
        int read_addr_0 = *ports->dl1c2arb_addr == TO_ARB_ADDR(op0.addr);
        int read_addr_1 = *ports->dl1c2arb_addr == TO_ARB_ADDR(op1.addr);
        if (expect_read_0) {
          SIM_INFO("Reading for 0");
          if (read_addr_1 && !read_addr_0) {
            SIM_ERROR("Read for slot 1, but expecting slot 0");
          }
          SIM_CHECK_EQ(*ports->dl1c2arb_addr, TO_ARB_ADDR(op0.addr));
        } else {
          SIM_INFO("Reading for 1");
          SIM_CHECK(expect_read_1);
          if (read_addr_0 && !read_addr_1) {
            SIM_ERROR("Read for slot 0, but expecting slot 1");
          }
          SIM_CHECK_EQ(*ports->dl1c2arb_addr, TO_ARB_ADDR(op1.addr));
        }
        fetch_active = true;
        SIM_INFO("Start fetch of addr %x (arb addr %x)", ltc_addr, TO_ARB_ADDR(ltc_addr));
      } else {
        // TODO: verify that the parameters are correct
        SIM_CHECK(*ports->dl1c2arb_opcode == LTC_OPC_WRITE);
        ltc_val = *ports->dl1c2arb_wdata;
        ltc_wbe = *ports->dl1c2arb_wbe;

        if (expect_write_0) {
          SIM_CHECK_EQ(*ports->dl1c2arb_addr, TO_ARB_ADDR(op0.addr));
          expect_write_0 = false;
        } else {
          SIM_CHECK(expect_write_1);
          SIM_CHECK_EQ(*ports->dl1c2arb_addr, TO_ARB_ADDR(op1.addr));
          expect_write_1 = false;
        }

        SIM_INFO("Start write of ...%x to addr %x (arb addr %x)", ltc_val, ltc_addr, TO_ARB_ADDR(ltc_addr));
        write_active = true;
      }
    }
  }

  if (active) {
    if (*ports->dl1c_ready) {
      SIM_INFO("Inactive.");
      active = false;
      SIM_CHECK(!expect_read_0);
      SIM_CHECK(!expect_write_0);
      SIM_CHECK(!expect_read_1);
      SIM_CHECK(!expect_write_1);

      finish_op(op0, *ports->dl1c_out_a);
      finish_op(op1, *ports->dl1c_out_b);
    }
  }

  if (!active) {
    if (*ports->dl1c_re_a || *ports->dl1c_re_b ||
        *ports->dl1c_we_a || *ports->dl1c_we_b) {
      SIM_INFO("Became active");
      active = true;

      op0.reset();
      op1.reset();

      op0.op = op_from_re_we(*ports->dl1c_re_a, *ports->dl1c_we_a);
      op1.op = op_from_re_we(*ports->dl1c_re_b, *ports->dl1c_we_b);

      op0.addr = FROM_L1C_ADDR(*ports->dl1c_addr_a);
      op0.data = *ports->dl1c_in_a;
      op0.wmask = *ports->dl1c_we_a;

      op1.addr = FROM_L1C_ADDR(*ports->dl1c_addr_b);
      op1.data = *ports->dl1c_in_b;
      op1.wmask = *ports->dl1c_we_b;

      if (op0.op != NONE) {
        ent0 = entry_for_addr(op0.addr);
        expect_read_0 = (ent0 == NULL);
        expect_write_0 = (op0.op == WRITE);
      } else {
        expect_read_0 = false;
        expect_write_0 = false;
      }

      if (op1.op != NONE) {
        ent1 = entry_for_addr(op1.addr);
        expect_read_1 = (ent1 == NULL) && (
          // If the addresses are the same, we don't expect a read on port 1.
          !expect_read_0 || (TO_ARB_ADDR(op0.addr) != TO_ARB_ADDR(op1.addr))
        );
        expect_write_1 = (op1.op == WRITE);
      } else {
        expect_read_1 = false;
        expect_write_1 = false;
      }

      SIM_INFO(
        "r0:%d r1:%d w0:%d w1:%d",
        expect_read_0, expect_read_1,
        expect_write_0, expect_write_1
      );
      SIM_INFO("set a: %x, tag a: %x", SET(op0.addr), TAG(op0.addr));
    }
  }
}
