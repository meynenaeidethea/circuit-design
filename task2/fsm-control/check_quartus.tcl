package require ::quartus::project
project_new onfi_fsm_check
set_global_assignment -name FAMILY "Cyclone 10 LP"
set_global_assignment -name DEVICE 10CL025YU256C8G
set_global_assignment -name TOP_LEVEL_ENTITY onfi_protocol_fsm
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name VHDL_FILE onfi_fsm_pkg.vhd
set_global_assignment -name VHDL_FILE onfi_protocol_fsm.vhd
set_global_assignment -name SDC_FILE check_core.sdc
set_global_assignment -name NUM_PARALLEL_PROCESSORS 2
set_instance_assignment -name VIRTUAL_PIN ON -to "*"
set_instance_assignment -name VIRTUAL_PIN OFF -to clk_i
set_instance_assignment -name VIRTUAL_PIN OFF -to rst_n_i
set_parameter -name g_page_bytes 2048
set_parameter -name g_pages_per_block 64
set_parameter -name g_blocks_per_lun 1024
set_parameter -name g_read_id_bytes 5
set_parameter -name g_mode_mask 000011
export_assignments
project_close
