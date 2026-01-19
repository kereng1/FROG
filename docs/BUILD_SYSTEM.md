# Build System Overview

This project uses a generic **Python + YAML** build system designed for flexibility and automation. It supports automated compilation, simulation, logging, and CI pipelines.

## 🚀 Usage

The build script is located at `build/builder.py`.

```bash
./build/builder.py -dut <component> [flags]
```

### Flags

| Flag | Description | Stage |
| :--- | :--- | :--- |
| `-dut <name>` | **Required**. Device Under Test (e.g., `alu`, `pc`). | N/A |
| `-hw` | Compile SystemVerilog sources. | `hw` |
| `-sim` | Run simulation (CLI mode). | `sim` |
| `-debug` | Run simulation with GUI (view waveforms). | `debug` |
| `-clean` | Clean build artifacts for the DUT. | `clean` |
| `-v` | Enable verbose output. | N/A |

### Examples

```bash
# Compile and run simulation for ALU
./build/builder.py -dut alu -hw -sim

# Compile only
./build/builder.py -dut pc -hw

# Open GUI to debug waveforms
./build/builder.py -dut rf -hw -debug

# Clean artifacts
./build/builder.py -dut alu -clean
```

---

## 📂 Configuration (`build/workflow.yaml`)

The entire build process is defined in `build/workflow.yaml`. You can easily add new stages without modifying the Python script.

```yaml
stages:
  hw:
    description: "Compile SystemVerilog sources"
    requires_dut: true
    dependencies:
      - init
    commands:
      - 'vlog -sv ...'
```

**Key Features:**
- **Dynamic CLI:** New stages automatically appear as flags (e.g., adding a `lint` stage adds a `-lint` flag).
- **Dependency Resolution:** Automatically runs required prerequisites (e.g., `-sim` runs `-hw` first).
- **Variables:** Supports dynamic paths like `{dut_dir}`, `{logs_dir}`, etc.

---

## 📝 Logging

Build artifacts and logs are stored per-DUT in `target/<dut>/`.

**Structure:**
```text
target/
  ├── alu/
  │   ├── logs/
  │   │   ├── build_20251208_130000/
  │   │   │   ├── build.log       # Full build trace
  │   │   │   ├── compile.log     # Compiler output (vlog)
  │   │   │   └── transcript.log  # Simulator output (vsim)
  │   │   └── build_latest/       # Symlink to latest build dir
  │   └── work/                   # Compiled library
```

At the end of a run, the script prints the path to the main log file.

---

## 🤖 CI/Regression

A local CI script is provided to run all tests defined in the GitHub Actions workflow (`.github/workflows/ci.yaml`).

```bash
./build/run_ci.py
```

This runs all IP simulations in parallel (conceptually) and provides a live status dashboard in the terminal:

```text
✓ PASS  Build & Sim - ALU         → .../build_latest/build.log
✓ PASS  Build & Sim - PC          → .../build_latest/build.log
✗ FAIL  Build & Sim - RV_IF       → .../build_latest/build.log
```

---

## 🏗 Directory Structure

* **`build/`**: Build scripts and configuration.
  * `builder.py`: Generic build executor.
  * `workflow.yaml`: Build configuration.
  * `run_ci.py`: Local regression runner.
* **`verif/<dut>/`**: Verification environment for each component.
  * `<dut>_list.f`: File list for compilation.
  * `<dut>_tb.sv`: Testbench top module.
* **`target/<dut>/`**: Generated output (logs, waveforms, compiled libs).
