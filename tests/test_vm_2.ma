{ r4 <- long; long handler; }
{ EHA <- r4; }

{ r0 <- 0x1000; r1 <- 0x2003; r2 <- 0x2000; r3 <- 0x3; }
{ *l(r0) <- r1; r0 <- 0x3000; r1 <- long; long 0xabcde; }
{ *l(r2) <- r3; r2 <- 0x2004; r3 <- 0x3003; }
{ *l(r0) <- r1; *l(r2) <- r3; }
{ r0 <- long; long 0xaaaaa; }
{ r0 <- *l(r2); } // Should be 0x3003
{ r0 <- *l(r2 - 4); } // Should be 0x3
{ r0 <- 0x1000; r1 <- 0b10; }
{ PTB <- r0; }
{ PFLAGS <- r1; r0 <- 0x1000; r1 <- 7; }
{ r0 <- *l(r0); } // Should be 0xabcde. If paging doesn't work, will be 0x2003.
{ r1 <- 5; }

{ break 0x1f; }

handler:
{ r0 <- 0xfffff; }
{ break 0x1f; }

// 0x1000:  0x2003
// 0x2000:  0x0003  0x3003
// 0x3000: 0xabcde
