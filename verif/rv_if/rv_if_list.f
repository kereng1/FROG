# File list for rv_if simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/pkg.sv
source/common/dff_macros.svh
source/cpu/rv_if.sv
# verif/rv_if/rv_if_tb.sv  (if i want to add a testbench, add it here take off the comment)

