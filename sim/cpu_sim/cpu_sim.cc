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
        result << string_format("  * shiftamt = %d (%x)\n", shiftamt.get());
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
            // Sign extend and left-shift by 4 bits;
            result->offset = (result->offset.get() << 12) >> 8;
            result->rs = rs_num;
        } else {
            result->offset = BITS(instr, 0, 25);
            // Sign extend and left-shift by 4 bits;
            result->offset = (result->offset.get() << 7) >> 3;
        }
    } else if (BIT(instr, 26)) {
        // ALU REG
        shared_ptr<alu_instruction> alu(new alu_instruction());
        result = alu;

        result->optype = ALU_OP;
        alu->aluop = aluop;
        result->rs = rs_num;
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
        result->rs = rs_num;

        if (BIT(instr, 12)) {
            // STORE
            result->rt = rt_num;
            result->offset = BITS(instr, 5, 5) | (BIT(instr, 13) << 5) | (BITS(instr, 19, 6) < 6);
        } else {
            // LOAD
            result->rd = rd_num;
            result->offset = BITS(instr, 13, 12);
        }
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
        return pred_comp ^ cpu.regs.p[pred_reg.reg];
    }
}

bool decoded_instruction::execute(cpu_t &cpu, cpu_t &old_cpu) {
    return false;
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
        if (this->instr[i]->long_imm) {
            if (i == 3) {
                printf("ERROR: Invalid long imm in slot 3! XXX (this should cause an exception)\n");
            } else {
                this->instr[i]->constant = packet[i + 1];
                ++i;
                this->instr[i] = shared_ptr<no_instruction>(new no_instruction(packet[i]));
            }
        }
    }
}

bool decoded_packet::execute(cpu_t &cpu) {
    cpu_t old_cpu = cpu;
    cpu.regs.pc += 4;

    for (int i = 0; i < 4; ++i) {
        if(this->instr[i]->execute(cpu, old_cpu)) {
            return true;
        }
    }

    return false;
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
