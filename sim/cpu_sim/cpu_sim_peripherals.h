#pragma once

#include <boost/optional/optional.hpp>
#ifdef USE_SDL
#include <SDL/SDL.h>
#endif
#include "cpu_sim.h"

struct cpu_t;
class interrupt_controller;
class video;

class peripheral {
public:
    virtual uint32_t process(cpu_t &cpu) { return false; }
    // Returns whether the given write will be handled by this peripheral.
    virtual void write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {}
    // Perform a read from the specified memory address. The address is guaranteed to
    // be 4-byte aligned.
    virtual uint32_t read(cpu_t &cpu, uint32_t addr) {
        return 0;
    }
    virtual std::string name() { return std::string("<NONE>"); }

};

class peripheral_manager {
public:
    bool process(cpu_t &cpu);
    bool check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    bool write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    boost::optional<uint32_t> read(cpu_t &cpu, uint32_t addr, uint8_t width);

    peripheral_manager();
private:
    std::vector<peripheral*> peripherals;
    std::vector<uint32_t> last_int_flags;

    interrupt_controller *ictl;
    video *vid;
};

#define PERIPHERAL_BASE 0x80000000


class interrupt_controller : public peripheral {
public:
    interrupt_controller(uint32_t num_peripherals);
    uint32_t process(cpu_t &cpu);
    void write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    uint32_t read(cpu_t &cpu, uint32_t addr);
    std::string name() { return std::string("Interrupt controller"); }

    void set_hw_flag(uint32_t periph, uint32_t flags);
    bool interrupt_fired(void) { return int_fired; };
private:
    void recompute(void);

    std::vector<uint32_t> mask;
    std::vector<uint32_t> pending;
    uint32_t firing_interrupts;
    bool int_fired;
};

#define TIMER_COUNT 0
#define TIMER_TOP 4
#define TIMER_CONTROL 8
#define TIMER_CONTROL_EN 0

// A timer implementation that just counts CPU cycles.
class cycle_timer : public peripheral {
public:
    cycle_timer() : top(0), count(0), int_enable(0), int_flag(0), enable(0) {}
    uint32_t process(cpu_t &cpu);
    void write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    uint32_t read(cpu_t &cpu, uint32_t addr);
    std::string name() { return std::string("Cycle timer"); }
private:
    uint32_t top;
    uint32_t count;
    bool int_enable;
    bool int_flag;
    bool enable;
};

#define SERIAL_DATA 0
#define SERIAL_CSR 4
// TODO: baud, interrupts, etc.

#define SERIAL_CSR_TXC 0
#define SERIAL_CSR_TXE 1
#define SERIAL_CSR_RX_EN 2
#define SERIAL_CSR_RXC 3
#define SERIAL_CSR_RX_ERR 4

// Serial port implementation. Just supports tx for now.
class serial_port : public peripheral {
public:
	serial_port() : counter(0), tx_buf(0), tx_shift(0), state(SERIAL_IDLE), baud(0), csr(1 << SERIAL_CSR_TXE) {}
    uint32_t process(cpu_t &cpu);
    void write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    uint32_t read(cpu_t &cpu, uint32_t addr);
    std::string name() { return std::string("Serial port"); }
private:
    uint32_t counter;
    char tx_buf;
    char tx_shift; // The shift register, containing what's actually being transmitted.
    enum {
        SERIAL_IDLE,
        SERIAL_TRANSMITTING,
    } state;

    uint32_t baud;
    uint32_t csr;
};


#define VIDEO_BASE 0

#ifdef USE_SDL

class video : public peripheral {
public:
    video();
    uint32_t process(cpu_t &cpu);
    void write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    uint32_t read(cpu_t &cpu, uint32_t addr);
    std::string name() { return std::string("Video controller"); }
    void video_mem_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
private:
    SDL_Surface *screen;
    uint32_t video_offset;
    uint32_t count;
    uint32_t screen_size();
    bool needs_updating;
    uint32_t min_x;
    uint32_t max_x;
    uint32_t min_y;
    uint32_t max_y;
};

#else
class video : public peripheral {
public:
    void video_mem_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {};
};
#endif
