#include "cpu_sim.h"
#include "cpu_sim_utils.h"

#include <string.h>

#define SIM_RAM_BYTES 64 * 1024  // Ought to be enough for anybody

cpu_t cpu;

/*

NOP: ADD R0 <- R0 + R0 (!P3) -> [111 0 0000000000 0000 0000 00000 00000 -> E000 0000]
HALT: BREAK 0x1FU -> [110 10001 00011 00000 1111 00000 00000 -> D118 3C00]

First sample program (trivial infinite loop):

asm:    B $0 (P3) / NOP / NOP / NOP
binary: 110 1100 0000000000000000000000000 / (111 0 0000000000 0000 0000 00000 00000) *3
hex:    D800 0000 / (E000 0000) *3


Second sample program (infinite loop with counter):

asm:    B $0 (P3) / ADD R0 <- R0 + 0x1 (P3) / NOP / NOP
binary: 110 1100 0000000000000000000000000 / 110 0 0000000001 0000 0000 00000 00000 / NOP*2
hex:    D800 0000 / C004 0000 / (E000 0000) *2


Third sample program (testing rotated constants):

asm:    ADD R0 <- R0 + (0x1 ROT 0x0)  = 0x00000001 /
        ADD R1 <- R1 + (0x1 ROT 0x2)  = 0x40000000 /
        ADD R2 <- R2 + (0x1 ROT 0x16) = 0x00000400 /
        ADD R3 <- R3 + (0x200 ROT 0x0) = 0x00000200
binary: 110 0 0000000001 0000 0000 00000 00000 /
        110 0 0000000001 0001 0000 00001 00001 /
        110 0 0000000001 1011 0000 00010 00010 /
        110 0 1000000000 0000 0000 00011 00011
hex:    C004 0000 / C004 4021 / C006 C042 / C800 0063


Fourth sample program (testing long immediates):

asm:    MOV R0 <- long(0xF0F0F0F0) / XXX / NOP / NOP
binary: 110 100000000000000 1000 00000 00000 /
        1111 0000 1111 0000 1111 0000 1111 0000 /
        NOP*2
hex:    D000 2000 / F0F0 F0F0 / (E000 0000) *2
*/

const size_t MAX_PROG_LEN = 0x256;
instruction ROM[][MAX_PROG_LEN] = {
    {
        0xD0002000, 0xF0F0F0F0, 0xE0000000, 0xE0000000,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
    {
        0xC0040000, 0xC0044021, 0xC006C042, 0xC8000063,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
    {
        0xD8000000, 0xE0000000, 0xE0000000, 0xE0000000,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
    {
        0xD8000000, 0xC0040000, 0xE0000000, 0xE0000000,
        0xD1183C00, 0xE0000000, 0xE0000000, 0xE0000000
    },
};
size_t ROMLEN = array_size(ROM);

void run_program() {
    instruction *mem = cpu.ram->code;
    cpu.regs.pc = 0x0;

    while(true) {
        printf("cpu.regs.pc is now 0x%x\n", cpu.regs.pc);
        printf("cpu.regs.r = { ");
        for (int i = 0; i < 32; ++i) {
            printf("%x, ", cpu.regs.r[i]);
        }
        printf("}\n");
        size_t instr_num = cpu.regs.pc/4;
        printf("Packet is %x / %x / %x / %x\n", mem[instr_num], mem[instr_num+1], mem[instr_num+2], mem[instr_num+3]);
        decoded_packet packet(&mem[instr_num]);
        printf("Packet looks like:\n");
        printf("%s", packet.to_string().c_str());
        printf("Executing packet...\n");
        if(packet.execute(cpu)) {
            printf("... BREAK 0x1FU -> end program\n");
            break;
        }
        printf("...done.\n");
    }
}

int main(int argc, char** argv) {
    cpu.ram = (mem_t *)malloc(SIM_RAM_BYTES);

    if (argc > 1) {
        if (!strcmp(argv[1], "random")) {
            srand(0);
            printf("Random instruction mode\n");
            while(true) {
                instruction instr = rand32();
                printf("Disassembling single instruction %x (%u):\n", instr, instr);
                shared_ptr<decoded_instruction> di = decoded_instruction::decode_instruction(instr);
                printf("%s\n\n\n", di->to_string().c_str());
            }
        }

        if (!strcmp(argv[1], "test")) {
            printf("OSOROM simulator starting in test mode\n");

            for (int i = 0; i < ROMLEN; ++i) {
                printf("Running test program #%d\n", i);
                bzero(cpu.ram, SIM_RAM_BYTES);
                memcpy(cpu.ram, ROM[i], MAX_PROG_LEN);
                run_program();
            }

            printf("OROSOM simulator terminating\n");
        }

        instruction instr = strtoul(argv[1], 0, 0);
        printf("Disassembling single instruction %x (%u):\n", instr, instr);
        shared_ptr<decoded_instruction> di = decoded_instruction::decode_instruction(instr);
        printf("%s\n", di->to_string().c_str());
        exit(0);
    }


    printf("OSOROM simulator starting\n");

    size_t i = 0;
    while(read(STDIN_FILENO, (uint32_t*)cpu.ram + i, sizeof(instruction)) > 0) {
        ++i;
        printf("%d instructions read. %d\n", i, (uint32_t*)cpu.ram + i);
    }

    run_program();
    printf("OROSOM simulator terminating\n");
}
