#pragma once

#include <boost/optional/optional.hpp>
#include "cpu_sim.h"

struct cpu_t;

class peripheral {
public:
    virtual bool process(cpu_t &cpu) { return false; }
    // Returns whether the given write will be handled by this peripheral.
    virtual bool check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) { return false; }
    // Returns true if the write was handled; false if this peripheral is punting on it.
    virtual bool write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) { return false; }
    // Perform a read from the specified memory address. none is returned if the address
    // is not special to this peripheral.
    virtual boost::optional<uint32_t> read(cpu_t &cpu, uint32_t addr, uint8_t width) { return boost::none; }
    virtual std::string name() { return std::string("<NONE>"); }
protected:
    bool fire_interrupt(cpu_t &cpu, uint8_t interrupt);
};

#define TIMER_BASE 0x80000000
#define TIMER_COUNT 0
#define TIMER_TOP 4
#define TIMER_CONTROL 8
#define TIMER_CONTROL_INT 0
#define TIMER_CONTROL_INT_EN 1
#define TIMER_CONTROL_EN 2

// A timer implementation that just counts CPU cycles.
class cycle_timer : public peripheral {
public:
    cycle_timer() : top(0), count(0), int_enable(0), int_flag(0), enable(0) {}
    bool process(cpu_t &cpu);
    bool check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    bool write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    boost::optional<uint32_t> read(cpu_t &cpu, uint32_t addr, uint8_t width);
    std::string name() { return std::string("Cycle timer"); }
private:
    uint32_t top;
    uint32_t count;
    bool int_enable;
    bool int_flag;
    bool enable;
};
