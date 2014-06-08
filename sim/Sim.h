#ifndef _SIM_H
#define _SIM_H

#include "verilated.h"

namespace Sim {
	extern vluint64_t main_time;
	void tick();
	
	extern uint64_t max_assertions_failed;
	extern uint64_t assertions_failed;
	
	void assert_failed();
	
	void init(int argc, char **argv);
	void finish();
	
	const char *param_str(const char *s, const char *dfl = NULL);
	
	uint64_t param_u64(const char *name, uint64_t dfl = 0);
	
	uint64_t random(uint64_t range);
	
	enum Level {
		Debug,
		Info,
		Error,
		Fatal
	};
	
	extern Level log_level;
	
	void log(Level lvl, const char *fmt, ...);
};

double sc_time_stamp();

#define SIM_DEBUG(fmt, ...) Sim::log(Sim::Debug, "D: %6lu ns: %s (%s:%d): " fmt "\n", Sim::main_time, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__ )
#define SIM_INFO(fmt, ...)  Sim::log(Sim::Info , "I: %6lu ns: %s (%s:%d): " fmt "\n", Sim::main_time, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__ )
#define SIM_ERROR(fmt, ...) Sim::log(Sim::Error, "E: %6lu ns: %s (%s:%d): " fmt "\n", Sim::main_time, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__ )
#define SIM_FATAL(fmt, ...) Sim::log(Sim::Fatal, "F: %6lu ns: %s (%s:%d): " fmt "\n", Sim::main_time, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__ )

#define SIM_CHECK(cond) do { if (!(cond)) { SIM_ERROR("checker failed: %s", #cond); } } while(0)

#endif
