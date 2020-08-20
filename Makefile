include config.mk

MAS ?= ../compiler/mas
MBC ?= ../compiler/mbc

#### Quartus
-include $(HOME)/.quartus_config.mk
Q ?= quartus_

PROJ=mcpu

QUARTUS_PARAMS=--read_settings_files=off --write_settings_files=off

.PHONY: all
all:
	@echo "Targets:"
	@echo "  fpga: run full synthesis and generate bitstream"
	@echo "  fpga-prog: program the FPGA"
	@echo "  fpga-timing: generating timing report"
	@echo "  TESTS_L0: run basic verilator tests"
	@echo "  TESTS_L{1,2,9}: run slower verilator tests"
	@echo "  CORETESTS: run full core tests"
	@echo "  CORETEST_%: run a single core test (from a .ma file in tests/)"
	@echo "  auto: re-autoizes all RTL"
	@echo "  run_%: run the binary generated from boot/%a.ma"


fpga/output_files/$(PROJ).map.summary: $(RTL_COMMON) $(RTL_FPGA) $(RTL_INC) fpga/bootrom.hex fpga/mcpu.*
	cd fpga && $(Q)map $(PROJ) $(addprefix --source=../,$(RTL_COMMON) $(RTL_FPGA))

fpga/output_files/$(PROJ).fit.summary: fpga/output_files/$(PROJ).map.summary
	cd fpga && $(Q)fit $(QUARTUS_PARAMS) $(PROJ)

fpga/output_files/$(PROJ).sof: fpga/output_files/$(PROJ).fit.summary
	cd fpga && $(Q)asm $(QUARTUS_PARAMS) $(PROJ)
	@echo Created $@

fpga/output_files/$(PROJ).sta.summary: fpga/output_files/$(PROJ).sof
	cd fpga && $(Q)sta $(PROJ)
	@echo Created $@

.PHONY: fpga-prog
fpga-prog: fpga/output_files/$(PROJ).sof
	$(Q)pgm -m JTAG -o p\;$<
.PHONY: fpga-timing
fpga-timing: fpga/output_files/$(PROJ).sta.summary
.PHONY: fpga
fpga: fpga/output_files/$(PROJ).sof

#### Verilator

TEST_BIN_DIR=test_bin

L0_TBS = $(foreach tb,$(TESTPLAN_L0_tests),$(TEST_$(tb)_tb))
L1_TBS = $(foreach tb,$(TESTPLAN_L1_tests),$(TEST_$(tb)_tb))

all_tbs: $(addprefix tb_,$(ALL_TBS))
l0_tbs: $(addprefix tb_,$(L0_TBS))
l1_tbs: $(addprefix tb_,$(L1_TBS))

# First, define the rules to build the testbenches.
define TB_template
$(TEST_BIN_DIR)/TB_$(1)/V$$(TB_$(1)_top): $(RTL_COMMON) $(addprefix sim/,$(TB_$(1)_cpps))
	verilator -CFLAGS $(VER_CFLAGS) -Irtl --Mdir $(TEST_BIN_DIR)/TB_$(1) --cc $$(TB_$(1)_top) $(addprefix sim/,$(TB_$(1)_cpps)) --exe --assert $(if $(TRACE),--trace) $(addprefix +incdir+,$(sort $(dir $(RTL_COMMON)))) +incdir+rtl/tb
	VPATH=../../ TRACE=1 make -C $(TEST_BIN_DIR)/TB_$(1)/ -f V$$(TB_$(1)_top).mk
endef
$(foreach tb,$(ALL_TBS),$(eval $(call TB_template,$(tb))))

define TEST_template
.PHONY: test_$(1)
test_$(1): $(TEST_BIN_DIR)/TB_$(TEST_$(1)_tb)/V$(TB_$(TEST_$(1)_tb)_top)
	$$(TEST_$(1)_env) $(TEST_BIN_DIR)/TB_$(TEST_$(1)_tb)/V$(TB_$(TEST_$(1)_tb)_top)
endef
$(foreach tb,$(ALL_TESTS),$(eval $(call TEST_template,$(tb))))

define TEST_LEVEL_template
.PHONY: TESTS_$(1)
TESTS_$(1): $(foreach tb,$(TESTPLAN_$(1)_tests),test_$(tb))
endef
$(foreach level,$(ALL_TESTPLANS),$(eval $(call TEST_LEVEL_template,$(level))))

#### Core tests
.PHONY: CORETESTS
CORETESTS: $(patsubst tests/%.ma,CORETEST_%,$(wildcard tests/*.ma))

.PHONY: asd
asd:
	echo $(patsubst tests/%.ma,tests/gen/%.vcd,$(wildcard tests/*.ma))

tests/gen/%.bin: tests/%.ma
	@mkdir -p tests/bin
	$(MAS) --fmt bin < $< > $@

tests/gen/%.txt: tests/gen/%.bin sim/cpu_sim/cpu_sim
	sim/cpu_sim/cpu_sim < $< > $@

tests/gen/%.vcd: tests/gen/%.txt tests/gen/%.bin test_bin/bin/coretest
	test_bin/bin/coretest $(patsubst %.vcd,%.bin,$@) $(patsubst %.vcd,%.txt,$@)
# TODO: core_test really should take a commandline option to tell it where
# to put the vcd.
	mv trace.vcd $@ || true

.phony: CORETEST_%
CORETEST_%: tests/gen/%.txt tests/gen/%.bin test_bin/bin/coretest
	test_bin/bin/coretest $(patsubst CORETEST_%,tests/gen/%.bin,$@) --regs $(patsubst CORETEST_%,tests/gen/%.txt,$@)

#### Other
sim/cpu_sim/cpu_sim: sim/cpu_sim/*.h sim/cpu_sim/*.cc
	make -C sim/cpu_sim cpu_sim

fpga/bootrom.hex: $(BOOTROM_ASM)
	$(MAS) --fmt bootrom $< -o $@

test_bin/bin/coretest: $(TEST_BIN_DIR)/TB_core_test/V$(TB_core_test_top)
	cp $< test_bin/bin/coretest

test_bin/boot/%.bin: boot/%.ma
	mkdir -p test_bin/boot
	$(MAS) --fmt bin $< -o $@

.PHONY: run_%
run_%: test_bin/boot/%.bin test_bin/bin/coretest
	test_bin/bin/coretest $<

.PHONY: auto
auto:
	emacs -l utils/nogit.el -l utils/verilog-mode.el --batch $(RTL_COMMON) $(RTL_FPGA) $(RTL_SIM) -f verilog-batch-auto

.PHONY: unauto
unauto:
	emacs -l utils/nogit.el -l utils/verilog-mode.el --batch $(RTL_COMMON) $(RTL_FPGA) $(RTL_SIM) -f verilog-batch-delete-auto
