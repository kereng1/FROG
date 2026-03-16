# RV32I Reference Model & Checker

## Overview

The Reference Model verification system provides cycle-accurate comparison between the RTL CPU and a behavioral model. It detects bugs by comparing **non-speculative operations**: register file writes and data memory accesses.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Testbench                               │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │   RTL CPU    │     │  Reference   │     │   Checker    │    │
│  │  (rv_cpu)    │     │    Model     │     │              │    │
│  │              │     │ (rv32i_ref)  │     │              │    │
│  │  5-stage     │     │  Single-     │     │  Compares    │    │
│  │  pipeline    │     │  cycle       │     │  RF & DMEM   │    │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘    │
│         │                    │                    │             │
│         │    RF/DMEM         │    Transactions   │             │
│         └────────────────────┴───────────────────┘             │
│                              ▼                                  │
│                     PASS / FAIL Report                          │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Reference Model Package (`rv32i_ref_pkg.sv`)

Defines data structures for verification:

| Type | Description |
|------|-------------|
| `t_instr_type` | Enum of all RV32I instructions (I_ADD, I_ADDI, etc.) |
| `t_rf_write_txn` | Register file write transaction (rd, data, pc) |
| `t_dmem_write_txn` | Data memory write transaction (addr, data, byte_en) |
| `t_dmem_read_txn` | Data memory read transaction |

### 2. Reference Model (`rv32i_ref.sv`)

Behavioral RV32I CPU model:

- **Single-cycle execution** (no pipeline)
- **Full RV32I support**: All integer instructions
- **Separate memory arrays**: Own copies of IMEM and DMEM
- **Transaction outputs**: Reports every RF write and DMEM access

**Key Signals:**
```systemverilog
input  logic        run           // Enable execution
output t_rf_write_txn   rf_write_txn    // RF write info
output t_dmem_write_txn dmem_write_txn  // DMEM write info
output logic [31:0] ref_pc             // Current PC
```

### 3. Checker (`rv_cpu_checker.sv`)

Compares RTL vs Reference with pipeline delay alignment:

| Transaction Type | Pipeline Delay |
|-----------------|----------------|
| RF Writes | 4 cycles (Q100H → Q104H) |
| DMEM Writes | 3 cycles (Q100H → Q103H) |

**Features:**
- Warm-up period before checking (allows delay queues to fill)
- Per-byte comparison for DMEM writes
- Ignores x0 writes (hardwired to zero)
- Error counting and reporting

## How It Works

1. **Same Program**: Both RTL and Reference Model load identical program
2. **Parallel Execution**: Both execute on same clock
3. **Transaction Capture**: Reference model outputs expected transactions immediately
4. **Delay Alignment**: Checker delays reference transactions to match RTL pipeline timing
5. **Comparison**: At each cycle, compares delayed reference vs actual RTL outputs

## Usage

### Running the Simulation

```bash
./build/builder.py -dut rv_cpu -sim
```

### Output Format

**Per-cycle console output:**
```
C=  5 | RTL_PC=0x014 SLTI   | REF_PC=0x014 I_SLTIU  | wb_rd=x2  we=1 | err=1
```

**Error messages:**
```
ERROR [RF] @190000: PC=0x00000000 Instr=I_ADDI
  REF: x1 = 0x0000000a (10)
  RTL: x1 = 0xfffffff6 (-10) (wr_en=1)
```

**Final summary:**
```
========================================
        SIMULATION SUMMARY
========================================
  Total Cycles:      495
  RF Writes:         304
  RF Errors:         0
  DMEM Writes:       3
  DMEM Errors:       0
----------------------------------------
  STATUS: PASS - All checks passed!
========================================
```

## File List

| File | Location | Description |
|------|----------|-------------|
| `rv32i_ref_pkg.sv` | `verif/rv_cpu/` | Transaction types and enums |
| `rv32i_ref.sv` | `verif/rv_cpu/` | Behavioral reference model |
| `rv_cpu_checker.sv` | `verif/rv_cpu/` | Comparison logic |
| `rv_cpu_tb.sv` | `verif/rv_cpu/` | Testbench integration |

## What It Checks

| Check Point | Stage | What's Compared |
|-------------|-------|-----------------|
| RF Writes | Q104H | Register address, write data, write enable |
| DMEM Writes | Q103H | Address, data (per-byte), byte enables |

## Debugging Tips

1. **Check PC alignment**: REF_PC should match RTL_PC after accounting for pipeline
2. **Warm-up errors**: First 4 cycles may show issues - ignore them
3. **Sign errors**: Watch for sign-extension bugs (positive ↔ negative)
4. **Instruction decode**: Compare instruction type names (RTL vs REF)

## Limitations

- Does not check speculative operations (branch prediction)
- Does not verify instruction fetch timing
- DMEM reads are compared via RF write-back (for loads)
