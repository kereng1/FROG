# File list for rv_mem_wrap simulation

# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/rv_pkg.sv
source/common/dff_macros.svh

# Memory implementation
source/common/rv_mem.sv
source/cpu/rv_dmem_wrap.sv

# DUT: rv_mem_wrap stage
source/cpu/rv_mem_wrap.sv

# Testbench
verif/rv_memory/rv_memory_tb.sv
