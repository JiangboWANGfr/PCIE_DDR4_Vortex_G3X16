#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
# CLOCK
create_clock -period "100.000000 MHz" [get_ports CLK_100_B3I]
create_clock -period "50.000000 MHz" [get_ports CLK_50_B2C]
create_clock -period "50.000000 MHz" [get_ports CLK_50_B2L]
create_clock -period "50.000000 MHz" [get_ports CLK_50_B3C]
create_clock -period "50.000000 MHz" [get_ports CLK_50_B3I]
create_clock -period "50.000000 MHz" [get_ports CLK_50_B3L]

create_clock -period "100.000000 MHz" [get_ports PCIE_REFCLK_p]

create_clock -period "644.531250 MHz" [get_ports QSFP28A_REFCLK_p]
create_clock -period "644.531250 MHz" [get_ports QSFP28B_REFCLK_p]
create_clock -period "644.531250 MHz" [get_ports QSFP28C_REFCLK_p]
create_clock -period "644.531250 MHz" [get_ports QSFP28D_REFCLK_p]

create_clock -period "166.666666 MHz" [get_ports DDR4A_REFCLK_p]
create_clock -period "300.000000 MHz" [get_ports DDR4B_REFCLK_p]
create_clock -period "300.000000 MHz" [get_ports DDR4C_REFCLK_p]
create_clock -period "300.000000 MHz" [get_ports DDR4D_REFCLK_p]

# for enhancing USB BlasterII to be reliable, 25MHz
create_clock -name {altera_reserved_tck} -period 40 {altera_reserved_tck}
set_input_delay -clock altera_reserved_tck -clock_fall 3 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck -clock_fall 3 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck 3 [get_ports altera_reserved_tdo]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -asynchronous -group [get_clocks { PCIE_REFCLK_p }]
set_clock_groups -asynchronous -group [get_clocks { DDR4A_REFCLK_p }]
set_clock_groups -asynchronous -group [get_clocks { DDR4B_REFCLK_p }]
set_clock_groups -asynchronous -group [get_clocks { DDR4C_REFCLK_p }]
set_clock_groups -asynchronous -group [get_clocks { DDR4D_REFCLK_p }]



#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from {any_rstn_rr}
set_false_path -to [get_ports LED*]
set_false_path -to [get_ports BUTTON*]



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************



