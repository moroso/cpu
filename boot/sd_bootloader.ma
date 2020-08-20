// Note: we can eliminate a few packets in this by changing the register
// allocation. It's not necessarily worth doing so; it would certainly
// make it less readable.

{ b self_copy; }
{
  r30 <- long; long 0x80003000; // SD peripheral address.
  r0 <- 4; // SD speed
  r1 <- 1; // Data wires (value of 1 => 4 wires)
}
{
  *l(r30 + 0) <- r0; // Set speed
  *l(r30 + 4) <- r1; // 4 data wires
  r26 <- 0x0; // Destination
  r0 <- 0;
}

// Send CMD0
{ *l(r30 + 16) <- r0; *l(r30 + 12) <- r0; r0 <- 1; r28 <- 0x80000000; }
{ bl wait_sd; *l(r28) <- r0; }

// Send CMD8
{ r0 <- 0x1aa; r1 <- 0x2808; }
{ *l(r30 + 16) <- r0; *l(r30 + 12) <- r1; r0 <- 2; }
{ bl wait_sd; *l(r28) <- r0; }
{ bl test_resp; r0 <- 0x08000001; r1 <- 0xaa000000; }
{ !p0? b fail; }

init_loop:
  // CMD55
  { r0 <- 0; r1 <- 0x2837; } // TODO: by choosing different registers, we could save
                             // a packet by merging this into the one before it.
  { *l(r30 + 16) <- r0; *l(r30 + 12) <- r1; r0 <- 3; }
  { bl wait_sd; *l(r28) <- r0; }
  { bl test_resp; r0 <- 0x37000001; r1 <- 0x20000000; }
  // ACMD41
  { !p0? b fail; r0 <- 0x40100000; r1 <- 0x2829; }
  { *l(r30 + 16) <- r0; *l(r30 + 12) <- r1; r0 <- 4; }
  { bl wait_sd; *l(r28) <- r0; }
  // Check the ready bit
  { r0 <- *l(r30 + 32); r1 <- long; long 0x800000; }
  { p0 <- r0 & r1; }
  { !p0? b init_loop; r0 <- 0; r1 <- long; long 0x8002; } // Card isn't ready yet. Keep trying.

// CMD2
{ *l(r30 + 16) <- r0; *l(r30 + 12) <- r1; r2 <- 5; }
{ bl wait_sd; *l(r28) <- r2; }

// CMD3
{ r0 <- 0; r1 <- long; long 0x8003; }
{ *l(r30 + 16) <- r0; *l(r30 + 12) <- r1; r2 <- 6; }
{ bl wait_sd; *l(r28) <- r2; }
{ r7 <- *l(r30 + 32); r0 <- long; long 0xffff0000; r2 <- 7; }
{ r7 <- r0 & (r7 << 8); *l(r28) <- r2; r1 <- 0x2807; } // r7 now has the RCA in its upper 16 bits.

// CMD7
{ *l(r30 + 16) <- r7; *l(r30 + 12) <- r1; r2 <- 8; }
{ bl wait_sd; *l(r28) <- r2; r1 <- 0x2837; }

// These two are to set the number of data lines.
// We can omit this if we're just using one, but... may as well use all four.
// CMD55
{ *l(r30 + 16) <- r7; *l(r30 + 12) <- r1; r2 <- 9; }
{ bl wait_sd; *l(r28) <- r2; r1 <- 2; r2 <- 0x2806; }
// ACMD6
{ *l(r30 + 16) <- r1; *l(r30 + 12) <- r2; r2 <- 10; }
{ bl wait_sd; *l(r28) <- r2; }

{ r9 <- 0; r10 <- 0; }
card_copy_loop:
  // Card initialized. Ready to start transfer.
  { bl sd_data_read; r0 <- r9; r9 <- r9 + 1; }
  { bl sd_data_copy; r0 <- r26 + r10; r10 <- r10 + 0x200; }
  // Change this to change how much data we copy, in 512-byte increments.
  // Later we might want a boot record on the card telling us how many
  // pages to load. For now, 1MB is plenty for the kernel and anything
  // else we're likely to want to boot, and takes ~1 second to do the
  // copy, which isn't terrible.
  { p0 <- r9 < 2048; } // 2048 gives us 1MB
  { p0? b card_copy_loop; }

{ flush.inst r0; } // TODO: the r0 is unused right now; this'll need to be updated later.

{ b r26; }
{ b fail; }

sd_data_read:
  { r1 <- long; long 0x12811; }
  { *l(r30 + 16) <- r0; *l(r30 + 12) <- r1; r2 <- 11; }
  { b wait_sd; *l(r28) <- r2; }

sd_data_copy:
  { r1 <- 0x80; r2 <- r0; r29 <- long; long 0x80003800; } // Data region
  cpy_loop:
    { r0 <- *l(r29); r1 <- r1 - 1; }
    { *l(r2) <- r0; r29 <- r29 + 4; r2 <- r2 + 4; p0 <- r1 == 0;}
    { !p0? b cpy_loop; }
  { bl r31 + 1; }

wait_sd:
  { r0 <- *l(r30 + 8); }
  { p0 <- r0 & 0b111; }
  { p0? b wait_sd; }
  { b r31 + 1; }

test_resp:
  // Tests the first two words of the response against r0 and r1.
  // p1 will be 1 if they match.
  { r2 <- *l(r30 + 32); r3 <- *l(r30 + 36); }
  { p1 <- r0 == r2; p0 <- r0 < r0; }
  { b r31 + 1; p1? p0 <- r1 == r3; }

fail:
  { r0 <- *l(r28); }
  { r0 <- r0 | 0x20000; }
  { *l(r28) <- r0; }
  { b fail; }

// Get the bootloader out of the way. Put it right at the end of
// memory, so that we can copy the target program to 0.
self_copy:
  { r0 <- 0x0; r1 <- long; long 0x1ffff000; r2 <- 0x400; }
  { r7 <- r1; }
  self_copy_loop:
    { r3 <- *l(r0); r2 <- r2 - 1; r0 <- r0 + 4; p0 <- r2 == 1; }
    { !p0? b self_copy_loop; *l(r1) <- r3; r1 <- r1 + 4; }
  { flush.inst r0; } // TODO: the r0 is unused right now; this'll need to be updated later.

  { b r7 + 1; }
