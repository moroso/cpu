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

#include <lua-5.3/lua.hpp>

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

/*** Lua bindings ***/

static int _osorom_readline(lua_State *L) {
    const char *prompt = luaL_checkstring(L, 1);
    char *rv = readline(prompt);
    if (!rv)
        return 0;
    lua_pushstring(L, rv);
    free(rv);
    return 1;
}

static int _osorom_add_history(lua_State *L) {
    const char *s = luaL_checkstring(L, 1);
    add_history(s);
    return 0;
}

static int _osorom_virt_to_phys(lua_State *L) {
    // 1: address
    // 2: for write
    
    uint32_t addr = luaL_checkinteger(L, 1);
    bool wr = lua_toboolean(L, 2);
    
    boost::optional<uint32_t> phys_addr = virt_to_phys(addr, cpu, wr);
    if (!phys_addr)
        return 0;
    lua_pushinteger(L, *phys_addr);
    return 1;
}

static int _osorom_get_state(lua_State *L) {
    lua_newtable(L);
    
    lua_pushstring(L, "r");
    lua_newtable(L);
    for (int i = 0; i < 32; i++) {
        lua_pushinteger(L, cpu.regs.r[i]);
        lua_rawseti(L, -2, i);
    }
    lua_settable(L, -3);

    lua_pushstring(L, "pred");
    lua_newtable(L);
    for (int i = 0; i < 3; i++) {
        lua_pushinteger(L, cpu.regs.p[i]);
        lua_rawseti(L, -2, i);
    }
    lua_settable(L, -3);
    
    lua_pushstring(L, "cp");
    lua_newtable(L);
    for (int i = 0; i < CP_REG_COUNT; i++) {
        lua_pushinteger(L, cpu.regs.cpr[i]);
        lua_rawseti(L, -2, i);
    }
    lua_settable(L, -3);

    lua_pushstring(L, "pc");
    lua_pushinteger(L, cpu.regs.pc);
    lua_settable(L, -3);
    
    lua_pushstring(L, "ovf");
    lua_pushinteger(L, cpu.regs.ovf);
    lua_settable(L, -3);
    
    lua_pushstring(L, "kmode");
    lua_pushinteger(L, cpu.regs.sys_kmode);
    lua_settable(L, -3);
    
    return 1;
}

static int _osorom_step_program(lua_State *L) {
    step_program();
    return 0;
}

volatile bool stop_flag = false;

void control_c_handler(int s) {
    stop_flag = true;
    printf("\n");
}

static int _osorom_run_program(lua_State *L) {
    stop_flag = false;
    
    struct sigaction sighandler, old_sighandler;
    sighandler.sa_handler = control_c_handler;
    sigemptyset(&sighandler.sa_mask);
    sighandler.sa_flags = 0;
    sigaction(SIGINT, &sighandler, &old_sighandler);

    boost::optional<int> bp = boost::none;
    boost::optional<int> wbp = boost::none;
    boost::optional<int> ebp = boost::none;
    while (!bp && !wbp && !ebp && !stop_flag) {
        step_program();
        wbp = hit_write_watchpoint();
        bp = hit_breakpoint();
        ebp = hit_exception_break();
    }
    
    sigaction(SIGINT, &old_sighandler, NULL);
    
    lua_newtable(L);
    
    if (stop_flag) {
        lua_pushliteral(L, "keyboard_interrupt");
        lua_pushboolean(L, true);
        lua_settable(L, -3);
    }
    
    if (bp) {
        lua_pushliteral(L, "breakpoint");
        lua_newtable(L);
        lua_pushliteral(L, "id");
        lua_pushinteger(L, *bp);
        lua_settable(L, -3);
        lua_pushliteral(L, "address");
        lua_pushinteger(L, breakpoints[*bp]);
        lua_settable(L, -3);
        lua_settable(L, -3);
    }
    
    if (wbp) {
        lua_pushliteral(L, "write_watchpoint");
        lua_newtable(L);
        lua_pushliteral(L, "id");
        lua_pushinteger(L, *wbp);
        lua_settable(L, -3);
        lua_pushliteral(L, "address");
        lua_pushinteger(L, write_watchpoints[*wbp]);
        lua_settable(L, -3);
        lua_settable(L, -3);
    }
    
    if (ebp) {
        lua_pushliteral(L, "exception");
        lua_pushinteger(L, *ebp);
        lua_settable(L, -3);
    }
    
    return 1;
}

/* XXX: This probably eventually wants to get sucked into Lua, along with
 * debug symbol loading in its entirety. */
static int _osorom_func_at(lua_State *L) {
    uint32_t addr = luaL_checkinteger(L, 1);
    
    boost::optional<std::pair<std::string, uint32_t> > funcname
        = func_at(addr);
    
    if (!funcname) {
        lua_pushnil(L);
    } else {
        lua_newtable(L);
        
        lua_pushstring(L, "name");
        lua_pushstring(L, funcname->first.c_str());
        lua_settable(L, -3);
        
        lua_pushstring(L, "offset");
        lua_pushinteger(L, funcname->second);
        lua_settable(L, -3);
    }
    
    return 1;
}

static int _osorom_disas_phys(lua_State *L) {
    uint32_t addr = luaL_checkinteger(L, 1);
    
    instruction_packet *pkt = (instruction_packet *)(cpu.ram + addr);
    decoded_packet packet(*pkt);
    
    lua_pushstring(L, packet.disassemble().c_str());
    
    return 1;
}

/* XXX: This is not really the cleanest interface here.  Probably the best
 * thing would be to publish a table in the library, exn_breaks, which had
 * metamethods hooked up to __index, __pairs, and __newindex to be
 * continuously "in sync" with the C++ view of the world.  But, let's be
 * real here -- life really is too short to build metatables by hand with
 * the C API to Lua.
 */

static int _osorom_exn_breaks_get(lua_State *L) {
    lua_newtable(L);
    
    for (int i = 0; i < NUM_EXCEPTIONS; i++) {
        lua_pushboolean(L, exn_breaks[i]);
        lua_rawseti(L, -2, i);
    }
    
    return 1;
}

static int _osorom_exn_breaks_set(lua_State *L) {
    int exn = luaL_checkinteger(L, 1);
    bool trap = lua_toboolean(L, 2);
    
    if (exn >= NUM_EXCEPTIONS || exn < 0) {
        lua_pushliteral(L, "exn out of bounds in exn_breaks_set");
        lua_error(L);
    }
    
    exn_breaks[exn] = trap;
    
    return 0;
}

static int _osorom_breakpoints_get(lua_State *L) {
    lua_newtable(L);
    for (int i = 0; i < breakpoints.size(); i++) {
        lua_pushinteger(L, i+1);
        
        lua_newtable(L);
        lua_pushliteral(L, "id");
        lua_pushinteger(L, i);
        lua_settable(L, -3);
        
        lua_pushliteral(L, "address");
        lua_pushinteger(L, breakpoints[i]);
        lua_settable(L, -3);
        
        lua_settable(L, -3);
    }
    
    return 1;
}

static int _osorom_breakpoints_add(lua_State *L) {
    uint32_t addr = luaL_checkinteger(L, 1);
    
    breakpoints.push_back(addr);
    
    lua_pushinteger(L, (int)breakpoints.size() - 1);
    
    return 1;
}

static int _osorom_write_watchpoints_get(lua_State *L) {
    lua_newtable(L);
    for (int i = 0; i < write_watchpoints.size(); i++) {
        lua_pushinteger(L, i+1);
        
        lua_newtable(L);
        lua_pushliteral(L, "id");
        lua_pushinteger(L, i);
        lua_settable(L, -3);
        
        lua_pushliteral(L, "address");
        lua_pushinteger(L, write_watchpoints[i]);
        lua_settable(L, -3);
        
        lua_settable(L, -3);
    }
    
    return 1;
}

static int _osorom_write_watchpoints_add(lua_State *L) {
    uint32_t addr = luaL_checkinteger(L, 1);
    
    write_watchpoints.push_back(addr);
    
    lua_pushinteger(L, (int)write_watchpoints.size() - 1);
    
    return 1;
}


static int _osorom_physmem(lua_State *L) {
    int sz = luaL_checkinteger(L, 1);
    uint32_t addr = luaL_checkinteger(L, 2);
    
    if (sz != 8 && sz != 16 && sz != 32) {
        lua_pushliteral(L, "size was not a reasonable number of bits");
        lua_error(L);
    }
    
    if (lua_isinteger(L, 3)) {
        uint32_t datum = luaL_checkinteger(L, 3);
        
        if (sz == 8) {
            *(uint8_t *)(cpu.ram + addr) = datum;
        } else if (sz == 16) {
            *(uint16_t *)(cpu.ram + addr) = datum;
        } else if (sz == 32) {
            *(uint32_t *)(cpu.ram + addr) = datum;
        }
        return 0;
    } else {
        if (sz == 8) {
            lua_pushinteger(L, *(uint8_t *)(cpu.ram + addr));
        } else if (sz == 16) {
            lua_pushinteger(L, *(uint16_t *)(cpu.ram + addr));
        } else if (sz == 32) {
            lua_pushinteger(L, *(uint32_t *)(cpu.ram + addr));
        }
        return 1;
    }
}

static const luaL_Reg osorom_lib[] = {
    {"readline", _osorom_readline},
    {"add_history", _osorom_add_history},
    {"virt_to_phys", _osorom_virt_to_phys},
    {"get_state", _osorom_get_state},
    {"step_program", _osorom_step_program},
    {"run_program", _osorom_run_program},
    {"func_at", _osorom_func_at},
    {"disas_phys", _osorom_disas_phys},
    {"exn_breaks_set", _osorom_exn_breaks_set},
    {"exn_breaks_get", _osorom_exn_breaks_get},
    {"breakpoints_get", _osorom_breakpoints_get},
    {"breakpoints_add", _osorom_breakpoints_add},
    {"write_watchpoints_get", _osorom_write_watchpoints_get},
    {"write_watchpoints_add", _osorom_write_watchpoints_add},
    {"physmem", _osorom_physmem},
    {NULL, NULL}
};

static int luaopen_osorom(lua_State *L) {
    luaL_newlib(L, osorom_lib);
    
    return 1;
}

void debug(char *debug_file) {
    cpu.regs.pc = 0x0;
    cpu.regs.sys_kmode = 1;

    bool done = false;
    std::string last;

    if (debug_file) {
        load_debug_file(debug_file);
    }
    
    lua_State *L;
    L = luaL_newstate();
    luaL_openlibs(L);
    luaL_requiref(L, "osorom", luaopen_osorom, 1);
    lua_pop(L, 1);
    
    int rv = luaL_loadfile(L, "debugger.lua");
    if (rv) {
        fprintf(stderr, "failed to load debugger.lua: %s\n", lua_tostring(L, -1));
        exit(1);
    }
    
    rv = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (rv) {
        fprintf(stderr, "failed to run debugger script: %s\n", lua_tostring(L, -1));
        exit(1);
    }
    
    lua_close(L);
}
