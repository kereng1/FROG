# Memory Architecture

## Overview

The memory system consists of two modules:

1. **`d_mem` (Internal memory)**
   - Word-addressable memory (each word = 32 bits).  
   - Handles all reads and writes at word granularity.  
   - Supports byte enables to write only specific bytes within a word.  
   - Contains internal flip-flops (`DFF_MEM`) for synchronous read/write.

2. **`wrap_mem` (Memory wrapper)**
   - Interfaces directly with CPU.  
   - Converts CPU byte-level addresses to word-aligned addresses for `d_mem`.  
   - Supports **BYTE (8-bit), HALFWORD (16-bit), and WORD (32-bit)** accesses.
   - Calculates **byte enable signals** and **shifts write data** according to the byte offset.  
   - Aligns read data from `d_mem` and performs **sign extension** (via CPU input `is_signed`).  
   - Ensures CPU always receives correctly aligned and extended data.

## Data Flow

1. **Write Operation:**
   - CPU provides `addr`, `wr_data`, `byte_en`, and  `is_signed`.  
   - `wrap_mem` calculates:
     - Word-aligned address for `d_mem`.
     - Shifted write data according to byte offset.
     - Shifted byte enable signals.
   - `d_mem` writes the data to the memory array.

2. **Read Operation:**
   - `wrap_mem` requests the word from `d_mem` using word-aligned address.
   - Shifts the data to bring the requested byte/halfword to LSB.
   - Performs sign extension if necessary.
   - Returns `rd_data` to the CPU.


## Supported RISC-V Memory Instructions

The `wrap_mem_signed` module supports all standard memory access instructions:

| Instruction | Access Size | Signed / Unsigned | Byte Enable | Notes |
|-------------|------------|-----------------|------------|-------|
| **LB**      | Byte       | Signed           | 0001      | Loads 1 byte and sign-extends to 32-bit. `is_signed` = 1 |
| **LBU**     | Byte       | Unsigned         | 0001      | Loads 1 byte and zero-extends to 32-bit. `is_signed` = 0 |
| **LH**      | Halfword   | Signed           | 0011      | Loads 2 bytes and sign-extends to 32-bit. `is_signed` = 1 |
| **LHU**     | Halfword   | Unsigned         | 0011      | Loads 2 bytes and zero-extends to 32-bit. `is_signed` = 0 |
| **LW**      | Word       | Signed/Unsigned  | 1111      | Loads 4 bytes (full word). Sign extension is irrelevant. |
| **SB**      | Byte       | N/A (Write)      | 0001      | Stores 1 byte at the given byte offset. |
| **SH**      | Halfword   | N/A (Write)      | 0011      | Stores 2 bytes at the given byte offset. |
| **SW**      | Word       | N/A (Write)      | 1111      | Stores full 4-byte word. |

### Notes
- The `is_signed` input is provided by the CPU for LOAD instructions only.  
  - `1` → sign-extend  
  - `0` → zero-extend  
- `wrap_mem_signed` calculates the proper **byte enable mask** and **shift** based on the byte offset within the word.  
- `d_mem` handles word-aligned reads/writes; `wrap_mem_signed` manages all sub-word alignment, shifting, and extension.  
- For STORE instructions, `byte_en` is shifted according to the byte offset so that only the targeted bytes are updated in `d_mem`.  
- This ensures correct behavior for all RISC-V memory access instructions.

## Testing

To run the testbench, use the following commands in the terminal: 

### Step 1: Compile the Design

To compile all source files: from the project root directory in the terminal: /root/FPGA_BAU, run this command:

```bash
vlog -f verif/d_mem/wrap_mem_list.f
```

### Step 2: Run the Simulation

**Option A: Command-line mode (output in terminal)**

```bash
vsim -c wrap_mem_tb -do "run -all; quit -f"
```
this will open the outputs inside the terminal command line
if you want to see the waveforms in ModelSim GUI viewer, follow these steps:

This displays test results directly in the terminal and exits automatically.

**Option B: GUI mode (view waveforms)**

```bash
vsim wrap_mem_tb -do "add wave *; run -all"
```

This opens ModelSim GUI, adds all signals to the waveform window, runs the simulation, and displays waveforms.
