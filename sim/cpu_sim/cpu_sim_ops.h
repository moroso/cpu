#pragma once

#include "cpu_sim.h"

struct no_instruction : public decoded_instruction {
    no_instruction(uint32_t raw);

    std::string opcode_str();
    std::string to_string();
    std::string disassemble_inner();
    exec_result execute_unconditional(cpu_t &cpu, cpu_t &old_cpu);
};

struct other_instruction : public decoded_instruction {
    otherop_t otherop;
    uint32_t reserved_bits;
    bool signd;  // mult/div
    bool wide; // div

    std::string opcode_str();
    std::string to_string();
    std::string disassemble_inner();
    exec_result execute_unconditional(cpu_t &cpu, cpu_t &old_cpu);
    uint64_t read_reg_mask();
    uint64_t write_reg_mask();
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
    std::string disassemble_inner();
    exec_result execute_unconditional(cpu_t &cpu, cpu_t &old_cpu);
};

struct branch_instruction : public decoded_instruction {
    bool branch_link;

    std::string branchop_str();
    std::string opcode_str();
    std::string disassemble_inner();
    exec_result execute_unconditional(cpu_t &cpu, cpu_t &old_cpu);
};

struct loadstore_instruction : public decoded_instruction {
    lsuop_t lsuop;  // This is redundant with the fields below, but it's convenient to keep it.
    bool store;
    bool linked;
    size_t width;

    std::string opcode_str();
    std::string disassemble_inner();
    exec_result execute_unconditional(cpu_t &cpu, cpu_t &old_cpu);
};
