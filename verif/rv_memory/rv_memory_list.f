# File list for rv_memory simulation

# Include directories
+incdir+source/common
+incdir+source/cpu
+incdir+source/d_mem
+incdir+verif/memory
+incdir+verif/rv_memory

# Source files - compile in order (dependencies first)
source/common/pkg.sv
source/common/dff_macros.svh

# Memory implementation
source/d_mem/mem.sv
source/d_mem/wrap_mem.sv


# DUT: rv_memory stage
source/cpu/rv_memory.sv

# Testbench
verif/rv_memory/rv_memory_tb.sv

