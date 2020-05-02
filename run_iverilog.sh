iverilog -g2005 -Wall -I rtl/lib -I rtl/soc -I rtl/core -I rtl/mc \
         -smcpu_iverilog \
         rtl/mcpu_iverilog.v \
         rtl/lib/*.v rtl/core/*.v \
         rtl/MCPU_int.v rtl/soc/*.v \
         rtl/mc/MCPU_MEM_arb.v rtl/mc/MCPU_MEM_dtlb.v rtl/mc/MCPU_MEM_LTC_bram.v rtl/mc/MCPU_MEM_preload.v \
         rtl/mc/MCPU_mem.v rtl/mc/MCPU_MEM_dl1c.v rtl/mc/MCPU_MEM_il1c.v rtl/mc/MCPU_MEM_ltc.v \
         rtl/mc/MCPU_MEM_pt_walk.v \
         -DBROKEN_ASSERTS -DIVERILOG $@
