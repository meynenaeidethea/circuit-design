package require ::quartus::project
project_new onfi_integration_check
set_global_assignment -name FAMILY "Cyclone 10 LP"
set_global_assignment -name DEVICE 10CL025YU256C8G
set_global_assignment -name TOP_LEVEL_ENTITY onfi_integration_top
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
foreach source {
    onfi_fsm_pkg.vhd onfi_protocol_fsm.vhd onfi_stream_fifo.vhd
    onfi_packet_bridge.vhd onfi_integration_top.vhd
} {
    set_global_assignment -name VHDL_FILE $source
}
set_global_assignment -name SDC_FILE check_integration.sdc
set_global_assignment -name NUM_PARALLEL_PROCESSORS 2
foreach port {
    sink_data_i[*] sink_valid_i sink_sop_i sink_eop_i sink_empty_i[*] sink_ready_o
    source_data_o[*] source_valid_o source_sop_o source_eop_o source_empty_o[*] source_ready_i
    phy_rst_no phy_initialized_i phase_o.* cmd_valid_o cmd_ready_i
    w_data_o[*] w_last_o w_valid_o w_ready_i r_data_i[*] r_last_i r_valid_i r_ready_o
    done_i.* done_valid_i done_ready_o recover_req_o recover_ack_i busy_o fault_o
} {
    set_instance_assignment -name VIRTUAL_PIN ON -to $port
}
export_assignments
project_close
