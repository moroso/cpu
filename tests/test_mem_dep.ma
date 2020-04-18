{ r0 <- 0x1000; r1 <- long; long 0xabcdef; r2 <- 0xee; }
{ *l(r0) <- r1; *l(r0 + 4) <- r2; }
{ r2 <- *l(r0); }
{ r2 <- long; long 0x55555; }
{ break 0x1f; }