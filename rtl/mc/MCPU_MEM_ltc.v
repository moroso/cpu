/* MCPU_MEM_ltc
 * Level 2 cache
 * Moroso project SOC
 * 
 *** Summary
 *
 * The mcpu LTC further abstracts the LPDDR2 PHY's Avalon memory interface
 * into a 32-byte "atom" interface.  Wider atoms allow more data to be
 * transferred between caches with lower latency; on the other hand, wider
 * atoms also result in more substantial wiring congestion in the SoC.  32
 * bytes seemed as good a compromise as any.
 *
 * The LTC has a command-and-data interface that feeds into an internal
 * FIFO.  It buffers some internally, but enforces a strict ordering on its
 * external interface -- after a write has been issued, it is guaranteed to
 * be accessible to other clients immediately.  Data is returned from read
 * requests some time after they are issued; in the case of cache hits,
 * requests may be returned in just a few cycles, whereas requests that have
 * to go out to main memory can take quite a lot longer.
 *
 * LTC provides a set of six opcodes for users: normal read, normal write,
 * read-through (reads from cache or from main memory, but does not evict a
 * cache line in the latter case), write-through (writes to cache or to main
 * memory, but does not evict a cache line in the latter case), prefetch,
 * and clean.  LTC supports read-under-prefetch.
 *
 * LTC could be extended to support client IDs, allowing for
 * read-under-miss; in the current single-client design, this cannot be
 * achieved while still having responses guaranteed to be returned in the
 * same order as requests.
 *
 * (The following figures are tentative, and may change.)  LTC is a 64kB
 * cache; this means that it stores 2048 atoms.  Cache lines are four atoms
 * (128 bytes) wide; this means that LTC has 128 cache lines.  Cache lines
 * are 4-way set associative; this means that LTC has 32 sets.  So, the
 * system address mapping looks like this:
 *   addr[ 4: 0]: atom offset
 *   addr[ 6: 5]: cache line offset
 *   addr[11: 7]: set
 *   addr[31:12]: tag
 *
 * LTC is going to be an enormous pain to verify.  Let's just hope we get it
 * right the first time.
 *
 *** Implementation details
 *
 * All outputs are zero.  Lol!
 */

`timescale 1 ps / 1 ps

module MCPU_MEM_ltc(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_addr_0, ltc2mc_avl_be_0, ltc2mc_avl_burstbegin_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_size_0, ltc2mc_avl_wdata_0,
   ltc2mc_avl_write_req_0, arb2ltc_rdata, arb2ltc_rvalid,
   arb2ltc_stall,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, ltc2mc_avl_rdata_0,
   ltc2mc_avl_rdata_valid_0, ltc2mc_avl_ready_0, arb2ltc_valid,
   arb2ltc_opcode, arb2ltc_addr, arb2ltc_wdata, arb2ltc_wbe
   );

/* opcode parameters */
`include "MCPU_MEM_ltc.vh"

	parameter WAYS = 4;
	parameter WAYS_BITS = 2;
	parameter SETS = 32;
	parameter ATOMS_PER_LINE = 4;
	
	parameter TAG_UPPER = 31;
	parameter TAG_LOWER = 12;
	parameter TAG_BITS  = (TAG_UPPER - TAG_LOWER + 1);
	
	parameter SET_UPPER = 11;
	parameter SET_LOWER =  7;
	parameter SET_BITS  = (SET_UPPER - SET_LOWER + 1);
	
	parameter ATOM_UPPER = 6;
	parameter ATOM_LOWER = 5;
	parameter ATOM_BITS  = (ATOM_UPPER - ATOM_LOWER + 1);
	
	parameter BYTE_UPPER = 4;
	parameter BYTE_LOWER = 0;
	parameter BYTES_IN_ATOM = 32;
	parameter BITS_IN_ATOM = BYTES_IN_ATOM * 8;
	parameter BYTE_BITS  = (BYTE_UPPER - BYTE_LOWER + 1);

	/*** Portlist ***/
	
	/* Clocks */
	input           clkrst_mem_clk;
	input           clkrst_mem_rst_n;

	/* Avalon interface */
	output [24:0]	ltc2mc_avl_addr_0;
	output [15:0]	ltc2mc_avl_be_0;
	output		ltc2mc_avl_burstbegin_0;
	output		ltc2mc_avl_read_req_0;
	output [4:0]	ltc2mc_avl_size_0;
	output [127:0]	ltc2mc_avl_wdata_0;
	output		ltc2mc_avl_write_req_0;
	input [127:0]	ltc2mc_avl_rdata_0;
	input		ltc2mc_avl_rdata_valid_0;
	input		ltc2mc_avl_ready_0;
	
	/* Atom interface */
	/* XXX: Add LTC streams */
	input           arb2ltc_valid;
	input [2:0]     arb2ltc_opcode;
	input [31:5]	arb2ltc_addr;
	
	input [255:0]   arb2ltc_wdata;
	input [31:0]    arb2ltc_wbe;
	
	output [255:0]  arb2ltc_rdata;
	output          arb2ltc_rvalid;
	
	output          arb2ltc_stall;
	
	/*** Logic ***/
	
	/*AUTOREG*/
	// Beginning of automatic regs (for this module's undeclared outputs)
	reg [255:0]	arb2ltc_rdata;
	reg		arb2ltc_rvalid;
	reg		arb2ltc_stall;
	reg [24:0]	ltc2mc_avl_addr_0;
	reg [15:0]	ltc2mc_avl_be_0;
	reg		ltc2mc_avl_burstbegin_0;
	reg		ltc2mc_avl_read_req_0;
	reg [4:0]	ltc2mc_avl_size_0;
	reg [127:0]	ltc2mc_avl_wdata_0;
	reg		ltc2mc_avl_write_req_0;
	// End of automatics
	
	/*** Request input pipe ***/
	wire         arb2ltc_valid_0a = arb2ltc_valid;
	wire [2:0]   arb2ltc_opcode_0a = arb2ltc_opcode;
	wire [31:5]  arb2ltc_addr_0a = arb2ltc_addr;
	wire [255:0] arb2ltc_wdata_0a = arb2ltc_wdata;
	wire [31:0]  arb2ltc_wbe_0a = arb2ltc_wbe;
	
	wire        arb2ltc_is_read_0a  = arb2ltc_valid_0a && ((arb2ltc_opcode == LTC_OPC_READ) || (arb2ltc_opcode == LTC_OPC_READTHROUGH));
	wire        arb2ltc_is_write_0a = arb2ltc_valid_0a && ((arb2ltc_opcode == LTC_OPC_WRITE) || (arb2ltc_opcode == LTC_OPC_WRITETHROUGH));
	
	reg         arb2ltc_valid_1a;
	reg [2:0]   arb2ltc_opcode_1a;
	reg [31:5]  arb2ltc_addr_1a;
	
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			arb2ltc_valid_1a <= 0;
			arb2ltc_opcode_1a <= 3'b0;
			arb2ltc_addr_1a <= 27'b0;
		end else begin
			/* XXX stall */
			arb2ltc_valid_1a <= arb2ltc_valid_0a;
			arb2ltc_opcode_1a <= arb2ltc_opcode_0a;
			arb2ltc_addr_1a <= arb2ltc_addr_0a;
		end
	
	wire            stall_0a;
	
	/*** Fill feedback path (from below) ***/
	reg          resp_wr;
	reg          resp_wr_1a;
	reg          resp_rd;
	reg          resp_rd_1a;
	wire         resp_override = resp_wr | resp_rd;
	reg          resp_override_1a;
	reg          resp_fill_start, resp_fill_end;
	reg   [31:5] resp_addr;
	wire [255:0] resp_data;

	/* XXX: evades, not solves race condition in write-vs-refill path... */
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			resp_wr_1a <= 0;
			resp_rd_1a <= 0;
			resp_override_1a <= 0;
		end else begin
			resp_wr_1a <= resp_wr;
			resp_rd_1a <= resp_rd;
			resp_override_1a <= resp_override;
		end


	/*** Cache ways ***/
	
	/* Note that the ltc2mc/mc2ltc path always takes precedence.  So if
	 * there's going to be an arb2ltc operation, you better nerf it if
	 * we're doing an mc operation on the same cycle!
	 */
	
	wire [SETS-1:0] set_valid_0a;
	wire [SETS-1:0] set_dirty_0a;
	wire [255:0]    set_rd_data_1a [SETS-1:0];
	wire [TAG_UPPER:TAG_LOWER] set_evicting_tag [SETS-1:0];
	reg  [255:0]    rd_data_1a;
	wire            rd_valid_0a;
	reg             rd_valid_1a;
	wire [TAG_UPPER:TAG_LOWER] evicting_tag = set_evicting_tag[arb2ltc_addr_0a[SET_UPPER:SET_LOWER]];
	
	genvar set;
	genvar way;
	genvar ii;
	integer i;
	generate
		for (set = 0; set < SETS; set = set + 1) begin: set_gen
			wire [WAYS-1:0] ways_match_0a;
			reg [WAYS_BITS-1:0] way_0a;
			reg [WAYS-1:0] way_valid;
			reg [WAYS-1:0] way_dirty;
			reg [WAYS_BITS-1:0] way_evicting;
			
			reg [BITS_IN_ATOM-1:0] lines [(WAYS * ATOMS_PER_LINE)-1:0];
			reg [BITS_IN_ATOM-1:0] line_rd_data_1a;
			
			wire set_selected_0a;
			
			reg [TAG_UPPER:TAG_LOWER] way_tag [WAYS-1:0];
			
			/* Way CAM */
			/* The way CAM is actually unused during eviction -- it's overridden by way_evicting. */
			for (way = 0; way < WAYS; way = way + 1) begin: way_gen
				always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
					if (~clkrst_mem_rst_n) begin
						way_tag[way] <= {TAG_BITS{1'bx}};
					end else begin
						if (set_selected_0a && resp_wr && (way_evicting == way[WAYS_BITS-1:0])) /* always from mc2ltc path, never from arb2ltc path */
							way_tag[way] <= resp_addr[TAG_UPPER:TAG_LOWER];
					end
				
				assign ways_match_0a[way] = way_tag[way][TAG_UPPER:TAG_LOWER] == arb2ltc_addr_0a[TAG_UPPER:TAG_LOWER]; /* always from arb2ltc path, never from mc2ltc path */
			end
			assign set_evicting_tag[set] = way_tag[way_evicting];
			
			/* Way and RAM select logic */
			assign set_valid_0a[set] = |(ways_match_0a & way_valid);
			always @(*) begin
				way_0a = {WAYS_BITS{1'bx}};
				for (i = 0; i < WAYS; i = i + 1)
					if (ways_match_0a[i] && way_valid[i])
						way_0a = i[WAYS_BITS-1:0];
			end
			/* XXX needs rd and wr split out */
			assign set_selected_0a = (resp_override ? resp_addr[SET_UPPER:SET_LOWER] : arb2ltc_addr_0a[SET_UPPER:SET_LOWER]) == set[SET_BITS-1:0];
			
			wire [WAYS_BITS + ATOM_BITS - 1:0] line_addr = 
			  resp_override ? {way_evicting, resp_addr[ATOM_UPPER:ATOM_LOWER]} 
			                : {way_0a, arb2ltc_addr_0a[ATOM_UPPER:ATOM_LOWER]};
			
			/* Set read logic */
			always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
				if (~clkrst_mem_rst_n) begin
					line_rd_data_1a <= 256'b0;
				end else begin
					if ((set_selected_0a && set_valid_0a[set] && arb2ltc_is_read_0a) || /* arb2ltc path */
					    (set_selected_0a && resp_rd) /* mc2ltc flush path */)
						line_rd_data_1a <= lines[line_addr];
				end
			
			/* Set write logic */
			/* We have to generate for byte enables. */
			for (ii = 0; ii < BYTES_IN_ATOM; ii = ii + 1)
				always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
					if (~clkrst_mem_rst_n) begin
					end else begin
						if ((set_selected_0a && set_valid_0a[set] && arb2ltc_is_write_0a && arb2ltc_wbe_0a[ii]) || /* arb2ltc path */
						    (set_selected_0a && resp_wr)) /* mc2ltc refill path */
							lines[line_addr][ii*8+7:ii*8] <=
							  resp_wr ? resp_data[ii*8+7:ii*8]
							          : arb2ltc_wdata_0a[ii*8+7:ii*8];
					end
			
			always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
				if (~clkrst_mem_rst_n) begin
					way_dirty <= {WAYS{1'b0}};
					way_valid <= {WAYS{1'b0}};
				end else begin
					if (set_selected_0a && resp_fill_start) begin /* mc2ltc start path */
						way_dirty[way_evicting] <= 0;
						way_valid[way_evicting] <= 0;
					end else if (set_selected_0a && resp_fill_end) begin /* mc2ltc completion path */
						way_valid[way_evicting] <= 1;
					end else if (set_selected_0a && set_valid_0a[set] && arb2ltc_is_write_0a) /* arb2ltc path */
						way_dirty[way_0a] <= 1;
				end
			assign set_dirty_0a[set] = way_dirty[way_evicting];
					
			assign set_rd_data_1a[set] = line_rd_data_1a;
			
			/* Way aging and eviction selection.
			 *
			 * We simply do FIFO eviction for now.  Later, we
			 * can do clock hand eviction if we want.  Ha, ha.
			 */
			always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
				if (~clkrst_mem_rst_n) begin
					way_evicting <= {WAYS_BITS{1'b0}};
				end else begin
					if (set_selected_0a && resp_fill_end) begin
						way_evicting <= way_evicting + 1;
					end
				end
		end
	endgenerate
	
	wire   miss_0a  = !set_valid_0a[arb2ltc_addr_0a[SET_UPPER:SET_LOWER]] && (arb2ltc_is_read_0a | arb2ltc_is_write_0a);
	wire   dirty_0a = set_dirty_0a[arb2ltc_addr_0a[SET_UPPER:SET_LOWER]];
	
	/* XXX: This logic to solve the refill-vs-write race is not quite
	 * what it should be.  It fixes the visible bug, but delaying
	 * resp_wr by a cycle really shouldn't be necessary.*/
	assign stall_0a = miss_0a || resp_override || resp_override_1a;
	
	always @(*) begin
		rd_valid_0a = arb2ltc_is_read_0a && ~miss_0a && ~resp_override;
		rd_data_1a = set_rd_data_1a[arb2ltc_addr_1a[SET_UPPER:SET_LOWER]];
	end
	
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			rd_valid_1a <= 1'b0;
		end else begin
			rd_valid_1a <= rd_valid_0a;
		end

	always @(*) begin
		arb2ltc_stall = stall_0a;
		arb2ltc_rdata = rd_data_1a;
		arb2ltc_rvalid = rd_valid_1a;
	end
	
	/*** Memory controller state machine ***/
	
	/* Request generation */
	parameter MCSM_IDLE    = 2'b00;
	parameter MCSM_WRITING = 2'b01;
	parameter MCSM_READING = 2'b10;
	
	reg [1:0] mcsm;
	reg [1:0] mcsm_next;
	
	/* HACK HACK, hardcoded, oh well.  The counter goes to 8: 4 atoms
	 * per line, then 2 MC cycles per atom.
	 */
	reg [2:0] mcsm_ofs;
	reg [2:0] mcsm_ofs_next;
	
	reg       read_filling;
	reg       read_filling_set;
	reg       read_filling_clr;
	
	/* HACK HACK, this uses arb2ltc_addr directly, which will not work
	 * when mcsm is handling queued prefetch and flush (or writethrough)
	 * opcodes */
	always @(*) begin
		mcsm_next = mcsm;

		ltc2mc_avl_burstbegin_0 = 1'b0;
		ltc2mc_avl_size_0 = {5{1'bx}};

		ltc2mc_avl_addr_0 = {25{1'bx}};

		ltc2mc_avl_read_req_0 = 1'b0;

		ltc2mc_avl_write_req_0 = 1'b0;
		ltc2mc_avl_wdata_0 = {128{1'bx}};
		ltc2mc_avl_be_0 = {16{1'bx}};
		
		read_filling_set = 0;
		
		resp_rd = 1'b0;

		case (mcsm)
		MCSM_IDLE: begin
			if (miss_0a && ~read_filling) begin /* wait to complete the fill, to avoid rerequesting */
				mcsm_ofs_next = 3'd0;
				mcsm_next = dirty_0a ? MCSM_WRITING : MCSM_READING;
				if (dirty_0a)
					resp_rd = 1'b1;
			end
		end
		MCSM_WRITING: begin
			resp_rd = 1'b1;
			
			ltc2mc_avl_write_req_0 = 1'b1;
			ltc2mc_avl_burstbegin_0 = mcsm_ofs == 3'd0;
			ltc2mc_avl_size_0 = 5'd8;
			ltc2mc_avl_addr_0 = {evicting_tag[28:TAG_LOWER], arb2ltc_addr[SET_UPPER:SET_LOWER], mcsm_ofs};
			ltc2mc_avl_wdata_0 = mcsm_ofs[0] ? rd_data_1a[255:128] : rd_data_1a[127:0];
			ltc2mc_avl_be_0 = {16{1'b1}};
			
			mcsm_next = (mcsm_ofs == 3'd7) ? MCSM_READING : MCSM_WRITING;
			mcsm_ofs_next = mcsm_ofs + 1;
		end
		MCSM_READING: begin
			ltc2mc_avl_read_req_0 = 1'b1;
			ltc2mc_avl_burstbegin_0 = mcsm_ofs == 3'd0;
			ltc2mc_avl_size_0 = 5'd8;
			ltc2mc_avl_addr_0 = {arb2ltc_addr[/*31*/28:7], mcsm_ofs}; 
			
			read_filling_set = (mcsm_ofs == 3'd0);
			mcsm_next = (mcsm_ofs == 3'd7) ? MCSM_IDLE : MCSM_READING;
			mcsm_ofs_next = mcsm_ofs + 1;
		end
		default: begin
			mcsm_next = 2'hx;
		end
		endcase
	end
	
	/* Response handling */
	/* HACK HACK: this should be a fifo, rather than hardwired */
	reg   [2:0] resp_ofs;
	reg   [2:0] resp_ofs_next;

	/* resp_wr reg above */
	/* resp_addr reg above */
	/* resp_data wire above */
	reg    [127:0] resp_data_lo;
	reg            resp_data_lo_latch;
	assign         resp_data = {ltc2mc_avl_rdata_0, resp_data_lo};
	
	
	always @(*) begin
		resp_wr = 1'b0;
		resp_addr = {27{1'bx}};
		resp_data_lo_latch = 0;
		read_filling_clr = 0;
		resp_fill_start = 0;
		resp_fill_end = 0;
		resp_ofs_next = resp_ofs;
		
		if (read_filling && ltc2mc_avl_rdata_valid_0) begin
			resp_data_lo_latch = ~resp_ofs[0];
			resp_addr = {arb2ltc_addr[31:7], resp_ofs[2:1]};
			resp_wr = resp_ofs[0];
			
			resp_fill_start = (resp_ofs == 3'd1);
			resp_fill_end   = (resp_ofs == 3'd7);
			read_filling_clr = (resp_ofs == 3'd7);
			resp_ofs_next = resp_ofs + 1;
			
			assert(!resp_rd) else $error("LTC write request from MC during read cycle");
		end
		
		if (resp_rd) begin
			resp_addr = {arb2ltc_addr[31:7], mcsm_ofs_next[2:1]};
		end
	end
	
	/* Clocked state machine logic */
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			mcsm <= MCSM_IDLE;
			mcsm_ofs <= 3'd0;
			resp_ofs <= 3'd0;
			resp_data_lo <= {128{1'b0}};
		end else begin
			if (ltc2mc_avl_ready_0) begin
				mcsm <= mcsm_next;
				mcsm_ofs <= mcsm_ofs_next;
			end

			resp_ofs <= resp_ofs_next;
			read_filling <= (read_filling | read_filling_set) & ~read_filling_clr;
			if (resp_data_lo_latch)
				resp_data_lo <= ltc2mc_avl_rdata_0;
			
			assert (!(ltc2mc_avl_rdata_valid_0 && !read_filling)) else $error("ltc2mc avl response without filling?");
		end

	/*** ***/
endmodule
