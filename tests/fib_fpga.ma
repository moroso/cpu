start:
{r31 <- long; long 0x80000000}
{r1 <- *w(r31)}
{r2 <- 1; r3 <- 0; p0 <- r1 == 0}
loop:
{p0 ? b end}
{r2 <- r2 + r3; r3 <- r2; r1 <- r1 - 1}
{b loop; p0 <- r1 == 0}
end:
{b start; *w(r31) <- r2}
{break 0x1fu}