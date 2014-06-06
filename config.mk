# Caution: files must not have the same name -- they get flattened down
# later!

RTL_COMMON = \
	rtl/mcpu.v \
	rtl/mc/MCPU_MEM_ltc.v \
	rtl/lib/FIFO.v

RTL_FPGA = \
	$(wildcard rtl/mc/lpddr2_phy/*.v rtl/mc/lpddr2_phy/*.sv) \
	rtl/mc/lpddr2_phy.v \
	rtl/mc/MCPU_mc.v
	
RTL_SIM =

# .vh files and other misc things needed for sim or synth
RTL_INC = \
	$(wildcard rtl/mc/lpddr2_phy/*.hex) \
	rtl/mc/MCPU_MEM_ltc.vh \
	rtl/lib/clog2.vh

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

TB_ltc_directed_top  = MCPU_MEM_ltc
TB_ltc_directed_cpps = ltc_directed.cpp Cmod_MCPU_MEM_mc.cpp Stim_MCPU_MEM_ltc.cpp Check_MCPU_MEM_ltc.cpp
ALL_TBS += ltc_directed

TEST_ltc_basic_tb   = ltc_directed
TEST_ltc_basic_env  = LTC_DIRECTED_TEST_NAME=basic

TEST_ltc_backtoback_tb   = ltc_directed
TEST_ltc_backtoback_env  = LTC_DIRECTED_TEST_NAME=backtoback

TEST_ltc_evict_tb   = ltc_directed
TEST_ltc_evict_env  = LTC_DIRECTED_TEST_NAME=evict

TEST_ltc_regress_two_set_tb   = ltc_directed
TEST_ltc_regress_two_set_env  = LTC_DIRECTED_TEST_NAME=regress_two_set

TESTPLAN_L0_tests += ltc_basic ltc_backtoback ltc_evict
TESTPLAN_L1_tests += ltc_regress_two_set
ALL_TESTS += ltc_basic ltc_backtoback ltc_evict ltc_regress_two_set

TB_ltc_random_top  = MCPU_MEM_ltc
TB_ltc_random_cpps = ltc_random.cpp Cmod_MCPU_MEM_mc.cpp Stim_MCPU_MEM_ltc.cpp Check_MCPU_MEM_ltc.cpp
ALL_TBS += ltc_random

TEST_ltc_random_0_tb = ltc_random
TEST_ltc_random_0_env = LTC_RANDOM_SEED=0 LTC_RANDOM_ADDRESSES=256 LTC_RANDOM_OPERATIONS=4096
TESTPLAN_L1_tests += ltc_random_0
ALL_TESTS += ltc_random_0

TEST_ltc_random_long_tb = ltc_random
TEST_ltc_random_long_env = LTC_RANDOM_OPERATIONS=262144
TESTPLAN_L9_tests += ltc_random_long
ALL_TESTS += ltc_random_long
