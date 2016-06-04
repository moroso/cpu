CPP=clang++

ifeq ($(shell uname),Darwin)
# brew install lua53
LUALIB=/usr/local/lib/liblua.5.3.dylib
else
LUALIB=-l:liblua.so.5.3
endif


all: cpu_sim

cpu_sim: cpu_sim*.cc cpu_sim*.h Makefile
	$(CPP) -g -O3 -std=c++11 cpu_sim*.cc -o cpu_sim -lreadline $(LUALIB)

cpu_sim_sdl: cpu_sim*.cc cpu_sim*.h Makefile
	$(CPP) -g -O3 -std=c++11 cpu_sim*.cc -o cpu_sim_sdl `sdl-config --cflags --libs` -DUSE_SDL -lreadline $(LUALIB)

.PHONY: clean

clean:
	rm cpu_sim
