module uart_rx(
               input        clk,
               input        rx_en,
               input        rx_pin,
               output reg   rxc = 0,
               output reg   rx_err = 0,
               output [7:0] rx_byte
               );
   parameter BAUD_CLOCK = 0;
   localparam HALF_BAUD_CLOCK = BAUD_CLOCK / 2;

   localparam END_STATE = 4'hc;

   reg [3:0]         state = 0;
   reg [3:0]         next_state;

   reg [15:0]        baudclock = 0;
   reg [15:0]        oversampclock = 0;

   reg [7:0]         rxbuf = 0;
   reg [7:0]         rxreg = 0;

   assign rx_byte = rxreg;

   always @(*) begin
      if (state == 4'h0 & rx_en)
        next_state = 4'h1;
      else if (~rx_en)
        next_state = 4'h0;
      else if (state == 4'h2 & baudclock == HALF_BAUD_CLOCK[15:0] - 1)
        next_state = 4'h3;
      else if (baudclock == BAUD_CLOCK[15:0] - 1)
        next_state = state + 1;
      else
        next_state = state;
   end

   always @(posedge clk) begin
      if (state != next_state) begin
        if ((next_state != END_STATE) & (state >= 4'h3))
          rxbuf <= {rx_pin, rxbuf[7:1]};
         baudclock <= 0;
      end else if (state == 0 | (state == 4'b1 & rx_pin))
        baudclock <= 0;
      else
        baudclock <= baudclock + 1;

      if (state == 4'h1)
        if (rx_pin)
          state <= 4'h1;
        else
          // Got the start bit
          state <= 4'h2;
      else if (next_state == END_STATE) begin
         if (rx_pin) begin
            rxreg <= rxbuf;
            rxc <= 1;
         end else
           rx_err <= 1;
         state <= 4'h1;
      end else
        state <= next_state;

      if (rxc)
        rxc <= 0;
      if (rx_err)
        rx_err <= 0;
   end
endmodule // uart_rx

module uart_tx(
               input       clk,
               input       start_tx,
               input [7:0] txbyte,
               output reg  tx_pin,
               output      tx_complete
               );
   parameter BAUD_CLOCK = 0;

   reg [15:0]              baudclock = 0;
   reg [3:0]               state = 0;
   reg                     next = 0;
   reg                     ending_tx = 0;

   reg                     next_running = 0;
   reg [15:0]              next_baudclock = 0;
   reg [15:0]              advanced_baudclock = 0;
   reg [3:0]               next_state;

   always @(*)
     if (baudclock == BAUD_CLOCK[15:0] - 1)
       advanced_baudclock = 0;
     else
       advanced_baudclock = baudclock + 1;

   always @(*)
     if (state == 0)
       next_baudclock = 0;
     else
       next_baudclock = advanced_baudclock;

   always @(posedge clk) begin
      baudclock <= next_baudclock;
      next <= (next & ~tx_complete) | start_tx;
      state <= next_state;

      ending_tx <= 0;
   end

   always @(*)
     if (state != 0 & baudclock != BAUD_CLOCK[15:0] - 1)
       next_state = state;
     else
       if (state == 0)
         if (next)
           next_state = 4'h1;
         else
           next_state = 4'h0;
       else
         if (state == 4'ha)
           if (next)
             next_state = 1;
           else
             next_state = 0;
         else
           next_state = state + 1;

   assign tx_complete = (state == 4'ha & baudclock == 0);

   always @(*) begin
      case (state)
        4'h0: tx_pin = 1;
        4'h1: tx_pin = 0; // Start bit
        4'h2: tx_pin = txbyte[0];
        4'h3: tx_pin = txbyte[1];
        4'h4: tx_pin = txbyte[2];
        4'h5: tx_pin = txbyte[3];
        4'h6: tx_pin = txbyte[4];
        4'h7: tx_pin = txbyte[5];
        4'h8: tx_pin = txbyte[6];
        4'h9: tx_pin = txbyte[7];
        4'ha: tx_pin = 1; // Stop bit
	default: tx_pin = 1'bx;
      endcase // case (state)
   end
endmodule // uart_tx

module uart(
            input             clk,
            output            tx_pin,
            input             rx_pin,
            input             write_en,
            input [31:0]      write_val,
            input             addr,
            output reg [31:0] read_val
            );

   parameter CLOCK_HZ = 50000000;
   localparam BAUD_CLOCK = CLOCK_HZ / 115200;

   reg             start_tx = 0;
   reg             inited = 0;
   reg             txc = 0;
   reg             rxc = 0;
   reg             rx_err = 0;
   reg             in_progress = 0;

   reg [7:0]       tx_queue = 0;
   reg             tx_queue_full = 0;
   reg [7:0]       tx_buffer = 0;

   reg [7:0]       rx_buffer = 0;

   wire [7:0]      rx_byte_in;
   wire            rxc_in;
   wire            rx_err_in;
   wire            tx_complete;
   reg             rx_en = 0;

   always @(*) begin
      if (addr)
        read_val = {27'hx, rx_err, rxc, rx_en, ~tx_queue_full, txc};
      else
        read_val = {24'hx, rx_buffer};
   end

   always @(posedge clk) begin
      if (write_en)
        if (addr) begin // Status register
           txc <= write_val[0];
           rx_en <= write_val[2];
           rxc <= write_val[3];
           rx_err <= write_val[4];
        end else begin // Data register
           $display("UART write %x (%c)", write_val, write_val[7:0]);
           tx_queue <= write_val[7:0];
           tx_queue_full <= 1;
        end
      if (tx_complete | ~in_progress) begin
         if (tx_complete)
           txc <= 1;
         if (tx_queue_full) begin
            tx_queue_full <= 0;
            tx_buffer <= tx_queue;
            start_tx <= 1;
            in_progress <= 1;
         end else
           in_progress <= 0;
      end
      if (start_tx)
        start_tx <= 0;
      if (rxc_in) begin
         rxc <= 1'b1;
         rx_buffer <= rx_byte_in;
      end
      if (rx_err_in)
        rx_err <= 1'b1;
   end

   uart_tx #(
             .BAUD_CLOCK(BAUD_CLOCK)
             ) uart_tx_inst(// Inputs
                            .txbyte             (tx_buffer),
                            /*AUTOINST*/
			    // Outputs
			    .tx_pin		(tx_pin),
			    .tx_complete	(tx_complete),
			    // Inputs
			    .clk		(clk),
			    .start_tx		(start_tx));

   uart_rx #(
             .BAUD_CLOCK(BAUD_CLOCK)
             ) uart_rx_inst(// Outputs
                            .rxc                (rxc_in),
                            .rx_err             (rx_err_in),
                            .rx_byte            (rx_byte_in[7:0]),
                            /*AUTOINST*/
			    // Inputs
			    .clk		(clk),
			    .rx_en		(rx_en),
			    .rx_pin		(rx_pin));

endmodule // uart
