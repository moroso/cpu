start:
{r1 <- r31}
{r2 <- 1; r3 <- 1; r4 <- 0; p0 <- r1 == 0}
loop:
{p0 ? b end}
{r2 <- r3 + r4; r3 <- r2; r4 <- r3; r1 <- r1 - 1}
{b loop}
end:
{b start; r0 <- r2}