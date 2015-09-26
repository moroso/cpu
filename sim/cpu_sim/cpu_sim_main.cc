#include "cpu_sim.h"
#include "cpu_sim_debugger.h"
#include "cpu_sim_main.h"
#include "cpu_sim_utils.h"
#include "cpu_sim_peripherals.h"

#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>

cpu_t cpu;
FILE *trace_file;
FILE *mem_trace_file;
bool verbose;
bool benchmark;

/*

NOP: ADD R0 <- R0 + R0 (!P3) -> [111 0 0000000000 0000 0000 00000 00000 -> E000 0000]
HALT: BREAK 0x1FU -> [110 10001 00011 00000 1111 00000 00000 -> D118 3C00]

First sample program (trivial infinite loop):

asm:    B $0 (P3) / NOP / NOP / NOP
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


Fourth sample program (testing long immediates):

asm:    MOV R0 <- long(0xF0F0F0F0) / XXX / NOP / NOP
binary: 110 100000000000000 1000 00000 00000 /
        1111 0000 1111 0000 1111 0000 1111 0000 /
        NOP*2
hex:    D000 2000 / F0F0 F0F0 / (E000 0000) *2
*/

const size_t MAX_PROG_LEN = 0x256;
instruction ROM[][MAX_PROG_LEN] = {
    {
        0xD0002000, 0xF0F0F0F0, 0xE0000000, 0xE0000000,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
    {
        0xC0040000, 0xC0044021, 0xC006C042, 0xC8000063,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
    {
        0xD8000000, 0xE0000000, 0xE0000000, 0xE0000000,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
    {
        0xD8000000, 0xC0040000, 0xE0000000, 0xE0000000,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
};
size_t ROMLEN = array_size(ROM);

const size_t PRINT_LEN = 0x100;

void dump_ram_at(uint32_t addr, uint32_t highlight_addr) {
    for (size_t i = addr; i < addr + PRINT_LEN; i += 4) {
        uint32_t val = *(uint32_t *)(cpu.ram + i);
        if (i == highlight_addr) {
            printf(">%08x<", val);
        } else {
            printf(" %08x ", val);
        }
    }
}

void dump_ram() {
    const size_t STACK_BASE = 0x80000;
    printf("First %zu bytes of RAM:\n", PRINT_LEN);
    dump_ram_at(0, 0xffffffff);
    printf("\n");
    printf("First %zu bytes of stack (@0x%zx):\n", PRINT_LEN, STACK_BASE);
    dump_ram_at(STACK_BASE, cpu.regs.r[30]);
    printf("\n");
}

void dump_regs(regs_t regs, bool verbose) {
    if (verbose) {
        printf("regs.pc = 0x%x\n", regs.pc);
        printf("regs.r = { ");
        for (int i = 0; i < 32; ++i) {
            printf("0x%x, ", regs.r[i]);
        }
        printf("}\n");
        printf("regs.p = { ");
        for (int i = 0; i < 3; ++i) {
            printf("%d, ", regs.p[i]);
        }
        printf("}\n");
        printf("regs.ovf = 0x%x\n", regs.ovf);
        printf("regs.PFLAGS = 0x%x\n", regs.cpr[CP_PFLAGS]);
        printf("kmode = %d\n", cpu.regs.sys_kmode);
    } else {
        printf("pc 0x%x ", regs.pc);
        printf("r { ");
        for (int i = 0; i < 32; ++i) {
            printf("0x%x ", regs.r[i]);
        }
        printf("} ");
        printf("p { ");
        for (int i = 0; i < 3; ++i) {
            printf("%d ", regs.p[i]);
        }
        printf("} ");
        printf("ovf 0x%x", regs.ovf);

        printf("\n");
    }
}

void write_reg_trace(uint32_t pc, instruction_packet *pkt) {
    if (!trace_file)
        return;

    //TODO: error checking?
    fwrite(&pc, 4, 1, trace_file);
    if (pkt)
        fwrite(pkt, sizeof(instruction_packet), 1, trace_file);
    else {
        uint32_t zero = 0;
        for (int i = 0; i < 4; i++) {
            fwrite(&zero, 4, 1, trace_file);
        }
    }
    fwrite(&cpu.reg_read_mask, 6, 1, trace_file);
    fwrite(&cpu.reg_write_mask, 6, 1, trace_file);

    int count = 0;
    for (int i = 0; i < 64; i++) {
        uint64_t mask = ((uint64_t)1) << i;
        if (mask & cpu.reg_write_mask)
            count++;
    }
    fwrite(&count, 1, 1, trace_file);

    for (int i = 0; i < 64; i++) {
        uint64_t mask = ((uint64_t)1) << i;
        if (mask & cpu.reg_write_mask) {
            uint32_t val = cpu.reg_value(i);
            fwrite(&val, 4, 1, trace_file);
        }
    }
}

bool step_program() {
    // Run a single cycle.

    cpu.reg_write_mask = 0;
    cpu.reg_read_mask = 0;
    uint32_t original_pc = cpu.read_pc(cpu);
    bool interrupt = cpu.process_peripherals();
    bool exc = false;
    instruction_packet *pkt = NULL;
    if (!interrupt) {
        boost::optional<uint32_t> pc_phys = virt_to_phys(cpu.read_pc(cpu), cpu, false);
        // Note: no need for multiple checks, because packets can't cross page boundaries.

        if (pc_phys) {
            int idx = (*pc_phys) >> 4;
            if (idx >= cpu.packet_cache->size()) {
                cpu.packet_cache->resize(idx * 2 + 1);
            }
            //TODO: cache invalidation on write
            if (!(*cpu.packet_cache)[idx]) {
                pkt = (instruction_packet *)(cpu.ram + *pc_phys);
                if (verbose) {
                    dump_regs(cpu.regs, true);
                    printf("RAM dump:\n");
                    dump_ram();
                }
                if (verbose)
                    printf("Packet is %x / %x / %x / %x\n", (*pkt)[0], (*pkt)[1], (*pkt)[2], (*pkt)[3]);
                (*cpu.packet_cache)[idx] = decoded_packet(*pkt);
            }
            if (verbose) {
                printf("Packet looks like:\n");
                printf("%s", (*(*cpu.packet_cache)[idx]).to_string().c_str());
                printf("Executing packet...\n");
            }
            exc = (*(*cpu.packet_cache)[idx]).execute(cpu);
            if (cpu.halted) {
                if (verbose) {
                    printf("... BREAK 0x1FU -> end program\n");
                    printf("FINAL REGS: ");
                }
                dump_regs(cpu.regs, false);
                return true;
            }
        } else {
            if (verbose)
                printf("Invalid address in instruction fetch: %x\n", cpu.regs.pc);
            cpu.clear_exceptions();
            cpu.write_coreg(CP_EC0, EXC_PAGEFAULT_ON_FETCH);
            exc = true;
        }
    }

    if (exc || interrupt) {
        if (verbose) {
            if (exc)
                printf("EXCEPTION!!!!\n");
            else
                printf("INTERRUPT!!!!\n");
        }
        cpu.write_coreg(CP_EPC, cpu.read_pc(cpu) | cpu.read_sys_kmode(cpu)
                        | (BIT(cpu.read_coreg(CP_PFLAGS, cpu), PFLAGS_INT_ENABLE) << 1));
        // All other flags, if applicable, were set during the execution of the packet.
        cpu.write_pc(cpu.read_coreg(CP_EHA, cpu));
        cpu.write_coreg(CP_PFLAGS, cpu.read_coreg(CP_PFLAGS, cpu) & ~(1 << PFLAGS_INT_ENABLE));
        cpu.write_sys_kmode(true);
    }
    write_reg_trace(original_pc, pkt);
    if (verbose)
        printf("...done.\n");

    return false;
}

void run_program() {
    cpu.regs.pc = 0x0;
    cpu.regs.sys_kmode = 1;

    bool done = false;

    int cycle = 0;
    int last_time = 0;

    while(!done) {
        done = step_program();
        if (benchmark) {
            if ((cycle % 1000000) == 0) {
                struct timeval cur_time;
                gettimeofday(&cur_time, NULL);
                int new_time = cur_time.tv_sec * 1000 + cur_time.tv_usec / 1000;
                fprintf(stderr, "%d instructions in %d ms = %f instructions per second\n",
                        cycle, new_time - last_time,
                        (cycle * 1000. / (float)(new_time - last_time)));
                cycle = 0;
                last_time = new_time;
            }
        }
        cycle++;
    }
}

enum run_mode_t {
    MODE_DEFAULT = 0,
    MODE_TEST,
    MODE_RANDOM,
    MODE_DIS,
};

run_mode_t mode;

void usage(char *progname) {
    fprintf(stderr, "usage: %s [-v] [-g] [-h|-t|-r|-d <0xNNNN>]\n", progname);
}

int main(int argc, char** argv) {
    int c = 0;
    opterr = 0;
    char *dis_inst;
    char *trace_filename = NULL;
    char *mem_trace_filename = NULL;
    verbose = false;
    bool debugger = false;
    char *input_filename = NULL;


    static struct option long_options[] = {
        {"trace",     required_argument, 0, 0},
        {"mem_trace", required_argument, 0, 0},
        {"input",     required_argument, 0, 0},
        {0,           0,                 0, 0},
    };
    int option_index;

    while ((c = getopt_long(argc, argv, "bgvhtrd:o:", long_options, &option_index)) != -1) {
        switch (c) {
            case 0:
                switch (option_index) {
                    case 0:
                        trace_filename = optarg;
                        break;
                    case 1:
                        mem_trace_filename = optarg;
                        break;
                    case 2:
                        input_filename = optarg;
                }
                break;
            case 'b':
                benchmark = true;
                break;
            case 'v':
                verbose = true;
                break;
            case 'h':
                usage(argv[0]);
                exit(0);
            case 't':
                mode = MODE_TEST;
                break;
            case 'r':
                mode = MODE_RANDOM;
                break;
            case 'd':
                mode = MODE_DIS;
                dis_inst = optarg;
                break;
            case 'g':
                debugger = true;
                break;
            case '?':
                if (optopt == 'd') {
                    fprintf(stderr, "Option -%c requires an argument.\n", optopt);
                } else if (isprint(optopt)) {
                    fprintf(stderr, "Unknown option '-%c'.\n", optopt);
                } else {
                    fprintf(stderr, "Unknown option character '\\x%x'.\n", optopt);
                }
                exit(1);
            default:
                abort();
        }
    }

    if (mode == MODE_RANDOM) {
        srand(0);
        printf("Random instruction mode\n");
        while(true) {
            instruction instr = rand32();
            printf("Disassembling single instruction %x (%u):\n", instr, instr);
            shared_ptr<decoded_instruction> di = decoded_instruction::decode_instruction(instr);
            printf("%s\n\n\n", di->to_string().c_str());
        }
    }

    if (mode == MODE_DIS) {
        instruction instr = strtoul(dis_inst, 0, 0);
        printf("Disassembling single instruction %x (%u):\n", instr, instr);
        shared_ptr<decoded_instruction> di = decoded_instruction::decode_instruction(instr);
        printf("%s\n", di->to_string().c_str());
        exit(0);
    }

    cpu.packet_cache = new std::vector<boost::optional<decoded_packet> >();

    cpu.ram = (uint8_t *)malloc(SIM_RAM_BYTES);
    cpu.peripherals.push_back(new cycle_timer());
    cpu.peripherals.push_back(new video());
    cpu.peripherals.push_back(new serial_port());

    if (mode == MODE_TEST) {
        printf("OSOROM simulator starting in test mode\n");

        for (int i = 0; i < ROMLEN; ++i) {
            printf("Running test program #%d\n", i);
            bzero(cpu.ram, SIM_RAM_BYTES);
            memcpy(cpu.ram, ROM[i], MAX_PROG_LEN);
            run_program();
        }

        printf("OROSOM simulator terminating\n");
        exit(0);
    }

    // MODE_DEFAULT: Read program from stdin

    printf("OSOROM simulator starting\n");

    size_t i = 0;
    int fd;
    if (input_filename) {
        printf("Reading from %s\n", input_filename);
        fd = open(input_filename, O_RDONLY);
    } else {
        fd = STDIN_FILENO;
    }
    while(read(fd, &cpu.ram[i], 1) > 0) {
        ++i;
        if (i >= SIM_RAM_BYTES) {
            printf("FATAL: Program larger than RAM\n");
            abort();
        }
    }
    if (input_filename)
        close(fd);

    printf("Trace to %s\n", trace_filename);
    trace_file = fopen(trace_filename, "w");

    if (debugger)
        debug();
    else
        run_program();
    printf("OROSOM simulator terminating\n");

    if (trace_file)
        fclose(trace_file);
}
