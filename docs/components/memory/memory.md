# Memory Subsystem Documentation

This document describes the memory subsystem used in the RV32 pipeline implementation.
The design follows a clear separation between:
- A **generic raw memory model**
- A **data-memory wrapper with load/store semantics**
- A **top-level memory wrapper instantiating instruction and data memories**

---

## Overview

The memory subsystem is composed of three main modules:

rv_mem_wrap  
├── i_mem        : rv_mem        (Instruction Memory)  
└── u_dmem_wrap  : rv_dmem_wrap  
------└── u_dmem   : rv_mem        (Data Memory)



Both instruction memory and data memory are implemented using the same low-level
memory module (`rv_mem`), while higher-level behavior is implemented using wrappers.

---

## 1. `rv_mem` – Raw Memory Model

### Description
`rv_mem` is a **generic synchronous 32-bit memory array**.
It represents the lowest-level memory primitive in the system.

This module is **agnostic to instruction/data semantics**.

### Key Characteristics
- Word-addressed memory (`addr` is a word index)
- Byte-enable support for partial writes
- Synchronous write
- **Synchronous read** (read data is registered)
- Implemented using DFF macros (`DFF_MEM`, `DFF`)

### Interface
- `wr_en` controls write operation
- `byte_en` selects which bytes within a word are updated
- `rd_data` is returned one cycle later

### Usage
`rv_mem` module is used as the underlying memory primitive.
It is instantiated:
- Once as **instruction memory**
- Once as **data memory (via a wrapper)**

---

## 2. `rv_dmem_wrap` – Data Memory Wrapper

### Description
`rv_dmem_wrap` implements **RISC-V load/store semantics** on top of `rv_mem`.

It converts byte-addressed CPU requests into word-based memory accesses and
handles all alignment and extension logic.

### Pipeline Timing
- **Q103H**: Memory request (address, write data, control)
- **Q104H**: Read data returned

### Responsibilities

#### Address Handling
- Converts byte address → word address
- Extracts byte offset within word

#### Write Path (Q103H)
- Shifts `byte_en` according to byte offset
- Aligns write data to correct byte lanes
- Supports:
  - SB (store byte)
  - SH (store halfword)
  - SW (store word)

#### Read Path (Q104H)
- Masks valid bytes
- Aligns data to LSB
- Performs sign or zero extension

### Supported RISC-V Memory Instructions

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

*\*Note: Byte enable masks and data positions are dynamically shifted by `rv_dmem_wrap` based on the address offset (`addr[1:0]`).*


### Notes
- Internally instantiates `rv_mem`
- Assumes `rv_mem` provides registered read data

---

## 3. `rv_mem_wrap` – Top-Level Memory Wrapper

### Description
`rv_mem_wrap` is the **memory stage of the pipeline**.
It instantiates both instruction memory and data memory.

### Instruction Memory (`i_mem`)
- Implemented using `rv_mem`
- Read-only
- Always uses `byte_en = 4'b1111`
- `wr_en = 0`
- Addressed using `pc[31:2]`
- Used for instruction fetch (IF → ID)

### Data Memory
- Implemented using `rv_dmem_wrap`
- Supports read/write
- Controlled by pipeline signals
- Used for load/store instructions (EXE → MEM → WB)

---

## Design Rationale

- **Single memory model (`rv_mem`)**  
  Avoids duplication and keeps behavior consistent.

- **Wrappers define semantics**  
  Whether a memory is instruction or data is determined by the wrapper, not the memory itself.

- **Clear hierarchy for verification**  
  Enables clean XMR access in testbenches.

---

## Summary

| Module        | Purpose                              |
|--------------|--------------------------------------|
| `rv_mem`     | Generic synchronous memory           |
| `rv_dmem_wrap` | Data memory semantics (LSU logic)    |
| `rv_mem_wrap` | Pipeline memory stage (IMEM + DMEM)  |

This structure cleanly separates concerns and aligns with standard CPU microarchitecture practices.