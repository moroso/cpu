#include "verilated.h"
#include "VMCPU_MEM_ltc.h"
#include "Cmod_MCPU_MEM_mc.h"

int main(int argc, char **argv, char **env) {
	Verilated::commandArgs(argc, argv);
	VMCPU_MEM_ltc *ltc = new VMCPU_MEM_ltc;
	Cmod_MCPU_MEM_mc *mc_cmod = new Cmod_MCPU_MEM_mc(Cmod_MCPU_MEM_mc_CONNECT(*ltc));
	
	return 0;
}