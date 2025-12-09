# RISC-V CPU Documentation

This folder contains the documentation for the **rv_cpu** module — a 5-stage pipelined RISC-V processor implementation.

## Architecture Overview

The CPU implements a classic 5-stage pipeline with the following stages:

```
┌──────────┐    ┌───────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  rv_if   │───▶│ rv_decode │───▶│  rv_exe  │───▶│  rv_ma   │───▶│  rv_wb   │
│ (Fetch)  │    │ (Decode)  │    │(Execute) │    │ (Memory) │    │(WriteBack)│
│  Q100H   │    │  Q101H    │    │  Q102H   │    │  Q103H   │    │  Q104H   │
└────┬─────┘    └─────┬─────┘    └──────────┘    └────┬─────┘    └────┬─────┘
     │                │                              │               │
     │                │                              │               │
     ▼                │                              ▼               │
┌──────────┐          │                         ┌────────────┐       │
│  I_MEM   │──────────┘                         │ wrap_mem   │───────┘
│(Instruct)│                                    │  (D_MEM)   │
└──────────┘                                    └─────┬──────┘
                                                      │
                                                ┌─────▼──────┐
                                                │   d_mem    │
                                                │(Memory Arr)│
                                                └────────────┘
                              ┌───────────────┐
                              │    rv_ctrl    │
                              │(Control Unit) │
                              └───────────────┘
```

## Pipeline Stage Naming Convention

The pipeline uses a timing notation `Q1xxH` where:
- **Q100H** — Instruction Fetch stage (cycle 0)
- **Q101H** — Decode stage (cycle 1)
- **Q102H** — Execute stage (cycle 2)
- **Q103H** — Memory Access stage (cycle 3)
- **Q104H** — Write Back stage (cycle 4)

---

## Module Descriptions

### 1. `rv_if.sv` — Instruction Fetch Stage (Q100H)

**Purpose:** Fetches instructions from instruction memory and manages the program counter.

**Key Responsibilities:**
- Sends the Program Counter (PC) to instruction memory (`I_MEM`)
- Computes `PC + 4` for sequential instruction fetching
- Selects next PC based on control signals (branch/jump targets from ALU or sequential PC+4)

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `rst` | Input | 1 | Reset signal |
| `alu_out_Q102H` | Input | 32 | Branch/jump target address from execute stage |
| `ctrl` | Input | `t_if_ctrl` | Control signals for IF stage |
| `pc_Q100H` | Output | 32 | Current program counter |
| `pc_Q101H` | Output | 32 | Program counter passed to decode stage |

**Control Signals:**
- `sel_next_pc_alu_out_Q102H` — Selects ALU output as next PC (for branches/jumps)
- `ready_Q100H` / `ready_Q101H` — Pipeline enable signals

---

### 2. `rv_decode.sv` — Decode Stage (Q101H)

**Purpose:** Decodes instructions and reads register file values.

**Status:** 🚧 *Not yet implemented*

**Expected Responsibilities:**
- Instruction decoding
- Register file read operations
- Immediate value extraction
- Control signal generation

---

### 3. `rv_exe.sv` — Execute Stage (Q102H)

**Purpose:** Performs arithmetic/logic operations and evaluates branch conditions.

**Key Responsibilities:**
- ALU operations (ADD, SUB, SLT, SLTU, SLL, SRL, SRA, XOR, OR, AND)
- Branch condition evaluation (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- Data hazard detection and forwarding

**ALU Operations:**
| Operation | Description |
|-----------|-------------|
| `ALU_ADD` | Addition |
| `ALU_SUB` | Subtraction |
| `ALU_SLT` | Set Less Than (signed) |
| `ALU_SLTU` | Set Less Than (unsigned) |
| `ALU_SLL` | Shift Left Logical |
| `ALU_SRL` | Shift Right Logical |
| `ALU_SRA` | Shift Right Arithmetic |
| `ALU_XOR` | Bitwise XOR |
| `ALU_OR` | Bitwise OR |
| `ALU_AND` | Bitwise AND |

**Branch Conditions:**
| Condition | Description |
|-----------|-------------|
| `BRANCH_COND_BEQ` | Branch if Equal |
| `BRANCH_COND_BNE` | Branch if Not Equal |
| `BRANCH_COND_BLT` | Branch if Less Than (signed) |
| `BRANCH_COND_BGE` | Branch if Greater or Equal (signed) |
| `BRANCH_COND_BLTU` | Branch if Less Than (unsigned) |
| `BRANCH_COND_BGEU` | Branch if Greater or Equal (unsigned) |

**Forwarding Unit:**
The module includes hazard detection for data forwarding:
- Detects RAW (Read After Write) hazards between Q102H and Q103H/Q104H stages
- Forwards write-back data from later stages when hazards are detected

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `rst` | Input | 1 | Reset signal |
| `ctrl` | Input | `t_exe_ctrl` | Control signals |
| `pc_Q102H` | Input | 32 | Program counter |
| `reg_data1_Q102H` | Input | 32 | Register source 1 data |
| `reg_data2_Q102H` | Input | 32 | Register source 2 data |
| `imm_Q102H` | Input | 32 | Immediate value |
| `wb_data_Q103H` | Input | 32 | Write-back data from MA stage (forwarding) |
| `wb_data_Q104H` | Input | 32 | Write-back data from WB stage (forwarding) |
| `branch_cond_met_Q102H` | Output | 1 | Branch condition result |
| `pc_plus4_Q103H` | Output | 32 | PC+4 for JAL/JALR |
| `alu_out_Q103H` | Output | 32 | ALU result |
| `dmem_wr_data_Q103H` | Output | 32 | Data memory write data |

---

### 4. `rv_ma.sv` — Memory Access Stage (Q103H)

**Purpose:** Handles data memory reads (LOAD) and writes (STORE).

**Key Responsibilities:**
- Generates memory request signals (`core2dmem_req`)
- Selects write-back data source (ALU result or PC+4)

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `rst` | Input | 1 | Reset signal |
| `ctrl` | Input | `t_ma_ctrl` | Control signals |
| `pc_plus4_Q103H` | Input | 32 | PC+4 from execute stage |
| `alu_out_Q103H` | Input | 32 | ALU result (memory address) |
| `dmem_wr_data_Q103H` | Input | 32 | Data to write to memory |
| `core2dmem_req_Q103H` | Output | `t_core2mem_req` | Memory request interface |
| `pre_wb_data_Q104H` | Output | 32 | Pre-selected write-back data |

**Memory Request Interface (`t_core2mem_req`):**
- `wr_data` — Write data
- `address` — Memory address
- `wr_en` — Write enable
- `rd_en` — Read enable
- `byte_en` — Byte enable mask

---

### 5. `rv_wb.sv` — Write Back Stage (Q104H)

**Purpose:** Selects final write-back data and writes to register file.

**Key Responsibilities:**
- Multiplexes between memory read data and ALU/PC result
- Provides final write-back data to register file

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `rst` | Input | 1 | Reset signal |
| `ctrl` | Input | `t_wb_ctrl` | Control signals |
| `pre_wb_data_Q104H` | Input | 32 | Data from MA stage |
| `dmem_rd_data_Q104H` | Input | 32 | Data read from memory |
| `wb_data_Q104H` | Output | 32 | Final write-back data |

**Write-back Source Selection:**
- `SEL_WR_DATA` — Use pre-computed write-back data (ALU result or PC+4)
- `SEL_DMEM_RD_DATA` — Use data memory read result (for LOAD instructions)

---

### 6. `rv_ctrl.sv` — Control Unit

**Purpose:** Central control unit that generates control signals for all pipeline stages.

**Status:** 🚧 *Skeleton only — implementation in progress*

**Expected Responsibilities:**
- Instruction decoding and control signal generation
- Pipeline stall and flush control
- Hazard management coordination

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `rst` | Input | 1 | Reset signal |
| `instruction_Q101H` | Input | 32 | Decoded instruction |
| `branch_cond_met_Q102H` | Input | 1 | Branch condition from EXE |
| `if_ctrl` | Output | `t_if_ctrl` | IF stage control signals |
| `decode_ctrl` | Output | `t_decode_ctrl` | Decode stage control signals |
| `exe_ctrl` | Output | `t_exe_ctrl` | EXE stage control signals |
| `mem_ctrl` | Output | `t_mem_ctrl` | MA stage control signals |
| `wb_ctrl` | Output | `t_wb_ctrl` | WB stage control signals |

---

### 7. `rv_cpu.sv` — Top-Level Module

**Purpose:** Top-level module that instantiates and interconnects all pipeline stages.

**Status:** 🚧 *Not yet implemented*

**Expected Responsibilities:**
- Instantiate all pipeline stage modules
- Connect pipeline stages together
- Interface with instruction and data memories

---

## Memory Modules

The CPU interfaces with two memory subsystems: **Instruction Memory (I_MEM)** and **Data Memory (D_MEM)**. The memory modules are located in `source/d_mem/`.

### 8. `d_mem.sv` — Low-Level Memory Array

**Location:** `source/d_mem/d_mem.sv`

**Purpose:** Low-level 32-bit synchronous memory array with byte-enable support.

**Key Features:**
- Configurable memory size (default: 256 words)
- Byte-granular write operations via `byte_en` mask
- Synchronous write, combinational read
- Implemented using D flip-flops macro (`DFF_MEM`)

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `MEM_SIZE_WORDS` | 256 | Number of 32-bit words in memory |

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `addr` | Input | 32 | Word address |
| `wr_en` | Input | 1 | Write enable |
| `wr_data` | Input | 32 | Data to write |
| `byte_en` | Input | 4 | Byte enable mask (one bit per byte) |
| `rd_data` | Output | 32 | Read data |

**Byte Enable Encoding:**
| `byte_en` | Operation |
|-----------|-----------|
| `4'b0001` | Byte 0 (bits 7:0) |
| `4'b0010` | Byte 1 (bits 15:8) |
| `4'b0100` | Byte 2 (bits 23:16) |
| `4'b1000` | Byte 3 (bits 31:24) |
| `4'b0011` | Halfword (bits 15:0) |
| `4'b1111` | Full word (bits 31:0) |

---

### 9. `wrap_mem.sv` — Data Memory Wrapper (D_MEM)

**Location:** `source/d_mem/wrap_mem.sv`

**Purpose:** High-level memory wrapper that provides byte/halfword/word access with proper alignment and sign/zero extension for LOAD operations.

**Key Features:**
- Wraps the low-level `d_mem` module
- Handles byte-level addressing (CPU provides byte address)
- Automatic byte-lane shifting for unaligned accesses
- Sign extension or zero extension for LOAD operations (LB, LBU, LH, LHU, LW)
- Supports RISC-V LOAD/STORE instructions

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `MEM_SIZE_BYTES` | 1024 | Total memory size in bytes |
| `MEM_SIZE_WORDS` | MEM_SIZE_BYTES/4 | Number of 32-bit words (auto-computed) |

**Ports:**
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `addr` | Input | 32 | Byte-level address from CPU |
| `wr_data` | Input | 32 | Data to write |
| `wr_en` | Input | 1 | Write enable |
| `is_signed` | Input | 1 | Sign extension control (1=sign, 0=zero) |
| `byte_en` | Input | 4 | Access size mask |
| `rd_data` | Output | 32 | Read data (sign/zero extended) |

**RISC-V Load/Store Support:**
| Instruction | `byte_en` | `is_signed` | Description |
|-------------|-----------|-------------|-------------|
| LB | `4'b0001` | 1 | Load Byte (sign-extended) |
| LBU | `4'b0001` | 0 | Load Byte Unsigned |
| LH | `4'b0011` | 1 | Load Halfword (sign-extended) |
| LHU | `4'b0011` | 0 | Load Halfword Unsigned |
| LW | `4'b1111` | - | Load Word |
| SB | `4'b0001` | - | Store Byte |
| SH | `4'b0011` | - | Store Halfword |
| SW | `4'b1111` | - | Store Word |

**Address Handling:**
- `addr[1:0]` — Byte offset within word (used for alignment)
- `addr[31:2]` — Word address (passed to `d_mem`)

---

### 10. Instruction Memory (I_MEM)

**Purpose:** Stores program instructions fetched by the IF stage.

**Implementation Notes:**
- The I_MEM can use the same `d_mem` module as the data memory
- Typically read-only during execution (no write enable from CPU)
- Addressed by the Program Counter (`pc_Q100H`) from `rv_if`
- Returns 32-bit instructions to the decode stage

**Interface with rv_if:**
```
rv_if (Q100H)          I_MEM
    │                    │
    │  pc_Q100H ────────▶│ addr
    │                    │
    │  instruction ◀─────│ rd_data
    │                    │
```

---

## Block Diagram

See `rv_cpu.drawio` for the visual block diagram of the CPU architecture.

## Dependencies

All modules depend on:
- `pkg::*` — Package containing type definitions and enumerations
- `dff_macros.svh` — DFF (D Flip-Flop) macros for pipeline registers

## Data Hazard Handling

The CPU uses **data forwarding** (bypassing) to handle RAW hazards:
1. Hazard detection compares source registers in EXE stage with destination registers in MA/WB stages
2. When a hazard is detected, the forwarding mux selects the most recent write-back data
3. Priority: Q103H (MA stage) > Q104H (WB stage) > Register file

## File Summary

### CPU Pipeline Modules (`source/cpu/`)

| File | Stage | Status | Description |
|------|-------|--------|-------------|
| `rv_if.sv` | Q100H | ✅ Complete | Instruction Fetch |
| `rv_decode.sv` | Q101H | 🚧 Pending | Instruction Decode |
| `rv_exe.sv` | Q102H | ✅ Complete | Execute |
| `rv_ma.sv` | Q103H | ✅ Complete | Memory Access |
| `rv_wb.sv` | Q104H | ✅ Complete | Write Back |
| `rv_ctrl.sv` | — | 🚧 Skeleton | Control Unit |
| `rv_cpu.sv` | — | 🚧 Pending | Top-Level Module |

### Memory Modules (`source/d_mem/`)

| File | Status | Description |
|------|--------|-------------|
| `d_mem.sv` | ✅ Complete | Low-level 32-bit memory array with byte-enable |
| `wrap_mem.sv` | ✅ Complete | Memory wrapper with alignment & sign extension |

