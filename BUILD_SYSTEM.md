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

```bash
./build/run_workflow.sh compile    # Compile the design only
./build/run_workflow.sh run        # Compile and run simulation (CLI mode)
./build/run_workflow.sh run-gui    # Compile and run simulation (GUI mode)
./build/run_workflow.sh gui        # Alias for run-gui
./build/run_workflow.sh clean      # Remove generated files
./build/run_workflow.sh help       # Show help message
```

### From Any Directory

The build script automatically navigates to the project root, so it works from any location:

```bash
# From project root
./build/run_workflow.sh run

# From subdirectories (use relative or absolute path)
../../build/run_workflow.sh run
/root/FPGA_BAU/build/run_workflow.sh run
```

## Log Files

All builds create timestamped log files:
- Location: `target/logs/alu_build_YYYYMMDD_HHMMSS.log`
- Contains: Full compilation and simulation output
- Useful for: Debugging, tracking build history, troubleshooting

## Example Workflow

```bash
# Quick test run
make run
# or
./build/run_workflow.sh run

# View waveforms
make run-gui
# or
./build/run_workflow.sh run-gui

# Clean up
make clean
# or
./build/run_workflow.sh clean
```

## Benefits

1. **Time Saving**: No more manual `cd`, `vlog`, `vsim` commands
2. **Consistency**: Same workflow every time
3. **Debugging**: Timestamped logs for troubleshooting
4. **Flexibility**: Two build tools (Makefile and script) for different preferences
5. **Extensibility**: Easy to add more testbenches as project grows

## Current Configuration

- **Testbench**: ALU (`alu_tb`)
- **File List**: `verif/alu/alu_list.f`
- **Simulator**: ModelSim/QuestaSim

## Future Enhancements

- [ ] Support for multiple testbenches (register file, control unit, etc.)
- [ ] Parallel compilation for faster builds
- [ ] Integration with CI/CD pipelines
- [ ] Build configuration file for easy testbench switching


