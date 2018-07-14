#include <stdlib.h>
#include <time.h>
#include <stdarg.h>
#include <stdio.h>

#include "Sim.h"

#include "verilated.h"

vluint64_t Sim::main_time = 0;
uint64_t Sim::max_assertions_failed = 10;
uint64_t Sim::assertions_failed = 0;
Sim::Level Sim::log_level = Info;

double sc_time_stamp() {
	return Sim::main_time;
}

void Sim::tick() {
	main_time++;
}

void Sim::assert_failed() {
	assertions_failed++;
	if (assertions_failed > max_assertions_failed)
		SIM_FATAL("too many assertions failed");
}

void Sim::init(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);

	log_level = (Level)param_u64("SIM_LOG_LEVEL", Info);

	max_assertions_failed = param_u64("SIM_MAX_ASSERTIONS", 10);

	srandom(param_u64("SIM_RANDOM_SEED", time(NULL)));
}

void Sim::finish() {
	if (assertions_failed > 0) {
		SIM_FATAL("non-zero assertion failures: check logs");
		exit(1);
	}
}

const char *Sim::param_str(const char *name, const char *dfl) {
	const char *r;
	
	r = getenv(name);
	if (!r)
		SIM_INFO("parameter \"%s\" not found, defaulting to \"%s\"", name, dfl);
	return r ? r : dfl;
}

uint64_t Sim::param_u64(const char *name, uint64_t dfl) {
	const char *r;
	
	r = getenv(name);
	if (r) {
		uint64_t converted_val = strtoull(r, NULL, 0);
		SIM_INFO("parameter \"%s\" specified as \"%lu\"", name, converted_val);
		return converted_val;
	} else {
		SIM_INFO("parameter \"%s\" not found, defaulting to \"%lu\"", name, dfl);
		return dfl;
	}
}

uint64_t Sim::random(uint64_t range) {
	return ::random() % range;
}

void Sim::log(Sim::Level lvl, const char *fmt, ...) {
	va_list ap;
	
	if (lvl >= log_level) {
		va_start(ap, fmt);
		vfprintf(stderr, fmt, ap);
		va_end(ap);
	}
	
	if (lvl >= Error && lvl >= log_level) {
		va_start(ap, fmt);
		vfprintf(stderr, fmt, ap);
		va_end(ap);
	}
	
	if (lvl >= Fatal) {
		exit(1);
	}

	if (lvl >= Error) {
		assert_failed();
	}
}
