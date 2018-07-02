#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
#endif
#include "Cmod_MCPU_MEM_arb.h"
#include "VMCPU_MEM_pt_walk.h"

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

class WalkTest {
  VMCPU_MEM_pt_walk *tb;
  Cmod_MCPU_MEM_arb *arb;
  Cmod_MCPU_MEM_arb_ports *arb_ports;

public:
  WalkTest(VMCPU_MEM_pt_walk *tb);
  ~WalkTest();

  void write_w(uint32_t addr, uint32_t val) {
    arb->write_w(addr, val);
  }
  uint32_t read(uint32_t addr) {
    return arb->read(addr);
  }

  void set_base(uint32_t base) {
    tb->pagedir_base = base >> 12;
  }

  void do_lookup(uint32_t addr);

  void set_dir_entry(uint32_t pagedir_base, uint32_t addr, uint32_t page, uint8_t flags);

  void set_tab_entry(uint32_t pagetab_base, uint32_t addr, uint32_t page, uint8_t flags);

  void verify(uint32_t virt, uint32_t phys, uint8_t pd_flags, uint8_t pt_flags);
  void verify_absent(uint32_t virt);
};

WalkTest::WalkTest(VMCPU_MEM_pt_walk *tb)
{
  this->tb = tb;
  arb = new Cmod_MCPU_MEM_arb;
  arb_ports = new Cmod_MCPU_MEM_arb_ports;

  Cmod_MCPU_MEM_arb_CONNECT(arb_ports, tb);

  arb->add_client(arb_ports);

  tb->clk = 0;
  tb->addr = 0;
  tb->re = 0;
  tb->pagedir_base = 0;
  tb->eval();
  arb->clk();
  tb->eval();

  Sim::tick();
  TRACE;
}

WalkTest::~WalkTest() {
  delete tb;
  delete arb;
  delete arb_ports;
}

void WalkTest::do_lookup(uint32_t addr) {
  tb->clk = 1;
  tb->eval();
  tb->re = 1;
  tb->addr = addr;
  tb->eval();
  arb->clk();
  tb->eval();
  Sim::tick();
  TRACE;

  while(1) {
    tb->clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clk = 1;
    tb->eval();
    tb->re = 0;
    arb->clk();
    tb->eval();

    if (tb->ready) { break; }
    Sim::tick();
    TRACE;
  }
}

void WalkTest::set_dir_entry(uint32_t pagedir_base, uint32_t addr, uint32_t page,
                             uint8_t flags) {
  uint32_t pagedir_offs = addr >> 22;
  uint32_t entry_addr = pagedir_base + pagedir_offs * 4;
  uint32_t entry = (page & ~0xfff) | flags;

  write_w(entry_addr, entry);
}

void WalkTest::set_tab_entry(uint32_t pagetab_base, uint32_t addr, uint32_t page,
                             uint8_t flags) {
  uint32_t pagetab_offs = (addr >> 12) & 0x3ff;
  uint32_t entry_addr = pagetab_base + pagetab_offs * 4;
  uint32_t entry = (page & ~0xfff) | flags;

  write_w(entry_addr, entry);
}

void WalkTest::verify(uint32_t virt, uint32_t phys, uint8_t pd_flags, uint8_t pt_flags) {
  do_lookup(virt);
  uint32_t actual_phys = tb->phys_addr;
  if (!tb->present) {
    SIM_FATAL("Address 0x%x is not present", virt);
  }
  if (tb->pagedir_flags != pd_flags) {
    SIM_FATAL("0x%x has pagedir flags 0x%x (expected 0x%x)",
              virt, tb->pagedir_flags, pd_flags);
  }
  if (tb->pagetab_flags != pt_flags) {
    SIM_FATAL("0x%x has pagetab flags 0x%x (expected 0x%x)",
              virt, tb->pagetab_flags, pt_flags);
  }
  if (actual_phys != phys) {
    SIM_FATAL("0x%x translates to 0x%x (expected 0x%x)",
              virt, actual_phys, phys);
  }
}

void WalkTest::verify_absent(uint32_t virt) {
  do_lookup(virt);
  if (tb->present) {
    SIM_FATAL("Expected 0x%x to be missing, but it is present");
  }
}

int main(int argc, char **argv, char **env) {
	Sim::init(argc, argv);

	VMCPU_MEM_pt_walk *tb = new VMCPU_MEM_pt_walk;

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);
#endif

  WalkTest test = WalkTest(tb);
  uint32_t pagedir_base = 0x4000;
  test.set_base(pagedir_base);
  // First page table
  test.set_dir_entry(pagedir_base, 0xdeadbeef, 0x05550000, 0xf);
  // A few entries, with different addresses and flags.
  test.set_tab_entry(0x5550000, 0xdeadbeef, 0x8aaaa000, 0xf);
  test.set_tab_entry(0x5550000, 0xdeadceef, 0x8abcd000, 0xf);
  test.set_tab_entry(0x5550000, 0xdeaddeef, 0x8abcd000, 0xe);
  test.set_tab_entry(0x5550000, 0xdeadeeef, 0x8abcd000, 0x3);

  // An entry that is not present.
  test.set_dir_entry(pagedir_base, 0xeeadbeef, 0x05550000, 0xe);

  // Like the first one, but page directory has different flags.
  test.set_dir_entry(pagedir_base, 0xfeadbeef, 0x05560000, 0x1);
  test.set_tab_entry(0x5560000, 0xfeadbeef, 0x9aaaa000, 0xf);
  test.set_tab_entry(0x5560000, 0xfeadceef, 0x9abcd000, 0xf);
  test.set_tab_entry(0x5560000, 0xfeaddeef, 0x9abcd000, 0xe);
  test.set_tab_entry(0x5560000, 0xfeadeeef, 0x9abcd000, 0x3);

  test.verify(0xdeadbeef, 0x8aaaaeef, 0xf, 0xf);
  test.verify(0xdeadbee0, 0x8aaaaee0, 0xf, 0xf);
  test.verify(0xdeadcee0, 0x8abcdee0, 0xf, 0xf);
  test.verify(0xdeadeee0, 0x8abcdee0, 0xf, 0x3);

  test.verify(0xfeadbeef, 0x9aaaaeef, 0x1, 0xf);
  test.verify(0xfeadbee0, 0x9aaaaee0, 0x1, 0xf);
  test.verify(0xfeadcee0, 0x9abcdee0, 0x1, 0xf);
  test.verify(0xfeadeee0, 0x9abcdee0, 0x1, 0x3);

  // Absent due to page table entry
  test.verify_absent(0xdeaddeef);
  // Absent due to page directory entry
  test.verify_absent(0xeeadbeef);

  // Let a few clock cycles go by before we exit (it's nicer
  // when we're looking at the .vcd file)
  for (int i = 0; i < 16; i++) {
    tb->clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clk = 1;
    tb->eval();
    Sim::tick();
    TRACE;
  }

  Sim::finish();

	return 0;
}