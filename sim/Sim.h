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

#define SIM_LOG(c, l, fmt, ...) Sim::log(c, l ": %6lu ns: [%s] %s (%s:%d): " fmt "\n", Sim::main_time, instance, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__ )

#define SIM_DEBUG(fmt, ...) SIM_LOG(Sim::Debug, "D", fmt, ##__VA_ARGS__ )
#define SIM_INFO(fmt, ...) SIM_LOG(Sim::Info, "I", fmt, ##__VA_ARGS__ )
#define SIM_ERROR(fmt, ...) SIM_LOG(Sim::Error, "E", fmt, ##__VA_ARGS__ )
#define SIM_FATAL(fmt, ...) SIM_LOG(Sim::Fatal, "F", fmt, ##__VA_ARGS__ )
#define SIM_CHECK(cond) do { if (!(cond)) { SIM_ERROR("checker failed: %s", #cond); } } while(0)
#define SIM_CHECK_EQ(e1, e2) do { if ((e1) != (e2)) { SIM_ERROR("checker failed: %x != %x", (e1), (e2)); } } while(0)
#define SIM_CHECK_MSG(cond, msg, ...) do { if (!(cond)) { SIM_ERROR("checker failed: " msg, ##__VA_ARGS__ ); } } while(0)
#define SIM_ASSERT(cond) do { if (!(cond)) { SIM_FATAL("checker failed: %s", #cond); } } while(0)
#define SIM_ASSERT_MSG(cond, msg, ...) do { if (!(cond)) { SIM_FATAL("checker failed: " msg, ##__VA_ARGS__ ); } } while(0)

static const char *instance = "global";

#endif
