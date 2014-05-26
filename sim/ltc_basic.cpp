#include "VMCPU_MEM_ltc.h"
#include "verilated.h"

int main(int argc, char **argv, char **env) {
	Verilated::commandArgs(argc, argv);
	VMCPU_MEM_ltc *ltc = new VMCPU_MEM_ltc;
	
	return 0;
}