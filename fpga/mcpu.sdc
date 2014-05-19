# Clock constraints
create_clock -name "clk125" -period 8.000ns [get_ports {PIN_U12}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# tsu/th constraints

# tco constraints

# set_output_delay -clock "clk125" -max 3ns [get_ports {led}] 


# tpd constraints

