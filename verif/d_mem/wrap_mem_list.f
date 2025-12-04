# This It tells your simulator (ModelSim / VCS...) which files to compile,
# and where to look for include directories.

# where to look for "include" directories
+incdir+source/common
+incdir+source/d_mem
+incdir+verif/d_mem

# Source files - this is the list of files to compile
source/common/dff_macros.svh
source/d_mem/d_mem.sv
source/d_mem/wrap_mem.sv
verif/d_mem/wrap_mem_tb.sv