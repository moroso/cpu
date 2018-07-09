#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
#endif
#include "Cmod_MCPU_MEM_walk.h"
#include "VMCPU_MEM_dtlb.h"

// (Loose) upper bound on cycle count any operation should take.
#define DEADLINE 128

#define TAG_SIZE 7
#define SET_SIZE 13

#define DATA_BRAM_SIZE (1<<SET_SIZE)

#if VM_TRACE
  #define TRACE tfp->dump(Sim::main_time)
#else
  #define TRACE
#endif

#if VM_TRACE
void _close_trace() {
	if (tfp) tfp->close();
}
#endif

class TlbTest {
  Cmod_MCPU_MEM_walk_ports *walk_ports;
  Cmod_MCPU_MEM_walk *walk;
	VMCPU_MEM_dtlb *tb;

public:
  TlbTest(VMCPU_MEM_dtlb *tb);
  ~TlbTest();

  void lookup(uint32_t addr_a, bool addr_a_en, uint32_t addr_b, bool addr_b_en,
              int expected_accesses);
  void lookup_complex(uint32_t addr_a, bool addr_a_en,
                      uint32_t addr_a_new, bool addr_a_new_en,
                      uint32_t addr_b, bool addr_b_en,
                      uint32_t addr_b_new, bool addr_b_new_en,
                      int expected_accesses);
  void lookup_single(uint32_t addr, bool is_addr_b, int expected_accesses);
  void complete_lookup(uint32_t addr_a, bool addr_a_en,
                       uint32_t addr_a_new, bool addr_a_new_en,
                       uint32_t addr_b, bool addr_b_en,
                       uint32_t addr_b_new, bool addr_b_new_en,
                       int expected_accesses, int prior_accesses);
  void set_addr(uint32_t virt, uint32_t phys, uint8_t virt_flags, uint8_t phys_flags);
  void reset();
  void verify(uint32_t expected_addr_a, uint32_t expected_flags_a, bool check_addr_a,
              uint32_t expected_addr_b, uint32_t expected_flags_b, bool check_addr_b);
  void verify_single(uint32_t expected_addr, uint32_t expected_flags, bool is_addr_b);
};

TlbTest::TlbTest(VMCPU_MEM_dtlb *tb) : tb(tb) {
  walk_ports = new Cmod_MCPU_MEM_walk_ports;
  Cmod_MCPU_MEM_walk_CONNECT(walk_ports, tb);
  walk = new Cmod_MCPU_MEM_walk(walk_ports);
}

TlbTest::~TlbTest() {
  delete walk;
  delete walk_ports;
}

void TlbTest::reset() {
  // Clear the cache, for a new test.
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    tb->MCPU_MEM_dtlb__DOT__data_bram_gen__BRA__0__KET____DOT__data_bram0__DOT__ram[i] = 0;
    tb->MCPU_MEM_dtlb__DOT__data_bram_gen__BRA__1__KET____DOT__data_bram0__DOT__ram[i] = 0;
    tb->MCPU_MEM_dtlb__DOT__evict_bram0__DOT__ram[i] = 0;
  }

  walk->clear();
}

void TlbTest::lookup(uint32_t addr_a, bool addr_a_en,
                     uint32_t addr_b, bool addr_b_en,
                     int expected_accesses) {
  lookup_complex(addr_a, addr_a_en, addr_a, false,
                 addr_b, addr_b_en, addr_b, false,
                 expected_accesses);
}

void TlbTest::complete_lookup(uint32_t addr_a, bool addr_a_en,
                              uint32_t addr_a_new, bool addr_a_new_en,
                              uint32_t addr_b, bool addr_b_en,
                              uint32_t addr_b_new, bool addr_b_new_en,
                              int expected_accesses, int prior_accesses) {
  int cycles = 0;
  while (cycles++ < DEADLINE) {
    tb->dtlb_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;

    tb->dtlb_clk = 1;
    walk->clk();
    tb->eval();
    tb->dtlb_re_a = addr_a_new_en;
    tb->dtlb_addr_a = addr_a_new;
    tb->dtlb_re_b = addr_b_new_en;
    tb->dtlb_addr_b = addr_b_new;
    tb->eval();
    if (tb->dtlb_ready) {
      int access_count = walk->get_access_count() - prior_accesses;
      if (expected_accesses >= 0 && access_count != expected_accesses) {
        SIM_FATAL("On read from %x(%d), %x(%d) expected %d walk accesses; got %d",
                  addr_a, addr_a_en, addr_b, addr_b_en, expected_accesses, access_count);
      }
      return;
    }
    Sim::tick();
    TRACE;
  }

  SIM_FATAL("Deadline of %d exceeded on read from %x(%d), %x(%d)",
            DEADLINE, addr_a, addr_a_en, addr_b, addr_b_en);
}

void TlbTest::lookup_complex(uint32_t addr_a, bool addr_a_en,
                             uint32_t addr_a_new, bool addr_a_new_en,
                             uint32_t addr_b, bool addr_b_en,
                             uint32_t addr_b_new, bool addr_b_new_en,
                             int expected_accesses) {
  int prior_accesses = walk->get_access_count();

  tb->dtlb_clk = 1;
  tb->eval();
  tb->dtlb_re_a = addr_a_en;
  tb->dtlb_addr_a = addr_a;
  tb->dtlb_re_b = addr_b_en;
  tb->dtlb_addr_b = addr_b;
  tb->eval();
  Sim::tick();
  TRACE;

  complete_lookup(addr_a, addr_a_en,
                  addr_a_new, addr_a_new_en,
                  addr_b, addr_b_en,
                  addr_b_new, addr_b_new_en,
                  expected_accesses,
                  prior_accesses);
}

void TlbTest::lookup_single(uint32_t addr, bool is_addr_b, int expected_accesses) {
  if (is_addr_b) {
    lookup(0, false, addr, true, expected_accesses);
  } else {
    lookup(addr, true, 0, false, expected_accesses);
  }
}

void TlbTest::verify(uint32_t expected_addr_a,
                     uint32_t expected_flags_a,
                     bool check_addr_a,
                     uint32_t expected_addr_b,
                     uint32_t expected_flags_b,
                     bool check_addr_b) {
  if (check_addr_a) {
    if (tb->dtlb_phys_addr_a != expected_addr_a ||
        tb->dtlb_flags_a != expected_flags_a) {
      SIM_FATAL("Bad lookup on A: expected 0x%x(0x%x), got 0x%x(0x%x)",
                expected_addr_a, expected_flags_a,
                tb->dtlb_phys_addr_a, tb->dtlb_flags_a);
    }
  }

  if (check_addr_b) {
    if (tb->dtlb_phys_addr_b != expected_addr_b ||
        tb->dtlb_flags_b != expected_flags_b) {
      SIM_FATAL("Bad lookup on B: expected 0x%x(0x%x), got 0x%x(0x%x)",
                expected_addr_b, expected_flags_b,
                tb->dtlb_phys_addr_b, tb->dtlb_flags_b);
    }
  }
}

void TlbTest::verify_single(uint32_t expected_addr, uint32_t expected_flags,
                            bool is_addr_b) {
  if (is_addr_b) {
    verify(0, 0, false, expected_addr, expected_flags, true);
  } else {
    verify(expected_addr, expected_flags, true, 0, 0, false);
  }
}

void TlbTest::set_addr(uint32_t virt, uint32_t phys,
                       uint8_t virt_flags, uint8_t phys_flags) {
  walk->add_mapping(virt, phys, virt_flags, phys_flags);
}

/* TEST CASES */
void test_cache_single_part(TlbTest &test, bool is_addr_b) {
  test.set_addr(0x12345, 0x56789, 0xf, 0xf);
  test.set_addr(0x22345, 0xccccc, 0xf, 0xf);
  test.set_addr(0x32345, 0xddddd, 0xf, 0xf);
  test.set_addr(0x42345, 0xeeeee, 0xf, 0xf);
  test.set_addr(0x52345, 0xfffff, 0xf, 0xf);

  test.lookup_single(0x12345, is_addr_b, 1);
  test.verify_single(0x56789, 0xf, is_addr_b);

  // If we read again, it should come back in a single cycle
  test.lookup_single(0x12345, is_addr_b, 0);
  test.verify_single(0x56789, 0xf, is_addr_b);

  test.lookup_single(0x22345, is_addr_b, 1);
  test.verify_single(0xccccc, 0xf, is_addr_b);

  // Now both values should be cached, and come back in one cycle
  test.lookup_single(0x12345, is_addr_b, 0);
  test.verify_single(0x56789, 0xf, is_addr_b);
  test.lookup_single(0x22345, is_addr_b, 0);
  test.verify_single(0xccccc, 0xf, is_addr_b);

  test.lookup_single(0x32345, is_addr_b, 1);
  test.verify_single(0xddddd, 0xf, is_addr_b);

  // 0x12345 should have been evicted. The other two values should
  // be single-cycle.
  test.lookup_single(0x22345, is_addr_b, 0);
  test.verify_single(0xccccc, 0xf, is_addr_b);
  test.lookup_single(0x32345, is_addr_b, 0);
  test.verify_single(0xddddd, 0xf, is_addr_b);

  test.lookup_single(0x12345, is_addr_b, 1);
  test.verify_single(0x56789, 0xf, is_addr_b);

  // This time 0x22345 should have been evicted.
  test.lookup_single(0x32345, is_addr_b, 0);
  test.verify_single(0xddddd, 0xf, is_addr_b);
  test.lookup_single(0x12345, is_addr_b, 0);
  test.verify_single(0x56789, 0xf, is_addr_b);

  // Two consecutive misses without a hit between them--test that
  // eviction bits are set correctly on miss, not just after a hit.
  test.lookup_single(0x42345, is_addr_b, 1);
  test.verify_single(0xeeeee, 0xf, is_addr_b);
  test.lookup_single(0x52345, is_addr_b, 1);
  test.verify_single(0xfffff, 0xf, is_addr_b);

  // Neither of these should have gotten evicted.
  test.lookup_single(0x42345, is_addr_b, 0);
  test.verify_single(0xeeeee, 0xf, is_addr_b);
  test.lookup_single(0x52345, is_addr_b, 0);
  test.verify_single(0xfffff, 0xf, is_addr_b);
}
void test_cache_single(TlbTest &test) {
  test.reset();
  test_cache_single_part(test, false);
  test.reset();
  test_cache_single_part(test, true);
}

void test_cache_single_fill_part(TlbTest &test, bool is_addr_b) {
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.set_addr(i, 0xfffff ^ i, 0xf, 0xf);
    test.set_addr(0x80000 | i, 0xaaaaa ^ i, 0xf, 0xf);
  }

  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(i, is_addr_b, 1);
    test.verify_single(0xfffff ^ i, 0xf, is_addr_b);
  }
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(0x80000 | i, is_addr_b, 1);
    test.verify_single(0xaaaaa ^ i, 0xf, is_addr_b);
  }

  // This time around, all access should be single cycle.
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(i, is_addr_b, 0);
    test.verify_single(0xfffff ^ i, 0xf, is_addr_b);
  }
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(0x80000 | i, is_addr_b, 0);
    test.verify_single(0xaaaaa ^ i, 0xf, is_addr_b);
  }
}
void test_cache_single_fill(TlbTest &test) {
  test.reset();
  test_cache_single_fill_part(test, false);
  test.reset();
  test_cache_single_fill_part(test, true);
}

void test_cache_dual_simple(TlbTest &test) {
  test.reset();

  test.set_addr(0x12345, 0x56789, 0xf, 0xf);
  test.set_addr(0x22345, 0xccccc, 0xf, 0xf);
  test.set_addr(0x32345, 0xddddd, 0xf, 0xf);
  test.set_addr(0x42345, 0xeeeee, 0xf, 0xf);
  test.set_addr(0x52345, 0xfffff, 0xf, 0xf);

  test.lookup(0x12345, true, 0x22345, true, 2);
  test.verify(0x56789, 0xf, true, 0xccccc, 0xf, true);

  // Reading again should hit the cache
  test.lookup(0x12345, true, 0x22345, true, 0);
  test.verify(0x56789, 0xf, true, 0xccccc, 0xf, true);

  // Read on opposite channels
  test.lookup(0x22345, true, 0x12345, true, 0);
  test.verify(0xccccc, 0xf, true, 0x56789, 0xf, true);

  // Both should be evicted
  test.lookup(0x32345, true, 0x42345, true, 2);
  test.verify(0xddddd, 0xf, true, 0xeeeee, 0xf, true);

  test.lookup(0x32345, true, 0x42345, true, 0);
  test.verify(0xddddd, 0xf, true, 0xeeeee, 0xf, true);

  // The read from the first slot should update the eviction bit,
  // so the read in the second slot should evict 0x42345, not 0x32345.
  test.lookup(0x32345, true, 0x52345, true, 1);
  test.verify(0xddddd, 0xf, true, 0xfffff, 0xf, true);

  test.lookup(0x32345, true, 0x52345, true, 0);
  test.verify(0xddddd, 0xf, true, 0xfffff, 0xf, true);
}

void test_cache_dual_read_same(TlbTest &test) {
  test.reset();

  test.set_addr(0x12345, 0x56789, 0xf, 0xf);
  test.lookup(0x12345, true, 0x12345, true, 1);
  test.verify(0x56789, 0xf, true, 0x56789, 0xf, true);

  // Same test, but from the cache
  test.lookup(0x12345, true, 0x12345, true, 0);
  test.verify(0x56789, 0xf, true, 0x56789, 0xf, true);
}

void test_combine_flags(TlbTest &test) {
  test.reset();

  test.set_addr(0x0, 0x0, 0x9, 0x1); // Global+present flag
  test.lookup(0x0, true, 0x0, true, 1);
  test.verify(0x0, 0x9, true, 0x0, 0x9, true);

  test.set_addr(0x1, 0x0, 0x1, 0x9); // Global+present flag
  test.lookup(0x1, true, 0x1, true, 1);
  test.verify(0x0, 0x9, true, 0x0, 0x9, true);

  test.set_addr(0x2, 0x0, 0x5, 0x1); // Kernel+present flag
  test.lookup(0x2, true, 0x2, true, 1);
  test.verify(0x0, 0x5, true, 0x0, 0x5, true);

  test.set_addr(0x3, 0x0, 0x1, 0x5); // Kernel+present flag
  test.lookup(0x3, true, 0x3, true, 1);
  test.verify(0x0, 0x5, true, 0x0, 0x5, true);

  test.set_addr(0x4, 0x0, 0x3, 0x1); // Writeable+present flag
  test.lookup(0x4, true, 0x4, true, 1);
  test.verify(0x0, 0x1, true, 0x0, 0x1, true);

  test.set_addr(0x5, 0x0, 0x1, 0x3); // Writeable+present flag
  test.lookup(0x5, true, 0x5, true, 1);
  test.verify(0x0, 0x1, true, 0x0, 0x1, true);

  test.set_addr(0x6, 0x0, 0x1, 0x0); // Present flag
  test.lookup(0x6, true, 0x6, true, 1);
  test.verify(0x0, 0x0, true, 0x0, 0x0, true);

  test.set_addr(0x7, 0x0, 0x0, 0x1); // Present flag
  test.lookup(0x7, true, 0x7, true, 1);
  test.verify(0x0, 0x0, true, 0x0, 0x0, true);
}

void test_cache_missing(TlbTest &test) {
  test.reset();

  test.set_addr(0x0, 0x10, 0xf, 0x0); // Non-present page
  test.set_addr(0x1, 0x20, 0x0, 0xf); // Non-present page

  // Look up the missing pages
  test.lookup(0x0, true, 0x1, true, 2);
  test.verify(0x10, 0xc, true, 0x20, 0xc, true);

  // We should have cached the absent pages
  test.lookup(0x1, true, 0x0, true, 0);
  test.verify(0x20, 0xc, true, 0x10, 0xc, true);
}

void test_back_to_back(TlbTest &test) {
  test.reset();

  test.set_addr(0x0, 0x10, 0xf, 0xf);
  test.set_addr(0x1, 0x11, 0xf, 0xf);
  test.set_addr(0x2, 0x12, 0xf, 0xf);
  test.set_addr(0x3, 0x13, 0xf, 0xf);

  // Look up addresses 0 and 2. Then, next cycle, change
  // the addresses to 1 and 3, keeping re lines high.
  test.lookup_complex(0x0, true, 0x1, true, 0x2, true, 0x3, true, 2);
  test.verify(0x10, 0xf, true, 0x12, 0xf, true);

  // Keep clocking; next time ready goes high, we should have
  // the results of addresses 1 and 3.
  test.complete_lookup(0x1, true, 0x0, true, 0x3, true, 0x0, true, -1, 0);
  test.verify(0x11, 0xf, true, 0x13, 0xf, true);
}

int main(int argc, char **argv, char **env) {
	Sim::init(argc, argv);

	VMCPU_MEM_dtlb *tb = new VMCPU_MEM_dtlb;
  TlbTest test = TlbTest(tb);

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);
#endif

  test_cache_single(test);
  test_cache_single_fill(test);
  test_cache_dual_simple(test);
  test_cache_dual_read_same(test);
  test_combine_flags(test);
  test_cache_missing(test);
  test_back_to_back(test);

  // Let a few clock cycles go by before we exit (it's nicer
  // when we're looking at the .vcd file)
  for (int i = 0; i < 128; i++) {
    tb->eval();
    tb->dtlb_clk = 1;
    //walk->clk();
    tb->eval();
    Sim::tick();
    TRACE;

    tb->dtlb_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;
  }

  Sim::finish();

	return 0;
}
