# Memory Architecture

## Overview

The memory system is encapsulated within a top-level **`memory`** module. This module serves as a unified interface, managing both the **Instruction Memory (IMEM)** and **Data Memory (DMEM)** paths within the CPU pipeline.

### Hierarchical Structure
* **`memory` (Top-Level):** The main orchestrator that handles pipeline synchronization.
    * **`i_mem` (Instruction Memory):** An instance of `d_mem` used for fetching instructions.
    * **`wrap_mem` (Data Memory Wrapper):** A logic layer that handles alignment, masking, and sign extension for data accesses.
        * **`d_mem` (Core Storage):** The actual synchronous 32-bit word-addressable memory array.



---

## Component Details

### 1. Unified Memory Controller (`memory.sv`)
The top-level module coordinates the timing between different pipeline stages:
- **IF Stage (Q100H -> Q101H):** Fetches instructions using the Program Counter (PC). It includes a reset mechanism that forces a `NOP` instruction (`0x00000013`) to ensure the pipeline starts safely.
- **MEM Stage (Q103H -> Q104H):** Manages Data Memory access. It receives the ALU result as an address and passes the output to the Write-Back stage via a pipeline register.

### 2. Memory Wrapper (`wrap_mem.sv`)
The `wrap_mem` is the "intelligence" layer of the memory system. It interfaces directly with the CPU to handle byte-level granularity while maintaining compatibility with the word-aligned `d_mem`.

**Detailed Logic & Responsibilities:**
- **Address Translation:** Converts CPU byte-level addresses to word-aligned addresses for `d_mem` by stripping the 2 LSBs (`addr[31:2]`).
- **Write Operation (Store):** - Calculates the proper **byte enable mask** based on the instruction type and address offset.
    - **Shifts write data** to the correct byte lane (e.g., for `SB`, it moves the byte to the targeted position within the 32-bit word).
- **Read Operation (Load):**
    - Requests a full word from `d_mem`.
    - **LSB Alignment:** Shifts the resulting word to bring the requested byte or halfword to the Least Significant Bit (LSB) position.
    - **Sign Extension:** Based on the `is_signed` input from the CPU:
        - **Signed (`is_signed=1`):** Performs sign-extension for `LB` and `LH` to maintain the correct value for 2's complement integers.
        - **Unsigned (`is_signed=0`):** Performs zero-extension for `LBU` and `LHU`.



### 3. Core Memory (`d_mem.sv`)
The underlying storage component:
- **Word-Addressable:** Each entry is a 32-bit word.
- **Byte Enable Mask:** A 4-bit `byte_en` signal allows the CPU to write only specific bytes within a word, essential for `SB` and `SH` instructions.
- **Synchronous Logic:** Utilizes internal flip-flops (`DFF_MEM`) for stable, clock-aligned reads and writes.

---

## Supported RISC-V Memory Instructions

| Instruction | Access Size | Signed / Unsigned | Byte Enable | Pipeline Stage | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **LB** | Byte | Signed | `0001`* | Q103H-Q104H | Sign-extends to 32 bits |
| **LBU** | Byte | Unsigned | `0001`* | Q103H-Q104H | Zero-extends to 32 bits |
| **LH** | Halfword | Signed | `0011`* | Q103H-Q104H | Sign-extends to 32 bits |
| **LHU** | Halfword | Unsigned | `0011`* | Q103H-Q104H | Zero-extends to 32 bits |
| **LW** | Word | N/A | `1111` | Q103H-Q104H | Full word load |
| **SB** | Byte | N/A | `0001`* | Q103H | Stores 1 byte |
| **SH** | Halfword | N/A | `0011`* | Q103H | Stores 2 bytes |
| **SW** | Word | N/A | `1111` | Q103H | Stores 4 bytes |

*\*Note: Byte enable masks and data positions are dynamically shifted by `wrap_mem` based on the address offset (`addr[1:0]`).*

---

## Testing & Simulation

We use a Python-based **Builder** tool to automate the design flow.

### 1. Instruction Initialization
Instructions are loaded into the `i_mem` using a "Backdoor" mechanism via a hex file:
`verif/memory/inst_mem.hex`

### 2. Running the Simulation
To compile and simulate the memory system from the project root:

```bash
 ./build/builder.py -dut memory -sim