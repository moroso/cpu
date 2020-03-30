module MCPU_CORE_stage_mem(/*AUTOARG*/
   // Outputs
   mem_ready_in, mem_ready_out, mem_valid_out, mem2wb_out_data,
   mem2wb_out_rd_num, mem2wb_out_rd_we, mem2dc_paddr, mem2dc_write,
   mem2dc_valid, mem2dc_data_out,
   // Inputs
   clkrst_core_clk, clkrst_core_rst_n, mem_valid_in, mem_out_ok,
   pc2mem_in_paddr, pc2mem_in_data, pc2mem_in_type, pc2mem_in_rd_num,
   pc2mem_in_rd_we, mem2dc_done, mem2dc_data_in
   );

	input clkrst_core_clk, clkrst_core_rst_n;

  // Stage interface
  input       mem_valid_in;
  input       mem_out_ok;
  output      mem_ready_in;
  output      mem_ready_out;
  output      mem_valid_out;

	input [31:0] pc2mem_in_paddr;
	input [31:0] pc2mem_in_data;
	input [2:0] pc2mem_in_type;
	input [4:0] pc2mem_in_rd_num;
	input pc2mem_in_rd_we;

  // Write-back interface
	output reg [31:0] mem2wb_out_data;
	output wire [4:0] mem2wb_out_rd_num;
	output wire mem2wb_out_rd_we;

  // Data cache interface
	output wire [29:0] mem2dc_paddr;
	output reg [3:0] mem2dc_write;
	output wire mem2dc_valid;
	input mem2dc_done;
	input [31:0] mem2dc_data_in;
	output reg [31:0] mem2dc_data_out;


	reg mem_inprogress;
  reg [2:0] pc2mem_in_type_1a;
  reg [4:0] pc2mem_in_rd_num_1a;
  reg [31:0] pc2mem_in_paddr_1a;
  reg 	     pc2mem_in_rd_we_1a;

	//Compute mask of bytes within the word to write. If this is a read, pass 0.
	always @(/*AUTOSENSE*/pc2mem_in_data or pc2mem_in_paddr
		 or pc2mem_in_type) begin
		if(~pc2mem_in_type[2]) begin
			mem2dc_write = 0;
			mem2dc_data_out = 32'bx;
		end
		else if(pc2mem_in_type[1]) begin 
			mem2dc_write = 4'b1111;
			mem2dc_data_out = pc2mem_in_data;
		end
		else if(pc2mem_in_type[0]) begin
			mem2dc_write = 4'b0011 << (pc2mem_in_paddr[1:0] & 2'b10);
			mem2dc_data_out = pc2mem_in_data << (pc2mem_in_paddr[1] * 16);
		end
		else begin
			mem2dc_write = 4'b0001 << pc2mem_in_paddr[1:0];
			mem2dc_data_out = pc2mem_in_data << (pc2mem_in_paddr[1:0] * 8);
		end
	end

	assign mem2dc_paddr = pc2mem_in_paddr[31:2];


	assign mem2dc_valid = mem_valid_in & mem_out_ok;
	always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
		if(~clkrst_core_rst_n) begin
		   mem_inprogress <= 0;
		   pc2mem_in_type_1a <= 'hx;
		   pc2mem_in_rd_num_1a <= 'hx;
		   pc2mem_in_paddr_1a <= 'hx;
		   pc2mem_in_rd_we_1a <= 'hx;
		end else if (mem_ready_in) begin
		   mem_inprogress <= mem_valid_in;
		   pc2mem_in_type_1a <= pc2mem_in_type;
		   pc2mem_in_rd_num_1a <= pc2mem_in_rd_num;
		   pc2mem_in_paddr_1a <= pc2mem_in_paddr;
		   pc2mem_in_rd_we_1a <= pc2mem_in_rd_we;
		end
	end

	
	//Take the part of the word that we wanted to read and put it in the low bits of the output
	always @(/*AUTOSENSE*/mem2dc_data_in or pc2mem_in_paddr_1a
		 or pc2mem_in_type_1a) begin
		if(pc2mem_in_type_1a[1]) mem2wb_out_data = mem2dc_data_in;
		else if(pc2mem_in_type_1a[0]) mem2wb_out_data = mem2dc_data_in >> (pc2mem_in_paddr_1a[1] * 5'd16) & 32'hFFFF;
		else mem2wb_out_data = mem2dc_data_in >> (pc2mem_in_paddr_1a[1:0] * 5'd8) & 32'hFF;
	end

	assign mem2wb_out_rd_num = pc2mem_in_rd_num_1a;
	assign mem2wb_out_rd_we = pc2mem_in_rd_we_1a;

  assign mem_valid_out = mem2dc_done & mem_inprogress;
  assign mem_ready_out = mem2dc_done;
  assign mem_ready_in = ~mem_valid_in | (mem_out_ok & mem_ready_out);

endmodule
