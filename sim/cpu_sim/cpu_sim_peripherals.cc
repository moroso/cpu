#ifdef USE_SDL
#include <SDL/SDL.h>
#endif

#include "cpu_sim.h"
#include "cpu_sim_peripherals.h"

extern bool verbose;

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
        if (verbose)
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
    screen = SDL_SetVideoMode(800, 600, 24, SDL_SWSURFACE);
    count = 0;
    video_offset = 0;

    needs_updating = false;
    min_x = screen->w - 1;
    max_x = 0;
    min_y = screen->h - 1;
    max_y = 0;
}

bool video::process(cpu_t &cpu) {
    count++;
    if (count == 10000) {
        count = 0;

        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_VIDEOEXPOSE) {
                SDL_UpdateRect(screen, 0,0,0,0);
            }
        }
        if (needs_updating) {
            // A single write can affect 2 pixels in the x direction, and 1
            // in the y direction.
            uint32_t w = max_x - min_x + 2;
            uint32_t h = max_y - min_y + 1;

            if (min_x + w > screen->w) {
                w = screen->w - min_x;
            }
            if (min_y + h > screen->h) {
                h = screen->h - min_y;
            }
            SDL_UpdateRect(screen, min_x, min_y, w, h);
        }
        needs_updating = false;
        min_x = screen->w - 1;
        max_x = 0;
        min_y = screen->h - 1;
        max_y = 0;
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

        needs_updating = true;
        min_x = 0;
        max_x = screen->w;
        min_y = 0;
        max_y = screen->h;
        return true;
    } else {
        // We write to real memory, but also do a write to the video buffer.
        if (addr >= video_offset && addr < video_offset + screen_size()) {
            for (int i = 0; i < width; i++) {
                *((uint8_t *)screen->pixels + (addr + i - video_offset)) = val & 0xff;
                val >>= 8;
            }
        }
        uint32_t offs = (addr - video_offset) / 3;
        uint32_t y = offs / screen->w;
        uint32_t x = offs % screen->w;

        if (x < min_x) min_x = x;
        if (x > max_x) max_x = x;
        if (y < min_y) min_y = y;
        if (y > max_y) max_y = y;
        needs_updating = true;
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


bool serial_port::check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: improve this.
    return addr >= SERIAL_BASE && addr <= SERIAL_BASE + SERIAL_STATUS;
}

bool serial_port::process(cpu_t &cpu) {
    if (state == SERIAL_TRANSMITTING) {
        counter++;
        if (counter == baud) {
            printf("%c", tx_shift);
            counter = 0;
            // Is there another character waiting in the buffer?
            if (!(status & (1 << SERIAL_STATUS_TXE))) {
                tx_shift = tx_buf;
            } else {
                state = SERIAL_IDLE;
            }
            status |= (1 << SERIAL_STATUS_TXC) | (1 << SERIAL_STATUS_TXE);
        }
    }

    if ((status & control) != 0) {
        return fire_interrupt(cpu, INT_SERIAL);
    }

    return false;
}

bool serial_port::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: support unaligned writes? Will we even allow those?
    if (width != 4 || (addr & 0x3) != 0)
        return false;

    if (addr == SERIAL_BASE + SERIAL_DATA) {
        tx_buf = val;
        if (state == SERIAL_IDLE) {
            state = SERIAL_TRANSMITTING;
            counter = 0;
            tx_shift = tx_buf;
            status |= (1 << SERIAL_STATUS_TXE);
        } else {
            status &= ~(1 << SERIAL_STATUS_TXE);
        }
        return true;
    } else if (addr == SERIAL_BASE + SERIAL_BAUD) {
        baud = val;
        return true;
    } else if (addr == SERIAL_BASE + SERIAL_CONTROL) {
        control = val;
        return true;
    } else if (addr == SERIAL_BASE + SERIAL_CONTROL) {
        // Clear the bits that were set in the write
        status &= ~val;
        return true;
    }

    return false;
}

boost::optional<uint32_t> serial_port::read(cpu_t &cpu, uint32_t addr, uint8_t width) {
    if (width != 4 || (addr & 0x3) != 0)
        return boost::none;
    if (addr == SERIAL_BASE + SERIAL_BAUD) {
        return baud;
    } else if (addr == SERIAL_BASE + SERIAL_CONTROL) {
        return control;
    } else if (addr == SERIAL_BASE + SERIAL_STATUS) {
        return status;
    }

    return boost::none;
}
