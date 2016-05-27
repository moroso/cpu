module MCPU_CORE_stage_mem(/*AUTOARG*/
   // Outputs
   mem2wb_out_data, mem2wb_out_rd_num, mem2wb_out_rd_we, mem2dc_paddr,
   mem2dc_write, mem2dc_valid,
   // Inouts
   mem2dc_data,
   // Inputs
   mem_valid, pc2mem_in_paddr, pc2mem_in_data, pc2mem_in_type,
   pc2mem_in_rd_num, pc2mem_in_rd_we, mem2dc_done
   );

	//input clkrst_core_clk, clkrst_core_rst_n;

	//input pc2mem_progress, mem2wb_progress;
	//output reg pc2mem_readyin, mem2wb_readyout;

	input mem_valid;

	input [31:0] pc2mem_in_paddr;
	input [31:0] pc2mem_in_data;
	input [2:0] pc2mem_in_type;
	input [4:0] pc2mem_in_rd_num;
	input pc2mem_in_rd_we;

	output reg [31:0] mem2wb_out_data;
	output reg [4:0] mem2wb_out_rd_num;
	output reg mem2wb_out_rd_we;

	output reg [29:0] mem2dc_paddr;
	output reg [3:0] mem2dc_write;
	output reg mem2dc_valid;
	input mem2dc_done;
	inout [31:0] mem2dc_data;


	//reg mem_valid;

	//assign pc2mem_readyin = ~mem2dc_valid | mem2wb_progress;
	//assign mem2wb_readyout = mem2dc_valid & mem2dc_done;

	//Compute mask of bytes within the word to write. If this is a read, pass 0.
	always @(/*AUTOSENSE*/pc2mem_in_paddr or pc2mem_in_type) begin
		if(~pc2mem_in_type[2]) mem2dc_write = 0;
		else if(pc2mem_in_type[1]) mem2dc_write = 4'b1111;
		else if(pc2mem_in_type[0]) mem2dc_write = 4'b0011 << (pc2mem_in_paddr[1:0] & 2'b10);
		else mem2dc_write = 4'b0001 << pc2mem_in_paddr[1:0];
	end

	assign mem2dc_paddr = pc2mem_in_paddr[31:2];

	/*
	always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
		mem_valid <= (mem_valid & (~mem2dc_done | ~mem2wb_progress)) | pc2mem_progress;
	end
	*/

	assign mem2dc_valid = mem_valid;

	//Send the input data on the bus if we're doing a write, or read from it if it's a read
	//I think this is how inout ports work? >.>
	assign mem2dc_data = (mem_valid & pc2mem_in_type[2]) ? pc2mem_in_data : 32'bZ;
	
	//Take the part of the word that we wanted to read and put it in the low bits of the output
	always @(/*AUTOSENSE*/mem2dc_data or pc2mem_in_paddr
		 or pc2mem_in_type) begin
		if(pc2mem_in_type[1]) mem2wb_out_data = mem2dc_data;
		else if(pc2mem_in_type[0]) mem2wb_out_data = mem2dc_data >> (pc2mem_in_paddr[1] * 5'd16) & 32'hFFFF;
		else mem2wb_out_data = mem2dc_data >> (pc2mem_in_paddr[1:0] * 5'd8) & 32'hFF;
	end

	assign mem2wb_out_rd_num = pc2mem_in_rd_num;
	assign mem2wb_out_rd_we = pc2mem_in_rd_we;

endmodule