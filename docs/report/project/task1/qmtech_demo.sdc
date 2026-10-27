create_clock -name clk50 -period 20.000 [get_ports {clk50_i}]
derive_clock_uncertainty
# External button asynchronously asserts the reset synchronizer.
# Release is synchronized by resetSync_r before reaching the datapath.
set_false_path -from [get_ports {nRst_btn_i}]
# LEDs have no external sampling clock or setup/hold requirement.
set_false_path -to [get_ports {conveyorLed_n_o rejectLed_n_o}]
