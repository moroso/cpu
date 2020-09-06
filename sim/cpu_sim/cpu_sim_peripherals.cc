#ifdef USE_SDL
#include <SDL/SDL.h>
#endif

#include "cpu_sim.h"
#include "cpu_sim_peripherals.h"

extern bool verbose;

peripheral_manager::peripheral_manager() {
    ictl = new interrupt_controller(16);
    vid = new video();

    // LEDSW. Not simulated yet.
    peripherals.push_back(new peripheral());
    // Serial.
    peripherals.push_back(new serial_port());
    // I2C. Not simulated yet.
    peripherals.push_back(new peripheral());
    // SD. Not simulated yet.
    peripherals.push_back(new peripheral());
    // Audio. Not simulated yet.
    peripherals.push_back(new peripheral());
    // Video.
    peripherals.push_back(vid);
    // Interrupt controller.
    peripherals.push_back(ictl);
    // No peripheral in this slot.
    peripherals.push_back(new peripheral());
    // Eight timers.
    for (int i = 0; i < 8; i += 1) {
        peripherals.push_back(new cycle_timer());
    }

    for (int i = 0; i < peripherals.size(); i += 1) {
        last_int_flags.push_back(0);
    }

    if (verbose) {
        printf("Peripheral map:\n");
        for (int i = 0; i < peripherals.size(); i += 1) {
            printf("%d %s\n", i, peripherals[i]->name().c_str());
        }
    }
}

bool peripheral_manager::process(cpu_t &cpu) {
    for (int i = 0; i < peripherals.size(); i += 1) {
        // Interrupt controller has to happen last.
        if (peripherals[i] == ictl) { continue; }
        uint32_t result = peripherals[i]->process(cpu);
        if (result != last_int_flags[i]) {
            last_int_flags[i] = result;
            ictl->set_hw_flag(i, result);
        }
    }

    ictl->process(cpu);

    return ictl->interrupt_fired();
}

bool peripheral_manager::check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    if (addr < PERIPHERAL_BASE) {
        return false;
    }

    int idx = (addr - PERIPHERAL_BASE) >> 12;
    int offs = addr & 0xfff;
    if (idx >= peripherals.size()) {
        return false;
    }

    //return peripheral_vec[idx].check_write(cpu, offs, val, width);
    return true;
}

bool peripheral_manager::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    if (check_write(cpu, addr, val, width)) {
        assert(addr >= PERIPHERAL_BASE);

        int idx = (addr - PERIPHERAL_BASE) >> 12;
        int offs = addr & 0xfff;

        assert(idx < peripherals.size());

        peripherals[idx]->write(cpu, offs, val, width);

        return true;
    } else {
        // The video peripheral does the checking of whether this is really within
        // vram. We should send it all writes that aren't in peripheral space.
        vid->video_mem_write(cpu, addr, val, width);
        return false;
    }
}

boost::optional<uint32_t> peripheral_manager::read(cpu_t &cpu, uint32_t addr, uint8_t width) {
    //printf("Asking peripheral to read from %x\n", addr);
    if (addr < PERIPHERAL_BASE) {
        //printf("  Rejected: too small\n");
        return boost::none;
    }

    int idx = (addr - PERIPHERAL_BASE) >> 12;
    int offs = addr & 0xfff;

    //printf("Index %d, offset %d\n", idx, offs);

    if (idx >= peripherals.size()) {
        //printf("  Rejected: too large\n");
        return boost::none;
    }

    //printf("Handling via %s\n", peripherals[idx]->name().c_str());
    uint32_t val = peripherals[idx]->read(cpu, offs);
    if (width == 4) {
        return val;
    } else if (width == 2) {
        return val >> ((addr & 1) * 16);
    } else if (width == 1) {
        return val >> ((addr & 3) * 8);
    } else {
        fprintf(stderr, "Unsupported width %d\n", width);
        abort();
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// INTERRUPT CONTROLLER

interrupt_controller::interrupt_controller(uint32_t num_peripherals) {
    for (int i = 0; i < num_peripherals; i += 1) {
        mask.push_back(0);
        pending.push_back(0);
    }

    firing_interrupts = 0;
    int_fired = false;
}

void interrupt_controller::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: support unaligned writes
    uint32_t base = addr >> 10;
    uint32_t offs = (addr >> 2) & 0xff;
    if (base == 1) {
        // Interrupt pending registers
        if (offs < pending.size()) {
            pending[offs] &= ~val;
        }
    } else if (base == 2) {
        // Interrupt enable registers
        if (offs < mask.size()) {
            mask[offs] = val;
        }
    }

    recompute();
}

uint32_t interrupt_controller::read(cpu_t &cpu, uint32_t addr) {
    uint32_t base = addr >> 10;
    uint32_t offs = (addr >> 2) & 0xff;
    if (base == 0 && offs == 0) {
        return firing_interrupts;
    } else if (base == 1) {
        // Interrupt pending registers
        if (offs < pending.size()) {
            return pending[offs];
        } else {
            return 0;
        }
    } else if ((addr >> 10) == 2) {
        // Interrupt enable registers
        if (offs < mask.size()) {
            return mask[offs];
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

void interrupt_controller::set_hw_flag(uint32_t periph, uint32_t flags) {
    pending[periph] |= flags;
    recompute();
}

void interrupt_controller::recompute(void) {
    firing_interrupts = 0;
    for (int i = 0; i < mask.size(); i += 1) {
        if (pending[i] & mask[i]) {
            firing_interrupts |= 1 << i;
        }
    }
}

uint32_t interrupt_controller::process(cpu_t &cpu) {
    int_fired = false;
    if (firing_interrupts) {
        if (!(cpu.regs.cpr[CP_PFLAGS] & (1 << PFLAGS_INT_ENABLE)))
            return 0;

        cpu.clear_exceptions();
        cpu.regs.cpr[CP_EC0] = EXC_INTERRUPT;
        int_fired = true;
    }
    return 0;
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// TIMER

uint32_t cycle_timer::process(cpu_t &cpu) {
    if (enable) {
        count += 1; // Assume we get an instruction every 3 cycles or so.
        if (verbose)
            printf("count: %d top: %d\n", count, top);
    }
    if (count >= top) {
        count = 0;
        return 1;
    }

    return 0;
}

void cycle_timer::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: support unaligned writes? Will we even allow those?
    if (addr == TIMER_COUNT) {
        count = val;
    } else if (addr == TIMER_TOP) {
        top = val;
    } else if (addr == TIMER_CONTROL) {
        enable = BIT(val, TIMER_CONTROL_EN);
    }
}

uint32_t cycle_timer::read(cpu_t &cpu, uint32_t addr) {
    if (addr == TIMER_COUNT) {
        return count;
    } else if (addr == TIMER_TOP) {
        return top;
    } else if (addr == TIMER_CONTROL) {
        return enable << TIMER_CONTROL_EN;
    }

    return 0;
}


/////////////////////////////////////////////////////////////////////////////////////////////////
// VIDEO

#ifdef USE_SDL

video::video() {
    SDL_Init(SDL_INIT_VIDEO);
    screen = SDL_SetVideoMode(640, 480, 24, SDL_SWSURFACE);
    count = 0;
    video_offset = 0;

    needs_updating = false;
    min_x = screen->w - 1;
    max_x = 0;
    min_y = screen->h - 1;
    max_y = 0;
}

uint32_t video::process(cpu_t &cpu) {
    // This isn't great. But updating the screen every write is extremely slow.
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

    return 0;
}

uint32_t video::screen_size() {
    return screen->pitch * screen->h;
}

void video::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    if (addr == VIDEO_BASE && width == 4) {
        video_offset = val;
        memcpy(screen->pixels, &cpu.ram[video_offset], screen_size());

        needs_updating = true;
        min_x = 0;
        max_x = screen->w;
        min_y = 0;
        max_y = screen->h;
    }
}

void video::video_mem_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // We write to real memory, but also do a write to the video buffer.
    // (The memory write is handled by the core, so we just need to
    // take care of the latter.)
    if (addr < video_offset || addr >= video_offset + screen_size()) {
        return;
    }
    for (int i = 0; i < width; i++) {
        *((uint8_t *)screen->pixels + (addr + i - video_offset)) = val & 0xff;
        val >>= 8;
    }
    uint32_t offs = (addr - video_offset) / 3;
    uint32_t y = offs / screen->w;
    uint32_t x = offs % screen->w;

    if (x < min_x) min_x = x;
    if (x > max_x) max_x = x;
    if (y < min_y) min_y = y;
    if (y > max_y) max_y = y;
    needs_updating = true;
}

uint32_t video::read(cpu_t &cpu, uint32_t addr) {
    if (addr == VIDEO_BASE) {
        return video_offset;
    } else {
        return 0;
    }
}

#endif


/////////////////////////////////////////////////////////////////////////////////////////////////
// Serial

uint32_t serial_port::process(cpu_t &cpu) {
    //printf("%x\n", csr);
    if (state == SERIAL_TRANSMITTING) {
        counter++;
        if (counter == 1000) { // TODO: baud
            fprintf(stderr, "%c", tx_shift);
            counter = 0;
            // Is there another character waiting in the buffer?
            if (!(csr & (1 << SERIAL_CSR_TXE))) {
                tx_shift = tx_buf;
            } else {
                state = SERIAL_IDLE;
            }
            csr |= (1 << SERIAL_CSR_TXC) | (1 << SERIAL_CSR_TXE);
        }
    }

    /* Note: interrupts aren't supported in hardware yet.
    if ((status & control) != 0) {
        return fire_interrupt(cpu, INT_SERIAL);
    }*/

    return 0;
}

void serial_port::write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: support unaligned writes? Will we even allow those?

    if (addr == SERIAL_DATA) {
        tx_buf = val;
        if (state == SERIAL_IDLE) {
            state = SERIAL_TRANSMITTING;
            counter = 0;
            tx_shift = tx_buf;
            // TODO: get the status bits right
            csr |= (1 << SERIAL_CSR_TXE);
        } else {
            csr &= ~(1 << SERIAL_CSR_TXE);
        }
    } else if (addr == SERIAL_CSR) {
        csr = val;
    }
    // TODO: baud, etc.
}

uint32_t serial_port::read(cpu_t &cpu, uint32_t addr) {
    //printf("Serial read\n");
    if (addr == SERIAL_DATA) {
        // TODO: support serial reads
        return 0;
    } else if (addr == SERIAL_CSR) {
        return csr;
    }

    //printf("Read not handled\n");
    return 0;
}
