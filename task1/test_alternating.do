onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
set source_dir [file dirname [file normalize [info script]]]
file mkdir [file join $source_dir simulation alternating]
cd [file join $source_dir simulation alternating]
if {![file exists work]} {vlib work}
vmap work work
foreach source {conveyor_sorter.vhd flow_tester.vhd conveyor_sorter_top.vhd qmtech_demo_top.vhd struct_tb.vhd flow_tester_tb.vhd} {
    vcom -2008 [file join $source_dir $source]
}
set BreakOnAssertion 2
foreach cycles {1 2 3 8} {
    vsim -onfinish stop work.struct_tb -gREJECT_CYCLES=$cycles
    run -all
    quit -sim
}
foreach cycles {1 2 8} {
    vsim -onfinish stop work.flow_tester_tb -gSTEP_CYCLES=$cycles
    run -all
    quit -sim
}
