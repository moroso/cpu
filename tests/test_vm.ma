           // Copy the page directory to a page.
           { r0 <- 0x1000; r1 <- long; long pagedir; r2 <- 4; }
           { bl rt_memcpy; }
           // Copy the page table.
           { r0 <- 0x2000; r1 <- long; long pagetab; r2 <- 16; }
           { bl rt_memcpy; }

           // At this point, the page directory and table entry are set up.
           { r0 <- 0x1000; r1 <- 0b10; }
           { ptb <- r0; }
           { pflags <- r1; }

b1:        { bl store_caller; }
           { r20 <- r0; }
           { r20 <- r20 - long; long b1; }

           { r7 <- long; long fourtytwo; }
           { r21 <- *l(r7); }
           { r7 <- r7 + 0x3000; }
           { r22 <- *l(r7); }
           { r0 <- long; long store_caller_wrapper; }
           { r0 <- r0 + 0x3000; }
           { bl r0; }
           { r23 <- r0 - long; long b2; }

exit:      { r30 <- 0; r0 <- 0; r1 <- 0; r7 <- 0; }
           { break 0x1f; }
store_caller_wrapper:
           { r7 <- r31; }
b2:        { bl store_caller; }
           { r31 <- r7; }
           { b r31 + 1; }
store_caller:
           { r0 <- r31; }
           { b r31 + 1; }

rt_memcpy: { p1 <- r2 == 0 }
           { p1? b r31 + 1; }
memcpy_loop:
           { r3 <- *b(r1); r2 <- r2 - 1; p0 <- r2 <=s 1; p1 <- r2 == 0; }
           { !p0? b memcpy_loop; !p1? *b(r0) <- r3; r0 <- r0 + 1;
             r1 <- r1 + 1; }
           { p0? b r31 + 1; }

// 0x0000 -> 0x0fff: code (flat mapped)
// 0x1000 -> 0x1fff: page directory (flat mapped)
// 0x2000 -> 0x2fff: page table (flat mapped)
// 0x3000 -> 0x3fff: maps to 0x0000

pagedir:   { long 0x00002003; }
pagetab:   { long 0x00000003; long 0x00001003; long 0x00002003; long 0x00000003; }
fourtytwo: { long 0x42424242; }