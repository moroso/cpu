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
    // XXX incomplete
    if (this->aluop == ALU_ADD) {
        uint32_t total = 0;

        if (this->rs) {
            total += cpu.regs.r[this->rs.get().reg];
        }
        if (this->constant) {
            total += this->constant.get();
        }
        if (this->rt) {
            total += shiftwith(cpu.regs.r[this->rt.get().reg], this->shiftamt.get(), (shift_type)this->stype.get());
        }

        cpu.regs.r[this->rd.get().reg] = total;
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