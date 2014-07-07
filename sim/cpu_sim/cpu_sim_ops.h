#pragma once

#include "cpu_sim.h"

struct other_instruction : public decoded_instruction {
    otherop_t otherop;
    uint32_t reserved_bits;

    std::string opcode_str();
    std::string to_string();
    bool execute(cpu_t &cpu, uint32_t old_pc);
};

struct alu_instruction : public decoded_instruction {
};