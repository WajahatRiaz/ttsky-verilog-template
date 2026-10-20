# ODIN Tapeout wrapper — 50 MHz on clk
set clock_period 20.0
set clock_port [get_ports clk]
create_clock -name clk -period $clock_period $clock_port
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

set all_inputs_no_clk {}
foreach port [get_ports *] {
	if {[get_property $port direction] == "input" && [get_property $port name] != "clk"} {
		lappend all_inputs_no_clk $port
	}
}

set io_budget [expr {$clock_period * 0.5}]
if {[llength $all_inputs_no_clk] > 0} {
	set_input_delay -clock [get_clocks clk] $io_budget $all_inputs_no_clk
}

set all_outputs [all_outputs]
if {[llength $all_outputs] > 0} {
	set_output_delay -clock [get_clocks clk] $io_budget $all_outputs
}

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X [all_inputs]
set_load 0.033 [all_outputs]
