RUNTIME := $(shell date +R%Y%m%d-%H%M%S)
RUN ?= $(RUNTIME)
RUNDIR ?= runs/$(RUN)

include config.mk
-include $(HOME)/.quartus_config.mk
Q ?= quartus_

default:
	@echo "targets:"
#	@echo "  sw           builds software (must be run before fpga to build boot0)"
	@echo "  fpga         runs a complete pass through the tool flow"
	@echo "  sim          produces a Verilator binary"
	@echo "  tests        rebuilds tests"
	@echo "  auto         re-autoizes all RTL"
	@echo ""
	@echo "variables:"
	@echo "  RUN=[...]    name of run (for runs/ directory; defaults to date+time)"
	@echo "  STA=1        run static timing analysis"
	@echo "  PROG=1       download FPGA bitfile to board after compilation"
	@echo "  SVF=1        build SVF for distribution"
	@echo
	@echo "error: you must specify a valid target"
	@exit 1

#sw: .DUMMY
#	@make -C sw

###############################################################################

symlinks: .DUMMY $(RUNDIR)/stamps/symlinks

$(RUNDIR)/stamps/symlinks:
	@echo "Creating run symlinks"
	@mkdir -p runs
	if [ -h runs/run_0a ] ; then rm runs/run_1a; mv runs/run_0a runs/run_1a ; fi
	ln -s $(RUN) runs/run_0a
	@mkdir -p $(RUNDIR)/stamps
	@touch $(RUNDIR)/stamps/symlinks

sim-symlinks: .DUMMY $(RUNDIR)/stamps/sim-symlinks

$(RUNDIR)/stamps/sim-symlinks:  $(RUNDIR)/stamps/symlinks
	if [ -h runs/sim_0a ] ; then rm runs/sim_1a; mv runs/sim_0a runs/sim_1a ; fi
	ln -s $(RUN) runs/sim_0a
	@touch $(RUNDIR)/stamps/sim-symlinks

sim-genrtl: .DUMMY $(RUNDIR)/stamps/sim-genrtl

$(RUNDIR)/stamps/sim-genrtl: sim-symlinks
	@echo "simulation not yet ready"; exit 1
	@echo "Copying RTL for simulation to $(RUNDIR)/sim/rtl..."
	@mkdir -p $(RUNDIR)/stamps
	@mkdir -p $(RUNDIR)/sim/rtl
	@cp $(RTL_COMMON) $(RTL_SIM) $(RTL_INC) $(RUNDIR)/sim/rtl
	@echo "Copying testbench for simulation to $(RUNDIR)/sim..."
	@cp sim/* $(RUNDIR)/sim
	@touch $(RUNDIR)/stamps/sim-genrtl

sim-verilate: .DUMMY $(RUNDIR)/stamps/sim-verilate

$(RUNDIR)/stamps/sim-verilate: $(RUNDIR)/stamps/sim-genrtl
	@echo "Building simulator source with Verilator into $(RUNDIR)/sim/obj_dir..."
	@mkdir -p $(RUNDIR)/sim/obj_dir
	cd $(RUNDIR)/sim; verilator -Irtl --cc rtl/$(RTL_SIM_TOP) testbench.cpp --exe --assert
	@touch $(RUNDIR)/stamps/sim-verilate

sim-build: .DUMMY $(RUNDIR)/stamps/sim-build

$(RUNDIR)/stamps/sim-build: $(RUNDIR)/stamps/sim-verilate
	@echo "Building simulator from Verilated source into $(RUNDIR)/sim/obj_dir..."
	make -C $(RUNDIR)/sim/obj_dir -f V$(SIM_TOP_NAME).mk
	ln -sf obj_dir/V$(SIM_TOP_NAME) $(RUNDIR)/sim/
	@touch $(RUNDIR)/stamps/sim-build

sim: .DUMMY $(RUNDIR)/stamps/sim

$(RUNDIR)/stamps/sim: $(RUNDIR)/stamps/sim-build
	@echo "Simulator built in $(RUNDIR)/sim."
	@touch $(RUNDIR)/stamps/sim

###############################################################################

QPARAMS = $(FPGA_TOOL_BITS) --read_settings_files=off --write_settings_files=off $(FPGA_PROJ)

fpga-symlinks: $(RUNDIR)/stamps/fpga-symlinks

$(RUNDIR)/stamps/fpga-symlinks:  $(RUNDIR)/stamps/symlinks
	if [ -h runs/fpga_0a ] ; then rm runs/fpga_1a; mv runs/fpga_0a runs/fpga_1a ; fi
	ln -s $(RUN) runs/fpga_0a
	@touch $(RUNDIR)/stamps/fpga-symlinks

# XXX: should we generate the .xst file?
fpga-genrtl: .DUMMY $(RUNDIR)/stamps/fpga-genrtl

$(RUNDIR)/stamps/fpga-genrtl: $(RUNDIR)/stamps/fpga-symlinks
	@echo "Copying RTL for synthesis to $(RUNDIR)/fpga/rtl..."
	@mkdir -p $(RUNDIR)/stamps
	@mkdir -p $(RUNDIR)/fpga/rtl
	@cp $(RTL_COMMON) $(RTL_FPGA) $(RTL_INC) $(RUNDIR)/fpga/rtl
	@echo "Copying FPGA configuration to $(RUNDIR)/fpga..."
	@cp fpga/* $(RUNDIR)/fpga
	@touch $(RUNDIR)/stamps/fpga-genrtl

fpga-map: .DUMMY $(RUNDIR)/stamps/fpga-map

$(RUNDIR)/stamps/fpga-map: $(RUNDIR)/stamps/fpga-genrtl
	@echo "Running mapper in $(RUNDIR)/fpga..."
	@touch $(RUNDIR)/stamps/fpga-map-start
	cd $(RUNDIR)/fpga; $(Q)map $(FPGA_TOOL_BITS) --read_settings_files=on --write_settings_files=on $(FPGA_PROJ) $(addprefix --source=rtl/,$(notdir $(RTL_COMMON) $(RTL_FPGA)))
	@touch $(RUNDIR)/stamps/fpga-map

fpga-fit: .DUMMY $(RUNDIR)/stamps/fpga-fit

$(RUNDIR)/stamps/fpga-fit: $(RUNDIR)/stamps/fpga-map
	@echo "Running fitter in $(RUNDIR)/fpga..."
	@touch $(RUNDIR)/stamps/fpga-fit-start
	cd $(RUNDIR)/fpga; $(Q)fit $(QPARAMS)
	@touch $(RUNDIR)/stamps/fpga-fit

fpga-asm: .DUMMY $(RUNDIR)/stamps/fpga-asm

$(RUNDIR)/stamps/fpga-asm: $(RUNDIR)/stamps/fpga-fit
	@echo "Running assembler in $(RUNDIR)/fpga..."
	@touch $(RUNDIR)/stamps/fpga-asm-start
	cd $(RUNDIR)/fpga; $(Q)asm $(QPARAMS)
	@touch $(RUNDIR)/stamps/fpga-asm
	@echo -en "\n\n\n"
	@echo "Bit file generated: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof"
	@echo -en "\n\n\n"

fpga-sta: .DUMMY $(RUNDIR)/stamps/fpga-sta

$(RUNDIR)/stamps/fpga-sta: $(RUNDIR)/stamps/fpga-fit
	@echo "Running STA in $(RUNDIR)/fpga..."
	@touch $(RUNDIR)/stamps/fpga-sta-start
	cd $(RUNDIR)/fpga; $(Q)sta $(FPGA_PROJ)
	@touch $(RUNDIR)/stamps/fpga-sta

$(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof: $(RUNDIR)/stamps/fpga-asm

fpga-svf: .DUMMY $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).svf

$(RUNDIR)/fpga/output_files/$(FPGA_PROJ).svf: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof
	$(Q)cpf -c -q 33MHz -g 3.3 -n p $< $@

fpga-prog: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof
	$(Q)pgm -m JTAG -o p\;$<

fpga: .DUMMY $(RUNDIR)/stamps/fpga

$(RUNDIR)/stamps/fpga: fpga-asm $(if $(STA),fpga-sta) $(if $(SVF),fpga-svf) $(if $(PROG),fpga-prog)
	@echo -en '\n\n\n'
	@echo "Build complete!"
	@echo "  Bit file location: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).sof"
	@$(if $(SVF),echo "  SVF file location: $(RUNDIR)/fpga/output_files/$(FPGA_PROJ).svf")
	@echo -en '\n\n\n'
	@touch $(RUNDIR)/stamps/fpga

###############################################################################

auto: .DUMMY
	emacs -l utils/nogit.el -l utils/verilog-mode.el --batch $(RTL_COMMON) $(RTL_FPGA) $(RTL_SIM) -f verilog-batch-auto

#tests: .DUMMY
#	make -C tests

.DUMMY:
