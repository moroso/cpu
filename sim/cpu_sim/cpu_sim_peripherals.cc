#include "cpu_sim.h"
#include "cpu_sim_peripherals.h"

bool peripheral::fire_interrupt(cpu_t &cpu, uint8_t interrupt) {
    if (!cpu.regs.cpr[CP_PFLAGS] & (1 << PFLAGS_INT_ENABLE))
        return false;

    cpu.clear_exceptions();
    cpu.regs.cpr[CP_EC0] = EXC_INTERRUPT | (interrupt << 5);
    return true;
}

bool cycle_timer::check_write(cpu_t &cpu, uint32_t addr, uint32_t val, uint8_t width) {
    // TODO: improve this.
    printf("Periph checking %x\n", addr);
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
        printf("Interrupt?\n");
    }

    if (int_flag && int_enable) {
        printf("Interrupt!\n");
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
