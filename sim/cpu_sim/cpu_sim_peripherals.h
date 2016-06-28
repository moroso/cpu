#pragma once

#include <boost/optional/optional.hpp>
#ifdef USE_SDL
#include <SDL/SDL.h>
#endif
#include "cpu_sim.h"

struct cpu_t;

class peripheral {
public:
    virtual bool process(cpu_t &cpu) { return false; }
    // Returns whether the given write will be handled by this peripheral.
    virtual bool check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width){return false; }
    // Returns true if the write was handled; false if this peripheral is punting on it.
    virtual bool write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) { return false; }
    // Perform a read from the specified memory address. none is returned if the address
    // is not special to this peripheral.
    virtual boost::optional<uint32_t> read(cpu_t &cpu, uint32_t addr, uint8_t width) {
		return boost::none;
	}
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

#define SERIAL_BASE 0x80001000
#define SERIAL_BAUD 0
#define SERIAL_DATA 4
#define SERIAL_CONTROL 8
#define SERIAL_STATUS 12

#define SERIAL_CONTROL_TXCI 0
#define SERIAL_CONTROL_TXEI 1
#define SERIAL_CONTROL_RXCI 2
#define SERIAL_STATUS_TXC 0
#define SERIAL_STATUS_TXE 1
#define SERIAL_STATUS_RXC 2

// Serial port implementation. Just supports tx for now.
class serial_port : public peripheral {
public:
	serial_port() : counter(0), tx_buf(0), tx_shift(0), state(SERIAL_IDLE), baud(0), control(0), status(1 << SERIAL_STATUS_TXE) {}
    bool process(cpu_t &cpu);
    bool check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    bool write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    boost::optional<uint32_t> read(cpu_t &cpu, uint32_t addr, uint8_t width);
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
    uint32_t control;
    uint32_t status;
};


#define VIDEO_BASE 0x80002000
#define VIDEO_RAM_PTR 0

#ifdef USE_SDL

class video : public peripheral {
public:
    video();
    bool process(cpu_t &cpu);
    bool check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    bool write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width);
    boost::optional<uint32_t> read(cpu_t &cpu, uint32_t addr, uint8_t width);
    std::string name() { return std::string("Video controller"); }
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
class video : public peripheral {};
#endif
