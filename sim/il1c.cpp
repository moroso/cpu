#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
#endif
#include "Cmod_MCPU_MEM_arb.h"
#include "Cmod_MCPU_MEM_dtlb.h"
#include "MCPU_MEM_il1c_ports.h"
#include "Stim_MCPU_MEM_il1c.h"
#include "Check_MCPU_MEM_il1c.h"

#include "VMCPU_MEM_il1c.h"

// (Loose) upper bound on cycle count any operation should take.
#define DEADLINE 128

#define TAG_SIZE 23
#define SET_SIZE 4

#define NUM_SETS (1<<SET_SIZE)

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

class Il1cTest {
  Cmod_MCPU_MEM_dtlb_ports *dtlb_ports;
  Cmod_MCPU_MEM_dtlb *dtlb;
  Cmod_MCPU_MEM_arb_ports *arb_ports;
  MCPU_MEM_il1c_ports *il1c_ports;
	VMCPU_MEM_il1c *tb;

  Check_MCPU_MEM_il1c *check;
  Cmod_MCPU_MEM_arb *arb;
  Stim_MCPU_MEM_il1c *stim;

public:
  Il1cTest(VMCPU_MEM_il1c *tb);
  ~Il1cTest();

  void latch() {
    arb->latch();
    dtlb->latch();
  }

  void clk() {
    tb->eval();
    stim->clk();
    tb->eval();
    dtlb->clk();
    arb->clk();
    tb->eval();
    check->clk();
  }

  bool done() {
    return stim->done() && check->done();
  }

  void read(uint32_t addr) {
    stim->read(addr);
  }

  void read_nowait(uint32_t addr) {
    stim->read_nowait(addr);
  }

  void pause() {
    stim->pause();
  }

  void set_addr(uint32_t virt, uint32_t phys, uint8_t flags) {
    dtlb->add_mapping(virt, phys, flags);
  }

  void write(uint32_t addr, uint32_t val) {
    arb->write_w(addr, val);
  }
};

Il1cTest::Il1cTest(VMCPU_MEM_il1c *tb) : tb(tb) {
  dtlb_ports = new Cmod_MCPU_MEM_dtlb_ports;
  Cmod_MCPU_MEM_dtlb_CONNECT_SINGLE(dtlb_ports, tb, il1c2tlb_);
  dtlb = new Cmod_MCPU_MEM_dtlb(dtlb_ports);

  arb_ports = new Cmod_MCPU_MEM_arb_ports;
  Cmod_MCPU_MEM_arb_CONNECT(arb_ports, tb, il1c);
  arb = new Cmod_MCPU_MEM_arb();
  arb->add_client(arb_ports);

  il1c_ports = new MCPU_MEM_il1c_ports;
  MCPU_MEM_il1c_CONNECT(il1c_ports, tb);
  stim = new Stim_MCPU_MEM_il1c(il1c_ports);

  check = new Check_MCPU_MEM_il1c(il1c_ports);
}

Il1cTest::~Il1cTest() {
  delete check;
  delete stim;
  delete arb;
  delete arb_ports;
  delete dtlb;
  delete dtlb_ports;
}

void run_test(VMCPU_MEM_il1c *tb, void (*testfunc)(Il1cTest &test)) {
  // Clear cache state, in case we're running multiple tests.
  // TODO: the cache needs a reset signal.
  tb->MCPU_MEM_il1c__DOT__valid = 0;

  Il1cTest test(tb);

  testfunc(test);
  while (!test.done()) {
    test.latch();
    tb->clk = 1;
    test.clk();
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;
  }

  // Wait a few cycles before starting the next test.
  for (int i = 0; i < 16; i++) {
    test.latch();
    tb->clk = 1;
    test.clk();
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;
  }
}

void test_basic(Il1cTest &test) {
  test.set_addr(0, 1, 0xf);
  test.write(0x1000, 0xdeadbeef);
  test.write(0x1010, 0x11111111);
  test.write(0x1020, 0x22222222);
  test.write(0x1030, 0x33333333);

  test.read(0x00);
  test.read(0x10);
  test.read(0x00);
  test.read(0x10);

  test.read(0x20);
  test.read(0x30);
  test.read(0x00);
  test.read(0x10);
  test.read(0x20);
  test.read(0x30);
}

void test_evict(Il1cTest &test) {
  test.set_addr(0, 1, 0xf);
  test.write(0x1000, 0xdeadbeef);
  test.write(0x1200, 0x11111111);

  test.read(0x00);
  test.read(0x20);
  test.read(0x20);
  test.read(0x00);
  test.read(0x00);
  test.read_nowait(0x20);
  test.read(0x20);
}

void test_fill(Il1cTest &test) {
  test.set_addr(0, 1, 0xf);
  for (int i = 0; i < 2 * NUM_SETS; i += 1) {
    test.write(i * 16 + 0x1000, i);
  }

  for (int i = 0; i < NUM_SETS * 2; i += 1) {
    // Note: each set will be accessed *twice*, at a different offset.
    test.read(i * 16);
  }

  for (int i = 0; i < NUM_SETS * 2; i += 1) {
    test.read(i * 16);
  }
}

void test_multi_page_basic(Il1cTest &test) {
  test.set_addr(0, 7, 0xf);
  test.set_addr(1, 3, 0xf);

  for (int i = 0; i < 1024; i += 1) {
    // The values in memory don't matter; fill them randomly.
    test.write(0x7000 + i * 4, Sim::random(-1));
    test.write(0x3000 + i * 4, Sim::random(-1));
  }

  for (int i = 0; i < NUM_SETS * 2; i += 1) {
    // Note: each set will be accessed *twice*, at a different offset.
    test.read(i * 16);
  }

  for (int i = 0; i < NUM_SETS * 2; i += 1) {
    test.read(0x1000 + i * 16);
  }

  for (int i = 0; i < NUM_SETS * 2; i += 1) {
    test.read(0x1000 + i * 16);
  }

  for (int i = 0; i < NUM_SETS * 2; i += 1) {
    // Note: each set will be accessed *twice*, at a different offset.
    test.read(i * 16);
  }
}

void test_two_page_random(Il1cTest &test) {
  // Random test restricted to two pages, to increase the collision rate
  // but still test different lookups to the tlb.
  int nrandoms = Sim::param_u64("IL1C_RANDOM_OPERATIONS", RANDOM_OPS_DEFAULT);

  test.set_addr(0, 7, 0xf);
  test.set_addr(1, 3, 0xf);

  for (int i = 0; i < 1024; i += 1) {
    // The values in memory don't matter; fill them randomly.
    test.write(0x7000 + i * 4, Sim::random(-1));
    test.write(0x3000 + i * 4, Sim::random(-1));
  }
  for (int i = 0; i < nrandoms; i += 1) {
    int page = Sim::random(2);
    int offs = Sim::random(1024);

    test.read(page * 0x1000 + offs * 4);
  }
}

void test_unconstrained_random(Il1cTest &test) {
  int nrandoms = Sim::param_u64("IL1C_RANDOM_OPERATIONS", RANDOM_OPS_DEFAULT);

  #define PAGES (Cmod_MCPU_MEM_arb_MEMSZ / 4096)

  // "reverse" flat-map the entire memory space.
  for (int i = 0; i < PAGES; i++) {
    test.set_addr(i, PAGES - 1 - i, 0xf);
  }

  for (int i = 0; i < nrandoms; i += 1) {
    int addr = Sim::random(Cmod_MCPU_MEM_arb_MEMSZ) & ~0xf;

    // Write some values (depending only on the memory locations,
    // so they won't change) to the memory area we're reading.
    int addr1 = ((PAGES - 1 - (addr >> 12)) << 12) | (addr & 0xfe0);
    int addr2 = addr1 + 0x10;

    test.write(addr1, addr1);
    test.write(addr2, addr2);
    test.read(addr);
  }
}

int main(int argc, char **argv, char **env) {
	Sim::init(argc, argv);

	VMCPU_MEM_il1c *tb = new VMCPU_MEM_il1c();

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);
#endif

	const char *testname;
	testname = Sim::param_str("IL1C_TEST_NAME", "directed");

  if (!strcmp(testname, "directed")) {
    SIM_INFO("basic");
    run_test(tb, test_basic);
    SIM_INFO("evict");
    run_test(tb, test_evict);
    SIM_INFO("full");
    run_test(tb, test_fill);
    SIM_INFO("multi_page");
    run_test(tb, test_multi_page_basic);
  } else if (!strcmp(testname, "random")) {
    SIM_INFO("two_page_random");
    run_test(tb, test_two_page_random);

    SIM_INFO("unconstrained_random");
    run_test(tb, test_unconstrained_random);
  } else {
    SIM_FATAL("Unknown test name %s", testname);
  }

  Sim::finish();

	return 0;
}
