#include "cpu_sim.h"
#include "cpu_sim_ops.h"
#include "cpu_sim_utils.h"


#include <queue>
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

// Returns the value of a register, including coprocessor registers and
// anything else, indexed by their number in the trace file.
uint32_t cpu_t::reg_value(uint32_t reg) {
    if (reg < 32)
        return regs.r[reg];
    else if (reg < 32 + 16)
        return regs.cpr[reg - 32];
    else if (reg < 32 + 20)
        return regs.cpr[reg - 32 + (16 - 9)];
    else if (reg == 32 + 20)
        return regs.ovf;
    else
        return regs.p[reg - 32 - 20];
}

uint64_t reg_mask(uint8_t reg) {
    return (((uint64_t)1) << reg);
}

uint64_t coreg_mask(uint8_t coreg) {
    if (coreg >= 16)
        return (((uint64_t)1) << (coreg + 32 - (16 - 9)));
    else
        return (((uint64_t)1) << (coreg + 32));
}

uint64_t ovf_mask() {
    return (((uint64_t)1) << (32 + 20));
}

uint64_t pred_mask(uint8_t pred) {
    return (((uint64_t)1) << (32 + 20 + 1 + pred));
}

void cpu_t::write_reg(uint8_t reg, uint32_t val) {
    reg_write_mask |= reg_mask(reg);
    regs.r[reg] = val;
}

uint32_t cpu_t::read_reg(uint8_t reg, cpu_t &new_cpu) {
    new_cpu.reg_read_mask |= reg_mask(reg);
    return regs.r[reg];
}

void cpu_t::write_coreg(uint8_t reg, uint32_t val) {
    reg_write_mask |= coreg_mask(reg);
    regs.cpr[reg] = val;
}

uint32_t cpu_t::read_coreg(uint8_t reg, cpu_t &new_cpu) {
    new_cpu.reg_read_mask |= coreg_mask(reg);
    return regs.cpr[reg];
}

void cpu_t::write_pred(uint8_t reg, bool val) {
    reg_write_mask |= pred_mask(reg);
    regs.p[reg] = val;
}

bool cpu_t::read_pred(uint8_t reg, cpu_t &new_cpu) {
    new_cpu.reg_read_mask |= pred_mask(reg);
    return regs.p[reg];
}

void cpu_t::write_ovf(uint32_t val) {
    reg_write_mask |= ovf_mask();
    regs.ovf = val;
}

uint32_t cpu_t::read_ovf(cpu_t &new_cpu) {
    new_cpu.reg_read_mask |= ovf_mask();
    return regs.ovf;
}

void cpu_t::write_pc(uint32_t val) {
    regs.pc = val;
}

uint32_t cpu_t::read_pc(cpu_t &new_cpu) {
    return regs.pc;
}

void cpu_t::write_link(bool val) {
    regs.link = val;
}

bool cpu_t::read_link(cpu_t &new_cpu) {
    return regs.link;
}

void cpu_t::write_sys_kmode(bool val) {
    regs.sys_kmode = val;
}

bool cpu_t::read_sys_kmode(cpu_t &new_cpu) {
    return regs.sys_kmode;
}

std::string decoded_instruction::opcode_str() {
    return std::string(OPTYPE_STR[optype]);
}

std::string decoded_instruction::to_string() {
    std::ostringstream result;
    result << string_format("- Instruction (%x):", raw_instr);
    if (raw_instr == 0xe0000000) {
        result << " NOP\n";
        return result.str();
    } else if (pred_reg.reg == 3 && pred_comp) {
        result << "\n  ** Instruction looks NOPpish **\n";
    } else {
        result << "\n";
    }

    result << string_format("  * [%cP%d] %s\n", pred_comp ? '~' : ' ', pred_reg.reg, opcode_str().c_str());
    if (constant)
        result << string_format("  * constant = %d (%x)\n", constant.get(), constant.get());
    if (offset)
        result << string_format("  * offset = %d (%x)\n", offset.get(), offset.get());
    if (rs)
        result << string_format("  * rs = %d\n", rs->reg);
    if (rd)
        result << string_format("  * rd = %d\n", rd->reg);
    if (rt)
        result << string_format("  * rt = %d\n", rt->reg);
    if (shiftamt)
        result << string_format("  * shiftamt = %d (%x)\n", shiftamt.get(), shiftamt.get());
    if (stype)
        result << string_format("  * stype = %x\n", stype.get());
    if (long_imm)
        result << "  * [long immediate]\n";

    return result.str();
}

shared_ptr<decoded_instruction> decoded_instruction::decode_instruction(instruction instr) {
    shared_ptr<decoded_instruction> result(new decoded_instruction());

    aluop_t aluop = (aluop_t)BITS(instr, 10, 4);
    cmpop_t cmpop = (cmpop_t)BITS(instr, 7, 3);

    uint32_t rs_num = BITS(instr, 0, 5);
    uint32_t rd_num = BITS(instr, 5, 5);
    uint32_t rt_num = BITS(instr, 14, 5);
    uint32_t pd_num = BITS(instr, 5, 2);

    if (BIT(instr, 28) == 0x0) {
        // ALU SHORT
        shared_ptr<alu_instruction> alu(new alu_instruction());
        result = alu;

        result->optype = ALU_OP;
        alu->aluop = aluop;

        if (aluop == ALU_COMPARE) {
            alu->cmpop = cmpop;
            alu->pd = pd_num;
        } else {
            result->rd = rd_num;
        }

        uint32_t constant = BITS(instr, 18, 10);
        uint32_t rotate = BITS(instr, 14, 4);

        if (alu->alu_unary()) {
            // Last 5 bits are high bits of constant
            constant |= (rs_num << 10);
        } else {
            // Last 5 bits are source register number
            result->rs = rs_num;
        }

        result->constant = (constant >> (rotate * 2)) | (constant << (32 - rotate * 2));
    } else if (BIT(instr, 27)) {
        // BRANCH OR BRANCH/LINK
        shared_ptr<branch_instruction> branch(new branch_instruction());
        result = branch;

        result->optype = BRANCH_OP;
        branch->branch_link = BIT(instr, 25);

        if (BIT(instr, 26)) {
            result->offset = BITS(instr, 5, 20);
            result->offset = SIGN_EXTEND_32(result->offset.get(), 20) << 4;
            result->rs = rs_num;
        } else {
            result->offset = BITS(instr, 0, 25);
            result->offset = SIGN_EXTEND_32(result->offset.get(), 25) << 4;
        }
    } else if (BIT(instr, 26)) {
        // ALU REG
        shared_ptr<alu_instruction> alu(new alu_instruction());
        result = alu;

        result->optype = ALU_OP;
        alu->aluop = aluop;

        if (alu->alu_binary()) {
            result->rs = rs_num;
        }
        result->rt = rt_num;
        result->shiftamt = BITS(instr, 21, 5);
        result->stype = (shift_type)BITS(instr, 19, 2);

        if (aluop == ALU_COMPARE) {
            alu->cmpop = cmpop;
            alu->pd = pd_num;
        } else {
            result->rd = rd_num;
        }
    } else if (BIT(instr, 25)) {
        // LOAD/STORE
        shared_ptr<loadstore_instruction> loadstore(new loadstore_instruction());
        result = loadstore;
        result->optype = LSU_OP;

        loadstore->lsuop = (lsuop_t)BITS(instr, 10, 3);

        switch (loadstore->lsuop & 0x3) {
            case 0x0:
                loadstore->width = 1;
                break;
            case 0x1:
                loadstore->width = 2;
                break;
            case 0x2:
            case 0x3:
                loadstore->width = 4;
                break;
        }
        loadstore->store = loadstore->lsuop >> 2;
        loadstore->linked = (loadstore->lsuop & 0x3) == 0x3;

        result->rs = rs_num;

        if (BIT(instr, 12)) {
            // STORE
            result->rt = rt_num;
            result->offset = BITS(instr, 5, 5) | (BIT(instr, 13) << 5) | (BITS(instr, 19, 6) << 6);
        } else {
            // LOAD
            result->rd = rd_num;
            result->offset = BITS(instr, 13, 12);
        }
        result->offset = SIGN_EXTEND_32(result->offset.get(), 12);
    } else if (BIT(instr, 24)) {
        // OTHER OPCODE
        shared_ptr<other_instruction> other(new other_instruction());
        result = other;

        result->optype = OTHER_OP;
        other->otherop = (otherop_t)BITS(instr, 20, 4);

        result->rs = rs_num;
        result->rd = rd_num;
        result->rt = rt_num;
        other->reserved_bits = (BIT(instr, 19) << 4) | BITS(instr, 10, 4);
        other->signd = (other->reserved_bits & 0x10) >> 4;
    } else if (BITS(instr, 21, 3) == 0x1) {
        // ALU 1OP REGSH
        shared_ptr<alu_instruction> alu(new alu_instruction());
        result = alu;

        result->optype = ALU_OP;
        alu->aluop = aluop;
        result->rs = rs_num;
        result->rd = rd_num;
        result->rt = rt_num;
        result->stype = (shift_type)BITS(instr, 19, 2);
    } else if (BITS(instr, 14, 10) == 0x000) {
        // ALU W/ LONG IMM
        shared_ptr<alu_instruction> alu(new alu_instruction());
        result = alu;

        result->optype = ALU_OP;
        alu->aluop = aluop;
        result->rs = rs_num;
        result->rd = rd_num;
        result->long_imm = true;
        // Long immediate is in the following instruction slot; it will be extracted separately.
    } else {
        // UNDEFINED OP / BAD ENCODING
        result->optype = INVALID_OP;
    }

    // Set these at the end, since we may reset 'result' to point to an object of subclass type.
    result->raw_instr = instr;

    result->pred_reg = BITS(instr, 30, 2);
    result->pred_comp = BITS(instr, 29, 1);

    return result;
}

bool decoded_instruction::predicate_ok(cpu_t &cpu) {
    if (pred_reg.reg == 3) {
        return !pred_comp;
    } else {
        return pred_comp ^ cpu.read_pred(pred_reg.reg, cpu);
    }
}

uint64_t decoded_instruction::reg_read_mask() {
    uint64_t result = 0;

    if (rs) {
        result |= (1 << (*rs).reg);
    }
    if (rt) {
        result |= (1 << (*rt).reg);
    }

    return result;
}

uint64_t decoded_instruction::reg_write_mask() {
    uint64_t result = 0;
    if (rd) {
        result |= (1<< (*rd).reg);
    }

    return result;
}

exec_result decoded_instruction::execute_unconditional(cpu_t &cpu, cpu_t &old_cpu) {
    // Override in subclasses. If we hit this default implementation, it means we failed
    // to decode the instruction.
    return exec_result(EXC_ILLEGAL_INSTRUCTION);
}

exec_result decoded_instruction::execute(cpu_t &cpu, cpu_t &old_cpu) {
    if (!predicate_ok(old_cpu)) {
        return exec_result(EXC_NO_ERROR);
    }
    return this->execute_unconditional(cpu, old_cpu);
}

std::string decoded_packet::to_string() {
    std::ostringstream result;
    for (int i = 0; i < 4; ++i) {
        result << string_format("%s", instr[i]->to_string().c_str());
    }
    return result.str();
}

decoded_packet::decoded_packet(instruction_packet packet) {
    for (int i = 0; i < 4; ++i) {
        this->instr[i] = decoded_instruction::decode_instruction(packet[i]);
        // TODO: enforce slots for other kinds of instructions.
        if (this->instr[i]->long_imm) {
            if (i == 3) {
                // There's a long in slot 3. Replace it with an invalid instruction to ensure that
                // we cause an exception.
                this->instr[i] = shared_ptr<decoded_instruction>(new decoded_instruction());
                this->instr[i]->optype = INVALID_OP;
            } else {
                this->instr[i]->constant = packet[i + 1];
                ++i;
                this->instr[i] = shared_ptr<no_instruction>(new no_instruction(packet[i]));
            }
        }
    }
}

void cpu_t::clear_exceptions() {
    for (int i = 0; i < 4; ++i)
        write_coreg(CP_EC0 + i, 0);
    for (int i = 0; i < 2; ++i)
        write_coreg(CP_EA0 + i, 0);
}

bool cpu_t::process_peripherals() {
    bool interrupt_fired = false;
    for (int i = 0; i < peripherals.size(); i++) {
        if (peripherals[i]->process(*this)) {
            interrupt_fired = true;
        }
    }

    return interrupt_fired;
}

bool cpu_t::validate_write(uint32_t addr, uint32_t val, uint8_t width) {
    for (int i = 0; i < peripherals.size(); i++)
    {
        if (peripherals[i]->check_write(*this, addr, val, width)) {
            return true;
        }
    }

    for (int i = 0; i < width; ++i) {
        if (addr + i >= SIM_RAM_BYTES) {
            return false;
        }
    }

    return true;
}

bool decoded_packet::execute(cpu_t &cpu) {
    cpu_t old_cpu = cpu;
    cpu.write_pc(cpu.read_pc(cpu) + 0x10);
    boost::optional<mem_write_t> writes[2];
    exec_result results[4];

    bool exception = false;

    for (int i = 0; i < 4; ++i) {
        results[i] = this->instr[i]->execute(cpu, old_cpu);
        if (results[i].exception != EXC_NO_ERROR) {
            // There was an exception. Clear error state in each lane.
            // We'll write the exceptions into the appropriate registers later.
            exception = true;
            old_cpu.clear_exceptions();
            break;
        }
    }

    for (int i = 0; i < 4; ++i) {
        if (results[i].exception == EXC_HALT) {
            cpu.halted = true;
            return false;
        }
        assert(i < 2 || !results[i].mem_write);
        assert(results[i].exception == EXC_NO_ERROR || !results[i].mem_write);
        if (results[i].exception == EXC_NO_ERROR && i < 2) {
            writes[i] = results[i].mem_write;
        }
        if (results[i].exception != EXC_NO_ERROR) {
            printf("Exception %d in slot %d\n", results[i].exception, i);
            old_cpu.write_coreg(CP_EC0 + i, results[i].exception);
            if (results[i].fault_address) {
                assert(i < 2);
                old_cpu.write_coreg(CP_EA0 + i, *results[i].fault_address);
            }
        }
    }

    if (exception) {
        // Roll back the state. Note that error flags were all set in old_cpu,
        // so we don't lose them.
        cpu = old_cpu;
    } else {
        // Resolve all writes.
        for (int i = 0; i < 2; ++i) {
            if (writes[i]) {
                mem_write_t mem_write = *writes[i];
                bool handled = false;
                for (int i = 0; i < cpu.peripherals.size(); i++) {
                    handled = cpu.peripherals[i]->write(cpu,
                                                        mem_write.addr,
                                                        mem_write.val,
                                                        mem_write.width);
                    if (handled && verbose) {
                        printf("Write handled by %s\n", cpu.peripherals[i]->name().c_str());
                        break;
                    }
                }
                if (!handled) {
                    // Note: error checking was already done.
                    for (int j = 0; j < mem_write.width; ++j) {
                        cpu.ram[mem_write.addr + j] = mem_write.val & 0xFF;
                        mem_write.val >>= 8;
                    }
                }
            }
        }
    }
    return exception;
}

uint64_t decoded_packet::reg_read_mask() {
    uint64_t result = 0;
    for (int i = 0; i < 4; i++) {
        result |= instr[i]->reg_read_mask();
    }

    return result;
}

uint64_t decoded_packet::reg_write_mask() {
    uint64_t result = 0;
    for (int i = 0; i < 4; i++) {
        result |= instr[i]->reg_write_mask();
    }

    return result;
}

typedef uint32_t pd_entry_t;
typedef uint32_t pt_entry_t;

boost::optional<uint32_t> virt_to_phys(uint32_t addr, cpu_t &cpu, const bool store) {
    /* Returns a boost::optional containing the physical address corresponding to the given
     * virtual address, or none if this would cause a fault.
     */
    uint32_t pflags = cpu.read_coreg(CP_PFLAGS, cpu);
    uint32_t ptbr = cpu.read_coreg(CP_PTB, cpu);

    if (!BIT(pflags, PFLAGS_PAGING_ENABLE)) {
        // Paging disabled.
        return addr;
    }

    uint32_t pd_index = BITS(addr, 22, 10);
    uint32_t pt_index = BITS(addr, 12, 10);
    uint32_t page_offset = BITS(addr, 0, 12);

    pd_entry_t *ptb = (pd_entry_t *)(cpu.ram + ptbr);
    pd_entry_t pd_entry = ptb[pd_index];

    bool pd_present = BIT(pd_entry, 0);
    if (!pd_present) {
        return boost::none;
    }
    uint32_t pt_addr = BITS(pd_entry, 12, 17) << 12;
    bool pd_write = BIT(pd_entry, 1);
    bool pd_kmode = BIT(pd_entry, 2);

    pt_entry_t *pt = (pt_entry_t *)(cpu.ram + pt_addr);
    pt_entry_t pt_entry = pt[pt_index];

    bool pt_present = BIT(pt_entry, 0);
    if (!pt_present) {
        return boost::none;
    }
    uint32_t page_addr = pt_entry & BITS(pt_entry, 12, 20) << 12;
    bool pt_write = BIT(pt_entry, 1);
    bool pt_kmode = BIT(pt_entry, 2);

    if (!cpu.read_sys_kmode(cpu) && (pt_kmode || pd_kmode)) {
        // Attempting to access kernel mode memory while in user mode.
        return boost::none;
    }

    if (store && !(pt_write && pd_write)) {
        // Attempting to write to a non-writable page.
        return boost::none;
    }

    return page_addr + page_offset;
}


// These are for interfacing between the simulator and the 'outside world'. We have three modes:
//   * In 'cmodel mode', we simulate the CPU, and interface with a mixed Verilog/C++ implementation of the rest of the
//     world. We send memory reads and writes to the outside world, pause execution and return control to the driver
//     when we can make no further progress, and resume executing (coroutine-style) when a cycle contains a memory read
//     result for us.
//   * In 'lockstep mode', we simulate the CPU alongside a Verilog implemention of the CPU. We take our cues from the 
//     Verilog version -- it feeds us memory reads and writes, and the results, as well as the register file commits
//     that happen during each instruction. We merely check these against our own. The only time we should be
//     'surprised' is in the event of a hardware interrupt, which we'll receive in place of register file commits as
//     the 'outcome' of an instruction.
//   * In 'freestanding mode', we run the whole world ourselves. This entails simulating an MMU, which is not required 
//     in the other modes, as well as memory, and providing a way to load memory contents at startup, and emulating
//     devices if need be.
std::queue<mem_read_event> instruction_fetch_queue;
std::queue<mem_event> mem_request_queue[2];
std::queue<mem_read_result> mem_result_queue[2];
std::queue<instruction_commit> instruction_commit_queue;

