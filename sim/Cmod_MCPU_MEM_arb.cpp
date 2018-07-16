#include "Cmod_MCPU_MEM_arb.h"
#include "Sim.h"
#include "mem_common.h"

#define DATA_BYTES 32
// Requests will be delayed by anywhere from
// DELAY_CYCLES_BASE to DELAY_CYCLES_BASE + DELAY_CYCLES_RAND
// cycles.
#define DELAY_CYCLES_BASE 16
#define DELAY_CYCLES_RAND 16

Cmod_MCPU_MEM_arb::Cmod_MCPU_MEM_arb() :
  current_client(0),
  active(false),
  remaining_cycles(0)
{
}

void Cmod_MCPU_MEM_arb::add_client(Cmod_MCPU_MEM_arb_ports *_ports) {
  *_ports->arb_stall = 0;
  *_ports->arb_rvalid = 0;

  clients.push_back(_ports);
}

void Cmod_MCPU_MEM_arb::clk() {
  for (Cmod_MCPU_MEM_arb_ports *client: clients) {
    // Stall all clients that are trying to make requests.
    // (If we're just finishing one, we'll un-stall it below.)
    *client->arb_stall = *client->arb_valid;
    if (*client->arb_valid)
      *client->arb_rvalid = 0;
  }

  if (active) {
    remaining_cycles -= 1;

    SIM_DEBUG("Client %d active; %d cycles remain", current_client, remaining_cycles);

    if (remaining_cycles == 0) {
      Cmod_MCPU_MEM_arb_ports* client = clients[current_client];
      int adjusted_addr = *client->arb_addr << 5;

      *client->arb_stall = 0;

      SIM_DEBUG("Opcode = %d", *client->arb_opcode);
      switch (*client->arb_opcode) {
      case LTC_OPC_READ:
      case LTC_OPC_READTHROUGH: {
          SIM_DEBUG("Performing read from %08x", adjusted_addr);
          for (int i = 0; i < DATA_BYTES / 4; i++) {
            client->arb_rdata[i] = read(adjusted_addr + i * 4);
          }
          *clients[current_client]->arb_rvalid = 1;
          break;
        }
      case LTC_OPC_WRITE:
      case LTC_OPC_WRITETHROUGH: {
          SIM_DEBUG("Performing write to %08x", adjusted_addr);
          // Do writes a byte at at time to make checking the mask easier.
          for (int i = 0; i < DATA_BYTES; i++) {
            if (*client->arb_wbe & (1<<i)) {
              write_b(adjusted_addr + i, client->arb_wdata[i/4] >> ((i%4) * 8));
            }
          }
          break;
        }
        // Nothing to do for clear or prefetch--we're not actually
        // simulating the caching.
        default: break;
      }

      active = false;
    } else if (remaining_cycles == 1) {
      // De-assert stall one cycle before we're ready.
      *clients[current_client]->arb_stall = 0;
    }
  } else {
    // No client was previously active. See if we have a request waiting.

    for (int i = 0; i < clients.size(); i += 1) {
      int candidate = (current_client + i) % clients.size();
      if (*clients[candidate]->arb_valid) {
        SIM_DEBUG("Selected client %d", candidate);
        // Found one! Mark it as in-progress.
        current_client = candidate;

        remaining_cycles = DELAY_CYCLES_BASE + Sim::random(DELAY_CYCLES_RAND);
        active = true;

        break;
      }
    }
  }
}

#define MASK(X) ((X) & 0x3fffffff)

void Cmod_MCPU_MEM_arb::write_w(uint32_t addr, uint32_t val) {
  addr = MASK(addr);
  memory[addr] = val;
  memory[addr+1] = val >> 8;
  memory[addr+2] = val >> 16;
  memory[addr+3] = val >> 24;
}

void Cmod_MCPU_MEM_arb::write_h(uint32_t addr, uint16_t val) {
  addr = MASK(addr);
  memory[addr] = val;
  memory[addr+1] = val >> 8;
}

void Cmod_MCPU_MEM_arb::write_b(uint32_t addr, uint8_t val) {
  addr = MASK(addr);
  memory[addr] = val;
}

uint32_t Cmod_MCPU_MEM_arb::read(uint32_t addr) {
  addr = MASK(addr);
  return memory[addr] |
    memory[addr+1] << 8 |
    memory[addr+2] << 16 |
    memory[addr+3] << 24;
}
