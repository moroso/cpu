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

bool other_instruction::execute(cpu_t &cpu, cpu_t &old_cpu) {
    if (!predicate_ok(old_cpu)) {
        return false;
    }

    switch (otherop) {
        case OTHER_BREAK:
            if (reserved_bits == 0x1FU) {
                switch (cpu.regs.r[30]) {
                    case 0:
                        // MAGIC_HALT
                        return true;
                    case 1:
                        // MAGIC_PRINT_R0
                        printf("R0 HAS VALUE %d (%x)\n", cpu.regs.r[0], cpu.regs.r[0]);
                        break;
                }
            }
            break;
        case OTHER_MULT:
            if (signd) {
                int64_t rs_val = (int32_t)old_cpu.regs.r[rs.get()];
                int64_t rt_val = (int32_t)old_cpu.regs.r[rt.get()];
                uint64_t result = rs_val * rt_val;
                cpu.regs.r[rd.get()] = result & 0xFFFFFFFF;
                cpu.regs.ovf = result >> 32;
            } else {
                uint64_t rs_val = old_cpu.regs.r[rs.get()];
                uint64_t rt_val = old_cpu.regs.r[rt.get()];
                uint64_t result = rs_val * rt_val;
                cpu.regs.r[rd.get()] = result & 0xFFFFFFFF;
                cpu.regs.ovf = result >> 32;
            }
            break;
        case OTHER_DIV:
            if (signd) {
                int32_t rs_val = old_cpu.regs.r[rs.get()];
                int32_t rt_val = old_cpu.regs.r[rt.get()];
                cpu.regs.r[rd.get()] = rs_val / rt_val;
                cpu.regs.ovf = rs_val % rt_val;
            } else {
                uint32_t rs_val = old_cpu.regs.r[rs.get()];
                uint32_t rt_val = old_cpu.regs.r[rt.get()];
                cpu.regs.r[rd.get()] = rs_val / rt_val;
                cpu.regs.ovf = rs_val % rt_val;
            }
            break;
        case OTHER_MFHI:
            cpu.regs.r[rd.get()] = old_cpu.regs.ovf;
            break;
        case OTHER_MTHI:
            cpu.regs.ovf = old_cpu.regs.r[rs.get()];
            break;
    }

    return false;
}

bool branch_instruction::execute(cpu_t &cpu, cpu_t &old_cpu) {
    if (!predicate_ok(old_cpu)) {
        return false;
    }

    uint32_t target;
    if (rs) {
        target = old_cpu.regs.r[rs.get().reg];
    } else {
        target = old_cpu.regs.pc;
    }
    target += this->offset.get();

    target &= ~0xF;
    cpu.regs.pc = target;
    if (branch_link) {
        cpu.regs.r[31] = old_cpu.regs.pc;
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

bool alu_instruction::execute(cpu_t &cpu, cpu_t &old_cpu) {
    if (!predicate_ok(old_cpu)) {
        return false;
    }

    uint32_t op1, op2;

    if (alu_binary()) {
        // All 2-op forms use rs as the first operand.
        op1 = old_cpu.regs.r[rs.get().reg];
    }

    // For 2-op forms, we are retrieving the second operand here; for 1-op forms, the only operand is called 'op2'.
    if (constant) {
        // ALU short form
        op2 = constant.get();
    } else if (rs && alu_unary()) {
        // ALU 1-op "regsh" (register shifted by register) form
        op2 = old_cpu.regs.r[rt.get().reg];
        op2 = shiftwith(op2, old_cpu.regs.r[rs.get().reg], stype.get());
    } else {
        // ALU register form
        op2 = old_cpu.regs.r[rt.get().reg];
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
                result = (uint32_t)SIGN_EXTEND_32(op2, 8);
                break;
            case ALU_SXH:
                result = (uint32_t)SIGN_EXTEND_32(op2, 16);
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

bool loadstore_instruction::execute(cpu_t &cpu, cpu_t &old_cpu) {
    if (!predicate_ok(old_cpu)) {
        return false;
    }

    uint32_t addr_mask = ~(width - 1);
    uint32_t mem_addr = addr_mask & (old_cpu.regs.r[rs.get()] + offset.get());

    if (store) {
        if (linked) {
            if (!cpu.regs.link) {
                printf("ERROR: XXX should throw exception here\n");
                return false;
            }
        }

        uint32_t val = old_cpu.regs.r[rt.get()];

        for (int i = 0; i < width; ++i) {
            if (mem_addr >= SIM_RAM_BYTES) {
                printf("FATAL: Load/store outside RAM\n");
                abort();
            }
            cpu.ram->data[mem_addr + i] = val & 0xFF;
            val >>= 8;
        }
    } else {
        uint32_t val = 0;
        // Little-endian: copy starting at the msb
        mem_addr += width - 1;

        for (int i = 0; i < width; ++i) {
            if (mem_addr >= SIM_RAM_BYTES) {
                printf("FATAL: Load/store outside RAM\n");
                abort();
            }
            val <<= 8;
            val += cpu.ram->data[mem_addr];
            mem_addr--;
        }

        cpu.regs.r[rd.get()] = val;

        if (linked) {
            cpu.regs.link = true;
        }
    }

    return false;
}