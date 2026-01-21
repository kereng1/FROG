# File list for rv_dmem_wrap simulation
# This tests the data memory wrapper module

# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/dff_macros.svh
source/common/rv_mem.sv
source/cpu/rv_dmem_wrap.sv

# Testbench
verif/wrap_mem/wrap_mem_tb.sv
