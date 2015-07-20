#ifdef USE_SDL
#include <SDL/SDL.h>
#endif

#include "cpu_sim.h"
#include "cpu_sim_peripherals.h"

bool peripheral::fire_interrupt(cpu_t &cpu, uint8_t interrupt) {
    if (!(cpu.regs.cpr[CP_PFLAGS] & (1 << PFLAGS_INT_ENABLE)))
        return false;

    cpu.clear_exceptions();
    cpu.regs.cpr[CP_EC0] = EXC_INTERRUPT | (interrupt << 5);
    return true;
}

bool cycle_timer::check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: improve this.
    return addr >= TIMER_BASE && addr <= TIMER_BASE + TIMER_CONTROL;
}

bool cycle_timer::process(cpu_t &cpu) {
    if (enable) {
        count++;
        printf("count: %d top: %d\n", count, top);
    }
    if (count == top) {
        count = 0;
        int_flag = true;
    }

    if (int_flag && int_enable) {
        return fire_interrupt(cpu, INT_TIMER);
    }

    return false;
}

bool cycle_timer::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: support unaligned writes? Will we even allow those?
    if (addr == TIMER_BASE + TIMER_COUNT) {
        count = val;
        return true;
    } else if (addr == TIMER_BASE + TIMER_TOP) {
        top = val;
        return true;
    } else if (addr == TIMER_BASE + TIMER_CONTROL) {
        int_flag = BIT(val, TIMER_CONTROL_INT);
        int_enable = BIT(val, TIMER_CONTROL_INT_EN);
        enable = BIT(val, TIMER_CONTROL_EN);
        return true;
    }

    return false;
}

boost::optional<uint32_t> cycle_timer::read(cpu_t &cpu, uint32_t addr, uint8_t width) {
    // TODO: support unaligned reads? Will we even allow those?
    // TODO: support different widths
    if (addr == TIMER_BASE + TIMER_COUNT) {
        return count;
    } else if (addr == TIMER_BASE + TIMER_TOP) {
        return top;
    } else if (addr == TIMER_BASE + TIMER_CONTROL) {
        return
          (int_flag << TIMER_CONTROL_INT) |
          (int_enable << TIMER_CONTROL_INT_EN) |
          (enable << TIMER_CONTROL_EN);
    }

    return boost::none;
}

#ifdef USE_SDL

video::video() {
    SDL_Init(SDL_INIT_VIDEO);
    screen = SDL_SetVideoMode(800, 600, 32, SDL_SWSURFACE);
    count = 0;
    video_offset = 0;
}

bool video::process(cpu_t &cpu) {
    count++;
    if (count == 10000) {
        count = 0;
        // TODO: update only what we need.
        SDL_UpdateRect(screen, 0, 0, 0, 0);
    }

    return false;
}

bool video::check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    return addr == VIDEO_BASE;
}

uint32_t video::screen_size() {
    return screen->pitch * screen->h;
}

bool video::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    if (addr == VIDEO_BASE && width == 4) {
        video_offset = val;
        memcpy(screen->pixels, &cpu.ram[video_offset], screen_size());
        return true;
    } else {
        // We write to real memory, but also do a write to the video buffer.
        if (addr >= video_offset && addr < video_offset + screen_size()) {
            for (int i = 0; i < width; i++) {
                *((uint8_t *)screen->pixels + (addr + i - video_offset)) = val & 0xff;
                val >>= 8;
            }
        }
        return false;
    }
}

boost::optional<uint32_t> video::read(cpu_t &cpu, uint32_t addr, uint8_t width) {
    if (addr == VIDEO_BASE && width == 4) {
        return video_offset;
    } else {
        return boost::none;
    }
}

#endif
