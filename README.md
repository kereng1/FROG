## RISC-V-based FPGA system project - a complete hardware-software system with a pipelined RISC-V CPU running on an FPGA board.

## Project Overview

- A 32-bit RISC-V pipelined CPU (RV32I)
- Memory interface and basic I/O (LEDs, switches, buttons)
- UART interface for PC communication
- VGA display engine for video output
- C test programs that run on the CPU

---

## Commands to Run the Project

Replace `<component_name>` with any of the component names (e.g., `alu`, `d_mem`, `regfile`, `i_mem`, `rf`).

This will compile, simulate, and open ModelSim GUI for the selected component:

```bash
./build/run_workflow.sh <component_name> run-gui

# Compile only (no simulation)
./build/run_workflow.sh <component_name> compile

# Clean generated files
./build/run_workflow.sh <component_name> clean

# Show help message
./build/run_workflow.sh help
```

You can also use `compile` (compile only), `run` (simulate without GUI), or `clean` (remove generated files) as needed.

### Component Requirements

For the script to work with a component, ensure:
- Directory exists: `verif/<component_name>/`
- List file exists: `verif/<component_name>/<component_name>_list.f`
- Testbench module is named: `<component_name>_tb`

## Project Components

- **32-bit RISC-V pipelined CPU** (RV32I, 5-stage pipeline)
- **Memory interface** and basic I/O (LEDs, switches, buttons)
- **UART interface** for PC communication
- **VGA display engine** for video output
- **C test programs** that run on the CPU

## Repository Structure

```
FPGA_BAU/
├── source/          # RTL source files
├── verif/           # Testbenches
├── software/        # C test programs
├── build/           # Build scripts
└── target/          # Generated files (logs, waves, etc.)
```

## Project Status

| Component        | Status        |
|-----------------|---------------|
| CPU Design       | 🟡 In progress|
| FPGA Deployment  | ⏳ Pending    |
| UART Interface   | ⏳ Pending    |
| VGA Engine       | ⏳ Pending    |

## Technologies

- **HDL**: SystemVerilog
- **ISA**: RISC-V RV32I
- **Tools**: ModelSim, Make
