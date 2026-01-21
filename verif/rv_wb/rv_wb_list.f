# File list for rv_wb simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/rv_pkg.sv
source/common/dff_macros.svh
source/cpu/rv_wb.sv
# verif/rv_wb/rv_wb_tb.sv  (if you want to add a testbench, add it here and remove the comment)
