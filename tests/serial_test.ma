          { r10 <- 0x80001000; r0 <- 0x4000; }
          // Set baud rate
          { *l(r10 + 0) <- r0; }

          { r1 <- long; long tx_data; }
          // Read a character, and increment the string pointer (r1).
loop:     { r2 <- *b(r1); r1 <- r1 + 1; }
          // Read the control register, and see if we're at the end of the
          // string.
tx_wait:  { r3 <- *l(r10 + 8); p0 <- r2 == 0; }
          // Check the TX_EMPTY bit.
          { p0? b end; p1 <- r3 & 0b100; }
          // If it's not empty, wait until it is. If it's empty, write to it.
          { !p1? b tx_wait; p1? *l(r10 + 4) <- r2; }
          { b loop; }

tx_data:  { long 0x6c6c6548; long 0x6f57206f; long 0x21646c72; long 0xa; }
end:      { b end; }