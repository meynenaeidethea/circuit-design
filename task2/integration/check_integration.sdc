create_clock -name avalon_clk -period 20.000 [get_ports clk_avalon_i]
create_clock -name logic_clk -period 8.000 [get_ports clk_logic_i]
set_clock_groups -asynchronous -group [get_clocks avalon_clk] -group [get_clocks logic_clk]
derive_clock_uncertainty
