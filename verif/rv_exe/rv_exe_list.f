# File list for rv_exe simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/rv_pkg.sv
source/common/dff_macros.svh
source/cpu/rv_exe.sv
# verif/rv_exe/rv_exe_tb.sv  (if you want to add a testbench, add it here and remove the comment)
