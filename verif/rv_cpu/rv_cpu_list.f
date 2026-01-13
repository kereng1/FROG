# File list for rv_cpu simulation
# Include directories
+incdir+source/common
+incdir+source/cpu

# Source files - compile in order (dependencies first)
source/common/pkg.sv
source/common/dff_macros.svh

# CPU pipeline stages
source/cpu/rv_if.sv
source/cpu/rv_decode.sv
source/cpu/rv_exe.sv
source/cpu/rv_ma.sv
source/cpu/rv_wb.sv
source/cpu/rv_ctrl.sv
source/cpu/rv_cpu.sv

# Testbench
verif/rv_cpu/rv_cpu_tb.sv
