package require -exact qsys 19.2

set_module_property NAME de10pro_vortex_mem_drain
set_module_property VERSION 1.0
set_module_property DISPLAY_NAME "DE10-Pro Vortex memory drain monitor"
set_module_property DESCRIPTION "Transparent Avalon-MM monitor for safe Vortex clock changes"
set_module_property GROUP "Board Management"
set_module_property AUTHOR "Vortex"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false

add_fileset synth_fileset QUARTUS_SYNTH synth_callback
set_fileset_property synth_fileset TOP_LEVEL de10pro_vortex_mem_drain
proc synth_callback {entity_name} {
    add_fileset_file de10pro_vortex_mem_drain.v VERILOG \
        PATH de10pro_vortex_mem_drain.v TOP_LEVEL_FILE
}

add_parameter ADDRESS_WIDTH INTEGER 33
set_parameter_property ADDRESS_WIDTH HDL_PARAMETER true

add_parameter DATA_WIDTH INTEGER 512
set_parameter_property DATA_WIDTH HDL_PARAMETER true

add_parameter BURSTCOUNT_WIDTH INTEGER 5
set_parameter_property BURSTCOUNT_WIDTH HDL_PARAMETER true

add_parameter OUTSTANDING_WIDTH INTEGER 16
set_parameter_property OUTSTANDING_WIDTH HDL_PARAMETER true

add_parameter QUIET_CYCLES INTEGER 8
set_parameter_property QUIET_CYCLES HDL_PARAMETER true

add_interface clock clock end
set_interface_property clock clockRate 0
add_interface_port clock clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset reset Input 1

add_interface s0 avalon end
set_interface_property s0 addressUnits SYMBOLS
set_interface_property s0 associatedClock clock
set_interface_property s0 associatedReset reset
set_interface_property s0 bitsPerSymbol 8
set_interface_property s0 maximumPendingReadTransactions 16
add_interface_port s0 s0_address address Input ADDRESS_WIDTH
add_interface_port s0 s0_burstcount burstcount Input BURSTCOUNT_WIDTH
add_interface_port s0 s0_byteenable byteenable Input DATA_WIDTH/8
add_interface_port s0 s0_debugaccess debugaccess Input 1
add_interface_port s0 s0_read read Input 1
add_interface_port s0 s0_readdata readdata Output DATA_WIDTH
add_interface_port s0 s0_readdatavalid readdatavalid Output 1
add_interface_port s0 s0_waitrequest waitrequest Output 1
add_interface_port s0 s0_write write Input 1
add_interface_port s0 s0_writedata writedata Input DATA_WIDTH

add_interface m0 avalon start
set_interface_property m0 addressUnits SYMBOLS
set_interface_property m0 associatedClock clock
set_interface_property m0 associatedReset reset
set_interface_property m0 bitsPerSymbol 8
set_interface_property m0 burstOnBurstBoundariesOnly false
set_interface_property m0 doStreamReads false
set_interface_property m0 doStreamWrites false
set_interface_property m0 linewrapBursts false
set_interface_property m0 maximumPendingReadTransactions 16
add_interface_port m0 m0_address address Output ADDRESS_WIDTH
add_interface_port m0 m0_burstcount burstcount Output BURSTCOUNT_WIDTH
add_interface_port m0 m0_byteenable byteenable Output DATA_WIDTH/8
add_interface_port m0 m0_debugaccess debugaccess Output 1
add_interface_port m0 m0_read read Output 1
add_interface_port m0 m0_readdata readdata Input DATA_WIDTH
add_interface_port m0 m0_readdatavalid readdatavalid Input 1
add_interface_port m0 m0_waitrequest waitrequest Input 1
add_interface_port m0 m0_write write Output 1
add_interface_port m0 m0_writedata writedata Output DATA_WIDTH

add_interface drain conduit end
set_interface_property drain associatedClock ""
set_interface_property drain associatedReset ""
add_interface_port drain drain_req_async drain_req Input 1
add_interface_port drain drain_ack drain_ack Output 1
