# FPGA_BAU

## RISC-V FPGA System Project
This repository contains our final-year Electrical Engineering project, where we design and implement a full RISC-V–based computing system, including a CPU, memory interface, I/O handling, UART communication, and video display output — all running on an FPGA platform.

### Project Overview
The goal of the project is to build a complete working system based on a RISC-V pipelined CPU, capable of executing user-provided software and interacting with external peripherals through FPGA hardware interfaces.



### Start commands
FIXME - add command to compile simulate and debug components


### Project Stages
#### 1️⃣ RISC-V Pipelined CPU Design

Design and implementation of a 32-bit RISC-V processor.

Supports pipelining stages (IF, ID, EX, MEM, WB).

Fully synthesizable and developed in Verilog/SystemVerilog.


#### 2️⃣ FPGA Deployment & Basic I/O Integration 

Deploy the processor to an FPGA board.

Connect the CPU to the board’s peripherals (switches, LEDs, buttons).

Write test software in C, compiled to RISC-V machine code, to verify functionality (e.g., read switches and perform actions accordingly).


#### 3️⃣ UART Communication Layer

Integrate a UART-to-USB interface for external host communication.

Enable reading and writing to CPU memory from a computer.

Implement a communication protocol allowing the PC to send program instructions to be executed on the FPGA system.


#### 4️⃣ Display Engine (VGA Output)

Implement a VGA controller supporting standard video timing.

Generate pixel signals and synchronization pulses at the required frequency.

Map CPU-generated framebuffer data to live screen output.


### ⌨️ Interpreter Functionality (Planned Feature)

A command-line interpreter will be developed to support standalone programming directly on the FPGA:

Connect a keyboard to the FPGA.

Type commands/code directly.

Interpreter parses and translates instructions into machine code.

The CPU executes the code in real time.


### Technologies and Tools

Hardware: FPGA board (specify model later)

HDL: SystemVerilog

ISA: RISC-V RV32I

Software: C programming for compiled test programs

Interfaces: UART, VGA, GPIO

### Repository Structure

/src                   → RISC-V pipeline implementation

/verif                 → Testbenches for individual hardware modules

/src/peripherals       → UART, VGA controller, GPIO logic

/software              → C test programs and interpreter

/docs                  → Documentation and architecture diagrams

### Status
| Stage           | Progress       |
| --------------- | -------------- |
| CPU Design      | 🟡 In progress |
| FPGA Deployment | ⏳ Pending      |
| UART Interface  | ⏳ Pending      |
| VGA Engine      | ⏳ Pending      |


## Authors

Hila Mashiach

Keren Sharon
