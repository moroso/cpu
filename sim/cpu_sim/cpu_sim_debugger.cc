#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <string>
#include <vector>
#include <readline/readline.h>
#include <readline/history.h>
#include <ctype.h>
#include <signal.h>
#include <unistd.h>
#include <map>

#include <boost/algorithm/string/classification.hpp>
#include <boost/algorithm/string/split.hpp>

#include "cpu_sim.h"
#include "cpu_sim_main.h"
#include "cpu_sim_debugger.h"

extern cpu_t cpu;

std::vector<uint32_t> breakpoints;
std::vector<uint32_t> write_watchpoints;
bool exn_breaks[NUM_EXCEPTIONS];

std::map<uint32_t, std::string> functions;
bool functions_loaded = false;

boost::optional<std::pair<std::string, uint32_t> > func_at(uint32_t addr) {
    uint32_t inst_index = addr / 0x10;
    if (!functions_loaded)
        return boost::none;

    std::map<uint32_t, std::string>::iterator it = functions.lower_bound(inst_index);
    if (it->first == inst_index)
        return std::pair<std::string, uint32_t>(it->second, addr - it->first * 0x10);

    if (it == functions.begin())
        return boost::none;

    it--;
    return std::pair<std::string, uint32_t>(it->second, addr - it->first * 0x10);
}

void dump_inst_phys(uint32_t phys_addr) {
    instruction_packet *pkt = (instruction_packet *)(cpu.ram + phys_addr);
    decoded_packet packet(*pkt);
    printf("%s", packet.disassemble().c_str());
}

void dump_inst(uint32_t virt_addr) {
    boost::optional<uint32_t> pc_phys = virt_to_phys(virt_addr, cpu, false);
    // Note: no need for multiple checks, because packets can't cross page boundaries.

    if (pc_phys) {
        dump_inst_phys(*pc_phys);
    } else {
        printf("<Cannot access memory>");
    }

}

boost::optional<int> is_breakpoint(uint32_t addr) {
    for (int i = 0; i < breakpoints.size(); ++i) {
        if (addr == breakpoints[i])
            return i;
    }
    return boost::none;
}

boost::optional<int> hit_write_watchpoint() {
    // TODO: this doesn't take into account size, just starting address.
    for (int i = 0; i < write_watchpoints.size(); ++i) {
      if (cpu.last_writes[0] && (*cpu.last_writes[0]).addr == write_watchpoints[i])
            return i;
      if (cpu.last_writes[1] && (*cpu.last_writes[1]).addr == write_watchpoints[i])
            return i;
    }
    return boost::none;
}

boost::optional<int> hit_breakpoint() {
    return is_breakpoint(cpu.regs.pc);
}

boost::optional<int> last_exception() {
    if (!cpu.exn_last_cycle) {
        return boost::none;
    }

    for (int i = 0; i < 4; ++i) {
        if (cpu.regs.cpr[CP_EC0 + i] != EXC_NO_ERROR)
            return cpu.regs.cpr[CP_EC0 + i];
    }

    // Should never happen.
    assert(false);
}

boost::optional<int> hit_exception_break() {
    boost::optional<int> last_exc = last_exception();
    if (!last_exc)
        return boost::none;

    if (exn_breaks[*last_exc])
        return last_exc;
    else
        return boost::none;
}

uint32_t read_num(std::string &num_str) {
    if (num_str.substr(0, 2) == "0x") {
        return std::stoul(num_str.substr(2, std::string::npos), NULL, 16);
    } else {
        return std::stoul(num_str);
    }
}

volatile bool stop_flag = false;

void control_c_handler(int s) {
    stop_flag = true;
    printf("\n");
}

void process_line(std::string &line) {
    std::vector<std::string> tokens;
    split(tokens, line, boost::algorithm::is_any_of(" "));

    if (tokens.size() == 0)
    {
        printf("No tokens\n");
        return;
    }

    if (tokens[0] == "list") {
        printf("List!\n");
    } else if (tokens[0] == "regs" || tokens[0] == "r") {
        if (tokens.size() == 1) {
            for (int i = 0; i < 32; ++i) {
                printf("%sr%d = 0x%08x ", (i >= 10 ? "" : " "), i, cpu.regs.r[i]);
                if ((i % 4) == 3)
                    printf("\n");
            }
        } else {
            if (tokens[1] == "pc") {
                printf("pc = 0x%08x\n", cpu.regs.pc);
            } else if (tokens[1] == "co" || tokens[1] == "c") {
                for (int i = 0; i < CP_REG_COUNT; ++i) {
                    if (i <= CP_EA1 || i >= CP_SP0) {
                        printf("%6s = 0x%08x", CP_REG_STR[i], cpu.regs.cpr[i]);
                        if (i % 2 == 1)
                            printf("\n");
                    }
                }
                // Also print whether we're in kmode, and OVF.
                printf("%6s = 0x%08x%6s = 0x%08x\n",
                       "ovf", cpu.regs.ovf,
                       "kmode", cpu.regs.sys_kmode);
            } else if (tokens[1] == "p") {
                printf("pred = { %d, %d, %d }\n",
                       cpu.regs.p[0],
                       cpu.regs.p[1],
                       cpu.regs.p[2]);
            }
        }
    } else if (tokens[0] == "i") {
        step_program();
        boost::optional<std::pair<std::string, uint32_t> > funcname
            = func_at(cpu.regs.pc);
        if (funcname) {
            printf("pc = 0x%08x <%s+0x%x>  ",
                   cpu.regs.pc,
                   funcname->first.c_str(),
                   funcname->second);
        } else {
            printf("pc = 0x%08x  ", cpu.regs.pc);
        }
        dump_inst(cpu.regs.pc);
        printf("\n");
    } else if (tokens[0] == "q") {
        exit(0);
    } else if (tokens[0] == "run") {
        struct sigaction sighandler, old_sighandler;
        sighandler.sa_handler = control_c_handler;
        sigemptyset(&sighandler.sa_mask);
        sighandler.sa_flags = 0;
        sigaction(SIGINT, &sighandler, &old_sighandler);
        boost::optional<int> bp = boost::none;
        boost::optional<int> wbp = boost::none;
        boost::optional<int> ebp = boost::none;
        stop_flag = false;
        while (!bp && !wbp && !ebp && !stop_flag) {
            step_program();
            wbp = hit_write_watchpoint();
            bp = hit_breakpoint();
            ebp = hit_exception_break();
        }
        sigaction(SIGINT, &old_sighandler, NULL);
        if (bp)
            printf("Hit breakpoint %d\n", *bp);
        else if (wbp)
            printf("Hit watchpoint %d\n", *wbp);
        else if (ebp)
            printf("Hit exception %d\n", *ebp);

        boost::optional<std::pair<std::string, uint32_t> > funcname
            = func_at(cpu.regs.pc);
        if (funcname) {
            printf("pc = 0x%08x <%s+0x%x>  ",
                   cpu.regs.pc,
                   funcname->first.c_str(),
                   funcname->second);
        } else {
            printf("pc = 0x%08x  ", cpu.regs.pc);
        }
        dump_inst(cpu.regs.pc);
        printf("\n");
    } else if (tokens[0] == "b" || tokens[0] == "break") {
        if (tokens.size() == 1) {
            printf("Breakpoints:\n");
            for (int i = 0; i < breakpoints.size(); ++i) {
                printf("%4d at 0x%08x\n", i, breakpoints[i]);
            }
        } else {
            uint32_t addr = read_num(tokens[1]);
            breakpoints.push_back(addr);
            printf("Breakpoint %d at 0x%08x\n", (int)breakpoints.size() - 1, addr);
        }
    } else if (tokens[0] == "b/w" || tokens[0] == "break/w") {
        if (tokens.size() == 1) {
            printf("Watchpoints on write:\n");
            for (int i = 0; i < write_watchpoints.size(); ++i) {
                printf("%4d at 0x%08x\n", i, write_watchpoints[i]);
            }
        } else {
            uint32_t addr = read_num(tokens[1]);
            write_watchpoints.push_back(addr);
            printf("Watchpoint %d on write to 0x%08x\n", (int)write_watchpoints.size() - 1, addr);
        }
    } else if (tokens[0] == "b/e" || tokens[0] == "break/e") {
        if (tokens.size() == 1) {
            printf("Breaking on exceptions:\n");
            for (int i = 0; i < NUM_EXCEPTIONS; ++i) {
                if (exn_breaks[i]) {
                    printf("   %d\n", i);
                }
            }
        } else {
            uint32_t exn = read_num(tokens[1]);
            if (exn >= NUM_EXCEPTIONS) {
                printf("Bad exception index: %d\n", exn);
                return;
            }

            exn_breaks[exn] = !exn_breaks[exn];
            if (exn_breaks[exn]) {
                printf("Breaking on exception %d\n", exn);
            } else {
                printf("Removed break on exception %d\n", exn);
            }
        }
    } else if (tokens[0] == "disassemble" || tokens[0] == "dis" || tokens[0] == "d") {
        uint32_t addr;
        if (tokens.size() == 1)
            addr = cpu.regs.pc;
        else
            addr = read_num(tokens[1]);

        uint32_t start_offs;
        if (addr < 0x30)
            start_offs = addr / 0x10;
        else
            start_offs = 3;

        for (int i = 0; i < 8; i++)
        {
            uint32_t this_addr = addr + 0x10 * (i - start_offs);
            boost::optional<std::pair<std::string, uint32_t> > funcname
                = func_at(this_addr);
            if (funcname) {
                printf("%c%c%8x <%s+0x%x> ",
                       (is_breakpoint(this_addr) ? '!' : ' '),
                       (i == start_offs ? '*' : ' '),
                       this_addr,
                       funcname->first.c_str(),
                       funcname->second);
            } else {
                printf("%c%c%8x ",
                       (is_breakpoint(this_addr) ? '!' : ' '),
                       (i == start_offs ? '*' : ' '),
                       this_addr);
            }
            dump_inst(this_addr);
            printf("\n");
        }
    } else if (tokens[0][0] == 'x') {
        // The "examine" instruction. This requires some parsing.
        int next_pos;
        bool physical;
        if (tokens[0][1] == 'p') {
            physical = true;
            next_pos = 2;
        } else {
            physical = false;
            next_pos = 1;
        }

        int width;
        int count;
        if (tokens[0][next_pos] == '/') {
            next_pos++;
            if (isdigit(tokens[0][next_pos])) {
                size_t pos;
                count = std::stoi(tokens[0].substr(next_pos, std::string::npos), &pos);
                next_pos += pos;
            }
            switch (tokens[0][next_pos]) {
                case 'b': { width = 1; break; }
                case 'h': { width = 2; break; }
                case 0:
                case 'l': { width = 4; break; }
                default: { printf("Bad command\n"); return; }
            }
        } else {
            width = 4;
            count = 1;
        }

        uint32_t addr;
        if (tokens.size() == 1 || tokens[1] == "p") {
            addr = cpu.regs.pc;
        } else {
            addr = read_num(tokens[1]);
        }

        if (physical) {
            uint8_t *base_addr = ((uint8_t*)cpu.ram) + addr;
            for (int i = 0; i < count; i++) {
                if (width == 1) {
                    printf("0x%02hhx ", base_addr[i]);
                } else if (width == 2) {
                    printf("0x%04hx ", ((uint16_t*)base_addr)[i]);
                } else if (width == 4) {
                    printf("0x%08x ", ((uint32_t*)base_addr)[i]);
                }
            }
        } else {
            for (int i = 0; i < count; i++) {
                // NB: we assume we don't cross a page boundary.
                boost::optional<uint32_t> phys_addr = virt_to_phys(addr + width * i, cpu, false);

                if (phys_addr) {
                    if (width == 1) {
                        printf("0x%02hhx ", *(((uint8_t*)cpu.ram) + *phys_addr));
                    } else if (width == 2) {
                        printf("0x%04hx ", *(uint16_t*)((uint8_t*)cpu.ram + *phys_addr));
                    } else if (width == 4) {
                        printf("0x%08x ", *(uint32_t*)((uint8_t*)cpu.ram + *phys_addr));
                    }
                } else {
                    printf("<Cannot access memory>");
                }
            }
        }
        printf("\n");
    } else if (tokens[0] == "p") {
      if (tokens.size() != 2) {
          printf("Give an address!\n");
          return;
      }
      uint32_t addr = read_num(tokens[1]);
      boost::optional<uint32_t> phys_addr = virt_to_phys(addr, cpu, false);
      boost::optional<uint32_t> phys_addr_write = virt_to_phys(addr, cpu, true);
      if (phys_addr) {
          printf("Virtual address 0x%x maps to physical address 0x%x ",
                 addr, *phys_addr);
          if (phys_addr_write) {
              printf("(rw)\n");
          } else {
              printf("(ro)\n");
          }
      } else {
          printf("Virtual address 0x%x has no physical address\n", addr);
      }
    } else if (tokens[0] == "help") {
        printf("Commands:\n");
        printf("    x: examine address.\n");
        printf("   xp: examine physical address.\n");
        printf("    r: display regs. 'regs co' for coregs; 'regs p' for pred regs; 'regs pc' for pc.\n");
        printf("    b: add breakpoint/view breakpoints\n");
        printf("  b/w: add watchpoint/view watchpoints\n");
        printf("  b/e: add breakpoint on exception/view breakpoints on exceptions\n");
        printf("  run: run until a breakpoint is hit\n");
        printf("    i: step instruction packets\n");
        printf("    d: disassemble\n");
        printf("    p: virtual->physical address lookup\n");
        printf("    q: quit\n");
    }
}

void load_debug_labels(FILE *f) {
    // TODO: more error checking on reads.
    // TODO: endianness
    uint32_t num_records = 0;

    fread(&num_records, 4, 1, f);

    printf("%d labels\n", num_records);

    while(num_records--) {
        uint32_t addr = 0;
        uint32_t len = 0;
        char buffer[256];

        fread(&addr, 4, 1, f);
        fread(&len, 4, 1, f);
        if (len >= 256) {
            printf("Label too long. Bailing.\n");
            exit(0);
        }

        int read_records = fread(buffer, len, 1, f);
        if (read_records != 1 || buffer[len - 1] != 0) {
            printf("Format error. Bailing.\n");
            exit(0);
        }

        functions.insert(std::pair<uint32_t, std::string>(addr, std::string(buffer)));
    }

    functions_loaded = true;
}

void load_debug_file(char *debug_file) {
    // TODO: more error checking on reads.
    printf("Loading debugging symbols from %s\n", debug_file);
    FILE *f = fopen(debug_file, "r");
    if (!f) {
        printf("... failed to open\n");
        return;
    }

    char buffer[4];
    fread(buffer, 4, 1, f);

    if (strncmp(buffer, "MROD", 4) != 0) {
        printf("... bad format\n");
        return;
    }

    while(!feof(f)) {
        if (fread(buffer, 4, 1, f) != 1)
            return;
        if (strncmp(buffer, "LBEL", 4) == 0) {
            load_debug_labels(f);
        } else {
            printf("Bad section: %02hhx%02hhx%02hhx%02hhx\n",
                   buffer[0], buffer[1], buffer[2], buffer[3]);
        }
    }

    fclose(f);
}

void debug(char *debug_file) {
    cpu.regs.pc = 0x0;
    cpu.regs.sys_kmode = 1;

    bool done = false;
    std::string last;

    if (debug_file) {
        load_debug_file(debug_file);
    }

    while(true) {
        char *line_c_str = readline("mdb> ");
        if (!line_c_str)
            return;
        std::string line(line_c_str);
        if (line.size() == 0) {
            line = last;
        } else {
            last = line;
            add_history(line_c_str);
        }
        free(line_c_str);

        process_line(line);
    }
}
