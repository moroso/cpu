#ifndef _CHECK_H
#define _CHECK_H

#include <stdio.h>
#include "verilated.h"

extern vluint64_t main_time;
void sim_assert_failed();

#define SIM_CHECK(cond) do { if (!(cond)) { printf("%s: checker failed at %lu ns: %s\n", __PRETTY_FUNCTION__, main_time, #cond); sim_assert_failed(); } } while(0)

#endif
