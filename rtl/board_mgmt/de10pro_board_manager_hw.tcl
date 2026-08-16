package require -exact qsys 19.2

set_module_property NAME de10pro_board_manager
set_module_property VERSION 1.0
set_module_property DISPLAY_NAME "DE10-Pro board manager"
set_module_property DESCRIPTION "Telemetry, fail-safe fan control, and Vortex clock control"
set_module_property GROUP "Board Management"
set_module_property AUTHOR "Vortex"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false

add_fileset synth_fileset QUARTUS_SYNTH synth_callback
set_fileset_property synth_fileset TOP_LEVEL de10pro_board_manager
proc synth_callback {entity_name} {
    add_fileset_file board_mgmt_i2c_master.v VERILOG PATH board_mgmt_i2c_master.v
    add_fileset_file board_mgmt_core.v VERILOG PATH board_mgmt_core.v
    add_fileset_file de10pro_dynamic_clock.v VERILOG PATH de10pro_dynamic_clock.v
    add_fileset_file de10pro_board_manager.v VERILOG PATH de10pro_board_manager.v TOP_LEVEL_FILE
}

add_parameter MGMT_CLK_HZ INTEGER 50000000
set_parameter_property MGMT_CLK_HZ HDL_PARAMETER true
set_parameter_property MGMT_CLK_HZ UNITS Hertz

add_parameter TELEMETRY_POLL_CYCLES INTEGER 5000000
set_parameter_property TELEMETRY_POLL_CYCLES HDL_PARAMETER true

add_interface clock clock end
set_interface_property clock clockRate 50000000
add_interface_port clock clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset reset Input 1

add_interface csr avalon end
set_interface_property csr addressUnits SYMBOLS
set_interface_property csr associatedClock clock
set_interface_property csr associatedReset reset
set_interface_property csr bitsPerSymbol 8
set_interface_property csr explicitAddressSpan 256
set_interface_property csr maximumPendingReadTransactions 1
set_interface_property csr readLatency 0
add_interface_port csr avs_address address Input 8
add_interface_port csr avs_byteenable byteenable Input 4
add_interface_port csr avs_chipselect chipselect Input 1
add_interface_port csr avs_read read Input 1
add_interface_port csr avs_readdata readdata Output 32
add_interface_port csr avs_readdatavalid readdatavalid Output 1
add_interface_port csr avs_waitrequest waitrequest Output 1
add_interface_port csr avs_write write Input 1
add_interface_port csr avs_writedata writedata Input 32

add_interface reconfig avalon start
set_interface_property reconfig addressUnits SYMBOLS
set_interface_property reconfig associatedClock clock
set_interface_property reconfig associatedReset reset
set_interface_property reconfig bitsPerSymbol 8
set_interface_property reconfig burstOnBurstBoundariesOnly false
set_interface_property reconfig doStreamReads false
set_interface_property reconfig doStreamWrites false
set_interface_property reconfig linewrapBursts false
set_interface_property reconfig maximumPendingReadTransactions 0
add_interface_port reconfig reconfig_address address Output 10
add_interface_port reconfig reconfig_read read Output 1
add_interface_port reconfig reconfig_write write Output 1
add_interface_port reconfig reconfig_writedata writedata Output 8
add_interface_port reconfig reconfig_readdata readdata Input 8
add_interface_port reconfig reconfig_waitrequest waitrequest Input 1

add_interface board_io conduit end
set_interface_property board_io associatedClock clock
set_interface_property board_io associatedReset reset
add_interface_port board_io temp_scl temp_scl Bidir 1
add_interface_port board_io temp_sda temp_sda Bidir 1
add_interface_port board_io fan_scl fan_scl Bidir 1
add_interface_port board_io fan_sda fan_sda Bidir 1
add_interface_port board_io power_scl power_scl Bidir 1
add_interface_port board_io power_sda power_sda Bidir 1
add_interface clock_control conduit end
set_interface_property clock_control associatedClock ""
set_interface_property clock_control associatedReset ""
add_interface_port clock_control clock_change_req clock_change_req Output 1
add_interface_port clock_control clock_reset_req clock_reset_req Output 1
add_interface_port clock_control clock_change_ack clock_change_ack Input 1
add_interface_port clock_control clock_reset_ack clock_reset_ack Input 1

add_interface memory_drain conduit end
set_interface_property memory_drain associatedClock ""
set_interface_property memory_drain associatedReset ""
add_interface_port memory_drain memory_drain_req drain_req Output 1
add_interface_port memory_drain memory_drain_ack drain_ack Input 1

add_interface pll_status conduit end
set_interface_property pll_status associatedClock ""
set_interface_property pll_status associatedReset ""
add_interface_port pll_status pll_locked export Input 1

add_interface vortex_clock clock end
set_interface_property vortex_clock clockRate 0
add_interface_port vortex_clock vortex_clk clk Input 1
