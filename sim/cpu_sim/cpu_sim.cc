#include <queue>
#include <sstream>
#include <string>

#include <stdio.h>
#include <stdarg.h>
#include <string.h>

#include <boost/optional/optional.hpp>
#include <boost/format.hpp>

// Set bit a through bit b (inclusive), as long as 0 <= a <= 31 and 0 <= b <= 31.
// From http://stackoverflow.com/a/8774613 .
#define BIT_MASK(a, b) (((unsigned) -1 >> (31 - (b))) & ~((1U << (a)) - 1))

#define BITS(word, idx, count) ((word & BIT_MASK(idx, idx + count - 1)) >> idx)
#define BIT(word, idx) BITS(word, idx, 1)

#define array_size(x) (sizeof(x) / sizeof((x)[0]))

typedef uint32_t address_t;
typedef uint32_t data_t;
typedef char lane_t;  // -1 for 'N/A' (i.e. for hardware interrupt events)

struct event {
    lane_t lane;
};

struct mem_event : public event {
    address_t addr;
};

struct mem_read_event : public mem_event {};

struct mem_read_result : public mem_event {
    boost::optional<data_t> data;
};

typedef void (instr_bottom_half)(mem_read_result);

struct mem_write_event : public mem_event {
    data_t data;
    unsigned int byte_enable : 4;
};

struct instruction_continuation {
    mem_read_event query;
    instr_bottom_half k;
};

typedef boost::optional<instruction_continuation> instruction_result;

struct instruction_commit {
    // XXX either up to four registers to commit, OR an exception or interrupt. 
    // XXX don't forget about other things we might need to commit, such as:
    // - link flag
    // - extra-maths register (for div and mul)
    // - PC, in case of a branch
};

typedef uint32_t instruction;
typedef instruction instruction_packet[4];

enum opcode_t {
    OP_B,
    OP_BL,
    OP_BREAK,
    OP_CPOP,
    OP_DIV,
    OP_ERET,
    OP_FENCE,
    OP_LB,
    OP_LH,
    OP_LL,
    OP_LW,
    OP_MFC,
    OP_MFHI,
    OP_MTC,
    OP_MTHI,
    OP_MULT,
    OP_SB,
    OP_SC,
    OP_SH,
    OP_SW,
    OP_SYSCALL,

    // Non-opcodes
    ALU_OP,
    INVALID_OP,
};

const size_t OPCODES_COUNT = INVALID_OP + 1;
const size_t MAX_OPCODE_LEN = 16;

const char OPCODE_STR[][MAX_OPCODE_LEN] = {
    "B",
    "BL",
    "BREAK",
    "CPOP",
    "DIV",
    "ERET",
    "FENCE",
    "LB",
    "LH",
    "LL",
    "LW",
    "MFC",
    "MFHI",
    "MTC",
    "MTHI",
    "MULT",
    "SB",
    "SC",
    "SH",
    "SW",
    "SYSCALL",

    // Non-opcodes
    "<ALU>",
    "<INVALID>"
};
static_assert(array_size(OPCODE_STR) == OPCODES_COUNT, "Opcode count mismatch");

// Must match instruction encoding
enum aluop_t {
    ALU_ADD,
    ALU_AND,
    ALU_NOR,
    ALU_OR,
    ALU_SUB,
    ALU_RSB,
    ALU_XOR,
    ALU_COMPARE,
    ALU_MOV,
    ALU_MVN,
    ALU_SXB,
    ALU_SXH,
    ALU_RESV1,
    ALU_RESV2,
    ALU_RESV3,
    ALU_RESV4
};

const size_t ALUOPS_COUNT = ALU_RESV4 + 1;
static_assert(ALUOPS_COUNT == 16, "Bad alu op list");

const char ALUOP_STR[][MAX_OPCODE_LEN] = {
    "ADD",
    "AND",
    "NOR",
    "OR",
    "SUB",
    "RSB",
    "XOR",
    "<COMPARE>",
    "MOV",
    "MVN",
    "SXB",
    "SXH",
    "<RESERVED 1>",
    "<RESERVED 2>",
    "<RESERVED 3>",
    "<RESERVED 4>"
};
static_assert(array_size(ALUOP_STR) == ALUOPS_COUNT, "Aluops count mismatch");

// Must match instruction encoding
enum cmpop_t {
    CMP_LTU,
    CMP_LEU,
    CMP_EQ,
    CMP_RESV,
    CMP_LTS,
    CMP_LES,
    CMP_BS,
    CMP_BC
};

const size_t CMPOPS_COUNT = CMP_BC + 1;
static_assert(CMPOPS_COUNT == 8, "Bad cmp op list");

const char CMPOP_STR[][MAX_OPCODE_LEN] = {
    "LTU",
    "LEU",
    "EQ",
    "<RESERVED>",
    "LTS",
    "LES",
    "BS",
    "BC"
};
static_assert(array_size(CMPOP_STR) == CMPOPS_COUNT, "Cmpops count mismatch");


struct reg_t {
    unsigned int reg:5;

    reg_t (unsigned int r) : reg(r) {}
    operator int() { return reg; }
};

struct pred_reg_t {
    unsigned int reg:2;

    pred_reg_t (unsigned int r) : reg(r) {}
    operator int() { return reg; }
};


// From StackOverflow user Erik Aronesty, http://stackoverflow.com/a/8098080 .
std::string string_format(const std::string fmt_str, ...) {
    int final_n, n = ((int)fmt_str.size()) * 2; /* reserve 2 times as much as the length of the fmt_str */
    std::string str;
    std::unique_ptr<char[]> formatted;
    va_list ap;
    while(1) {
        formatted.reset(new char[n]); /* wrap the plain char array into the unique_ptr */
        strcpy(&formatted[0], fmt_str.c_str());
        va_start(ap, fmt_str);
        final_n = vsnprintf(&formatted[0], n, fmt_str.c_str(), ap);
        va_end(ap);
        if (final_n < 0 || final_n >= n)
            n += abs(final_n - n + 1);
        else
            break;
    }
    return std::string(formatted.get());
}

struct decoded_instruction {
    uint32_t raw_instr;  // For debugging

    pred_reg_t pred_reg = 0;
    bool pred_comp;
    opcode_t opcode = INVALID_OP;
    boost::optional<aluop_t> aluop;
    boost::optional<cmpop_t> cmpop;
    boost::optional<uint32_t> constant;
    boost::optional<int32_t> offset;
    boost::optional<reg_t> rs;
    boost::optional<reg_t> rd;
    boost::optional<reg_t> rt;
    boost::optional<pred_reg_t> pd;
    boost::optional<uint32_t> shiftamt;
    boost::optional<uint32_t> stype;
    bool long_imm = false;

    bool alu_unary() {
        return aluop && aluop > ALU_COMPARE;
    }

    bool alu_binary() {
        return aluop && aluop <= ALU_COMPARE;
    }

    bool alu_compare() {
        return aluop && aluop == ALU_COMPARE;
    }

    std::string opcode_str() {
        std::ostringstream result;

        if (opcode < OPCODES_COUNT) {
            result << OPCODE_STR[opcode];
        } else {
            result << OPCODE_STR[INVALID_OP];
            return result.str();
        }

        if (aluop) {
            result << " - " << ALUOP_STR[aluop.get()];
        }

        if (cmpop) {
            result << " - " << CMPOP_STR[cmpop.get()];
        }

        return result.str();
    }

    std::string to_string() {
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
        if (pd)
            result << string_format("  * pd = %d\n", pd->reg);
        if (long_imm)
            result << "  * [long immediate]\n";

        return result.str();
    }
};

struct decoded_packet {
    decoded_instruction instr[4];

    std::string to_string() {
        std::ostringstream result;
        for (int i = 0; i < 4; ++i) {
            result << string_format("%s", instr[i].to_string().c_str());
        }
        return result.str();
    }
};

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

/*

First sample program (trivial infinite loop):

asm:    B $0 (P3) / NOP / NOP / NOP (Expressing NOP as ADD R0 <- R0 + R0 (!P3))
binary: 110 1100 0000000000000000000000000 / (111 0 0000000000 0000 0000 00000 00000) *3
hex:    D800 0000 / (E000 0000) *3


Second sample program (infinite loop with counter):

asm:    B $0 (P3) / ADD R0 <- R0 + 0x1 (P3) / NOP / NOP
binary: 110 1100 0000000000000000000000000 / 110 0 0000000001 0000 0000 00000 00000 / NOP*2
hex:    D800 0000 / C004 0000 / (E000 0000) *2


Third sample program (testing rotated constants):

asm:    ADD R0 <- R0 + (0x1 ROT 0x0)  = 0x00000001 /
        ADD R1 <- R1 + (0x1 ROT 0x2)  = 0x40000000 /
        ADD R2 <- R2 + (0x1 ROT 0x16) = 0x00000400 /
        ADD R3 <- R3 + (0x200 ROT 0x0) = 0x00000200
binary: 110 0 0000000001 0000 0000 00000 00000 /
        110 0 0000000001 0001 0000 00001 00001 /
        110 0 0000000001 1011 0000 00010 00010 /
        110 0 1000000000 0000 0000 00011 00011
hex:    C004 0000 / C004 4021 / C006 C042 / C800 0063
*/

instruction ROM[] = {
    0xC0040000, 0xC0044021, 0xC006C042, 0xC8000063,
    0xE0000000, 0xE0000000, 0xE0000000, 0xE0000000
};
size_t ROMLEN = array_size(ROM);

// Order must match instruction encoding
enum shift_type {
    LSL,
    LSR,
    ASR,
    ROR
};


// Instruction (and instruction packet) decoding

decoded_instruction decode_instruction(instruction instr) {
    decoded_instruction result;
    result.raw_instr = instr;

    result.pred_reg = BITS(instr, 30, 2);
    result.pred_comp = BITS(instr, 29, 1);

    aluop_t aluop = (aluop_t)BITS(instr, 10, 4);
    cmpop_t cmpop = (cmpop_t)BITS(instr, 7, 3);

    uint32_t rs_num = BITS(instr, 0, 5);
    uint32_t rd_num = BITS(instr, 5, 5);
    uint32_t rt_num = BITS(instr, 14, 5);
    uint32_t pd_num = BITS(instr, 5, 2);

    if (BIT(instr, 28)) {
        if (BIT(instr, 27)) {
            // BRANCH OR BRANCH/LINK
            if (BIT(instr, 26)) {
                result.offset = BITS(instr, 5, 20);
                result.rs = rs_num;
            } else {
                result.offset = BITS(instr, 0, 25);
            }

            if (BIT(instr, 25)) {
                // BRANCH/LINK
                result.opcode = OP_BL;
            } else {
                // BRANCH (PLAIN)
                result.opcode = OP_B;
            }
        } else {
            if (BIT(instr, 26)) {
                // ALU REG
                result.opcode = ALU_OP;
                result.aluop = aluop;

                if (aluop == ALU_COMPARE) {
                    result.cmpop = cmpop;
                    result.pd = pd_num;
                } else {
                    result.rd = rd_num;
                }
            } else {
                if (BIT(instr, 25)) {
                    // LOAD/STORE
                } else {
                    if (BIT(instr, 24)) {
                        // OTHER
                    } else {
                        // ALU FUNKY OR UNDEFINED OPCODE
                    }
                }
            }
        }
    } else {
        // ALU SHORT
        result.opcode = ALU_OP;
        result.aluop = aluop;

        if (aluop == ALU_COMPARE) {
            result.cmpop = cmpop;
            result.pd = pd_num;
        } else {
            result.rd = rd_num;
        }

        uint32_t constant = BITS(instr, 18, 10);
        uint32_t rotate = BITS(instr, 14, 4);

        if (result.alu_unary()) {
            // Last 5 bits are high bits of constant
            constant |= (rs_num << 10);
        } else {
            // Last 5 bits are source register number
            result.rs = rs_num;
        }

        result.constant = (constant >> (rotate * 2)) | (constant << (32 - rotate * 2));
    }

    return result;
}

decoded_packet decode_packet(instruction_packet packet) {
    decoded_packet result;

    for (int i = 0; i < 4; ++i) {
        result.instr[i] = decode_instruction(packet[i]);
    }
    return result;
}

struct regs_t {
    uint32_t r[32];
    uint32_t pc;
};
regs_t regs;

uint32_t shiftwith(uint32_t value, uint32_t shiftamt, shift_type stype) {
    switch(stype) {
        case LSL:
            return value << shiftamt;
        case LSR:
            return value >> shiftamt;
        case ASR:
            return ((int32_t)value) >> shiftamt;
        case ROR:
            return (value >> shiftamt) | (value << (32 - shiftamt));
    }
}

// Instruction (and instruction packet) execution

void execute_instruction(decoded_instruction instr, uint32_t old_pc) {
    if (instr.opcode == OP_B) {
        regs.pc = old_pc;
        regs.pc += instr.offset.get();
        if (instr.rs) {
            regs.pc += regs.r[instr.rs.get().reg];
        }
    } else if (instr.opcode == ALU_OP && instr.aluop == ALU_ADD) {
        uint32_t total = 0;

        if (instr.rs) {
            total += regs.r[instr.rs.get().reg];
        }
        if (instr.constant) {
            total += instr.constant.get();
        }
        if (instr.rt) {
            total += shiftwith(regs.r[instr.rt.get().reg], instr.shiftamt.get(), (shift_type)instr.stype.get());
        }

        regs.r[instr.rd.get().reg] = total;
    }
}

void execute_packet(decoded_packet packet) {
    uint32_t saved_pc = regs.pc;
    regs.pc += 4;

    for (int i = 0; i < 4; ++i) {
        execute_instruction(packet.instr[i], saved_pc);
    }
}


// Driver / testing stub

int main(int argc, char** argv) {
    printf("OSOROM simulator starting\n");

    while(regs.pc < ROMLEN) {
        printf("regs.pc is now 0x%x\n", regs.pc);
        printf("regs.r = { ");
        for (int i = 0; i < 32; ++i) {
            printf("%x, ", regs.r[i]);
        }
        printf("}\n");
        printf("Packet is %x / %x / %x / %x\n", ROM[regs.pc+0], ROM[regs.pc+1], ROM[regs.pc+2], ROM[regs.pc+3]);
        decoded_packet packet = decode_packet(&ROM[regs.pc]);
        printf("Packet looks like:\n");
        printf("%s", packet.to_string().c_str());
        printf("Executing packet...\n");
        execute_packet(packet);
        printf("...done.\n");
    }

    printf("OROSOM simulator terminating\n");
}
