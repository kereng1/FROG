# Build System Implementation

## Overview

Implemented an automated build system for the MIPS CPU Pipeline project to streamline compilation and simulation workflows. The system provides two complementary build tools: a Makefile and a shell script with timestamped logging.

## Features

### ✅ Automated Compilation
- Single command compilation of all source files
- Automatic dependency handling via file lists
- Clear error reporting and status messages

### ✅ Simulation Modes
- **CLI Mode**: Quick test runs with output in terminal
- **GUI Mode**: Interactive ModelSim GUI with waveform viewing

### ✅ Logging & Debugging
- Timestamped log files for each build
- All compilation and simulation output captured
- Easy troubleshooting with detailed logs in `target/logs/`

### ✅ Clean Targets
- Remove generated files (work/, transcript, VCD files)
- Clean all simulation artifacts

## Files Created

1. **`Makefile`** - Standard build automation
   - Location: Project root
   - Standard make targets for hardware projects

2. **`build/run_workflow.sh`** - Build script with logging
   - Location: `build/run_workflow.sh`
   - Timestamped logging to `target/logs/`
   - Colored output and error handling

## Usage

### Using Makefile

```bash
make compile    # Compile the design only
make run        # Compile and run simulation (CLI mode)
make run-gui    # Compile and run simulation (GUI mode with waveforms)
make clean      # Remove work directory and generated files
make clean-all  # Remove all simulation artifacts including VCD files
make help       # Show help message
```

### Using Build Script

The build script supports multiple components. Specify the component name as the first argument:

```bash
./build/run_workflow.sh <component_name> compile    # Compile the design only
./build/run_workflow.sh <component_name> run        # Compile and run simulation (CLI mode)
./build/run_workflow.sh <component_name> run-gui    # Compile and run simulation (GUI mode)
./build/run_workflow.sh <component_name> gui        # Alias for run-gui
./build/run_workflow.sh <component_name> clean      # Remove generated files
./build/run_workflow.sh help                         # Show help message
```

**Examples:**
```bash
./build/run_workflow.sh alu run        # Build and run ALU testbench
./build/run_workflow.sh alu run-gui    # View ALU waveforms in GUI
./build/run_workflow.sh d_mem compile  # Compile d_mem only
./build/run_workflow.sh regfile run    # Build and run register file testbench
```

### From Any Directory

The build script automatically navigates to the project root, so it works from any location:

```bash
# From project root
./build/run_workflow.sh alu run

# From subdirectories (use relative or absolute path)
../../build/run_workflow.sh alu run
/root/FPGA_BAU/build/run_workflow.sh alu run
```

## Log Files

All builds create timestamped log files:
- Location: `target/logs/<component_name>_build_YYYYMMDD_HHMMSS.log`
- Contains: Full compilation and simulation output
- Useful for: Debugging, tracking build history, troubleshooting

Example: `target/logs/alu_build_20251125_152251.log`

## Example Workflow

```bash
# Quick test run
make run
# or
./build/run_workflow.sh alu run

# View waveforms
make run-gui
# or
./build/run_workflow.sh alu run-gui

# Clean up
make clean
# or
./build/run_workflow.sh alu clean
```

## Benefits

1. **Time Saving**: No more manual `cd`, `vlog`, `vsim` commands
2. **Consistency**: Same workflow every time
3. **Debugging**: Timestamped logs for troubleshooting
4. **Flexibility**: Two build tools (Makefile and script) for different preferences
5. **Extensibility**: Easy to add more testbenches as project grows

## Multi-Component Support

The build script now supports multiple components. For each component, the script automatically:
- Constructs the list file path: `verif/<component_name>/<component_name>_list.f`
- Expects testbench module: `<component_name>_tb`
- Creates component-specific log files and transcripts

### Component Requirements

To add a new component:
1. Create directory: `verif/<component_name>/`
2. Create list file: `verif/<component_name>/<component_name>_list.f`
3. Ensure testbench module is named: `<component_name>_tb`

### Available Components

- **ALU**: `./build/run_workflow.sh alu run`
- **d_mem**: `./build/run_workflow.sh d_mem run`
- Additional components can be added following the same structure

## Current Configuration

- **Simulator**: ModelSim/QuestaSim
- **Work Directory**: `target/work/` (shared across all components)
- **Logs**: `target/logs/<component_name>_build_*.log`
- **Transcripts**: `target/<component_name>_transcript`
- **Waveforms**: `target/<component_name>_vsim.wlf`

## Future Enhancements

- [x] Support for multiple testbenches (register file, control unit, etc.)
- [ ] Parallel compilation for faster builds
- [ ] Integration with CI/CD pipelines
- [ ] Build configuration file for custom testbench naming


