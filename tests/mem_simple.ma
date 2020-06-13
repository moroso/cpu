{r0 <- 0xEE1; r3 <- 0x1000}
{*w(r3) <- r0; *w(r3 + 4) <- r0}
{r1 <- *w(r3); r2 <- *w(r3 + 4)}
{r1 <- r1; r2 <- r2;} // just to make sure the sim doesn't exit early
{break 0x1fu}