/* Simple serial first-stage bootloader for Moroso.
 * Does no verification or anything of the downloaded program; once
 * it gets as many bytes as it expects, it jumps to the program to
 * start executing it. The program is limited to 64k packets (about 1/2
 * megabyte).
 *
 * The protocol ("B" is bootloader, "H" is host) is:
 *  - B -> H: "MBOOT"
 *  - H -> B: number of packets to send (two bytes, MSB first)
 *  - H -> B: packet data
 *  - B -> H: "DONE"
 */

{ b self_copy; }

/* r29 will always point to the serial port's memory area.
 * r28 is the next address to write to.
 * r27 is the number of packets remaining to read.
 */
{
  r29 <- long; long 0x80001000; // Serial port base address
  r11 <- 0b00100; // Value to write to serial status register
  r28 <- 0x0; // Destination address (at which to store the program).
}
{ r26 <- 0x80000000; r0 <- 1; r25 <- r28; }
{ *l(r26) <- r0; }
{
  bl write_uart;
  *l(r29 + 4) <- r11; // enable rx
  r0 <- 'M'; }
{ bl write_uart; r0 <- 'B'; }
{ bl write_uart; r0 <- 'O'; }
{ bl write_uart; r0 <- 'O'; }
{ bl write_uart; r0 <- 'T'; }
// Read the length, MSB first.
{ bl read_uart; }
{ bl read_uart; r24 <- r0; }
{ r27 <- r0 + (r24 << 8); }
outer_loop:
  { bl read_packet; r27 <- r27 - 1; }
  { p0 <- r27 == 0; }
  { !p0? b outer_loop; }
{ flush.inst r0; } // TODO: the r0 is unused right now; this'll need to be updated later.
{ bl write_uart; r0 <- 'D'; }
{ bl write_uart; r0 <- 'O'; }
{ bl write_uart; r0 <- 'N'; }
{ bl write_uart; r0 <- 'E'; }
{ b r25; }

// Note: the functions here don't save any registers. Beware of that if
// you update anything here, or try to use these functions elsewhere.
read_packet:
  { r3 <- 15; r10 <- r31; } // Note: one less than the number of bytes to read.
  read_packet_loop:
    { bl read_uart; }
    { *l(r26) <- r0; }
    { *b(r28) <- r0; r28 <- r28 + 1; r3 <- r3 - 1; p1 <- r3 == 0; }
    { !p1? b read_packet_loop; }
    { b r10 + 1; }

read_uart:
  { r11 <- 0b00100; }
  { *l(r29 + 4) <- r11; } // clear the rxc bit
  uart_read_loop:
    { r0 <- *b(r29 + 4); }
    { p0 <- r0 & 0b1000; } // rxc
    { !p0? b uart_read_loop; }
  { p0 <- r0 & 0b10000; }
  { p0? b err; }
  { b r31 + 1; r0 <- *b(r29); }

write_uart:
  { r11 <- 0b00100; }
  { *l(r29 + 4) <- r11; } // clear txc
  { *l(r29) <- r0; }
  uart_write_loop:
    { r0 <- *b(r29 + 4); }
    { p0 <- r0 & 0b1; } // txc
    { !p0? b uart_write_loop; }
  { b r31 + 1; }

err:
  { r0 <- 0x80000000; r1 <- long; long 0x555; }
  { b err; *l(r0) <- r1; }

// Get the bootloader out of the way. Put it right at the end of
// memory, so that we can copy the target program to 0.
self_copy:
  { r0 <- 0x0; r1 <- long; long 0x1ffff000; r2 <- 0x200; }
  { r7 <- r1; }
  self_copy_loop:
    { r3 <- *l(r0); r2 <- r2 - 1; r0 <- r0 + 4; p0 <- r2 == 1; }
    { !p0? b self_copy_loop; *l(r1) <- r3; r1 <- r1 + 4; }
  { flush.inst r0; } // TODO: the r0 is unused right now; this'll need to be updated later.
  { b r7 + 1; }
