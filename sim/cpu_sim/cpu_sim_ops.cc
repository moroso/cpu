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

extern bool verbose;

std::string format_signed_hex(int32_t num) {
    if (num >= 0)
        return string_format("0x%x", num);
    else
        return string_format("-0x%x", -num);
}

no_instruction::no_instruction(uint32_t raw) {
    raw_instr = raw;
}

std::string no_instruction::opcode_str() {
    return std::string("<NO INSTRUCTION (LONG IMMEDIATE)>");
}

std::string no_instruction::to_string() {
    return string_format("- No instruction (long immediate: %x)\n", raw_instr);
}

std::string no_instruction::disassemble_inner() {
    return string_format("long 0x%x", raw_instr);
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

std::string other_instruction::disassemble_inner() {
    std::ostringstream result;

    switch (otherop) {
        case OTHER_SYSCALL:
        case OTHER_BREAK:
            result << OTHEROP_STR[otherop];
            if (reserved_bits)
                result << string_format(" 0x%x", reserved_bits);
            break;
        case OTHER_FENCE:
        case OTHER_ERET:
            result << OTHEROP_STR[otherop];
            break;
        case OTHER_MFC:
            result << string_format("r%d <- ", rd.get()) << CP_REG_STR[rs.get()];
            break;
        case OTHER_MTC:
            result << CP_REG_STR[rd.get()] << string_format(" <- r%d", rs.get());
            break;
        case OTHER_MULT:
        case OTHER_DIV:
            result << string_format("r%d <- r%d %c%s%s r%d",
                                    rd.get(), rs.get(),
                                    (otherop == OTHER_MULT ? '*' : '/'),
                                    (signd ? "s" : ""),
                                    (wide ? "w" : ""),
                                    rt.get());
            break;
        case OTHER_MTHI:
            result << string_format("ovf <- r%d", rs.get());
            break;
        case OTHER_MFHI:
            result << string_format("r%d <- ovf", rd.get());
            break;
        case OTHER_FLUSH:
          result << string_format("flush.X r%d", rs.get());
        default:
            result << "UNKNOWN";
            break;
    }

    return result.str();
}

extern bool stop_flag;

exec_result other_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    switch (otherop) {
        case OTHER_SYSCALL:
            return exec_result(EXC_SYSCALL);
        case OTHER_BREAK:
            if (reserved_bits == 0x1FU) {
                switch (cpu.read_reg(30, cpu)) {
                    case 0:
                        // MAGIC_HALT
                        return exec_result(EXC_HALT);
                    case 1:
                        // MAGIC_PRINT_R0
                        printf("R0 HAS VALUE %d (%x)\n",
                               cpu.read_reg(0, cpu), cpu.read_reg(0, cpu));
                        break;
                    case 2:
                        // MAGIC_PUTC_R0
                        fputc(cpu.read_reg(0, cpu), stderr);
                        break;
                    case 3:
                        // MAGIC_DEBUG
                        stop_flag = true;
                        break;
                }
            } else {
                return exec_result(EXC_BREAK);
            }
            break;
        case OTHER_MULT:
            if (signd) {
                int64_t rs_val = (int32_t)old_cpu.read_reg(rs.get(), cpu);
                int64_t rt_val = (int32_t)old_cpu.read_reg(rt.get(), cpu);
                uint64_t result = rs_val * rt_val;
                cpu.write_reg(rd.get(), result & 0xFFFFFFFF);
                cpu.write_ovf(result >> 32);
            } else {
                uint64_t rs_val = old_cpu.read_reg(rs.get(), cpu);
                uint64_t rt_val = old_cpu.read_reg(rt.get(), cpu);
                uint64_t result = rs_val * rt_val;
                cpu.write_reg(rd.get(), result & 0xFFFFFFFF);
                cpu.write_ovf(result >> 32);
            }
            break;
        case OTHER_DIV:
            if (signd) {
                int64_t rs_val;
                if (wide) {
                    rs_val = old_cpu.read_reg(rs.get(), cpu);
                    rs_val += ((uint64_t)old_cpu.read_ovf(cpu)) << 32;
                } else {
                    rs_val = (int32_t)old_cpu.read_reg(rs.get(), cpu);
                }
                int32_t rt_val = old_cpu.read_reg(rt.get(), cpu);
                if (rt_val == 0)
                    return exec_result(EXC_DIVIDE_BY_ZERO);
                cpu.write_reg(rd.get(), rs_val / rt_val);
                cpu.write_ovf(rs_val % rt_val);
            } else {
                uint64_t rs_val = old_cpu.read_reg(rs.get(), cpu);
                uint32_t rt_val = old_cpu.read_reg(rt.get(), cpu);
                if (wide) {
                    rs_val += ((uint64_t)old_cpu.read_ovf(cpu)) << 32;
                }
                if (rt_val == 0)
                    return exec_result(EXC_DIVIDE_BY_ZERO);
                cpu.write_reg(rd.get(), rs_val / rt_val);
                cpu.write_ovf(rs_val % rt_val);
            }
            break;
        case OTHER_MFHI:
            cpu.write_reg(rd.get(), old_cpu.read_ovf(cpu));
            break;
        case OTHER_MTHI:
            cpu.write_ovf(old_cpu.read_reg(rs.get(), cpu));
            break;
        case OTHER_MFC:
            if (!old_cpu.read_sys_kmode(cpu)) {
                return exec_result(EXC_INSUFFICIENT_PERMISSIONS);
            }
            cpu.write_reg(rd.get(), old_cpu.read_coreg(rs.get(), cpu));
            break;
        case OTHER_MTC:
            if (!old_cpu.read_sys_kmode(cpu)) {
                return exec_result(EXC_INSUFFICIENT_PERMISSIONS);
            }
            cpu.write_coreg(rd.get(), old_cpu.read_reg(rs.get(), cpu));
            if (rd.get() == CP_PTB) {
                cpu.flush_packet_cache_flag = true;
            }
            break;
        case OTHER_ERET:
            if (!old_cpu.read_sys_kmode(cpu)) {
                return exec_result(EXC_INSUFFICIENT_PERMISSIONS);
            }
            cpu.write_pc(old_cpu.read_coreg(CP_EPC, cpu) & 0xFFFFFFF0);
            cpu.write_sys_kmode(old_cpu.read_coreg(CP_EPC, cpu) & 0x01);
            if (BIT(old_cpu.read_coreg(CP_EPC, cpu), 1)) {
                cpu.write_coreg(CP_PFLAGS,
                                cpu.read_coreg(CP_PFLAGS, cpu) | (1 << PFLAGS_INT_ENABLE));
            } else {
                cpu.write_coreg(CP_PFLAGS,
                                cpu.read_coreg(CP_PFLAGS, cpu) & ~(1 << PFLAGS_INT_ENABLE));
            }
            cpu.write_link(false);
            break;
        case OTHER_FLUSH:
            break;
        default:
            return exec_result(EXC_ILLEGAL_INSTRUCTION);
            break;
    }

    return exec_result(EXC_NO_ERROR);
}

extern uint64_t ovf_mask();
extern uint64_t coreg_mask(uint8_t reg);

uint64_t other_instruction::read_reg_mask() {
    uint64_t result = decoded_instruction::reg_read_mask();

    // TODO: clean this up a bit.
    switch (otherop) {
        case OTHER_MFHI:
            result |= ovf_mask();
            break;
        case OTHER_MFC:
            result |= coreg_mask(rs.get());
            break;
        default:
            break;
    }

    return result;
}

uint64_t other_instruction::write_reg_mask() {
    uint64_t result = decoded_instruction::reg_read_mask();

    // TODO: clean this up a bit.
    switch (otherop) {
        case OTHER_MTHI:
            result |= ovf_mask();
            break;
        case OTHER_MTC:
            result |= coreg_mask(rd.get());
            break;
        default:
            break;
    }

    return result;
}

exec_result branch_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    uint32_t target;
    if (rs) {
        target = old_cpu.read_reg(rs.get().reg, cpu);
    } else {
        target = old_cpu.read_pc(cpu);
    }
    target += this->offset.get();

    target &= ~0xF;
    cpu.write_pc(target);
    if (branch_link) {
        cpu.write_reg(31, old_cpu.read_pc(cpu));
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

std::string branch_instruction::disassemble_inner() {
    if (rs) {
        return branchop_str() + " r" + std::to_string(rs.get().reg) + " + " +
            format_signed_hex(this->offset.get());
    } else {
        return branchop_str() + " " + format_signed_hex(this->offset.get());
    }
}

std::string alu_instruction::opcode_str() {
    std::string result = decoded_instruction::opcode_str() + " - " + ALUOP_STR[aluop];

    if (cmpop) {
        result += " - ";
        result += CMPOP_STR[cmpop.get()];
    }

    return result;
}

std::string alu_instruction::disassemble_inner() {
    std::ostringstream result;
    const std::string op_strs[] = {
        "+", "&", "~|", "|", "-", "-:", "^",
        "", "", "~", "sxb", "sxh", "RESV1", "RESV2", "RESV3", "RESV4",
    };
    const std::string shift_strs[] = {
        "<<", ">>l", ">>a", ">>c",
    };
    const std::string cmpop_strs[] = {
        "<", "<=", "==", "[RESERVERD]", "<s", "<=s", "&", "BC"
    };

    std::string op2;

    if (long_imm) {
        op2 = "long";
    } else if (constant) {
        op2 = string_format("0x%x", constant.get());
    } else if (rs && alu_unary()) {
        op2 = string_format("r%d %s r%d",
                            rt.get().reg, shift_strs[stype.get()].c_str(), rs.get().reg);
    } else {
        op2 = string_format("r%d %s %s",
                            rt.get().reg,
                            shift_strs[stype.get()].c_str(),
                            format_signed_hex(shiftamt.get()).c_str());
    }

    if (aluop == ALU_COMPARE)
        result << string_format("p%d <- ", pd.get().reg);
    else
        result << string_format("r%d <- ", rd.get().reg);
    if (alu_binary()) {
        if (aluop != ALU_COMPARE) {
            result << string_format("r%d ", rs.get().reg) << op_strs[aluop] + " " + op2;
        } else {
            result << string_format("r%d ", rs.get().reg) << cmpop_strs[cmpop.get()] + " " + op2;
        }
    } else {
        if (aluop < NUM_ALU_OPS)
            result << op_strs[aluop] << op2;
        else
            result << "INVALID ALU OP " << aluop;
    }
    return result.str();
}

exec_result alu_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    uint32_t op1, op2;

    if (alu_binary()) {
        // All 2-op forms use rs as the first operand.
        op1 = old_cpu.read_reg(rs.get().reg, cpu);
    }

    // For 2-op forms, we are retrieving the second operand here; for
    // 1-op forms, the only operand is called 'op2'.
    if (constant) {
        // ALU short form
        op2 = constant.get();
    } else if (rs && alu_unary()) {
        // ALU 1-op "regsh" (register shifted by register) form
        op2 = old_cpu.read_reg(rt.get().reg, cpu);
        op2 = shiftwith(op2, old_cpu.read_reg(rs.get().reg, cpu), stype.get());
    } else {
        // ALU register form
        op2 = old_cpu.read_reg(rt.get().reg, cpu);
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

        cpu.write_reg(rd.get().reg, result);
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

        cpu.write_pred(pd.get().reg, result);
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

std::string loadstore_instruction::disassemble_inner() {
    const std::string lsu_strings[] = {
        "b", "h", "l", "ll",
        "b", "h", "l", "sc",
    };
    if (store) {
        return "*" + lsu_strings[lsuop] + "(" + string_format("r%d", rs.get()) + " + " +
            format_signed_hex(offset.get()) + ") <- " + string_format("r%d", rt.get());
    } else {
        return string_format("r%d <- ", rd.get()) + "*" + lsu_strings[lsuop] + "(" +
            string_format("r%d", rs.get()) + " + " + format_signed_hex(offset.get()) + ")";
    }
}

exec_result loadstore_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    uint32_t addr_mask = ~(width - 1);
    uint32_t virt_mem_addr = addr_mask & (old_cpu.read_reg(rs.get(), cpu) + offset.get());
    // We know the operation won't cross a page boundary, because of alignment requirements.
    boost::optional<uint32_t> mem_addr_opt = virt_to_phys(virt_mem_addr, old_cpu, store);
    if (!mem_addr_opt)
        return exec_result(EXC_PAGEFAULT_ON_DATA_ACCESS, virt_mem_addr);

    uint32_t mem_addr = *mem_addr_opt;

    if (store) {
        if (linked) {
            cpu.write_pred(0, old_cpu.read_link(cpu));

            if (!old_cpu.read_link(cpu)) {
                return exec_result(EXC_NO_ERROR);
            }

            cpu.write_link(false);
        }

        uint32_t val = old_cpu.read_reg(rt.get(), cpu);

        if (!cpu.validate_write(mem_addr, val, width))
            return exec_result(EXC_INVALID_PHYSICAL_ADDRESS, virt_mem_addr);

        return exec_result(EXC_NO_ERROR, mem_addr, width, val);
    } else {
        boost::optional<uint32_t> val = boost::none;

        boost::optional<uint32_t> periph_val = cpu.peripherals.read(cpu, mem_addr, width);
        if (periph_val) {
            if (verbose)
                printf("Read handled by peripheral\n");
            cpu.write_reg(rd.get(), *periph_val);
            return exec_result(EXC_NO_ERROR);
        }

        if (mem_addr >= SIM_RAM_BYTES) {
            // XXX: should this really be FATAL? for stores it is a fault
            printf("FATAL: Load/store outside RAM: %x\n", mem_addr);
            abort();
        }

        // Little-endian: copy starting at the msb
        mem_addr += width - 1;

        if (!val) {
            uint32_t read_val = 0;
            for (int i = 0; i < width; ++i) {
                read_val <<= 8;
                read_val += cpu.ram[mem_addr];
                mem_addr--;
            }
            val = read_val;
        }

        cpu.write_reg(rd.get(), *val);

        if (linked) {
            cpu.write_link(true);
        }

        return exec_result(EXC_NO_ERROR);
    }
}
