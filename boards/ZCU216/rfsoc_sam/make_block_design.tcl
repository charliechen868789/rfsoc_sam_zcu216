set overlay_name "block_design"
set design_name "rfsoc_sam"
set iprepo_dir ./../../ip/iprepo

# Create project
create_project ${overlay_name} ./${overlay_name} -part xczu49dr-ffvf1760-2-e
set_property board_part xilinx.com:zcu216:part0:2.0 [current_project]
set_property target_language VHDL [current_project]

# Set IP repository paths
set_property ip_repo_paths $iprepo_dir [current_project]
update_ip_catalog

# Add constraints
add_files -fileset constrs_1 -norecurse ./constraints.xdc

# Add ZCU216 I/Q de-interleave adapter (see rfsoc_sam.tcl KNOWN ISSUE note)
add_files -norecurse ./hdl/axis_iq_deinterleave.vhd
set_property file_type {VHDL} [get_files axis_iq_deinterleave.vhd]
update_compile_order -fileset sources_1

# Make block design
source ./${design_name}.tcl
