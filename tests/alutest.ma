{r0 <- 1; r1 <- 0xFF80; r10 <- long; long 0x12345678}
{r4 <- 4; r5 <- 5; r6 <- 6; r7 <- 7}
{r2 <- SXB r1; p0 <- r1 == 1; r3 <- r4 - r5; r8 <- r6 + (r7 >>u 1)}
{p0? r9 <- 1; !p0? r9 <- 2; nop; nop}

{ break 0x1f }