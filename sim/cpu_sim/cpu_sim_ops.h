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
    aluop_t aluop;
    boost::optional<cmpop_t> cmpop;
    boost::optional<pred_reg_t> pd;

    bool alu_unary();
    bool alu_binary();
    bool alu_compare();

    std::string opcode_str();
    std::string to_string();
    bool execute(cpu_t &cpu, uint32_t old_pc);
};

struct branch_instruction : public decoded_instruction {
    bool branch_link;

    std::string branchop_str();
    std::string opcode_str();
    bool execute(cpu_t &cpu, uint32_t old_pc);
};

struct loadstore_instruction : public decoded_instruction {
    lsuop_t lsuop;

    std::string opcode_str();
};