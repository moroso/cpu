#include "cpu_sim_ops.h"
#include "cpu_sim_utils.h"

#include <sstream>
#include <string>

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>

#include <boost/optional/optional.hpp>
#include <boost/format.hpp>


std::string other_instruction::opcode_str() {
    return decoded_instruction::opcode_str() + " - " + OTHEROP_STR[otherop];
}

std::string other_instruction::to_string() {
    std::string result = decoded_instruction::to_string();

    if (reserved_bits != 0x00)
        result += string_format("  * WARNING: reserved bits nonzero (%x)\n", reserved_bits);

    return result;
}

bool other_instruction::execute(cpu_t &cpu, uint32_t old_pc) {
    if (otherop == OTHER_BREAK && reserved_bits == 0x1FU) {
        // MAGIC_HALT
        return true;
    }

    return false;
}
