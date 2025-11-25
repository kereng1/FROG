#!/bin/bash
# Simple ALU build + simulate script with timestamped logging

# Move to project root (script is in build/, so go up one directory)
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Create target directories
mkdir -p target/logs
mkdir -p target/work

# Create timestamp and logfile
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOG_FILE="$PROJECT_ROOT/target/logs/alu_build_$TIMESTAMP.log"

# Configuration
TB_NAME="alu_tb"
TB_LIST="verif/alu/alu_list.f"
WORK_DIR="$PROJECT_ROOT/target/work"
TRANSCRIPT="$PROJECT_ROOT/target/transcript"
WLF_FILE="$PROJECT_ROOT/target/vsim.wlf"

# Function to log and display
log_and_display() {
    echo "$1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------
# STEP 1: Compile ALU
# -----------------------------------------------------------
compile() {
    log_and_display "=== ALU Build & Simulation ==="
    log_and_display "Project root: $PROJECT_ROOT"
    log_and_display "Log file: $LOG_FILE"
    log_and_display ""
    
    log_and_display "[1/2] Compiling ALU sources with vlog..."
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
# STEP 2: Simulate ALU testbench (CLI mode)
# -----------------------------------------------------------
run_cli() {
    compile
    
    log_and_display "[2/2] Running ALU testbench with vsim (CLI mode)..."
    vsim -c -work "$WORK_DIR" -l "$TRANSCRIPT" -wlf "$WLF_FILE" "$TB_NAME" -do "run -all; quit -f" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log_and_display "❌ Simulation FAILED"
        log_and_display "Check the log file: $LOG_FILE"
        exit 1
    fi
    
    log_and_display "✔ Simulation SUCCESS"
    log_and_display ""
    log_and_display "=== ALU Build Completed Successfully ==="
    log_and_display "Full log: $LOG_FILE"
}

# -----------------------------------------------------------
# STEP 2: Simulate ALU testbench (GUI mode)
# -----------------------------------------------------------
run_gui() {
    compile

    log_and_display "[2/2] Running ALU testbench with vsim (GUI mode)..."
    log_and_display "Opening ModelSim GUI with waveforms..."
    log_and_display ""

    # Run GUI mode, capture output to logfile
    vsim -work "$WORK_DIR" -l "$TRANSCRIPT" -wlf "$WLF_FILE" "$TB_NAME" -do "add wave *; run -all; quit -f" >> "$LOG_FILE" 2>&1 &

    # Allow GUI to start properly
    sleep 1

    log_and_display "✔ Simulation started (GUI mode)"
    log_and_display "Console output will appear in: $LOG_FILE"
}

# -----------------------------------------------------------
# Clean generated files
# -----------------------------------------------------------
clean() {
    log_and_display "Cleaning generated files..."
    # Clean old files in project root (for backward compatibility)
    rm -rf work/
    rm -f transcript vsim.wlf
    rm -f *.vcd
    # Clean all target directory contents (work library, transcript, waveform files, etc.)
    rm -rf target/work
    rm -f target/transcript target/vsim.wlf target/*.wlf
    rm -f target/*.vcd
    # Note: Logs in target/logs are preserved. To remove everything including logs, delete target/ manually
    log_and_display "✔ Clean complete!"
}

# -----------------------------------------------------------
# Main script logic
# -----------------------------------------------------------
case "${1:-help}" in
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
        echo "Usage: ./build/run_workflow.sh [command]"
        echo ""
        echo "Commands:"
        echo "  compile    - Compile the design only"
        echo "  run        - Compile and run simulation (CLI mode)"
        echo "  run-gui    - Compile and run simulation (GUI mode)"
        echo "  gui        - Alias for run-gui"
        echo "  clean      - Remove generated files"
        echo "  help       - Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./build/run_workflow.sh run        # Quick test run"
        echo "  ./build/run_workflow.sh run-gui    # View waveforms"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './build/run_workflow.sh help' for usage information"
        exit 1
        ;;
esac

exit 0
