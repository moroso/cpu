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
    ADD,
    AND,
    B,
    BL,
    BREAK,
    CMPBC,
    CMPBS,
    CMPEQ,
    CMPLES,
    CMPLEU,
    CMPLTS,
    CMPLTU,
    CPOP,
    DIV,
    ERET,
    FENCE,
    LB,
    LH,
    LL,
    LW,
    MFC,
    MFHI,
    MOV,
    MTC,
    MTHI,
    MVN,
    MULT,
    NOR,
    OR,
    RSB,
    SB,
    SC,
    SH,
    SUB,
    SW,
    SXB,
    SXH,
    SYSCALL,
    XOR,

    // Non-opcodes
    COMPARE_OP,
    INVALID_OP,
};

const size_t OPCODES_COUNT = INVALID_OP + 1;
const size_t MAX_OPCODE_LEN = 16;

const char OPCODE_STR[][MAX_OPCODE_LEN] = {
    "ADD",
    "AND",
    "B",
    "BL",
    "BREAK",
    "CMPBC",
    "CMPBS",
    "CMPEQ",
    "CMPLES",
    "CMPLEU",
    "CMPLTS",
    "CMPLTU",
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
    "MOV",
    "MTC",
    "MTHI",
    "MVN",
    "MULT",
    "NOR",
    "OR",
    "RSB",
    "SB",
    "SC",
    "SH",
    "SUB",
    "SW",
    "SXB",
    "SXH",
    "SYSCALL",
    "XOR",

    // Non-opcodes
    "<COMPARE>",
    "<INVALID>"
};
static_assert(array_size(OPCODE_STR) == OPCODES_COUNT, "Opcode count mismatch");

struct reg_t {
    unsigned int reg:5;

    reg_t (unsigned int r) : reg(r) {}
};


// Pretty-printing

const char *opcode_str(opcode_t opcode) {
    if (opcode < OPCODES_COUNT) {
        return OPCODE_STR[opcode];
    } else {
        return OPCODE_STR[INVALID_OP];
    }
}


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

    unsigned int pred_reg:2;
    bool pred_comp;
    opcode_t opcode = INVALID_OP;
    boost::optional<uint32_t> constant;
    boost::optional<int32_t> offset;
    boost::optional<reg_t> rs;
    boost::optional<reg_t> rd;
    boost::optional<reg_t> rt;
    bool long_imm = false;

    bool is_cmp() {
        return opcode >= CMPBC && opcode <= CMPLTU;
    }

    std::string to_string() {
        std::ostringstream result;
        result << string_format("- Instruction (%x):\n", raw_instr);
        result << string_format("  * [%cP%d] %s\n", pred_comp ? '~' : ' ', pred_reg, opcode_str(opcode));
        if (constant)
            result << string_format("  * constant = %d\n", constant.get());
        if (offset)
            result << string_format("  * offset = %d\n", offset.get());
        if (rs)
            result << string_format("  * rs = %d\n", rs->reg);
        if (rd)
            result << string_format("  * rd = %d\n", rd->reg);
        if (rt)
            result << string_format("  * rt = %d\n", rt->reg);
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

*/

instruction_packet ROM[] = { 0xD8000000, 0xC0040000, 0xE0000000, 0xE0000000 };


// ALU (and comparison) ops

const opcode_t ALUOPS[] = {
    ADD,
    AND,
    NOR,
    OR,
    SUB,
    RSB,
    XOR,
    COMPARE_OP,
    MOV,
    MVN,
    SXB,
    SXH
};
const size_t ALUOPS_COUNT = array_size(ALUOPS);

const opcode_t CMPOPS[] = {
    CMPLTU,
    CMPLEU,
    CMPEQ,
    INVALID_OP,
    CMPLTS,
    CMPLES,
    CMPBS,
    CMPBC,
};
const size_t CMPOPS_COUNT = array_size(CMPOPS);

opcode_t decode_aluop(uint32_t bits) {
    if (bits < ALUOPS_COUNT) {
        return ALUOPS[bits];
    } else {
        return INVALID_OP;
    }
}

opcode_t decode_cmpop(uint32_t bits) {
    if (bits < CMPOPS_COUNT) {
        return CMPOPS[bits];
    } else {
        return INVALID_OP;
    }
}


// Instruction (and instruction packet) decoding

decoded_instruction decode_instruction(instruction instr) {
    printf("decoding instruction %x\n", instr);
    decoded_instruction result;
    result.raw_instr = instr;

    result.pred_reg = BITS(instr, 30, 2);
    result.pred_comp = BITS(instr, 29, 1);

    opcode_t aluop = decode_aluop(BITS(instr, 10, 4));
    opcode_t cmpop = decode_cmpop(BITS(instr, 7, 3));

    uint32_t rs_num = BITS(instr, 0, 5);
    uint32_t rd_num = BITS(instr, 5, 5);
    uint32_t rt_num = BITS(instr, 14, 5);

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
                result.opcode = BL;
            } else {
                // BRANCH (PLAIN)
                result.opcode = B;
            }
        } else {
            if (BIT(instr, 26)) {
                // ALU REG
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
        if (aluop == COMPARE_OP) {
            result.opcode = cmpop;
        } else {
            result.opcode = aluop;
        }

        uint32_t constant = BITS(instr, 18, 10);
        uint32_t rotate = BITS(instr, 14, 4);
        result.constant = constant << (rotate * 2);
        result.rs = rs_num;
        result.rd = rd_num;
    }

    printf("decoded result pp:\n%s", result.to_string().c_str());
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

uint32_t shiftwith(uint32_t value, uint32_t shiftamt, uint32_t shf) {
    return value; // XXX
}

// Instruction (and instruction packet) execution

void execute_instruction(decoded_instruction instr, uint32_t old_pc) {
    if (instr.opcode == B) {
        regs.pc = old_pc;
        regs.pc += instr.offset.get();
        if (instr.rs) {
            regs.pc += regs.r[instr.rs.get().reg];
        }
    } else if (instr.opcode == ADD) {
        uint32_t total = 0;

        if (instr.rs) {
            total += regs.r[instr.rs.get().reg];
        }
        if (instr.constant) {
            total += instr.constant.get();
        }
        if (instr.rt) {
            total += shiftwith(regs.r[instr.rt.get().reg], 0, 0); // XXX
        }

        regs.r[instr.rd.get().reg] = total;
    }
}

void execute_packet(decoded_packet packet) {
    uint32_t saved_pc = regs.pc;
    ++regs.pc;

    for (int i = 0; i < 4; ++i) {
        execute_instruction(packet.instr[i], saved_pc);
    }
}


// Driver / testing stub

int main(int argc, char** argv) {
    printf("OSOROM simulator starting\n");

    while(true) {
        printf("regs.pc is now 0x%x\n", regs.pc);
        printf("regs.r = { ");
        for (int i = 0; i < 32; ++i) {
            printf("%x, ", regs.r[i]);
        }
        printf("}\n");
        printf("Packet is %x / %x / %x / %x\n", ROM[regs.pc][0], ROM[regs.pc][1], ROM[regs.pc][2], ROM[regs.pc][3]);
        decoded_packet packet = decode_packet(ROM[regs.pc]);
        printf("Packet looks like:\n");
        printf("%s", packet.to_string().c_str());
        printf("Executing packet...\n");
        execute_packet(packet);
        printf("...done.\n");
    }

    printf("OROSOM simulator terminating\n");
}
