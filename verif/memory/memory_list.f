# File list for memory module simulation
# Include directories
+incdir+source/common
+incdir+source/d_mem
+incdir+source/cpu
+incdir+verif/memory

# Source files - compile in order (dependencies first)
source/common/dff_macros.svh
source/d_mem/d_mem.sv
source/d_mem/wrap_mem.sv
source/cpu/memory/memory.sv

# Testbench
verif/memory/memory_tb.sv

