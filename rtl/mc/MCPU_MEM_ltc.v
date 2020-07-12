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
 *** Protocol details
 *
 * This has changed since the initial implementation, so read carefully!
 *
 * stall goes inactive on the cycle *before* the LTC is ready to receive a
 * new set of inputs.  That is to say, LTC expects all of its inputs to be
 * flopped by a block that looks like this:
 *
 *   always @(posedge clkrst_mem_clk)
 *     if (~arb2ltc_stall)
 *       {arb2ltc_opcode, ...} <= ...
 *
 * This is a change from previous behavior, in which it was permissible to
 * change LTC's inputs /on the same cycle it deasserted stall/.
 *
 * From an LTC implementation perspective, this means that LTC's
 * stall-deassert has to "predict" when it will be ready -- stall deasserts
 * when the /next/ cycle will be a non-miss cycle for a read, or when the
 * /next/ cycle will be a write.
 *
 *         _____       _____       _____       _____
 *  clk   /     \_____/     \_____/     \_____/     \_____
 *        |           |           |           | 
 *           ___________________________________   _______
 *  cmd   __/___________________________________\_/_______
 *        |           |           |           |
 *             ______________________                 ____
 *  stall ____/                      \_______________/
 *
 *** Implementation details
 *
 * LTC is split into two halves: the cache lookup path, and the fill path. 
 * These are described independently.
 *
 * The cache lookup path is described as an input decode stage, a parallel
 * set-decode stage, and finally, an operation on a RAM.  Cycle numbers are
 * referenced from input from the arb2ltc interface: that is to say,
 * arb2ltc_valid_0a is the same as arb2ltc_valid.  In the initial
 * implementation of LTC, data were available on the _1a cycle; in LTCv2,
 * data become available on the _2a cycle.  Tentatively, miss calculation
 * appears by the _1a cycle.  (In LTCv1, miss calculation appeared by _0a.)
 *
 * The refill path is a state machine that controls output on the ltc2mc
 * interface.  The refill path's _0a cycle provides an "override" set of
 * signals to the cache lookup path, intercepting the arb2ltc path to
 * instead read from the cache (for eviction) and write to the cache (For
 * filling).  These feedback signals have the names resp_*.
 *
 */

`timescale 1 ps / 1 ps

module MCPU_MEM_ltc(/*AUTOARG*/
   // Outputs
   ltc2mc_avl_addr_0, ltc2mc_avl_be_0, ltc2mc_avl_burstbegin_0,
   ltc2mc_avl_read_req_0, ltc2mc_avl_size_0, ltc2mc_avl_wdata_0,
   ltc2mc_avl_write_req_0, arb2ltc_rdata, arb2ltc_rvalid,
   arb2ltc_stall, video2ltc_rvalid, video2ltc_rdata, video2ltc_stall,
   // Inputs
   clkrst_mem_clk, clkrst_mem_rst_n, ltc2mc_avl_rdata_0,
   ltc2mc_avl_rdata_valid_0, ltc2mc_avl_ready_0, arb2ltc_valid,
   arb2ltc_opcode, arb2ltc_addr, arb2ltc_wdata, arb2ltc_wbe,
   video2ltc_re, video2ltc_addr
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
	 output [24:0]  ltc2mc_avl_addr_0;
	 output [15:0]  ltc2mc_avl_be_0;
	 output         ltc2mc_avl_burstbegin_0;
	 output         ltc2mc_avl_read_req_0;
	 output [4:0]   ltc2mc_avl_size_0;
	 output [127:0] ltc2mc_avl_wdata_0;
	 output         ltc2mc_avl_write_req_0;
	 input [127:0]  ltc2mc_avl_rdata_0;
	 input          ltc2mc_avl_rdata_valid_0;
	 input          ltc2mc_avl_ready_0;
	
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

	/* Video RAM interface */
	input 					video2ltc_re;
	input [28:7] 		video2ltc_addr;
	output 					video2ltc_rvalid;
	output [127:0] 	video2ltc_rdata;
	output reg 			video2ltc_stall;

	
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
	reg [127:0]	video2ltc_rdata;
	reg		video2ltc_rvalid;
	// End of automatics
	
	/*** Request input pipe ***/
	wire         arb2ltc_valid_0a = arb2ltc_valid;
	wire [2:0]   arb2ltc_opcode_0a = arb2ltc_opcode;
	wire [31:5]  arb2ltc_addr_0a = arb2ltc_addr;
	wire [255:0] arb2ltc_wdata_0a = arb2ltc_wdata;
	wire [31:0]  arb2ltc_wbe_0a = arb2ltc_wbe;
	
	wire        arb2ltc_is_read_0a  = arb2ltc_valid_0a && ((arb2ltc_opcode == LTC_OPC_READ) || (arb2ltc_opcode == LTC_OPC_READTHROUGH));
	wire        arb2ltc_is_write_0a = arb2ltc_valid_0a && ((arb2ltc_opcode == LTC_OPC_WRITE) || (arb2ltc_opcode == LTC_OPC_WRITETHROUGH));
	wire        arb2ltc_is_bogus_0a = arb2ltc_valid_0a && ((arb2ltc_opcode == LTC_OPC_PREFETCH) || (arb2ltc_opcode == LTC_OPC_CLEAN));
	
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
	reg          resp_wr_0a;
	reg          resp_wr_1a;
	reg          resp_rd_0a;
	reg          resp_rd_1a;
	wire         resp_override_0a = resp_wr_0a | resp_rd_0a;
	reg          resp_override_1a;
	reg          resp_fill_start_0a, resp_fill_end_0a;
	wire  [31:5] resp_addr_0a;
	wire [255:0] resp_data_0a;

	/* XXX: evades, not solves race condition in write-vs-refill path... */
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			resp_wr_1a <= 0;
			resp_rd_1a <= 0;
			resp_override_1a <= 0;
		end else begin
			resp_wr_1a <= resp_wr_0a;
			resp_rd_1a <= resp_rd_0a;
			resp_override_1a <= resp_override_0a;
		end


	/*** Cache ways ***/
	
	/* Note that the refill path always takes precedence.  So if there's
	 * going to be an arb2ltc operation, you better nerf it if we're
	 * doing an mc operation on the same cycle!  The address that we're
	 * actually accessing on this cycle is given in addr; try to avoid
	 * using resp_addr and arb2ltc_addr if you don't need them.
	 */
	wire [31:5] addr_0a = resp_override_0a ? resp_addr_0a : arb2ltc_addr_0a;
	wire [28:7] video2ltc_addr_0a = video2ltc_addr;

	wire 		    video2ltc_re_0a = video2ltc_re;
	wire [255:0] video_cache_rdata;
	
	/* We would use arb2ltc_addr to decide on the set, rather than addr,
	 * because in LTCv1 the set that we're accessing is the same if
	 * we're evicting or if we're not (given that the input is stalled
	 * while we evict).  But, in LTCv2, arb2ltc_addr_0a may have "moved
	 * on" as opposed to arb2ltc_addr_1a, which is what controls the
	 * reload state machine.  So, even though it jacks up the critical
	 * path in LTCv1, we're still using addr (instead of arb2ltc_addr)
	 * to decide on the set.
	 *
	 * XXX: LTCv1 still uses arb2ltc_addr to avoid circular logic path
	 */
	wire [SET_BITS-1 : 0] set_0a = arb2ltc_addr_0a[SET_UPPER:SET_LOWER];
	wire [SET_BITS-1 : 0] video_set_0a = video2ltc_addr_0a[SET_UPPER:SET_LOWER];
	
	wire [SETS-1:0] set_valid_0a;
	wire [SETS-1:0] video_set_valid_0a;
	wire [SETS-1:0] set_dirty_0a;
	reg  [255:0]    rd_data_1a;
	reg             rd_valid_0a;
	reg             rd_valid_1a;

	/* Mux out the tag that we're evicting, so that the refill path can
	 * know about it.
	 */
	wire [TAG_UPPER:TAG_LOWER] set_evicting_tag_0a [SETS-1:0];
	wire [TAG_UPPER:TAG_LOWER] evicting_tag_0a = set_evicting_tag_0a[set_0a];
	
	wire [BITS_IN_ATOM-1:0] line_rd_data_1a;
	/* XXX: Probably should have rd and wr split out. */
	wire [WAYS_BITS - 1 : 0] set_way_0a [SETS-1:0];
	wire [WAYS_BITS - 1 : 0] way_0a = set_way_0a[set_0a];
	wire [WAYS_BITS - 1 : 0] video_set_way_0a [SETS-1:0];
	wire [WAYS_BITS - 1 : 0] video_way_0a = video_set_way_0a[video_set_0a];

	reg 			 burst_read;
	reg 			 burst_read_set;
	reg 			 burst_read_clr;

	reg [2:0]  video_ofs;
	reg [2:0]  video_ofs_next;

	genvar set;
	genvar way;
	genvar ii;
	integer i;
	generate
		for (set = 0; set < SETS; set = set + 1) begin: set_gen
			wire [WAYS-1:0] ways_match_0a;
			wire [WAYS-1:0] video_ways_match_0a;
			reg [WAYS_BITS-1:0] way_active_0a;
			reg [WAYS_BITS-1:0] video_way_active_0a;
			reg [WAYS-1:0] way_valid_0a;
			reg [WAYS-1:0] way_dirty_0a;
			reg [WAYS_BITS-1:0] way_evicting_0a;
			
			wire set_selected_0a = set_0a == set[SET_BITS-1:0];
			
			reg [TAG_UPPER:TAG_LOWER] way_tag [WAYS-1:0];
			
			/* Way CAM */
			/* The way CAM is actually unused during eviction -- it's overridden by way_evicting. */
			for (way = 0; way < WAYS; way = way + 1) begin: way_gen
				always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
					if (~clkrst_mem_rst_n) begin
						way_tag[way] <= {TAG_BITS{1'bx}};
					end else begin
						if (set_selected_0a && resp_wr_0a && (way_evicting_0a == way[WAYS_BITS-1:0])) /* always from mc2ltc path, never from arb2ltc path */
							way_tag[way] <= resp_addr_0a[TAG_UPPER:TAG_LOWER];
					end
				
				assign ways_match_0a[way] = way_tag[way][TAG_UPPER:TAG_LOWER] == arb2ltc_addr_0a[TAG_UPPER:TAG_LOWER]; /* always from arb2ltc path, never from mc2ltc path */
				assign video_ways_match_0a[way] = way_tag[way][TAG_UPPER:TAG_LOWER] == {3'b0, video2ltc_addr_0a[28:TAG_LOWER]};
			end
			assign set_evicting_tag_0a[set] = way_tag[way_evicting_0a];
			
			/* Way and RAM select logic */
			assign set_valid_0a[set] = |(ways_match_0a & way_valid_0a);
			assign video_set_valid_0a[set] = |(video_ways_match_0a & way_valid_0a);
			always @(/*AUTOSENSE*/resp_override_0a
				 or way_evicting_0a or way_valid_0a
				 or ways_match_0a) begin
				way_active_0a = {WAYS_BITS{1'bx}};
				for (i = 0; i < WAYS; i = i + 1)
					if (ways_match_0a[i] && way_valid_0a[i])
						way_active_0a = i[WAYS_BITS-1:0];
				if (resp_override_0a)
					way_active_0a = way_evicting_0a;
			end
			assign set_way_0a[set] = way_active_0a;
			always @(/*AUTOSENSE*/video_ways_match_0a
				 or way_valid_0a) begin
				video_way_active_0a = {WAYS_BITS{1'bx}};
				for (i = 0; i < WAYS; i = i + 1)
					if (video_ways_match_0a[i] && way_valid_0a[i])
						video_way_active_0a = i[WAYS_BITS-1:0];
			end
			assign video_set_way_0a[set] = video_way_active_0a;

			always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
				if (~clkrst_mem_rst_n) begin
					way_dirty_0a <= {WAYS{1'b0}};
					way_valid_0a <= {WAYS{1'b0}};
				end else begin
					if (set_selected_0a && resp_fill_start_0a) begin /* mc2ltc start path */
						way_dirty_0a[way_evicting_0a] <= 0;
						way_valid_0a[way_evicting_0a] <= 0;
					end else if (set_selected_0a && resp_fill_end_0a) begin /* mc2ltc completion path */
						way_valid_0a[way_evicting_0a] <= 1;
					end else if (set_selected_0a && set_valid_0a[set] && arb2ltc_is_write_0a) /* arb2ltc path */
						way_dirty_0a[way_active_0a] <= 1;
				end
			assign set_dirty_0a[set] = way_dirty_0a[way_evicting_0a];
					
			/* Way aging and eviction selection.
			 *
			 * We simply do FIFO eviction for now.  Later, we
			 * can do clock hand eviction if we want.  Ha, ha.
			 */
			always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
				if (~clkrst_mem_rst_n) begin
					way_evicting_0a <= {WAYS_BITS{1'b0}};
				end else begin
					if (set_selected_0a && resp_fill_end_0a) begin
						way_evicting_0a <= way_evicting_0a + 1;
					end
				end
		end
	endgenerate

	wire [WAYS_BITS + SET_BITS + ATOM_BITS - 1:0] video_bram_addr =
																								{video_set_0a, video_way_0a, video_ofs_next[2:1]};
	wire video_addr_hit = (burst_read | burst_read_set | video2ltc_re) && video_set_valid_0a[video_set_0a];

	/* Set read logic */
	MCPU_MEM_LTC_bram #(
		.DEPTH(WAYS * SETS * ATOMS_PER_LINE),
		.DEPTH_BITS(WAYS_BITS + SET_BITS + ATOM_BITS),
		.WIDTH_BYTES(BYTES_IN_ATOM))
		u_bram(
		.clkrst_mem_clk(clkrst_mem_clk),
		
		.addr0({set_0a, way_0a, addr_0a[ATOM_UPPER:ATOM_LOWER]}),
		.re0((set_valid_0a[set_0a] && arb2ltc_is_read_0a) || /* arb2ltc path */
		    (resp_rd_0a)), /* mc2ltc flush path */
		.rdata0(line_rd_data_1a),

		.addr1(video_bram_addr),
		.re1(video_addr_hit),
		.rdata1(video_cache_rdata[255:0]),
		
		.wbe0(({BYTES_IN_ATOM{(set_valid_0a[set_0a] && arb2ltc_is_write_0a)}} & arb2ltc_wbe_0a) | /* arb2ltc path */
		     {BYTES_IN_ATOM{resp_wr_0a}}), /* mc2ltc refill path */
		.wdata0(resp_wr_0a ? resp_data_0a : arb2ltc_wdata_0a)
	);
		
	wire   miss_0a  = !set_valid_0a[arb2ltc_addr_0a[SET_UPPER:SET_LOWER]] && (arb2ltc_is_read_0a | arb2ltc_is_write_0a);
	wire   dirty_0a = set_dirty_0a[arb2ltc_addr_0a[SET_UPPER:SET_LOWER]];
	
	/* Stalls always take place when we're about to override on a
	 * response, since that steals the /next/ cycle.  Additionally, if
	 * we're missing, we also stall.
	 */
	assign stall_0a = resp_override_0a ||
	                  (arb2ltc_is_read_0a && miss_0a) || 
	                  (arb2ltc_is_write_0a && miss_0a);
	
	always @(*) begin
		rd_valid_0a = arb2ltc_is_read_0a && ~miss_0a && ~resp_override_0a;
		rd_data_1a = line_rd_data_1a;
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

	/* Video burst logic */
	always @(*) begin
		video2ltc_rdata = video_addr_hit ? video_cache_rdata[{video_ofs[0], 7'h0} +: 128] : ltc2mc_avl_rdata_0;
		video2ltc_rvalid = (ltc2mc_avl_rdata_valid_0 | video_addr_hit) & (burst_read | burst_read_set);
	end
	
	/*** Memory controller state machine ***/
	
	/* Request generation */
	parameter MCSM_IDLE    = 2'b00;
	parameter MCSM_WRITING = 2'b01;
	parameter MCSM_READING = 2'b10;
	parameter MCSM_BURST_READ = 2'b11;
	
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
		mcsm_ofs_next = mcsm_ofs;

		ltc2mc_avl_burstbegin_0 = 1'b0;
		ltc2mc_avl_size_0 = {5{1'bx}};

		ltc2mc_avl_addr_0 = {25{1'bx}};

		ltc2mc_avl_read_req_0 = 1'b0;

		ltc2mc_avl_write_req_0 = 1'b0;
		ltc2mc_avl_wdata_0 = {128{1'bx}};
		ltc2mc_avl_be_0 = {16{1'bx}};
		
		read_filling_set = 0;
		
		resp_rd_0a = 1'b0;

		burst_read_set = 1'b0;
		video2ltc_stall = 1'b1;

		case (mcsm)
		MCSM_IDLE: begin
			if (~read_filling && ~burst_read) begin
				video2ltc_stall = 1'b0;
				if (video2ltc_re) begin
					mcsm_ofs_next = 3'd0;
					mcsm_next = MCSM_BURST_READ;
				end else if (miss_0a && ~read_filling) begin /* wait to complete the fill, to avoid rerequesting */
					mcsm_ofs_next = 3'd0;
					mcsm_next = dirty_0a ? MCSM_WRITING : MCSM_READING;
					if (dirty_0a)
						resp_rd_0a = 1'b1;
				end
			end
		end
		MCSM_WRITING: begin
			resp_rd_0a = 1'b1;
			
			ltc2mc_avl_write_req_0 = 1'b1;
			ltc2mc_avl_burstbegin_0 = mcsm_ofs == 3'd0;
			ltc2mc_avl_size_0 = 5'd8;
			ltc2mc_avl_addr_0 = {evicting_tag_0a[28:TAG_LOWER], arb2ltc_addr[SET_UPPER:SET_LOWER], mcsm_ofs};
			ltc2mc_avl_wdata_0 = mcsm_ofs[0] ? rd_data_1a[255:128] : rd_data_1a[127:0];
			ltc2mc_avl_be_0 = {16{1'b1}};
			
			mcsm_next = (mcsm_ofs == 3'd7) ? MCSM_READING : MCSM_WRITING;
			mcsm_ofs_next = mcsm_ofs + 1;
		end
		MCSM_READING: begin
			ltc2mc_avl_read_req_0 = 1'b1;
			ltc2mc_avl_burstbegin_0 = 1'b1;
			ltc2mc_avl_size_0 = 5'd8;
			ltc2mc_avl_addr_0 = {arb2ltc_addr[/*31*/28:7], 3'b0};
			
			read_filling_set = 1'b1;
			mcsm_next = MCSM_IDLE;
		end
			MCSM_BURST_READ: begin
     		burst_read_set = 1'b1;

				if (~video_addr_hit) begin
					ltc2mc_avl_read_req_0 = 1'b1;
					ltc2mc_avl_burstbegin_0 = 1'b1;
					ltc2mc_avl_size_0 = 5'd8; // TODO: we might want to increase the size here.
					ltc2mc_avl_addr_0 = {video2ltc_addr[28:7], 3'b0};
				end
				mcsm_next = MCSM_IDLE;
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
	assign         resp_data_0a = {ltc2mc_avl_rdata_0, resp_data_lo};
	
	assign resp_addr_0a = resp_rd_0a ? {arb2ltc_addr[31:7], mcsm_ofs_next[2:1]}
	                                 : {arb2ltc_addr[31:7], resp_ofs[2:1]};

	always @(*) begin
		resp_wr_0a = 1'b0;
		resp_data_lo_latch = 0;
		read_filling_clr = 0;
		resp_fill_start_0a = 0;
		resp_fill_end_0a = 0;
		resp_ofs_next = resp_ofs;
		
		if ((read_filling | read_filling_set) && ltc2mc_avl_rdata_valid_0) begin
			resp_data_lo_latch = ~resp_ofs[0];
			resp_wr_0a = resp_ofs[0];
			
			resp_fill_start_0a = (resp_ofs == 3'd1);
			resp_fill_end_0a   = (resp_ofs == 3'd7);
			read_filling_clr = (resp_ofs == 3'd7);
			resp_ofs_next = resp_ofs + 1;

`ifndef BROKEN_ASSERTS
			assert(!resp_rd_0a) else $error("LTC write request from MC during read cycle");
`endif
		end
	end // always @ (*)

	always @(*) begin
		burst_read_clr = 0;
		video_ofs_next = video_ofs;

		if ((burst_read | burst_read_set) & (ltc2mc_avl_rdata_valid_0 | video_addr_hit)) begin
			video_ofs_next = video_ofs + 1;
			burst_read_clr = (video_ofs == 3'd7);
		end
	end

	/* Clocked state machine logic */
	always @(posedge clkrst_mem_clk or negedge clkrst_mem_rst_n)
		if (~clkrst_mem_rst_n) begin
			mcsm <= MCSM_IDLE;
			mcsm_ofs <= 3'd0;
			resp_ofs <= 3'd0;
			resp_data_lo <= {128{1'b0}};
			read_filling <= 0;
			video_ofs <= 0;
			burst_read <= 0;
		end else begin
			if (ltc2mc_avl_ready_0) begin
				mcsm <= mcsm_next;
				mcsm_ofs <= mcsm_ofs_next;
			end

			resp_ofs <= resp_ofs_next;
		   video_ofs <= video_ofs_next;
			read_filling <= (read_filling | read_filling_set) & ~read_filling_clr;
		   burst_read <= (burst_read | burst_read_set) & ~burst_read_clr;
			if (resp_data_lo_latch)
				resp_data_lo <= ltc2mc_avl_rdata_0;

`ifndef BROKEN_ASSERTS
			assert (!(ltc2mc_avl_rdata_valid_0 && !(read_filling | read_filling_set | burst_read))) else $error("ltc2mc avl response without filling?");
`endif
		end
	/*** ***/
endmodule
