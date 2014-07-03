#include "cpu_sim.h"

#include <string.h>
#include <stdarg.h>

// From StackOverflow user Erik Aronesty, http://stackoverflow.com/a/8098080 .
std::string string_format(const std::string fmt_str, ...) {
    int final_n, n = ((int)fmt_str.size()) * 2; /* reserve 2 times as much as the length of the fmt_str */
    std::string str;
    std::unique_ptr<char[]> formatted;
    va_list ap;
    while(1) {
        formatted.reset(new char[n]); /* wrap the plain char array into the unique_ptr */
        strcpy(&formatted[0], fmt_str.c_str());
        va_start(ap, fmt_str);
        final_n = vsnprintf(&formatted[0], n, fmt_str.c_str(), ap);
        va_end(ap);
        if (final_n < 0 || final_n >= n)
            n += abs(final_n - n + 1);
        else
            break;
    }
    return std::string(formatted.get());
}

uint32_t rand32() {
    return
        (rand() & 0xff) |
        ((rand() & 0xff) << 8) |
        ((rand() & 0xff) << 16) |
        ((rand() & 0xff) << 24);
}

uint32_t shiftwith(uint32_t value, uint32_t shiftamt, shift_type stype) {
    switch(stype) {
        case LSL:
            return value << shiftamt;
        case LSR:
            return value >> shiftamt;
        case ASR:
            return ((int32_t)value) >> shiftamt;
        case ROR:
            return (value >> shiftamt) | (value << (32 - shiftamt));
    }
}