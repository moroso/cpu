RUNTIME := $(shell date +R%Y%m%d-%H%M%S)
RUN ?= $(RUNTIME)
RUNDIR ?= runs/$(RUN)
TESTPLANS ?= L0 L1 L9

include config.mk
-include $(HOME)/.quartus_config.mk
Q ?= quartus_

default:
	@echo "targets:"
#	@echo "  sw            builds software (must be run before fpga to build boot0)"
	@echo "  fpga          runs a complete pass through the tool flow"
	@echo "  sim           produces a Verilator binary"
	@echo "  tests         runs tests"
	@echo "  sanity        runs sanity-only tests"
	@echo "  auto          re-autoizes all RTL"
	@echo ""
	@echo "expert targets:"
	@echo "  tb_...        builds one testbench"
	@echo "  test_...      runs one test"
	@echo ""
	@echo "variables:"
	@echo "  RUN=[...]     name of run (for runs/ directory; defaults to date+time)"
	@echo "  STA=1         run static timing analysis"
	@echo "  PROG=1        download FPGA bitfile to board after compilation"
	@echo "  SVF=1         build SVF for distribution"
	@echo "  TESTPLANS=... testplans to run (for tests) (default: L0)"
	@echo "  TESTS=...     tests tor run (for tests)"
	@echo ""
	@echo "testplans available:"
	@$(foreach testplan,$(ALL_TESTPLANS),echo "  $(testplan): $(TESTPLAN_$(testplan)_name) (tests:$(TESTPLAN_$(testplan)_tests)) ";)
	@echo ""
	@echo "error: you must specify a valid target"
	@exit 1
.PHONY: default

#sw: .DUMMY
#	@make -C sw

###############################################################################

GREEN=\033[32;01m
RED=\033[31;01m
STOP=\033[0m

say = @echo -e "${GREEN}"$(1)"${STOP}"
err = @echo -e "${RED}"$(1)"${STOP}"

###############################################################################

.PHONY: symlinks
symlinks: $(RUNDIR)/stamps/symlinks

$(RUNDIR)/stamps/symlinks:
	$(call say,Creating run symlinks)
	@mkdir -p runs
	if [ -h runs/run_0a ] ; then rm runs/run_1a; mv runs/run_0a runs/run_1a ; fi
	ln -s $(RUN) runs/run_0a
	@mkdir -p $(RUNDIR)/stamps
	@touch $(RUNDIR)/stamps/symlinks

.PHONY: sim-symlinks
sim-symlinks: $(RUNDIR)/stamps/sim-symlinks

$(RUNDIR)/stamps/sim-symlinks:  $(RUNDIR)/stamps/symlinks
	if [ -h runs/sim_0a ] ; then rm runs/sim_1a; mv runs/sim_0a runs/sim_1a ; fi
	ln -s $(RUN) runs/sim_0a
	@touch $(RUNDIR)/stamps/sim-symlinks

.PHONY: sim-genrtl
sim-genrtl: $(RUNDIR)/stamps/sim-genrtl

$(RUNDIR)/stamps/sim-genrtl: sim-symlinks
	$(call say,Copying RTL for simulation to $(RUNDIR)/sim/rtl...)
	@mkdir -p $(RUNDIR)/stamps
	@mkdir -p $(RUNDIR)/sim/rtl
	@cp $(RTL_COMMON) $(RTL_SIM) $(RTL_INC) $(RUNDIR)/sim/rtl
	$(call say,Copying testbench for simulation to $(RUNDIR)/sim...)
	@cp sim/* $(RUNDIR)/sim
	@touch $(RUNDIR)/stamps/sim-genrtl

# Here comes all the testplan mess.

# First, define the rules to build the testbenches.
define TB_template
$(RUNDIR)/sim/$(1)/V$$($(1)_top): $(RUNDIR)/stamps/sim-genrtl
	$(call say,"Verilating testbench: $(1)")
	cd $(RUNDIR)/sim; verilator -Irtl --Mdir $(1) --cc $$(TB_$(1)_top) $$(TB_$(1)_cpps) --exe --assert
	$(call say,"Compiling testbench: $(1)")
	make -C $(RUNDIR)/sim/$(1) -f V$$(TB_$(1)_top).mk

.PHONY: tb_$(1)
tb_$(1): $(RUNDIR)/sim/$(1)/V$$($(1)_top)
endef
$(foreach tb,$(ALL_TBS),$(eval $(call TB_template,$(tb))))

TB_binary = $(RUNDIR)/sim/$(1)/V$(TB_$(1)_top)

# Then, the rules to run tests.
define TEST_template
$(RUNDIR)/testlog/$(1): tb_$$(TEST_$(1)_tb)
	$(call say,"Running test: $(1)")
	@mkdir -p $(RUNDIR)/testlog
	$$(TEST_$(1)_env) $$(call TB_binary,$$(TEST_$(1)_tb)) > $$@

.PHONY: test_$(1)
test_$(1): $(RUNDIR)/testlog/$(1)
endef

$(foreach test,$(ALL_TESTS),$(eval $(call TEST_template,$(test))))

# Finally, run the tests as requested.
TESTS += $(foreach testplan,$(TESTPLANS),$(TESTPLAN_$(testplan)_tests))
tests: $(foreach test,$(TESTS),$(RUNDIR)/testlog/$(test))

sanity:
	make tests TESTPLANS=L0

.PHONY: sim
sim:
	$(call err,"There is no simulator right now: maybe you want to 'make tests'?")

###############################################################################

QPARAMS = $(FPGA_TOOL_BITS) --read_settings_files=off --write_settings_files=off $(FPGA_PROJ)

.PHONY: fpga-symlinks
fpga-symlinks: $(RUNDIR)/stamps/fpga-symlinks

$(RUNDIR)/stamps/fpga-symlinks:  $(RUNDIR)/stamps/symlinks
	if [ -h runs/fpga_0a ] ; then rm runs/fpga_1a; mv runs/fpga_0a runs/fpga_1a ; fi
	ln -s $(RUN) runs/fpga_0a
	@touch $(RUNDIR)/stamps/fpga-symlinks

# XXX: should we generate the .xst file?
.PHONY: fpga-genrtl
fpga-genrtl: $(RUNDIR)/stamps/fpga-genrtl

$(RUNDIR)/stamps/fpga-genrtl: $(RUNDIR)/stamps/fpga-symlinks
	$(call say,"Copying RTL for synthesis to $(RUNDIR)/fpga/rtl...")
	@mkdir -p $(RUNDIR)/stamps
	@mkdir -p $(RUNDIR)/fpga/rtl
	@cp $(RTL_COMMON) $(RTL_FPGA) $(RTL_INC) $(RUNDIR)/fpga/rtl
	$(call say,"Copying FPGA configuration to $(RUNDIR)/fpga...")
	@cp fpga/* $(RUNDIR)/fpga
	@touch $(RUNDIR)/stamps/fpga-genrtl

.PHONY: fpga-map
fpga-map: $(RUNDIR)/stamps/fpga-map

$(RUNDIR)/stamps/fpga-map: $(RUNDIR)/stamps/fpga-genrtl
	$(call say,"Running mapper in $(RUNDIR)/fpga...")
	@touch $(RUNDIR)/stamps/fpga-map-start
	cd $(RUNDIR)/fpga; $(Q)map $(FPGA_TOOL_BITS) --read_settings_files=on --write_settings_files=on $(FPGA_PROJ) $(addprefix --source=rtl/,$(notdir $(RTL_COMMON) $(RTL_FPGA)))
	@touch $(RUNDIR)/stamps/fpga-map

.PHONY: fpga-fit
fpga-fit: $(RUNDIR)/stamps/fpga-fit

$(RUNDIR)/stamps/fpga-fit: $(RUNDIR)/stamps/fpga-map
	$(call say,"Running fitter in $(RUNDIR)/fpga...")
	@touch $(RUNDIR)/stamps/fpga-fit-start
	cd $(RUNDIR)/fpga; $(Q)fit $(QPARAMS)
	@touch $(RUNDIR)/stamps/fpga-fit

.PHONY: fpga-asm
fpga-asm: $(RUNDIR)/stamps/fpga-asm

$(RUNDIR)/stamps/fpga-asm: $(RUNDIR)/stamps/fpga-fit
	$(call say,"Running assembler in $(RUNDIR)/fpga...")
	@touch $(RUNDIR)/stamps/fpga-asm-start
	cd $(RUNDIR)/fpga; $(Q)asm $(QPARAMS)
	@touch $(RUNDIR)/stamps/fpga-asm
	@echo -en "\n\n\n"
	$(call say,"Bit file generated: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof")
	@echo -en "\n\n\n"

.PHONY: fpga-sta
fpga-sta: $(RUNDIR)/stamps/fpga-sta

$(RUNDIR)/stamps/fpga-sta: $(RUNDIR)/stamps/fpga-fit
	$(call say,"Running STA in $(RUNDIR)/fpga...")
	@touch $(RUNDIR)/stamps/fpga-sta-start
	cd $(RUNDIR)/fpga; $(Q)sta $(FPGA_PROJ)
	@touch $(RUNDIR)/stamps/fpga-sta

$(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof: $(RUNDIR)/stamps/fpga-asm

.PHONY: fpga-svf
fpga-svf: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).svf

$(RUNDIR)/fpga/output_files/$(FPGA_PROJ).svf: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof
	$(Q)cpf -c -q 33MHz -g 3.3 -n p $< $@

.PHONY: fpga-prog
fpga-prog: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof
	$(Q)pgm -m JTAG -o p\;$<

.PHONY: fpga
fpga: $(RUNDIR)/stamps/fpga

$(RUNDIR)/stamps/fpga: fpga-asm $(if $(STA),fpga-sta) $(if $(SVF),fpga-svf) $(if $(PROG),fpga-prog)
	@echo -en '\n\n\n'
	$(call say,"Build complete!")
	$(call say,"  Bit file location: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof")
	@$(if $(SVF),$(call say,"  SVF file location: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).svf"))
	@echo -en '\n\n\n'
	@touch $(RUNDIR)/stamps/fpga

###############################################################################

.PHONY: auto
auto:
	emacs -l utils/nogit.el -l utils/verilog-mode.el --batch $(RTL_COMMON) $(RTL_FPGA) $(RTL_SIM) -f verilog-batch-auto

#tests:
#	make -C tests

