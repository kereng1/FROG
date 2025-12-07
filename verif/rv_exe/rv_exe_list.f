# File list for rv_exe simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/pkg.sv
source/common/dff_macros.svh
source/cpu/rv_exe.sv
# verif/rv_exe/rv_exe_tb.sv  (if i want to add a testbench, add it here take of the comment)

