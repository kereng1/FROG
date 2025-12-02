# This It tells your simulator (ModelSim) which files to compile for rf,
# and where to look for include directories.

# where to look for "include" directories
+incdir+source/common
+incdir+source/rf

# Source files - this is the list of files to compile
source/common/dff_macros.svh
source/rf/rf.sv
verif/rf/rf_tb.sv