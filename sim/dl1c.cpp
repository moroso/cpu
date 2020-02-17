#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
#endif
#include "Cmod_MCPU_MEM_arb.h"
#include "MCPU_MEM_dl1c_ports.h"
#include "Stim_MCPU_MEM_dl1c.h"
#include "Check_MCPU_MEM_dl1c.h"

#include "VMCPU_MEM_dl1c.h"

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

#define ADDR_OF(tag, set) ((((tag)<<SET_SIZE)|(set))<<2)

#if VM_TRACE
void _close_trace() {
	if (tfp) tfp->close();
}
#endif

class Dl1cTest {
  Cmod_MCPU_MEM_arb_ports *arb_ports;
  MCPU_MEM_dl1c_ports *dl1c_ports;
	VMCPU_MEM_dl1c *tb;

  Check_MCPU_MEM_dl1c *check;
  Cmod_MCPU_MEM_arb *arb;
  Stim_MCPU_MEM_dl1c *stim;

public:
  Dl1cTest(VMCPU_MEM_dl1c *tb);
  ~Dl1cTest();

  void latch() {
    arb->latch();
  }

  void clk() {
    tb->eval();
    stim->clk();
    arb->clk();
    tb->eval();
    check->clk();
    tb->eval();
  }

  void cycle() {
    latch();
    tb->clk = 1;
    clk();
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;
  }

  void reset() {
    tb->dl1c_reset = 1;
    for (int i = 0; i < 2; i++) {
      tb->clk = 1;
      tb->eval();
      Sim::tick();
      TRACE;

      tb->clk = 0;
      tb->eval();
      Sim::tick();
      TRACE;
    }

    tb->dl1c_reset = 0;

    for (int i = 0; i < 2; i++) {
      tb->clk = 1;
      tb->eval();
      Sim::tick();
      TRACE;

      tb->clk = 0;
      tb->eval();
      Sim::tick();
      TRACE;
    }
  }

  bool done() {
    return stim->done();
  }

  void perform(Dl1c_Op op0, Dl1c_Op op1) {
    stim->perform(op0, op1);
  }
/*
  void read_nowait(uint32_t addr) {
    stim->read_nowait(addr);
  }
*/
  void pause() {
    //stim->pause();
  }

  void mem_write(uint32_t addr, uint32_t val) {
    arb->write_w(addr, val);
  }
};

Dl1cTest::Dl1cTest(VMCPU_MEM_dl1c *tb) : tb(tb) {
  arb_ports = new Cmod_MCPU_MEM_arb_ports;
  Cmod_MCPU_MEM_arb_CONNECT(arb_ports, tb, dl1c);
  arb = new Cmod_MCPU_MEM_arb();
  arb->add_client(arb_ports);

  dl1c_ports = new MCPU_MEM_dl1c_ports;
  MCPU_MEM_dl1c_CONNECT(dl1c_ports, tb);
  stim = new Stim_MCPU_MEM_dl1c(dl1c_ports);

  check = new Check_MCPU_MEM_dl1c(dl1c_ports);
}

Dl1cTest::~Dl1cTest() {
  delete check;
  delete stim;
  delete arb;
  delete arb_ports;
}

void test_basic(Dl1cTest &test) {
  for (int i = 0; i < 0x1000; i++) {
    test.mem_write(i * 4, i | 0xcc0000);
  }

  test.perform(Op_Read(0x100), Op_Read(0x110));
}

void test_directed(Dl1cTest &test) {
  for (int i = 0; i < 0x10000; i++) {
    test.mem_write(i * 4, i | 0xcc0000);
  }

  // Various reads, from the same line
  test.perform(Op_Read(0x104), Op_Read(0x104));
  test.perform(Op_Read(0x108), Op_Read(0x10c));
  test.perform(Op_Read(0x10c), Op_Read(0x100));

  // Write + read
  test.perform(Op_Write(0x20c, 0x00dd083), Op_Read(0x100));
  test.perform(Op_Read(0x20c), Op_Read(0x100));

  // Two writes
  test.perform(Op_Write(0x30c, 0x00dd0c3), Op_Write(0x308, 0x00dd0c2));
  test.perform(Op_Read(0x308), Op_Read(0x30c));
  test.perform(Op_Read(0x300), Op_Read(0x304));
  test.perform(Op_Read(0x30c), Op_Read(0x308));

  // Test of eviction
  test.perform(Op_Read(0x300c), Op_Read(0x3008));
  test.perform(Op_Read(0x400c), Op_Read(0x4008));
  test.perform(Op_Read(0x500c), Op_Read(0x5008));
  test.perform(Op_Read(0x400c), Op_Read(0x4008));
  test.perform(Op_Read(0x300c), Op_Read(0x3008));
  test.perform(Op_Read(0x500c), Op_Read(0x5008));

  // Write, and read on the same line
  test.perform(Op_Write(0x28c, 0x00dd087), Op_Read(0x288));
  test.perform(Op_Read(0x288), Op_Read(0x28c));

  // Byte writes
  test.perform(Op_Write_Mask(0x38c, 0x00dd0e3, 0x1), Op_Noop());
  test.perform(Op_Write_Mask(0x38c, 0x00dd0e3, 0x2), Op_Noop());
  test.perform(Op_Write_Mask(0x38c, 0x00dd0e3, 0x4), Op_Noop());

  test.perform(Op_Read(0x38c), Op_Noop());

  test.perform(Op_Write_Mask(0x48c, 0x00dd123, 0x1),
               Op_Write_Mask(0x48c, 0x00dd123, 0x2));
  test.perform(Op_Read(0x48c), Op_Read(0x488));
}

void run_test(VMCPU_MEM_dl1c *tb, void (*testfunc)(Dl1cTest &test)) {
  Dl1cTest test(tb);

  testfunc(test);

  test.reset();

  while (!test.done()) {
    test.cycle();
  }

  for (int i = 0; i < 16; i++) {
    test.cycle();
  }
}

int main(int argc, char **argv, char **env) {
  Sim::init(argc, argv);

  VMCPU_MEM_dl1c *tb = new VMCPU_MEM_dl1c();

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);
#endif

  SIM_INFO("basic");

  run_test(tb, test_basic);
  run_test(tb, test_directed);

  Sim::finish();

  return 0;
}
