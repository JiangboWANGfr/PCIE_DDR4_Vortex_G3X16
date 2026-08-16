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
create_clock -period "166.666666 MHz" [get_ports DDR4B_REFCLK_p]
create_clock -period "166.666666 MHz" [get_ports DDR4C_REFCLK_p]
create_clock -period "166.666666 MHz" [get_ports DDR4D_REFCLK_p]

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
proc vortex_require_collection_size {label collection expected_size} {
    set actual_size [llength [query_collection -report -all $collection]]
    if {$actual_size != $expected_size} {
        set message "$label matched $actual_size nodes; expected $expected_size"
        post_message -type error $message
        error $message
    }
}

set_false_path -from [get_ports CPU_RESET_n] -to [get_registers {any_rstn_r any_rstn_rr si5340_rstn_r si5340_rstn_rr}]
# PCIE_PERST_n is an asynchronous board-level reset, including the direct HIP pin_perst path.
set_false_path -from [get_ports PCIE_PERST_n]
set_false_path -from {any_rstn_rr}
set_false_path -to [get_ports LED*]
set_false_path -to [get_ports BUTTON*]

# Cut only the asynchronous input into each manually implemented two-stage
# synchronizer. Do not replace these targeted exceptions with asynchronous
# clock groups: the Qsys CDC FIFOs retain their generated max-skew constraints.
foreach {cdc_label cdc_pattern} {
    dynamic_pll_locked u_pcie_ddr4_system|board_manager_0|board_manager_0|dynamic_clock|pll_locked_sync[0]
    dynamic_change_ack u_pcie_ddr4_system|board_manager_0|board_manager_0|dynamic_clock|change_ack_sync[0]
    dynamic_memory_drain_ack u_pcie_ddr4_system|board_manager_0|board_manager_0|dynamic_clock|memory_drain_ack_sync[0]
    dynamic_reset_ack u_pcie_ddr4_system|board_manager_0|board_manager_0|dynamic_clock|reset_ack_sync[0]
    status_pll_locked u_pcie_ddr4_system|board_manager_0|board_manager_0|pll_locked_sync[0]
    status_change_ack u_pcie_ddr4_system|board_manager_0|board_manager_0|change_ack_sync[0]
    status_memory_drain_ack u_pcie_ddr4_system|board_manager_0|board_manager_0|memory_drain_ack_sync[0]
    shell_clock_change_req u_pcie_ddr4_system|vortex_shell_0|vortex_shell_0|clock_control|clock_change_req_sync[0]
    shell_clock_reset_req u_pcie_ddr4_system|vortex_shell_0|vortex_shell_0|clock_control|clock_reset_req_sync[0]
    memory_drain_req u_pcie_ddr4_system|vortex_mem_drain_0|vortex_mem_drain_0|drain_req_meta
} {
    set cdc_meta [get_registers -nowarn $cdc_pattern]
    vortex_require_collection_size "manual CDC $cdc_label" $cdc_meta 1
    set_false_path -to $cdc_meta
}

# Board-management I2C output timing is intentionally waived; the controller
# uses CLK_50_B2C clock-enables and requires RTL plus board-level verification.
set_false_path -to [get_ports {SI5340A0_I2C_SCL SI5340A0_I2C_SDA SI5340A1_I2C_SCL SI5340A1_I2C_SDA}]
set_false_path -from [get_ports {TEMP_I2C_SCL TEMP_I2C_SDA FAN_I2C_SCL FAN_I2C_SDA POWER_MONITOR_I2C_SCL POWER_MONITOR_I2C_SDA}]
set_false_path -to [get_ports {TEMP_I2C_SCL TEMP_I2C_SDA FAN_I2C_SCL FAN_I2C_SDA POWER_MONITOR_I2C_SCL POWER_MONITOR_I2C_SDA}]



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************
set vortex_gray_source [get_registers -nowarn {u_pcie_ddr4_system|board_manager_0|board_manager_0|dynamic_clock|vortex_counter_gray[*]}]
set vortex_gray_meta [get_registers -nowarn {u_pcie_ddr4_system|board_manager_0|board_manager_0|dynamic_clock|vortex_gray_meta[*]}]
vortex_require_collection_size "Vortex Gray source registers" $vortex_gray_source 32
vortex_require_collection_size "Vortex Gray first-stage registers" $vortex_gray_meta 32

# Follow the Quartus 19.2 altera_avalon_dc_fifo constraint model: keep the
# asynchronous paths available for physical net-delay and bus-skew control.
set_max_delay -from $vortex_gray_source -to $vortex_gray_meta 200
set_net_delay -max -get_value_from_clock_period dst_clock_period \
    -value_multiplier 0.8 -from $vortex_gray_source -to $vortex_gray_meta
set_max_skew -get_skew_value_from_clock_period src_clock_period \
    -skew_value_multiplier 0.8 -from $vortex_gray_source -to $vortex_gray_meta



#**************************************************************
# Set Minimum Delay
#**************************************************************
set_min_delay -from $vortex_gray_source -to $vortex_gray_meta -200



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************
