# AC — RISC-V RV32I CPU

SystemVerilog implementation of a 5-stage pipelined RISC-V RV32I CPU. AI-driven development with spectrum and issue-driven workflows.

## Development Workflow

**All changes follow GitHub flow.** Use the [github-flow](.cursor/skills/github-flow/SKILL.md) skill:

1. Create issue → branch → implement → commit → push → PR → gatekeeper review → merge
2. One issue per change; branch name: `{issue-number}-{short-desc}`
3. PR body must include `Fixes #N` to auto-close the issue

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `source/cpu/` | RTL: 5-stage pipeline (rv_if, rv_decode, rv_exe, rv_ma, rv_wb), rv_ctrl, rv_cpu |
| `source/common/` | rv_pkg, rv_mem, dff_macros |
| `verif/<dut>/` | Testbenches per DUT: `*_tb.sv`, `*_list.f`, reference model, checker |
| `build/` | builder.py, workflow.yaml, run_ci.py |
| `tools/` | assembler.py, machine2sv.py |
| `docs/` | Specs, component docs |

## RTL Overview

- **rv_cpu.sv**: Top-level, instantiates 5 stages and control
- **rv_ctrl.sv**: Control unit, decodes instruction and drives stage controls
- **rv_if / rv_decode / rv_exe / rv_ma / rv_wb**: Pipeline stages
- **rv_mem_wrap, rv_dmem_wrap**: Instruction and data memory interfaces

## Testbench Overview

- **`*_tb.sv`**: Top, drives clk/rst, instantiates DUT and reference
- **`*_checker.sv`**: Compares RTL vs reference (RF writes, DMEM writes)
- **rv32i_ref.sv**: Reference model for RV32I
- **`*_list.f`**: File list for compilation

## Build & CI

- `./build/builder.py -dut <name> -hw -sim` — compile and simulate
- `./build/run_ci.py` — local regression
- `.github/workflows/ci.yaml` — CI: rv_cpu, rv_memory, wrap_mem

## Roadmap (WIP)

- GCC toolchain integration
- Enhanced builders and gatekeepers
