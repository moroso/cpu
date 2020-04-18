#include "Cmod_MCPU_MEM_mc.h"

#include "VMCPU_int_MCPU_MEM_preload__R1000.h"
#include "VMCPU_int_MCPU_mem.h"
#include "VMCPU_int_MCPU_CORE_regfile.h"
#include "VMCPU_int_MCPU_core.h"
#include "VMCPU_int_MCPU_int.h"
#include "VMCPU_int.h"
#include "Sim.h"
#include "verilated.h"

#if VM_TRACE
#include <verilated_vcd_c.h>  
VerilatedVcdC* tfp;

#if VM_TRACE
#define TRACE tfp->dump(Sim::main_time)
#else
#define TRACE
#endif

void _close_trace() {
	if (tfp) tfp->close();
}
#endif

class CoreTest {
public:
  VMCPU_int *tb;
  Cmod_MCPU_MEM_mc *mc;
  Cmod_MCPU_MEM_mc_ports *mc_ports;

  CoreTest() {
    mc_ports = new Cmod_MCPU_MEM_mc_ports();
    tb = new VMCPU_int();

    Cmod_MCPU_MEM_mc_CONNECT(mc_ports, tb);
    mc = new Cmod_MCPU_MEM_mc(mc_ports);
  }

  void clk() {
    tb->clkrst_core_clk = 0;
    tb->clkrst_mem_clk = 0;
    tb->eval();
    Sim::tick();
    TRACE;

    tb->clkrst_core_clk = 1;
    tb->clkrst_mem_clk = 1;
    tb->eval();
    mc->clk();
    tb->eval();
    Sim::tick();
    TRACE;
  }
};

void run_test(CoreTest *t, char *romfile, char *regsfile) {
  t->tb->clkrst_core_rst_n = 1;
  t->tb->clkrst_mem_rst_n = 1;

  t->clk();

  t->tb->clkrst_core_rst_n = 0;
  t->tb->clkrst_mem_rst_n = 0;

  FILE *romf = fopen(romfile, "r");
  int pos = 0;
  while (!feof(romf)) {
    // TODO: check overflow and all that.
    fread(t->tb->MCPU_int->mem->preload_inst->rom[pos], 4, 8, romf);
    pos += 1;
  }

  fclose(romf);

  t->clk();

  t->tb->clkrst_core_rst_n = 1;
  t->tb->clkrst_mem_rst_n = 1;

  t->clk();

  uint32_t pc = 0xffffffe;
  for (int i = 0; i < 100000; i++) {
    t->clk();

    int break_signal = t->tb->MCPU_int->core->pc_break;
    int valid = t->tb->MCPU_int->core->pc_valid_in;
    if (break_signal && valid) {
      pc = t->tb->MCPU_int->core->d2pc_in_virtpc;
      t->tb->MCPU_int->core->pipe_flush = 1;
      t->tb->eval();

      // TODO: we could be more careful about this, but 100 cycles should
      // be enough to finish anything we were doing.
      for (int j = 0; j < 100; j++) {
        // Hacky way to keep us from executing anything new at this point.
        t->tb->MCPU_int->core->pipe_flush = 1;
        t->clk();
      }
      break;
    }
  }

  FILE *regsf = fopen(regsfile, "r");
  uint32_t expected_pc;

  while(fgetc(regsf) != '\n');

  fscanf(regsf, "pc 0x%x r {", &expected_pc);

  SIM_ASSERT_MSG((pc + 1) << 4 == expected_pc,
                 "PC mismatch: 0x%x != 0x%x",
                 (pc + 1) << 4, expected_pc);

  for (int i = 0; i < 32; i++) {
    uint32_t regval;
    fscanf(regsf, "%x ", &regval);
    SIM_ASSERT_MSG(t->tb->MCPU_int->core->regs->mem[i] == regval,
                   "Mismatch in r%d: 0x%x != 0x%x",
                   i, t->tb->MCPU_int->core->regs->mem[i], regval);
  }

  fscanf(regsf, "} p { ");
  uint32_t expected_preds = 0;
  for (int i = 0; i < 3; i++) {
    uint32_t p;
    fscanf(regsf, "%d ", &p);
    expected_preds |= (p << i);
  }

  SIM_ASSERT_MSG(expected_preds == t->tb->MCPU_int->core->regs->preds,
                 "preds mismatch: 0x%x != 0x%x",
                 t->tb->MCPU_int->core->regs->preds, expected_preds);
  fclose(regsf);
}

int main(int argc, char **argv, char **env) {
	Sim::init(argc, argv);

  CoreTest *t = new CoreTest();

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  t->tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);
#endif

  SIM_INFO("Testing");

  run_test(t, argv[1], argv[2]);

  SIM_INFO("Done");
}
