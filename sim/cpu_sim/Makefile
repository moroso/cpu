CPP=clang++

all: cpu_sim

cpu_sim: cpu_sim*.cc cpu_sim*.h Makefile
	$(CPP) -g -O3 -std=c++11 cpu_sim*.cc -o cpu_sim -lreadline

cpu_sim_sdl: cpu_sim*.cc cpu_sim*.h Makefile
	$(CPP) -g -O3 -std=c++11 cpu_sim*.cc -o cpu_sim_sdl `sdl-config --cflags --libs` -DUSE_SDL -lreadline

.PHONY: clean

clean:
	rm cpu_sim
