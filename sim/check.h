#ifndef _CHECK_H
#define _CHECK_H

#include <stdio.h>

void sim_assert_failed();

#define SIM_CHECK(cond) do { if (!(cond)) { printf("%s: checker failed: %s\n", __FUNCTION__, #cond); sim_assert_failed(); } } while(0)

#endif
