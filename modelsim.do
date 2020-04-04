vlib mcpu
vlog -reportprogress 300 -work mcpu \
    +define+BROKEN_ASSERTS=1 \
    +define+SIM=1 \
    +incdir+rtl/lib +incdir+rtl/core +incdir+rtl/mc \
    rtl/mcpu.v \
    rtl/lib/*.v rtl/core/*.v \
    rtl/MCPU_int.v rtl/soc/*.v \
    rtl/mc/MCPU_MEM_arb.v rtl/mc/MCPU_MEM_dtlb.v \
    rtl/mc/MCPU_MEM_LTC_bram.v rtl/mc/MCPU_MEM_preload.v \
    rtl/mc/MCPU_mem.v rtl/mc/MCPU_MEM_dl1c.v \
    rtl/mc/MCPU_MEM_il1c.v rtl/mc/MCPU_MEM_ltc.v \
    rtl/mc/MCPU_MEM_pt_walk.v

vsim mcpu.mcpu
log * -r
add wave -position end  sim:/mcpu/clk50
add wave -position end  sim:/mcpu/clkrst_mem_rst_n
