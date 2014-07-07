#pragma once

#include "cpu_sim.h"

#include <string>

std::string string_format(const std::string fmt_str, ...);
uint32_t shiftwith(uint32_t value, uint32_t shiftamt, shift_type stype);
uint32_t rand32();