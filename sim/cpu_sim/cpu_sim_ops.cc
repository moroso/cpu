#include "cpu_sim_ops.h"
#include "cpu_sim_utils.h"

#include <sstream>
#include <string>

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>

#include <boost/optional/optional.hpp>
#include <boost/format.hpp>

no_instruction::no_instruction(uint32_t raw) {
    raw_instr = raw;
}

std::string no_instruction::opcode_str() {
    return std::string("<NO INSTRUCTION (LONG IMMEDIATE)>");
}

std::string no_instruction::to_string() {
    return string_format("- No instruction (long immediate: %x)\n", raw_instr);
}

std::string other_instruction::opcode_str() {
    return decoded_instruction::opcode_str() + " - " + OTHEROP_STR[otherop];
}

std::string other_instruction::to_string() {
    std::string result = decoded_instruction::to_string();

    if (reserved_bits != 0x00)
        result += string_format("  * WARNING: reserved bits nonzero (%x)\n", reserved_bits);

    return result;
}

bool other_instruction::execute(cpu_t &cpu, uint32_t old_pc) {
    if (otherop == OTHER_BREAK && reserved_bits == 0x1FU) {
        // MAGIC_HALT
        return true;
    }

    return false;
}

bool branch_instruction::execute(cpu_t &cpu, uint32_t old_pc) {
    // XXX This only handles B, not BL
    cpu.regs.pc = old_pc;
    cpu.regs.pc += this->offset.get();
    if (this->rs) {
        cpu.regs.pc += cpu.regs.r[this->rs.get().reg];
    }

    return false;
}

std::string branch_instruction::branchop_str() {
    if (branch_link) {
        return "BL";
    } else {
        return "B";
    }
}

std::string branch_instruction::opcode_str() {
    return decoded_instruction::opcode_str() + " - " + branchop_str();
}

std::string alu_instruction::opcode_str() {
    std::string result = decoded_instruction::opcode_str() + " - " + ALUOP_STR[aluop];

    if (cmpop) {
        result += " - ";
        result += CMPOP_STR[cmpop.get()];
    }

    return result;
}

bool alu_instruction::execute(cpu_t &cpu, uint32_t old_pc) {
    uint32_t op1, op2;

    if (alu_binary()) {
        op1 = cpu.regs.r[rs.get().reg];
    }

    if (constant) {
        op2 = constant.get();
    } else if (rs && alu_unary()) {
        op2 = cpu.regs.r[rs.get().reg];
        op2 = shiftwith(op2, cpu.regs.r[rt.get().reg], stype.get());
    } else {
        op2 = cpu.regs.r[rt.get().reg];
        op2 = shiftwith(op2, shiftamt.get(), stype.get());
    }

    if (aluop != ALU_COMPARE) {
        uint32_t result;
        switch(aluop) {
            case ALU_ADD:
                result = op1 + op2;
                break;
            case ALU_AND:
                result = op1 & op2;
                break;
            case ALU_NOR:
                result = ~(op1 | op2);
                break;
            case ALU_OR:
                result = op1 | op2;
                break;
            case ALU_SUB:
                result = op1 - op2;
                break;
            case ALU_RSB:
                result = op2 - op1;
                break;
            case ALU_XOR:
                result = op1 ^ op2;
                break;
            case ALU_MOV:
                result = op2;
                break;
            case ALU_MVN:
                result = ~op2;
                break;
            case ALU_SXB:
                result = (uint32_t)(((int32_t)op2 << 24) >> 24);
                break;
            case ALU_SXH:
                result = (uint32_t)(((int32_t)op2 << 16) >> 16);
                break;
            default:
                result = 0;
                printf("ERROR: Reserved instruction executed. XXX This should be an exception!\n");
                break;
        }

        cpu.regs.r[rd.get().reg] = result;
    } else {
        if (pd.get().reg == 3) {
            printf("WARNING: Writes into P3 from compare instructions are ignored.\n");
            return false;
        }
        bool result;
        switch(cmpop.get()) {
            case CMP_LTU:
                result = op1 < op2;
                break;
            case CMP_LTS:
                result = (int32_t)op1 < (int32_t)op2;
                break;
            case CMP_LEU:
                result = op1 <= op2;
                break;
            case CMP_LES:
                result = (int32_t)op1 <= (int32_t)op2;
                break;
            case CMP_EQ:
                result = op1 == op2;
                break;
            case CMP_BS:
                result = op1 & op2;
                break;
            case CMP_BC:
                result = ~op1 & op2;
                break;
            case CMP_RESV:
                result = 0;
                printf("ERROR: Reserved instruction executed. XXX This should be an exception!\n");
                break;
        }

        cpu.regs.p[pd.get().reg] = result;
    }

    return false;
}

std::string alu_instruction::to_string() {
    std::string result = decoded_instruction::to_string();

    if (pd)
        result += string_format("  * pd = %d\n", pd->reg);

    return result;
}

bool alu_instruction::alu_unary() {
    return aluop > ALU_COMPARE;
}

bool alu_instruction::alu_binary() {
    return aluop <= ALU_COMPARE;
}

bool alu_instruction::alu_compare() {
    return aluop == ALU_COMPARE;
}

std::string loadstore_instruction::opcode_str() {
    return decoded_instruction::opcode_str() + " - " + LSUOP_STR[lsuop];
}