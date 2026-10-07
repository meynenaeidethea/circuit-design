onerror {abort}
set source_dir [file normalize [file dirname [info script]]]
file mkdir [file join $source_dir simulation alternating]
cd [file join $source_dir simulation alternating]
if {![file exists work]} {vlib work}
vmap work work
vcom -2008 [file join $source_dir conveyor_sorter.vhd]
vcom -2008 [file join $source_dir flow_tester.vhd]
vcom -2008 [file join $source_dir struct_tb.vhd]
vcom -2008 [file join $source_dir flow_tester_tb.vhd]
vsim -onfinish stop work.struct_tb
set BreakOnAssertion 2
run 400 ns
quit -sim
vsim -onfinish stop work.flow_tester_tb
set BreakOnAssertion 2
run -all
