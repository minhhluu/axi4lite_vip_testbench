## KC705 Evaluation Board - 200 MHz System Clock Constraint

# 1. Create the clock object for synthesis/timing analysis
#    -name: User-defined name for the clock inside vivado
#    -period: Clock period in nanoseconds (200 MHz = 1 / 200x10^6 = 5.0 ns)
#    [get_ports]: The top-level input port name of your design
create_clock -name sys_clk -period 5.000 [get_ports aclk]

# 2. (Optional but recommended) Assign the clock to the specific differential
#    pins available on the KC705 board (AD12/AD11 are the 200MHz sysclk pins)
#    If you just want synthesis numbers and aren't programming a real board right now,
#    you can leave these commented out.

# set_property PACKAGE_PIN AD12 [get_ports aclk_p]
# set_property IOSTANDARD LVDS [get_ports aclk_p]
# set_property PACKAGE_PIN AD11 [get_ports aclk_n]
# set_property IOSTANDARD LVDS [get_ports aclk_n]
