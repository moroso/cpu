# Caution: files must not have the same name -- they get flattened down
# later!

RTL_COMMON = \
	rtl/MCPU_int.v \
	rtl/core/MCPU_CORE_alu.v \
	rtl/core/MCPU_CORE_coproc.v \
	rtl/core/MCPU_CORE_decode.v \
	rtl/core/MCPU_CORE_exn_encode.v \
	rtl/core/MCPU_CORE_regfile.v \
	rtl/core/MCPU_CORE_scoreboard.v \
	rtl/core/MCPU_CORE_stage_dtlb.v \
	rtl/core/MCPU_CORE_stage_fetch.v \
	rtl/core/MCPU_CORE_stage_mem.v \
	rtl/core/MCPU_core.v \
	rtl/lib/FIFO.v \
	rtl/lib/dp_bram.v \
	rtl/lib/reg_2.v \
	rtl/lib/register.v \
	rtl/lib/sp_bram.v \
	rtl/mc/MCPU_MEM_LTC_bram.v \
	rtl/mc/MCPU_MEM_arb.v \
	rtl/mc/MCPU_MEM_dl1c.v \
	rtl/mc/MCPU_MEM_dtlb.v \
	rtl/mc/MCPU_MEM_il1c.v \
	rtl/mc/MCPU_MEM_il1c.v \
	rtl/mc/MCPU_MEM_ltc.v \
	rtl/mc/MCPU_MEM_preload.v \
	rtl/mc/MCPU_MEM_pt_walk.v \
	rtl/mc/MCPU_mem.v \
	rtl/mcpu.v \
	rtl/soc/MCPU_SOC_i2c.v \
	rtl/soc/MCPU_SOC_ledsw.v \
	rtl/soc/MCPU_SOC_mmio.v \
	rtl/soc/uart.v

RTL_FPGA = \
	$(wildcard rtl/mc/lpddr2_phy/*.v rtl/mc/lpddr2_phy/*.sv) \
	rtl/mc/lpddr2_phy.v \
	rtl/mc/MCPU_mc.v

RTL_SIM = \
	rtl/tb/TB_MCPU_MEM_arb.v \
	rtl/tb/TB_MCPU_MEM_preload.v \
	rtl/tb/TB_MCPU_core.v

# .vh files and other misc things needed for sim or synth
RTL_INC = \
	$(wildcard rtl/mc/lpddr2_phy/*.hex) \
	rtl/mc/MCPU_MEM_ltc.vh \
	rtl/mc/MCPU_MEM_pt.vh \
	rtl/lib/clog2.vh \
	rtl/core/oper_type.vh \
	rtl/core/exn_codes.vh

BOOTROM_ASM = boot/serial_bootloader.ma

SIM_TOP_FILE = mcpu.v
SIM_TOP_NAME = mcpu

FPGA_PROJ = mcpu

# Not necessary yet, but if we become larger and run out of address space,
# we'll need this.
#
# FPGA_TOOL_BITS = --64bit

### Tests ###

# Testplans available:
#  L0: basic sanity: L0 should pass *quickly*.
#  L1: slightly longer tests: L1 may take a little longer.
#  L9: randoms: L9 is expected to grow to be an hour or so.

ALL_TESTPLANS = L0 L1 L9

TESTPLAN_L0_name  = level0 sanity
TESTPLAN_L0_tests =

TESTPLAN_L1_name  = level1 regressions
TESTPLAN_L1_tests = 

TESTPLAN_L9_name  = level9 randoms
TESTPLAN_L9_tests =

# L2C tests

TB_ltc_top  = MCPU_MEM_ltc
TB_ltc_cpps = ltc.cpp Sim.cpp Cmod_MCPU_MEM_mc.cpp Stim_MCPU_MEM.cpp Check_MCPU_MEM.cpp
ALL_TBS += ltc

TEST_ltc_basic_tb   = ltc
TEST_ltc_basic_env  = LTC_DIRECTED_TEST_NAME=basic

TEST_ltc_backtoback_tb   = ltc
TEST_ltc_backtoback_env  = LTC_DIRECTED_TEST_NAME=backtoback

TEST_ltc_evict_tb   = ltc
TEST_ltc_evict_env  = LTC_DIRECTED_TEST_NAME=evict

TEST_ltc_regress_two_set_tb   = ltc
TEST_ltc_regress_two_set_env  = LTC_DIRECTED_TEST_NAME=regress_two_set

TESTPLAN_L0_tests += ltc_basic ltc_backtoback ltc_evict
TESTPLAN_L1_tests += ltc_regress_two_set
ALL_TESTS += ltc_basic ltc_backtoback ltc_evict ltc_regress_two_set

TEST_ltc_random_0_tb = ltc
TEST_ltc_random_0_env = LTC_DIRECTED_TEST_NAME=random SIM_RANDOM_SEED=0 LTC_RANDOM_ADDRESSES=256 LTC_RANDOM_OPERATIONS=4096
TESTPLAN_L1_tests += ltc_random_0
ALL_TESTS += ltc_random_0

TEST_ltc_random_long_tb = ltc
TEST_ltc_random_long_env = LTC_DIRECTED_TEST_NAME=random LTC_RANDOM_OPERATIONS=262144
TESTPLAN_L9_tests += ltc_random_long
ALL_TESTS += ltc_random_long


# ARB tests

TB_arb_top  = TB_MCPU_MEM_arb
TB_arb_cpps = arb.cpp Sim.cpp Stim_MCPU_MEM.cpp Check_MCPU_MEM.cpp Cmod_MCPU_MEM_mc.cpp
ALL_TBS += arb

TEST_arb_single_tb  = arb
TEST_arb_single_env = ARB_DIRECTED_TEST_NAME=single

TEST_arb_basic_tb  = arb
TEST_arb_basic_env =

TEST_arb_random_0_tb  = arb
TEST_arb_random_0_env = ARB_DIRECTED_TEST_NAME=random SIM_RANDOM_SEED=0 ARB_RANDOM_ADDRESSES=256 ARB_RANDOM_OPERATIONS=4096

TEST_arb_random_long_tb  = arb
TEST_arb_random_long_env = ARB_DIRECTED_TEST_NAME=random ARB_RANDOM_OPERATIONS=262144

TESTPLAN_L0_tests += arb_single arb_basic
TESTPLAN_L1_tests += arb_random_0
TESTPLAN_L9_tests += arb_random_long
ALL_TESTS += arb_single arb_basic arb_random_0 arb_random_long

# Preloader tests

TB_pre_top = TB_MCPU_MEM_preload
TB_pre_cpps = pre.cpp Sim.cpp Stim_MCPU_MEM.cpp Check_MCPU_MEM.cpp Cmod_MCPU_MEM_mc.cpp
ALL_TBS += pre

TEST_pre_basic_tb = pre
TEST_pre_basic_env =
TEST_pre_basic_rom = sim/rom/bytes.hex
ALL_TESTS += pre_basic
TESTPLAN_L0_tests += pre_basic

TB_int_top = MCPU_int
TB_int_cpps =
ALL_TBS += int

TB_core_sim_top = MCPU_core
TB_core_sim_cpps = core_sim.cpp Sim.cpp
ALL_TBS += core_sim

TB_core_test_top = MCPU_int
TB_core_test_cpps = core_test.cpp Sim.cpp Cmod_MCPU_MEM_mc.cpp
ALL_TBS += core_test

TB_core_sys_top = TB_MCPU_core
TB_core_sys_cpps = core_sys.cpp Sim.cpp
ALL_TBS += core_sys

# Pagetable walker tests

TB_pt_walk_top = MCPU_MEM_pt_walk
TB_pt_walk_cpps = walk.cpp Sim.cpp Cmod_MCPU_MEM_arb.cpp
ALL_TBS += pt_walk

TEST_pt_walk_basic_tb  = pt_walk
TEST_pt_walk_basic_env =

TESTPLAN_L0_tests += pt_walk_basic
ALL_TESTS += pt_walk_basic

# TLB tests

TB_dtlb_top = MCPU_MEM_dtlb
TB_dtlb_cpps = dtlb.cpp Sim.cpp Cmod_MCPU_MEM_walk.cpp Check_MCPU_MEM_dtlb.cpp \
	 Stim_MCPU_MEM_dtlb.cpp
ALL_TBS += dtlb

TEST_dtlb_basic_tb  = dtlb
TEST_dtlb_basic_env =

TEST_dtlb_fill_tb  = dtlb
TEST_dtlb_fill_env = DTLB_TEST_NAME=fill

# Uses the full address space
TEST_dtlb_random_full_tb  = dtlb
TEST_dtlb_random_full_env = DTLB_TEST_NAME=random

# Random tests that limit the sets and tags, to increase
# the frequency of collisions and evictions
TEST_dtlb_random_limited_tb  = dtlb
TEST_dtlb_random_limited_env = DTLB_TEST_NAME=random DTLB_RANDOM_TAGS=16 DTLB_RANDOM_SETS=16

TEST_dtlb_random_long_tb  = dtlb
TEST_dtlb_random_long_env = DTLB_TEST_NAME=random DTLB_RANDOM_OPERATIONS=262144

TESTPLAN_L0_tests += dtlb_basic
TESTPLAN_L1_tests += dtlb_fill dtlb_random_full dtlb_random_limited
TESTPLAN_L2_tests += dtlb_random_long
ALL_TESTS += dtlb_basic dtlb_fill dtlb_random_full dtlb_random_limited dtlb_random_long

# Instruction L1C tests

TB_il1c_top = MCPU_MEM_il1c
TB_il1c_cpps = il1c.cpp Sim.cpp Cmod_MCPU_MEM_dtlb.cpp Cmod_MCPU_MEM_arb.cpp \
    Stim_MCPU_MEM_il1c.cpp Check_MCPU_MEM_il1c.cpp
ALL_TBS += il1c

TEST_il1c_basic_tb = il1c
TEST_il1c_basic_env =

TEST_il1c_random_tb = il1c
TEST_il1c_random_env = IL1C_TEST_NAME=random

TESTPLAN_L0_tests += il1c_basic
TESTPLAN_L1_tests += il1c_random
ALL_TESTS += il1c_basic il1c_random

# Data L1C tests

TB_dl1c_top = MCPU_MEM_dl1c
TB_dl1c_cpps = dl1c.cpp Sim.cpp Cmod_MCPU_MEM_dtlb.cpp Cmod_MCPU_MEM_arb.cpp \
    Stim_MCPU_MEM_dl1c.cpp Check_MCPU_MEM_dl1c.cpp
ALL_TBS += dl1c

TEST_dl1c_basic_tb = dl1c
TEST_dl1c_basic_env =

TEST_dl1c_random_tb = dl1c
TEST_dl1c_random_env = DL1C_TEST_NAME=random

TESTPLAN_L0_tests += dl1c_basic
TESTPLAN_L1_tests += dl1c_random
ALL_TESTS += dl1c_basic dl1c_random
