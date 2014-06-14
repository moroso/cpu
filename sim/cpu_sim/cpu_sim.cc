#include <queue>
#include <boost/optional/optional.hpp>

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
};

struct decoded_instruction {
    unsigned int pred_reg:2;
    bool pred_comp;
    opcode_t opcode = INVALID_OP;
    boost::optional<uint32_t> constant;
    boost::optional<int32_t> offset;
    boost::optional<reg_t> rs;
    boost::optional<reg_t> rd;
    boost::optional<reg_t> rt;
    bool long_imm;
};

struct decoded_packet {
    decoded_instruction instr[4];
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

First sample program (infinite loop):

asm:    B $0 (P3) / NOP / NOP / NOP (Expressing NOP as ADD R0 <- R0 + R0 (!P3))
binary: 110 1100 0000000000000000000000000 / (111 000000000000000 0000 00000 00000) *3
hex:    D800 0000 / (E000 0000) *3

*/

instruction_packet ROM[] = { 0xD8000000, 0xE0000000, 0xE0000000, 0xE0000000 };


// Pretty-printing

const char *opcode_str(opcode_t opcode) {
    if (opcode < OPCODES_COUNT) {
        return OPCODE_STR[opcode];
    } else {
        return OPCODE_STR[INVALID_OP];
    }
}

void pp_instruction(instruction instr, decoded_instruction instr_d) {
    printf("- Instruction (%x):\n", instr);
    printf("  * [%cP%d] %s\n", (instr_d.pred_comp ? '~' : ' '), instr_d.pred_reg, opcode_str(instr_d.opcode));
    if (instr_d.offset)
        printf("  * offset = %d\n", instr_d.offset.get());
    if (instr_d.rs)
        printf("  * rs = %d\n", instr_d.rs.get().reg);
}

void pp_packet(instruction_packet ip, decoded_packet dp) {
    for (int i = 0; i < 4; ++i) {
        pp_instruction(ip[i], dp.instr[i]);
    }
}


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
                result.rs->reg = rs_num;
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
    }

    printf("decoded result pp:\n");
    pp_instruction(instr, result);
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


// Instruction (and instruction packet) execution

void execute_instruction(decoded_instruction instr, uint32_t old_pc) {
    if (instr.opcode == B) {
        regs.pc = old_pc;
        printf("pc is %d\n", regs.pc);
        regs.pc += instr.offset.get();
        printf("pc is %d\n", regs.pc);
        if (instr.rs) {
            regs.pc += regs.r[instr.rs.get().reg];
        }
        printf("pc is %d\n", regs.pc);
    }
}

void execute_packet(decoded_packet packet) {
    uint32_t saved_pc = regs.pc;
    ++regs.pc;

    for (int i = 0; i < 4; ++i) {
        printf("a pc is %d\n", regs.pc);
        execute_instruction(packet.instr[i], saved_pc);
        printf("b pc is %d\n", regs.pc);
    }
}


// Driver / testing stub

int main(int argc, char** argv) {
    printf("OSOROM simulator starting\n");

    while(true) {
        printf("regs.pc is now 0x%x\n", regs.pc);
        printf("Packet is %x / %x / %x / %x\n", ROM[regs.pc][0], ROM[regs.pc][1], ROM[regs.pc][2], ROM[regs.pc][3]);
        decoded_packet packet = decode_packet(ROM[regs.pc]);
        printf("Packet looks like:\n");
        pp_packet(ROM[regs.pc], packet);
        printf("Executing packet...\n");
        execute_packet(packet);
        printf("...done.\n");
    }

    printf("OROSOM simulator terminating\n");
}