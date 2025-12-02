#!/bin/bash
# Generic component build + simulate script with timestamped logging
# Usage: ./build/run_workflow.sh <component_name> [command]

# Move to project root (script is in build/, so go up one directory)
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Create target directories
mkdir -p target/logs
mkdir -p target/work

# Check if first argument is help (special case - show help without component name)
if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
    echo "MIPS CPU Pipeline - Build Script"
    echo "================================="
    echo ""
    echo "Usage: ./build/run_workflow.sh <component_name> [command]"
    echo ""
    echo "Arguments:"
    echo "  component_name  - Name of the component to build/simulate (e.g., alu, d_mem, regfile)"
    echo ""
    echo "Commands:"
    echo "  compile         - Compile the design only"
    echo "  run             - Compile and run simulation (CLI mode)"
    echo "  run-gui         - Compile and run simulation (GUI mode)"
    echo "  gui             - Alias for run-gui"
    echo "  clean           - Remove generated files"
    echo "  help            - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./build/run_workflow.sh alu run        # Build and run ALU testbench"
    echo "  ./build/run_workflow.sh alu run-gui    # Build and run ALU with GUI"
    echo "  ./build/run_workflow.sh d_mem compile  # Compile d_mem only"
    echo "  ./build/run_workflow.sh regfile run    # Build and run register file testbench"
    echo ""
    echo "Note: List files should be located at: verif/<component_name>/<component_name>_list.f"
    echo "      Testbench module should be named: <component_name>_tb"
    exit 0
fi

# Get component name from first argument (required)
COMPONENT_NAME="${1}"
shift

# Create timestamp and logfile
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOG_FILE="$PROJECT_ROOT/target/logs/${COMPONENT_NAME}_build_$TIMESTAMP.log"

# Configuration - construct paths based on component name
# List file path: verif/<component>/<component>_list.f
TB_LIST="$PROJECT_ROOT/verif/${COMPONENT_NAME}/${COMPONENT_NAME}_list.f"
# Testbench name: <component>_tb
TB_NAME="${COMPONENT_NAME}_tb"
WORK_DIR="$PROJECT_ROOT/target/work"
TRANSCRIPT="$PROJECT_ROOT/target/${COMPONENT_NAME}_transcript"
WLF_FILE="$PROJECT_ROOT/target/${COMPONENT_NAME}_vsim.wlf"

# Function to log and display
log_and_display() {
    echo "$1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------
# STEP 1: Compile Component
# -----------------------------------------------------------
compile() {
    log_and_display "=== ${COMPONENT_NAME^^} Build & Simulation ==="
    log_and_display "Component: $COMPONENT_NAME"
    log_and_display "Project root: $PROJECT_ROOT"
    log_and_display "Log file: $LOG_FILE"
    log_and_display ""
    
    # Check if list file exists
    if [ ! -f "$TB_LIST" ]; then
        log_and_display "❌ Error: List file not found: $TB_LIST"
        log_and_display "Please ensure the list file exists for component '$COMPONENT_NAME'"
        exit 1
    fi
    
    log_and_display "[1/2] Compiling $COMPONENT_NAME sources with vlog..."
    # Remove old compiled module to ensure fresh compilation when source files change
    if [ -d "$WORK_DIR" ]; then
        vdel -lib "$WORK_DIR" "$TB_NAME" -quiet >> "$LOG_FILE" 2>&1 || true
    fi
    vlog -sv -work "$WORK_DIR" -f "$TB_LIST" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log_and_display "❌ Compilation FAILED"
        log_and_display "Check the log file: $LOG_FILE"
        exit 1
    fi
    
    log_and_display "✔ Compilation SUCCESS"
    log_and_display ""
}

# -----------------------------------------------------------
# STEP 2: Simulate Component testbench (CLI mode)
# -----------------------------------------------------------
run_cli() {
    compile
    
    log_and_display "[2/2] Running $COMPONENT_NAME testbench with vsim (CLI mode)..."
    vsim -c -work "$WORK_DIR" -l "$TRANSCRIPT" -wlf "$WLF_FILE" "$TB_NAME" -do "run -all; quit -f" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log_and_display "❌ Simulation FAILED"
        log_and_display "Check the log file: $LOG_FILE"
        exit 1
    fi
    
    log_and_display "✔ Simulation SUCCESS"
    log_and_display ""
    log_and_display "=== ${COMPONENT_NAME^^} Build Completed Successfully ==="
    log_and_display "Full log: $LOG_FILE"
}

# -----------------------------------------------------------
# STEP 2: Simulate Component testbench (GUI mode)
# -----------------------------------------------------------
run_gui() {
    compile

    log_and_display "[2/2] Running $COMPONENT_NAME testbench with vsim (GUI mode)..."
    log_and_display "Opening ModelSim GUI with waveforms..."
    log_and_display ""

    # Run GUI mode - add waves and run simulation, but keep GUI open
    vsim -work "$WORK_DIR" -l "$TRANSCRIPT" -wlf "$WLF_FILE" "$TB_NAME" -do "add wave *; run -all" >> "$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then
        log_and_display "❌ Simulation FAILED"
        log_and_display "Check the log file: $LOG_FILE"
        exit 1
    fi

    log_and_display "✔ Simulation completed (GUI remains open)"
    log_and_display "Console output: $LOG_FILE"
}

# -----------------------------------------------------------
# Clean generated files
# -----------------------------------------------------------
clean() {
    log_and_display "Cleaning generated files..."
    # Clean old files in project root (for backward compatibility)
    rm -rf work/
    rm -f transcript vsim.wlf
    # Clean all target directory contents (work library, transcript, waveform files, etc.)
    rm -rf target/work
    rm -f target/*_transcript target/*_vsim.wlf target/*.wlf
    # Also clean legacy files if they exist
    rm -f target/transcript target/vsim.wlf
    # Clean all log files
    rm -f target/logs/*.log
    log_and_display "✔ Clean complete! (Removed work files, transcripts, waveforms, and logs)"
}

# -----------------------------------------------------------
# Main script logic
# -----------------------------------------------------------
# Get command (first argument after component name, or default to 'help')
COMMAND="${1:-help}"

case "$COMMAND" in
    compile)
        compile
        ;;
    run)
        run_cli
        ;;
    run-gui|gui)
        run_gui
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        echo "MIPS CPU Pipeline - Build Script"
        echo "================================="
        echo ""
        echo "Usage: ./build/run_workflow.sh <component_name> [command]"
        echo ""
        echo "Component: $COMPONENT_NAME"
        echo ""
        echo "Commands:"
        echo "  compile         - Compile the design only"
        echo "  run             - Compile and run simulation (CLI mode)"
        echo "  run-gui         - Compile and run simulation (GUI mode)"
        echo "  gui             - Alias for run-gui"
        echo "  clean           - Remove generated files"
        echo "  help            - Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./build/run_workflow.sh $COMPONENT_NAME run        # Build and run testbench"
        echo "  ./build/run_workflow.sh $COMPONENT_NAME run-gui    # Build and run with GUI"
        echo "  ./build/run_workflow.sh $COMPONENT_NAME compile    # Compile only"
        echo ""
        echo "Note: List files should be located at: verif/<component_name>/<component_name>_list.f"
        echo "      Testbench module should be named: <component_name>_tb"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Run './build/run_workflow.sh <component_name> help' for usage information"
        exit 1
        ;;
esac

exit 0
