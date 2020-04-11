{r30 <- 0x80000000; r29 <- long; long 0x80001000; r10 <- 0b100}
{*l(r29 + 4) <- r10; *l(r30) <- r10}
loop:
{bl recv_char}
{p1 <- r0 == 0x100}
{!p1? bl send_char; !p1? *l(r30) <- r0}
//{!p1? *l(r30) <- r0}
{b loop}


/* Wait for UART TX queue to be empty, then write r0 into it.
 * Uses: r1
 */
send_char:
{r1 <- *l(r29 + 4)}
{p0 <- r1 & 0b10}
{!p0? b send_char; p0? *l(r29) <- r0}
{b r31 + 1}

/* Non-blocking UART receive - return a character and clear rx complete bit
 * returns 0x100 if nothing available
 * Uses: r1
 */
recv_char:
{r1 <- *l(r29 + 4)}
{p0 <- r1 & 0b1000}
{p0? *l(r29 + 4) <- r10; p0? r0 <- *l(r29); !p0? r0 <- 0x100}
{b r31 + 1}