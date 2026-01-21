# File list for rv_if simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/rv_pkg.sv
source/common/dff_macros.svh
source/cpu/rv_if.sv
# verif/rv_if/rv_if_tb.sv  (if you want to add a testbench, add it here and remove the comment)
