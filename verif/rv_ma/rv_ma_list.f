# File list for rv_mem simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/pkg.sv
source/common/dff_macros.svh
source/cpu/rv_mem.sv
# verif/rv_mem/rv_mem_tb.sv  (if i want to add a testbench, add it here take of the comment)

