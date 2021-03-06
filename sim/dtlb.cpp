#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
#endif
#include "Cmod_MCPU_MEM_walk.h"
#include "Check_MCPU_MEM_dtlb.h"
#include "Stim_MCPU_MEM_dtlb.h"
#include "MCPU_MEM_dtlb_ports.h"

#include "VMCPU_MEM_dtlb.h"

// (Loose) upper bound on cycle count any operation should take.
#define DEADLINE 128

#define TAG_SIZE 16
#define SET_SIZE 4

#define DATA_BRAM_SIZE (1<<SET_SIZE)

#if VM_TRACE
  #define TRACE tfp->dump(Sim::main_time)
#else
  #define TRACE
#endif

#define RANDOM_OPS_DEFAULT 16384
// By default, random tests can use any tag
#define RANDOM_TAGS_DEFAULT (1<<TAG_SIZE)
// By default, random tests can use any set
#define RANDOM_SETS_DEFAULT (1<<SET_SIZE)

#define ADDR_OF(tag, set) (((tag)<<SET_SIZE)|(set))

#if VM_TRACE
void _close_trace() {
	if (tfp) tfp->close();
}
#endif

class TlbTest {
  Cmod_MCPU_MEM_walk_ports *walk_ports;
  MCPU_MEM_dtlb_ports *dtlb_ports;
  Cmod_MCPU_MEM_walk *walk;
	VMCPU_MEM_dtlb *tb;
  Check_MCPU_MEM_dtlb *check;
  Stim_MCPU_MEM_dtlb *stim;

public:
  TlbTest(VMCPU_MEM_dtlb *tb);
  ~TlbTest();

  void lookup(uint32_t addr_a, bool addr_a_en, uint32_t addr_b, bool addr_b_en);
  void lookup_nowait(uint32_t addr_a, bool addr_a_en, uint32_t addr_b, bool addr_b_en);
  void lookup_single(uint32_t addr, bool is_addr_b);
  void set_addr(uint32_t virt, uint32_t phys, uint8_t virt_flags, uint8_t phys_flags);
  bool done();

  void latch() {
    walk->latch();
  }

  void clk() {
    tb->eval();
    stim->clk();
    walk->clk();
    tb->eval();
    check->clk();
    tb->eval();
  }

  void enable_walker_randomness() {
    walk->use_random = true;
  }
};

TlbTest::TlbTest(VMCPU_MEM_dtlb *tb) : tb(tb) {
  walk_ports = new Cmod_MCPU_MEM_walk_ports;
  Cmod_MCPU_MEM_walk_CONNECT(walk_ports, tb);
  walk = new Cmod_MCPU_MEM_walk(walk_ports);
  dtlb_ports = new MCPU_MEM_dtlb_ports;
  MCPU_MEM_dtlb_CONNECT(dtlb_ports, tb);
  check = new Check_MCPU_MEM_dtlb(dtlb_ports);
  stim = new Stim_MCPU_MEM_dtlb(dtlb_ports);
}

TlbTest::~TlbTest() {
  delete walk;
  delete walk_ports;
  delete check;
  delete stim;
  delete dtlb_ports;
}

void TlbTest::lookup(uint32_t addr_a, bool addr_a_en,
                     uint32_t addr_b, bool addr_b_en) {
  stim->read(addr_a, addr_a_en, addr_b, addr_b_en);
}

void TlbTest::lookup_nowait(uint32_t addr_a, bool addr_a_en,
                            uint32_t addr_b, bool addr_b_en) {
  stim->read_nowait(addr_a, addr_a_en, addr_b, addr_b_en);
}

void TlbTest::lookup_single(uint32_t addr, bool is_addr_b) {
  if (is_addr_b) {
    lookup(0, false, addr, true);
  } else {
    lookup(addr, true, 0, false);
  }
}

void TlbTest::set_addr(uint32_t virt, uint32_t phys,
                       uint8_t pd_flags, uint8_t pt_flags) {
  walk->add_mapping(virt, phys, pd_flags, pt_flags);
}

bool TlbTest::done() {
  return stim->done() && tb->dtlb_ready;
}

void run_test(VMCPU_MEM_dtlb *tb, void (*testfunc)(TlbTest &test)) {
  // TODO: we really should have at least one test with paging disabled...
  tb->paging_on = 1;
  // Clear cache state, in case we're running multiple tests.
  tb->clkrst_mem_rst_n = 1;
  tb->eval();
  Sim::tick();
  TRACE;
  tb->clkrst_mem_rst_n = 0;
  tb->eval();
  Sim::tick();
  TRACE;
  tb->clkrst_mem_rst_n = 1;
  tb->eval();
  Sim::tick();
  TRACE;

  TlbTest test(tb);

  testfunc(test);
  while (!test.done()) {
    test.latch();
    tb->clkrst_mem_clk = 1;
    test.clk();
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clkrst_mem_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;
  }

  // Wait a few cycles before starting the next test.
  for (int i = 0; i < 16; i++) {
    test.latch();
    tb->clkrst_mem_clk = 1;
    test.clk();
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clkrst_mem_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;
  }
}

/* TEST CASES */
void test_cache_single_part(TlbTest &test, bool is_addr_b) {
  test.set_addr(0x12345, 0x56789, 0xf, 0xf);
  test.set_addr(0x22345, 0xccccc, 0xf, 0xf);
  test.set_addr(0x32345, 0xddddd, 0xf, 0xf);
  test.set_addr(0x42345, 0xeeeee, 0xf, 0xf);
  test.set_addr(0x52345, 0xfffff, 0xf, 0xf);

  test.lookup_single(0x12345, is_addr_b);

  // If we read again, it should come back in a single cycle
  test.lookup_single(0x12345, is_addr_b);

  test.lookup_single(0x22345, is_addr_b);

  // Now both values should be cached, and come back in one cycle
  test.lookup_single(0x12345, is_addr_b);
  test.lookup_single(0x22345, is_addr_b);

  test.lookup_single(0x32345, is_addr_b);

  // 0x12345 should have been evicted. The other two values should
  // be single-cycle.
  test.lookup_single(0x22345, is_addr_b);
  test.lookup_single(0x32345, is_addr_b);

  test.lookup_single(0x12345, is_addr_b);

  // This time 0x22345 should have been evicted.
  test.lookup_single(0x32345, is_addr_b);
  test.lookup_single(0x12345, is_addr_b);

  // Two consecutive misses without a hit between them--test that
  // eviction bits are set correctly on miss, not just after a hit.
  test.lookup_single(0x42345, is_addr_b);
  test.lookup_single(0x52345, is_addr_b);

  // Neither of these should have gotten evicted.
  test.lookup_single(0x42345, is_addr_b);
  test.lookup_single(0x52345, is_addr_b);
}
void test_cache_single_a(TlbTest &test) {
  test_cache_single_part(test, false);
}
void test_cache_single_b(TlbTest &test) {
  test_cache_single_part(test, true);
}

void test_cache_single_fill_part(TlbTest &test, bool is_addr_b) {
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.set_addr(i, 0xfffff ^ i, 0xf, 0xf);
    test.set_addr(0x80000 | i, 0xaaaaa ^ i, 0xf, 0xf);
  }

  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(i, is_addr_b);
  }
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(0x80000 | i, is_addr_b);
  }

  // This time around, all access should be single cycle.
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(i, is_addr_b);
  }
  for (int i = 0; i < DATA_BRAM_SIZE; i++) {
    test.lookup_single(0x80000 | i, is_addr_b);
  }
}
void test_cache_single_fill_a(TlbTest &test) {
  test_cache_single_fill_part(test, false);
}
void test_cache_single_fill_b(TlbTest &test) {
  test_cache_single_fill_part(test, true);
}

void test_cache_dual_simple(TlbTest &test) {
  test.set_addr(0x12345, 0x56789, 0xf, 0xf);
  test.set_addr(0x22345, 0xccccc, 0xf, 0xf);
  test.set_addr(0x32345, 0xddddd, 0xf, 0xf);
  test.set_addr(0x42345, 0xeeeee, 0xf, 0xf);
  test.set_addr(0x52345, 0xfffff, 0xf, 0xf);

  test.lookup(0x12345, true, 0x22345, true);

  // Reading again should hit the cache
  test.lookup(0x12345, true, 0x22345, true);

  // Read on opposite channels
  test.lookup(0x22345, true, 0x12345, true);

  // Both should be evicted
  test.lookup(0x32345, true, 0x42345, true);

  test.lookup(0x32345, true, 0x42345, true);

  // The read from the first slot should update the eviction bit,
  // so the read in the second slot should evict 0x42345, not 0x32345.
  test.lookup(0x32345, true, 0x52345, true);

  test.lookup(0x32345, true, 0x52345, true);
}

void test_cache_dual_read_same(TlbTest &test) {
  test.set_addr(0x12345, 0x56789, 0xf, 0xf);
  test.lookup(0x12345, true, 0x12345, true);

  // Same test, but from the cache
  test.lookup(0x12345, true, 0x12345, true);
}

void test_combine_flags(TlbTest &test) {
  test.set_addr(0x0, 0x0, 0x9, 0x1); // Global+present flag
  test.lookup(0x0, true, 0x0, true);

  test.set_addr(0x1, 0x0, 0x1, 0x9); // Global+present flag
  test.lookup(0x1, true, 0x1, true);

  test.set_addr(0x2, 0x0, 0x5, 0x1); // Kernel+present flag
  test.lookup(0x2, true, 0x2, true);

  test.set_addr(0x3, 0x0, 0x1, 0x5); // Kernel+present flag
  test.lookup(0x3, true, 0x3, true);

  test.set_addr(0x4, 0x0, 0x3, 0x1); // Writeable+present flag
  test.lookup(0x4, true, 0x4, true);

  test.set_addr(0x5, 0x0, 0x1, 0x3); // Writeable+present flag
  test.lookup(0x5, true, 0x5, true);

  test.set_addr(0x6, 0x0, 0x1, 0x0); // Present flag
  test.lookup(0x6, true, 0x6, true);

  test.set_addr(0x7, 0x0, 0x0, 0x1); // Present flag
  test.lookup(0x7, true, 0x7, true);
}

void test_cache_missing(TlbTest &test) {
  test.set_addr(0x0, 0x10, 0xf, 0x0); // Non-present page
  test.set_addr(0x1, 0x20, 0x0, 0xf); // Non-present page

  // Look up the missing pages
  test.lookup(0x0, true, 0x1, true);

  // We should have cached the absent pages
  test.lookup(0x1, true, 0x0, true);
}

void test_back_to_back(TlbTest &test) {
  test.set_addr(0x0, 0x10, 0xf, 0xf);
  test.set_addr(0x1, 0x11, 0xf, 0xf);
  test.set_addr(0x2, 0x12, 0xf, 0xf);
  test.set_addr(0x3, 0x13, 0xf, 0xf);

  // Look up addresses 0 and 2. Then, next cycle, change
  // the addresses to 1 and 3, keeping re lines high.
  test.lookup_nowait(0x0, true, 0x2, true);

  // Keep clocking; next time ready goes high, we should have
  // the results of addresses 1 and 3.
  test.lookup(0x1, true, 0x3, true);
}

void test_evict_hit_and_miss(TlbTest &test) {
  // Test various eviction edge cases.
  test.set_addr(0x00000, 0x10, 0xf, 0xf);
  test.set_addr(0x10000, 0x11, 0xf, 0xf);
  test.set_addr(0x20000, 0x12, 0xf, 0xf);
  test.set_addr(0x30000, 0x13, 0xf, 0xf);

  test.lookup(0x00000, true, 0x10000, true);
  // This will hit on B and miss on A.
  // 0x20000 should replace 0x10000.
  test.lookup(0x20000, true, 0x00000, true);

  // 0x00000 should still be in the cache.
  test.lookup(0x00000, true, 0, false);

  // Repeat the test with slots swapped.
  // Hit on A and miss on B.
  test.lookup(0x20000, true, 0x30000, true);

  // 0x20000 should still be in the cache.
  test.lookup(0x20000, true, 0, false);
}

void test_random(TlbTest &test) {
  test.enable_walker_randomness();

  int nrandoms = Sim::param_u64("DTLB_RANDOM_OPERATIONS", RANDOM_OPS_DEFAULT);
  int ntags = Sim::param_u64("DTLB_RANDOM_TAGS", RANDOM_TAGS_DEFAULT);
  int nsets = Sim::param_u64("DTLB_RANDOM_SETS", RANDOM_SETS_DEFAULT);

  for (int i = 0; i < nrandoms; i++) {
    bool lookup1 = Sim::random(2);
    int tag1 = Sim::random(ntags);
    int set1 = Sim::random(nsets);

    bool lookup2 = Sim::random(2);
    int tag2 = Sim::random(ntags);
    int set2 = Sim::random(nsets);

    test.lookup(ADDR_OF(tag1, set1), lookup1,
                ADDR_OF(tag2, set2), lookup2);
  }
}



int main(int argc, char **argv, char **env) {
	Sim::init(argc, argv);

	VMCPU_MEM_dtlb *tb = new VMCPU_MEM_dtlb();

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);
#endif

	const char *testname;
	testname = Sim::param_str("DTLB_TEST_NAME", "directed");

  if (!strcmp(testname, "directed")) {
    SIM_INFO("cache single a");
    run_test(tb, test_cache_single_a);
    SIM_INFO("cache single b");
    run_test(tb, test_cache_single_b);
    SIM_INFO("dual simple");
    run_test(tb, test_cache_dual_simple);
    SIM_INFO("dual read same");
    run_test(tb, test_cache_dual_read_same);
    SIM_INFO("combine flags");
    run_test(tb, test_combine_flags);
    SIM_INFO("cache missing");
    run_test(tb, test_cache_missing);
    SIM_INFO("back to back");
    run_test(tb, test_back_to_back);
    SIM_INFO("evict");
    run_test(tb, test_evict_hit_and_miss);
  } else if (!strcmp(testname, "fill")) {
    // Fill tests are slowish, so don't include them with the
    // basic directed tests.
    SIM_INFO("cache single_fill a");
    run_test(tb, test_cache_single_fill_a);
    SIM_INFO("cache single_fill b");
    run_test(tb, test_cache_single_fill_b);
  } else if (!strcmp(testname, "random")) {
    SIM_INFO("random");
    run_test(tb, test_random);
  } else {
    SIM_FATAL("Unknown test name %s", testname);
  }

  Sim::finish();

	return 0;
}
