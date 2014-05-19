# Caution: files must not have the same name -- they get flattened down
# later!

RTL_COMMON = \
	rtl/mcpu.v

RTL_FPGA =
RTL_SIM =

SIM_TOP_FILE = mcpu.v
SIM_TOP_NAME = mcpu

FPGA_PROJ = mcpu

# Not necessary yet, but if we become larger and run out of address space,
# we'll need this.
#
# FPGA_TOOL_BITS = --64bit

# .vh files
RTL_INC =
