#pragma once

#include <memory>

#include <stdlib.h>

#include <boost/optional/optional.hpp>
#include <boost/format.hpp>

#include "cpu_sim_peripherals.h"

using std::shared_ptr;

#define SIM_RAM_BYTES (1024 * 1024 * 512)


// Set bit a through bit b (inclusive), as long as 0 <= a <= 31 and 0 <= b <= 31.
// From http://stackoverflow.com/a/8774613 .
#define BIT_MASK(a, b) (((unsigned) -1 >> (31 - (b))) & ~((1U << (a)) - 1))

#define BITS(word, idx, count) ((word & BIT_MASK(idx, idx + count - 1)) >> idx)
#define BIT(word, idx) BITS(word, idx, 1)

#define SIGN_EXTEND_32(value, from_bits) ( (( (int32_t)(value) ) << (32-(from_bits))) >> (32-(from_bits)) )

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

enum optype_t {
    BRANCH_OP,
    ALU_OP,
    LSU_OP,
    OTHER_OP,
    INVALID_OP
};

const size_t OPTYPES_COUNT = INVALID_OP + 1;
const size_t MAX_OPCODE_LEN = 16;

const char OPTYPE_STR[][MAX_OPCODE_LEN] = {
    "<BRANCH_OP>",
    "<ALU_OP>",
    "<LSU_OP>",
    "<OTHER_OP>",
    "<INVALID_OP>"
};
static_assert(array_size(OPTYPE_STR) == OPTYPES_COUNT, "Optype count mismatch");


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


// Order must match instruction encoding
enum shift_type {
    LSL,
    LSR,
    ASR,
    ROR
};


// Order must match instruction encoding
enum lsuop_t {
    LS_LB,
    LS_LHW,
    LS_LW,
    LS_LL,
    LS_SB,
    LS_SHW,
    LS_SW,
    LS_SC
};

const size_t LSUOPS_COUNT = LS_SC + 1;
static_assert(LSUOPS_COUNT == 8, "Bad lsu op list");

const char LSUOP_STR[][MAX_OPCODE_LEN] = {
    "LB",
    "LHW",
    "LW",
    "LL",
    "SB",
    "SHW",
    "SW",
    "SC"
};
static_assert(array_size(LSUOP_STR) == LSUOPS_COUNT, "Lsuops count mismatch");


// Order must match instruction encoding
enum otherop_t {
    OTHER_RESV0,
    OTHER_BREAK,
    OTHER_SYSCALL,
    OTHER_FENCE,
    OTHER_ERET,
    OTHER_CPOP,
    OTHER_MFC,
    OTHER_MTC,
    OTHER_MULT,
    OTHER_DIV,
    OTHER_MFHI,
    OTHER_MTHI,
    OTHER_SIMD0,
    OTHER_SIMD1,
    OTHER_SIMD2,
    OTHER_SIMD3
};

const size_t OTHEROPS_COUNT = OTHER_SIMD3 + 1;
static_assert(OTHEROPS_COUNT == 16, "Bad other op list");

const char OTHEROP_STR[][MAX_OPCODE_LEN] = {
    "<RESV0>",
    "BREAK",
    "SYSCALL",
    "FENCE",
    "ERET",
    "CPOP",
    "MFC",
    "MTC",
    "MULT",
    "DIV",
    "MFHI",
    "MTHI",
    "<SIMD0>",
    "<SIMD1>",
    "<SIMD2>",
    "<SIMD3>"
};
static_assert(array_size(OTHEROP_STR) == OTHEROPS_COUNT, "Otherops count mismatch");


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

struct regs_t {
    uint32_t r[32];
    bool p[4];
    uint32_t pc;
    bool link;
    uint32_t ovf;  // Mult/div overflow register
    uint32_t cpr[32];
    bool sys_kmode;  // 1 - kernel / 0 - user
};

enum cp_reg_t {
    CP_PFLAGS,
    CP_PTB,
    CP_EHA,
    CP_EPC,
    CP_EC0,
    CP_EC1,
    CP_EC2,
    CP_EC3,
    CP_EA0,
    CP_EA1,
    CP_SP0 = 16,
    CP_SP1,
    CP_SP2,
    CP_SP3
};

const size_t CP_REG_COUNT = CP_SP3 + 1;
static_assert(CP_REG_COUNT == 20, "Bad coreg list");

const char CP_REG_STR[][MAX_OPCODE_LEN] = {
    "pflags",
    "ptb",
    "eha",
    "epc",
    "ec0",
    "ec1",
    "ec2",
    "ec3",
    "ea0",
    "ea1",
    "", "", "", "", "", "",
    "sp0",
    "sp1",
    "sp2",
    "sp3",
};
static_assert(array_size(CP_REG_STR) == CP_REG_COUNT, "Coreg count mismatch");


#define PFLAGS_INT_ENABLE 0
#define PFLAGS_PAGING_ENABLE 1

struct cpu_t {
    regs_t regs;
    uint8_t *ram;
    bool halted;
    std::vector<peripheral*> peripherals;

    // Clear all exception flags.
    void clear_exceptions();

    // Update all peripheral status, returning true if one fired.
    bool process_peripherals();

    // Tells us whether we consider the given physical address to be present for a write.
    bool validate_write(uint32_t addr, uint32_t val, uint8_t width);

    uint32_t reg_value(uint32_t reg);

    void write_reg(uint8_t reg, uint32_t val);
    uint32_t read_reg(uint8_t reg, cpu_t &new_cpu);
    void write_coreg(uint8_t reg, uint32_t val);
    uint32_t read_coreg(uint8_t reg, cpu_t &new_cpu);
    void write_pred(uint8_t reg, bool val);
    bool read_pred(uint8_t reg, cpu_t &new_cpu);
    void write_ovf(uint32_t val);
    uint32_t read_ovf(cpu_t &new_cpu);
    void write_pc(uint32_t val);
    uint32_t read_pc(cpu_t &new_cpu);
    void write_link(bool val);
    bool read_link(cpu_t &new_cpu);
    void write_sys_kmode(bool val);
    bool read_sys_kmode(cpu_t &new_cpu);

    // Used for generating the trace file.
    uint64_t reg_write_mask;
    uint64_t reg_read_mask;
};

// order must match
enum exception_t {
    EXC_NO_ERROR,
    EXC_PAGEFAULT_ON_FETCH,
    EXC_ILLEGAL_INSTRUCTION,
    EXC_INSUFFICIENT_PERMISSIONS,
    EXC_DUPLICATE_DESTINATION,
    EXC_PAGEFAULT_ON_DATA_ACCESS,
    EXC_INVALID_PHYSICAL_ADDRESS,
    EXC_DIVIDE_BY_ZERO,
    EXC_INTERRUPT,
    EXC_SYSCALL,
    EXC_BREAK,

    EXC_HALT, // Not something that happens on the real CPU; just to flag that we want to end the simulation.
};

// order must match
enum interrupt_t {
    INT_TIMER,
    INT_USB,
    INT_FRAMEBUFFER,
    INT_SD,
    INT_SERIAL,
};

struct mem_write_t {
    uint32_t addr; // Note: physical address!
    uint8_t width;
    uint32_t val;
};

// Everything we need to know as a result of executing a single instruction.
struct exec_result {
    exception_t exception;
    boost::optional<uint32_t> fault_address;
    boost::optional<mem_write_t> mem_write;

    exec_result() : exec_result(EXC_NO_ERROR) {}
    exec_result(exception_t exception) : exception(exception), fault_address(boost::none), mem_write(boost::none) {}
    exec_result(exception_t exception,
                uint32_t addr,
                uint8_t width,
                uint32_t val) : exception(exception), fault_address(boost::none), mem_write({addr, width, val}) {}
    exec_result(exception_t exception,
                uint32_t fault_address) : exception(exception), fault_address(fault_address), mem_write(boost::none) {}
};

struct decoded_instruction {
    uint32_t raw_instr;  // For debugging

    pred_reg_t pred_reg = 0;
    bool pred_comp;
    optype_t optype = INVALID_OP;
    boost::optional<uint32_t> constant;
    boost::optional<int32_t> offset;
    boost::optional<reg_t> rs;
    boost::optional<reg_t> rd;
    boost::optional<reg_t> rt;
    boost::optional<uint32_t> shiftamt;
    boost::optional<shift_type> stype;
    bool long_imm = false;

    static shared_ptr<decoded_instruction> decode_instruction(instruction);

    decoded_instruction() {
        // XXX: I'm so sorry.
    }

    virtual std::string opcode_str();
    virtual std::string to_string();
    std::string disassemble();
    virtual std::string disassemble_inner();

    virtual exec_result execute(cpu_t &cpu, cpu_t &old_cpu);

    virtual uint64_t reg_read_mask();
    virtual uint64_t reg_write_mask();

    bool is_nop();

protected:
    virtual bool predicate_ok(cpu_t &cpu);
    // Internal use (ignores predicate flags):
    virtual exec_result execute_unconditional(cpu_t &cpu, cpu_t &old_cpu);
};

struct decoded_packet {
    shared_ptr<decoded_instruction> instr[4];

    decoded_packet(instruction_packet);

    std::string to_string();
    std::string disassemble();

    bool execute(cpu_t &cpu);

    uint64_t reg_read_mask();
    uint64_t reg_write_mask();
};

boost::optional<uint32_t> virt_to_phys(uint32_t addr, cpu_t &cpu, const bool store);
