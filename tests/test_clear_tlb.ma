.struct PAGETAB_ENT {
    page: 31..12;
    global: 3;
    kernel: 2;
    writeable: 1;
    present: 0;
}

{ r4 <- long; long handler; }
{ EHA <- r4; }

{
    r0 <- 0x1000;
    r1 <- PAGETAB_ENT { page=2, writeable=1, present=1 };
    r2 <- 0x2000;
    r3 <- PAGETAB_ENT { page=0, writeable=1, present=1 };
}
{ *l(r0) <- r1; r0 <- 0x3000; r1 <- long; long 0xabcde; }
{
    *l(r2) <- r3;
    r2 <- 0x2004;
    r3 <- PAGETAB_ENT { page=3, writeable=1, present=1 };
}
{
    *l(r0) <- r1;
    *l(r2) <- r3;
    r2 <- 0x4000;
    r3 <- PAGETAB_ENT { page=5, writeable=1, present=1 };
}
{
    *l(r2) <- r3;
    r2 <- 0x5000;
    r3 <- PAGETAB_ENT { page=0, writeable=1, present=1 };
    r4 <- PAGETAB_ENT { page=5, writeable=1, present=1 };
}
{ *l(r2) <- r3; *l(r2 + 4) <- r4; }
{ r0 <- long; long 0xaaaaa; }
{ r0 <- *l(r2); } // Should be 0x3003
{ r0 <- *l(r2 - 4); } // Should be 0x3
{ r0 <- 0x1000; r1 <- 0b10; }
{ PTB <- r0; }
{ PFLAGS <- r1; r0 <- 0x1000; r1 <- 7; }
{ r0 <- *l(r0); }

{ r1 <- 0x4000; }
{ PTB <- r1; }
{ r2 <- 0x1000; }
{ nop; }
{ nop; }
{ nop; }
{ r1 <- *l(r2); }

{ break 0x1f; }

handler:
{ r0 <- 0xfffff; }
{ break 0x1f; }

// 0x1000:  0x2003
// 0x2000:  0x0003  0x3003
// 0x3000: 0xabcde
// 0x4000:  0x5003
// 0x5000:  0x0003  0x5003