all: cpu_sim

cpu_sim: cpu_sim.cc
	clang++ -g -O1 -std=c++11 cpu_sim.cc -o cpu_sim

.PHONY: clean

clean:
	rm cpu_sim
