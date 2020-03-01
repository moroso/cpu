// TODO: rewrite this in terms of stim/check classes.

#include <stdlib.h>

#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
#endif
#include "Cmod_MCPU_MEM_arb.h"
#include "VMCPU_MEM_pt_walk.h"

// (Loose) upper bound on cycle count any operation should take.
#define DEADLINE 128
// Mask for the present bit among the flags for an entry.
#define BIT_PRESENT 1

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
    tb->tlb2ptw_pagedir_base = base >> 12;
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

  Cmod_MCPU_MEM_arb_CONNECT(arb_ports, tb, ptw);

  arb->add_client(arb_ports);

  arb->latch();
  tb->tlb2ptw_clk = 0;
  tb->tlb2ptw_addr = 0;
  tb->tlb2ptw_re = 0;
  tb->tlb2ptw_pagedir_base = 0;
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
  int cycles = 0;

  arb->latch();
  tb->tlb2ptw_clk = 1;
  tb->eval();
  tb->tlb2ptw_re = 1;
  tb->tlb2ptw_addr = addr;
  tb->eval();
  arb->clk();
  tb->eval();
  Sim::tick();
  TRACE;

  while (cycles++ < DEADLINE) {
    tb->tlb2ptw_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;

    arb->latch();
    tb->tlb2ptw_clk = 1;
    tb->tlb2ptw_re = 0;
    tb->eval();
    arb->clk();
    tb->eval();

    if (cycles > 2 && tb->tlb2ptw_ready) { return; }
    Sim::tick();
    TRACE;
  }

  // If we get here, we hit the deadline.
  SIM_FATAL("Hit deadline when looking up 0x%x", addr);
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
  uint32_t actual_phys = tb->tlb2ptw_phys_addr;
  if (!((tb->tlb2ptw_pagetab_flags & BIT_PRESENT) &&
        (tb->tlb2ptw_pagedir_flags & BIT_PRESENT))) {
    SIM_FATAL("Address 0x%x is not present", virt);
  }
  if (tb->tlb2ptw_pagedir_flags != pd_flags) {
    SIM_FATAL("0x%x has pagedir flags 0x%x (expected 0x%x)",
              virt, tb->tlb2ptw_pagedir_flags, pd_flags);
  }
  if (tb->tlb2ptw_pagetab_flags != pt_flags) {
    SIM_FATAL("0x%x has pagetab flags 0x%x (expected 0x%x)",
              virt, tb->tlb2ptw_pagetab_flags, pt_flags);
  }
  if (actual_phys != phys) {
    SIM_FATAL("0x%x translates to 0x%x (expected 0x%x)",
              virt, actual_phys, phys);
  }
}

void WalkTest::verify_absent(uint32_t virt) {
  do_lookup(virt);
  if ((tb->tlb2ptw_pagetab_flags & BIT_PRESENT) &&
      (tb->tlb2ptw_pagedir_flags & BIT_PRESENT)) {
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

  test.verify(0xdeadb, 0x8aaaa, 0xf, 0xf);
  test.verify(0xdeadc, 0x8abcd, 0xf, 0xf);
  test.verify(0xdeade, 0x8abcd, 0xf, 0x3);

  test.verify(0xfeadb, 0x9aaaa, 0x1, 0xf);
  test.verify(0xfeadc, 0x9abcd, 0x1, 0xf);
  test.verify(0xfeade, 0x9abcd, 0x1, 0x3);

  // Absent due to page table entry
  test.verify_absent(0xdeadd);
  // Absent due to page directory entry
  test.verify_absent(0xeeadb);

  // Let a few clock cycles go by before we exit (it's nicer
  // when we're looking at the .vcd file)
  for (int i = 0; i < 16; i++) {
    tb->tlb2ptw_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;

    tb->tlb2ptw_clk = 1;
    tb->eval();
    Sim::tick();
    TRACE;
  }

  Sim::finish();

	return 0;
}
