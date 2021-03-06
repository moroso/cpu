#include "Cmod_MCPU_MEM_mc.h"

#include "VMCPU_int_MCPU_MEM_preload__R1000.h"
#include "VMCPU_int_MCPU_mem.h"
#include "VMCPU_int_MCPU_CORE_regfile.h"
#include "VMCPU_int_MCPU_core.h"
#include "VMCPU_int_MCPU_int.h"
#include "VMCPU_int.h"
#include "Sim.h"
#include "verilated.h"

#include <verilated_vcd_c.h>
VerilatedVcdC* tfp;
void _close_trace() {
	if (tfp) tfp->close();
}

#define TRACE tfp->dump(Sim::main_time)

class CoreTest {
public:
  VMCPU_int *tb;
  Cmod_MCPU_MEM_mc *mc;
  Cmod_MCPU_MEM_mc_ports *mc_ports;
  uint32_t counter;

  CoreTest() {
    mc_ports = new Cmod_MCPU_MEM_mc_ports();
    tb = new VMCPU_int();

    Cmod_MCPU_MEM_mc_CONNECT(mc_ports, tb);
    mc = new Cmod_MCPU_MEM_mc(mc_ports);
  }

  void clk_(bool trace) {
    uint32_t t = Sim::main_time;
    if ((t % 8) == 0)
      tb->clkrst_audio_clk = 0;
    if ((t % 8) == 4)
      tb->clkrst_audio_clk = 1;
    tb->clkrst_core_clk = 0;
    tb->clkrst_mem_clk = 0;
    tb->eval();
    Sim::tick();
    if (trace) {
      TRACE;
    }

    tb->clkrst_core_clk = 1;
    tb->clkrst_mem_clk = 1;
    tb->eval();
    mc->clk();
    tb->eval();
    Sim::tick();
    if (trace) {
      TRACE;
    }
  }

  void clk() {
    clk_(true);
  }

  void clk_notrace() {
    clk_(false);
  }

  void uart_send(uint8_t b, bool trace) {
    uint16_t ext_b = (((uint16_t)b) << 1) | 0x200;

    for (int bit_idx = 0; bit_idx < 10; bit_idx++) {
      uint8_t bit = !!(ext_b & (1 << bit_idx));
      for (int j = 0; j < 50000000 / 115200; j++) {
        tb->ext_uart_rx = bit;
        clk_(trace);
      }
    }
  }
};

void run_test(CoreTest *t, char *romfile, char *regsfile, char *bootfile, int skip_cycles) {
  t->tb->clkrst_core_rst_n = 1;
  t->tb->clkrst_mem_rst_n = 1;

  t->clk();

  t->tb->clkrst_core_rst_n = 0;
  t->tb->clkrst_mem_rst_n = 0;

  FILE *romf = fopen(romfile, "r");
  if (!romf) {
    SIM_FATAL("Cannot find ROM file");
  }

  uint32_t pos = 0;
  while (!feof(romf)) {
    uint8_t buf[16];
    if (fread(buf, 16, 1, romf) == 0) {
      break;
    }
    for (int i = 0; i < 16; i++) {
      t->mc->set(pos * 16 + i, buf[i]);
    }
    pos += 1;
  }

  fclose(romf);

  SIM_INFO("Loaded rom.");

  t->clk();

  t->tb->MCPU_int->mem->preload_inst->loading = 0; // Disable the preloader.
  t->tb->clkrst_core_rst_n = 1;
  t->tb->clkrst_mem_rst_n = 1;

  t->clk();

  if (bootfile) {
    t->tb->ext_uart_rx = 1;

    SIM_INFO("Waiting for bootloader");
    // Give the bootloader some time to initialize and send the MBOOT string.
    for (int i = 0; i < 40000; i++) {
      t->clk();
    }
    SIM_INFO("Starting program load");
    FILE *bootf = fopen(bootfile, "r");
    fseek(bootf, 0, SEEK_END);
    uint32_t size = ftell(bootf);
    rewind(bootf);

    t->uart_send(size/16, true);
    for (int i = 0; i < 40; i++) {
      t->clk();
    }
    //t->uart_send(0xaa, true);

    char packet[16];
    while (fread(&packet, 16, 1, bootf) > 0) {
      SIM_INFO("Loading packet");
      for (int i = 0; i < 16; i++) {
        t->uart_send(packet[i], false);
      }
    }
  }
  SIM_INFO("Loaded!");

  uint32_t pc = 0xffffffe;
  for (int i = 0; i < 1000000 + skip_cycles; i++) {
    if ((i % 1000000) == 0) {
      SIM_INFO("%d cycles elapsed\n", i);
    }
    if (i < skip_cycles) {
      t->clk_notrace();
    } else {
      t->clk();
    }

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

  if (!regsfile || strlen(regsfile) <= 1) return;

  FILE *regsf = fopen(regsfile, "r");
  uint32_t expected_pc;

  while(fgetc(regsf) != '\n');

  fscanf(regsf, "pc 0x%x r {", &expected_pc);

  SIM_ASSERT_MSG((pc + 1) << 4 == expected_pc,
                 "PC mismatch: actual 0x%x != expected 0x%x",
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
  // Rather than trying to remember the seed or anything, we'll just set it to zero.
  srandom(0);

  int skip_cycles = 0;
  char *regs_file = NULL;
  char *boot_file = NULL;
  for (int i = 2; i < argc; i += 1) {
    if (strcmp(argv[i], "--skip_cycles") == 0) {
      skip_cycles = atoi(argv[i+1]);
      i += 1;
    } else if (strcmp(argv[i], "--regs") == 0) {
      regs_file = argv[i+1];
      i += 1;
    } else if (strcmp(argv[i], "--boot") == 0) {
      boot_file = argv[i+1];
      i += 1;
    } else {
      SIM_FATAL("Unknown option %s", argv[i]);
    }
  }
  SIM_INFO("Skipping logging on first %d cycles\n", skip_cycles);

  CoreTest *t = new CoreTest();

  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  t->tb->trace(tfp, 99);
  tfp->open("trace.vcd");
  atexit(_close_trace);

  SIM_INFO("Testing");

  run_test(t, argv[1], regs_file, boot_file, skip_cycles);

  SIM_INFO("Done");
}
