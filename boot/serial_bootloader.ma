/* Simple serial first-stage bootloader for Moroso.
 * Does no verification or anything of the downloaded program; once
 * it gets as many bytes as it expects, it jumps to the program to
 * start executing it. The program is always loaded into 0x1000, and
 * (right now) is limited to 255 packets (but that won't be a difficult
 * limitation to remove).
 *
 * The protocol ("B" is bootloader, "H" is host) is:
 *  - B -> H: "MBOOT"
 *  - H -> B: number of packets to send (single byte)
 *  - For each packet:
 *    - B -> H: number of packets expected *after* this one (single byte)
 *    - H -> B: packet contents (16 bytes)
 *  - B -> H: "DONE"
 *
 * Assemble this with "mas --fmt bootrom serial_bootloader.ma -o bootrom.hex"
 * and put bootrom.hex in the root of the repo.
 */

/* r29 will always point to the serial port's memory area.
 * r28 is the next address to write to.
 * r27 is the number of packets remaining to read.
 */
{
  r29 <- long; long 0x80001000; // Serial port base address
  r11 <- 0b00100; // Value to write to serial status register
  r28 <- 0x1000; // Destination address (at which to store the program).
                 // Note (if you change this): appears again below.
}
{ r26 <- 0x80000000; r0 <- 1; }
{ *l(r26) <- r0; }
{
  bl write_uart;
  *l(r29 + 4) <- r11; // enable rx
  r0 <- 'M'; }
{ bl write_uart; r0 <- 'B'; }
{ bl write_uart; r0 <- 'O'; }
{ bl write_uart; r0 <- 'O'; }
{ bl write_uart; r0 <- 'T'; }
{ bl read_uart; }
{ r27 <- r0; }
outer_loop:
  { bl read_packet; r27 <- r27 - 1; }
  { p0 <- r27 == 0; }
  { !p0? b outer_loop; }
{ bl write_uart; r0 <- 'D'; }
{ bl write_uart; r0 <- 'O'; }
{ bl write_uart; r0 <- 'N'; }
{ bl write_uart; r0 <- 'E'; r28 <- 0x1000; }
{ b r28; }

// Note: the functions here don't save any registers. Beware of that if
// you update anything here, or try to use these functions elsewhere.
read_packet:
  { r3 <- 15; r10 <- r31; } // Note: one less than the number of bytes to read.
  { bl write_uart; r0 <- r27; }
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