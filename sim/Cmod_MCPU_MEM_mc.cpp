#include "Cmod_MCPU_MEM_mc.h"
#include "Sim.h"

Cmod_MCPU_MEM_mc::Cmod_MCPU_MEM_mc(Cmod_MCPU_MEM_mc_ports *_ports) :
	ports(_ports), 
	burst_length(0),
  burst_idx(0),
	burst_read(false),
  burst_write(false) {

	*ports->ltc2mc_avl_ready_0 = 0;
	*ports->ltc2mc_avl_rdata_valid_0 = 0;
	ports->ltc2mc_avl_rdata_0[0] = ports->ltc2mc_avl_rdata_0[1] = ports->ltc2mc_avl_rdata_0[2] = ports->ltc2mc_avl_rdata_0[3] = 0;
	
	ltc2mc_avl_read_req_0_last = ltc2mc_avl_write_req_0_last = 0;
}

/* WDatas are little endian. */
void Cmod_MCPU_MEM_mc::clk() {
	if (!*ports->ltc2mc_avl_ready_0) {
		/* Assert that nothing has changed.  Don't do any actual work if we're not ready! */
		SIM_CHECK((ltc2mc_avl_read_req_0_last == *ports->ltc2mc_avl_read_req_0) && "read request changed during not ready");
		SIM_CHECK((ltc2mc_avl_write_req_0_last == *ports->ltc2mc_avl_write_req_0) && "write request changed during not ready");
    *ports->ltc2mc_avl_rdata_valid_0 = 0;
	} else {
    if (*ports->ltc2mc_avl_burstbegin_0) {
      SIM_CHECK_MSG(*ports->ltc2mc_avl_ready_0, "Starting a burst while controller isn't ready");
      SIM_CHECK_MSG(!burst_read, "Starting a burst while a read is in progress");
      SIM_CHECK_MSG(!burst_write, "Starting a burst while a write is in progress");

      burst_base = *ports->ltc2mc_avl_addr_0 * 16;
      burst_length = 8; // TODO: support other burst sizes and actually read the wires.
      burst_idx = 0;
      if (*ports->ltc2mc_avl_read_req_0) {
        burst_read = true;
      } else if (*ports->ltc2mc_avl_write_req_0) {
        burst_write = true;
      }
    }

    if (burst_read) {
      SIM_CHECK_MSG(!burst_write, "Burst write during read");

      if (Sim::random(100) < 50) {
        *ports->ltc2mc_avl_rdata_valid_0 = 1;

        uint32_t memad = burst_base + 16 * burst_idx;
        int i;

        for (i = 0; i < 4; i++)
          ports->ltc2mc_avl_rdata_0[i] =
            (memory[memad + i*4 + 0] <<  0) | (memory[memad + i*4 + 1] <<  8) |
            (memory[memad + i*4 + 2] << 16) | (memory[memad + i*4 + 3] << 24);

        burst_idx += 1;
        if (burst_idx == burst_length) {
          burst_read = false;
        }
      } else {
        *ports->ltc2mc_avl_rdata_valid_0 = 0;
      }
    } else {
      *ports->ltc2mc_avl_rdata_valid_0 = 0;
    }

    if (burst_write) {
      if (*ports->ltc2mc_avl_write_req_0) {
        uint32_t memad = burst_base + 16 * burst_idx;
        int i;

        for (i = 0; i < 16; i++)
          if (*ports->ltc2mc_avl_be_0 & (1 << i))
            memory[memad + i] = (ports->ltc2mc_avl_wdata_0[i / 4] >> ((i % 4) * 8)) & 0xFF;

        burst_idx += 1;
        if (burst_idx == burst_length) {
          burst_write = false;
        }
      }
    }
	}

  if (!*ports->ltc2mc_avl_rdata_valid_0) {
    for (int i = 0; i < 4; i++)
      ports->ltc2mc_avl_rdata_0[i] = 0xbadbadba;
  }


	ltc2mc_avl_write_req_0_last = *ports->ltc2mc_avl_write_req_0;
	ltc2mc_avl_read_req_0_last = *ports->ltc2mc_avl_read_req_0;

	/* Set up ready for next time. */
	*ports->ltc2mc_avl_ready_0 = Sim::random(100) < 96;
}
