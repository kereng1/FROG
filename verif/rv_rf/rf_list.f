# File list for rv_decode (register file) simulation
# Note: The register file is now part of rv_decode module

# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/dff_macros.svh
source/common/rv_pkg.sv
source/cpu/rv_decode.sv

# Testbench
verif/rv_rf/tb_rv_rf.sv
