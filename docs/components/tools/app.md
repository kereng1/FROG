# Assembly Toolchain

Two utility scripts to support the assembly-to-simulation workflow.

## Workflow

```
[.asm file] --assembler--> [.txt file (debug)] --machine2sv--> [.sv file (simulation)]
```

All output files are created in the `output_tools/` directory by default.

---

## 1. Assembler (`assembler.py`)

**Purpose:** Convert RISC-V assembly code into human-readable machine code for debugging.

| | |
|---|---|
| **Input** | `<filename>.asm` - Assembly source file containing RISC-V instructions |
| **Output** | `output_tools/<filename>.txt` - Debug-friendly text file |

### Output Format

```
<address>: <instruction_hex>
```

### Example

**Input:** `test.asm`
```asm
addi x1, x0, 10
addi x2, x0, 20
add  x3, x1, x2
```

**Output:** `output_tools/test.txt`
```
00000000: 00A00093
00000004: 01400113
00000008: 002081B3
```

### Usage

```bash
python tools/assembler.py test.asm                    # -> output_tools/test.txt
python tools/assembler.py test.asm -o custom.txt      # -> custom.txt
```

---

## 2. Machine-to-SV Converter (`machine2sv.py`)

**Purpose:** Convert the assembler output into a memory initialization file compatible with SystemVerilog's `$readmemh` function.

| | |
|---|---|
| **Input** | `<filename>.txt` - Output from assembler (address: instruction format) |
| **Output** | `output_tools/<filename>.sv` - SV-compatible memory file (little-endian bytes) |

### Example

**Input:** `output_tools/test.txt`
```
00000000: 00A00093
00000004: 01400113
00000008: 002081B3
```

**Output:** `output_tools/test.sv`
```
// Memory initialization for simulation
// Generated from machine code
// Source: test.txt
// Date: 2026-03-06 11:31:11
// Total instructions: 3

00A00093
01400113
002081B3
```

### Output Format Details

- Header comments with metadata
- One 32-bit instruction per line
- Compatible with `$readmemh` for word-addressable memory

### Usage

```bash
python tools/machine2sv.py output_tools/test.txt                  # -> output_tools/test.sv
python tools/machine2sv.py output_tools/test.txt -o load_mem.sv   # -> load_mem.sv
```

---

## Complete Workflow Example

```bash
# Step 1: Assemble
python tools/assembler.py program.asm

# Step 2: Convert to SV memory file
python tools/machine2sv.py output_tools/program.txt

# Result: output_tools/program.sv (ready for simulation)
```

## Usage in Testbench

The testbench (`verif/rv_cpu/rv_cpu_tb.sv`) loads the memory file using:

```systemverilog
$readmemh("output_tools/load_mem.sv", dut.u_rv_mem_wrap.i_mem.mem);
```

Generate `load_mem.sv` before running simulation:

```bash
python tools/assembler.py program.asm
python tools/machine2sv.py output_tools/program.txt -o output_tools/load_mem.sv
```

## Output Directory Structure

```
FROG/
├── tools/
│   ├── assembler.py
│   └── machine2sv.py
└── output_tools/          # Created automatically
    ├── program.txt        # Debug output (address: hex)
    └── program.sv         # Simulation memory file
```
