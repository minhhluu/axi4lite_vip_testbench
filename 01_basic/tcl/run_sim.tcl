# Step 1: Set the simulation runtime to a safe value (all-at-once)
set_property -name "xsim.simulate.runtime" -value "-all" -objects [get_filesets sim_1]

# Step 2: Reset and relaunch the simulation
puts "=============================================="
puts "  Launching AXI4-Lite Validation Simulation"
puts "=============================================="

launch_simulation

# The simulation will run to $finish automatically because runtime = -all
# All $display output appears in the Tcl Console

puts ""
puts "=============================================="
puts "  Simulation complete — review messages above"
puts "=============================================="
