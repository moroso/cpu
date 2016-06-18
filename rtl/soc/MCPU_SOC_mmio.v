module MCPU_SOC_mmio(clkrst_core_clk, clkrst_core_rst_n, data_in, addr, wren, 
data_out, meminput, memoutput, uart_rx, uart_tx, uart_status);

	input clkrst_core_clk, clkrst_core_rst_n;

	input [31:0] data_in;
	input [28:0] addr;
	input [3:0] wren;
	output reg [31:0] data_out;
    

	input [31:0] meminput; // switches
	output reg [31:0] memoutput; // 7segs / LEDs

	input uart_rx;
	output uart_tx;
    output [4:0] uart_status;

	wire [31:0] writemask;
	assign writemask = {{8{wren[3]}},{8{wren[2]}},{8{wren[1]}},{8{wren[0]}}};

	reg is_ledsw, is_uart;

	wire [31:0] uart_read_val;

	always @(addr, meminput, uart_read_val) begin
		is_ledsw = 0;
		is_uart = 0;
		data_out = 32'bx;
		case(addr[28:10])
			19'd0: begin // LED/SW
				is_ledsw = 1;
				data_out = meminput;
			end
			19'd1: begin // UART
				is_uart = 1;
				data_out = uart_read_val;
			end
		endcase // addr[28:12]
	end

	uart uart_mod(
		.clk(clkrst_core_clk),
		.tx_pin(uart_tx),
		.rx_pin(uart_rx),
		.addr(addr[0]),
		.write_en(is_uart & wren[0]),
		.write_val(data_in),
		.read_val(uart_read_val),
        .uart_status(uart_status)
	);

	always @(posedge clkrst_core_clk, negedge clkrst_core_rst_n) begin
		if(~clkrst_core_rst_n) memoutput <= 0;
		else if(is_ledsw) memoutput <= (data_in & writemask) | (memoutput & ~writemask);
	end

endmodule