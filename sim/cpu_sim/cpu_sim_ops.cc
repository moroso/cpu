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

exec_result no_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    return exec_result(EXC_NO_ERROR);
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

exec_result other_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    switch (otherop) {
        case OTHER_SYSCALL:
            return exec_result(EXC_SYSCALL);
        case OTHER_BREAK:
            if (reserved_bits == 0x1FU) {
                switch (cpu.regs.r[30]) {
                    case 0:
                        // MAGIC_HALT
                        return exec_result(EXC_HALT);
                    case 1:
                        // MAGIC_PRINT_R0
                        printf("R0 HAS VALUE %d (%x)\n", cpu.regs.r[0], cpu.regs.r[0]);
                        break;
                    case 2:
                        // MAGIC_PUTC_R0
                        fputc(cpu.regs.r[0], stderr);
                        break;
                }
            } else {
                return exec_result(EXC_BREAK);
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
                if (rt_val == 0)
                    return exec_result(EXC_DIVIDE_BY_ZERO);
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
        case OTHER_MFC:
            if (!old_cpu.regs.sys_kmode)
                return exec_result(EXC_INSUFFICIENT_PERMISSIONS);
            cpu.regs.r[rd.get()] = old_cpu.regs.cpr[rs.get()];
            break;
        case OTHER_MTC:
            if (!old_cpu.regs.sys_kmode)
                return exec_result(EXC_INSUFFICIENT_PERMISSIONS);
            cpu.regs.cpr[rd.get()] = old_cpu.regs.r[rs.get()];
            break;
        case OTHER_ERET:
            if (!old_cpu.regs.sys_kmode)
                return exec_result(EXC_INSUFFICIENT_PERMISSIONS);
            cpu.regs.pc = old_cpu.regs.cpr[CP_EPC] & 0xFFFFFFF0;
            cpu.regs.sys_kmode = old_cpu.regs.cpr[CP_EPC] & 0x01;
            if (BIT(old_cpu.regs.cpr[CP_EPC], 1))
                cpu.regs.cpr[CP_PFLAGS] |= (1 << PFLAGS_INT_ENABLE);
            else
                cpu.regs.cpr[CP_PFLAGS] &= ~(1 << PFLAGS_INT_ENABLE);
            cpu.regs.link = false;
            break;
        default:
            return exec_result(EXC_ILLEGAL_INSTRUCTION);
            break;
    }

    return exec_result(EXC_NO_ERROR);
}

exec_result branch_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
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

    return exec_result(EXC_NO_ERROR);
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

exec_result alu_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
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
                return exec_result(EXC_ILLEGAL_INSTRUCTION);
        }

        cpu.regs.r[rd.get().reg] = result;
    } else {
        if (pd.get().reg == 3) {
            printf("WARNING: Writes into P3 from compare instructions are ignored.\n");
            return exec_result(EXC_NO_ERROR);
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
                return exec_result(EXC_ILLEGAL_INSTRUCTION);
                break;
        }

        cpu.regs.p[pd.get().reg] = result;
    }

    return exec_result(EXC_NO_ERROR);
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

exec_result loadstore_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    uint32_t addr_mask = ~(width - 1);
    uint32_t virt_mem_addr = addr_mask & (old_cpu.regs.r[rs.get()] + offset.get());
    // We know the operation won't cross a page boundary, because of alignment requirements.
    // TODO: check for a fault here.
    boost::optional<uint32_t> mem_addr_opt = virt_to_phys(virt_mem_addr, old_cpu, store);
    if (!mem_addr_opt)
        return exec_result(EXC_PAGEFAULT_ON_DATA_ACCESS, virt_mem_addr);

    for (int i = 1; i < width; ++i) {
        // Verify that all remaining bytes in this access are valid.
        if (!virt_to_phys(virt_mem_addr + i, old_cpu, store))
            return exec_result(EXC_PAGEFAULT_ON_DATA_ACCESS, virt_mem_addr);
    }

    uint32_t mem_addr = *mem_addr_opt;

    if (store) {
        if (linked) {
            cpu.regs.p[0] = !cpu.regs.link;

            if (!cpu.regs.link) {
                return exec_result(EXC_NO_ERROR);
            }

            cpu.regs.link = false;
        }

        uint32_t val = old_cpu.regs.r[rt.get()];

        if (!cpu.validate_write(mem_addr, val, width))
            return exec_result(EXC_INVALID_PHYSICAL_ADDRESS, virt_mem_addr);

        return exec_result(EXC_NO_ERROR, mem_addr, width, val);
    } else {
        boost::optional<uint32_t> val = boost::none;
        // Little-endian: copy starting at the msb
        mem_addr += width - 1;

        for (int i = 0; i < cpu.peripherals.size(); i++) {
            boost::optional<uint32_t> periph_val = cpu.peripherals[i]->read(cpu, mem_addr, width);
            if (periph_val) {
                printf("Read handled by %s\n", cpu.peripherals[i]->name().c_str());
                cpu.regs.r[rd.get()] = *periph_val;
                return exec_result(EXC_NO_ERROR);
            }
        }

        for (int i = 0; i < cpu.peripherals.size(); i++) {
            boost::optional<uint32_t> result = cpu.peripherals[i]->read(cpu, mem_addr, width);
            if (result) {
                val = result;
                break;
            }
        }

        if (!val) {
            uint32_t read_val = 0;
            for (int i = 0; i < width; ++i) {
                if (mem_addr >= SIM_RAM_BYTES) {
                    printf("FATAL: Load/store outside RAM\n");
                    abort();
                }
                read_val <<= 8;
                read_val += cpu.ram[mem_addr];
                mem_addr--;
            }
            val = read_val;
        }

        cpu.regs.r[rd.get()] = *val;

        if (linked) {
            cpu.regs.link = true;
        }

        return exec_result(EXC_NO_ERROR);
    }
}
