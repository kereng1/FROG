# File list for rv_cpu simulation with Reference Model
# Include directories
+incdir+source/common
+incdir+source/cpu
+incdir+verif/rv_cpu

# Source files - compile in order (dependencies first)
source/common/rv_pkg.sv
source/common/dff_macros.svh

# CPU pipeline stages
source/cpu/rv_if.sv
source/cpu/rv_decode.sv
source/cpu/rv_exe.sv
source/cpu/rv_ma.sv
source/cpu/rv_wb.sv
source/cpu/rv_ctrl.sv
source/cpu/rv_cpu.sv

# Memory modules
source/common/rv_mem.sv
source/cpu/rv_dmem_wrap.sv
source/cpu/rv_mem_wrap.sv

# Reference Model
verif/rv_cpu/rv32i_ref_pkg.sv
verif/rv_cpu/rv32i_ref.sv
verif/rv_cpu/rv_cpu_checker.sv

# Testbench
verif/rv_cpu/rv_cpu_tb.sv
